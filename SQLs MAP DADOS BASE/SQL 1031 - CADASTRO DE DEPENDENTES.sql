/* == SQL 1031 - CADASTRO DE DEPENDENTES ==
   ======================================== */


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

COLAB_BASE AS (
  SELECT DISTINCT
         C.COD_CONTRATO,
         C.COD_PESSOA,
         C.DATA_ADMISSAO,
         C.DES_PESSOA,
         C.DES_PAI,
         C.DES_MAE
    FROM V_DADOS_CONTRATO_AVT C
    JOIN CONTRATOS_OK OK
      ON OK.COD_CONTRATO = C.COD_CONTRATO
),

BASE_GERAL AS (

  /* 1) Dependentes reais */
  SELECT
         COL.COD_CONTRATO,
         COL.DATA_ADMISSAO,
         'DEPENDENTE' AS ORIGEM_REGISTRO,
         DEP.COD_PESSOA_DEPEND,
         SUBSTR(DEP.DES_DEPEND, 1, 40) AS NOME_DEPENDENTE,
         DEP.NOME_MAE,

         CASE
             WHEN DEP.COD_GRAU_PARENT = 1 THEN 1
             WHEN DEP.COD_GRAU_PARENT = 2 THEN 2
             WHEN DEP.COD_GRAU_PARENT = 3 THEN 16
             WHEN DEP.COD_GRAU_PARENT = 4 THEN 99
             WHEN DEP.COD_GRAU_PARENT = 5 THEN 11
             WHEN DEP.COD_GRAU_PARENT = 6 THEN 22
             WHEN DEP.COD_GRAU_PARENT = 7 THEN 12
             WHEN DEP.COD_GRAU_PARENT = 8 THEN 4
             WHEN DEP.COD_GRAU_PARENT = 9 THEN 8
             WHEN DEP.COD_GRAU_PARENT = 10 THEN 7
             WHEN DEP.COD_GRAU_PARENT = 11 THEN 99
             WHEN DEP.COD_GRAU_PARENT = 12 THEN 6
             WHEN DEP.COD_GRAU_PARENT = 13 THEN 99
             WHEN DEP.COD_GRAU_PARENT = 14 THEN 14
             WHEN DEP.COD_GRAU_PARENT = 15 THEN 18
             WHEN DEP.COD_GRAU_PARENT = 16 THEN 99
             ELSE 99
         END AS GRAU_PARENTESCO,

         DEP.SEXO_DEPEND,
         DEP.IRF,
         DEP.DTA_NASC_DEPEND,
         DEP.CPF_DEPEND,
         DEP.MATRICULA_NASC_DEPEND,
         DEP.COD_ESTADO_CIVIL,
         DEP.COD_GRAU_INSTRUCAO,

         CASE
             WHEN DEP.COD_GRAU_PARENT = 2 THEN 1
             WHEN DEP.COD_GRAU_PARENT = 16 THEN 2
             WHEN DEP.COD_GRAU_PARENT IN (1, 11, 14) THEN 3
             WHEN DEP.COD_GRAU_PARENT IN (3, 4, 5, 27) THEN 9
             WHEN DEP.COD_GRAU_PARENT IN (12, 8, 23) THEN 6
             WHEN DEP.COD_GRAU_PARENT = 18 THEN 10
             WHEN DEP.COD_GRAU_PARENT IN (17, 26) THEN 11
             WHEN DEP.COD_GRAU_PARENT = 22 THEN 12
             ELSE 99
         END AS COD_ESOCIAL,

         DEP.SAL_FAMILIA
    FROM COLAB_BASE COL
    JOIN V_DADOS_DEPEND_COLAB_AVT2 DEP
      ON DEP.COD_CONTRATO = COL.COD_CONTRATO
   WHERE DEP.COD_PESSOA_DEPEND IS NOT NULL

  UNION ALL

  /* 2) Pai como dependente lógico */
  SELECT
         COL.COD_CONTRATO,
         COL.DATA_ADMISSAO,
         'PAI' AS ORIGEM_REGISTRO,
         NULL AS COD_PESSOA_DEPEND,
         SUBSTR(COL.DES_PAI, 1, 40) AS NOME_DEPENDENTE,
         NULL AS NOME_MAE,
         3 AS GRAU_PARENTESCO,
         'M' AS SEXO_DEPEND,
         NULL AS IRF,
         NULL AS DTA_NASC_DEPEND,
         NULL AS CPF_DEPEND,
         NULL AS MATRICULA_NASC_DEPEND,
         NULL AS COD_ESTADO_CIVIL,
         NULL AS COD_GRAU_INSTRUCAO,
         9 AS COD_ESOCIAL,
         NULL AS SAL_FAMILIA
    FROM COLAB_BASE COL
   WHERE COL.DES_PAI IS NOT NULL

  UNION ALL

  /* 3) Mãe como dependente lógico */
  SELECT
         COL.COD_CONTRATO,
         COL.DATA_ADMISSAO,
         'MAE' AS ORIGEM_REGISTRO,
         NULL AS COD_PESSOA_DEPEND,
         SUBSTR(COL.DES_MAE, 1, 40) AS NOME_DEPENDENTE,
         NULL AS NOME_MAE,
         3 AS GRAU_PARENTESCO,
         'F' AS SEXO_DEPEND,
         NULL AS IRF,
         NULL AS DTA_NASC_DEPEND,
         NULL AS CPF_DEPEND,
         NULL AS MATRICULA_NASC_DEPEND,
         NULL AS COD_ESTADO_CIVIL,
         NULL AS COD_GRAU_INSTRUCAO,
         9 AS COD_ESOCIAL,
         NULL AS SAL_FAMILIA
    FROM COLAB_BASE COL
   WHERE COL.DES_MAE IS NOT NULL
),

