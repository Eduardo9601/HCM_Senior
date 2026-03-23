/* ============================================
   == SQL 1002 - CADASTRO DE CENTRO DE CUSTO ==
   ============================================ */


/*=== 1002 - CADASTRO DE CENTRO DE CUSTO ===*/

WITH
/* =========================
   1) BASE CCUs (TIPO 2/3)
   ========================= */
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

/* Pais reais (TIPO 2) referenciados por filhos nível 6 na mesma UNIDADE */
PAI_LVL6_T2 AS (
  SELECT DISTINCT COD_EMP, UNIDADE, SUBORDINADO_A AS COD_ORG_PAI
    FROM BASE_CC
   WHERE COD_TIPO = 2
     AND COD_NIVEL_ORG = 6
     AND SUBORDINADO_A IS NOT NULL
),

/* 1ª etapa: calcula flags (sem ROW_NUMBER ainda) */
CC_FLAGS AS (
  SELECT B.*,

         /* Forçadores */
         CASE
           WHEN B.COD_TIPO = 3 AND B.UNIDADE = 900 AND B.COD_ORGANOGRAMA = 1503 THEN 1
           WHEN B.COD_TIPO = 2 AND B.UNIDADE = 907 AND B.COD_ORGANOGRAMA = 2159 THEN 1
           WHEN B.COD_TIPO = 2 AND B.UNIDADE = 763 AND B.COD_ORGANOGRAMA = 1639 THEN 1
           WHEN B.COD_TIPO = 2 AND B.UNIDADE = 764 AND B.COD_ORGANOGRAMA = 2188 AND B.SUBORDINADO_A = 2266 THEN 1
           WHEN B.COD_TIPO = 2 AND B.UNIDADE = 768 AND B.COD_ORGANOGRAMA = 1641 THEN 1
           WHEN B.COD_TIPO = 2 AND B.UNIDADE = 769 AND B.COD_ORGANOGRAMA = 1764 THEN 1
           WHEN B.COD_TIPO = 2 AND B.UNIDADE = 771 AND B.COD_ORGANOGRAMA = 1643 THEN 1
           ELSE 0
         END AS IS_FORCED,

         /* Marca pai nível 5 (TIPO 2) quando existe filho nível 6 duplicando a UNIDADE */
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

/* 2ª etapa: aplica ROW_NUMBER usando as flags */
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
  SELECT COD_EMP,
         COD_TIPO,
         UNIDADE,
         DES_UNIDADE,
         DATA_INICIO,
         DATA_FIM,
         CASE WHEN IS_FORCED = 1 THEN 0 ELSE 1 END AS PRI,
         COD_ORGANOGRAMA
    FROM RANKED_CC
   WHERE RN = 1
),

/* =========================
   2) LOJAS (TIPO 1)
   ========================= */
BASE_LOJAS AS (
  SELECT A.COD2 AS COD_EMP,
         1 AS COD_TIPO,
         A.COD_ORGANOGRAMA,
         A.EDICAO_ORG AS UNIDADE,
         CASE
           WHEN A.COD_TIPO = 1 THEN
            'FILIAL' || '  ' || A.EDICAO_ORG || ' - ' ||
            TRIM(REGEXP_REPLACE(B.CIDADE, '\s+', ' '))
           ELSE
            TRIM(REGEXP_REPLACE(A.NOME_ORGANOGRAMA, '\s+', ' '))
         END AS DES_UNIDADE,
         A.DATA_INICIO,
         A.DATA_FIM
    FROM V_EST_ORG_AVT A
    JOIN V_EST_ORG_AVT B
      ON A.EDICAO_ORG = B.EDICAO_ORG
   WHERE A.COD_NIVEL_ORG = 5
     AND B.COD_NIVEL_ORG = 3
     AND A.COD_TIPO = 1
     AND A.COD2 = 8
     AND B.COD2 = 8
     AND B.EDICAO_ORG NOT IN ('157', '173', '549', '7549')

  UNION ALL

  SELECT B.COD2 AS COD_EMP,
         1 AS COD_TIPO,
         B.COD_ORGANOGRAMA,
         B.EDICAO_ORG AS UNIDADE,
         CASE
           WHEN B.EDICAO_ORG = '173' THEN
            'TOT - ' || TRIM(REGEXP_REPLACE(B.CIDADE, '\s+', ' ')) || ' ' || B.EDICAO_ORG
           WHEN B.EDICAO_ORG IN ('549', '7549') THEN
            'ECM - E-COMERCE ' || B.EDICAO_ORG
           ELSE
            TRIM(REGEXP_REPLACE(B.NOME_ORGANOGRAMA, '\s+', ' '))
         END AS DES_UNIDADE,
         B.DATA_INICIO,
         B.DATA_FIM
    FROM V_EST_ORG_AVT B
   WHERE B.COD_NIVEL_ORG = 3
     AND B.COD2 = 8
     AND B.EDICAO_ORG IN ('549', '7549')
),

