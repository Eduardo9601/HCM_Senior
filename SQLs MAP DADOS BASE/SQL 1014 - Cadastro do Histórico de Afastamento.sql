/* == 1014 - CADASTRO DO HISTÓRICO DE AFASTAMENTO ==
   ================================================= */

--VERSÃO DIRETA --EXPORTAÇÃO DIRETA DA CONSULTA PARA EXCEL E CONVERTIDA PARA CSV

/*VERSÃO DEFINITIVA - SEM TRATAMENTO DE TRASNFERÊNCIAS ENTRE EMPRESAS, MAPEAMENTO GERAL*/


WITH
PARAM AS (
  SELECT DATE '2026-04-23' AS DT_CORTE FROM DUAL
),

/* contratos “existentes” no lote importado (admissão <= corte) */
CONTRATOS_OK AS (
  SELECT C.COD_CONTRATO
    FROM V_DADOS_CONTRATO_AVT C
   CROSS JOIN PARAM P
   GROUP BY C.COD_CONTRATO, P.DT_CORTE
  HAVING MIN(NVL(TRUNC(C.DATA_ADMISSAO), DATE '1900-01-01')) < P.DT_CORTE
  
)


SELECT DISTINCT NVL(ORG.COD_NIVEL2, 0) AS "codigo_empresa",
                1 AS "tipo_colaborador",
                AF.COD_CONTRATO AS "cadastro_colaborador",
                TO_CHAR(AF.DATA_INICIO, 'DD/MM/YYYY') AS "data_afastamento",
                
                CASE
                  WHEN AF.HORAS_AFASTAMENTO IS NOT NULL THEN
                   AF.HORAS_AFASTAMENTO
                  ELSE
                   '0000'
                END AS "hora_afastamento",
                
                CASE
                    WHEN AF.DATA_FIM = '31/12/2999' THEN 
                      '31/12/1900'
                    ELSE
                      TO_CHAR(AF.DATA_FIM, 'DD/MM/YYYY') 
                END AS "data_termino_afastamento",
                
                '0000' AS "hora_termino_afastamento",
                CASE
                    WHEN AF.DATA_FIM_FRE = '31/12/2999' THEN 
                      '31/12/1900'
                    ELSE
                      TO_CHAR(AF.DATA_FIM_FRE, 'DD/MM/YYYY') 
                END AS "data_termino_previsto",
                
                CASE
                    WHEN AF.COD_CAUSA_AFAST = 1 THEN 
                      4
                    ELSE 
                      NVL(CODS.HCM_COD, 0)
                END AS "situacao_afastamento",
                
                0 AS "causa_demissao",
                0 AS "dias_justificados",
                NULL AS "observacao_afastamento",
                
                CASE
                  WHEN AF.COD_CID_10 IS NULL THEN
                   NULL
                  ELSE
                   SUBSTR(REGEXP_REPLACE(UPPER(TRIM(AF.COD_CID_10)),
                                         '[^A-Z0-9]',
                                         ''),
                          1,
                          4)
                END AS "classificacao_int_doencas", --classificacao_internacional_doencas
                
                PS.NOME_PESSOA AS "nome_atendente",
                0              AS "orgao_classe",
                NULL           AS "registro_conselho_profissional",
                NULL           AS "uf_conselho_profissional",
                0              AS "motivo_afastamento"

  FROM RHFP0306 AF
  JOIN CONTRATOS_OK OK
    ON OK.COD_CONTRATO = AF.COD_CONTRATO
 CROSS JOIN PARAM P
 
 OUTER APPLY (
    SELECT H.COD_ORGANOGRAMA
      FROM RHFP0310 H
     WHERE H.COD_CONTRATO = AF.COD_CONTRATO
       AND TRUNC(H.DATA_INICIO) <= TRUNC(AF.DATA_INICIO)
       AND TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >= TRUNC(AF.DATA_INICIO)
     ORDER BY H.DATA_INICIO DESC
     FETCH FIRST 1 ROW ONLY
) HIST

 /*OUTER APPLY ( \* ESCOLHE 1 ORGANOGRAMA “MELHOR” P/ A DATA DO AFASTAMENTO *\
              SELECT H.COD_ORGANOGRAMA
                FROM (SELECT H.*,
                              CASE
                                WHEN TRUNC(H.DATA_INICIO) <=
                                     TRUNC(AF.DATA_INICIO) AND
                                     TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >=
                                     TRUNC(AF.DATA_INICIO) THEN
                                 1
                                WHEN TRUNC(H.DATA_INICIO) <=
                                     TRUNC(AF.DATA_INICIO) THEN
                                 2
                                ELSE
                                 3
                              END AS RK,
                              CASE
                                WHEN TRUNC(H.DATA_INICIO) <=
                                     TRUNC(AF.DATA_INICIO) AND
                                     TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >=
                                     TRUNC(AF.DATA_INICIO) THEN
                                 0
                                WHEN TRUNC(H.DATA_INICIO) <=
                                     TRUNC(AF.DATA_INICIO) THEN
                                 TRUNC(AF.DATA_INICIO) - TRUNC(H.DATA_INICIO)
                                ELSE
                                 TRUNC(H.DATA_INICIO) - TRUNC(AF.DATA_INICIO)
                              END AS DIST
                         FROM RHFP0310 H
                        WHERE H.COD_CONTRATO = AF.COD_CONTRATO) H
               ORDER BY RK,
                         DIST,
                         CASE
                           WHEN RK IN (1, 2) THEN
                            H.DATA_INICIO
                         END DESC,
                         CASE
                           WHEN RK = 3 THEN
                            H.DATA_INICIO
                         END ASC
               FETCH FIRST 1 ROW ONLY) HIST*/

  LEFT JOIN RHFP0401 ORG
    ON ORG.COD_ORGANOGRAMA = HIST.COD_ORGANOGRAMA

  LEFT JOIN PESSOA PS
    ON PS.COD_PESSOA = AF.COD_PESSOA

  LEFT JOIN GRZ_DEPARA_AFAST_TMP CODS
    ON CODS.DATASYS_COD = AF.COD_CAUSA_AFAST
   AND CODS.DATASYS_COD <> 1

 WHERE ORG.COD_NIVEL2 IS NOT NULL
   AND TRUNC(AF.DATA_INICIO) < P.DT_CORTE
   --AND AF.COD_CONTRATO = 19
 ORDER BY AF.COD_CONTRATO, TO_CHAR(AF.DATA_INICIO, 'DD/MM/YYYY');





