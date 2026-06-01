/* == SQL 1033 - PROGRAMAÇÕES DE FÉRIAS == */
/* Baseada na mesma régua do 1032 */

WITH
PARAM AS (
  SELECT DATE '2026-04-23' AS DT_CORTE FROM DUAL
),

/* contratos existentes no lote: admitidos até 22/04/2026 */
CONTRATOS_OK AS (
  SELECT
      C.COD_CONTRATO,
      MIN(TRUNC(C.DATA_ADMISSAO)) AS DATA_ADMISSAO,
      MAX(TRUNC(C.DATA_DEMISSAO)) AS DATA_DEMISSAO
    FROM V_DADOS_CONTRATO_AVT C
   CROSS JOIN PARAM P
   GROUP BY C.COD_CONTRATO, P.DT_CORTE
  HAVING MIN(NVL(TRUNC(C.DATA_ADMISSAO), DATE '1900-01-01')) < P.DT_CORTE
),

/* evita multiplicação pela RHFP0401 */
ORG_UNICO AS (
  SELECT
      O.COD_ORGANOGRAMA,
      MAX(O.COD_NIVEL2) AS COD_NIVEL2
  FROM RHFP0401 O
  WHERE O.COD_NIVEL2 IS NOT NULL
  GROUP BY O.COD_ORGANOGRAMA
),

/* mesma lógica auxiliar do 1032: dias gozados/abono/faltas por período */
FERIAS AS (
    SELECT
        B.COD_CONTRATO,
        TRUNC(B.DATA_INICIO_PERIODO) AS DATA_INICIO_PERIODO,
        SUM(NVL(B.DIAS_FERIAS, 0)) AS DIAS_GOZADOS,
        SUM(NVL(B.DIAS_ABONO, 0))  AS DIAS_ABONO,
        SUM(NVL(B.FALTA_FERIAS, 0)) AS FALTA_FERIAS
    FROM RHFP0328 B
    GROUP BY
        B.COD_CONTRATO,
        TRUNC(B.DATA_INICIO_PERIODO)
),

/* mesma lógica do 1032 para identificar se o período teve quitação por rescisão */
FERIAS_GOZADAS AS (
    SELECT
        X.COD_CONTRATO,
        TRUNC(X.DATA_INICIO_PERIODO) AS DATA_INICIO_PERIODO,

        MAX(CASE
              WHEN X.TIPO_FERIAS = 'R' THEN 1
              ELSE 0
            END) AS TEM_RESCISAO,

        MAX(X.TIPO_FERIAS) KEEP (
            DENSE_RANK LAST ORDER BY X.DATA_PREVISTA_FERIAS
        ) AS TIPO_FERIAS

    FROM (
        SELECT DISTINCT
               B.COD_CONTRATO,
               B.DATA_INICIO_PERIODO,
               C.DATA_PREVISTA_FERIAS,
               C.TIPO_FERIAS
        FROM RHFP0328 B
        JOIN RHFP0327 C
          ON C.COD_CONTRATO = B.COD_CONTRATO
         AND TRUNC(C.DATA_PREVISTA_FERIAS) = TRUNC(B.DATA_PREVISTA_FERIAS)
    ) X
    GROUP BY
        X.COD_CONTRATO,
        TRUNC(X.DATA_INICIO_PERIODO)
),

