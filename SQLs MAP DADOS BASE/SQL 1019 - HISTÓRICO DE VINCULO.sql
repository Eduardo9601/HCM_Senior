/* == 1019 - HISTÓRICO DE VÍNCULO ==
   =============================== */


SELECT DISTINCT /* 1) CODIGO_EMPRESA VIGENTE NA DATA DA ADMISSÃO */
                ORG.COD_NIVEL2 AS "codigo_empresa",
                1 AS "tipo_colaborador",
                CT.COD_CONTRATO AS "cadastro_colaborador",
                TO_CHAR(CT.DATA_AVANCO, 'DD/MM/YYYY') AS "data_alteracao",
                NVL(CT.COD_VINCULO_EMPREG, 0) AS "codigo_vinculo"
  FROM V_DADOS_CONTRATO_AVT CT
 OUTER APPLY (
              /* RETORNA TODOS OS ORGANOGRAMAS DO CONTRATO */
              SELECT H.COD_ORGANOGRAMA
                FROM RHFP0310 H
               WHERE H.COD_CONTRATO = CT.COD_CONTRATO) HIST
  LEFT JOIN RHFP0401 ORG
    ON ORG.COD_ORGANOGRAMA = HIST.COD_ORGANOGRAMA
 WHERE ORG.COD_NIVEL2 IS NOT NULL
   AND CT.DATA_AVANCO < DATE '2026-04-23' -- DATA DE CORTE
 ORDER BY CT.COD_CONTRATO,
          TO_CHAR(CT.DATA_AVANCO, 'DD/MM/YYYY'),
          ORG.COD_NIVEL2;
