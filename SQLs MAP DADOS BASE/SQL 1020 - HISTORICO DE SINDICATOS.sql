/*=== 1020 - HISTÓRICO DE SINDICATOS (LOTE 1 - ATÉ DT_CORTE) ===*/

WITH
PARAM AS (
    SELECT DATE '2026-04-23' AS DT_CORTE
    FROM DUAL
),

CONTRATOS_OK AS (
    SELECT C.COD_CONTRATO
      FROM V_DADOS_CONTRATO_AVT C
     CROSS JOIN PARAM P
     GROUP BY C.COD_CONTRATO, P.DT_CORTE
    HAVING MIN(NVL(TRUNC(C.DATA_AVANCO), DATE '1900-01-01')) < P.DT_CORTE
),

/* =========================================================
   BASE LIMPA DO HISTÓRICO DE SINDICATOS
   Mantém todos os históricos com datas diferentes
   Remove repetição exata do mesmo evento
   ========================================================= */
SIND_BASE AS (
    SELECT
        X.COD_CONTRATO,
        X.DATA_INICIO,
        X.COD_SINDICATO,
        X.IND_MENS_SINDICATO
    FROM (
        SELECT
            SD.COD_CONTRATO AS COD_CONTRATO,
            TRUNC(SD.DATA_INICIO) AS DATA_INICIO,
            NVL(SD.COD_SINDICATO, 0) AS COD_SINDICATO,
            NVL(SD.IND_MENS_SINDICATO, 'N') AS IND_MENS_SINDICATO,
            ROW_NUMBER() OVER (
                PARTITION BY
                    SD.COD_CONTRATO,
                    TRUNC(SD.DATA_INICIO),
                    NVL(SD.COD_SINDICATO, 0),
                    NVL(SD.IND_MENS_SINDICATO, 'N')
                ORDER BY
                    NVL(TRUNC(SD.DATA_FIM), DATE '2999-12-31') DESC,
                    SD.DATA_INICIO DESC,
                    SD.COD_SINDICATO DESC
            ) AS RN
        FROM VH_HIST_SINDICATOS_CONT_AVT SD
        JOIN CONTRATOS_OK OKA
          ON OKA.COD_CONTRATO = SD.COD_CONTRATO
        CROSS JOIN PARAM P
        WHERE TRUNC(SD.DATA_INICIO) < P.DT_CORTE    
    ) x
    WHERE X.RN = 1
),

/* =========================================================
   RESULTADO BASE COM EMPRESA DO MOMENTO DO SINDICATO
   ========================================================= */
BASE_RESULTADO AS (
    SELECT
        ORG.COD_NIVEL2 AS CODIGO_EMPRESA,
        1 AS TIPO_COLABORADOR,
        SB.COD_CONTRATO AS CADASTRO_COLABORADOR,
        SB.DATA_INICIO AS DATA_ALTERACAO,
        SB.COD_SINDICATO AS CODIGO_SINDICATO,
        SB.IND_MENS_SINDICATO AS SOCIO_SINDICATO,
        'S' AS POSSUI_BANCO_HORAS
    FROM SIND_BASE SB

    OUTER APPLY (
        SELECT ZZ.COD_ORGANOGRAMA
        FROM (
            SELECT
                H.COD_ORGANOGRAMA AS COD_ORGANOGRAMA,
                ROW_NUMBER() OVER (
                    ORDER BY
                        CASE
                            WHEN TRUNC(H.DATA_INICIO) <= SB.DATA_INICIO
                             AND TRUNC(NVL(H.DATA_FIM, DATE '2999-12-31')) >= SB.DATA_INICIO
                            THEN 1
                            WHEN TRUNC(H.DATA_INICIO) <= SB.DATA_INICIO
                            THEN 2
                            ELSE 3
                        END,
                        CASE
                            WHEN TRUNC(H.DATA_INICIO) <= SB.DATA_INICIO
                             AND TRUNC(NVL(H.DATA_FIM, DATE '2999-12-31')) >= SB.DATA_INICIO
                            THEN 0
                            WHEN TRUNC(H.DATA_INICIO) <= SB.DATA_INICIO
                            THEN SB.DATA_INICIO - TRUNC(H.DATA_INICIO)
                            ELSE TRUNC(H.DATA_INICIO) - SB.DATA_INICIO
                        END,
                        H.DATA_INICIO DESC,
                        NVL(H.DATA_FIM, DATE '2999-12-31') DESC,
                        H.COD_ORGANOGRAMA DESC
                ) AS RN
            FROM RHFP0310 H
            WHERE H.COD_CONTRATO = SB.COD_CONTRATO
        ) ZZ
        WHERE ZZ.RN = 1
    ) OV

    LEFT JOIN RHFP0401 ORG
      ON ORG.COD_ORGANOGRAMA = OV.COD_ORGANOGRAMA

    WHERE ORG.COD_NIVEL2 IS NOT NULL
),

