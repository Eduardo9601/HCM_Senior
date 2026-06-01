/* == SQL 1032 - PERIODO DE FERIAS == */
/* ================================== */

/*oficial*/


WITH
PARAM AS (
  SELECT DATE '2026-04-23' AS DT_CORTE FROM DUAL
),

/* contratos “existentes” no lote importado (admissão <= corte) */
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

FERIAS AS (
    SELECT
        B.COD_CONTRATO,
        B.DATA_INICIO_PERIODO,
        SUM(NVL(B.DIAS_FERIAS, 0)) AS DIAS_GOZADOS,
        SUM(NVL(B.DIAS_ABONO, 0))  AS DIAS_ABONO,
        SUM(NVL(B.FALTA_FERIAS, 0)) AS FALTA_FERIAS
    FROM RHFP0328 B
    GROUP BY
        B.COD_CONTRATO,
        B.DATA_INICIO_PERIODO
),

FERIAS_GOZADAS AS (
    SELECT
        X.COD_CONTRATO,
        X.DATA_INICIO_PERIODO,

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
         AND C.DATA_PREVISTA_FERIAS = B.DATA_PREVISTA_FERIAS
    ) X
    GROUP BY
        X.COD_CONTRATO,
        X.DATA_INICIO_PERIODO
),


SELECAO_FINAL AS (
SELECT DISTINCT
    ORG.COD_NIVEL2,
    1 AS TIPO_COLABORADOR,
    A.COD_CONTRATO,
    A.DATA_INICIO_PERIODO,
    A.DATA_FIM_PERIODO,

    NVL(A.DIAS_PERIODO, 0) - NVL(F.FALTA_FERIAS, 0) AS DIAS_DIREITO,
    NVL(F.FALTA_FERIAS, 0) AS DIAS_FALTA,

    NVL(F.DIAS_GOZADOS, 0) AS DIAS_DEBITO,
    0 AS DIAS_SERVICO_MILITAR,
    NVL(F.DIAS_ABONO, 0) AS DIAS_ABONO,
    

    NVL(A.DIAS_PERIODO, 0)
    - NVL(F.DIAS_GOZADOS, 0)
    - NVL(F.DIAS_ABONO, 0)
    - NVL(F.FALTA_FERIAS, 0) AS DIAS_SALDO,

    CASE
        WHEN (
              NVL(A.DIAS_PERIODO, 0)
            - NVL(F.DIAS_GOZADOS, 0)
            - NVL(F.DIAS_ABONO, 0)
            - NVL(F.FALTA_FERIAS, 0)
        ) <= 0
        THEN 'Quitado'

        WHEN (
              NVL(A.DIAS_PERIODO, 0)
            - NVL(F.DIAS_GOZADOS, 0)
            - NVL(F.DIAS_ABONO, 0)
            - NVL(F.FALTA_FERIAS, 0)
        ) > 0
         AND A.DATA_FIM_PERIODO < TRUNC(SYSDATE)
        THEN 'Vencido'

        ELSE 'Pendente'
    END AS SITUACAO_CALC,
    
    CASE
    WHEN OK.DATA_DEMISSAO IS NOT NULL
     AND NVL(FG.TEM_RESCISAO, 0) = 1
    THEN 'Quitado Rescisão'

    WHEN (
          NVL(A.DIAS_PERIODO, 0)
        - NVL(F.DIAS_GOZADOS, 0)
        - NVL(F.DIAS_ABONO, 0)
        - NVL(F.FALTA_FERIAS, 0)
    ) <= 0
    THEN 'Quitado Normal'

    ELSE 'Aberto'
END AS SITUACAO_PERIODO_DESC,

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
              AND OK.DATA_DEMISSAO IS NOT NULL THEN 
           2
      
        WHEN (
              NVL(A.DIAS_PERIODO, 0)
            - NVL(F.DIAS_GOZADOS, 0)
            - NVL(F.DIAS_ABONO, 0)
            - NVL(F.FALTA_FERIAS, 0)
        ) <= 0
        THEN 1

        ELSE 0
    END AS SITUACAO_PERIODO,

    CASE
         WHEN OK.DATA_DEMISSAO IS NOT NULL AND NVL(FG.TEM_RESCISAO, 0) = 1 THEN 
           'Quitado Rescisão'

        WHEN (
              NVL(A.DIAS_PERIODO, 0)
            - NVL(F.DIAS_GOZADOS, 0)
            - NVL(F.DIAS_ABONO, 0)
            - NVL(F.FALTA_FERIAS, 0)
        ) <= 0
        THEN 'Quitado Normal'

        ELSE 'Aberto'
    END AS SITUACAO_PERIODO_DESC,
    A.MULT_AVO

FROM RHFP0325 A

LEFT JOIN FERIAS F
       ON F.COD_CONTRATO = A.COD_CONTRATO
      AND F.DATA_INICIO_PERIODO = A.DATA_INICIO_PERIODO

LEFT JOIN FERIAS_GOZADAS FG
       ON FG.COD_CONTRATO = A.COD_CONTRATO
      AND FG.DATA_INICIO_PERIODO = A.DATA_INICIO_PERIODO
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
     ORDER BY RK,
              DIST,
              CASE WHEN RK IN (1,2) THEN H.DATA_INICIO END DESC,
              CASE WHEN RK = 3 THEN H.DATA_INICIO END ASC
     FETCH FIRST 1 ROW ONLY
) HIST