BASE_NUMERADA AS (
  SELECT BG.*,
         ROW_NUMBER() OVER (
           PARTITION BY BG.COD_CONTRATO
           ORDER BY
             CASE
               /* filhos, enteados e adotivos primeiro */
               WHEN BG.GRAU_PARENTESCO IN (1, 11, 14) THEN 1

               /* cônjuge / companheiro depois */
               WHEN BG.GRAU_PARENTESCO IN (2, 16) THEN 2

               /* pai */
               WHEN BG.ORIGEM_REGISTRO = 'PAI' THEN 3

               /* mãe */
               WHEN BG.ORIGEM_REGISTRO = 'MAE' THEN 4

               /* demais */
               ELSE 9
             END,

             CASE
               WHEN BG.GRAU_PARENTESCO IN (1, 11, 14)
               THEN BG.DTA_NASC_DEPEND
             END ASC NULLS LAST,

             BG.NOME_DEPENDENTE
         ) AS CODIGO_DEPENDENTE
    FROM BASE_GERAL BG
)

SELECT DISTINCT
       ORG.COD_NIVEL2 AS "codigo_empresa",
       1 AS "tipo_colaborador",
       BG.COD_CONTRATO AS "cadastro_colaborador",
       BG.CODIGO_DEPENDENTE AS "codigo_dependente",
       BG.NOME_DEPENDENTE AS "nome_dependente",

       CASE
         WHEN BG.NOME_MAE IS NOT NULL THEN SUBSTR(BG.NOME_MAE, 1, 70)
         ELSE NULL
       END AS "nome_mae",

       BG.GRAU_PARENTESCO AS "grau_parentesco",
       BG.SEXO_DEPEND AS "tipo_sexo",

       CASE
         WHEN BG.IRF = 'S' THEN 21
         ELSE 0
       END AS "limite_irf",

       TO_CHAR(BG.DTA_NASC_DEPEND, 'DD/MM/YYYY') AS "data_nascimento",
       NULL AS "data_atestado_invalidez",
       NULL AS "nome_cartorio",
       NULL AS "numero_livro",
       NULL AS "numero_registro",
       NULL AS "numero_folha",
       BG.CPF_DEPEND AS "numero_cpf",
       NULL AS "pensao_judicial",
       NULL AS "data_obito",
       NULL AS "numero_certidao",
       NULL AS "nome_completo",
       BG.MATRICULA_NASC_DEPEND AS "matricula_certidao_nascimento",
       NULL AS "matricula_certidao_obito",
       NULL AS "declaracao_nascido_vivo",
       NULL AS "cartao_nacional_saude",

       CASE
         WHEN BG.COD_ESTADO_CIVIL IS NOT NULL THEN BG.COD_ESTADO_CIVIL
         ELSE 0
       END AS "estado_civil",

       CASE
         WHEN BG.COD_GRAU_INSTRUCAO = 1 THEN 1
         WHEN BG.COD_GRAU_INSTRUCAO = 2 THEN 1
         WHEN BG.COD_GRAU_INSTRUCAO = 3 THEN 3
         WHEN BG.COD_GRAU_INSTRUCAO = 4 THEN 4
         WHEN BG.COD_GRAU_INSTRUCAO = 5 THEN 5
         WHEN BG.COD_GRAU_INSTRUCAO = 6 THEN 6
         WHEN BG.COD_GRAU_INSTRUCAO = 7 THEN 7
         WHEN BG.COD_GRAU_INSTRUCAO = 8 THEN 8
         WHEN BG.COD_GRAU_INSTRUCAO = 9 THEN 9
         WHEN BG.COD_GRAU_INSTRUCAO = 10 THEN 14
         WHEN BG.COD_GRAU_INSTRUCAO = 11 THEN 10
         WHEN BG.COD_GRAU_INSTRUCAO = 12 THEN 15
         WHEN BG.COD_GRAU_INSTRUCAO = 13 THEN 11
         WHEN BG.COD_GRAU_INSTRUCAO = 14 THEN 16
         WHEN BG.COD_GRAU_INSTRUCAO = 15 THEN 12
         WHEN BG.COD_GRAU_INSTRUCAO = 16 THEN 17
         WHEN BG.COD_GRAU_INSTRUCAO = 17 THEN 13
         ELSE 99
       END AS "grau_instrucao",

       BG.COD_ESOCIAL AS "tipo_dependente_esocial",

       CASE
         WHEN BG.SAL_FAMILIA = 'S' THEN 14
         ELSE 0
       END AS "limite_dep_salario_familia",

       NULL AS "data_exp_carteira_ident",
       NULL AS "estado_emi_carteira_ident",
       NULL AS "orgao_emi_carteira_ident",
       NULL AS "numero_carteira_identidade",
       0 AS "registro_identidade_civil",
       NULL AS "numero_titulo_eleitor",
       0 AS "numero_pis_pasep",
       NULL AS "uf_carteira_trabalho",
       0 AS "numero_carteira_trabalho",
       NULL AS "serie_carteira_trabalho",
       NULL AS "digito_carteira_trabalho"

  FROM BASE_NUMERADA BG

  OUTER APPLY (
      SELECT H.COD_ORGANOGRAMA
        FROM (
              SELECT H.*,
                     CASE
                       WHEN TRUNC(H.DATA_INICIO) <= TRUNC(BG.DATA_ADMISSAO)
                        AND TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >= TRUNC(BG.DATA_ADMISSAO) THEN 1
                       WHEN TRUNC(H.DATA_INICIO) <= TRUNC(BG.DATA_ADMISSAO) THEN 2
                       ELSE 3
                     END AS RK,
                     CASE
                       WHEN TRUNC(H.DATA_INICIO) <= TRUNC(BG.DATA_ADMISSAO)
                        AND TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >= TRUNC(BG.DATA_ADMISSAO) THEN 0
                       WHEN TRUNC(H.DATA_INICIO) <= TRUNC(BG.DATA_ADMISSAO) THEN TRUNC(BG.DATA_ADMISSAO) - TRUNC(H.DATA_INICIO)
                       ELSE TRUNC(H.DATA_INICIO) - TRUNC(BG.DATA_ADMISSAO)
                     END AS DIST
                FROM RHFP0310 H
               WHERE H.COD_CONTRATO = BG.COD_CONTRATO
        ) H
       ORDER BY RK,
                DIST,
                CASE WHEN RK IN (1,2) THEN H.DATA_INICIO END DESC,
                CASE WHEN RK = 3 THEN H.DATA_INICIO END ASC
       FETCH FIRST 1 ROW ONLY
  ) HIST

  LEFT JOIN RHFP0401 ORG
    ON ORG.COD_ORGANOGRAMA = HIST.COD_ORGANOGRAMA

 WHERE ORG.COD_NIVEL2 IS NOT NULL

 ORDER BY BG.COD_CONTRATO, BG.CODIGO_DEPENDENTE;
 
 
 
 
 
 
