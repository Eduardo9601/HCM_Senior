/* ==========================================
   == 1017 - HISTÓRICO DE CENTROS DE CUSTO ==
   ========================================== */


/*VERSÃO DEFINITIVA*/


WITH
PARAM AS (
  SELECT TO_DATE('19/01/2026','DD/MM/YYYY') AS DT_CORTE FROM DUAL
),

/* contratos que EXISTEM no cadastro importado (admitidos até a data corte) */
CONTRATOS_OK AS (
  SELECT C.COD_CONTRATO
    FROM V_DADOS_CONTRATO_AVT C
   CROSS JOIN PARAM P
   GROUP BY C.COD_CONTRATO, P.DT_CORTE
  HAVING MIN(NVL(TRUNC(C.DATA_ADMISSAO), DATE '1900-01-01')) <= P.DT_CORTE
),

/* =========================================================
   A) MAPA DE CCUs (MESMA LÓGICA DO 1002)
   ========================================================= */

/* --------- TIPO 2/3 (CCUs empresa 8) --------- */
BASE_CC AS (
  SELECT A.COD2 AS COD_EMP,
         A.COD_TIPO,
         A.COD_ORGANOGRAMA,
         A.COD_NIVEL_ORG,
         A.EDICAO_ORG AS UNIDADE,
         TRIM(REGEXP_REPLACE(A.NOME_ORGANOGRAMA, '\s+', ' ')) AS DES_UNIDADE,
         A.COD3 AS SUBORDINADO_A,
         A.DATA_INICIO,
         A.DATA_FIM
    FROM V_EST_ORG_AVT A
   WHERE A.COD2 = 8
     AND A.COD_TIPO IN (2, 3)
     AND A.COD_NIVEL_ORG IN (5, 6)
),

PAI_LVL6_T2 AS (
  SELECT DISTINCT COD_EMP, UNIDADE, SUBORDINADO_A AS COD_ORG_PAI
    FROM BASE_CC
   WHERE COD_TIPO = 2
     AND COD_NIVEL_ORG = 6
     AND SUBORDINADO_A IS NOT NULL
),

CC_FLAGS AS (
  SELECT B.*,
         CASE
           WHEN B.COD_EMP = 8 AND B.COD_TIPO = 3 AND B.UNIDADE = 900 AND B.COD_ORGANOGRAMA = 1503 THEN 1
           WHEN B.COD_EMP = 8 AND B.COD_TIPO = 2 AND B.UNIDADE = 907 AND B.COD_ORGANOGRAMA = 2159 THEN 1
           WHEN B.COD_EMP = 8 AND B.COD_TIPO = 2 AND B.UNIDADE = 763 AND B.COD_ORGANOGRAMA = 1639 THEN 1
           WHEN B.COD_EMP = 8 AND B.COD_TIPO = 2 AND B.UNIDADE = 764 AND B.COD_ORGANOGRAMA = 2188 AND B.SUBORDINADO_A = 2266 THEN 1
           WHEN B.COD_EMP = 8 AND B.COD_TIPO = 2 AND B.UNIDADE = 768 AND B.COD_ORGANOGRAMA = 1641 THEN 1
           WHEN B.COD_EMP = 8 AND B.COD_TIPO = 2 AND B.UNIDADE = 769 AND B.COD_ORGANOGRAMA = 1764 THEN 1
           WHEN B.COD_EMP = 8 AND B.COD_TIPO = 2 AND B.UNIDADE = 771 AND B.COD_ORGANOGRAMA = 1643 THEN 1
           ELSE 0
         END AS IS_FORCED,

         CASE
           WHEN B.COD_TIPO = 2
            AND B.COD_NIVEL_ORG = 5
            AND EXISTS (
                 SELECT 1
                   FROM PAI_LVL6_T2 P
                  WHERE P.COD_EMP     = B.COD_EMP
                    AND P.UNIDADE     = B.UNIDADE
                    AND P.COD_ORG_PAI = B.COD_ORGANOGRAMA
               )
           THEN 1 ELSE 0
         END AS IS_PAI_DE_NIVEL6
    FROM BASE_CC B
),

RANKED_CC AS (
  SELECT F.*,
         ROW_NUMBER() OVER (
           PARTITION BY F.COD_EMP, F.UNIDADE
           ORDER BY
             CASE WHEN F.IS_FORCED = 1 THEN 0 ELSE 1 END,
             CASE WHEN F.IS_PAI_DE_NIVEL6 = 1 THEN 0 ELSE 1 END,
             CASE WHEN F.COD_TIPO = 2 THEN 0 ELSE 1 END,
             CASE WHEN F.COD_NIVEL_ORG = 5 THEN 0 ELSE 1 END,
             F.COD_ORGANOGRAMA
         ) AS RN
    FROM CC_FLAGS F
),

