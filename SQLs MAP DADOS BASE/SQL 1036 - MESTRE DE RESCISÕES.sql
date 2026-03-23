/*=== 1036 - MESTRE DE RESCISÕES ===*/

/*VERSÃO DEFINITIVA*/

WITH PARAM AS
 (SELECT DATE '2026-01-19' AS DT_CORTE FROM DUAL),

/* contratos que “existem” no cadastro importado (admitidos até o corte) */
CONTRATOS_OK AS
 (SELECT C.COD_CONTRATO
    FROM V_DADOS_CONTRATO_AVT C
   CROSS JOIN PARAM P
   GROUP BY C.COD_CONTRATO, P.DT_CORTE
  HAVING MIN(NVL(TRUNC(C.DATA_ADMISSAO), DATE '1900-01-01')) <= P.DT_CORTE)

SELECT DISTINCT ORG.COD_NIVEL2 AS "codigo_empresa",
                1 AS "tipo_colaborador",
                A.COD_CONTRATO AS "cadastro_colaborador",
                TO_CHAR(A.DATA_FIM, 'DD/MM/YYYY') AS "data_demissao",
                CASE
                  WHEN A.COD_CAUSA_DEMISSAO = 10 THEN
                   01
                  WHEN A.COD_CAUSA_DEMISSAO = 11 THEN
                   02
                  WHEN A.COD_CAUSA_DEMISSAO = 12 THEN
                   12
                  WHEN A.COD_CAUSA_DEMISSAO = 13 THEN
                   13
                  WHEN A.COD_CAUSA_DEMISSAO = 14 THEN
                   14
                  WHEN A.COD_CAUSA_DEMISSAO = 20 THEN
                   03
                  WHEN A.COD_CAUSA_DEMISSAO = 21 THEN
                   04
                  WHEN A.COD_CAUSA_DEMISSAO = 30 THEN
                   06
                  WHEN A.COD_CAUSA_DEMISSAO = 33 THEN
                   28
                  WHEN A.COD_CAUSA_DEMISSAO = 60 THEN
                   08
                  WHEN A.COD_CAUSA_DEMISSAO = 80 THEN
                   80
                  ELSE
                   00
                END AS "causa_demissao",
                TO_CHAR(B.DATA_AVISO_PREVIO, 'DD/MM/YYYY') AS "data_aviso_previo",
                TO_CHAR(B.DATA_PAGAMENTO, 'DD/MM/YYYY') AS "data_pagamento_rescisao",
                0 AS "dias_aviso_indenizado",
                ROUND(TO_NUMBER(REPLACE(NVL(NULLIF(TRIM(B.DIAS_AVISO_PREVIO),
                                                   ''),
                                            '0'),
                                        ',',
                                        '.'),
                                '999999D999',
                                'NLS_NUMERIC_CHARACTERS=.,')) AS "dias_aviso_reavido",
                0 AS "dias_saldo_salarios",
                0 AS "dias_fim_contrato_antecipado",
                0 AS "salario_final_aviso",
                0 AS "saldo_anterior_fgts",
                B.DESCRICAO_MOTIVO AS "comentario_rescisao",
                'N' AS "reposicao_vaga",
                0 AS "salario_base",
                CASE
                  WHEN B.DIAS_AV_TRAB <> 0 OR B.DIAS_AV_TRAB IS NOT NULL THEN
                   1
                  WHEN B.DIAS_AV_FUNC <> 0 OR B.DIAS_AV_FUNC IS NOT NULL THEN
                   2
                  ELSE
                   3
                END AS "aviso_previo",
                0 AS "cumpriu_jornada_semana",
                0 AS "sabado_compensado",
                0 AS "dias_aviso_indeniz_acres",
                0 AS "dias_aviso_reavido_acrescimo",
                0 AS "termo_quitacao_trct",
                SUBSTR(REGEXP_REPLACE(TO_CHAR(B.NRO_ATESTADO_OBITO),
                                      '[^0-9]',
                                      ''),
                       1,
                       30) AS "atestado_obito",
                B.NRO_PROC_TRAB AS "processo_trabalhista"
  FROM RHFP0300 A
  JOIN RHFP0350 B
    ON B.COD_CONTRATO = A.COD_CONTRATO
  LEFT JOIN RHFP0351 C
    ON C.COD_CONTRATO = A.COD_CONTRATO
 OUTER APPLY (SELECT H.COD_ORGANOGRAMA
                FROM RHFP0310 H
               WHERE H.COD_CONTRATO = A.COD_CONTRATO
               ORDER BY NVL(H.DATA_FIM, DATE '9999-12-31') DESC,
                        H.DATA_INICIO DESC
               FETCH FIRST 1 ROW ONLY) HIST
  LEFT JOIN RHFP0401 ORG
    ON ORG.COD_ORGANOGRAMA = HIST.COD_ORGANOGRAMA
 CROSS JOIN PARAM P
 WHERE ORG.COD_NIVEL2 IS NOT NULL
   AND A.COD_CONTRATO IN (SELECT COD_CONTRATO FROM CONTRATOS_OK)
   AND A.DATA_FIM IS NOT NULL
   AND TRUNC(A.DATA_FIM) <= P.DT_CORTE
 ORDER BY A.COD_CONTRATO, TO_CHAR(A.DATA_FIM, 'DD/MM/YYYY');