LOJAS_CANON AS (
  SELECT COD_EMP,
         UNIDADE,
         COD_TIPO,
         DES_UNIDADE,
         DATA_INICIO,
         DATA_FIM,
         2 AS PRI,
         COD_ORGANOGRAMA
    FROM (
      SELECT L.*,
             ROW_NUMBER() OVER(
               PARTITION BY L.COD_EMP, L.UNIDADE
               ORDER BY L.COD_ORGANOGRAMA
             ) RN
        FROM BASE_LOJAS L
    )
   WHERE RN = 1
),

/* =======================
   3) COLIGADAS (TIPO 4)
   ======================= */

/* Base do tipo 4 (todas as empresas) */
BASE_T4 AS (
  SELECT A.COD2 AS COD_EMP,
         4 AS COD_TIPO,
         A.COD_ORGANOGRAMA,
         A.COD_NIVEL_ORG,
         A.EDICAO_ORG AS UNIDADE,
         TRIM(REGEXP_REPLACE(A.NOME_ORGANOGRAMA, '\s+', ' ')) AS DES_UNIDADE,
         A.COD3 AS SUBORDINADO_A,
         A.DATA_INICIO,
         A.DATA_FIM
    FROM V_EST_ORG_AVT A
   WHERE A.COD_TIPO = 4
     AND A.COD_NIVEL_ORG IN (5, 6)
),

/* Identifica "pais" (quem tem filhos apontando pra ele) */
T4_CHILD AS (
  SELECT COD_EMP,
         SUBORDINADO_A AS COD_ORG_PAI,
         COUNT(*) AS QTD_FILHOS
    FROM BASE_T4
   WHERE SUBORDINADO_A IS NOT NULL
   GROUP BY COD_EMP, SUBORDINADO_A
),

T4_FLAGS AS (
  SELECT B.*,
         NVL(C.QTD_FILHOS, 0) AS QTD_FILHOS,
         CASE WHEN NVL(C.QTD_FILHOS, 0) > 0 THEN 1 ELSE 0 END AS IS_PAI
    FROM BASE_T4 B
    LEFT JOIN T4_CHILD C
      ON C.COD_EMP = B.COD_EMP
     AND C.COD_ORG_PAI = B.COD_ORGANOGRAMA
),

/* Canoniza: 1 por (empresa, unidade) */
COLIGADAS_CANON AS (
  SELECT COD_EMP,
         COD_TIPO,
         UNIDADE,
         DES_UNIDADE,
         DATA_INICIO,
         DATA_FIM,
         3 AS PRI,
         COD_ORGANOGRAMA
    FROM (
      SELECT F.*,
             ROW_NUMBER() OVER(
               PARTITION BY F.COD_EMP, F.UNIDADE
               ORDER BY
                 /* 1) pai ganha */
                 CASE WHEN F.IS_PAI = 1 THEN 0 ELSE 1 END,
                 /* 2) prioriza nível 6 */
                 CASE WHEN F.COD_NIVEL_ORG = 6 THEN 0 ELSE 1 END,
                 /* 3) vigente/histórico: maior data_fim ganha */
                 NVL(F.DATA_FIM, DATE '2999-12-31') DESC,
                 /* 4) desempate */
                 F.COD_ORGANOGRAMA
             ) RN
        FROM T4_FLAGS F
    )
   WHERE RN = 1
),

/* =========================
   4) UNION GERAL
   ========================= */
ALL_CC AS (
  SELECT COD_EMP, COD_TIPO, UNIDADE, DES_UNIDADE, DATA_INICIO, DATA_FIM, PRI, COD_ORGANOGRAMA
    FROM CC_CANON
  UNION ALL
  SELECT COD_EMP, COD_TIPO, UNIDADE, DES_UNIDADE, DATA_INICIO, DATA_FIM, PRI, COD_ORGANOGRAMA
    FROM LOJAS_CANON
  UNION ALL
  SELECT COD_EMP, COD_TIPO, UNIDADE, DES_UNIDADE, DATA_INICIO, DATA_FIM, PRI, COD_ORGANOGRAMA
    FROM COLIGADAS_CANON
),

FINAL AS (
  SELECT A.*,
         ROW_NUMBER() OVER(
           PARTITION BY A.COD_EMP, A.COD_TIPO, A.UNIDADE
           ORDER BY A.PRI, A.COD_ORGANOGRAMA
         ) AS RN
    FROM ALL_CC A
)

SELECT COD_EMP AS "codigo_empresa",
       CASE
         WHEN COD_TIPO = 2 THEN
          '001' || UNIDADE
         WHEN COD_TIPO = 3 THEN
          '013' || UNIDADE
         ELSE
          UNIDADE
       END AS "codigo_centro_custo",
       SUBSTR(DES_UNIDADE, 1, 80) AS "nome_centro_custo",
       TO_CHAR(DATA_INICIO, 'DD/MM/YYYY') AS "data_criacao",
       CASE
           WHEN DATA_FIM = '31/12/2999' THEN 
             NULL
           ELSE
             TO_CHAR(DATA_FIM, 'DD/MM/YYYY') 
       END AS "data_extincao",
       UNIDADE AS "texto_centro_custo"
  FROM FINAL
 WHERE RN = 1
 ORDER BY COD_TIPO, "codigo_centro_custo";