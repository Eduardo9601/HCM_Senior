/*== 1054 - INFORMAÇÕES ADMISSIONAIS ===*/


WITH PARAM AS
 (SELECT DATE '2026-01-19' AS DT_CORTE FROM DUAL),

/* contratos que “existem” no cadastro importado (admitidos até o corte) */
CONTRATOS_OK AS
 (SELECT C.COD_CONTRATO
    FROM V_DADOS_CONTRATO_AVT C
   CROSS JOIN PARAM P
   GROUP BY C.COD_CONTRATO, P.DT_CORTE
  HAVING MIN(NVL(TRUNC(C.DATA_ADMISSAO), DATE '1900-01-01')) <= P.DT_CORTE
  
)

SELECT DISTINCT ORG.COD_NIVEL2 AS "codigo_empresa",
                1 AS "tipo_colaborador",
                A.COD_CONTRATO AS "cadastro_colaborador",
                to_char(A.DATA_INICIO, 'DD/MM/YYYY') AS "data_admissao",
                B.COD_TIPO_ADMISSAO AS "tipo_admissao",
                1 AS "indicativo_admissao", -- NÃO POSSUIMOS COLUNA PARA ESTA INFORMAÇÃO
                NULL AS "tipo_inscricao",
                NULL AS "numero_inscricao_anterior",
                TO_CHAR(A.DATA_AVANCO, 'DD/MM/YYYY') AS "data_inicio_vinculo",
                A.COD_CONTRATO AS "matricula_trabalhador",
                NULL AS "cedido_onus", -- NÃO POSSUIMOS COLABORADORES QUE FAZEM SERVIÇOS EM OUTRAS EMPRESAS
                CAT.COD_CATEGORIA_ORIGEM AS "codigo_categoria_esocial",
                'N' AS "ressarcimento_onus", -- NÃO POSSUI (PORQUE NÃO TEMOS COLABORADORES QUE PRESTAM SERVIÇOS PARA OUTRAS EMPRESAS, ENTÃO NÃO TEM RESSARCIMENTO)
                CASE
                  WHEN A.IND_SEGURO_DESEMP = 'N' THEN
                   1
                  WHEN A.IND_SEGURO_DESEMP = 'S' THEN
                   2
                  ELSE
                   0
                END AS "recebe_seguro"
  FROM RHFP0300 A
  JOIN RHFP0114 B
    ON B.COD_TIPO_ADMISSAO = A.COD_TIPO_ADMISSAO
  LEFT JOIN (SELECT A1.COD_CONTRATO,
                    COALESCE(H1.COD_CATEGORIA_TRAB, A1.COD_CATEGORIA_TRAB) AS COD_CATEGORIA_ORIGEM
               FROM RHFP0300 A1
               LEFT JOIN (SELECT COD_CONTRATO, COD_CATEGORIA_TRAB
                           FROM (SELECT H.COD_CONTRATO,
                                        H.COD_CATEGORIA_TRAB,
                                        ROW_NUMBER() OVER(PARTITION BY H.COD_CONTRATO ORDER BY H.DATA_HISTORICO) AS RN
                                   FROM RHFP0301 H)
                          WHERE RN = 1) H1
                 ON H1.COD_CONTRATO = A1.COD_CONTRATO) CAT
    ON CAT.COD_CONTRATO = A.COD_CONTRATO

 OUTER APPLY (SELECT H.COD_ORGANOGRAMA
                FROM RHFP0310 H
               WHERE H.COD_CONTRATO = A.COD_CONTRATO
               ORDER BY NVL(H.DATA_FIM, DATE '9999-12-31') DESC,
                        H.DATA_INICIO DESC
               FETCH FIRST 1 ROW ONLY) HIST

  LEFT JOIN RHFP0401 ORG
    ON ORG.COD_ORGANOGRAMA = HIST.COD_ORGANOGRAMA
  CROSS JOIN PARAM P
 WHERE  ORG.COD_NIVEL2 IS NOT NULL
 AND A.COD_CONTRATO IN (SELECT COD_CONTRATO FROM CONTRATOS_OK)
 AND A.DATA_AVANCO <= P.DT_CORTE --DATA DE CORTE
 AND A.DATA_INICIO <= P.DT_CORTE --DATA DE CORTE
 ORDER BY A.COD_CONTRATO;