/* =========================================================
   DEDUP FINAL
   1 linha por contrato + data + sindicato + sócio
   ========================================================= */
FINAL_LIMPO AS (
    SELECT
        BR.CODIGO_EMPRESA,
        BR.TIPO_COLABORADOR,
        BR.CADASTRO_COLABORADOR,
        BR.DATA_ALTERACAO,
        BR.CODIGO_SINDICATO,
        BR.SOCIO_SINDICATO,
        BR.POSSUI_BANCO_HORAS,
        ROW_NUMBER() OVER (
            PARTITION BY
                BR.CADASTRO_COLABORADOR,
                BR.DATA_ALTERACAO,
                BR.CODIGO_SINDICATO,
                NVL(BR.SOCIO_SINDICATO, 'N')
            ORDER BY
                BR.CODIGO_EMPRESA DESC
        ) AS RN
    FROM BASE_RESULTADO BR
)

SELECT
    FL.CODIGO_EMPRESA AS "codigo_empresa",
    FL.TIPO_COLABORADOR AS "tipo_colaborador",
    FL.CADASTRO_COLABORADOR AS "cadastro_colaborador",
    TO_CHAR(FL.DATA_ALTERACAO, 'DD/MM/YYYY') AS "data_alteracao",
    FL.CODIGO_SINDICATO AS "codigo_sindicato",
    FL.SOCIO_SINDICATO AS "socio_sindicato",
    FL.POSSUI_BANCO_HORAS AS "possui_banco_horas"
FROM FINAL_LIMPO FL
WHERE FL.RN = 1
--AND CADASTRO_COLABORADOR = 352683
ORDER BY FL.CADASTRO_COLABORADOR, FL.DATA_ALTERACAO;





/*=== 1020 - HISTÓRICO DE SINDICATOS (VERSÃO TRANSFERIDOS) ===*/
/* Regra:
   - somente contratos com transferência entre empresas
   - 2 empresas: usa somente a última transição (simples ou vai-e-volta)
   - 3+ empresas: replicação acumulada
*/

WITH
PARAM AS (
    SELECT DATE '2026-04-23' AS DT_CORTE
    FROM DUAL
),

CONTRATOS_OK AS (
    SELECT C.COD_CONTRATO
      FROM V_DADOS_CONTRATO_AVT C
     CROSS JOIN PARAM P
     GROUP BY C.COD_CONTRATO, P.DT_CORTE
    HAVING MIN(NVL(TRUNC(C.DATA_AVANCO), DATE '1900-01-01')) < P.DT_CORTE
),

/* =========================================================
   MAPA DE REPLICAÇÃO - MESMA LÓGICA DO 1014/1015
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
   BASE LIMPA DO HISTÓRICO DE SINDICATOS
   ========================================================= */
SIND_BASE AS (
    SELECT
        X.COD_CONTRATO,
        X.DATA_INICIO,
        X.COD_SINDICATO,
        X.IND_MENS_SINDICATO
    FROM (
        SELECT
            SD.COD_CONTRATO AS COD_CONTRATO,
            TRUNC(SD.DATA_INICIO) AS DATA_INICIO,
            NVL(SD.COD_SINDICATO, 0) AS COD_SINDICATO,
            NVL(SD.IND_MENS_SINDICATO, 'N') AS IND_MENS_SINDICATO,
            ROW_NUMBER() OVER (
                PARTITION BY
                    SD.COD_CONTRATO,
                    TRUNC(SD.DATA_INICIO),
                    NVL(SD.COD_SINDICATO, 0),
                    NVL(SD.IND_MENS_SINDICATO, 'N')
                ORDER BY
                    NVL(TRUNC(SD.DATA_FIM), DATE '2999-12-31') DESC,
                    SD.DATA_INICIO DESC,
                    SD.COD_SINDICATO DESC
            ) AS RN
        FROM VH_HIST_SINDICATOS_CONT_AVT SD
        JOIN CONTRATOS_OK OKA
          ON OKA.COD_CONTRATO = SD.COD_CONTRATO
        CROSS JOIN PARAM P
        WHERE TRUNC(SD.DATA_INICIO) < P.DT_CORTE
          AND EXISTS (
                SELECT 1
                  FROM MAPA_BASE MB
                 WHERE MB.COD_CONTRATO = SD.COD_CONTRATO
          )
    ) X
    WHERE X.RN = 1
),

/* =========================================================
   RESULTADO BASE COM EMPRESA REAL DO MOMENTO DO SINDICATO
   ========================================================= */
