/* ==== SQL 1040 - FICHA FINANCEIRA ====*/

/* == Versão Oficial ==*/

--ROTINA: GRZ_EXPORT_EVENTOS_ANO_CSV


SELECT q."codigo_empresa",
       1 AS "tipo_colaborador",
       q."cadastro_colaborador",
       q."codigo_calculo",
       1 AS "tabela_evento",
       q."codigo_evento",
       q."referencia_evento",
       q."valor_evento",
       q."codigo_rubrica",
       q."fator_rubrica",
       q."origem_evento"
  FROM (SELECT DISTINCT org.cod_nivel2 AS "codigo_empresa",
                        a.cod_contrato AS "cadastro_colaborador",
                        a1.cod_mestre_evento AS "codigo_calculo",
                        EV.COD_EVENTO AS "codigo_evento",                  
                        TO_CHAR(ROUND(NVL(a.QTDE_VD, 0), 2), 'FM9999999990D00') AS "referencia_evento",
                        TO_CHAR(ROUND(NVL(a.VALOR_VD, 0), 2), 'FM9999999990D00') AS "valor_evento",
                        null as "codigo_rubrica",
                        null as "fator_rubrica",
                        null as "origem_evento",
                        /*colunas removidas do arquivo por orientação da Sênior, mantidas por backp de precaução*/
                        /*CASE
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
                        TO_CHAR(a1.data_referencia, 'MM/YYYY') AS "referencia",
                        TO_CHAR(a1.data_pagamento, 'DD/MM/YYYY') AS "data_pagamento",*/
                        

                        /* Técnicas para ordenação */
                        TRUNC(a1.data_referencia, 'MM') AS ord_mes,
                        TRUNC(a1.data_referencia) AS ord_ref,
                        TRUNC(a1.data_ini_mov) AS ord_ini

          FROM rhfp1006 a
          JOIN rhfp1003 a1
            ON a1.cod_mestre_evento = a.cod_mestre_evento
          JOIN rhfp1002 b
            ON b.cod_evento = a1.cod_evento
          JOIN RHFP1000 C
            ON A.COD_VD = C.COD_VD

          JOIN TB_EVENTOS_VD EV
            ON A.COD_VD = EV.COD_VD

          JOIN (SELECT C.COD_CONTRATO
                FROM V_DADOS_CONTRATO_AVT C
               GROUP BY C.COD_CONTRATO
              HAVING MIN(NVL(TRUNC(C.DATA_ADMISSAO), DATE '1900-01-01')) < '01/05/2026') OK
            ON OK.COD_CONTRATO = A.COD_CONTRATO

         OUTER APPLY (
                     /* ESCOLHE 1 ORGANOGRAMA ¿MELHOR¿ P/ A DATA_INI_MOV DO CÁLCULO */
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
           AND a1.cod_evento NOT IN (15, 16, 17, 19, 21, 22, 23, 25, 26)
           AND C.TIPO_VD NOT IN ('B', 'O')

           -- Período (agora será anual pelo loop, mas o filtro segue igual)
           AND TRUNC(a1.data_referencia) BETWEEN TRUNC(pc_ini) AND TRUNC(pc_fim)) q

 ORDER BY q.ord_mes,
          q.ord_ref,
          q.ord_ini,
          q."codigo_calculo",
          q."codigo_evento";







/*=== SQL 1040 - FICHA FINANCEIRA - Versão Tratamento Transferidos de Empresa ===*/

-- Rotina: GRZ_EXPORT_EVENTOS_ANO_TRE_CSV

/*SELECT USADO PARA EXPORTAR OS ARQUIVOS PARTICIONADOS NA ROTINA: GRZ_EXPORT_EVENTOS_ANO_CSV*/


SELECT q."codigo_empresa",
       1 AS "tipo_colaborador",
       q."cadastro_colaborador",
       q."codigo_calculo",
       1 AS "tabela_evento",
       q."codigo_evento",
       q."referencia_evento",
       q."valor_evento",
       q."codigo_rubrica",
       q."fator_rubrica",
       q."origem_evento"
  FROM (
        WITH
        MAPA_BASE AS (
            SELECT DISTINCT
                   M.COD_CONTRATO,
                   M.EMPRESA_ORIGEM,
                   M.EMPRESA_DESTINO,
                   TRUNC(M.DATA_TRANSFERENCIA) AS DATA_TRANSFERENCIA
              FROM GRZ_MAPA_TRANSF_EMPRESA_V2 M
             WHERE M.EMPRESA_ORIGEM  IS NOT NULL
               AND M.EMPRESA_DESTINO IS NOT NULL
               AND M.EMPRESA_ORIGEM <> M.EMPRESA_DESTINO
        ),

        MAPA_STATS AS (
            SELECT X.COD_CONTRATO,
                   COUNT(*) AS QT_MOVIMENTOS,
                   COUNT(DISTINCT X.EMPRESA) AS QT_EMPRESAS
              FROM (
                    SELECT COD_CONTRATO, EMPRESA_ORIGEM  AS EMPRESA FROM MAPA_BASE
                    UNION
                    SELECT COD_CONTRATO, EMPRESA_DESTINO AS EMPRESA FROM MAPA_BASE
                   ) X
             GROUP BY X.COD_CONTRATO
        ),

        MOV_SEQ AS (
            SELECT MB.COD_CONTRATO,
                   MB.EMPRESA_ORIGEM,
                   MB.EMPRESA_DESTINO,
                   MB.DATA_TRANSFERENCIA,
                   ROW_NUMBER() OVER (
                       PARTITION BY MB.COD_CONTRATO
                       ORDER BY MB.DATA_TRANSFERENCIA,
                                MB.EMPRESA_ORIGEM,
                                MB.EMPRESA_DESTINO
                   ) AS RN
              FROM MAPA_BASE MB
        ),

        ULTIMA_TRANSF AS (
            SELECT COD_CONTRATO,
                   EMPRESA_ORIGEM,
                   EMPRESA_DESTINO,
                   DATA_TRANSFERENCIA
              FROM (
                    SELECT MS.*,
                           ROW_NUMBER() OVER (
                               PARTITION BY MS.COD_CONTRATO
                               ORDER BY MS.DATA_TRANSFERENCIA DESC,
                                        MS.RN DESC
                           ) AS RN_ULT
                      FROM MOV_SEQ MS
                   )
             WHERE RN_ULT = 1
        ),

        PARES_2_EMPRESAS AS (
            SELECT U.COD_CONTRATO,
                   U.EMPRESA_ORIGEM,
                   U.EMPRESA_DESTINO,
                   U.DATA_TRANSFERENCIA
              FROM ULTIMA_TRANSF U
              JOIN MAPA_STATS S
                ON S.COD_CONTRATO = U.COD_CONTRATO
             WHERE S.QT_EMPRESAS = 2
        ),

        PARES_IMEDIATOS_3MAIS AS (
            SELECT M.COD_CONTRATO,
                   M.EMPRESA_ORIGEM,
                   M.EMPRESA_DESTINO,
                   M.DATA_TRANSFERENCIA
              FROM MOV_SEQ M
              JOIN MAPA_STATS S
                ON S.COD_CONTRATO = M.COD_CONTRATO
             WHERE S.QT_EMPRESAS > 2
        ),

        EMPRESAS_ANTERIORES AS (
            SELECT DISTINCT
                   CUR.COD_CONTRATO,
                   CUR.RN              AS RN_ATUAL,
                   ANT.EMPRESA_ORIGEM  AS EMPRESA_ANTERIOR
              FROM MOV_SEQ CUR
              JOIN MOV_SEQ ANT
                ON ANT.COD_CONTRATO = CUR.COD_CONTRATO
               AND ANT.RN < CUR.RN
              JOIN MAPA_STATS S
                ON S.COD_CONTRATO = CUR.COD_CONTRATO
             WHERE S.QT_EMPRESAS > 2

            UNION

            SELECT DISTINCT
                   CUR.COD_CONTRATO,
                   CUR.RN               AS RN_ATUAL,
                   ANT.EMPRESA_DESTINO  AS EMPRESA_ANTERIOR
              FROM MOV_SEQ CUR
              JOIN MOV_SEQ ANT
                ON ANT.COD_CONTRATO = CUR.COD_CONTRATO
               AND ANT.RN < CUR.RN
              JOIN MAPA_STATS S
                ON S.COD_CONTRATO = CUR.COD_CONTRATO
             WHERE S.QT_EMPRESAS > 2
        ),

        PARES_ACUM_3MAIS AS (
            SELECT DISTINCT
                   CUR.COD_CONTRATO,
                   EA.EMPRESA_ANTERIOR AS EMPRESA_ORIGEM,
                   CUR.EMPRESA_DESTINO AS EMPRESA_DESTINO,
                   CUR.DATA_TRANSFERENCIA
              FROM MOV_SEQ CUR
              JOIN EMPRESAS_ANTERIORES EA
                ON EA.COD_CONTRATO = CUR.COD_CONTRATO
               AND EA.RN_ATUAL     = CUR.RN
              JOIN MAPA_STATS S
                ON S.COD_CONTRATO = CUR.COD_CONTRATO
             WHERE S.QT_EMPRESAS > 2
               AND EA.EMPRESA_ANTERIOR <> CUR.EMPRESA_DESTINO
        ),

        PARES_3MAIS_BRUTO AS (
            SELECT * FROM PARES_IMEDIATOS_3MAIS
            UNION ALL
            SELECT * FROM PARES_ACUM_3MAIS
        ),

        PARES_3MAIS AS (
            SELECT COD_CONTRATO,
                   EMPRESA_ORIGEM,
                   EMPRESA_DESTINO,
                   DATA_TRANSFERENCIA
              FROM (
                    SELECT P.*,
                           ROW_NUMBER() OVER (
                               PARTITION BY P.COD_CONTRATO,
                                            P.EMPRESA_ORIGEM,
                                            P.EMPRESA_DESTINO
                               ORDER BY P.DATA_TRANSFERENCIA DESC
                           ) AS RN_PAR
                      FROM PARES_3MAIS_BRUTO P
                   )
             WHERE RN_PAR = 1
        ),

        MAPA_FINAL AS (
            SELECT * FROM PARES_2_EMPRESAS
            UNION ALL
            SELECT * FROM PARES_3MAIS
        ),

        BASE_ORIGEM AS (
            SELECT DISTINCT
                   ORG.COD_NIVEL2 AS "codigo_empresa",
                   A.COD_CONTRATO AS "cadastro_colaborador",
                   A1.COD_MESTRE_EVENTO AS "codigo_calculo",
                   EV.COD_EVENTO AS "codigo_evento",
                   TO_CHAR(ROUND(NVL(A.QTDE_VD, 0), 2), 'FM9999999990D00') AS "referencia_evento",
                   TO_CHAR(ROUND(NVL(A.VALOR_VD, 0), 2), 'FM9999999990D00') AS "valor_evento",
                   NULL AS "codigo_rubrica",
                   NULL AS "fator_rubrica",
                   NULL AS "origem_evento",

                   TRUNC(A1.DATA_REFERENCIA, 'MM') AS ord_mes,
                   TRUNC(A1.DATA_REFERENCIA) AS ord_ref,
                   TRUNC(A1.DATA_INI_MOV) AS ord_ini,
                   NVL(A.VALOR_VD, 0) AS VALOR_NUM

              FROM RHFP1006 A
              JOIN RHFP1003 A1
                ON A1.COD_MESTRE_EVENTO = A.COD_MESTRE_EVENTO
              JOIN RHFP1002 B
                ON B.COD_EVENTO = A1.COD_EVENTO
              JOIN RHFP1000 C
                ON A.COD_VD = C.COD_VD
              JOIN TB_EVENTOS_VD EV
                ON A.COD_VD = EV.COD_VD
              JOIN (
                    SELECT C.COD_CONTRATO
                      FROM V_DADOS_CONTRATO_AVT C
                     GROUP BY C.COD_CONTRATO
                    HAVING MIN(NVL(TRUNC(C.DATA_ADMISSAO), DATE '1900-01-01')) < DATE '2026-05-01'
              ) OK
                ON OK.COD_CONTRATO = A.COD_CONTRATO

             OUTER APPLY (
                 SELECT H.COD_ORGANOGRAMA
                   FROM (
                         SELECT H.*,
                                CASE
                                  WHEN TRUNC(H.DATA_INICIO) <= TRUNC(A1.DATA_INI_MOV)
                                   AND TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >= TRUNC(A1.DATA_INI_MOV) THEN 1
                                  WHEN TRUNC(H.DATA_INICIO) <= TRUNC(A1.DATA_INI_MOV) THEN 2
                                  ELSE 3
                                END AS RK,
                                CASE
                                  WHEN TRUNC(H.DATA_INICIO) <= TRUNC(A1.DATA_INI_MOV)
                                   AND TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >= TRUNC(A1.DATA_INI_MOV) THEN 0
                                  WHEN TRUNC(H.DATA_INICIO) <= TRUNC(A1.DATA_INI_MOV) THEN TRUNC(A1.DATA_INI_MOV) - TRUNC(H.DATA_INICIO)
                                  ELSE TRUNC(H.DATA_INICIO) - TRUNC(A1.DATA_INI_MOV)
                                END AS DIST
                           FROM RHFP0310 H
                          WHERE H.COD_CONTRATO = A.COD_CONTRATO
                        ) H
                  ORDER BY RK,
                           DIST,
                           CASE WHEN RK IN (1, 2) THEN H.DATA_INICIO END DESC,
                           CASE WHEN RK = 3 THEN H.DATA_INICIO END ASC
                  FETCH FIRST 1 ROW ONLY
             ) HIST

              LEFT JOIN RHFP0401 ORG
                ON ORG.COD_ORGANOGRAMA = HIST.COD_ORGANOGRAMA

             WHERE ORG.COD_NIVEL2 IS NOT NULL
               AND A1.COD_EVENTO NOT IN (15, 16, 17, 19, 21, 22, 23, 25, 26)
               AND C.TIPO_VD NOT IN ('B', 'O')
               AND EXISTS (
                     SELECT 1
                       FROM MAPA_BASE MB
                      WHERE MB.COD_CONTRATO = A.COD_CONTRATO
               )
               AND TRUNC(A1.DATA_REFERENCIA) BETWEEN TRUNC(pc_ini) AND TRUNC(pc_fim)
        ),

        BASE_REPLICADA AS (
            SELECT
                   MF.EMPRESA_DESTINO AS "codigo_empresa",
                   BO."cadastro_colaborador",
                   BO."codigo_calculo",
                   BO."codigo_evento",
                   BO."referencia_evento",
                   BO."valor_evento",
                   BO."codigo_rubrica",
                   BO."fator_rubrica",
                   BO."origem_evento",
                   BO.ord_mes,
                   BO.ord_ref,
                   BO.ord_ini,
                   BO.VALOR_NUM,
                   ROW_NUMBER() OVER (
                       PARTITION BY
                           MF.EMPRESA_DESTINO,
                           BO."cadastro_colaborador",
                           BO."codigo_calculo",
                           BO."codigo_evento",
                           BO."referencia_evento",
                           BO."valor_evento"
                       ORDER BY
                           MF.DATA_TRANSFERENCIA DESC,
                           MF.EMPRESA_ORIGEM DESC
                   ) AS RN
              FROM BASE_ORIGEM BO
              JOIN MAPA_FINAL MF
                ON MF.COD_CONTRATO   = BO."cadastro_colaborador"
               AND MF.EMPRESA_ORIGEM = BO."codigo_empresa"
        )

        SELECT BR."codigo_empresa",
               BR."cadastro_colaborador",
               BR."codigo_calculo",
               BR."codigo_evento",
               BR."referencia_evento",
               BR."valor_evento",
               BR."codigo_rubrica",
               BR."fator_rubrica",
               BR."origem_evento",
               BR.ord_mes,
               BR.ord_ref,
               BR.ord_ini
          FROM BASE_REPLICADA BR
         WHERE BR.RN = 1
           AND BR.VALOR_NUM <> 0
       ) q
 ORDER BY q.ord_mes,
          q.ord_ref,
          q.ord_ini,
          q."codigo_calculo",
          q."codigo_evento";











/* == Versão Inicial Alternativa ==*/

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



