/*=== SQL C1038 - EVENTOS DE RESCISÃO COMPLEMENTAR ===*/
/*
  BASE PRINCIPAL: RHFP0351
  CÁLCULOS: RHFP1006 + RHFP1003
  EVENTO RESCISÓRIO: RHFP1003.COD_EVENTO = 19

  REGRAS:
  - Só retorna complementar existente na RHFP0351;
  - Não usa COD_MESTRE_EVENTO da RHFP0351;
  - Não vincula por DATA_PAGAMENTO;
  - Casa complementar x cálculo por sequência;
  - Se pagamento comp = pagamento normal, exporta comp + 1 dia;
  - Se pagamento comp nulo, exporta pagamento normal + 1 dia;
  - Se pagamento comp diferente, mantém pagamento da complementar;
  - Retorna somente registros antes da data de corte;
  - Remove somente linha final 100% idêntica.
*/

WITH
PARAM AS (
    SELECT TO_DATE('23/04/2026', 'DD/MM/YYYY') AS DT_CORTE
      FROM DUAL
),

CONTRATOS_OK AS (
    SELECT C.COD_CONTRATO
      FROM V_DADOS_CONTRATO_AVT C
     CROSS JOIN PARAM P
     GROUP BY C.COD_CONTRATO, P.DT_CORTE
    HAVING MIN(NVL(TRUNC(C.DATA_ADMISSAO), DATE '1900-01-01')) < P.DT_CORTE
),

/*===================================================
  RESCISÃO NORMAL - APOIO PARA REGRA DE DATA
=====================================================*/
NORMAL_HDR AS (
    SELECT A.COD_CONTRATO,
           MAX(A.DATA_RESCISAO) AS DATA_RESCISAO_NORMAL,
           MAX(A.DATA_PAGAMENTO) AS DATA_PAGAMENTO_NORMAL
      FROM RHFP0350 A
     GROUP BY A.COD_CONTRATO
),

/*===================================================
  CASOS SEGUROS PARA CASAMENTO POR SEQUÊNCIA
  QTD RHFP0351 = QTD MESTRES 19
=====================================================*/
CASOS_COMP_SEGUROS AS (
    SELECT R.COD_CONTRATO
      FROM (
            SELECT A.COD_CONTRATO,
                   COUNT(*) AS QTD_RESC_COMP
              FROM RHFP0351 A
             GROUP BY A.COD_CONTRATO
           ) R
      JOIN (
            SELECT X.COD_CONTRATO,
                   COUNT(*) AS QTD_MESTRES_19
              FROM (
                    SELECT DISTINCT
                           B.COD_CONTRATO,
                           B.COD_MESTRE_EVENTO
                      FROM RHFP1006 B
                      JOIN RHFP1003 C
                        ON C.COD_MESTRE_EVENTO = B.COD_MESTRE_EVENTO
                     WHERE C.COD_EVENTO = 19
                   ) X
             GROUP BY X.COD_CONTRATO
           ) M
        ON M.COD_CONTRATO = R.COD_CONTRATO
     WHERE R.QTD_RESC_COMP = M.QTD_MESTRES_19
),

/*===================================================
  COMPLEMENTARES NUMERADAS
=====================================================*/
COMPLEMENTARES_SEQ AS (
    SELECT A.COD_CONTRATO,
           A.DATA_RESCISAO AS DATA_RESCISAO_COMP,
           A.DATA_COMPLEMENTO,
           A.DATA_PAGAMENTO AS DATA_PAGAMENTO_COMP,
           ROW_NUMBER() OVER (
               PARTITION BY A.COD_CONTRATO
               ORDER BY
                   NVL(A.DATA_PAGAMENTO, A.DATA_COMPLEMENTO),
                   A.DATA_COMPLEMENTO,
                   A.DATA_RESCISAO,
                   A.ROWID
           ) AS SEQ_COMP
      FROM RHFP0351 A
      JOIN CASOS_COMP_SEGUROS S
        ON S.COD_CONTRATO = A.COD_CONTRATO
),

/*===================================================
  MESTRES 19 NUMERADOS
=====================================================*/
MESTRES_19_SEQ AS (
    SELECT M.COD_CONTRATO,
           M.COD_MESTRE_EVENTO,
           M.DATA_PAGAMENTO_CALC,
           ROW_NUMBER() OVER (
               PARTITION BY M.COD_CONTRATO
               ORDER BY
                   M.DATA_PAGAMENTO_CALC,
                   M.COD_MESTRE_EVENTO
           ) AS SEQ_COMP
      FROM (
            SELECT B.COD_CONTRATO,
                   B.COD_MESTRE_EVENTO,
                   MAX(C.DATA_PAGAMENTO) AS DATA_PAGAMENTO_CALC
              FROM RHFP1006 B
              JOIN RHFP1003 C
                ON C.COD_MESTRE_EVENTO = B.COD_MESTRE_EVENTO
             WHERE C.COD_EVENTO = 19
             GROUP BY B.COD_CONTRATO,
                      B.COD_MESTRE_EVENTO
           ) M
      JOIN CASOS_COMP_SEGUROS S
        ON S.COD_CONTRATO = M.COD_CONTRATO
),

