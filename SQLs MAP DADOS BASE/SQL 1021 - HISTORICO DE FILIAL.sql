/* ============================================
   == SQL 1021 - HISTORICO DE FILIAL ==
   ============================================ */
   
/*VERSÃO DEFINITIVA*/

/*=== 1021 - HISTÓRICO DE FILIAIS (ATÉ DATA CORTE) ===*/

WITH
PARAM AS (
  SELECT TO_DATE('19/01/2026','DD/MM/YYYY') AS DT_CORTE FROM DUAL
),

/* 0) contratos permitidos (admitidos até a data de corte) */
CONTRATOS_OK AS (
  SELECT C.COD_CONTRATO
    FROM V_DADOS_CONTRATO_AVT C
   CROSS JOIN PARAM P
   GROUP BY C.COD_CONTRATO
  HAVING MIN(TRUNC(C.DATA_ADMISSAO)) <= P.DT_CORTE
),

/* 1) Histórico bruto (empresa + filial por data) */
ORG_RAW AS (
  SELECT
      O.COD_CONTRATO,
      O.COD_EMP,
      O.DATA_INI_ORG,
      O.DATA_FIM_ORG,
      O.EDICAO_ORG_3 AS CODIGO_NOVA_FILIAL,
      O.COD_UNIDADE,
      O.COD_ORGANOGRAMA,
      ROW_NUMBER() OVER (
        PARTITION BY O.COD_CONTRATO, O.COD_EMP, O.DATA_INI_ORG, O.EDICAO_ORG_3
        ORDER BY NVL(O.DATA_FIM_ORG, DATE '2999-12-31') DESC, O.COD_ORGANOGRAMA
      ) AS RN_DEDUP
  FROM VH_EST_ORG_CONTRATO_AVT O
  CROSS JOIN PARAM P
  WHERE O.COD_EMP IS NOT NULL
    AND O.EDICAO_ORG_3 IS NOT NULL
    AND O.EDICAO_ORG_3 NOT IN ('157','173')
    /* >>> AQUI é o pulo do gato: só contratos já importados (até a data corte) */
    AND O.COD_CONTRATO IN (SELECT COD_CONTRATO FROM CONTRATOS_OK)
    /* opcional: se tu quer cortar o histórico também pela data do evento */
    AND TRUNC(O.DATA_INI_ORG) <= P.DT_CORTE
),

/* 2) remove duplicata exata */
ORG_BASE AS (
  SELECT *
  FROM ORG_RAW
  WHERE RN_DEDUP = 1
),

/* 3) detecta mudança real (empresa OU filial) */
ORG_CHANGES AS (
  SELECT
      B.*,
      LAG(B.COD_EMP) OVER (
        PARTITION BY B.COD_CONTRATO
        ORDER BY B.DATA_INI_ORG, NVL(B.DATA_FIM_ORG, DATE '2999-12-31'), B.COD_ORGANOGRAMA
      ) AS EMP_ANTERIOR,
      LAG(B.CODIGO_NOVA_FILIAL) OVER (
        PARTITION BY B.COD_CONTRATO
        ORDER BY B.DATA_INI_ORG, NVL(B.DATA_FIM_ORG, DATE '2999-12-31'), B.COD_ORGANOGRAMA
      ) AS FILIAL_ANTERIOR
  FROM ORG_BASE B
),

/* 4) mantém só mudanças (remove repetição em sequência) */
ORG_MOV AS (
  SELECT *
  FROM ORG_CHANGES OC
  WHERE (OC.EMP_ANTERIOR IS NULL OR OC.COD_EMP <> OC.EMP_ANTERIOR
     OR  OC.FILIAL_ANTERIOR IS NULL OR OC.CODIGO_NOVA_FILIAL <> OC.FILIAL_ANTERIOR)
),

/* 5) compacta: garante 1 vez por (contrato, empresa, filial) */
ORG_UNIQ AS (
  SELECT *
  FROM (
    SELECT M.*,
           ROW_NUMBER() OVER(
             PARTITION BY M.COD_CONTRATO, M.COD_EMP, M.CODIGO_NOVA_FILIAL
             ORDER BY M.DATA_INI_ORG, NVL(M.DATA_FIM_ORG, DATE '2999-12-31'), M.COD_ORGANOGRAMA
           ) AS RN_UNIQ
    FROM ORG_MOV M
  )
  WHERE RN_UNIQ = 1
),

/* 6) dados do contrato (qualquer linha válida; não depende de 2999) */
CT_CANON AS (
  SELECT COD_CONTRATO,
         CASE WHEN COD_TIPO_ADMISSAO = 5 THEN 6 ELSE COD_TIPO_ADMISSAO END AS TIPO_ADMISSAO,
         NUM_FICHA_REGISTRO
  FROM (
    SELECT C.*,
           ROW_NUMBER() OVER (
             PARTITION BY C.COD_CONTRATO
             ORDER BY
               CASE WHEN C.NUM_FICHA_REGISTRO IS NOT NULL THEN 0 ELSE 1 END,
               CASE WHEN C.DATA_FIM_FICHA = DATE '2999-12-31' THEN 0 ELSE 1 END,
               NVL(C.DATA_FIM_FICHA, DATE '1900-01-01') DESC,
               NVL(C.DATA_INI_FICHA, DATE '1900-01-01') DESC
           ) RN
      FROM V_DADOS_CONTRATO_AVT C
     WHERE C.COD_CONTRATO IN (SELECT DISTINCT COD_CONTRATO FROM ORG_UNIQ)
  )
  WHERE RN = 1
)

SELECT
    U.COD_EMP AS "codigo_empresa",
    1 AS "tipo_colaborador",
    U.COD_CONTRATO AS "cadastro_colaborador",
    TO_CHAR(U.DATA_INI_ORG, 'DD/MM/YYYY') AS "data_alteracao",
    U.COD_EMP AS "codigo_nova_empresa",
    U.COD_CONTRATO AS "codigo_novo_cadastro",
    U.CODIGO_NOVA_FILIAL AS "codigo_nova_filial",
    C.TIPO_ADMISSAO AS "tipo_admissao",
    NVL(C.NUM_FICHA_REGISTRO, 0) AS "numero_ficha_registro",
    1 AS "tipo_admissao_colaborador"
FROM ORG_UNIQ U
LEFT JOIN CT_CANON C
  ON C.COD_CONTRATO = U.COD_CONTRATO
ORDER BY U.COD_CONTRATO, U.DATA_INI_ORG;







