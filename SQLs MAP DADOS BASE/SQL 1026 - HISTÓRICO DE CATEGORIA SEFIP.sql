/*=== 1026 - HISTÓRICO DE CATEGORIA SEFIP ===*/
/* Regra:
   - Data vem da SEFIP (não muda)
   - Categoria vem da SEFIP
   - Replica para cada empresa do contrato
   - Sem inventar datas novas
*/

WITH
PARAM AS (
  SELECT DATE '2026-04-23' AS DT_CORTE FROM DUAL
),

CONTRATOS_OK AS (
  SELECT A.COD_CONTRATO
    FROM RHFP0300 A
    CROSS JOIN PARAM P
   GROUP BY A.COD_CONTRATO, P.DT_CORTE
  HAVING MIN(TRUNC(NVL(A.DATA_AVANCO, A.DATA_INICIO))) < P.DT_CORTE
),

/* SEFIP - HISTÓRICO REAL */
SEFIP_BASE AS (
  SELECT DISTINCT
         H.COD_CONTRATO,
         TRUNC(H.DATA_HISTORICO) AS DT_ALT,
         H.COD_CATEGORIA_TRAB AS CATEGORIA_SEFIP
    FROM RHFP0301 H
    JOIN CONTRATOS_OK OK
      ON OK.COD_CONTRATO = H.COD_CONTRATO
   WHERE H.DATA_HISTORICO IS NOT NULL
     AND H.COD_CATEGORIA_TRAB IS NOT NULL
     AND TRUNC(H.DATA_HISTORICO) < (SELECT DT_CORTE FROM PARAM)

  UNION ALL

  /* ADMISSÃO - somente se não tiver histórico */
  SELECT A.COD_CONTRATO,
         TRUNC(A.DATA_INICIO) AS DT_ALT,
         A.COD_CATEGORIA_TRAB AS CATEGORIA_SEFIP
    FROM RHFP0300 A
    JOIN CONTRATOS_OK OK
      ON OK.COD_CONTRATO = A.COD_CONTRATO
   WHERE A.DATA_INICIO IS NOT NULL
     AND A.COD_CATEGORIA_TRAB IS NOT NULL
     AND TRUNC(A.DATA_INICIO) < (SELECT DT_CORTE FROM PARAM)
     AND NOT EXISTS (
           SELECT 1
             FROM RHFP0301 H
            WHERE H.COD_CONTRATO = A.COD_CONTRATO
         )
),

/* REMOVE REPETIÇÃO DE CATEGORIA SEGUIDA */
SEFIP_LIMPA AS (
  SELECT X.*
    FROM (
          SELECT S.*,
                 LAG(S.CATEGORIA_SEFIP) OVER (
                   PARTITION BY S.COD_CONTRATO
                   ORDER BY S.DT_ALT
                 ) AS ANT
            FROM SEFIP_BASE S
         ) X
   WHERE X.ANT IS NULL
      OR X.CATEGORIA_SEFIP <> X.ANT
),

/* EMPRESAS DO CONTRATO */
EMPRESAS AS (
  SELECT DISTINCT
         O.COD_CONTRATO,
         ORG.COD_NIVEL2 AS CODIGO_EMPRESA
    FROM RHFP0310 O
    JOIN RHFP0401 ORG
      ON ORG.COD_ORGANOGRAMA = O.COD_ORGANOGRAMA
   WHERE ORG.COD_NIVEL2 IS NOT NULL
),

/* CRUZAMENTO (REPLICAÇÃO) */
BASE_FINAL AS (
  SELECT E.CODIGO_EMPRESA,
         1 AS TIPO_COLABORADOR,
         S.COD_CONTRATO,
         S.DT_ALT,
         S.CATEGORIA_SEFIP,

         ROW_NUMBER() OVER (
           PARTITION BY
             E.CODIGO_EMPRESA,
             S.COD_CONTRATO,
             S.DT_ALT,
             S.CATEGORIA_SEFIP
           ORDER BY S.DT_ALT
         ) AS RN
    FROM SEFIP_LIMPA S
    JOIN EMPRESAS E
      ON E.COD_CONTRATO = S.COD_CONTRATO
)

SELECT CODIGO_EMPRESA AS "codigo_empresa",
       TIPO_COLABORADOR AS "tipo_colaborador",
       COD_CONTRATO AS "cadastro_colaborador",
       TO_CHAR(DT_ALT, 'DD/MM/YYYY') AS "data_alteracao_categoria",
       CASE
           WHEN CATEGORIA_SEFIP = 1 THEN
             1
           WHEN CATEGORIA_SEFIP = 2 THEN
             2
           WHEN CATEGORIA_SEFIP = 4 THEN
             4
           WHEN CATEGORIA_SEFIP = 7 THEN
             7
           WHEN CATEGORIA_SEFIP = 11 THEN 
             11
           WHEN CATEGORIA_SEFIP = 901 THEN
             99
           ELSE
             99
        END AS "categoria_sefip"
  FROM BASE_FINAL
 WHERE RN = 1
   --AND COD_CONTRATO = 398430
 ORDER BY COD_CONTRATO, DT_ALT, CODIGO_EMPRESA;