/*
   BASE DO 1032:
   Uma linha por período aquisitivo do contrato,
   com empresa resolvida pela DATA_INICIO_PERIODO.
*/
PERIODOS_1032 AS (
    SELECT DISTINCT
        ORG.COD_NIVEL2 AS CODIGO_EMPRESA,
        1 AS TIPO_COLABORADOR,
        A.COD_CONTRATO,
        TRUNC(A.DATA_INICIO_PERIODO) AS DATA_INICIO_PERIODO,
        TRUNC(A.DATA_FIM_PERIODO)    AS DATA_FIM_PERIODO,
        OK.DATA_ADMISSAO,
        OK.DATA_DEMISSAO,

        NVL(A.DIAS_PERIODO, 0) - NVL(F.FALTA_FERIAS, 0) AS DIAS_DIREITO,
        NVL(F.FALTA_FERIAS, 0) AS DIAS_FALTA,
        NVL(F.DIAS_GOZADOS, 0) AS DIAS_DEBITO,
        NVL(F.DIAS_ABONO, 0) AS DIAS_ABONO,

        NVL(A.DIAS_PERIODO, 0)
        - NVL(F.DIAS_GOZADOS, 0)
        - NVL(F.DIAS_ABONO, 0)
        - NVL(F.FALTA_FERIAS, 0) AS DIAS_SALDO,

        CASE
             WHEN OK.DATA_DEMISSAO IS NOT NULL
              AND TRUNC(A.DATA_INICIO_PERIODO) <= TRUNC(OK.DATA_DEMISSAO)
              AND (
                    NVL(A.DIAS_PERIODO, 0)
                  - NVL(F.DIAS_GOZADOS, 0)
                  - NVL(F.DIAS_ABONO, 0)
                  - NVL(F.FALTA_FERIAS, 0)
              ) > 0
             THEN 2

             WHEN NVL(FG.TEM_RESCISAO, 0) = 1
              AND OK.DATA_DEMISSAO IS NOT NULL
             THEN 2

             WHEN (
                    NVL(A.DIAS_PERIODO, 0)
                  - NVL(F.DIAS_GOZADOS, 0)
                  - NVL(F.DIAS_ABONO, 0)
                  - NVL(F.FALTA_FERIAS, 0)
              ) <= 0
             THEN 1

             ELSE 0
        END AS SITUACAO_PERIODO,

        A.MULT_AVO

    FROM RHFP0325 A

    JOIN CONTRATOS_OK OK
      ON OK.COD_CONTRATO = A.COD_CONTRATO

    LEFT JOIN FERIAS F
      ON F.COD_CONTRATO = A.COD_CONTRATO
     AND F.DATA_INICIO_PERIODO = TRUNC(A.DATA_INICIO_PERIODO)

    LEFT JOIN FERIAS_GOZADAS FG
      ON FG.COD_CONTRATO = A.COD_CONTRATO
     AND FG.DATA_INICIO_PERIODO = TRUNC(A.DATA_INICIO_PERIODO)

    OUTER APPLY (
        SELECT H.COD_ORGANOGRAMA
          FROM (
            SELECT H.*,
                   CASE
                     WHEN TRUNC(H.DATA_INICIO) <= TRUNC(A.DATA_INICIO_PERIODO)
                      AND TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >= TRUNC(A.DATA_INICIO_PERIODO)
                     THEN 1

                     WHEN TRUNC(H.DATA_INICIO) <= TRUNC(A.DATA_INICIO_PERIODO)
                     THEN 2

                     ELSE 3
                   END AS RK,

                   CASE
                     WHEN TRUNC(H.DATA_INICIO) <= TRUNC(A.DATA_INICIO_PERIODO)
                      AND TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >= TRUNC(A.DATA_INICIO_PERIODO)
                     THEN 0

                     WHEN TRUNC(H.DATA_INICIO) <= TRUNC(A.DATA_INICIO_PERIODO)
                     THEN TRUNC(A.DATA_INICIO_PERIODO) - TRUNC(H.DATA_INICIO)

                     ELSE TRUNC(H.DATA_INICIO) - TRUNC(A.DATA_INICIO_PERIODO)
                   END AS DIST
              FROM RHFP0310 H
             WHERE H.COD_CONTRATO = A.COD_CONTRATO
          ) H
         ORDER BY
              RK,
              DIST,
              CASE WHEN RK IN (1, 2) THEN H.DATA_INICIO END DESC,
              CASE WHEN RK = 3 THEN H.DATA_INICIO END ASC
         FETCH FIRST 1 ROW ONLY
    ) HIST

    JOIN ORG_UNICO ORG
      ON ORG.COD_ORGANOGRAMA = HIST.COD_ORGANOGRAMA

    CROSS JOIN PARAM P

    WHERE TRUNC(A.DATA_INICIO_PERIODO) < P.DT_CORTE
      AND ORG.COD_NIVEL2 IS NOT NULL
),

