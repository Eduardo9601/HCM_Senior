/*=== 1030 - HISTÓRICO DE SALÁRIOS ===*/

/*VERSÃO DEFINITIVA*/

/*=== 1030 - HISTÓRICO DE SALÁRIOS (LOTE 1 - ATÉ DATA CORTE) ===*/

WITH PARAM AS (
  SELECT TO_DATE('19/01/2026', 'DD/MM/YYYY') AS DT_CORTE
  FROM DUAL
),

/* contratos que "existem" no cadastro importado (admitidos até o corte) */
CONTRATOS_OK AS (
  SELECT C.COD_CONTRATO
    FROM V_DADOS_CONTRATO_AVT C
    CROSS JOIN PARAM P
   GROUP BY C.COD_CONTRATO, P.DT_CORTE
  HAVING MIN(NVL(TRUNC(C.DATA_ADMISSAO), DATE '1900-01-01')) <= P.DT_CORTE
),

BASE AS (
  SELECT DISTINCT
         ORG.COD_NIVEL2 AS COD_EMPRESA,
         1 AS TIPO_COLABORADOR,
         SAL.COD_CONTRATO AS COD_CONTRATO,
         SAL.DATA_INICIO AS DT_ORDEM,
         TO_CHAR(SAL.DATA_INICIO, 'DD/MM/YYYY') AS DATA_ALTERACAO,

                           CASE
                  WHEN SAL.COD_MOTIVO = 27 THEN
                   2 -- PROMOÇÃO
                  WHEN SAL.COD_MOTIVO = 100 THEN
                   3 -- CONVERSÃO
                  WHEN SAL.COD_MOTIVO = 29 THEN
                   4 -- TRANSFERÊNCIA
                  WHEN SAL.COD_MOTIVO = 497 THEN
                   5 -- ENQUADRAMENTO
                  WHEN SAL.COD_MOTIVO = 107 THEN
                   7 -- DISSÍDIO COLETIVO
                  WHEN SAL.COD_MOTIVO = 103 THEN
                   8 -- ANTECIPAÇÃO DISSÍDIO
                  WHEN SAL.COD_MOTIVO = 28 THEN
                   9 -- EQUIPARAÇÃO SALARIAL
                  WHEN SAL.COD_MOTIVO = 122 THEN
                   10 -- ALTERAÇÃO DE CARGO
                
                  WHEN SAL.COD_MOTIVO IN (31, 565) THEN
                   12 -- ESPONTÂNEO
                
                  WHEN SAL.COD_MOTIVO = 480 THEN
                   13 -- REINTEGRAÇÃO
                  WHEN SAL.COD_MOTIVO = 108 THEN
                   15 -- ACERTO DE FUNÇÃO
                  WHEN SAL.COD_MOTIVO = 129 THEN
                   18 -- ALTERAÇÃO DE CARGA HORÁRIA
                  WHEN SAL.COD_MOTIVO = 111 THEN
                   20 -- ACERTO DE HORÁRIO
                  WHEN SAL.COD_MOTIVO = 496 THEN
                   21 -- REDUÇÃO DE CARGA HORÁRIA
                  WHEN SAL.COD_MOTIVO = 115 THEN
                   22 -- ACERTO GERAL
                  WHEN SAL.COD_MOTIVO = 139 THEN
                   23 -- ACERTO DE ADMISSÃO
                  WHEN SAL.COD_MOTIVO = 143 THEN
                   25 -- ANTECIPAÇÃO
                  WHEN SAL.COD_MOTIVO = 119 THEN
                   27 -- AUMENTO - SALÁRIO MÍNIMO
                  WHEN SAL.COD_MOTIVO = 126 THEN
                   28 -- AUMENTO - SAL. MÍNIMO REGIONAL
                  WHEN SAL.COD_MOTIVO = 457 THEN
                   29 -- PISO REGIONAL
                  WHEN SAL.COD_MOTIVO = 113 THEN
                   30 -- PISO SALARIAL - CONF. DISSÍDIO
                  WHEN SAL.COD_MOTIVO = 573 THEN
                   31 -- PROMOÇÃO SALARIAL
                  WHEN SAL.COD_MOTIVO = 486 THEN
                   32 -- REAJUSTE - CONFORME DISSÍDIO
                  WHEN SAL.COD_MOTIVO = 136 THEN
                   33 -- RECOMPOSIÇÃO SAL. CONF. DISS.
                  WHEN SAL.COD_MOTIVO = 44 THEN
                   34 -- REGISTRO DE ADMISSÃO
                  WHEN SAL.COD_MOTIVO = 152 THEN
                   35 -- TABELA GERAL
                  WHEN SAL.COD_MOTIVO = 120 THEN
                   36 -- TABELA APRENDIZ
                  WHEN SAL.COD_MOTIVO = 105 THEN
                   37 -- VALOR FIXADO EM ASSEMBLEIA
                  WHEN SAL.COD_MOTIVO = 33 THEN
                   39 -- ACORDO COLETIVO                
                  ELSE
                   999 -- OU 0 / SAL.COD_MOTIVO, COMO VOCÊ PREFERIR
                END AS CODIGO_MOTIVO_ALTERACAO,

         NVL(SAL.VALOR_SALARIO, 0) AS VALOR_SALARIO_ATUAL,

         CASE
           WHEN SAL.TIPO_SALARIO = 'M' THEN 1
           WHEN SAL.TIPO_SALARIO = 'H' THEN 2
           ELSE 1
         END AS TIPO_SALARIO,

         NVL(SAL.PERCENTUAL, 0) AS PERCENTUAL_REAJUSTE_CONCEDIDO

    FROM RHFP0608 SAL

   OUTER APPLY (
      SELECT H.COD_ORGANOGRAMA
        FROM (SELECT H.*,
                     CASE
                       WHEN TRUNC(H.DATA_INICIO) <= TRUNC(SAL.DATA_INICIO)
                        AND TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >= TRUNC(SAL.DATA_INICIO) THEN 1
                       WHEN TRUNC(H.DATA_INICIO) <= TRUNC(SAL.DATA_INICIO) THEN 2
                       ELSE 3
                     END AS RK,
                     CASE
                       WHEN TRUNC(H.DATA_INICIO) <= TRUNC(SAL.DATA_INICIO)
                        AND TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >= TRUNC(SAL.DATA_INICIO) THEN 0
                       WHEN TRUNC(H.DATA_INICIO) <= TRUNC(SAL.DATA_INICIO) THEN TRUNC(SAL.DATA_INICIO) - TRUNC(H.DATA_INICIO)
                       ELSE TRUNC(H.DATA_INICIO) - TRUNC(SAL.DATA_INICIO)
                     END AS DIST
                FROM RHFP0310 H
               WHERE H.COD_CONTRATO = SAL.COD_CONTRATO) H
       ORDER BY RK,
                DIST,
                CASE WHEN RK IN (1, 2) THEN H.DATA_INICIO END DESC,
                CASE WHEN RK = 3 THEN H.DATA_INICIO END ASC
       FETCH FIRST 1 ROW ONLY
   ) HIST

   LEFT JOIN RHFP0401 ORG
     ON ORG.COD_ORGANOGRAMA = HIST.COD_ORGANOGRAMA

   WHERE ORG.COD_NIVEL2 IS NOT NULL
     AND SAL.COD_CONTRATO IN (SELECT COD_CONTRATO FROM CONTRATOS_OK)
)

SELECT COD_EMPRESA      AS "codigo_empresa",
       TIPO_COLABORADOR AS "tipo_colaborador",
       COD_CONTRATO     AS "cadastro_colaborador",
       DATA_ALTERACAO   AS "data_alteracao",

       ROW_NUMBER() OVER(
         PARTITION BY COD_CONTRATO
         ORDER BY DT_ORDEM ASC,
                  NVL(VALOR_SALARIO_ATUAL, 0) ASC,
                  CODIGO_MOTIVO_ALTERACAO ASC
       ) AS "sequencia_alteracao",

       CODIGO_MOTIVO_ALTERACAO       AS "codigo_motivo_alteracao",
       VALOR_SALARIO_ATUAL           AS "valor_salario_atual",
       TIPO_SALARIO                  AS "tipo_salario",
       PERCENTUAL_REAJUSTE_CONCEDIDO AS "percentual_reajuste_concedido"
  FROM BASE
 ORDER BY COD_CONTRATO, DT_ORDEM;
