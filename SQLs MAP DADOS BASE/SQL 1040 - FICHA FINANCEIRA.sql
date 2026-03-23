/*=== SQL 1040 - FICHA FINANCEIRA ===*/

-- (EXPORTAÇÃO POR ANO) 



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

SELECT q."codigo_empresa",
       1 AS "tipo_colaborador",
       q."cadastro_colaborador",
       q."codigo_calculo",
       0 AS "tabela_evento",
       q."codigo_evento",
       q."referencia_evento",
       q."valor_evento",
       q."tipo_calculo",
       q."referencia",
       q."data_pagamento"
  FROM (SELECT DISTINCT org.cod_nivel2       AS "codigo_empresa",
                        a.cod_contrato       AS "cadastro_colaborador",
                        a1.cod_mestre_evento AS "codigo_calculo",
                        A.COD_VD AS "codigo_evento",
                        CASE
                          WHEN b.cod_evento = 1 THEN
                           11
                          WHEN b.cod_evento = 2 THEN
                           CASE
                             WHEN EXTRACT(DAY FROM a1.data_ini_mov) <= 15 THEN
                              41
                             ELSE
                              42
                           END
                          WHEN b.cod_evento = 3 THEN
                           21
                          WHEN b.cod_evento IN (4, 5) THEN
                           22
                          WHEN b.cod_evento = 7 THEN
                           23
                          WHEN b.cod_evento = 8 THEN
                           12
                          WHEN b.cod_evento = 9 THEN
                           92
                          WHEN b.cod_evento = 10 THEN
                           91
                          WHEN b.cod_evento = 12 THEN
                           31
                          WHEN b.cod_evento IN (11, 13) THEN
                           32
                          ELSE
                           93
                        END AS "tipo_calculo",
                        
                        '' AS "referencia_evento",
                        NVL(a.valor_vd, 0) AS "valor_evento",
                        
                        TO_CHAR(a1.data_referencia, 'MM/YYYY') AS "referencia",
                        TO_CHAR(a1.data_pagamento, 'DD/MM/YYYY') AS "data_pagamento",
                        
                        /* Técnicas para ordenação */
                        TRUNC(a1.data_referencia, 'MM') AS ord_mes,
                        TRUNC(a1.data_referencia) AS ord_ref,
                        TRUNC(a1.data_ini_mov) AS ord_ini
        
          FROM rhfp1006 a
          JOIN rhfp1003 a1
            ON a1.cod_mestre_evento = a.cod_mestre_evento
          JOIN rhfp1002 b
            ON b.cod_evento = a1.cod_evento
          JOIN CONTRATOS_OK OK ON OK.COD_CONTRATO = A.COD_CONTRATO
		  CROSS JOIN PARAM P
         OUTER APPLY (
                     /* ESCOLHE 1 ORGANOGRAMA “MELHOR” P/ A DATA_INI_MOV DO CÁLCULO */
                     SELECT h.cod_organograma
                       FROM (SELECT h.*,
                                     CASE
                                       WHEN TRUNC(h.data_inicio) <=
                                            TRUNC(a1.data_ini_mov) AND
                                            TRUNC(NVL(h.data_fim,
                                                      DATE '9999-12-31')) >=
                                            TRUNC(a1.data_ini_mov) THEN
                                        1
                                       WHEN TRUNC(h.data_inicio) <=
                                            TRUNC(a1.data_ini_mov) THEN
                                        2
                                       ELSE
                                        3
                                     END AS rk,
                                     CASE
                                       WHEN TRUNC(h.data_inicio) <=
                                            TRUNC(a1.data_ini_mov) AND
                                            TRUNC(NVL(h.data_fim,
                                                      DATE '9999-12-31')) >=
                                            TRUNC(a1.data_ini_mov) THEN
                                        0
                                       WHEN TRUNC(h.data_inicio) <=
                                            TRUNC(a1.data_ini_mov) THEN
                                        TRUNC(a1.data_ini_mov) -
                                        TRUNC(h.data_inicio)
                                       ELSE
                                        TRUNC(h.data_inicio) -
                                        TRUNC(a1.data_ini_mov)
                                     END AS dist
                                FROM rhfp0310 h
                               WHERE h.cod_contrato = a.cod_contrato) h
                      ORDER BY rk,
                                dist,
                                CASE
                                  WHEN rk IN (1, 2) THEN
                                   h.data_inicio
                                END DESC,
                                CASE
                                  WHEN rk = 3 THEN
                                   h.data_inicio
                                END ASC
                      FETCH FIRST 1 ROW ONLY) hist
        
          LEFT JOIN rhfp0401 org
            ON org.cod_organograma = hist.cod_organograma
        
         WHERE org.cod_nivel2 IS NOT NULL
           AND a1.cod_evento NOT IN (15, 17, 19)
              
              /* =========================================================
              EXPORTAÇÃO POR ANO (ajuste aqui o ano desejado)
              Exemplo abaixo: somente ano de 2024
              ========================================================= */
           AND a1.data_referencia >= DATE '2025-01-01'
           AND a1.data_referencia < DATE '2026-01-01'
		   AND A.COD_CONTRATO IN (SELECT COD_CONTRATO FROM CONTRATOS_OK)
		   --AND TRUNC(<data_do_registro>) <= P.DT_CORTE --CASO NECESSÁRIO
		) q
 ORDER BY q.ord_mes, q.ord_ref, q.ord_ini, q."codigo_calculo", q."codigo_evento";