/*
   A 1033 deve nascer da RHFP0327.
   Aqui entram somente férias reais/programadas.
   Não existe fallback criando linha pela 0328.
*/
FERIAS_0327 AS (
    SELECT
        ROWIDTOCHAR(A.ROWID) AS RID_FERIAS,
        A.COD_CONTRATO,
        TRUNC(A.DATA_FERIAS) AS DATA_FERIAS,
        TRUNC(A.DATA_PREVISTA_FERIAS) AS DATA_PREVISTA_FERIAS,

        TRUNC(NVL(A.DATA_FERIAS, A.DATA_PREVISTA_FERIAS)) AS DATA_INICIO_FERIAS,

        CASE
          WHEN A.DATA_PAGAMENTO IS NULL THEN
            TRUNC(A.DATA_PREVISTA_FERIAS) - 2

          WHEN TRUNC(A.DATA_PAGAMENTO) = DATE '2026-12-31' THEN
            DATE '2025-12-31'

          ELSE
            TRUNC(A.DATA_PAGAMENTO)
        END AS DATA_PAGAMENTO,

        NVL(A.DIAS_FERIAS_CONCED, 0) AS DIAS_FERIAS,
        NVL(A.DIAS_ABONO_CONCED, 0) AS DIAS_ABONO,
        NVL(A.TIPO_FERIAS, 'N') AS TIPO_FERIAS
    FROM RHFP0327 A
    JOIN CONTRATOS_OK OK
      ON OK.COD_CONTRATO = A.COD_CONTRATO
    WHERE NVL(A.TIPO_FERIAS, 'N') <> 'R'

      /*
        Não remove colaborador demitido inteiro.
        Remove apenas férias que não foram gozadas enquanto ele estava ativo.
      */
      AND (
            OK.DATA_DEMISSAO IS NULL
            OR TRUNC(NVL(A.DATA_FERIAS, A.DATA_PREVISTA_FERIAS)) <= TRUNC(OK.DATA_DEMISSAO)
          )
),

/*
   Vincula a programação de férias da 0327 ao período aquisitivo pela 0328,
   e depois usa a base 1032 para garantir empresa/período corretos.
*/
FERIAS_COM_PERIODO AS (
    SELECT
        F.RID_FERIAS,
        PB.CODIGO_EMPRESA,
        F.COD_CONTRATO,
        PB.DATA_INICIO_PERIODO,
        F.DATA_INICIO_FERIAS,
        F.DATA_PREVISTA_FERIAS,
        F.DATA_PAGAMENTO,
        F.DIAS_FERIAS,
        F.DIAS_ABONO,
        F.TIPO_FERIAS,
        PB.DATA_DEMISSAO,
        PB.SITUACAO_PERIODO
    FROM FERIAS_0327 F

    JOIN RHFP0328 P
      ON P.COD_CONTRATO = F.COD_CONTRATO
     AND TRUNC(P.DATA_PREVISTA_FERIAS) = F.DATA_PREVISTA_FERIAS

    JOIN PERIODOS_1032 PB
      ON PB.COD_CONTRATO = P.COD_CONTRATO
     AND PB.DATA_INICIO_PERIODO = TRUNC(P.DATA_INICIO_PERIODO)

    /*
      Segurança adicional:
      Se o colaborador foi demitido, só passa férias iniciadas até a demissão.
    */
    WHERE (
            PB.DATA_DEMISSAO IS NULL
            OR F.DATA_INICIO_FERIAS <= TRUNC(PB.DATA_DEMISSAO)
          )
),

/*
   Deduplica somente multiplicações técnicas.
   A chave principal é o RID da RHFP0327.
   Ou seja: uma linha real da 0327 vira uma linha no 1033.
*/
FERIAS_DEDUP AS (
    SELECT
        X.*,
        ROW_NUMBER() OVER (
            PARTITION BY X.RID_FERIAS
            ORDER BY
                X.DATA_INICIO_PERIODO,
                X.DATA_INICIO_FERIAS,
                X.DATA_PREVISTA_FERIAS
        ) AS RN
    FROM FERIAS_COM_PERIODO X
),

/*
   OP existe só para manter o SELECT final no padrão esperado.
   A empresa já veio da mesma base do 1032.
*/
ORG_PICK AS (
    SELECT
        F.RID_FERIAS,
        MAX(F.CODIGO_EMPRESA) AS CODIGO_EMPRESA
    FROM FERIAS_DEDUP F
    WHERE F.RN = 1
    GROUP BY F.RID_FERIAS
)

SELECT
    OP.CODIGO_EMPRESA AS "codigo_empresa",
    1 AS "tipo_colaborador",
    F.COD_CONTRATO AS "cadastro_colaborador",
    TO_CHAR(F.DATA_INICIO_PERIODO, 'DD/MM/YYYY') AS "data_inicio_periodo_ferias",
    TO_CHAR(F.DATA_INICIO_FERIAS, 'DD/MM/YYYY') AS "data_inicio_ferias",
    CASE
      WHEN F.TIPO_FERIAS = 'C' THEN 'C'
      ELSE 'N'
    END AS "tipo_ferias",
    'S' AS "opcao_13_salario",
    TO_CHAR(F.DATA_PAGAMENTO, 'DD/MM/YYYY') AS "data_pagamento_recibo",
    F.DIAS_FERIAS AS "dias_ferias",
    F.DIAS_ABONO AS "dias_abono",
    0 AS "salario_base"