/*VERSÃO 2 - TRATAMENTO PARA APENAS OS CASOS COM TRANSFERÊNCIAS ENTRE EMPRESAS*/

/* == 1014 - CADASTRO DO HISTÓRICO DE AFASTAMENTO ==
   =================================================
   VERSÃO 2 - SOMENTE COLABORADORES COM TRANSFERÊNCIA ENTRE EMPRESAS

   REGRA:
   - 1 transferência: replica origem -> destino
   - vai e volta entre as mesmas 2 empresas: replica só da anterior -> atual (última transição)
   - 3 empresas ou mais: replica de forma acumulada
     Ex.: 4 -> 8 -> 6  ==>  4->8, 4->6, 8->6
*/

WITH
PARAM AS (
    SELECT DATE '2026-04-23' AS DT_CORTE
      FROM DUAL
),

/* contratos elegíveis do lote */
CONTRATOS_OK AS (
    SELECT C.COD_CONTRATO
      FROM V_DADOS_CONTRATO_AVT C
     CROSS JOIN PARAM P
     GROUP BY C.COD_CONTRATO, P.DT_CORTE
    HAVING MIN(NVL(TRUNC(C.DATA_ADMISSAO), DATE '1900-01-01')) < P.DT_CORTE
),

/* mapa bruto das transferências */
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

/* estatísticas por contrato */
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

/* movimentos em ordem cronológica */
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

/* última transição do contrato
   usada para:
   - contratos com apenas 1 transferência
   - vai e volta entre as mesmas 2 empresas */
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