--caso se aplicasse, mas a versão acima é o suficiente, pois a categoria não deve ter várias por empresa

/*=== 1026 - HISTÓRICO DE CATEGORIA SEFIP ===*/
/* Regra:
   - Data vem da SEFIP (não muda)
   - Categoria vem da SEFIP
   - Replica somente para destinos conforme mapa de transferência
   - 2 empresas: última transição
   - 3+ empresas: acumulativo
*/

WITH
PARAM AS (
  SELECT DATE '2026-04-23' AS DT_CORTE FROM DUAL
),

CONTRATOS_OK AS (
  SELECT A.COD_CONTRATO
    FROM RHFP0300 A
    CROSS JOIN PARAM P
   GROUP BY A.COD_CONTRATO, P.DT_CORTE
  HAVING MIN(TRUNC(NVL(A.DATA_AVANCO, A.DATA_INICIO))) < P.DT_CORTE
),

/* =========================================================
   MAPA DE REPLICAÇÃO - MESMA LÓGICA DO 1014/1015/1020
   ========================================================= */
MAPA_BASE AS (
    SELECT DISTINCT
           M.COD_CONTRATO,
           M.EMPRESA_ORIGEM,
           M.EMPRESA_DESTINO,
           TRUNC(M.DATA_TRANSFERENCIA) AS DATA_TRANSFERENCIA
      FROM GRZ_MAPA_TRANSF_EMPRESA_V2 M
     WHERE M.EMPRESA_ORIGEM  IS NOT NULL
       AND M.EMPRESA_DESTINO IS NOT NULL
       AND M.EMPRESA_ORIGEM <> M.EMPRESA_DESTINO
),

MAPA_STATS AS (
    SELECT X.COD_CONTRATO,
           COUNT(*) AS QT_MOVIMENTOS,
           COUNT(DISTINCT X.EMPRESA) AS QT_EMPRESAS
      FROM (
            SELECT COD_CONTRATO, EMPRESA_ORIGEM  AS EMPRESA FROM MAPA_BASE
            UNION
            SELECT COD_CONTRATO, EMPRESA_DESTINO AS EMPRESA FROM MAPA_BASE
           ) X
     GROUP BY X.COD_CONTRATO
),

MOV_SEQ AS (
    SELECT MB.COD_CONTRATO,
           MB.EMPRESA_ORIGEM,
           MB.EMPRESA_DESTINO,
           MB.DATA_TRANSFERENCIA,
           ROW_NUMBER() OVER (
               PARTITION BY MB.COD_CONTRATO
               ORDER BY MB.DATA_TRANSFERENCIA,
                        MB.EMPRESA_ORIGEM,
                        MB.EMPRESA_DESTINO
           ) AS RN
      FROM MAPA_BASE MB
),

ULTIMA_TRANSF AS (
    SELECT COD_CONTRATO,
           EMPRESA_ORIGEM,
           EMPRESA_DESTINO,
           DATA_TRANSFERENCIA
      FROM (
            SELECT MS.*,
                   ROW_NUMBER() OVER (
                       PARTITION BY MS.COD_CONTRATO
                       ORDER BY MS.DATA_TRANSFERENCIA DESC,
                                MS.RN DESC
                   ) AS RN_ULT
              FROM MOV_SEQ MS
           )
     WHERE RN_ULT = 1
),

/* 2 empresas distintas: simples e vai-e-volta */
PARES_2_EMPRESAS AS (
    SELECT U.COD_CONTRATO,
           U.EMPRESA_ORIGEM,
           U.EMPRESA_DESTINO,
           U.DATA_TRANSFERENCIA
      FROM ULTIMA_TRANSF U
      JOIN MAPA_STATS S
        ON S.COD_CONTRATO = U.COD_CONTRATO
     WHERE S.QT_EMPRESAS = 2
),

/* 3+ empresas: pares imediatos */
PARES_IMEDIATOS_3MAIS AS (
    SELECT M.COD_CONTRATO,
           M.EMPRESA_ORIGEM,
           M.EMPRESA_DESTINO,
           M.DATA_TRANSFERENCIA
      FROM MOV_SEQ M
      JOIN MAPA_STATS S
        ON S.COD_CONTRATO = M.COD_CONTRATO
     WHERE S.QT_EMPRESAS > 2
),

