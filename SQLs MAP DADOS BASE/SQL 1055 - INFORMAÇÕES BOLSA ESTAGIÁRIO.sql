/*=== SQL 1055 - INFORMAÇÕES BOLSA ESTAGIÁRIO ===*/


WITH
ESTAGIARIOS AS (
SELECT DISTINCT ORG.COD_NIVEL2,
                1 AS tipo_colaborador,
                A.COD_CONTRATO,
                TO_CHAR(A.DATA_INICIO, 'DD/MM/YYYY') AS data_referencia,
                B.NAT_ESTAGIO,
                B.NIV_ESTAGIO,
                B.AREA_ATUACAO,
                B.NR_APOLICE,
                B.VLR_BOLSA,
                TO_CHAR(B.DT_PREVISTA_TERMINO, 'DD/MM/YYYY') AS data_previsao_termino_estagio,
                B.COD_INST_ENSINO,                
                B.COD_AGE_INTEGRACAO,
                B.COD_SUPERVISOR            
  FROM RHFP0300 A
  JOIN RHFP0302 B
    ON B.COD_CONTRATO = A.COD_CONTRATO
  JOIN JURIDICA D
    ON D.COD_PESSOA = B.COD_AGE_INTEGRACAO
 OUTER APPLY (SELECT H.COD_ORGANOGRAMA
                FROM RHFP0310 H
               WHERE H.COD_CONTRATO = A.COD_CONTRATO
               ORDER BY NVL(H.DATA_FIM, DATE '9999-12-31') DESC,
                        H.DATA_INICIO DESC
               FETCH FIRST 1 ROW ONLY) HIST

  LEFT JOIN RHFP0401 ORG
    ON ORG.COD_ORGANOGRAMA = HIST.COD_ORGANOGRAMA    
  
 WHERE ORG.COD_NIVEL2 IS NOT NULL
 AND A.DATA_INICIO <= '19/01/2026' --DATA DE CORTE
 ORDER BY A.COD_CONTRATO
 
),

SUPERVISOR AS (
SELECT DISTINCT A.COD_SUPERVISOR,
                B.COD_CONTRATO AS CONTRATO_SUPERVISOR,
                C.CPF AS CPF_SUPERVISOR,
                C.NOME_PESSOA,
                ORG1.COD_NIVEL2 AS EMPRESA_SUPERVISOR
  FROM RHFP0302 A
  LEFT JOIN RHFP0300 B
    ON A.COD_SUPERVISOR = B.COD_FUNC
  LEFT JOIN PESSOA_FISICA C
    ON A.COD_SUPERVISOR = C.COD_PESSOA
 OUTER APPLY (SELECT H1.COD_ORGANOGRAMA
                FROM RHFP0310 H1
               WHERE H1.COD_CONTRATO = B.COD_CONTRATO
               ORDER BY NVL(H1.DATA_FIM, DATE '9999-12-31') DESC,
                        H1.DATA_INICIO DESC
               FETCH FIRST 1 ROW ONLY) HIST1
  LEFT JOIN RHFP0401 ORG1
    ON ORG1.COD_ORGANOGRAMA = HIST1.COD_ORGANOGRAMA

)
 
SELECT DISTINCT A.COD_NIVEL2                    AS "codigo_empresa",
                A.tipo_colaborador              AS "tipo_colaborador",
                A.COD_CONTRATO                  AS "cadastro_colaborador",
                A.data_referencia               AS "data_referencia",
                A.NAT_ESTAGIO                   AS "natureza_estagio",
                A.NIV_ESTAGIO                   AS "nivel_estagio",
                A.AREA_ATUACAO                  AS "area_atuacao_estagio",
                A.NR_APOLICE                    AS "apolice_seguro",
                A.VLR_BOLSA                     AS "valor_bolsa",
                A.data_previsao_termino_estagio AS "data_previsao_termino_estagio",
                A.COD_INST_ENSINO               AS "instituicao_ensino",
                A.COD_AGE_INTEGRACAO            AS "agente_integracao",
                
                /*SUPERVISOR*/
                B.EMPRESA_SUPERVISOR  as "empresa_supervisor",
                1                     as "tipo_supervisor",
                B.CONTRATO_SUPERVISOR AS "cadastro_supervisor",
                b.NOME_PESSOA         AS "nome_supervisor",
                B.CPF_SUPERVISOR      AS "cpf_supervisor"
  FROM ESTAGIARIOS A
  JOIN SUPERVISOR B
    ON A.COD_SUPERVISOR = B.COD_SUPERVISOR
  --ORDER BY A.COD_CONTRATO