LEFT JOIN RHFP0401 ORG
  ON ORG.COD_ORGANOGRAMA = HIST.COD_ORGANOGRAMA
CROSS JOIN PARAM P  
JOIN CONTRATOS_OK OK
  ON OK.COD_CONTRATO = A.COD_CONTRATO
WHERE A.COD_CONTRATO IN (SELECT COD_CONTRATO FROM CONTRATOS_OK)
  AND TRUNC(A.DATA_INICIO_PERIODO) < P.DT_CORTE
  AND ORG.COD_NIVEL2 IS NOT NULL
--AND A.COD_CONTRATO = 21831

)

SELECT COD_NIVEL2 AS "codigo_empresa",
       TIPO_COLABORADOR AS "tipo_colaborador",
       COD_CONTRATO AS "cadastro_colaborador",
       DATA_INICIO_PERIODO "data_inicio_periodo",
       DATA_FIM_PERIODO AS "data_fim_periodo",
       DIAS_DIREITO AS "dias_direito",
       DIAS_FALTA AS "dias_falta",
       0 AS "dias_licenca_remunerada",
       0 AS "dias_afastamento",
       DIAS_DEBITO AS "dias_debito",
       DIAS_SERVICO_MILITAR AS "dias_servico_militar",
       DIAS_ABONO AS "dias_abono_pecuario",
       DIAS_SALDO AS "dias_saldo",
       DIAS_DIREITO / NVL(MULT_AVO, 0) AS "avos_ferias",
       SITUACAO_PERIODO AS "situacao_periodo"
FROM SELECAO_FINAL
WHERE SITUACAO_PERIODO = 0
ORDER BY COD_CONTRATO, DATA_INICIO_PERIODO;








/* == SQL 1032 - PERIODO DE FERIAS ==
   ==================================
   VERSÃO TRANSFERIDOS

   Regra:
   - somente contratos com transferência entre empresas
   - 2 empresas: usa somente a última transição
   - 3+ empresas: replicação acumulada
   - mantém dados originais do período de férias
   - troca apenas a empresa para o destino
*/

WITH
PARAM AS (
  SELECT DATE '2026-04-23' AS DT_CORTE FROM DUAL
),

/* contratos existentes no lote importado */
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

/* 2 empresas distintas:
   cobre transferência simples e vai-e-volta */
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

