/*=== SQL N1038 - EVENTOS DE RESCISÃO NORMAL ===*/
/*
  BASE PRINCIPAL: RHFP0350
  CÁLCULOS: RHFP1006 + RHFP1003
  EVENTO RESCISÓRIO: RHFP1003.COD_EVENTO = 17

  REGRAS:
  - Só retorna rescisão normal existente na RHFP0350;
  - Não usa COD_MESTRE_EVENTO da RHFP0350;
  - Não vincula por DATA_PAGAMENTO;
  - Casa rescisão x cálculo por sequência;
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
  CASOS SEGUROS PARA CASAMENTO POR SEQUÊNCIA
  QTD RHFP0350 = QTD MESTRES 17
=====================================================*/
CASOS_NORMAIS_SEGUROS AS (
    SELECT R.COD_CONTRATO
      FROM (
            SELECT A.COD_CONTRATO,
                   COUNT(*) AS QTD_RESC_350
              FROM RHFP0350 A
             GROUP BY A.COD_CONTRATO
           ) R
      JOIN (
            SELECT X.COD_CONTRATO,
                   COUNT(*) AS QTD_MESTRES_17
              FROM (
                    SELECT DISTINCT
                           B.COD_CONTRATO,
                           B.COD_MESTRE_EVENTO
                      FROM RHFP1006 B
                      JOIN RHFP1003 C
                        ON C.COD_MESTRE_EVENTO = B.COD_MESTRE_EVENTO
                     WHERE C.COD_EVENTO = 17
                   ) X
             GROUP BY X.COD_CONTRATO
           ) M
        ON M.COD_CONTRATO = R.COD_CONTRATO
     WHERE R.QTD_RESC_350 = M.QTD_MESTRES_17
),

/*===================================================
  RESCISÕES NORMAIS NUMERADAS
=====================================================*/
RESCISOES_NORMAIS_SEQ AS (
    SELECT A.COD_CONTRATO,
           A.DATA_RESCISAO,
           A.DATA_PAGAMENTO,
           ROW_NUMBER() OVER (
               PARTITION BY A.COD_CONTRATO
               ORDER BY
                   NVL(A.DATA_PAGAMENTO, A.DATA_RESCISAO),
                   A.DATA_RESCISAO,
                   A.ROWID
           ) AS SEQ_RESC
      FROM RHFP0350 A
      JOIN CASOS_NORMAIS_SEGUROS S
        ON S.COD_CONTRATO = A.COD_CONTRATO
),

/*===================================================
  MESTRES 17 NUMERADOS
=====================================================*/
MESTRES_17_SEQ AS (
    SELECT M.COD_CONTRATO,
           M.COD_MESTRE_EVENTO,
           M.DATA_PAGAMENTO_CALC,
           ROW_NUMBER() OVER (
               PARTITION BY M.COD_CONTRATO
               ORDER BY
                   M.DATA_PAGAMENTO_CALC,
                   M.COD_MESTRE_EVENTO
           ) AS SEQ_RESC
      FROM (
            SELECT B.COD_CONTRATO,
                   B.COD_MESTRE_EVENTO,
                   MAX(C.DATA_PAGAMENTO) AS DATA_PAGAMENTO_CALC
              FROM RHFP1006 B
              JOIN RHFP1003 C
                ON C.COD_MESTRE_EVENTO = B.COD_MESTRE_EVENTO
             WHERE C.COD_EVENTO = 17
             GROUP BY B.COD_CONTRATO,
                      B.COD_MESTRE_EVENTO
           ) M
      JOIN CASOS_NORMAIS_SEGUROS S
        ON S.COD_CONTRATO = M.COD_CONTRATO
),

/*===================================================
  BASE NORMAL
=====================================================*/
BASE_NORMAL AS (
    SELECT R.COD_CONTRATO,
           R.DATA_RESCISAO,
           R.DATA_PAGAMENTO,
           M.COD_MESTRE_EVENTO,
           EV.COD_EVENTO AS CODIGO_EVENTO,
           B.COD_VD,
           NVL(B.QTDE_VD, 0) AS REF_EVENTO,
           NVL(B.VALOR_VD, 0) AS VALOR_EVENTO
      FROM RESCISOES_NORMAIS_SEQ R
      JOIN MESTRES_17_SEQ M
        ON M.COD_CONTRATO = R.COD_CONTRATO
       AND M.SEQ_RESC = R.SEQ_RESC
      JOIN RHFP1006 B
        ON B.COD_CONTRATO = M.COD_CONTRATO
       AND B.COD_MESTRE_EVENTO = M.COD_MESTRE_EVENTO
      JOIN TB_EVENTOS_VD EV
        ON EV.COD_VD = B.COD_VD
),

/*===================================================
  EMPRESA NA DATA DA RESCISÃO
=====================================================*/
ORG_REF AS (
    SELECT COD_CONTRATO,
           DATA_RESCISAO,
           COD_ORGANOGRAMA
      FROM (
            SELECT B.COD_CONTRATO,
                   TRUNC(B.DATA_RESCISAO) AS DATA_RESCISAO,
                   H.COD_ORGANOGRAMA,
                   ROW_NUMBER() OVER (
                       PARTITION BY B.COD_CONTRATO, TRUNC(B.DATA_RESCISAO)
                       ORDER BY H.DATA_INICIO DESC,
                                NVL(H.DATA_FIM, DATE '9999-12-31') DESC
                   ) AS RN
              FROM BASE_NORMAL B
              JOIN RHFP0310 H
                ON H.COD_CONTRATO = B.COD_CONTRATO
               AND TRUNC(H.DATA_INICIO) <= TRUNC(B.DATA_RESCISAO)
               AND TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >= TRUNC(B.DATA_RESCISAO)
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
           TO_CHAR(B.DATA_PAGAMENTO, 'DD/MM/YYYY') AS data_pagamento,
           1 AS codigo_tabela_eventos,
           B.CODIGO_EVENTO AS codigo_evento,
           TO_CHAR(ROUND(NVL(B.REF_EVENTO, 0), 2), 'FM9999999990D00') AS referencia_evento,
           TO_CHAR(ROUND(NVL(B.VALOR_EVENTO, 0), 2), 'FM9999999990D00') AS valor_evento
      FROM BASE_NORMAL B
      JOIN CONTRATOS_OK OK
        ON OK.COD_CONTRATO = B.COD_CONTRATO
      JOIN ORG_REF O
        ON O.COD_CONTRATO = B.COD_CONTRATO
       AND O.DATA_RESCISAO = TRUNC(B.DATA_RESCISAO)
      JOIN RHFP0401 ORG
        ON ORG.COD_ORGANOGRAMA = O.COD_ORGANOGRAMA
     CROSS JOIN PARAM P
     WHERE B.DATA_PAGAMENTO IS NOT NULL
       AND TRUNC(B.DATA_PAGAMENTO) < P.DT_CORTE
       AND TRUNC(B.DATA_RESCISAO) < P.DT_CORTE
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