/*VERSÃO EXCLUISIVA APENAS PARA OS CONTRATOS COM MAIS DE UMA EMPRESA*/

/* == SQL 1031 - CADASTRO DE DEPENDENTES ==
   ========================================
   VERSÃO TRANSFERIDOS
*/

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

/* =========================================================
   MAPA DE REPLICAÇÃO
   ========================================================= */
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

/* =========================================================
   BASE DO COLABORADOR
   ========================================================= */
COLAB_BASE AS (
  SELECT DISTINCT
         C.COD_CONTRATO,
         C.COD_PESSOA,
         C.DATA_ADMISSAO,
         C.DES_PESSOA,
         C.DES_PAI,
         C.DES_MAE
    FROM V_DADOS_CONTRATO_AVT C
    JOIN CONTRATOS_OK OK
      ON OK.COD_CONTRATO = C.COD_CONTRATO
   WHERE EXISTS (
         SELECT 1
           FROM MAPA_BASE MB
          WHERE MB.COD_CONTRATO = C.COD_CONTRATO
   )
),

BASE_GERAL AS (

  /* 1) Dependentes reais */
  SELECT
         COL.COD_CONTRATO,
         COL.DATA_ADMISSAO,
         'DEPENDENTE' AS ORIGEM_REGISTRO,
         DEP.COD_PESSOA_DEPEND,
         SUBSTR(DEP.DES_DEPEND, 1, 40) AS NOME_DEPENDENTE,
         DEP.NOME_MAE,

         CASE
             WHEN DEP.COD_GRAU_PARENT = 1 THEN 1
             WHEN DEP.COD_GRAU_PARENT = 2 THEN 2
             WHEN DEP.COD_GRAU_PARENT = 3 THEN 16
             WHEN DEP.COD_GRAU_PARENT = 4 THEN 99
             WHEN DEP.COD_GRAU_PARENT = 5 THEN 11
             WHEN DEP.COD_GRAU_PARENT = 6 THEN 22
             WHEN DEP.COD_GRAU_PARENT = 7 THEN 12
             WHEN DEP.COD_GRAU_PARENT = 8 THEN 4
             WHEN DEP.COD_GRAU_PARENT = 9 THEN 8
             WHEN DEP.COD_GRAU_PARENT = 10 THEN 7
             WHEN DEP.COD_GRAU_PARENT = 11 THEN 99
             WHEN DEP.COD_GRAU_PARENT = 12 THEN 6
             WHEN DEP.COD_GRAU_PARENT = 13 THEN 99
             WHEN DEP.COD_GRAU_PARENT = 14 THEN 14
             WHEN DEP.COD_GRAU_PARENT = 15 THEN 18
             WHEN DEP.COD_GRAU_PARENT = 16 THEN 99
             ELSE 99
         END AS GRAU_PARENTESCO,

         DEP.SEXO_DEPEND,
         DEP.IRF,
         DEP.DTA_NASC_DEPEND,
         DEP.CPF_DEPEND,
         DEP.MATRICULA_NASC_DEPEND,
         DEP.COD_ESTADO_CIVIL,
         DEP.COD_GRAU_INSTRUCAO,

         CASE
             WHEN DEP.COD_GRAU_PARENT = 2 THEN 1
             WHEN DEP.COD_GRAU_PARENT = 16 THEN 2
             WHEN DEP.COD_GRAU_PARENT IN (1, 11, 14) THEN 3
             WHEN DEP.COD_GRAU_PARENT IN (3, 4, 5, 27) THEN 9
             WHEN DEP.COD_GRAU_PARENT IN (12, 8, 23) THEN 6
             WHEN DEP.COD_GRAU_PARENT = 18 THEN 10
             WHEN DEP.COD_GRAU_PARENT IN (17, 26) THEN 11
             WHEN DEP.COD_GRAU_PARENT = 22 THEN 12
             ELSE 99
         END AS COD_ESOCIAL,

         DEP.SAL_FAMILIA
    FROM COLAB_BASE COL
    JOIN V_DADOS_DEPEND_COLAB_AVT2 DEP
      ON DEP.COD_CONTRATO = COL.COD_CONTRATO
   WHERE DEP.COD_PESSOA_DEPEND IS NOT NULL

  UNION ALL

  /* 2) Pai lógico */
  SELECT
         COL.COD_CONTRATO,
         COL.DATA_ADMISSAO,
         'PAI' AS ORIGEM_REGISTRO,
         NULL AS COD_PESSOA_DEPEND,
         SUBSTR(COL.DES_PAI, 1, 40) AS NOME_DEPENDENTE,
         NULL AS NOME_MAE,
         3 AS GRAU_PARENTESCO,
         'M' AS SEXO_DEPEND,
         NULL AS IRF,
         NULL AS DTA_NASC_DEPEND,
         NULL AS CPF_DEPEND,
         NULL AS MATRICULA_NASC_DEPEND,
         NULL AS COD_ESTADO_CIVIL,
         NULL AS COD_GRAU_INSTRUCAO,
         9 AS COD_ESOCIAL,
         NULL AS SAL_FAMILIA
    FROM COLAB_BASE COL
   WHERE COL.DES_PAI IS NOT NULL

  UNION ALL

  /* 3) Mãe lógica */
  SELECT
         COL.COD_CONTRATO,
         COL.DATA_ADMISSAO,
         'MAE' AS ORIGEM_REGISTRO,
         NULL AS COD_PESSOA_DEPEND,
         SUBSTR(COL.DES_MAE, 1, 40) AS NOME_DEPENDENTE,
         NULL AS NOME_MAE,
         3 AS GRAU_PARENTESCO,
         'F' AS SEXO_DEPEND,
         NULL AS IRF,
         NULL AS DTA_NASC_DEPEND,
         NULL AS CPF_DEPEND,
         NULL AS MATRICULA_NASC_DEPEND,
         NULL AS COD_ESTADO_CIVIL,
         NULL AS COD_GRAU_INSTRUCAO,
         9 AS COD_ESOCIAL,
         NULL AS SAL_FAMILIA
    FROM COLAB_BASE COL
   WHERE COL.DES_MAE IS NOT NULL
),

