/* == 1017 - HISTÓRICO DE CENTROS DE CUSTO ==
   ========================================== */

/* VERSÃO SIMPLIFICADA E MAIS ASSERTIVA */

WITH
PARAM AS (
  SELECT TO_DATE('23/04/2026','DD/MM/YYYY') AS DT_CORTE
    FROM DUAL
),

/* contratos que EXISTEM no cadastro importado/admitidos até a data corte */
CONTRATOS_OK AS (
  SELECT C.COD_CONTRATO
    FROM V_DADOS_CONTRATO_AVT C
   CROSS JOIN PARAM P
   GROUP BY C.COD_CONTRATO, P.DT_CORTE
  HAVING MIN(NVL(TRUNC(C.DATA_AVANCO), DATE '1900-01-01')) < P.DT_CORTE
),

/* =========================================================
   BASE ÚNICA DO HISTÓRICO ORGANIZACIONAL DO CONTRATO
   ========================================================= */
BASE_HIST AS (
  SELECT
      O.COD_CONTRATO,
      O.NOME_PESSOA,
      O.COD_EMP,
      O.DES_EMP,
      O.COD_ORGANOGRAMA,
      O.DATA_INI_ORG,
      O.DATA_FIM_ORG,
      O.COD_UNIDADE,
      O.COD_TIPO,
      O.DES_UNIDADE,
      O.NOME3
  FROM VH_EST_ORG_CONTRATO_AVT O
  CROSS JOIN PARAM P
  WHERE O.COD_CONTRATO IN (SELECT C.COD_CONTRATO FROM CONTRATOS_OK C)
    AND O.COD_EMP IS NOT NULL
    AND O.COD_UNIDADE IS NOT NULL
    AND O.COD_TIPO IN (1, 2, 3, 4)
    AND O.DATA_INI_ORG < P.DT_CORTE

    /* use para testar contrato específico */
    --AND O.COD_CONTRATO = 389622
),

/* =========================================================
   BLOCO 1 - LOJAS
   Regra: centro de custo = unidade
   ========================================================= */
LOJAS AS (
  SELECT
      B.COD_CONTRATO,
      B.NOME_PESSOA,
      B.COD_EMP,
      B.DES_EMP,
      B.COD_ORGANOGRAMA,
      B.DATA_INI_ORG,
      B.DATA_FIM_ORG,
      B.COD_UNIDADE,
      TO_CHAR(B.COD_UNIDADE) AS CENTRO_CUSTO,
      B.COD_TIPO,
      B.DES_UNIDADE,
      B.NOME3,
      'LOJAS' AS BLOCO_ORIGEM
  FROM BASE_HIST B
  WHERE B.COD_TIPO = 1
),

/* =========================================================
   BLOCO 2 - ADM
   Regra: centro de custo = 1 || unidade
   Exemplo: unidade 763 vira 1763
   ========================================================= */
ADM AS (
  SELECT
      B.COD_CONTRATO,
      B.NOME_PESSOA,
      B.COD_EMP,
      B.DES_EMP,
      B.COD_ORGANOGRAMA,
      B.DATA_INI_ORG,
      B.DATA_FIM_ORG,
      B.COD_UNIDADE,
      '1' || TO_CHAR(B.COD_UNIDADE) AS CENTRO_CUSTO,
      B.COD_TIPO,
      B.DES_UNIDADE,
      B.NOME3,
      'ADM' AS BLOCO_ORIGEM
  FROM BASE_HIST B
  WHERE B.COD_TIPO = 2
),

/* =========================================================
   BLOCO 3 - CD
   Regra: centro de custo = 13 || unidade
   Exemplo: unidade 900 vira 13900
   ========================================================= */
CD AS (
  SELECT
      B.COD_CONTRATO,
      B.NOME_PESSOA,
      B.COD_EMP,
      B.DES_EMP,
      B.COD_ORGANOGRAMA,
      B.DATA_INI_ORG,
      B.DATA_FIM_ORG,
      B.COD_UNIDADE,
      '13' || TO_CHAR(B.COD_UNIDADE) AS CENTRO_CUSTO,
      B.COD_TIPO,
      B.DES_UNIDADE,
      B.NOME3,
      'CD' AS BLOCO_ORIGEM
  FROM BASE_HIST B
  WHERE B.COD_TIPO = 3
),