BASE_RESULTADO AS (
    SELECT
        ORG.COD_NIVEL2 AS CODIGO_EMPRESA,
        1 AS TIPO_COLABORADOR,
        SB.COD_CONTRATO AS CADASTRO_COLABORADOR,
        SB.DATA_INICIO AS DATA_ALTERACAO,
        SB.COD_SINDICATO AS CODIGO_SINDICATO,
        SB.IND_MENS_SINDICATO AS SOCIO_SINDICATO,
        'S' AS POSSUI_BANCO_HORAS
    FROM SIND_BASE SB

    OUTER APPLY (
        SELECT ZZ.COD_ORGANOGRAMA
        FROM (
            SELECT
                H.COD_ORGANOGRAMA AS COD_ORGANOGRAMA,
                ROW_NUMBER() OVER (
                    ORDER BY
                        CASE
                            WHEN TRUNC(H.DATA_INICIO) <= SB.DATA_INICIO
                             AND TRUNC(NVL(H.DATA_FIM, DATE '2999-12-31')) >= SB.DATA_INICIO
                            THEN 1
                            WHEN TRUNC(H.DATA_INICIO) <= SB.DATA_INICIO
                            THEN 2
                            ELSE 3
                        END,
                        CASE
                            WHEN TRUNC(H.DATA_INICIO) <= SB.DATA_INICIO
                             AND TRUNC(NVL(H.DATA_FIM, DATE '2999-12-31')) >= SB.DATA_INICIO
                            THEN 0
                            WHEN TRUNC(H.DATA_INICIO) <= SB.DATA_INICIO
                            THEN SB.DATA_INICIO - TRUNC(H.DATA_INICIO)
                            ELSE TRUNC(H.DATA_INICIO) - SB.DATA_INICIO
                        END,
                        H.DATA_INICIO DESC,
                        NVL(H.DATA_FIM, DATE '2999-12-31') DESC,
                        H.COD_ORGANOGRAMA DESC
                ) AS RN
            FROM RHFP0310 H
            WHERE H.COD_CONTRATO = SB.COD_CONTRATO
        ) ZZ
        WHERE ZZ.RN = 1
    ) OV

    LEFT JOIN RHFP0401 ORG
      ON ORG.COD_ORGANOGRAMA = OV.COD_ORGANOGRAMA

    WHERE ORG.COD_NIVEL2 IS NOT NULL
),

/* =========================================================
   REPLICA ORIGEM -> DESTINO
   ========================================================= */
BASE_REPLICADA AS (
    SELECT
        MF.EMPRESA_DESTINO AS CODIGO_EMPRESA,
        BR.TIPO_COLABORADOR,
        BR.CADASTRO_COLABORADOR,
        BR.DATA_ALTERACAO,
        BR.CODIGO_SINDICATO,
        BR.SOCIO_SINDICATO,
        BR.POSSUI_BANCO_HORAS,
        ROW_NUMBER() OVER (
            PARTITION BY
                MF.EMPRESA_DESTINO,
                BR.CADASTRO_COLABORADOR,
                BR.DATA_ALTERACAO,
                BR.CODIGO_SINDICATO,
                NVL(BR.SOCIO_SINDICATO, 'N')
            ORDER BY
                MF.DATA_TRANSFERENCIA DESC,
                MF.EMPRESA_ORIGEM DESC
        ) AS RN
    FROM BASE_RESULTADO BR
    JOIN MAPA_FINAL MF
      ON MF.COD_CONTRATO   = BR.CADASTRO_COLABORADOR
     AND MF.EMPRESA_ORIGEM = BR.CODIGO_EMPRESA
),

/* =========================================================
   DEDUP FINAL
   ========================================================= */
FINAL_LIMPO AS (
    SELECT
        BR.CODIGO_EMPRESA,
        BR.TIPO_COLABORADOR,
        BR.CADASTRO_COLABORADOR,
        BR.DATA_ALTERACAO,
        BR.CODIGO_SINDICATO,
        BR.SOCIO_SINDICATO,
        BR.POSSUI_BANCO_HORAS
    FROM BASE_REPLICADA BR
    WHERE BR.RN = 1
)

SELECT
    FL.CODIGO_EMPRESA AS "codigo_empresa",
    FL.TIPO_COLABORADOR AS "tipo_colaborador",
    FL.CADASTRO_COLABORADOR AS "cadastro_colaborador",
    TO_CHAR(FL.DATA_ALTERACAO, 'DD/MM/YYYY') AS "data_alteracao",
    FL.CODIGO_SINDICATO AS "codigo_sindicato",
    FL.SOCIO_SINDICATO AS "socio_sindicato",
    FL.POSSUI_BANCO_HORAS AS "possui_banco_horas"
FROM FINAL_LIMPO FL
ORDER BY FL.CADASTRO_COLABORADOR, FL.DATA_ALTERACAO;
