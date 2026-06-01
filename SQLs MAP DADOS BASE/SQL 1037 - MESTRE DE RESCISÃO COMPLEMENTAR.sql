/*=== SQL 1037 - MESTRE DE RESCISÃO COMPLEMENTAR ===*/
/* AJUSTE: SE A COMPLEMENTAR TIVER A MESMA DATA DA RESCISÃO NORMAL
   E A MESMA DATA DE PAGAMENTO DA NORMAL,
   SOMA +1 DIA NA DATA_COMPLEMENTO E NA DATA_PAGAMENTO */

/*=== 1037 - MESTRE DE RESCISÃO COMPLEMENTAR ===*/

WITH PARAM AS (
    SELECT DATE '2026-04-23' AS DT_CORTE
      FROM DUAL
),

CONTRATOS_OK AS (
    SELECT C.COD_CONTRATO
      FROM V_DADOS_CONTRATO_AVT C
     CROSS JOIN PARAM P
     GROUP BY C.COD_CONTRATO, P.DT_CORTE
    HAVING MIN(NVL(TRUNC(C.DATA_ADMISSAO), DATE '1900-01-01')) < P.DT_CORTE
),

/* Rescisão normal */
RESCISAO_NORMAL AS (
    SELECT B.COD_CONTRATO,
           TRUNC(B.DATA_RESCISAO)  AS DATA_RESCISAO_NORMAL,
           TRUNC(B.DATA_PAGAMENTO) AS DATA_PAGAMENTO_NORMAL,
           B.DESCRICAO_MOTIVO,
           B.DIAS_AV_TRAB,
           B.DIAS_AV_FUNC
      FROM RHFP0350 B
),

/* Rescisões complementares */
RESCISAO_COMP AS (
    SELECT C.COD_CONTRATO,
           TRUNC(C.DATA_RESCISAO)    AS DATA_RESCISAO_BASE,
           TRUNC(C.DATA_COMPLEMENTO) AS DATA_COMPLEMENTO,
           TRUNC(C.DATA_PAGAMENTO)   AS DATA_PAGAMENTO_COMP,
           C.ROWID                   AS RID_COMP
      FROM RHFP0351 C
),

/* Detecta somente os casos em que a complementar
   cai exatamente no mesmo dia da normal
   e também com o mesmo pagamento da normal */
COMP_CONFLITO AS (
    SELECT C.COD_CONTRATO,
           C.RID_COMP
      FROM RESCISAO_COMP C
      JOIN RESCISAO_NORMAL N
        ON N.COD_CONTRATO = C.COD_CONTRATO
       AND N.DATA_RESCISAO_NORMAL = C.DATA_COMPLEMENTO
       AND N.DATA_PAGAMENTO_NORMAL = C.DATA_PAGAMENTO_COMP
),

/* Ajusta datas só nos casos de conflito */
COMP_AJUSTADA AS (
    SELECT C.COD_CONTRATO,
           C.RID_COMP,
           C.DATA_RESCISAO_BASE,
           C.DATA_COMPLEMENTO,
           C.DATA_PAGAMENTO_COMP,
           CASE
               WHEN X.COD_CONTRATO IS NOT NULL THEN C.DATA_COMPLEMENTO + 1
               ELSE C.DATA_COMPLEMENTO
           END AS DATA_COMPLEMENTO_AJUSTADA,
           CASE
               WHEN X.COD_CONTRATO IS NOT NULL THEN C.DATA_PAGAMENTO_COMP + 1
               ELSE C.DATA_PAGAMENTO_COMP
           END AS DATA_PAGAMENTO_AJUSTADA
      FROM RESCISAO_COMP C
      LEFT JOIN COMP_CONFLITO X
        ON X.COD_CONTRATO = C.COD_CONTRATO
       AND X.RID_COMP = C.RID_COMP
),

/* Empresa vigente na data da complementar ajustada */
ORG_REF AS (
    SELECT COD_CONTRATO,
           RID_COMP,
           COD_ORGANOGRAMA
      FROM (
            SELECT C.COD_CONTRATO,
                   C.RID_COMP,
                   H.COD_ORGANOGRAMA,
                   ROW_NUMBER() OVER (
                       PARTITION BY C.COD_CONTRATO, C.RID_COMP
                       ORDER BY H.DATA_INICIO DESC,
                                NVL(H.DATA_FIM, DATE '9999-12-31') DESC
                   ) AS RN
              FROM COMP_AJUSTADA C
              JOIN RHFP0310 H
                ON H.COD_CONTRATO = C.COD_CONTRATO
               AND TRUNC(H.DATA_INICIO) <= C.DATA_COMPLEMENTO_AJUSTADA
               AND TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >= C.DATA_COMPLEMENTO_AJUSTADA
           )
     WHERE RN = 1
)

SELECT DISTINCT
       ORG.COD_NIVEL2 AS "codigo_empresa",
       1 AS "tipo_colaborador",
       C.COD_CONTRATO AS "cadastro_colaborador",
       TO_CHAR(C.DATA_PAGAMENTO_AJUSTADA, 'DD/MM/YYYY') AS "data_pagamento",
       0 AS "dias_aviso_indenizado",
       0 AS "dias_aviso_reavido",
       0 AS "dias_saldo_salarios",
       0 AS "dias_fim_contrato_antecipado",
       0 AS "salario_final_aviso",
       0 AS "saldo_anterior_fgts",
       NULL AS "homologacao_dissidio_coletivo",
       N.DESCRICAO_MOTIVO AS "motivo_complementar",
       0 AS "salario_base",
       0 AS "integrar_rescisao",
       CASE
           WHEN NVL(N.DIAS_AV_TRAB, 0) <> 0 THEN 1
           WHEN NVL(N.DIAS_AV_FUNC, 0) <> 0 THEN 2
           ELSE 3
       END AS "aviso_previo",
       0 AS "dias_aviso_indeniz_acres",
       0 AS "dias_aviso_reavido_acrescimo",
       0 AS "termo_quitacao_trct"
  FROM COMP_AJUSTADA C
  JOIN RESCISAO_NORMAL N
    ON N.COD_CONTRATO = C.COD_CONTRATO
  JOIN CONTRATOS_OK OK
    ON OK.COD_CONTRATO = C.COD_CONTRATO
  JOIN ORG_REF O
    ON O.COD_CONTRATO = C.COD_CONTRATO
   AND O.RID_COMP = C.RID_COMP
  JOIN RHFP0401 ORG
    ON ORG.COD_ORGANOGRAMA = O.COD_ORGANOGRAMA
 CROSS JOIN PARAM P
 WHERE ORG.COD_NIVEL2 IS NOT NULL
   AND C.DATA_PAGAMENTO_COMP IS NOT NULL
   AND C.DATA_PAGAMENTO_AJUSTADA < P.DT_CORTE
 --AND C.COD_CONTRATO = 366560
 --AND C.COD_CONTRATO = 366153
 ORDER BY C.COD_CONTRATO;