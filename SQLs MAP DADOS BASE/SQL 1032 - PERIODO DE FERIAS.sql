/* ============================================
   == SQL 1032 - PERIODO DE FERIAS ==
   ============================================ */

/*VERSÃO DEFINITIVA*/


/*=== 1032 - PERÍODO DE FERIAS (LOTE 1 - ATE DATA CORTE) ===*/

WITH
PARAM AS (
  SELECT DATE '2026-01-19' AS DT_CORTE FROM DUAL
),

/* Contratos “existentes” no cadastro importado (admissão <= corte) */
CONTRATOS_OK AS (
  SELECT C.COD_CONTRATO
    FROM V_DADOS_CONTRATO_AVT C
   CROSS JOIN PARAM P
   GROUP BY C.COD_CONTRATO, P.DT_CORTE
  HAVING MIN(NVL(TRUNC(C.DATA_ADMISSAO), DATE '1900-01-01')) <= P.DT_CORTE
)

SELECT DISTINCT
       org.cod_nivel2 AS "codigo_empresa",
       1 AS "tipo_colaborador",
       a.cod_contrato AS "cadastro_colaborador",
       TO_CHAR(a.data_inicio_periodo, 'DD/MM/YYYY') AS "data_inicio_periodo",
       TO_CHAR(a.data_fim_periodo, 'DD/MM/YYYY') AS "data_fim_periodo",
       a.dias_periodo AS "dias_direito",
       NVL(c.total_faltas, 0) AS "dias_falta",
       b.dias_ferias_conced AS "dias_licenca_remunerada",
       b.dias_ferias_gozados AS "dias_afastamento",
       0 AS "dias_debito",
       0 AS "dias_servico_militar",
       NVL(c.dias_abono, 0) AS "dias_abono_pecuario",
       0 AS "dias_saldo",
       0 AS "avos_ferias",
       CASE
         WHEN b.tipo_ferias = 'R' THEN 2
         WHEN b.tipo_ferias = 'I' AND b.situacao_programacao = 1 THEN 0
         WHEN b.tipo_ferias = 'I' AND b.situacao_programacao = 2 THEN 1
         ELSE 0
       END AS "situacao_periodo"
  FROM rhfp0325 a
  JOIN rhfp0327 b
    ON b.cod_contrato = a.cod_contrato
  JOIN rhfp0328 c
    ON c.cod_contrato = b.cod_contrato
   AND c.data_prevista_ferias = b.data_prevista_ferias
   AND c.data_inicio_periodo = a.data_inicio_periodo

  OUTER APPLY (
    SELECT h.cod_organograma
      FROM (
        SELECT h.*,
               CASE
                 WHEN TRUNC(h.data_inicio) <= TRUNC(NVL(b.data_prevista_ferias, a.data_inicio_periodo))
                  AND TRUNC(NVL(h.data_fim, DATE '9999-12-31')) >= TRUNC(NVL(b.data_prevista_ferias, a.data_inicio_periodo))
                 THEN 1
                 WHEN TRUNC(h.data_inicio) <= TRUNC(NVL(b.data_prevista_ferias, a.data_inicio_periodo))
                 THEN 2
                 ELSE 3
               END AS rk,
               CASE
                 WHEN TRUNC(h.data_inicio) <= TRUNC(NVL(b.data_prevista_ferias, a.data_inicio_periodo))
                  AND TRUNC(NVL(h.data_fim, DATE '9999-12-31')) >= TRUNC(NVL(b.data_prevista_ferias, a.data_inicio_periodo))
                 THEN 0
                 WHEN TRUNC(h.data_inicio) <= TRUNC(NVL(b.data_prevista_ferias, a.data_inicio_periodo))
                 THEN TRUNC(NVL(b.data_prevista_ferias, a.data_inicio_periodo)) - TRUNC(h.data_inicio)
                 ELSE TRUNC(h.data_inicio) - TRUNC(NVL(b.data_prevista_ferias, a.data_inicio_periodo))
               END AS dist
          FROM rhfp0310 h
         WHERE h.cod_contrato = a.cod_contrato
      ) h
     ORDER BY rk,
              dist,
              CASE WHEN rk IN (1,2) THEN h.data_inicio END DESC,
              CASE WHEN rk = 3 THEN h.data_inicio END ASC
     FETCH FIRST 1 ROW ONLY
  ) hist

  LEFT JOIN rhfp0401 org
    ON org.cod_organograma = hist.cod_organograma

  CROSS JOIN PARAM P
 WHERE org.cod_nivel2 IS NOT NULL
   /* trava contrato */
   AND a.cod_contrato IN (SELECT cod_contrato FROM CONTRATOS_OK)
   /* trava pela data de referência do registro (mesma lógica que define empresa) */
   AND TRUNC(NVL(b.data_prevista_ferias, a.data_inicio_periodo)) <= P.DT_CORTE

 ORDER BY a.cod_contrato, TO_CHAR(a.data_inicio_periodo, 'DD/MM/YYYY');