/* numeração-base da origem, usada só como apoio */
BASE_NUMERADA AS (
  SELECT BG.*,
         ROW_NUMBER() OVER (
           PARTITION BY BG.COD_CONTRATO
           ORDER BY
             CASE
               WHEN BG.GRAU_PARENTESCO IN (1, 11, 14) THEN 1
               WHEN BG.GRAU_PARENTESCO IN (2, 16) THEN 2
               WHEN BG.ORIGEM_REGISTRO = 'PAI' THEN 3
               WHEN BG.ORIGEM_REGISTRO = 'MAE' THEN 4
               ELSE 9
             END,
             CASE
               WHEN BG.GRAU_PARENTESCO IN (1, 11, 14)
               THEN BG.DTA_NASC_DEPEND
             END ASC NULLS LAST,
             BG.NOME_DEPENDENTE
         ) AS CODIGO_DEPENDENTE_ORIG
    FROM BASE_GERAL BG
),

/* empresa da admissão/origem do registro */
BASE_COM_EMPRESA AS (
  SELECT DISTINCT
         ORG.COD_NIVEL2 AS COD_EMPRESA,
         BG.COD_CONTRATO,
         BG.DATA_ADMISSAO,
         BG.ORIGEM_REGISTRO,
         BG.COD_PESSOA_DEPEND,
         BG.NOME_DEPENDENTE,
         BG.NOME_MAE,
         BG.GRAU_PARENTESCO,
         BG.SEXO_DEPEND,
         BG.IRF,
         BG.DTA_NASC_DEPEND,
         BG.CPF_DEPEND,
         BG.MATRICULA_NASC_DEPEND,
         BG.COD_ESTADO_CIVIL,
         BG.COD_GRAU_INSTRUCAO,
         BG.COD_ESOCIAL,
         BG.SAL_FAMILIA
    FROM BASE_NUMERADA BG

    OUTER APPLY (
        SELECT H.COD_ORGANOGRAMA
          FROM (
                SELECT H.*,
                       CASE
                         WHEN TRUNC(H.DATA_INICIO) <= TRUNC(BG.DATA_ADMISSAO)
                          AND TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >= TRUNC(BG.DATA_ADMISSAO) THEN 1
                         WHEN TRUNC(H.DATA_INICIO) <= TRUNC(BG.DATA_ADMISSAO) THEN 2
                         ELSE 3
                       END AS RK,
                       CASE
                         WHEN TRUNC(H.DATA_INICIO) <= TRUNC(BG.DATA_ADMISSAO)
                          AND TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >= TRUNC(BG.DATA_ADMISSAO) THEN 0
                         WHEN TRUNC(H.DATA_INICIO) <= TRUNC(BG.DATA_ADMISSAO) THEN TRUNC(BG.DATA_ADMISSAO) - TRUNC(H.DATA_INICIO)
                         ELSE TRUNC(H.DATA_INICIO) - TRUNC(BG.DATA_ADMISSAO)
                       END AS DIST
                  FROM RHFP0310 H
                 WHERE H.COD_CONTRATO = BG.COD_CONTRATO
          ) H
         ORDER BY RK,
                  DIST,
                  CASE WHEN RK IN (1,2) THEN H.DATA_INICIO END DESC,
                  CASE WHEN RK = 3 THEN H.DATA_INICIO END ASC
         FETCH FIRST 1 ROW ONLY
    ) HIST

    LEFT JOIN RHFP0401 ORG
      ON ORG.COD_ORGANOGRAMA = HIST.COD_ORGANOGRAMA

   WHERE ORG.COD_NIVEL2 IS NOT NULL
),