/* pares para contratos com somente 2 empresas distintas:
   sempre fica só a última transição (cobre tanto simples quanto vai-e-volta) */
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

/* pares imediatos dos contratos com 3+ empresas
   Ex.: 4->8 e 8->6 */
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

/* empresas já vistas antes de cada etapa atual */
EMPRESAS_ANTERIORES AS (
    SELECT DISTINCT
           CUR.COD_CONTRATO,
           CUR.RN                         AS RN_ATUAL,
           ANT.EMPRESA_ORIGEM            AS EMPRESA_ANTERIOR
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
           CUR.RN                         AS RN_ATUAL,
           ANT.EMPRESA_DESTINO           AS EMPRESA_ANTERIOR
      FROM MOV_SEQ CUR
      JOIN MOV_SEQ ANT
        ON ANT.COD_CONTRATO = CUR.COD_CONTRATO
       AND ANT.RN < CUR.RN
      JOIN MAPA_STATS S
        ON S.COD_CONTRATO = CUR.COD_CONTRATO
     WHERE S.QT_EMPRESAS > 2
),

/* pares acumulados:
   para cada destino atual, herda também todas as empresas anteriores
   Ex.: 4->8->6  => quando chega na 6, gera 4->6 e 8->6 */
PARES_ACUM_3MAIS AS (
    SELECT DISTINCT
           CUR.COD_CONTRATO,
           EA.EMPRESA_ANTERIOR          AS EMPRESA_ORIGEM,
           CUR.EMPRESA_DESTINO          AS EMPRESA_DESTINO,
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

/* junta pares imediatos + acumulados dos contratos com 3+ empresas */
PARES_3MAIS_BRUTO AS (
    SELECT * FROM PARES_IMEDIATOS_3MAIS
    UNION ALL
    SELECT * FROM PARES_ACUM_3MAIS
),

/* remove pares repetidos dos contratos com 3+ empresas,
   mantendo a ocorrência mais recente do par origem->destino */
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

/* mapa final de replicação */
MAPA_FINAL AS (
    SELECT * FROM PARES_2_EMPRESAS
    UNION ALL
    SELECT * FROM PARES_3MAIS
),

/* base dos eventos de afastamento,
   identificando a empresa real do evento na data */
BASE_EVENTO AS (
    SELECT
           AF.COD_CONTRATO,
           AF.DATA_INICIO,
           AF.HORAS_AFASTAMENTO,
           AF.DATA_FIM,
           AF.DATA_FIM_FRE,
           AF.COD_CAUSA_AFAST,
           AF.COD_CID_10,
           AF.COD_PESSOA,
           ORG.COD_NIVEL2 AS EMPRESA_EVENTO
      FROM RHFP0306 AF
      JOIN CONTRATOS_OK OK
        ON OK.COD_CONTRATO = AF.COD_CONTRATO
     CROSS JOIN PARAM P

      OUTER APPLY (
          SELECT H.COD_ORGANOGRAMA
            FROM RHFP0310 H
           WHERE H.COD_CONTRATO = AF.COD_CONTRATO
             AND TRUNC(H.DATA_INICIO) <= TRUNC(AF.DATA_INICIO)
             AND TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >= TRUNC(AF.DATA_INICIO)
           ORDER BY H.DATA_INICIO DESC
           FETCH FIRST 1 ROW ONLY
      ) HIST

      LEFT JOIN RHFP0401 ORG
        ON ORG.COD_ORGANOGRAMA = HIST.COD_ORGANOGRAMA

     WHERE ORG.COD_NIVEL2 IS NOT NULL
       AND TRUNC(AF.DATA_INICIO) < P.DT_CORTE
),

/* replica os eventos da empresa de origem para a empresa destino do mapa */
BASE_REPLICADA AS (
    SELECT
           MF.EMPRESA_DESTINO                              AS codigo_empresa,
           1                                               AS tipo_colaborador,
           BE.COD_CONTRATO                                 AS cadastro_colaborador,
           TO_CHAR(BE.DATA_INICIO, 'DD/MM/YYYY')           AS data_afastamento,

           CASE
             WHEN BE.HORAS_AFASTAMENTO IS NOT NULL THEN BE.HORAS_AFASTAMENTO
             ELSE '0000'
           END                                             AS hora_afastamento,

           CASE
             WHEN BE.DATA_FIM = DATE '2999-12-31' THEN '31/12/1900'
             ELSE TO_CHAR(BE.DATA_FIM, 'DD/MM/YYYY')
           END                                             AS data_termino_afastamento,

           '0000'                                          AS hora_termino_afastamento,

           CASE
             WHEN BE.DATA_FIM_FRE = DATE '2999-12-31' THEN '31/12/1900'
             ELSE TO_CHAR(BE.DATA_FIM_FRE, 'DD/MM/YYYY')
           END                                             AS data_termino_previsto,

           CASE
             WHEN BE.COD_CAUSA_AFAST = 1 THEN 4
             ELSE NVL(CODS.HCM_COD, 0)
           END                                             AS situacao_afastamento,

           0                                               AS causa_demissao,
           0                                               AS dias_justificados,
           NULL                                            AS observacao_afastamento,

           CASE
             WHEN BE.COD_CID_10 IS NULL THEN NULL
             ELSE SUBSTR(
                    REGEXP_REPLACE(UPPER(TRIM(BE.COD_CID_10)), '[^A-Z0-9]', ''),
                    1,
                    4
                  )
           END                                             AS classificacao_int_doencas,

           PS.NOME_PESSOA                                  AS nome_atendente,
           0                                               AS orgao_classe,
           NULL                                            AS registro_conselho_profissional,
           NULL                                            AS uf_conselho_profissional,
           0                                               AS motivo_afastamento,

           /* trava anti-duplicação */
           ROW_NUMBER() OVER (
               PARTITION BY MF.EMPRESA_DESTINO,
                            BE.COD_CONTRATO,
                            TRUNC(BE.DATA_INICIO),
                            NVL(TRUNC(BE.DATA_FIM), DATE '1900-01-01'),
                            NVL(TRUNC(BE.DATA_FIM_FRE), DATE '1900-01-01'),
                            NVL(BE.HORAS_AFASTAMENTO, '0000'),
                            NVL(BE.COD_CAUSA_AFAST, -1),
                            NVL(BE.COD_CID_10, '###')
               ORDER BY MF.DATA_TRANSFERENCIA DESC,
                        MF.EMPRESA_ORIGEM
           ) AS RN_UNICO

      FROM BASE_EVENTO BE
      JOIN MAPA_FINAL MF
        ON MF.COD_CONTRATO   = BE.COD_CONTRATO
       AND MF.EMPRESA_ORIGEM = BE.EMPRESA_EVENTO

      LEFT JOIN PESSOA PS
        ON PS.COD_PESSOA = BE.COD_PESSOA

      LEFT JOIN GRZ_DEPARA_AFAST_TMP CODS
        ON CODS.DATASYS_COD = BE.COD_CAUSA_AFAST
       AND CODS.DATASYS_COD <> 1
)

SELECT
       codigo_empresa                         AS "codigo_empresa",
       tipo_colaborador                       AS "tipo_colaborador",
       cadastro_colaborador                   AS "cadastro_colaborador",
       data_afastamento                       AS "data_afastamento",
       hora_afastamento                       AS "hora_afastamento",
       data_termino_afastamento               AS "data_termino_afastamento",
       hora_termino_afastamento               AS "hora_termino_afastamento",
       data_termino_previsto                  AS "data_termino_previsto",
       situacao_afastamento                   AS "situacao_afastamento",
       causa_demissao                         AS "causa_demissao",
       dias_justificados                      AS "dias_justificados",
       observacao_afastamento                 AS "observacao_afastamento",
       classificacao_int_doencas              AS "classificacao_int_doencas",
       nome_atendente                         AS "nome_atendente",
       orgao_classe                           AS "orgao_classe",
       registro_conselho_profissional         AS "registro_conselho_profissional",
       uf_conselho_profissional               AS "uf_conselho_profissional",
       motivo_afastamento                     AS "motivo_afastamento"
  FROM BASE_REPLICADA
 WHERE RN_UNICO = 1
 ORDER BY cadastro_colaborador,
          TO_DATE(data_afastamento, 'DD/MM/YYYY'),
          codigo_empresa;



/*VERSÃO 2.1 - TRATAMENTO PARA APENAS OS CASOS COM TRANSFERÊNCIAS ENTRE EMPRESAS*/

/*=== 1014 - AFASTAMENTOS - VERSÃO 2 TRANSFERIDOS ENTRE EMPRESAS ===*/

WITH
PARAM AS (
  SELECT DATE '2026-04-23' AS DT_CORTE FROM DUAL
),

CONTRATOS_OK AS (
  SELECT C.COD_CONTRATO
    FROM V_DADOS_CONTRATO_AVT C
   CROSS JOIN PARAM P
   GROUP BY C.COD_CONTRATO, P.DT_CORTE
  HAVING MIN(NVL(TRUNC(C.DATA_ADMISSAO), DATE '1900-01-01')) < P.DT_CORTE
),

HIST_EMPRESA AS (
  SELECT
      H.COD_CONTRATO,
      H.COD_ORGANOGRAMA,
      H.DATA_INICIO,
      H.DATA_FIM,
      H.SEQ,
      ORG.COD_NIVEL2 AS COD_EMPRESA,
      ORG.COD_NIVEL3 AS COD_UNIDADE
  FROM RHFP0310 H
  JOIN RHFP0401 ORG
    ON ORG.COD_ORGANOGRAMA = H.COD_ORGANOGRAMA
),

CONTRATOS_TRANSFERIDOS AS (
  SELECT COD_CONTRATO
  FROM HIST_EMPRESA
  GROUP BY COD_CONTRATO
  HAVING COUNT(DISTINCT COD_EMPRESA) > 1
),

AF_BASE AS (
  SELECT
      AF.*,
      ORIG.COD_ORGANOGRAMA AS COD_ORGANOGRAMA_ORIGEM,
      ORIG.COD_EMPRESA     AS COD_EMPRESA_ORIGEM,
      ORIG.COD_UNIDADE     AS COD_UNIDADE_ORIGEM
  FROM RHFP0306 AF
  JOIN CONTRATOS_OK OK
    ON OK.COD_CONTRATO = AF.COD_CONTRATO
  JOIN CONTRATOS_TRANSFERIDOS CT
    ON CT.COD_CONTRATO = AF.COD_CONTRATO
  CROSS JOIN PARAM P

  OUTER APPLY (
      SELECT H.COD_ORGANOGRAMA,
             H.COD_EMPRESA,
             H.COD_UNIDADE,
             H.DATA_INICIO,
             H.DATA_FIM
        FROM HIST_EMPRESA H
       WHERE H.COD_CONTRATO = AF.COD_CONTRATO
         AND TRUNC(H.DATA_INICIO) <= TRUNC(AF.DATA_INICIO)
         AND TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >= TRUNC(AF.DATA_INICIO)
       ORDER BY H.DATA_INICIO DESC, H.SEQ DESC
       FETCH FIRST 1 ROW ONLY
  ) ORIG

  WHERE TRUNC(AF.DATA_INICIO) < P.DT_CORTE
    AND ORIG.COD_EMPRESA IS NOT NULL
    --AND AF.COD_CONTRATO = 352683
),

DESTINO_AF AS (
  SELECT
      B.COD_CONTRATO,
      B.DATA_INICIO AS DATA_AFASTAMENTO,
      DEST.COD_ORGANOGRAMA AS COD_ORGANOGRAMA_DESTINO,
      DEST.COD_EMPRESA     AS COD_EMPRESA_DESTINO,
      DEST.COD_UNIDADE     AS COD_UNIDADE_DESTINO
  FROM AF_BASE B

  OUTER APPLY (
      SELECT H.COD_ORGANOGRAMA,
             H.COD_EMPRESA,
             H.COD_UNIDADE,
             H.DATA_INICIO
        FROM HIST_EMPRESA H
       WHERE H.COD_CONTRATO = B.COD_CONTRATO
         AND H.COD_EMPRESA <> B.COD_EMPRESA_ORIGEM
         AND TRUNC(H.DATA_INICIO) > TRUNC(B.DATA_INICIO)
       ORDER BY H.DATA_INICIO ASC
       FETCH FIRST 1 ROW ONLY
  ) DEST

  WHERE DEST.COD_EMPRESA IS NOT NULL
),

LINHAS AS (
  /* LINHA 1 - ORIGEM */
  SELECT
      'ORIGEM' AS TIPO_LINHA,
      B.COD_EMPRESA_ORIGEM AS COD_EMPRESA,
      B.COD_UNIDADE_ORIGEM AS COD_UNIDADE,
      B.*
  FROM AF_BASE B

  UNION ALL

  /* LINHA 2 - DESTINO */
  SELECT
      'DESTINO' AS TIPO_LINHA,
      D.COD_EMPRESA_DESTINO AS COD_EMPRESA,
      D.COD_UNIDADE_DESTINO AS COD_UNIDADE,
      B.*
  FROM AF_BASE B
  JOIN DESTINO_AF D
    ON D.COD_CONTRATO = B.COD_CONTRATO
   AND D.DATA_AFASTAMENTO = B.DATA_INICIO
)

SELECT DISTINCT
       NVL(L.COD_EMPRESA, 0) AS "codigo_empresa",
       1 AS "tipo_colaborador",
       L.COD_CONTRATO AS "cadastro_colaborador",

       TO_CHAR(L.DATA_INICIO, 'DD/MM/YYYY') AS "data_afastamento",

       CASE
         WHEN L.HORAS_AFASTAMENTO IS NOT NULL THEN L.HORAS_AFASTAMENTO
         ELSE '0000'
       END AS "hora_afastamento",

       CASE
         WHEN TRUNC(L.DATA_FIM) = DATE '2999-12-31' THEN '31/12/1900'
         ELSE TO_CHAR(L.DATA_FIM, 'DD/MM/YYYY')
       END AS "data_termino_afastamento",

       '0000' AS "hora_termino_afastamento",

       CASE
         WHEN TRUNC(L.DATA_FIM_FRE) = DATE '2999-12-31' THEN '31/12/1900'
         ELSE TO_CHAR(L.DATA_FIM_FRE, 'DD/MM/YYYY')
       END AS "data_termino_previsto",

       CASE
          WHEN L.TIPO_LINHA = 'ORIGEM' THEN 7
          WHEN L.COD_CAUSA_AFAST = 1 THEN 4
          ELSE NVL(CODS.HCM_COD, 0)
       END AS "situacao_afastamento",

       0 AS "causa_demissao",
       0 AS "dias_justificados",
       NULL AS "observacao_afastamento",

       CASE
         WHEN L.COD_CID_10 IS NULL THEN NULL
         ELSE SUBSTR(
                REGEXP_REPLACE(UPPER(TRIM(L.COD_CID_10)), '[^A-Z0-9]', ''),
                1,
                4
              )
       END AS "classificacao_int_doencas", --classificacao_internacional_doencas

       PS.NOME_PESSOA AS "nome_atendente",
       0              AS "orgao_classe",
       NULL           AS "registro_conselho_profissional",
       NULL           AS "uf_conselho_profissional",
       0              AS "motivo_afastamento"

FROM LINHAS L

LEFT JOIN PESSOA PS
  ON PS.COD_PESSOA = L.COD_PESSOA
LEFT JOIN GRZ_DEPARA_AFAST_TMP CODS
  ON CODS.DATASYS_COD = L.COD_CAUSA_AFAST
 AND CODS.DATASYS_COD <> 1

ORDER BY
    "cadastro_colaborador",
    "data_afastamento",
    "codigo_empresa";





