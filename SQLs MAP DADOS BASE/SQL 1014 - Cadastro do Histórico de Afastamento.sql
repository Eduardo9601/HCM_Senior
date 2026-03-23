/* =================================================
   == 1014 - CADASTRO DO HISTÓRICO DE AFASTAMENTO ==
   ================================================= */

--VERSÃO DIRETA --EXPORTAÇÃO DIRETA DA CONSULTA PARA EXCEL E CONVERTIDA PARA CSV

/*VERSÃO DEFINITIVA*/

/*=== 1014 - AFASTAMENTOS ===*/

WITH
PARAM AS (
  SELECT DATE '2026-01-19' AS DT_CORTE FROM DUAL
),
/* contratos “existentes” no lote importado (admissão <= corte) */
CONTRATOS_OK AS (
  SELECT C.COD_CONTRATO
    FROM V_DADOS_CONTRATO_AVT C
   CROSS JOIN PARAM P
   GROUP BY C.COD_CONTRATO, P.DT_CORTE
  HAVING MIN(NVL(TRUNC(C.DATA_ADMISSAO), DATE '1900-01-01')) <= P.DT_CORTE
  
)

SELECT DISTINCT
       NVL(ORG.COD_NIVEL2, 0) AS "codigo_empresa",
       1 AS "tipo_colaborador",
       AF.COD_CONTRATO AS "cadastro_colaborador",
       TO_CHAR(AF.DATA_INICIO, 'DD/MM/YYYY') AS "data_afastamento",

       CASE
           WHEN AF.HORAS_AFASTAMENTO IS NOT NULL THEN
            AF.HORAS_AFASTAMENTO
           ELSE
            '0000'
       END AS "hora_afastamento",

       TO_CHAR(AF.DATA_FIM, 'DD/MM/YYYY') AS "data_termino_afastamento",
       '0000' AS "hora_termino_afastamento",
       TO_CHAR(AF.DATA_FIM_FRE, 'DD/MM/YYYY') AS "data_termino_previsto",
       NVL(CODS.HCM_COD, 0) AS "situacao_afastamento",
       0 AS "causa_demissao",
       0 AS "dias_justificados",
       NULL AS "observacao_afastamento",

       CASE
         WHEN AF.COD_CID_10 IS NULL THEN NULL
         ELSE SUBSTR(REGEXP_REPLACE(UPPER(TRIM(AF.COD_CID_10)), '[^A-Z0-9]', ''), 1, 4)
       END AS "classificacao_int_doencas",

       PS.NOME_PESSOA AS "nome_atendente",
       0 AS "orgao_classe",
       NULL AS "registro_conselho_profissional",
       NULL AS "uf_conselho_profissional",
       0 AS "motivo_afastamento"

  FROM RHFP0306 AF
  JOIN CONTRATOS_OK OK ON OK.COD_CONTRATO = AF.COD_CONTRATO
  CROSS JOIN PARAM P

  OUTER APPLY ( /* ESCOLHE 1 ORGANOGRAMA “MELHOR” P/ A DATA DO AFASTAMENTO */
      SELECT H.COD_ORGANOGRAMA
        FROM (SELECT H.*,
                     CASE
                       WHEN TRUNC(H.DATA_INICIO) <= TRUNC(AF.DATA_INICIO)
                        AND TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >= TRUNC(AF.DATA_INICIO) THEN 1
                       WHEN TRUNC(H.DATA_INICIO) <= TRUNC(AF.DATA_INICIO) THEN 2
                       ELSE 3
                     END AS RK,
                     CASE
                       WHEN TRUNC(H.DATA_INICIO) <= TRUNC(AF.DATA_INICIO)
                        AND TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >= TRUNC(AF.DATA_INICIO) THEN 0
                       WHEN TRUNC(H.DATA_INICIO) <= TRUNC(AF.DATA_INICIO) THEN TRUNC(AF.DATA_INICIO) - TRUNC(H.DATA_INICIO)
                       ELSE TRUNC(H.DATA_INICIO) - TRUNC(AF.DATA_INICIO)
                     END AS DIST
                FROM RHFP0310 H
               WHERE H.COD_CONTRATO = AF.COD_CONTRATO) H
       ORDER BY RK,
                DIST,
                CASE WHEN RK IN (1,2) THEN H.DATA_INICIO END DESC,
                CASE WHEN RK = 3 THEN H.DATA_INICIO END ASC
       FETCH FIRST 1 ROW ONLY
  ) HIST

  LEFT JOIN RHFP0401 ORG
    ON ORG.COD_ORGANOGRAMA = HIST.COD_ORGANOGRAMA

  LEFT JOIN PESSOA PS
    ON PS.COD_PESSOA = AF.COD_PESSOA

  LEFT JOIN GRZ_DEPARA_AFAST_TMP CODS
    ON CODS.DATASYS_COD = AF.COD_CAUSA_AFAST

 WHERE ORG.COD_NIVEL2 IS NOT NULL
 AND TRUNC(AF.DATA_INICIO) <= P.DT_CORTE
 ORDER BY AF.COD_CONTRATO, TO_CHAR(AF.DATA_INICIO, 'DD/MM/YYYY');






