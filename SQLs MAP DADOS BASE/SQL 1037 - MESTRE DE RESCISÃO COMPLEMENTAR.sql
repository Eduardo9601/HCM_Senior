/*=== SQL 1037 - MESTRE DE RESCISÃO COMPLEMENTAR  ===*/

WITH PARAM AS
 (SELECT DATE '2026-01-19' AS DT_CORTE FROM DUAL),

/* contratos que “existem” no cadastro importado (admitidos até o corte) */
CONTRATOS_OK AS
 (SELECT C.COD_CONTRATO
    FROM V_DADOS_CONTRATO_AVT C
   CROSS JOIN PARAM P
   GROUP BY C.COD_CONTRATO, P.DT_CORTE
  HAVING MIN(NVL(TRUNC(C.DATA_ADMISSAO), DATE '1900-01-01')) <= P.DT_CORTE
  
)

SELECT DISTINCT ORG.COD_NIVEL2 AS "codigo_empresa",
                1 AS "tipo_colaborador",
                A.COD_CONTRATO AS "cadastro_colaborador",
                TO_CHAR(C.DATA_PAGAMENTO, 'DD/MM/YYYY') AS "data_pagamento",
                0 AS "dias_aviso_indenizado",
                0 AS "dias_aviso_reavido",
                0 AS "dias_saldo_salarios",
                0 AS "dias_fim_contrato_antecipado",
                0 AS "salario_final_aviso",
                0 AS "saldo_anterior_fgts",
                NULL AS "homologacao_dissidio_coletivo",
                B.DESCRICAO_MOTIVO AS "motivo_complementar",
                0 AS "salario_base",
                0 AS "integrar_rescisao",
                CASE
                    WHEN B.DIAS_AV_TRAB <> 0 OR B.DIAS_AV_TRAB IS NOT NULL THEN 
                     1 
                    WHEN B.DIAS_AV_FUNC <> 0 OR B.DIAS_AV_FUNC IS NOT NULL THEN 
                     2
                    ELSE
                     3
                END AS "aviso_previo",
                0 AS "dias_aviso_indeniz_acres", -- dias_aviso_indenizado_acrescimo (é o nome real do campo)
                0 AS "dias_aviso_reavido_acrescimo",
                0 AS "termo_quitacao_trct"
  FROM RHFP0300 A
  JOIN RHFP0350 B
    ON B.COD_CONTRATO = A.COD_CONTRATO
  JOIN RHFP0351 C
    ON C.COD_CONTRATO = A.COD_CONTRATO
  JOIN CONTRATOS_OK OK ON OK.COD_CONTRATO = A.COD_CONTRATO
 OUTER APPLY (SELECT H.COD_ORGANOGRAMA
                FROM RHFP0310 H
               WHERE H.COD_CONTRATO = A.COD_CONTRATO
               ORDER BY NVL(H.DATA_FIM, DATE '9999-12-31') DESC,
                        H.DATA_INICIO DESC
               FETCH FIRST 1 ROW ONLY) HIST

  LEFT JOIN RHFP0401 ORG
    ON ORG.COD_ORGANOGRAMA = HIST.COD_ORGANOGRAMA

 WHERE ORG.COD_NIVEL2 IS NOT NULL
 AND A.COD_CONTRATO IN (SELECT COD_CONTRATO FROM CONTRATOS_OK)
 AND A.DATA_INICIO <= P.DT_CORTE  --DATA DE CORTE
 AND C.DATA_PAGAMENTO IS NOT NULL
 ORDER BY A.COD_CONTRATO;
 


