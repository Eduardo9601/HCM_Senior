/*== 1054 - INFORMAÇÕES ADMISSIONAIS ===*/

WITH PARAM AS (
    SELECT DATE '2026-04-23' AS DT_CORTE
      FROM DUAL
),

/* contratos que “existem” no cadastro importado (admitidos até o corte) */
CONTRATOS_OK AS (
    SELECT C.COD_CONTRATO
      FROM V_DADOS_CONTRATO_AVT C
     CROSS JOIN PARAM P
     GROUP BY C.COD_CONTRATO, P.DT_CORTE
    HAVING MIN(NVL(TRUNC(C.DATA_ADMISSAO), DATE '1900-01-01')) < P.DT_CORTE
),

/* categoria origem do colaborador */
CAT AS (
    SELECT A1.COD_CONTRATO,
           COALESCE(H1.COD_CATEGORIA_TRAB, A1.COD_CATEGORIA_TRAB) AS COD_CATEGORIA_ORIGEM,
           G.COD_ESOCIAL AS CATEGORIA
      FROM RHFP0300 A1
      JOIN RHFP0128 G
        ON A1.COD_CATEGORIA_TRAB = G.COD_CATEGORIA_TRAB
      LEFT JOIN (
            SELECT COD_CONTRATO, COD_CATEGORIA_TRAB
              FROM (
                    SELECT H.COD_CONTRATO,
                           H.COD_CATEGORIA_TRAB,
                           ROW_NUMBER() OVER (
                               PARTITION BY H.COD_CONTRATO
                               ORDER BY H.DATA_HISTORICO
                           ) AS RN
                      FROM RHFP0301 H
                   )
             WHERE RN = 1
      ) H1
        ON H1.COD_CONTRATO = A1.COD_CONTRATO
),

/* empresas distintas por contrato */
EMPRESAS_CONTRATO AS (
    SELECT DISTINCT
           H.COD_CONTRATO,
           O.COD_NIVEL2 AS COD_EMPRESA,
           H.DATA_INICIO,
           H.DATA_FIM
      FROM RHFP0310 H
      JOIN RHFP0401 O
        ON O.COD_ORGANOGRAMA = H.COD_ORGANOGRAMA
     CROSS JOIN PARAM P
     WHERE O.COD_NIVEL2 IS NOT NULL
       AND H.DATA_INICIO < P.DT_CORTE
),

/* mapa dos contratos com transferência entre empresas */
TRANS_EMPRESAS AS (
    SELECT A.COD_CONTRATO,
           A.DATA_ADMISSAO,
           A.DATA_DEMISSAO,
           A.EMPRESA_ORIGEM,
           A.DATA_INI_EMP_ORIG,
           A.DATA_FIM_EMP_ORIG,
           A.EMPRESA_DESTINO,
           A.DATA_INI_EMP_DEST,
           A.DATA_FIM_EMP_DEST,
           A.DATA_TRANSFERENCIA,
           PJ_ORIG.CGC AS CNPJ_ORIGEM
      FROM GRZ_MAPA_TRANSF_EMPRESA A
      LEFT JOIN RHFP0400 ORIG
        ON A.EMPRESA_ORIGEM = ORIG.COD_ORGANOGRAMA
      LEFT JOIN PESSOA_JURIDICA PJ_ORIG
        ON ORIG.COD_PESSOA = PJ_ORIG.COD_PESSOA
        WHERE A.COD_CONTRATO = 307416
),

BASE_FINAL AS (
    SELECT DISTINCT
           EMP.COD_EMPRESA AS "codigo_empresa",
           1 AS "tipo_colaborador",
           A.COD_CONTRATO AS "cadastro_colaborador",
           TO_CHAR(A.DATA_AVANCO, 'DD/MM/YYYY') AS "data_admissao",

           CASE
             WHEN T.COD_CONTRATO IS NOT NULL
              AND EMP.COD_EMPRESA = T.EMPRESA_ORIGEM THEN 1
             WHEN T.COD_CONTRATO IS NOT NULL
              AND EMP.COD_EMPRESA = T.EMPRESA_DESTINO THEN 2
             ELSE B.COD_TIPO_ADMISSAO
           END AS "tipo_admissao",

           1 AS "indicativo_admissao", -- mantém como está

           1 AS "tipo_inscricao",

           CASE
             WHEN T.COD_CONTRATO IS NOT NULL
              AND EMP.COD_EMPRESA IN (T.EMPRESA_ORIGEM, T.EMPRESA_DESTINO)
             THEN T.CNPJ_ORIGEM
             ELSE NULL
           END AS "numero_inscricao_anterior",

           CASE
             WHEN T.COD_CONTRATO IS NOT NULL
              AND EMP.COD_EMPRESA = T.EMPRESA_ORIGEM
             THEN TO_CHAR(T.DATA_ADMISSAO, 'DD/MM/YYYY')
             WHEN T.COD_CONTRATO IS NOT NULL
              AND EMP.COD_EMPRESA = T.EMPRESA_DESTINO
             THEN TO_CHAR(T.DATA_TRANSFERENCIA, 'DD/MM/YYYY')
             ELSE TO_CHAR(A.DATA_AVANCO, 'DD/MM/YYYY')
           END AS "data_inicio_vinculo",

           A.COD_CONTRATO AS "matricula_trabalhador",
           NULL AS "cedido_onus",
           CAT.CATEGORIA AS "codigo_categoria_esocial",
           'N' AS "ressarcimento_onus",
           CASE
             WHEN A.IND_SEGURO_DESEMP = 'N' THEN 1
             WHEN A.IND_SEGURO_DESEMP = 'S' THEN 2
             ELSE 0
           END AS "recebe_seguro"
      FROM RHFP0300 A
      JOIN RHFP0114 B
        ON B.COD_TIPO_ADMISSAO = A.COD_TIPO_ADMISSAO
      LEFT JOIN CAT
        ON CAT.COD_CONTRATO = A.COD_CONTRATO
      JOIN EMPRESAS_CONTRATO EMP
        ON EMP.COD_CONTRATO = A.COD_CONTRATO
      LEFT JOIN TRANS_EMPRESAS T
        ON T.COD_CONTRATO = A.COD_CONTRATO
     CROSS JOIN PARAM P
     WHERE A.COD_CONTRATO IN (SELECT COD_CONTRATO FROM CONTRATOS_OK)
       AND A.DATA_AVANCO < P.DT_CORTE
       AND A.DATA_INICIO < P.DT_CORTE

       /* se está no mapa de transferência, traz só origem e destino;
          se não está, mantém a lógica normal */
       AND (
             T.COD_CONTRATO IS NULL
             OR EMP.COD_EMPRESA IN (T.EMPRESA_ORIGEM, T.EMPRESA_DESTINO)
           )

        --AND A.COD_CONTRATO = 307416
)

SELECT *
  FROM BASE_FINAL
 ORDER BY "cadastro_colaborador", "codigo_empresa";