/* =========================================================
   BLOCO 4 - COLIGADAS
   Regra: centro de custo = unidade
   ========================================================= */
COLIGADAS AS (
  SELECT
      B.COD_CONTRATO,
      B.NOME_PESSOA,
      B.COD_EMP,
      B.DES_EMP,
      B.COD_ORGANOGRAMA,
      B.DATA_INI_ORG,
      B.DATA_FIM_ORG,
      B.COD_UNIDADE,
      TO_CHAR(B.COD_UNIDADE) AS CENTRO_CUSTO,
      B.COD_TIPO,
      B.DES_UNIDADE,
      B.NOME3,
      'COLIGADAS' AS BLOCO_ORIGEM
  FROM BASE_HIST B
  WHERE B.COD_TIPO = 4
),

/* =========================================================
   UNE TODOS OS BLOCOS EM UMA ÚNICA BASE
   ========================================================= */
HIST_UNIFICADO AS (
  SELECT * FROM LOJAS
  UNION ALL
  SELECT * FROM ADM
  UNION ALL
  SELECT * FROM CD
  UNION ALL
  SELECT * FROM COLIGADAS
),

/* =========================================================
   REMOVE DUPLICIDADE EXATA DO MESMO CONTRATO/DATA/CCU
   Mantém a linha mais "atual" pelo DATA_FIM_ORG e ORGANOGRAMA
   ========================================================= */
HIST_DEDUP AS (
  SELECT *
    FROM (
      SELECT H.*,
             ROW_NUMBER() OVER (
               PARTITION BY
                    H.COD_CONTRATO,
                    H.COD_EMP,
                    H.DATA_INI_ORG,
                    H.CENTRO_CUSTO
               ORDER BY
                    NVL(H.DATA_FIM_ORG, DATE '2999-12-31') DESC,
                    H.COD_ORGANOGRAMA DESC
             ) AS RN_DEDUP
        FROM HIST_UNIFICADO H
    )
   WHERE RN_DEDUP = 1
),

/* =========================================================
   IDENTIFICA MUDANÇA REAL DE CENTRO DE CUSTO
   Remove apenas repetição sequencial do mesmo CCU
   ========================================================= */
HIST_COMPARA AS (
  SELECT H.*,
         LAG(H.COD_EMP) OVER (
           PARTITION BY H.COD_CONTRATO
           ORDER BY
                H.DATA_INI_ORG,
                NVL(H.DATA_FIM_ORG, DATE '2999-12-31'),
                H.COD_ORGANOGRAMA
         ) AS COD_EMP_ANT,

         LAG(H.CENTRO_CUSTO) OVER (
           PARTITION BY H.COD_CONTRATO
           ORDER BY
                H.DATA_INI_ORG,
                NVL(H.DATA_FIM_ORG, DATE '2999-12-31'),
                H.COD_ORGANOGRAMA
         ) AS CENTRO_CUSTO_ANT
    FROM HIST_DEDUP H
),

HIST_FINAL AS (
  SELECT *
    FROM HIST_COMPARA
   WHERE COD_EMP_ANT IS NULL
      OR COD_EMP <> COD_EMP_ANT
      OR CENTRO_CUSTO <> CENTRO_CUSTO_ANT
)

SELECT
    F.COD_EMP       AS "codigo_empresa",
    1               AS "tipo_colaborador",
    F.COD_CONTRATO  AS "cadastro_colaborador",
    TO_CHAR(F.DATA_INI_ORG, 'DD/MM/YYYY') AS "data_alteracao",
    F.CENTRO_CUSTO  AS "codigo_centro_custos"
FROM HIST_FINAL F
--WHERE F.COD_CONTRATO = 388606
ORDER BY
    F.COD_CONTRATO,
    F.DATA_INI_ORG,
    F.COD_EMP,
    F.CENTRO_CUSTO;
    
