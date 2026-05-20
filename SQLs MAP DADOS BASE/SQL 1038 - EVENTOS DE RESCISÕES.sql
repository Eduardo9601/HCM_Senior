/*=== SQL 1038 - EVENTOS DE RESCISÕES - NORMAIS ===*/
/* REGRA CORRETA:
   - TIPO 17 NÃO SOFRE REGRA DA COMPLEMENTAR
   - TIPO 19:
       1) se pagamento comp = pagamento normal -> +1 dia
       2) se pagamento comp nulo -> normal +1 dia
       3) se pagamento comp diferente -> mantém
   - NUNCA DUPLICAR REGISTRO FINAL IDÊNTICO
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

/*========================
  RESCISÃO NORMAL - ANTERIOR
========================*/
/*RESCISAO_NORMAL AS (
    SELECT A.COD_CONTRATO,
           A.DATA_RESCISAO,
           A.DATA_PAGAMENTO,
           C.DATA_PAGAMENTO,
           EV.COD_EVENTO,
           NVL(B.QTDE_VD,0 ) AS REF_EVENTO,
           NVL(B.VALOR_VD, 0) AS VALOR_EVENTO
    FROM RHFP0350 A
    JOIN RHFP1006 B
           ON A.COD_CONTRATO = B.COD_CONTRATO
    JOIN RHFP1003 C
           ON C.COD_MESTRE_EVENTO = B.COD_MESTRE_EVENTO
         -- AND C.DATA_PAGAMENTO = A.DATA_PAGAMENTO
    JOIN TB_EVENTOS_VD EV
      ON EV.COD_VD = B.COD_VD
    WHERE C.COD_EVENTO = 17
   -- AND A.COD_CONTRATO = 379371
    ORDER BY A.COD_CONTRATO
   
),*/

/* contratos que realmente têm rescisão normal cadastrada */
CONTRATOS_RESCISAO_NORMAL AS (
    SELECT DISTINCT
           A.COD_CONTRATO,
           A.DATA_RESCISAO,
           A.DATA_PAGAMENTO
    FROM RHFP0350 A
),

/* escolhe UM cálculo 17 por contrato que tenha rescisão na RHFP0350 */
MESTRE_17_POR_CONTRATO AS (
    SELECT B.COD_CONTRATO,
           MAX(B.COD_MESTRE_EVENTO) AS COD_MESTRE_EVENTO
    FROM RHFP1006 B
    JOIN RHFP1003 C
      ON C.COD_MESTRE_EVENTO = B.COD_MESTRE_EVENTO
    WHERE C.COD_EVENTO = 17
      AND EXISTS (
          SELECT 1
          FROM RHFP0350 A
          WHERE A.COD_CONTRATO = B.COD_CONTRATO
      )
    GROUP BY B.COD_CONTRATO
),

/*========================
  RESCISÃO NORMAL
========================*/
RESCISAO_NORMAL AS (
    SELECT R.COD_CONTRATO,
           R.DATA_RESCISAO,
           R.DATA_PAGAMENTO,
           EV.COD_EVENTO,
           NVL(B.QTDE_VD, 0) AS REF_EVENTO,
           NVL(B.VALOR_VD, 0) AS VALOR_EVENTO
    FROM CONTRATOS_RESCISAO_NORMAL R
    JOIN MESTRE_17_POR_CONTRATO M
      ON M.COD_CONTRATO = R.COD_CONTRATO
    JOIN RHFP1006 B
      ON B.COD_CONTRATO = M.COD_CONTRATO
     AND B.COD_MESTRE_EVENTO = M.COD_MESTRE_EVENTO
    JOIN TB_EVENTOS_VD EV
      ON EV.COD_VD = B.COD_VD
),

/*========================
  RESCISÃO COMPLEMENTAR
========================*/
RESCISAO_COMPLEMENTAR AS (
    SELECT A.COD_CONTRATO,
           A.DATA_RESCISAO AS DTA_RESCISAO_COMP,
           A.DATA_PAGAMENTO AS DTA_PAGAMENTO_COMP,
           EV.COD_EVENTO AS EVENTO_COMP,
           NVL(B.QTDE_VD,0 ) AS REF_EVENTO_COMP,
           NVL(B.VALOR_VD, 0) AS VALOR_EVENTO_COMP
    FROM RHFP0351 A
    LEFT JOIN RHFP1006 B
           ON A.COD_CONTRATO = B.COD_CONTRATO
    LEFT JOIN RHFP1003 C
           ON C.COD_MESTRE_EVENTO = B.COD_MESTRE_EVENTO
          --AND C.DATA_PAGAMENTO = A.DATA_PAGAMENTO
    JOIN TB_EVENTOS_VD EV
      ON EV.COD_VD = B.COD_VD
    WHERE C.COD_EVENTO = 19
   -- AND A.COD_CONTRATO = 379371--IN (388612, 388071, 382487, 375438)

),


/*===================================================
  TRATAMENTO DAS DATAS DE PAGAMENTOS DA COMPLEMENTAR
=====================================================*/

