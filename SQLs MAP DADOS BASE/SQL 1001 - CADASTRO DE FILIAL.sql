/*=== 1001 - DADOS FILIAIS ===*/

/*USAR PARA O ARQUIVO DE FILIAIS*/


WITH
DADOS AS (
  SELECT *
    FROM V_EST_ORG_AVT
   WHERE COD_NIVEL_ORG = 3
     AND EDICAO_ORG NOT IN (157, 173)
),

--LOJAS
DES_UNIDADES_1 AS (
  SELECT A.COD2 AS COD_EMP,
         A.COD_TIPO,
         A.COD_ORGANOGRAMA,
         A.EDICAO_ORG AS UNIDADE,
         CASE
           WHEN A.COD_TIPO = 1 THEN
            A.SIGLA_REDE || ' - ' ||
            TRIM(REGEXP_REPLACE(B.CIDADE, '\s+', ' ')) || ' ' ||
            A.EDICAO_ORG
           ELSE
            TRIM(REGEXP_REPLACE(A.NOME_ORGANOGRAMA, '\s+', ' '))
         END AS DES_UNIDADE,
         'GRAZZIOTIN S/A' AS RAZAO_SOCIAL,           
         B.COD_IBGE
    FROM V_EST_ORG_AVT A
    JOIN V_EST_ORG_AVT B
      ON A.EDICAO_ORG = B.EDICAO_ORG
   WHERE A.COD_NIVEL_ORG = 5
     AND B.COD_NIVEL_ORG = 3
     AND A.COD_TIPO = 1
     AND A.COD2 = 8
     AND B.COD2 = 8
     AND B.EDICAO_ORG NOT IN ('157', '173', '549', '7549')

  UNION ALL

  /* Exceções: NÃO existem no nível 5 → monta só com nível 3 e sigla fixa */
  SELECT B.COD2 AS COD_EMP,
         1 AS COD_TIPO,
         B.COD_ORGANOGRAMA,
         B.EDICAO_ORG AS UNIDADE,
         CASE
           WHEN B.EDICAO_ORG = '173' THEN
            'TOT - ' || TRIM(REGEXP_REPLACE(B.CIDADE, '\s+', ' ')) || ' ' ||
            B.EDICAO_ORG
           WHEN B.EDICAO_ORG IN ('549', '7549') THEN
            'ECM - E-COMERCE ' || B.EDICAO_ORG
           ELSE
            TRIM(REGEXP_REPLACE(B.NOME_ORGANOGRAMA, '\s+', ' '))
         END AS DES_UNIDADE,
         'GRAZZIOTIN S/A' AS RAZAO_SOCIAL,
         B.COD_IBGE
    FROM V_EST_ORG_AVT B
   WHERE B.COD_NIVEL_ORG = 3
     AND B.COD2 = 8
     AND B.EDICAO_ORG IN ('549', '7549')
),

--ADM/CD
DES_UNIDADES_2 AS (
  SELECT COD2 AS COD_EMP,
         COD_TIPO,
         COD_ORGANOGRAMA,
         EDICAO_ORG AS UNIDADE,
         TRIM(REGEXP_REPLACE(NOME_ORGANOGRAMA, '\s+', ' ')) AS DES_UNIDADE,
         'GRAZZIOTIN S/A' AS RAZAO_SOCIAL,
         COD_IBGE
    FROM V_EST_ORG_AVT
   WHERE COD_NIVEL_ORG = 3
     AND COD_TIPO IN (2, 3)
     AND COD2 = 8
),