/* empresas anteriores já percorridas */
EMPRESAS_ANTERIORES AS (
    SELECT DISTINCT
           CUR.COD_CONTRATO,
           CUR.RN              AS RN_ATUAL,
           ANT.EMPRESA_ORIGEM  AS EMPRESA_ANTERIOR
      FROM MOV_SEQ CUR
      JOIN MOV_SEQ ANT
        ON ANT.COD_CONTRATO = CUR.COD_CONTRATO
       AND ANT.RN < CUR.RN
      JOIN MAPA_STATS S
        ON S.COD_CONTRATO = CUR.COD_CONTRATO
     WHERE S.QT_EMPRESAS > 2

    UNION

    SELECT DISTINCT
           CUR.COD_CONTRATO,
           CUR.RN               AS RN_ATUAL,
           ANT.EMPRESA_DESTINO  AS EMPRESA_ANTERIOR
      FROM MOV_SEQ CUR
      JOIN MOV_SEQ ANT
        ON ANT.COD_CONTRATO = CUR.COD_CONTRATO
       AND ANT.RN < CUR.RN
      JOIN MAPA_STATS S
        ON S.COD_CONTRATO = CUR.COD_CONTRATO
     WHERE S.QT_EMPRESAS > 2
),

/* acumulado: ex. 4->8->6 = 4->6 e 8->6 */
PARES_ACUM_3MAIS AS (
    SELECT DISTINCT
           CUR.COD_CONTRATO,
           EA.EMPRESA_ANTERIOR AS EMPRESA_ORIGEM,
           CUR.EMPRESA_DESTINO AS EMPRESA_DESTINO,
           CUR.DATA_TRANSFERENCIA
      FROM MOV_SEQ CUR
      JOIN EMPRESAS_ANTERIORES EA
        ON EA.COD_CONTRATO = CUR.COD_CONTRATO
       AND EA.RN_ATUAL     = CUR.RN
      JOIN MAPA_STATS S
        ON S.COD_CONTRATO = CUR.COD_CONTRATO
     WHERE S.QT_EMPRESAS > 2
       AND EA.EMPRESA_ANTERIOR <> CUR.EMPRESA_DESTINO
),

PARES_3MAIS_BRUTO AS (
    SELECT * FROM PARES_IMEDIATOS_3MAIS
    UNION ALL
    SELECT * FROM PARES_ACUM_3MAIS
),

PARES_3MAIS AS (
    SELECT COD_CONTRATO,
           EMPRESA_ORIGEM,
           EMPRESA_DESTINO,
           DATA_TRANSFERENCIA
      FROM (
            SELECT P.*,
                   ROW_NUMBER() OVER (
                       PARTITION BY P.COD_CONTRATO,
                                    P.EMPRESA_ORIGEM,
                                    P.EMPRESA_DESTINO
                       ORDER BY P.DATA_TRANSFERENCIA DESC
                   ) AS RN_PAR
              FROM PARES_3MAIS_BRUTO P
           )
     WHERE RN_PAR = 1
),

MAPA_FINAL AS (
    SELECT * FROM PARES_2_EMPRESAS
    UNION ALL
    SELECT * FROM PARES_3MAIS
),

/* =========================================================
   SEFIP - HISTÓRICO REAL
   ========================================================= */
SEFIP_BASE AS (
  SELECT DISTINCT
         H.COD_CONTRATO,
         TRUNC(H.DATA_HISTORICO) AS DT_ALT,
         H.COD_CATEGORIA_TRAB AS CATEGORIA_SEFIP
    FROM RHFP0301 H
    JOIN CONTRATOS_OK OK
      ON OK.COD_CONTRATO = H.COD_CONTRATO
   WHERE H.DATA_HISTORICO IS NOT NULL
     AND H.COD_CATEGORIA_TRAB IS NOT NULL
     AND TRUNC(H.DATA_HISTORICO) < (SELECT DT_CORTE FROM PARAM)
     AND EXISTS (
           SELECT 1
             FROM MAPA_BASE MB
            WHERE MB.COD_CONTRATO = H.COD_CONTRATO
     )

  UNION ALL

  /* ADMISSÃO - somente se não tiver histórico */
  SELECT A.COD_CONTRATO,
         TRUNC(A.DATA_INICIO) AS DT_ALT,
         A.COD_CATEGORIA_TRAB AS CATEGORIA_SEFIP
    FROM RHFP0300 A
    JOIN CONTRATOS_OK OK
      ON OK.COD_CONTRATO = A.COD_CONTRATO
   WHERE A.DATA_INICIO IS NOT NULL
     AND A.COD_CATEGORIA_TRAB IS NOT NULL
     AND TRUNC(A.DATA_INICIO) < (SELECT DT_CORTE FROM PARAM)
     AND EXISTS (
           SELECT 1
             FROM MAPA_BASE MB
            WHERE MB.COD_CONTRATO = A.COD_CONTRATO
     )
     AND NOT EXISTS (
           SELECT 1
             FROM RHFP0301 H
            WHERE H.COD_CONTRATO = A.COD_CONTRATO
         )
),

