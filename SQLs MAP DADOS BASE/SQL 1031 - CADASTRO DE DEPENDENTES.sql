/* ============================================
   == SQL 1031 - CADASTRO DE DEPENDENTES ==
   ============================================ */
   
/*VERSÃO DEFINITIVA*/

/*=== 1031 - CADASTRO DE DEPENDENTES (ATE DATA CORTE) ===*/

WITH
PARAM AS (
  SELECT DATE '2026-01-19' AS DT_CORTE FROM DUAL
),

/* contratos que "existem" no cadastro importado (admitidos ate o corte) */
CONTRATOS_OK AS (
  SELECT C.COD_CONTRATO
    FROM V_DADOS_CONTRATO_AVT C
    CROSS JOIN PARAM P
   GROUP BY C.COD_CONTRATO, P.DT_CORTE
  HAVING MIN(NVL(TRUNC(C.DATA_ADMISSAO), DATE '1900-01-01')) <= P.DT_CORTE
)

SELECT DISTINCT
       ORG.COD_NIVEL2 AS "codigo_empresa",
       1 AS "tipo_colaborador",
       DEP.COD_CONTRATO AS "cadastro_colaborador",
       DEP2.SEQ_DEPEND AS "codigo_dependente",
       SUBSTR(DEP.DES_DEPEND, 1, 40) AS "nome_dependente",
       CASE
           WHEN DEP.NOME_MAE IS NOT NULL THEN
             SUBSTR(DEP.NOME_MAE, 1, 70)
           ELSE
             NULL
       END AS "nome_mae",
       DEP.COD_GRAU_PARENT AS "grau_parentesco",
       DEP.SEXO_DEPEND AS "tipo_sexo",
       CASE
           WHEN DEP.IRF = 'S' THEN 21
           ELSE 00
       END AS "limite_irf",
       TO_CHAR(DEP.DTA_NASC_DEPEND, 'DD/MM/YYYY') AS "data_nascimento",
       NULL AS "data_atestado_invalidez",
       NULL AS "nome_cartorio",
       NULL AS "numero_livro",
       NULL AS "numero_registro",
       NULL AS "numero_folha",
       DEP.CPF_DEPEND AS "numero_cpf",
       NULL AS "pensao_judicial",
       NULL AS "data_obito",
       NULL AS "numero_certidao",
       NULL AS "nome_completo",
       DEP.MATRICULA_NASC_DEPEND AS "matricula_certidao_nascimento",
       NULL AS "matricula_certidao_obito",
       NULL AS "declaracao_nascido_vivo",
       NULL AS "cartao_nacional_saude",
       CASE
           WHEN DEP.COD_ESTADO_CIVIL IS NOT NULL THEN DEP.COD_ESTADO_CIVIL
           ELSE 0
       END AS "estado_civil",
       CASE
           WHEN DEP.COD_GRAU_INSTRUCAO IN (1,2,3,4,5,7,8,9,10) THEN DEP.COD_GRAU_INSTRUCAO
           ELSE 0
       END AS "grau_instrucao",
       DEP.COD_ESOCIAL AS "tipo_dependente_esocial",
       CASE
           WHEN DEP.SAL_FAMILIA = 'S' THEN 14
           ELSE 00
       END AS "limite_dep_salario_familia",    --limite_dependente_salario_familia
       NULL AS "data_exp_carteira_ident",      --data_expedicao_carteira_identidade
       NULL AS "estado_emi_carteira_ident",    --estado_emissor_carteira_identidade
       NULL AS "orgao_emi_carteira_ident",     --orgao_emissor_carteira_identidade
       NULL AS "numero_carteira_identidade",
       0 AS "registro_identidade_civil",
       NULL AS "numero_titulo_eleitor",
       0 AS "numero_pis_pasep",
       NULL AS "uf_carteira_trabalho",
       0 AS "numero_carteira_trabalho",
       NULL AS "serie_carteira_trabalho",
       NULL AS "digito_carteira_trabalho"
  FROM V_DADOS_DEPEND_COLAB_AVT2 DEP

  /* >>> ENTRAVE AQUI: só contratos admitidos até o corte <<< */
  JOIN CONTRATOS_OK OK
    ON OK.COD_CONTRATO = DEP.COD_CONTRATO

  LEFT JOIN GRZ_TMP_DEPEND_SEQ DEP2
    ON DEP.COD_CONTRATO = DEP2.COD_CONTRATO
   AND DEP.COD_PESSOA_DEPEND = DEP2.COD_PESSOA_DEPEND

  OUTER APPLY (
      SELECT H.COD_ORGANOGRAMA
        FROM (
              SELECT H.*,
                     CASE
                       WHEN TRUNC(H.DATA_INICIO) <= TRUNC(DEP.DATA_ADMISSAO)
                        AND TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >= TRUNC(DEP.DATA_ADMISSAO) THEN 1
                       WHEN TRUNC(H.DATA_INICIO) <= TRUNC(DEP.DATA_ADMISSAO) THEN 2
                       ELSE 3
                     END AS RK,
                     CASE
                       WHEN TRUNC(H.DATA_INICIO) <= TRUNC(DEP.DATA_ADMISSAO)
                        AND TRUNC(NVL(H.DATA_FIM, DATE '9999-12-31')) >= TRUNC(DEP.DATA_ADMISSAO) THEN 0
                       WHEN TRUNC(H.DATA_INICIO) <= TRUNC(DEP.DATA_ADMISSAO) THEN TRUNC(DEP.DATA_ADMISSAO) - TRUNC(H.DATA_INICIO)
                       ELSE TRUNC(H.DATA_INICIO) - TRUNC(DEP.DATA_ADMISSAO)
                     END AS DIST
                FROM RHFP0310 H
               WHERE H.COD_CONTRATO = DEP.COD_CONTRATO
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
 ORDER BY "nome_dependente", DEP.COD_CONTRATO;










/*
== PROCESSOS REALIZADOS PARA UM MELHOR MAPEAMENTO DOS DADOS ==

SELECT * FROM GRZ_TMP_DEPEND_SEQ
ORDER BY DES_DEPEND

SELECT * FROM V_DADOS_DEPEND_COLAB_AVT2
WHERE COD_PESSOA_DEPEND = 56811

select * from FISICA
WHERE COD_PESSOA = 56811

SELECT * FROM SENIOR_RH.R036DEP

select * from rhfp0202
where cod_PESSOA = 56811


CREATE GLOBAL TEMPORARY TABLE GRZ_TMP_DEPEND_SEQ (
    COD_CONTRATO       NUMBER      NOT NULL,
    COD_PESSOA_DEPEND  NUMBER      NOT NULL,
    DES_DEPEND         VARCHAR2(200),
    IDADE_DEPEND       NUMBER,
    SEQ_DEPEND         NUMBER      NOT NULL,
    QTD_DEPEND         NUMBER      NOT NULL,
    CONSTRAINT PK_GRZ_TMP_DEPEND_SEQ PRIMARY KEY (COD_CONTRATO, SEQ_DEPEND)
) ON COMMIT PRESERVE ROWS;


INSERT INTO GRZ_TMP_DEPEND_SEQ (
    COD_CONTRATO,
    COD_PESSOA_DEPEND,
    DES_DEPEND,
    IDADE_DEPEND,
    SEQ_DEPEND,
    QTD_DEPEND
)
SELECT
    COD_CONTRATO,
    COD_PESSOA_DEPEND,
    DES_DEPEND,
    IDADE_DEPEND,
    ROW_NUMBER() OVER (
        PARTITION BY COD_CONTRATO
        ORDER BY
            CASE WHEN IDADE_DEPEND IS NULL THEN 1 ELSE 0 END,
            IDADE_DEPEND DESC,
            COD_PESSOA_DEPEND
    ) AS SEQ_DEPEND,
    COUNT(*) OVER (PARTITION BY COD_CONTRATO) AS QTD_DEPEND
FROM V_DADOS_DEPEND_COLAB_AVT2;


SELECT
    COD_CONTRATO,
    COD_PESSOA_DEPEND,
    DES_DEPEND,
    IDADE_DEPEND,
    ROW_NUMBER() OVER (
        PARTITION BY COD_CONTRATO
        ORDER BY
            CASE WHEN IDADE_DEPEND IS NULL THEN 1 ELSE 0 END,
            IDADE_DEPEND DESC,
            COD_PESSOA_DEPEND
    ) AS SEQ_DEPEND,
    COUNT(*) OVER (PARTITION BY COD_CONTRATO) AS QTD_DEPEND
FROM V_DADOS_DEPEND_COLAB_AVT2
where cod_contrato in(377199, 352683);


*/