CC_CANON AS (
  SELECT COD_EMP, COD_TIPO, UNIDADE, PRI, COD_ORGANOGRAMA
    FROM (
      SELECT COD_EMP,
             COD_TIPO,
             UNIDADE,
             CASE WHEN IS_FORCED = 1 THEN 0 ELSE 1 END AS PRI,
             COD_ORGANOGRAMA,
             RN
        FROM RANKED_CC
    )
   WHERE RN = 1
),

/* --------- LOJAS (TIPO 1) empresa 8 --------- */
BASE_LOJAS AS (
  SELECT A.COD2 AS COD_EMP,
         1 AS COD_TIPO,
         A.COD_ORGANOGRAMA,
         A.EDICAO_ORG AS UNIDADE
    FROM V_EST_ORG_AVT A
    JOIN V_EST_ORG_AVT B ON A.EDICAO_ORG = B.EDICAO_ORG
   WHERE A.COD_NIVEL_ORG = 5
     AND B.COD_NIVEL_ORG = 3
     AND A.COD_TIPO = 1
     AND A.COD2 = 8
     AND B.COD2 = 8
     AND B.EDICAO_ORG NOT IN ('157','173','549','7549')

  UNION ALL

  SELECT B.COD2 AS COD_EMP,
         1 AS COD_TIPO,
         B.COD_ORGANOGRAMA,
         B.EDICAO_ORG AS UNIDADE
    FROM V_EST_ORG_AVT B
   WHERE B.COD_NIVEL_ORG = 3
     AND B.COD2 = 8
     AND B.EDICAO_ORG IN ('549','7549')
),

LOJAS_CANON AS (
  SELECT COD_EMP, COD_TIPO, UNIDADE, 2 AS PRI, COD_ORGANOGRAMA
    FROM (
      SELECT L.*,
             ROW_NUMBER() OVER(PARTITION BY L.COD_EMP, L.UNIDADE ORDER BY L.COD_ORGANOGRAMA) RN
        FROM BASE_LOJAS L
    )
   WHERE RN = 1
),

/* --------- COLIGADAS (TIPO 4) todas empresas --------- */
BASE_T4 AS (
  SELECT A.COD2 AS COD_EMP,
         4 AS COD_TIPO,
         A.COD_ORGANOGRAMA,
         A.COD_NIVEL_ORG,
         A.EDICAO_ORG AS UNIDADE,
         A.COD3 AS SUBORDINADO_A,
         A.DATA_INICIO,
         A.DATA_FIM
    FROM V_EST_ORG_AVT A
   WHERE A.COD_TIPO = 4
     AND A.COD_NIVEL_ORG IN (5, 6)
),

T4_CHILD AS (
  SELECT COD_EMP, SUBORDINADO_A AS COD_ORG_PAI, COUNT(*) AS QTD_FILHOS
    FROM BASE_T4
   WHERE SUBORDINADO_A IS NOT NULL
   GROUP BY COD_EMP, SUBORDINADO_A
),

COLIGADAS_CANON AS (
  SELECT COD_EMP, COD_TIPO, UNIDADE, 3 AS PRI, COD_ORGANOGRAMA
    FROM (
      SELECT B.COD_EMP,
             4 AS COD_TIPO,
             B.UNIDADE,
             B.COD_ORGANOGRAMA,
             ROW_NUMBER() OVER(
               PARTITION BY B.COD_EMP, B.UNIDADE
               ORDER BY
                 CASE WHEN NVL(C.QTD_FILHOS,0) > 0 THEN 0 ELSE 1 END,
                 CASE WHEN B.COD_NIVEL_ORG = 6 THEN 0 ELSE 1 END,
                 NVL(B.DATA_FIM, DATE '2999-12-31') DESC,
                 B.COD_ORGANOGRAMA
             ) RN
        FROM BASE_T4 B
        LEFT JOIN T4_CHILD C
          ON C.COD_EMP = B.COD_EMP
         AND C.COD_ORG_PAI = B.COD_ORGANOGRAMA
    )
   WHERE RN = 1
),

/* ======= MAPA determinístico: 1 linha por (empresa, unidade) =======
   prioridade: CC (2/3) primeiro, depois coligadas (4), depois lojas (1)
*/
CCU_MAP AS (
  SELECT COD_EMP,
         UNIDADE_NUM,
         CODCCU
    FROM (
      SELECT X.COD_EMP,
             TO_NUMBER(NULLIF(REGEXP_REPLACE(TO_CHAR(X.UNIDADE), '\D', ''), '')) AS UNIDADE_NUM,
             CASE
               WHEN X.COD_TIPO = 2 THEN 1 || TO_CHAR(X.UNIDADE)
               WHEN X.COD_TIPO = 3 THEN 13 || TO_CHAR(X.UNIDADE)
               ELSE TO_CHAR(X.UNIDADE)
             END AS CODCCU,
             ROW_NUMBER() OVER(
               PARTITION BY X.COD_EMP, TO_NUMBER(NULLIF(REGEXP_REPLACE(TO_CHAR(X.UNIDADE), '\D', ''), ''))
               ORDER BY
                 /* tipo 2/3 ganha, depois 4, depois 1 */
                 CASE
                   WHEN X.COD_TIPO IN (2,3) THEN 0
                   WHEN X.COD_TIPO = 4 THEN 1
                   ELSE 2
                 END,
                 X.PRI,
                 X.COD_ORGANOGRAMA
             ) RN
        FROM (
          SELECT COD_EMP, COD_TIPO, UNIDADE, PRI, COD_ORGANOGRAMA FROM CC_CANON
          UNION ALL
          SELECT COD_EMP, COD_TIPO, UNIDADE, PRI, COD_ORGANOGRAMA FROM COLIGADAS_CANON
          UNION ALL
          SELECT COD_EMP, COD_TIPO, UNIDADE, PRI, COD_ORGANOGRAMA FROM LOJAS_CANON
        ) X
    )
   WHERE RN = 1
),

