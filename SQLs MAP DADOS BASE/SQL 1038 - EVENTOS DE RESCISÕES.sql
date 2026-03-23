/*=== SQL 1038 - EVENTOS DE RESCISÕES ===*/


/*=== 1038 - EVENTOS DE RESCISÕES ===*/

WITH 
PARAM AS (
SELECT TO_DATE('19/01/2026', 'DD/MM/YYYY') AS DT_CORTE FROM DUAL
 
),
 
/* contratos “existentes” no lote importado (admissão <= corte) */
CONTRATOS_OK AS (
SELECT C.COD_CONTRATO
    FROM V_DADOS_CONTRATO_AVT C
   CROSS JOIN PARAM P
   GROUP BY C.COD_CONTRATO, P.DT_CORTE
  HAVING MIN(NVL(TRUNC(C.DATA_ADMISSAO), DATE '1900-01-01')) <= P.DT_CORTE

)

SELECT DISTINCT ORG.COD_NIVEL2 AS "codigo_empresa",
                1 AS "tipo_colaborador",
                A.COD_CONTRATO AS "cadastro_colaborador",
                TO_CHAR(A.DATA_PAGAMENTO, 'DD/MM/YYYY') AS "data_pagamento",
                1 AS "codigo_tabela_eventos",
                EV.COD_EVENTO AS "codigo_evento",
                0 AS "referencia_evento",
                NVL(D.VALOR_VD, 0) AS "valor_evento"
  FROM RHFP0350 A
/*LEFT JOIN RHFP0351 C
ON C.COD_CONTRATO = A.COD_CONTRATO*/
--AND C.COD_MESTRE_EVENTO IS NOT NULL

/* AQUI ESTÁ O PULO DO GATO: VD PELO MESTRE_EVENTO (NÃO PELO CONTRATO) */
  JOIN RHFP1006 D
    ON D.COD_CONTRATO = A.COD_CONTRATO

/* GARANTE QUE O MESTRE_EVENTO É DE RESCISÃO (EVITA PEGAR FOLHA NORMAL) */
  JOIN RHFP1003 E
    ON E.COD_MESTRE_EVENTO = D.COD_MESTRE_EVENTO
   AND E.COD_EVENTO IN (17, 19)
   
  JOIN RHFP1000 C
      ON D.COD_VD = C.COD_VD
   
  JOIN TB_EVENTOS_VD EV 
    ON D.COD_VD = EV.COD_VD

  JOIN CONTRATOS_OK OK
    ON OK.COD_CONTRATO = A.COD_CONTRATO
 CROSS JOIN PARAM P
 OUTER APPLY (
              /* ESCOLHE 1 ORGANOGRAMA “MELHOR” NA DATA DA REFERÊNCIA */
              SELECT H.COD_ORGANOGRAMA
                FROM (SELECT H.*,
                              CASE
                                WHEN TRUNC(H.DATA_INICIO) <=
                                     TRUNC(NVL(A.DATA_RESCISAO, A.DATA_PAGAMENTO)) AND
                                     TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >=
                                     TRUNC(NVL(A.DATA_RESCISAO, A.DATA_PAGAMENTO)) THEN
                                 1
                                WHEN TRUNC(H.DATA_INICIO) <=
                                     TRUNC(NVL(A.DATA_RESCISAO, A.DATA_PAGAMENTO)) THEN
                                 2
                                ELSE
                                 3
                              END AS RK,
                              CASE
                                WHEN TRUNC(H.DATA_INICIO) <=
                                     TRUNC(NVL(A.DATA_RESCISAO, A.DATA_PAGAMENTO)) AND
                                     TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >=
                                     TRUNC(NVL(A.DATA_RESCISAO, A.DATA_PAGAMENTO)) THEN
                                 0
                                WHEN TRUNC(H.DATA_INICIO) <=
                                     TRUNC(NVL(A.DATA_RESCISAO, A.DATA_PAGAMENTO)) THEN
                                 TRUNC(NVL(A.DATA_RESCISAO, A.DATA_PAGAMENTO)) -
                                 TRUNC(H.DATA_INICIO)
                                ELSE
                                 TRUNC(H.DATA_INICIO) -
                                 TRUNC(NVL(A.DATA_RESCISAO, A.DATA_PAGAMENTO))
                              END AS DIST
                         FROM RHFP0310 H
                        WHERE H.COD_CONTRATO = A.COD_CONTRATO) H
               ORDER BY RK,
                         DIST,
                         CASE
                           WHEN RK IN (1, 2) THEN
                            H.DATA_INICIO
                         END DESC,
                         CASE
                           WHEN RK = 3 THEN
                            H.DATA_INICIO
                         END ASC
               FETCH FIRST 1 ROW ONLY) HIST
  LEFT JOIN RHFP0401 ORG
    ON ORG.COD_ORGANOGRAMA = HIST.COD_ORGANOGRAMA

 WHERE ORG.COD_NIVEL2 IS NOT NULL
  
  AND TRUNC(A.DATA_PAGAMENTO) <= P.DT_CORTE
 ORDER BY A.COD_CONTRATO, TO_CHAR(A.DATA_PAGAMENTO, 'DD/MM/YYYY'), EV.COD_EVENTO;