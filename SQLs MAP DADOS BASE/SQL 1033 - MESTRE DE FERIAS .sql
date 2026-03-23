/* ============================================
   == SQL 1033 - MESTRE DE FERIAS ==
   ============================================ */

/*VERSÃO DEFINITIVA*/

/* ==== SQL 1033 - MESTRE DE FERIAS (SEM SALARIO) - LOTE 1 (ATE CORTE) ==== */

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
),

fer AS (
    SELECT
        a.ROWID AS rid_ferias,
        a.cod_contrato,
        a.data_ferias,
        a.data_prevista_ferias,
        a.data_pagamento,
        NVL(a.dias_ferias_conced, 0) AS dias_ferias_conced,
        NVL(a.dias_abono_conced, 0) AS dias_abono_conced,
        TRUNC(NVL(a.data_ferias, a.data_prevista_ferias)) AS dt_ref_fer
    FROM rhfp0327 a
    /* 1) trava contrato (não deixa “contrato novo” passar) */
    JOIN CONTRATOS_OK ok
      ON ok.cod_contrato = a.cod_contrato
),

/* Escolhe 1 período (0328) por férias */
p_pick AS (
    SELECT
        f.rid_ferias,
        p.data_inicio_periodo,
        ROW_NUMBER() OVER (
            PARTITION BY f.rid_ferias
            ORDER BY
                CASE WHEN p.data_inicio_periodo <= f.dt_ref_fer THEN 0 ELSE 1 END,
                CASE WHEN p.data_inicio_periodo <= f.dt_ref_fer THEN p.data_inicio_periodo END DESC,
                CASE WHEN p.data_inicio_periodo >  f.dt_ref_fer THEN p.data_inicio_periodo END ASC
        ) AS rn
    FROM fer f
    LEFT JOIN rhfp0328 p
           ON p.cod_contrato = f.cod_contrato
          AND p.data_prevista_ferias = f.data_prevista_ferias
),

/* Monta a base final (ainda 1 linha por férias) */
fer2 AS (
    SELECT
        f.*,
        b.data_inicio_periodo,
        TRUNC(NVL(f.data_ferias, NVL(f.data_prevista_ferias, b.data_inicio_periodo))) AS dt_ref
    FROM fer f
    LEFT JOIN p_pick pk
           ON pk.rid_ferias = f.rid_ferias
          AND pk.rn = 1
    LEFT JOIN rhfp0325 b
           ON b.cod_contrato = f.cod_contrato
          AND b.data_inicio_periodo = pk.data_inicio_periodo
    CROSS JOIN PARAM P
    /* 2) trava pela data “real” que você já usa como referência final */
    WHERE TRUNC(NVL(f.data_ferias, NVL(f.data_prevista_ferias, b.data_inicio_periodo))) <= P.DT_CORTE
),

/* Escolhe 1 empresa (via 0310 -> 0401) por férias */
org_pick AS (
    SELECT
        f2.rid_ferias,
        org.cod_nivel2 AS codigo_empresa,
        ROW_NUMBER() OVER (
            PARTITION BY f2.rid_ferias
            ORDER BY
                CASE
                    WHEN h.data_inicio <= f2.dt_ref
                     AND NVL(h.data_fim, DATE '9999-12-31') >= f2.dt_ref THEN 1
                    WHEN h.data_inicio <= f2.dt_ref THEN 2
                    ELSE 3
                END,
                CASE
                    WHEN h.data_inicio <= f2.dt_ref
                     AND NVL(h.data_fim, DATE '9999-12-31') >= f2.dt_ref THEN 0
                    WHEN h.data_inicio <= f2.dt_ref THEN f2.dt_ref - h.data_inicio
                    ELSE h.data_inicio - f2.dt_ref
                END,
                CASE WHEN h.data_inicio <= f2.dt_ref THEN h.data_inicio END DESC,
                CASE WHEN h.data_inicio >  f2.dt_ref THEN h.data_inicio END ASC
        ) AS rn
    FROM fer2 f2
    LEFT JOIN rhfp0310 h
           ON h.cod_contrato = f2.cod_contrato
    LEFT JOIN rhfp0401 org
           ON org.cod_organograma = h.cod_organograma
)

SELECT
    op.codigo_empresa AS "codigo_empresa",
    1 AS "tipo_colaborador",
    f2.cod_contrato AS "cadastro_colaborador",
    TO_CHAR(f2.data_inicio_periodo, 'DD/MM/YYYY') AS "data_inicio_periodo_ferias",
    TO_CHAR(f2.data_ferias, 'DD/MM/YYYY') AS "data_inicio_ferias",
    'N' AS "tipo_ferias",
    'S' AS "opcao_13_salario",
    TO_CHAR(f2.data_pagamento, 'DD/MM/YYYY') AS "data_pagamento_recibo",
    f2.dias_ferias_conced AS "dias_ferias",
    f2.dias_abono_conced  AS "dias_abono",
    0 AS "salario_base"
FROM fer2 f2
LEFT JOIN org_pick op
       ON op.rid_ferias = f2.rid_ferias
      AND op.rn = 1
ORDER BY f2.cod_contrato, f2.dt_ref;