/* replica origem -> destino */
BASE_REPLICADA AS (
  SELECT
         MF.EMPRESA_DESTINO AS COD_EMPRESA,
         B.COD_CONTRATO,
         B.ORIGEM_REGISTRO,
         B.COD_PESSOA_DEPEND,
         B.NOME_DEPENDENTE,
         B.NOME_MAE,
         B.GRAU_PARENTESCO,
         B.SEXO_DEPEND,
         B.IRF,
         B.DTA_NASC_DEPEND,
         B.CPF_DEPEND,
         B.MATRICULA_NASC_DEPEND,
         B.COD_ESTADO_CIVIL,
         B.COD_GRAU_INSTRUCAO,
         B.COD_ESOCIAL,
         B.SAL_FAMILIA,
         ROW_NUMBER() OVER (
           PARTITION BY
             MF.EMPRESA_DESTINO,
             B.COD_CONTRATO,
             NVL(B.COD_PESSOA_DEPEND, -1),
             NVL(B.NOME_DEPENDENTE, '###'),
             NVL(B.CPF_DEPEND, '###'),
             NVL(B.ORIGEM_REGISTRO, '###')
           ORDER BY
             MF.DATA_TRANSFERENCIA DESC,
             MF.EMPRESA_ORIGEM DESC
         ) AS RN
    FROM BASE_COM_EMPRESA B
    JOIN MAPA_FINAL MF
      ON MF.COD_CONTRATO   = B.COD_CONTRATO
     AND MF.EMPRESA_ORIGEM = B.COD_EMPRESA
),