/* REMOVE REPETIÇÃO DE CATEGORIA SEGUIDA */
SEFIP_LIMPA AS (
  SELECT X.*
    FROM (
          SELECT S.*,
                 LAG(S.CATEGORIA_SEFIP) OVER (
                   PARTITION BY S.COD_CONTRATO
                   ORDER BY S.DT_ALT
                 ) AS ANT
            FROM SEFIP_BASE S
         ) X
   WHERE X.ANT IS NULL
      OR X.CATEGORIA_SEFIP <> X.ANT
),

/* EMPRESA REAL DO EVENTO SEFIP */
SEFIP_COM_EMPRESA AS (
  SELECT
         ORG.COD_NIVEL2 AS CODIGO_EMPRESA,
         1 AS TIPO_COLABORADOR,
         S.COD_CONTRATO,
         S.DT_ALT,
         S.CATEGORIA_SEFIP
    FROM SEFIP_LIMPA S

    OUTER APPLY (
        SELECT ZZ.COD_ORGANOGRAMA
          FROM (
                SELECT
                       H.COD_ORGANOGRAMA,
                       ROW_NUMBER() OVER (
                           ORDER BY
                               CASE
                                   WHEN TRUNC(H.DATA_INICIO) <= S.DT_ALT
                                    AND TRUNC(NVL(H.DATA_FIM, DATE '2999-12-31')) >= S.DT_ALT
                                   THEN 1
                                   WHEN TRUNC(H.DATA_INICIO) <= S.DT_ALT
                                   THEN 2
                                   ELSE 3
                               END,
                               CASE
                                   WHEN TRUNC(H.DATA_INICIO) <= S.DT_ALT
                                    AND TRUNC(NVL(H.DATA_FIM, DATE '2999-12-31')) >= S.DT_ALT
                                   THEN 0
                                   WHEN TRUNC(H.DATA_INICIO) <= S.DT_ALT
                                   THEN S.DT_ALT - TRUNC(H.DATA_INICIO)
                                   ELSE TRUNC(H.DATA_INICIO) - S.DT_ALT
                               END,
                               H.DATA_INICIO DESC,
                               NVL(H.DATA_FIM, DATE '2999-12-31') DESC,
                               H.COD_ORGANOGRAMA DESC
                       ) AS RN
                  FROM RHFP0310 H
                 WHERE H.COD_CONTRATO = S.COD_CONTRATO
          ) ZZ
         WHERE ZZ.RN = 1
    ) OV

    LEFT JOIN RHFP0401 ORG
      ON ORG.COD_ORGANOGRAMA = OV.COD_ORGANOGRAMA

   WHERE ORG.COD_NIVEL2 IS NOT NULL
),

/* REPLICA ORIGEM -> DESTINO */
BASE_REPLICADA AS (
  SELECT
         MF.EMPRESA_DESTINO AS CODIGO_EMPRESA,
         S.TIPO_COLABORADOR,
         S.COD_CONTRATO,
         S.DT_ALT,
         S.CATEGORIA_SEFIP,
         ROW_NUMBER() OVER (
           PARTITION BY
             MF.EMPRESA_DESTINO,
             S.COD_CONTRATO,
             S.DT_ALT,
             S.CATEGORIA_SEFIP
           ORDER BY
             MF.DATA_TRANSFERENCIA DESC,
             MF.EMPRESA_ORIGEM DESC
         ) AS RN
    FROM SEFIP_COM_EMPRESA S
    JOIN MAPA_FINAL MF
      ON MF.COD_CONTRATO   = S.COD_CONTRATO
     AND MF.EMPRESA_ORIGEM = S.CODIGO_EMPRESA
)

SELECT CODIGO_EMPRESA AS "codigo_empresa",
       TIPO_COLABORADOR AS "tipo_colaborador",
       COD_CONTRATO AS "cadastro_colaborador",
       TO_CHAR(DT_ALT, 'DD/MM/YYYY') AS "data_alteracao_categoria",
       CASE
           WHEN CATEGORIA_SEFIP = 1 THEN 1
           WHEN CATEGORIA_SEFIP = 2 THEN 2
           WHEN CATEGORIA_SEFIP = 4 THEN 4
           WHEN CATEGORIA_SEFIP = 7 THEN 7
           WHEN CATEGORIA_SEFIP = 11 THEN 11
           WHEN CATEGORIA_SEFIP = 901 THEN 99
           ELSE 99
        END AS "categoria_sefip"
  FROM BASE_REPLICADA
 WHERE RN = 1
 ORDER BY COD_CONTRATO, DT_ALT, CODIGO_EMPRESA;