FROM FERIAS_DEDUP F
JOIN ORG_PICK OP
  ON OP.RID_FERIAS = F.RID_FERIAS
WHERE F.RN = 1
  AND OP.CODIGO_EMPRESA IS NOT NULL
  --AND F.DATA_INICIO_FERIAS > '22/04/2026'
  AND F.COD_CONTRATO = 393642
ORDER BY
    F.COD_CONTRATO,
    F.DATA_INICIO_PERIODO,
    F.DATA_INICIO_FERIAS;














/* == SQL 1033 - MESTRE DE FERIAS ==
====================================
VERSÃO TRANSFERIDOS
*/

WITH PARAM AS (
    SELECT DATE '2026-04-23' AS DT_CORTE
      FROM DUAL
),

/* contratos existentes no cadastro importado */
CONTRATOS_OK AS (
    SELECT C.COD_CONTRATO
      FROM V_DADOS_CONTRATO_AVT C
     CROSS JOIN PARAM P
     GROUP BY C.COD_CONTRATO, P.DT_CORTE
    HAVING MIN(NVL(TRUNC(C.DATA_ADMISSAO), DATE '1900-01-01')) < P.DT_CORTE
),

/* =========================================================
   MAPA DE REPLICAÇÃO
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
   BASE ORIGINAL DO 1033
   ========================================================= */
FER AS (
    SELECT A.ROWID AS RID_FERIAS,
           A.COD_CONTRATO,
           A.DATA_FERIAS,
           A.DATA_PREVISTA_FERIAS,
           A.DATA_PAGAMENTO,
           NVL(A.DIAS_FERIAS_CONCED, 0) AS DIAS_FERIAS_CONCED,
           NVL(A.DIAS_ABONO_CONCED, 0) AS DIAS_ABONO_CONCED,
           TRUNC(NVL(A.DATA_FERIAS, A.DATA_PREVISTA_FERIAS)) AS DT_REF_FER,
           A.TIPO_FERIAS
      FROM RHFP0327 A
      JOIN CONTRATOS_OK OK
        ON OK.COD_CONTRATO = A.COD_CONTRATO
     WHERE EXISTS (
           SELECT 1
             FROM MAPA_BASE MB
            WHERE MB.COD_CONTRATO = A.COD_CONTRATO
     )
),

/* escolhe 1 período (0328) por férias */
P_PICK AS (
    SELECT F.RID_FERIAS,
           P.DATA_INICIO_PERIODO,
           ROW_NUMBER() OVER (
               PARTITION BY F.RID_FERIAS
               ORDER BY CASE WHEN P.DATA_INICIO_PERIODO <= F.DT_REF_FER THEN 0 ELSE 1 END,
                        CASE WHEN P.DATA_INICIO_PERIODO <= F.DT_REF_FER THEN P.DATA_INICIO_PERIODO END DESC,
                        CASE WHEN P.DATA_INICIO_PERIODO > F.DT_REF_FER THEN P.DATA_INICIO_PERIODO END ASC
           ) AS RN
      FROM FER F
      LEFT JOIN RHFP0328 P
        ON P.COD_CONTRATO = F.COD_CONTRATO
       AND P.DATA_PREVISTA_FERIAS = F.DATA_PREVISTA_FERIAS
),

/* monta a base final ainda 1 linha por férias */
FER2 AS (
    SELECT DISTINCT
           F.*,
           B.DATA_INICIO_PERIODO,
           TRUNC(NVL(F.DATA_FERIAS,
                     NVL(F.DATA_PREVISTA_FERIAS, B.DATA_INICIO_PERIODO))) AS DT_REF
      FROM FER F
      LEFT JOIN P_PICK PK
        ON PK.RID_FERIAS = F.RID_FERIAS
       AND PK.RN = 1
      LEFT JOIN RHFP0325 B
        ON B.COD_CONTRATO = F.COD_CONTRATO
       AND B.DATA_INICIO_PERIODO = PK.DATA_INICIO_PERIODO
     CROSS JOIN PARAM P
     WHERE TRUNC(NVL(F.DATA_FERIAS,
                     NVL(F.DATA_PREVISTA_FERIAS, B.DATA_INICIO_PERIODO))) <= P.DT_CORTE
),