/* limpa duplicados e gera código dependente por empresa */
BASE_FINAL AS (
  SELECT
         BR.COD_EMPRESA,
         1 AS TIPO_COLABORADOR,
         BR.COD_CONTRATO,
         ROW_NUMBER() OVER (
           PARTITION BY BR.COD_CONTRATO, BR.COD_EMPRESA
           ORDER BY
             CASE
               WHEN BR.GRAU_PARENTESCO IN (1, 11, 14) THEN 1
               WHEN BR.GRAU_PARENTESCO IN (2, 16) THEN 2
               WHEN BR.ORIGEM_REGISTRO = 'PAI' THEN 3
               WHEN BR.ORIGEM_REGISTRO = 'MAE' THEN 4
               ELSE 9
             END,
             CASE
               WHEN BR.GRAU_PARENTESCO IN (1, 11, 14)
               THEN BR.DTA_NASC_DEPEND
             END ASC NULLS LAST,
             BR.NOME_DEPENDENTE
         ) AS CODIGO_DEPENDENTE,
         BR.NOME_DEPENDENTE,
         BR.NOME_MAE,
         BR.GRAU_PARENTESCO,
         BR.SEXO_DEPEND,
         BR.IRF,
         BR.DTA_NASC_DEPEND,
         BR.CPF_DEPEND,
         BR.MATRICULA_NASC_DEPEND,
         BR.COD_ESTADO_CIVIL,
         BR.COD_GRAU_INSTRUCAO,
         BR.COD_ESOCIAL,
         BR.SAL_FAMILIA
    FROM BASE_REPLICADA BR
   WHERE BR.RN = 1
)