/* acumulado:
   exemplo: 4 -> 8 -> 6
   gera: 4 -> 8, 4 -> 6, 8 -> 6
*/
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
   BASE ORIGINAL DO 1032
   ========================================================= */
FERIAS AS (
    SELECT
        B.COD_CONTRATO,
        B.DATA_INICIO_PERIODO,
        SUM(NVL(B.DIAS_FERIAS, 0)) AS DIAS_GOZADOS,
        SUM(NVL(B.DIAS_ABONO, 0))  AS DIAS_ABONO,
        SUM(NVL(B.FALTA_FERIAS, 0)) AS FALTA_FERIAS
    FROM RHFP0328 B
    GROUP BY
        B.COD_CONTRATO,
        B.DATA_INICIO_PERIODO
),

FERIAS_GOZADAS AS (
    SELECT
        X.COD_CONTRATO,
        X.DATA_INICIO_PERIODO,
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
         AND C.DATA_PREVISTA_FERIAS = B.DATA_PREVISTA_FERIAS
    ) X
    GROUP BY
        X.COD_CONTRATO,
        X.DATA_INICIO_PERIODO
),

SELECAO_ORIGEM AS (
    SELECT
        ORG.COD_NIVEL2 AS COD_EMPRESA,
        1 AS TIPO_COLABORADOR,
        A.COD_CONTRATO,
        A.DATA_INICIO_PERIODO,
        A.DATA_FIM_PERIODO,

        NVL(A.DIAS_PERIODO, 0) - NVL(F.FALTA_FERIAS, 0) AS DIAS_DIREITO,
        NVL(F.FALTA_FERIAS, 0) AS DIAS_FALTA,

        NVL(F.DIAS_GOZADOS, 0) AS DIAS_DEBITO,
        0 AS DIAS_SERVICO_MILITAR,
        NVL(F.DIAS_ABONO, 0) AS DIAS_ABONO,

        NVL(A.DIAS_PERIODO, 0)
        - NVL(F.DIAS_GOZADOS, 0)
        - NVL(F.DIAS_ABONO, 0)
        - NVL(F.FALTA_FERIAS, 0) AS DIAS_SALDO,

        CASE
            WHEN (
                  NVL(A.DIAS_PERIODO, 0)
                - NVL(F.DIAS_GOZADOS, 0)
                - NVL(F.DIAS_ABONO, 0)
                - NVL(F.FALTA_FERIAS, 0)
            ) <= 0
            THEN 'Quitado'

            WHEN (
                  NVL(A.DIAS_PERIODO, 0)
                - NVL(F.DIAS_GOZADOS, 0)
                - NVL(F.DIAS_ABONO, 0)
                - NVL(F.FALTA_FERIAS, 0)
            ) > 0
             AND A.DATA_FIM_PERIODO < TRUNC(SYSDATE)
            THEN 'Vencido'

            ELSE 'Pendente'
        END AS SITUACAO_CALC,

        CASE
            WHEN FG.TIPO_FERIAS = 'R' THEN 2

            WHEN (
                  NVL(A.DIAS_PERIODO, 0)
                - NVL(F.DIAS_GOZADOS, 0)
                - NVL(F.DIAS_ABONO, 0)
                - NVL(F.FALTA_FERIAS, 0)
            ) <= 0
            THEN 1

            ELSE 0
        END AS SITUACAO_PERIODO,

        CASE
            WHEN FG.TIPO_FERIAS = 'R' THEN 'Quitado Rescisão'

            WHEN (
                  NVL(A.DIAS_PERIODO, 0)
                - NVL(F.DIAS_GOZADOS, 0)
                - NVL(F.DIAS_ABONO, 0)
                - NVL(F.FALTA_FERIAS, 0)
            ) <= 0
            THEN 'Quitado Normal'

            ELSE 'Aberto'
        END AS SITUACAO_PERIODO_DESC,

        A.MULT_AVO

    FROM RHFP0325 A

    LEFT JOIN FERIAS F
           ON F.COD_CONTRATO = A.COD_CONTRATO
          AND F.DATA_INICIO_PERIODO = A.DATA_INICIO_PERIODO

    LEFT JOIN FERIAS_GOZADAS FG
           ON FG.COD_CONTRATO = A.COD_CONTRATO
          AND FG.DATA_INICIO_PERIODO = A.DATA_INICIO_PERIODO

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
         ORDER BY RK,
                  DIST,
                  CASE WHEN RK IN (1,2) THEN H.DATA_INICIO END DESC,
                  CASE WHEN RK = 3 THEN H.DATA_INICIO END ASC
         FETCH FIRST 1 ROW ONLY
    ) HIST

    LEFT JOIN RHFP0401 ORG
      ON ORG.COD_ORGANOGRAMA = HIST.COD_ORGANOGRAMA

    CROSS JOIN PARAM P

    WHERE A.COD_CONTRATO IN (SELECT COD_CONTRATO FROM CONTRATOS_OK)
      AND TRUNC(A.DATA_INICIO_PERIODO) < P.DT_CORTE
      AND ORG.COD_NIVEL2 IS NOT NULL
      AND EXISTS (
            SELECT 1
              FROM MAPA_BASE MB
             WHERE MB.COD_CONTRATO = A.COD_CONTRATO
      )
),