CONTRATOS_COMPLEMENTAR AS (
SELECT A.COD_CONTRATO,
       A.DATA_RESCISAO,
       A.DATA_AVISO_PREVIO,
       B.DATA_COMPLEMENTO,
       A.DATA_PAGAMENTO AS DATA_PGTO_NORMAL,
       CASE
           WHEN A.DATA_PAGAMENTO = B.DATA_PAGAMENTO THEN
             B.DATA_PAGAMENTO + 1
           WHEN B.DATA_PAGAMENTO IS NULL THEN
             A.DATA_PAGAMENTO + 1
           ELSE
             B.DATA_PAGAMENTO
       END AS DTA_PGTO_COMP
FROM RHFP0350 A
INNER JOIN RHFP0351 B
       ON A.COD_CONTRATO = B.COD_CONTRATO
--WHERE A.COD_CONTRATO = 379371

),

BASE_FINAL AS (
SELECT R.COD_CONTRATO,
       R.DATA_RESCISAO,
       R.DATA_PAGAMENTO,
       R.COD_EVENTO,
       R.REF_EVENTO,
       R.VALOR_EVENTO
FROM RESCISAO_NORMAL R

UNION ALL

SELECT A.COD_CONTRATO,
       A.DTA_RESCISAO_COMP AS DATA_RECISAO,
       B.DTA_PGTO_COMP AS DATA_PAGAMENTO,
       A.EVENTO_COMP AS COD_EVENTO,
       A.REF_EVENTO_COMP AS REF_EVENTO,
       A.VALOR_EVENTO_COMP AS VALOR_EVENTO
FROM RESCISAO_COMPLEMENTAR A
JOIN CONTRATOS_COMPLEMENTAR B 
  ON A.COD_CONTRATO = B.COD_CONTRATO

),


/*============================
  EMPRESA NA DATA DA RESCISÃO
==============================*/
ORG_REF AS (
    SELECT COD_CONTRATO,
           DATA_RESCISAO,
           COD_ORGANOGRAMA
    FROM (
        SELECT B.COD_CONTRATO,
               B.DATA_RESCISAO,
               H.COD_ORGANOGRAMA,
               ROW_NUMBER() OVER (
                   PARTITION BY B.COD_CONTRATO, TRUNC(B.DATA_RESCISAO)
                   ORDER BY H.DATA_INICIO DESC,
                            NVL(H.DATA_FIM, DATE '9999-12-31') DESC
               ) AS RN
        FROM BASE_FINAL B
        JOIN RHFP0310 H
          ON H.COD_CONTRATO = B.COD_CONTRATO
         AND TRUNC(H.DATA_INICIO) <= TRUNC(B.DATA_RESCISAO)
         AND TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >= TRUNC(B.DATA_RESCISAO)
    )
    WHERE RN = 1
),


/*========================
  RESULTADO BRUTO
========================*/
FINAL_BRUTO AS (
    SELECT
           ORG.COD_NIVEL2 AS codigo_empresa,
           1 AS tipo_colaborador,
           B.COD_CONTRATO AS cadastro_colaborador,
           TO_CHAR(B.DATA_PAGAMENTO, 'DD/MM/YYYY') AS data_pagamento,
           1 AS codigo_tabela_eventos,
           B.COD_EVENTO AS codigo_evento,
           TO_CHAR(ROUND(NVL(B.REF_EVENTO, 0), 2), 'FM9999999990D00') AS referencia_evento,
           TO_CHAR(ROUND(NVL(B.VALOR_EVENTO, 0), 2), 'FM9999999990D00') AS valor_evento
    FROM BASE_FINAL B
    JOIN CONTRATOS_OK OK
      ON OK.COD_CONTRATO = B.COD_CONTRATO
    JOIN ORG_REF O
      ON O.COD_CONTRATO = B.COD_CONTRATO
     AND TRUNC(O.DATA_RESCISAO) = TRUNC(B.DATA_RESCISAO)
    JOIN RHFP0401 ORG
      ON ORG.COD_ORGANOGRAMA = O.COD_ORGANOGRAMA
    CROSS JOIN PARAM P
    WHERE NVL(TRUNC(B.DATA_PAGAMENTO), DATE '1900-01-01') < P.DT_CORTE
),

/*========================
  REMOVE SÓ REGISTRO FINAL 100% IDÊNTICO
========================*/
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
               ORDER BY
                   F.codigo_evento
           ) AS RN
    FROM FINAL_BRUTO F
)

SELECT
       CODIGO_EMPRESA AS "codigo_empresa",
       TIPO_COLABORADOR AS "tipo_colaborador",
       CADASTRO_COLABORADOR AS "cadastro_colaborador",
       DATA_PAGAMENTO AS "data_pagamento",
       CODIGO_TABELA_EVENTOS AS "codigo_tabela_eventos",
       CODIGO_EVENTO AS "codigo_evento",
       REFERENCIA_EVENTO AS "referencia_evento",
       VALOR_EVENTO AS "valor_evento"
FROM FINAL_DEDUP
WHERE RN = 1
--AND CADASTRO_COLABORADOR = 366153
ORDER BY CADASTRO_COLABORADOR,
         DATA_PAGAMENTO,
         CODIGO_EVENTO,
         REFERENCIA_EVENTO,
         VALOR_EVENTO;    