--COLIGADAS
DES_UNIDADES_3 AS (
  SELECT COD2 AS COD_EMP,
         COD_TIPO,
         COD_ORGANOGRAMA,
         EDICAO_ORG AS UNIDADE,
         CASE
           WHEN COD2 = 2 THEN
            'VR ADMINISTRAÇÃO'
           WHEN COD_ORGANOGRAMA = 5 THEN
            'MUNDIART ADMINISTRAÇÃO'
           WHEN COD_ORGANOGRAMA = 1735 THEN
            'COMÉRCIO E IMPORTAÇÃO - FILIAL'
           WHEN COD2 = 6 THEN
            'GRATO ADMINISTRAÇÃO LTDA'
           WHEN COD2 = 276 THEN
            'CENTRO SHOPPING LTDA'
           WHEN COD2 = 280 THEN
            'CAULESPAR ADMINISTRAÇÃO LTDA'
           WHEN COD2 = 282 THEN
            'CENTRO ADMINISTRATIVO'
           WHEN COD2 = 1417 THEN
            'ASSOCIACAO FUNCIONARIOS GRZ'
           WHEN COD2 = 1629 THEN
            'FLORESTA GRAZZIOTIN LTDA'
           ELSE
            SUBSTR(TRIM(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(UPPER(NOME_ORGANOGRAMA),
                                                                     '\s+',
                                                                     ' '),
                                                      '( EMP E PARTIC( LTDA)?| E PARTIC( LTDA)?| PARTIC LTDA| PARTIC\.? LTDA\.?)',
                                                      ''),
                                       '( LTDA\.?| S/A| SA)$',
                                       '')),
                   1,
                   40)
         END AS DES_UNIDADE,
         CASE
           WHEN COD2 = 2 THEN
            'VR GRAZZIOTIN S/A'
           WHEN COD2 = 4 THEN
            'MUNDIART S/A'
           WHEN COD2 = 6 THEN
            'GRATO AGORPECUÁRIA LTDA'
           WHEN COD2 = 276 THEN
            'CENTRO SHOPPING LTDA'
           WHEN COD2 = 280 THEN
            'CAULESPAR LTDA'
           WHEN COD2 = 282 THEN
            'GRAZZIOTIN FINANCEIRA S/A'
           WHEN COD2 = 1417 THEN
            'ASSOCIAÇÃO GRAZZIOTIN S/A'
           WHEN COD2 = 1629 THEN
            'FLORESTA GRAZZIOTIN LTDA'
           ELSE
            NULL
         END AS RAZAO_SOCIAL,
         COD_IBGE
    FROM V_EST_ORG_AVT
   WHERE COD_NIVEL_ORG = 3
     AND COD_TIPO = 4
     AND COD2 <> 8
),

/* CTE master */
DES_UNIDADES AS (
  SELECT COD_EMP, COD_TIPO, UNIDADE, DES_UNIDADE, RAZAO_SOCIAL, COD_IBGE 
  FROM DES_UNIDADES_1
  UNION ALL
  SELECT COD_EMP, COD_TIPO, UNIDADE, DES_UNIDADE, RAZAO_SOCIAL, COD_IBGE 
  FROM DES_UNIDADES_2
  UNION ALL
  SELECT COD_EMP, COD_TIPO, UNIDADE, DES_UNIDADE, RAZAO_SOCIAL, COD_IBGE 
  FROM DES_UNIDADES_3
  ORDER BY COD_TIPO
  
),