SELECT DISTINCT
       BG.COD_EMPRESA AS "codigo_empresa",
       BG.TIPO_COLABORADOR AS "tipo_colaborador",
       BG.COD_CONTRATO AS "cadastro_colaborador",
       BG.CODIGO_DEPENDENTE AS "codigo_dependente",
       BG.NOME_DEPENDENTE AS "nome_dependente",

       CASE
         WHEN BG.NOME_MAE IS NOT NULL THEN SUBSTR(BG.NOME_MAE, 1, 70)
         ELSE NULL
       END AS "nome_mae",

       BG.GRAU_PARENTESCO AS "grau_parentesco",
       BG.SEXO_DEPEND AS "tipo_sexo",

       CASE
         WHEN BG.IRF = 'S' THEN 21
         ELSE 0
       END AS "limite_irf",

       TO_CHAR(BG.DTA_NASC_DEPEND, 'DD/MM/YYYY') AS "data_nascimento",
       NULL AS "data_atestado_invalidez",
       NULL AS "nome_cartorio",
       NULL AS "numero_livro",
       NULL AS "numero_registro",
       NULL AS "numero_folha",
       BG.CPF_DEPEND AS "numero_cpf",
       NULL AS "pensao_judicial",
       NULL AS "data_obito",
       NULL AS "numero_certidao",
       NULL AS "nome_completo",
       BG.MATRICULA_NASC_DEPEND AS "matricula_certidao_nascimento",
       NULL AS "matricula_certidao_obito",
       NULL AS "declaracao_nascido_vivo",
       NULL AS "cartao_nacional_saude",

       CASE
         WHEN BG.COD_ESTADO_CIVIL IS NOT NULL THEN BG.COD_ESTADO_CIVIL
         ELSE 0
       END AS "estado_civil",

       CASE
         WHEN BG.COD_GRAU_INSTRUCAO = 1 THEN 1
         WHEN BG.COD_GRAU_INSTRUCAO = 2 THEN 1
         WHEN BG.COD_GRAU_INSTRUCAO = 3 THEN 3
         WHEN BG.COD_GRAU_INSTRUCAO = 4 THEN 4
         WHEN BG.COD_GRAU_INSTRUCAO = 5 THEN 5
         WHEN BG.COD_GRAU_INSTRUCAO = 6 THEN 6
         WHEN BG.COD_GRAU_INSTRUCAO = 7 THEN 7
         WHEN BG.COD_GRAU_INSTRUCAO = 8 THEN 8
         WHEN BG.COD_GRAU_INSTRUCAO = 9 THEN 9
         WHEN BG.COD_GRAU_INSTRUCAO = 10 THEN 14
         WHEN BG.COD_GRAU_INSTRUCAO = 11 THEN 10
         WHEN BG.COD_GRAU_INSTRUCAO = 12 THEN 15
         WHEN BG.COD_GRAU_INSTRUCAO = 13 THEN 11
         WHEN BG.COD_GRAU_INSTRUCAO = 14 THEN 16
         WHEN BG.COD_GRAU_INSTRUCAO = 15 THEN 12
         WHEN BG.COD_GRAU_INSTRUCAO = 16 THEN 17
         WHEN BG.COD_GRAU_INSTRUCAO = 17 THEN 13
         ELSE 99
       END AS "grau_instrucao",

       BG.COD_ESOCIAL AS "tipo_dependente_esocial",

       CASE
         WHEN BG.SAL_FAMILIA = 'S' THEN 14
         ELSE 0
       END AS "limite_dep_salario_familia",

       NULL AS "data_exp_carteira_ident",
       NULL AS "estado_emi_carteira_ident",
       NULL AS "orgao_emi_carteira_ident",
       NULL AS "numero_carteira_identidade",
       0 AS "registro_identidade_civil",
       NULL AS "numero_titulo_eleitor",
       0 AS "numero_pis_pasep",
       NULL AS "uf_carteira_trabalho",
       0 AS "numero_carteira_trabalho",
       NULL AS "serie_carteira_trabalho",
       NULL AS "digito_carteira_trabalho"

  FROM BASE_FINAL BG
 ORDER BY BG.COD_CONTRATO, BG.COD_EMPRESA, BG.CODIGO_DEPENDENTE;