/* =========================================================
   REPLICA ORIGEM -> DESTINO
   ========================================================= */
BASE_REPLICADA AS (
    SELECT
        MF.EMPRESA_DESTINO AS COD_EMPRESA,
        SO.TIPO_COLABORADOR,
        SO.COD_CONTRATO,
        SO.DATA_INICIO_PERIODO,
        SO.DATA_FIM_PERIODO,
        SO.DIAS_DIREITO,
        SO.DIAS_FALTA,
        SO.DIAS_DEBITO,
        SO.DIAS_SERVICO_MILITAR,
        SO.DIAS_ABONO,
        SO.DIAS_SALDO,
        SO.MULT_AVO,
        SO.SITUACAO_PERIODO,

        ROW_NUMBER() OVER (
            PARTITION BY
                MF.EMPRESA_DESTINO,
                SO.COD_CONTRATO,
                SO.DATA_INICIO_PERIODO,
                SO.DATA_FIM_PERIODO
            ORDER BY
                MF.DATA_TRANSFERENCIA DESC,
                MF.EMPRESA_ORIGEM DESC
        ) AS RN

    FROM SELECAO_ORIGEM SO
    JOIN MAPA_FINAL MF
      ON MF.COD_CONTRATO   = SO.COD_CONTRATO
     AND MF.EMPRESA_ORIGEM = SO.COD_EMPRESA
)

SELECT COD_EMPRESA AS "codigo_empresa",
       TIPO_COLABORADOR AS "tipo_colaborador",
       COD_CONTRATO AS "cadastro_colaborador",
       DATA_INICIO_PERIODO AS "data_inicio_periodo",
       DATA_FIM_PERIODO AS "data_fim_periodo",
       DIAS_DIREITO AS "dias_direito",
       DIAS_FALTA AS "dias_falta",
       0 AS "dias_licenca_remunerada",
       0 AS "dias_afastamento",
       DIAS_DEBITO AS "dias_debito",
       DIAS_SERVICO_MILITAR AS "dias_servico_militar",
       DIAS_ABONO AS "dias_abono_pecuario",
       DIAS_SALDO AS "dias_saldo",

       CASE
         WHEN NVL(MULT_AVO, 0) = 0 THEN 0
         ELSE DIAS_DIREITO / MULT_AVO
       END AS "avos_ferias",

       SITUACAO_PERIODO AS "situacao_periodo"
  FROM BASE_REPLICADA
 WHERE RN = 1
 AND COD_CONTRATO = 116131
 ORDER BY COD_CONTRATO, COD_EMPRESA, DATA_INICIO_PERIODO;



