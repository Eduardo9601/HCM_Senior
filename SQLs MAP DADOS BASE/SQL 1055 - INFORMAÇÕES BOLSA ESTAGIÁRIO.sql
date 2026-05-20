/*=== SQL 1055 - INFORMAÇÕES BOLSA ESTAGIÁRIO ===*/

WITH
PARAM AS (
    SELECT DATE '2026-04-23' AS DT_CORTE FROM DUAL
),

ESTAGIARIOS AS (
    SELECT DISTINCT
           ORG.COD_NIVEL2,
           1 AS TIPO_COLABORADOR,
           A.COD_CONTRATO,
           TO_CHAR(A.DATA_INICIO, 'DD/MM/YYYY') AS DATA_REFERENCIA,
           B.NAT_ESTAGIO,
           B.NIV_ESTAGIO,
           B.AREA_ATUACAO,
           B.NR_APOLICE,
           B.VLR_BOLSA,
           TO_CHAR(B.DT_PREVISTA_TERMINO, 'DD/MM/YYYY') AS DATA_PREVISAO_TERMINO_ESTAGIO,
           B.COD_INST_ENSINO,
           B.COD_AGE_INTEGRACAO,
           B.COD_SUPERVISOR
      FROM RHFP0300 A
      JOIN RHFP0302 B
        ON B.COD_CONTRATO = A.COD_CONTRATO
      JOIN JURIDICA D
        ON D.COD_PESSOA = B.COD_AGE_INTEGRACAO
     CROSS JOIN PARAM P

     OUTER APPLY (
         SELECT H.COD_ORGANOGRAMA
           FROM RHFP0310 H
          WHERE H.COD_CONTRATO = A.COD_CONTRATO
          ORDER BY NVL(H.DATA_FIM, DATE '9999-12-31') DESC,
                   H.DATA_INICIO DESC
          FETCH FIRST 1 ROW ONLY
     ) HIST

      LEFT JOIN RHFP0401 ORG
        ON ORG.COD_ORGANOGRAMA = HIST.COD_ORGANOGRAMA

     WHERE ORG.COD_NIVEL2 IS NOT NULL
       AND A.DATA_INICIO < P.DT_CORTE
),

SUPERVISOR_BASE AS (
    SELECT
           A.COD_SUPERVISOR,
           B.COD_CONTRATO AS CONTRATO_SUPERVISOR,
           C.CPF AS CPF_SUPERVISOR,
           C.NOME_PESSOA,
           ORG1.COD_NIVEL2 AS EMPRESA_SUPERVISOR,

           ROW_NUMBER() OVER (
               PARTITION BY A.COD_SUPERVISOR
               ORDER BY
                   CASE 
                       WHEN B.DATA_FIM IS NULL THEN 0 
                       ELSE 1 
                   END,
                   NVL(B.DATA_FIM, DATE '9999-12-31') DESC,
                   NVL(B.DATA_INICIO, DATE '1900-01-01') DESC,
                   B.COD_CONTRATO DESC
           ) AS RN

      FROM RHFP0302 A

      LEFT JOIN RHFP0300 B
        ON B.COD_FUNC = A.COD_SUPERVISOR

      LEFT JOIN PESSOA_FISICA C
        ON C.COD_PESSOA = A.COD_SUPERVISOR

      OUTER APPLY (
          SELECT H1.COD_ORGANOGRAMA
            FROM RHFP0310 H1
           WHERE H1.COD_CONTRATO = B.COD_CONTRATO
           ORDER BY NVL(H1.DATA_FIM, DATE '9999-12-31') DESC,
                    H1.DATA_INICIO DESC
           FETCH FIRST 1 ROW ONLY
      ) HIST1

      LEFT JOIN RHFP0401 ORG1
        ON ORG1.COD_ORGANOGRAMA = HIST1.COD_ORGANOGRAMA

     WHERE A.COD_SUPERVISOR IS NOT NULL
),

SUPERVISOR AS (
    SELECT
           COD_SUPERVISOR,
           CONTRATO_SUPERVISOR,
           CPF_SUPERVISOR,
           NOME_PESSOA,
           EMPRESA_SUPERVISOR
      FROM SUPERVISOR_BASE
     WHERE RN = 1
)

SELECT
       A.COD_NIVEL2                    AS "codigo_empresa",
       A.TIPO_COLABORADOR              AS "tipo_colaborador",
       A.COD_CONTRATO                  AS "cadastro_colaborador",
       A.DATA_REFERENCIA               AS "data_referencia",
       A.NAT_ESTAGIO                   AS "natureza_estagio",
       A.NIV_ESTAGIO                   AS "nivel_estagio",
       A.AREA_ATUACAO                  AS "area_atuacao_estagio",
       A.NR_APOLICE                    AS "apolice_seguro",
       A.VLR_BOLSA                     AS "valor_bolsa",
       A.DATA_PREVISAO_TERMINO_ESTAGIO AS "data_previsao_termino_estagio",
       A.COD_INST_ENSINO               AS "instituicao_ensino",
       A.COD_AGE_INTEGRACAO            AS "agente_integracao",

       B.EMPRESA_SUPERVISOR            AS "empresa_supervisor",
       CASE 
           WHEN B.CONTRATO_SUPERVISOR IS NOT NULL THEN 1
           ELSE NULL
       END                             AS "tipo_supervisor",
       B.CONTRATO_SUPERVISOR           AS "cadastro_supervisor",
       B.NOME_PESSOA                   AS "nome_supervisor",
       B.CPF_SUPERVISOR                AS "cpf_supervisor"

  FROM ESTAGIARIOS A

  LEFT JOIN SUPERVISOR B
    ON B.COD_SUPERVISOR = A.COD_SUPERVISOR

 ORDER BY A.COD_CONTRATO;