/* escolhe 1 empresa da origem por férias */
ORG_PICK AS (
    SELECT F2.RID_FERIAS,
           ORG.COD_NIVEL2 AS CODIGO_EMPRESA,
           ROW_NUMBER() OVER (
               PARTITION BY F2.RID_FERIAS
               ORDER BY CASE
                          WHEN H.DATA_INICIO <= F2.DT_REF
                           AND NVL(H.DATA_FIM, DATE '9999-12-31') >= F2.DT_REF THEN 1
                          WHEN H.DATA_INICIO <= F2.DT_REF THEN 2
                          ELSE 3
                        END,
                        CASE
                          WHEN H.DATA_INICIO <= F2.DT_REF
                           AND NVL(H.DATA_FIM, DATE '9999-12-31') >= F2.DT_REF THEN 0
                          WHEN H.DATA_INICIO <= F2.DT_REF THEN F2.DT_REF - H.DATA_INICIO
                          ELSE H.DATA_INICIO - F2.DT_REF
                        END,
                        CASE WHEN H.DATA_INICIO <= F2.DT_REF THEN H.DATA_INICIO END DESC,
                        CASE WHEN H.DATA_INICIO > F2.DT_REF THEN H.DATA_INICIO END ASC
           ) AS RN
      FROM FER2 F2
      LEFT JOIN RHFP0310 H
        ON H.COD_CONTRATO = F2.COD_CONTRATO
      LEFT JOIN RHFP0401 ORG
        ON ORG.COD_ORGANOGRAMA = H.COD_ORGANOGRAMA
),

BASE_ORIGEM AS (
    SELECT OP.CODIGO_EMPRESA AS COD_EMPRESA,
           1 AS TIPO_COLABORADOR,
           F2.COD_CONTRATO,
           F2.DATA_INICIO_PERIODO,
           F2.DATA_FERIAS,
           F2.TIPO_FERIAS,
           F2.DATA_PAGAMENTO,
           F2.DIAS_FERIAS_CONCED,
           F2.DIAS_ABONO_CONCED,
           0 AS SALARIO_BASE,
           F2.DT_REF
      FROM FER2 F2
      LEFT JOIN ORG_PICK OP
        ON OP.RID_FERIAS = F2.RID_FERIAS
       AND OP.RN = 1
     WHERE OP.CODIGO_EMPRESA IS NOT NULL
       AND F2.TIPO_FERIAS <> 'R'
),

/* replica origem -> destino */
BASE_REPLICADA AS (
    SELECT MF.EMPRESA_DESTINO AS COD_EMPRESA,
           BO.TIPO_COLABORADOR,
           BO.COD_CONTRATO,
           BO.DATA_INICIO_PERIODO,
           BO.DATA_FERIAS,
           BO.TIPO_FERIAS,
           BO.DATA_PAGAMENTO,
           BO.DIAS_FERIAS_CONCED,
           BO.DIAS_ABONO_CONCED,
           BO.SALARIO_BASE,
           BO.DT_REF,
           ROW_NUMBER() OVER (
               PARTITION BY MF.EMPRESA_DESTINO,
                            BO.COD_CONTRATO,
                            BO.DATA_INICIO_PERIODO,
                            NVL(BO.DATA_FERIAS, DATE '1900-01-01'),
                            NVL(BO.DATA_PAGAMENTO, DATE '1900-01-01'),
                            BO.DIAS_FERIAS_CONCED,
                            BO.DIAS_ABONO_CONCED
               ORDER BY MF.DATA_TRANSFERENCIA DESC,
                        MF.EMPRESA_ORIGEM DESC
           ) AS RN
      FROM BASE_ORIGEM BO
      JOIN MAPA_FINAL MF
        ON MF.COD_CONTRATO   = BO.COD_CONTRATO
       AND MF.EMPRESA_ORIGEM = BO.COD_EMPRESA
)

SELECT COD_EMPRESA AS "codigo_empresa",
       TIPO_COLABORADOR AS "tipo_colaborador",
       COD_CONTRATO AS "cadastro_colaborador",
       TO_CHAR(DATA_INICIO_PERIODO, 'DD/MM/YYYY') AS "data_inicio_periodo_ferias",
       TO_CHAR(DATA_FERIAS, 'DD/MM/YYYY') AS "data_inicio_ferias",
       CASE
         WHEN TIPO_FERIAS = 'C' THEN 'C'
         ELSE 'N'
       END AS "tipo_ferias",
       'S' AS "opcao_13_salario",
       TO_CHAR(DATA_PAGAMENTO, 'DD/MM/YYYY') AS "data_pagamento_recibo",
       DIAS_FERIAS_CONCED AS "dias_ferias",
       DIAS_ABONO_CONCED AS "dias_abono",
       SALARIO_BASE AS "salario_base"
  FROM BASE_REPLICADA
 WHERE RN = 1
 AND COD_CONTRATO = 391954
 ORDER BY COD_CONTRATO, COD_EMPRESA, DT_REF;