/* =========================================================
   B) HISTÓRICO DO COLABORADOR (COM DATA CORTE + SEM REPETIR CCU)
   ========================================================= */
ORG_RAW_CCU AS (
  SELECT
      O.COD_CONTRATO,
      O.COD_EMP,
      O.DATA_INI_ORG,
      O.DATA_FIM_ORG,
      TO_NUMBER(NULLIF(REGEXP_REPLACE(TO_CHAR(O.COD_UNIDADE), '\D', ''), '')) AS UNIDADE_NUM,
      O.COD_ORGANOGRAMA,
      ROW_NUMBER() OVER (
        PARTITION BY O.COD_CONTRATO, O.COD_EMP, O.DATA_INI_ORG,
                     TO_NUMBER(NULLIF(REGEXP_REPLACE(TO_CHAR(O.COD_UNIDADE), '\D', ''), ''))
        ORDER BY NVL(O.DATA_FIM_ORG, DATE '2999-12-31') DESC, O.COD_ORGANOGRAMA
      ) AS RN_DEDUP
  FROM VH_EST_ORG_CONTRATO_AVT O
  CROSS JOIN PARAM P
  WHERE O.COD_EMP IS NOT NULL
    AND O.COD_UNIDADE IS NOT NULL
    AND O.COD_CONTRATO IN (SELECT COD_CONTRATO FROM CONTRATOS_OK)
    AND TRUNC(O.DATA_INI_ORG) <= P.DT_CORTE
),

ORG_BASE_CCU AS (
  SELECT * FROM ORG_RAW_CCU WHERE RN_DEDUP = 1
),

ORG_CHG_CCU AS (
  SELECT B.*,
         LAG(B.COD_EMP) OVER(
           PARTITION BY B.COD_CONTRATO
           ORDER BY B.DATA_INI_ORG, NVL(B.DATA_FIM_ORG, DATE '2999-12-31'), B.COD_ORGANOGRAMA
         ) AS EMP_ANTERIOR,
         LAG(B.UNIDADE_NUM) OVER(
           PARTITION BY B.COD_CONTRATO
           ORDER BY B.DATA_INI_ORG, NVL(B.DATA_FIM_ORG, DATE '2999-12-31'), B.COD_ORGANOGRAMA
         ) AS CCU_ANTERIOR
    FROM ORG_BASE_CCU B
),

ORG_MOV_CCU AS (
  SELECT *
    FROM ORG_CHG_CCU
   WHERE EMP_ANTERIOR IS NULL
      OR COD_EMP <> EMP_ANTERIOR
      OR CCU_ANTERIOR IS NULL
      OR UNIDADE_NUM <> CCU_ANTERIOR
),

/* não repetir o mesmo CCU dentro da mesma empresa pro mesmo contrato */
ORG_UNIQ_CCU AS (
  SELECT *
    FROM (
      SELECT M.*,
             ROW_NUMBER() OVER(
               PARTITION BY M.COD_CONTRATO, M.COD_EMP, M.UNIDADE_NUM
               ORDER BY M.DATA_INI_ORG, NVL(M.DATA_FIM_ORG, DATE '2999-12-31'), M.COD_ORGANOGRAMA
             ) RN_UNIQ
        FROM ORG_MOV_CCU M
    )
   WHERE RN_UNIQ = 1
)

SELECT
    U.COD_EMP      AS "codigo_empresa",
    1              AS "tipo_colaborador",
    U.COD_CONTRATO AS "cadastro_colaborador",
    TO_CHAR(U.DATA_INI_ORG, 'DD/MM/YYYY') AS "data_alteracao",
    M.CODCCU       AS "codigo_centro_custos"
FROM ORG_UNIQ_CCU U
JOIN CCU_MAP M
  ON M.COD_EMP = U.COD_EMP
 AND M.UNIDADE_NUM = U.UNIDADE_NUM
--WHERE U.COD_CONTRATO = 297305  -- teste
ORDER BY U.COD_EMP, U.COD_CONTRATO, U.DATA_INI_ORG;



