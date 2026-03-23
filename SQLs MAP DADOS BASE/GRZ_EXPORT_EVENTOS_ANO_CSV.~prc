CREATE OR REPLACE PROCEDURE GRZ_EXPORT_EVENTOS_ANO_CSV (
    p_dt_ini   IN DATE,
    p_dt_fim   IN DATE,
    p_prefix   IN VARCHAR2 DEFAULT 'export_eventos'
) IS
    v_dir        CONSTANT VARCHAR2(4000) := '/mnt/nlgestao/nfe/HCM_1040';
    v_q_ini       DATE;
    v_q_fim       DATE;
    v_file        UTL_FILE.FILE_TYPE;
    v_filename    VARCHAR2(4000);

    v_header      VARCHAR2(4000) :=
      'codigo_empresa;tipo_colaborador;cadastro_colaborador;codigo_calculo;tabela_evento;codigo_evento;referencia_evento;valor_evento;tipo_calculo;referencia;data_pagamento';

    v_cnt         NUMBER;

    /* =========================
       Cursor principal (dados)
       ========================= */
    CURSOR c_dados (pc_ini DATE, pc_fim DATE) IS
SELECT q."codigo_empresa",
       1 AS "tipo_colaborador",
       q."cadastro_colaborador",
       q."codigo_calculo",
       1 AS "tabela_evento",
       q."codigo_evento",
       q."referencia_evento",
       q."valor_evento",
       q."tipo_calculo",
       q."referencia",
       q."data_pagamento"
  FROM (SELECT DISTINCT org.cod_nivel2 AS "codigo_empresa",
                        a.cod_contrato AS "cadastro_colaborador",
                        a1.cod_mestre_evento AS "codigo_calculo",
                        EV.COD_EVENTO AS "codigo_evento",
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

                        0 AS "referencia_evento",
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
          JOIN RHFP1000 C
            ON A.COD_VD = C.COD_VD

          JOIN TB_EVENTOS_VD EV
            ON A.COD_VD = EV.COD_VD

          JOIN (SELECT C.COD_CONTRATO
                FROM V_DADOS_CONTRATO_AVT C
               GROUP BY C.COD_CONTRATO
              HAVING MIN(NVL(TRUNC(C.DATA_ADMISSAO), DATE '1900-01-01')) <= '19/01/2026') OK
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

    /* ============================================
       Conta dados do período (não cria arquivo se 0)
       (mantive o nome original pra não mexer mais do que precisa)
       ============================================ */
    FUNCTION count_trimester(p_ini DATE, p_fim DATE) RETURN NUMBER IS
        v NUMBER;
    BEGIN
        SELECT COUNT(*)
          INTO v
          FROM (
                SELECT DISTINCT
                       ORG.COD_NIVEL2,
                       A.COD_CONTRATO,
                       A1.COD_MESTRE_EVENTO,
                       EV.COD_EVENTO,
                       A.VALOR_VD,
                       A1.DATA_REFERENCIA,
                       A1.DATA_PAGAMENTO,
                       A1.DATA_INI_MOV
                  FROM RHFP1006 A
                  JOIN RHFP1003 A1
                    ON A1.COD_MESTRE_EVENTO = A.COD_MESTRE_EVENTO
                  JOIN RHFP1002 B
                    ON B.COD_EVENTO = A1.COD_EVENTO
                  JOIN RHFP1000 C
                    ON A.COD_VD = C.COD_VD

                  JOIN TB_EVENTOS_VD EV
                    ON A.COD_VD = EV.COD_VD

                  JOIN (SELECT C.COD_CONTRATO
                        FROM V_DADOS_CONTRATO_AVT C
                       GROUP BY C.COD_CONTRATO
                      HAVING MIN(NVL(TRUNC(C.DATA_ADMISSAO), DATE '1900-01-01')) <= '19/01/2026') OK
                    ON OK.COD_CONTRATO = A.COD_CONTRATO
                 OUTER APPLY (
                     SELECT H.COD_ORGANOGRAMA
                       FROM (
                             SELECT H.*,
                                    CASE
                                      WHEN TRUNC(H.DATA_INICIO) <= TRUNC(A1.DATA_INI_MOV)
                                           AND TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >= TRUNC(A1.DATA_INI_MOV)
                                      THEN 1
                                      WHEN TRUNC(H.DATA_INICIO) <= TRUNC(A1.DATA_INI_MOV) THEN 2
                                      ELSE 3
                                    END AS RK,
                                    CASE
                                      WHEN TRUNC(H.DATA_INICIO) <= TRUNC(A1.DATA_INI_MOV)
                                           AND TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >= TRUNC(A1.DATA_INI_MOV)
                                      THEN 0
                                      WHEN TRUNC(H.DATA_INICIO) <= TRUNC(A1.DATA_INI_MOV)
                                      THEN TRUNC(A1.DATA_INI_MOV) - TRUNC(H.DATA_INICIO)
                                      ELSE TRUNC(H.DATA_INICIO) - TRUNC(A1.DATA_INI_MOV)
                                    END AS DIST
                               FROM RHFP0310 H
                              WHERE H.COD_CONTRATO = A.COD_CONTRATO
                            ) H
                      ORDER BY RK,
                               DIST,
                               CASE WHEN RK IN (1,2) THEN H.DATA_INICIO END DESC,
                               CASE WHEN RK = 3     THEN H.DATA_INICIO END ASC
                      FETCH FIRST 1 ROW ONLY
                 ) HIST
                  LEFT JOIN RHFP0401 ORG
                    ON ORG.COD_ORGANOGRAMA = HIST.COD_ORGANOGRAMA
                 WHERE ORG.COD_NIVEL2 IS NOT NULL
                   AND C.TIPO_VD NOT IN ('B', 'O')
                   AND A1.COD_EVENTO NOT IN (15, 16, 17, 19, 21, 22, 23, 25, 26)
                   AND TRUNC(A1.DATA_REFERENCIA) BETWEEN TRUNC(P_INI) AND TRUNC(P_FIM)
          );
        RETURN v;
    END;

    FUNCTION year_label(p_date DATE) RETURN VARCHAR2 IS
    BEGIN
        RETURN TO_CHAR(p_date,'YYYY');
    END;

BEGIN
    IF p_dt_ini IS NULL OR p_dt_fim IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001,'Datas inicial e final são obrigatórias.');
    END IF;

    IF TRUNC(p_dt_ini) > TRUNC(p_dt_fim) THEN
        RAISE_APPLICATION_ERROR(-20002,'p_dt_ini não pode ser maior que p_dt_fim.');
    END IF;

    -- início no começo do ano (quebra anual)
    v_q_ini := TRUNC(p_dt_ini,'YYYY');

    WHILE v_q_ini <= TRUNC(p_dt_fim) LOOP
        -- fim do ano ou p_dt_fim (o que vier primeiro)
        v_q_fim := LEAST(TRUNC(ADD_MONTHS(v_q_ini,12)) - 1, TRUNC(p_dt_fim));

        -- garante que o primeiro arquivo respeite a data inicial real informada
        IF v_q_ini < TRUNC(p_dt_ini) THEN
            v_q_ini := TRUNC(p_dt_ini);
        END IF;

        v_cnt := count_trimester(v_q_ini, v_q_fim);

        IF v_cnt > 0 THEN
            v_filename :=
                p_prefix || '_' ||
                year_label(v_q_ini) || '_' ||
                TO_CHAR(v_q_ini,'YYYYMMDD') || '_' ||
                TO_CHAR(v_q_fim,'YYYYMMDD') || '.csv';

            v_file := UTL_FILE.FOPEN(v_dir, v_filename, 'W', 32767);

            -- header fixo
            UTL_FILE.PUT_LINE(v_file, v_header);

            -- dados
            FOR r IN c_dados(v_q_ini, v_q_fim) LOOP
                UTL_FILE.PUT_LINE(
                    v_file,
                    NVL(r."codigo_empresa",'') || ';' ||
                    '1' || ';' ||
                    NVL(r."cadastro_colaborador",'') || ';' ||
                    NVL(r."codigo_calculo",'') || ';' ||
                    '0' || ';' ||
                    NVL(r."codigo_evento",'') || ';' ||
                    NVL(r."referencia_evento",'') || ';' ||
                    REPLACE(TO_CHAR(NVL(r."valor_evento",0), 'FM9999999990D00', 'NLS_NUMERIC_CHARACTERS=,.'), '.', ',') || ';' ||
                    NVL(r."tipo_calculo",'') || ';' ||
                    NVL(r."referencia",'') || ';' ||
                    NVL(r."data_pagamento",'')
                );
            END LOOP;

            UTL_FILE.FCLOSE(v_file);
        END IF;

        -- próximo ano
        v_q_ini := TRUNC(ADD_MONTHS(TRUNC(v_q_fim) + 1, 0), 'YYYY');
    END LOOP;

EXCEPTION
    WHEN OTHERS THEN
        BEGIN
            IF UTL_FILE.IS_OPEN(v_file) THEN
                UTL_FILE.FCLOSE(v_file);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
        RAISE;
END;
/