/* SELEÇÃO FINAL "bruta" (com colunas auxiliares só pra deduplicar) */ 
FINAL_RAW AS (
SELECT A.COD_TIPO,
       A.COD2 AS "codigo_empresa",
       COALESCE(U.UNIDADE, A.EDICAO_ORG) AS "codigo_filial",
       A.COD2 AS "codigo_pai_filial",      
       U.RAZAO_SOCIAL AS "razao_social",
       U.DES_UNIDADE AS "nome_filial",
       
       SUBSTR(TRIM(NVL(A.LOGRADOURO, '')), 1, 40) AS "endereco_filial",
       SUBSTR(TRIM(NVL(A.COMPLEMENTO, '')), 1, 40) AS "complemento_endereco",
       SUBSTR(TRIM(NVL(TO_CHAR(A.NUMERO), '')), 1, 6) AS "numero_endereco",
       SUBSTR(TRIM(NVL(A.COD_BAIRRO, '')), 1, 40) AS "codigo_bairro",
       SUBSTR(TRIM(NVL(A.COD_UF, '')), 1, 2) AS "estado",
       
       COALESCE(U.COD_IBGE, A.COD_IBGE) AS "codigo_cidade",
       
       55 AS "codigo_ddi_telefone",
       SUBSTR(TRIM(0), 1, 3) AS "codigo_ddd_telefone",
       SUBSTR(TRIM(NULL), 1, 20) AS "numero_telefone",
       
       CASE
         WHEN (A.COD_TIPO = 2 OR A.COD_ORGANOGRAMA IN (3, 5, 7, 277, 281, 283, 1418, 1630)) THEN
          'M'
         ELSE
          'F'
       END AS "tipo_filial",
       1 AS "tipo_inscricao",
       
       /* mantém 15 (layout), mas blindado contra Excel comer zeros */
       SUBSTR(LPAD(REGEXP_REPLACE(TRIM(NVL(A.CNPJ, '')), '[^0-9]', ''), 15, '0'), 1, 15) AS "numero_inscricao",
       
       SUBSTR(TRIM(NULL), 1, 12) AS "codigo_cei",
       
       /* IE: nulo => nulo | só zeros => nulo | valor real => mantém (preferência por dígitos) */
       CASE
         WHEN REGEXP_LIKE(NVL(REGEXP_REPLACE(TO_CHAR(A.INSC_EST), '[^0-9]', ''), '0'), '^0*$') THEN
          NULL
         ELSE
          SUBSTR(REGEXP_REPLACE(TO_CHAR(A.INSC_EST), '[^0-9]', ''), 1, 15)
       END AS "inscricao_estadual",
       
       /* IM: mesma regra (tamanho 16 no teu layout) */
       CASE
         WHEN REGEXP_LIKE(NVL(REGEXP_REPLACE(TO_CHAR(A.INSC_MUNIC), '[^0-9]', ''), '0'), '^0*$') THEN
          NULL
         ELSE
          SUBSTR(REGEXP_REPLACE(TO_CHAR(A.INSC_MUNIC), '[^0-9]', ''), 1, 16)
       END AS "inscricao_municipal",
       
       SUBSTR(REGEXP_REPLACE(TRIM(NVL(TO_CHAR(A.CNAE2), '')), '[^0-9]', ''), 1, 7) AS "cnae_fiscal",
       SUBSTR(TRIM(NVL(TO_CHAR(A.COD_ATIV), '')), 1, 7) AS "codigo_nac_atv_economica",
       SUBSTR(TRIM(NULL), 1, 12) AS "inscricao_cno",
       SUBSTR(TRIM(NULL), 1, 14) AS "inscricao_caepf",
       SUBSTR(REGEXP_REPLACE(TRIM(NVL(TO_CHAR(A.CNAE2), '')), '[^0-9]', ''), 1, 7) AS "cnae_fiscal_preponderante",
       1 AS "tipo_caepf",
       SUBSTR(TRIM(NVL(A.TIP_LOGRA, '')), 1, 5) AS "tipo_logradouro",
       SUBSTR(REGEXP_REPLACE(TRIM(NVL(A.CEP, '')), '[^0-9]', ''), 1, 8) AS "codigo_cep_filial",
       
       A.NOME_ORGANOGRAMA AS "nome_empresarial_completo",
       
       /* auxiliares pra matar duplicidade sem “inventar” dado */
       A.COD_ORGANOGRAMA AS COD_ORG,
       A.DATA_INICIO     AS DT_INI,
       A.DATA_FIM        AS DT_FIM
  FROM DADOS A
  LEFT JOIN DES_UNIDADES U
    ON U.COD_EMP = A.COD2
   AND U.COD_TIPO = A.COD_TIPO
   AND U.UNIDADE = A.EDICAO_ORG
 ORDER BY A.COD_TIPO, UNIDADE
),

/* Dedup: 1 linha por (empresa, filial) pegando o mais vigente/atual */
FINAL AS (
  SELECT F.*,
         ROW_NUMBER() OVER (
           PARTITION BY F.COD_TIPO, F."codigo_empresa", F."codigo_filial"
           ORDER BY
             F.COD_TIPO,
             CASE WHEN NVL(F.DT_FIM, DATE '2999-12-31') = DATE '2999-12-31' THEN 1 ELSE 0 END DESC,
             NVL(F.DT_FIM, DATE '2999-12-31') DESC,
             F.DT_INI DESC,
             F.COD_ORG DESC
         ) AS RN
  FROM FINAL_RAW F
)

SELECT
  "codigo_empresa",
  "codigo_filial",
  "razao_social",
  "nome_filial",
  "endereco_filial",
  "complemento_endereco",
  "numero_endereco",
  "codigo_bairro",
  "estado",
  "codigo_cidade",
  "codigo_ddi_telefone",
  "codigo_ddd_telefone",
  "numero_telefone",
  "tipo_filial",
  "tipo_inscricao",
  "numero_inscricao",
  "codigo_cei",
  "inscricao_estadual",
  "inscricao_municipal",
  "cnae_fiscal",
  "codigo_nac_atv_economica",
  "inscricao_cno",
  "inscricao_caepf",
  "cnae_fiscal_preponderante",
  "tipo_caepf",
  "tipo_logradouro",
  "codigo_cep_filial",
  "nome_empresarial_completo"
FROM FINAL
WHERE RN = 1
ORDER BY cod_tipo, "codigo_filial";