/*===================================================
  BASE COMPLEMENTAR
=====================================================*/
BASE_COMP AS (
    SELECT C.COD_CONTRATO,
           C.SEQ_COMP,
           C.DATA_RESCISAO_COMP,
           C.DATA_COMPLEMENTO,
           C.DATA_PAGAMENTO_COMP,
           N.DATA_PAGAMENTO_NORMAL,
           CASE
               WHEN C.DATA_PAGAMENTO_COMP = N.DATA_PAGAMENTO_NORMAL THEN
                    C.DATA_PAGAMENTO_COMP + 1
               WHEN C.DATA_PAGAMENTO_COMP IS NULL THEN
                    N.DATA_PAGAMENTO_NORMAL + 1
               ELSE
                    C.DATA_PAGAMENTO_COMP
           END AS DATA_PAGAMENTO_EXPORT,
           M.COD_MESTRE_EVENTO,
           EV.COD_EVENTO AS CODIGO_EVENTO,
           B.COD_VD,
           NVL(B.QTDE_VD, 0) AS REF_EVENTO,
           NVL(B.VALOR_VD, 0) AS VALOR_EVENTO
      FROM COMPLEMENTARES_SEQ C
      JOIN MESTRES_19_SEQ M
        ON M.COD_CONTRATO = C.COD_CONTRATO
       AND M.SEQ_COMP = C.SEQ_COMP
      LEFT JOIN NORMAL_HDR N
        ON N.COD_CONTRATO = C.COD_CONTRATO
      JOIN RHFP1006 B
        ON B.COD_CONTRATO = M.COD_CONTRATO
       AND B.COD_MESTRE_EVENTO = M.COD_MESTRE_EVENTO
      JOIN TB_EVENTOS_VD EV
        ON EV.COD_VD = B.COD_VD
),

/*===================================================
  EMPRESA NA DATA DA RESCISÃO COMPLEMENTAR
=====================================================*/
ORG_REF AS (
    SELECT COD_CONTRATO,
           DATA_RESCISAO_COMP,
           COD_ORGANOGRAMA
      FROM (
            SELECT B.COD_CONTRATO,
                   TRUNC(B.DATA_RESCISAO_COMP) AS DATA_RESCISAO_COMP,
                   H.COD_ORGANOGRAMA,
                   ROW_NUMBER() OVER (
                       PARTITION BY B.COD_CONTRATO, TRUNC(B.DATA_RESCISAO_COMP)
                       ORDER BY H.DATA_INICIO DESC,
                                NVL(H.DATA_FIM, DATE '9999-12-31') DESC
                   ) AS RN
              FROM BASE_COMP B
              JOIN RHFP0310 H
                ON H.COD_CONTRATO = B.COD_CONTRATO
               AND TRUNC(H.DATA_INICIO) <= TRUNC(B.DATA_RESCISAO_COMP)
               AND TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >= TRUNC(B.DATA_RESCISAO_COMP)
           )
     WHERE RN = 1
),

/*===================================================
  RESULTADO BRUTO
=====================================================*/
FINAL_BRUTO AS (
    SELECT
           ORG.COD_NIVEL2 AS codigo_empresa,
           1 AS tipo_colaborador,
           B.COD_CONTRATO AS cadastro_colaborador,
           TO_CHAR(B.DATA_PAGAMENTO_EXPORT, 'DD/MM/YYYY') AS data_pagamento,
           1 AS codigo_tabela_eventos,
           B.CODIGO_EVENTO AS codigo_evento,
           TO_CHAR(ROUND(NVL(B.REF_EVENTO, 0), 2), 'FM9999999990D00') AS referencia_evento,
           TO_CHAR(ROUND(NVL(B.VALOR_EVENTO, 0), 2), 'FM9999999990D00') AS valor_evento
      FROM BASE_COMP B
      JOIN CONTRATOS_OK OK
        ON OK.COD_CONTRATO = B.COD_CONTRATO
      JOIN ORG_REF O
        ON O.COD_CONTRATO = B.COD_CONTRATO
       AND O.DATA_RESCISAO_COMP = TRUNC(B.DATA_RESCISAO_COMP)
      JOIN RHFP0401 ORG
        ON ORG.COD_ORGANOGRAMA = O.COD_ORGANOGRAMA
     CROSS JOIN PARAM P
     WHERE B.DATA_PAGAMENTO_EXPORT IS NOT NULL
       AND TRUNC(B.DATA_PAGAMENTO_EXPORT) < P.DT_CORTE
       AND TRUNC(B.DATA_RESCISAO_COMP) < P.DT_CORTE
       AND ORG.COD_NIVEL2 IS NOT NULL
),

/*===================================================
  REMOVE SOMENTE LINHA FINAL 100% IDÊNTICA
=====================================================*/
FINAL_DEDUP AS (
    SELECT F.*,
           ROW_NUMBER() OVER (
               PARTITION BY
                   F.codigo_empresa,
                   F.tipo_colaborador,
                   F.cadastro_colaborador,
                   F.data_pagamento,
                   F.codigo_tabela_eventos,
                   F.codigo_evento,
                   F.referencia_evento,
                   F.valor_evento
               ORDER BY F.codigo_evento
           ) AS RN
      FROM FINAL_BRUTO F
)

SELECT
       codigo_empresa AS "codigo_empresa",
       tipo_colaborador AS "tipo_colaborador",
       cadastro_colaborador AS "cadastro_colaborador",
       data_pagamento AS "data_pagamento",
       codigo_tabela_eventos AS "codigo_tabela_eventos",
       codigo_evento AS "codigo_evento",
       referencia_evento AS "referencia_evento",
       valor_evento AS "valor_evento"
  FROM FINAL_DEDUP
 WHERE RN = 1
   AND valor_evento <> 0
 ORDER BY cadastro_colaborador,
          data_pagamento,
          codigo_evento,
          referencia_evento,
          valor_evento;
