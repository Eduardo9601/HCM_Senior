/*=== SQL 1026 - HISTÓRICO DE CATEGORIA SEFIP ===*/

/*VERSÃO DEFINITIVA*/



/*=== SQL 1026 - HISTÓRICO DE CATEGORIA SEFIP (COM DATA CORTE) ===*/

WITH
PARAM AS (
  SELECT DATE '2026-01-19' AS DT_CORTE
  FROM DUAL
),

/* contratos que "existem" no lote importado (admitidos até a data de corte) */
CONTRATOS_OK AS (
  SELECT A.COD_CONTRATO
    FROM RHFP0300 A
    CROSS JOIN PARAM P
   GROUP BY A.COD_CONTRATO, P.DT_CORTE
  HAVING MIN(TRUNC(NVL(A.DATA_INICIO, DATE '1900-01-01'))) <= P.DT_CORTE
),

linhas AS (
  /* 1) Histórico (primeiro registro + quando muda) */
  SELECT x.cod_contrato,
         x.data_historico     AS dt_alt,
         x.cod_categoria_trab AS categoria_sefip
    FROM (
          SELECT h.cod_contrato,
                 h.data_historico,
                 h.cod_categoria_trab,
                 LAG(h.cod_categoria_trab) OVER(
                   PARTITION BY h.cod_contrato
                   ORDER BY h.data_historico
                 ) AS categ_anterior
            FROM rhfp0301 h
            JOIN CONTRATOS_OK ok
              ON ok.cod_contrato = h.cod_contrato
         ) x
   WHERE x.categ_anterior IS NULL
      OR x.cod_categoria_trab <> x.categ_anterior

  UNION ALL

  /* 2) Atual (somente contratos SEM histórico) */
  SELECT a.cod_contrato,
         a.data_inicio        AS dt_alt,
         a.cod_categoria_trab AS categoria_sefip
    FROM rhfp0300 a
    JOIN CONTRATOS_OK ok
      ON ok.cod_contrato = a.cod_contrato
   WHERE NOT EXISTS (
         SELECT 1
           FROM rhfp0301 h
          WHERE h.cod_contrato = a.cod_contrato
   )
)

SELECT org.cod_nivel2 AS "codigo_empresa",
       1 AS "tipo_colaborador",
       l.cod_contrato AS "cadastro_colaborador",
       TO_CHAR(l.dt_alt, 'DD/MM/YYYY') AS "data_alteracao_categoria",
       l.categoria_sefip AS "categoria_sefip"
  FROM linhas l

/* escolhe o organograma “melhor” para a data do registro */
 OUTER APPLY (
    SELECT h.cod_organograma
      FROM (
            SELECT h.*,
                   CASE
                     WHEN TRUNC(h.data_inicio) <= TRUNC(l.dt_alt)
                      AND TRUNC(NVL(h.data_fim, DATE '9999-12-31')) >= TRUNC(l.dt_alt) THEN 1
                     WHEN TRUNC(h.data_inicio) <= TRUNC(l.dt_alt) THEN 2
                     ELSE 3
                   END AS rk,
                   CASE
                     WHEN TRUNC(h.data_inicio) <= TRUNC(l.dt_alt)
                      AND TRUNC(NVL(h.data_fim, DATE '9999-12-31')) >= TRUNC(l.dt_alt) THEN 0
                     WHEN TRUNC(h.data_inicio) <= TRUNC(l.dt_alt) THEN TRUNC(l.dt_alt) - TRUNC(h.data_inicio)
                     ELSE TRUNC(h.data_inicio) - TRUNC(l.dt_alt)
                   END AS dist
              FROM rhfp0310 h
             WHERE h.cod_contrato = l.cod_contrato
           ) h
     ORDER BY rk,
              dist,
              CASE WHEN rk IN (1, 2) THEN h.data_inicio END DESC,
              CASE WHEN rk = 3 THEN h.data_inicio END ASC
     FETCH FIRST 1 ROW ONLY
 ) hist

  LEFT JOIN rhfp0401 org
    ON org.cod_organograma = hist.cod_organograma

 WHERE org.cod_nivel2 IS NOT NULL
   AND l.dt_alt IS NOT NULL
   AND l.categoria_sefip IS NOT NULL
 ORDER BY l.cod_contrato, l.dt_alt;



 
 
 
 
 
