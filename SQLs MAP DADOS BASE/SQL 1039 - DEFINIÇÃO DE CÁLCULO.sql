/*=== SQL 1039 - DEFINIÇÃO DE CÁLCULO ===*/


/*=== 1039 - DEFINIÇÃO DE CÁLCULO ===*/

SELECT Q."codigo_empresa",
       Q."codigo_calculo",
       Q."tipo_calculo",
       Q."competencia_calculo",
       Q."data_pagamento",
       Q."data_inicio_folha",
       Q."data_fim_folha",
       Q."codigo_origem_complementar",
       Q."data_inicio_apuracao",
       Q."data_fim_apuracao"
  FROM (SELECT DISTINCT ORG.COD_NIVEL2 AS "codigo_empresa",
                        A.COD_MESTRE_EVENTO AS "codigo_calculo",
                                            
                        CASE
                          WHEN B.COD_EVENTO = 1 THEN
                           11
                          WHEN B.COD_EVENTO = 2 THEN
                           CASE
                             WHEN EXTRACT(DAY FROM A.DATA_INI_MOV) <= 15 THEN
                              41
                             ELSE
                              42
                           END                          
                          WHEN B.COD_EVENTO = 3 THEN
                           21
                          WHEN B.COD_EVENTO IN (4, 5) THEN
                           22
                          WHEN B.COD_EVENTO = 7 THEN
                           23
                          WHEN B.COD_EVENTO IN(6, 8) THEN
                           12
                          WHEN B.COD_EVENTO = 9 THEN
                           92
                          WHEN B.COD_EVENTO = 10 THEN
                           91
                          WHEN B.COD_EVENTO = 12 THEN                            
                           31                           
                          WHEN B.COD_EVENTO IN (11, 13) THEN
                           32
                          WHEN B.COD_EVENTO IN (19, 20) THEN
                           15 
                          ELSE                           
                           93
                        END AS "tipo_calculo",
                        
                        LPAD(EXTRACT(MONTH FROM TRUNC(A.DATA_REFERENCIA)), 2, '0')
                        || '/' ||
                        TO_CHAR(EXTRACT(YEAR FROM TRUNC(A.DATA_REFERENCIA))) AS "competencia_calculo",
                        --UNISTR('\200B') || TO_CHAR(TRUNC(A.DATA_REFERENCIA), 'MM/YYYY') AS "competencia_calculo",
                        TO_CHAR(A.DATA_PAGAMENTO, 'DD/MM/YYYY') AS "data_pagamento",
                        TO_CHAR(A.DATA_INI_MOV, 'DD/MM/YYYY') AS "data_inicio_folha",
                        TO_CHAR(A.DATA_FIM_MOV, 'DD/MM/YYYY') AS "data_fim_folha",
                        0 AS "codigo_origem_complementar",
                        TO_CHAR(A.DATA_INI_MOV, 'DD/MM/YYYY') AS "data_inicio_apuracao",
                        TO_CHAR(A.DATA_FIM_MOV, 'DD/MM/YYYY') AS "data_fim_apuracao",
                        
                        /* COLUNAS TÉCNICAS SÓ PRA ORDENAÇÃO (NÃO VÃO PRO ARQUIVO) */
                        TRUNC(A.DATA_REFERENCIA, 'MM') AS ORD_MES,
                        TRUNC(A.DATA_REFERENCIA) AS ORD_REF,
                        TRUNC(A.DATA_INI_MOV) AS ORD_INI
          FROM RHFP1003 A
          JOIN RHFP1002 B
            ON B.COD_EVENTO = A.COD_EVENTO
          LEFT JOIN RHFP0401 ORG
            ON ORG.COD_ORGANOGRAMA = A.COD_ORGANOGRAMA
         WHERE ORG.COD_NIVEL2 IS NOT NULL
           AND B.COD_EVENTO NOT IN (15, 16, 17, 19, 21, 22, 23, 25, 26)) Q 
 ORDER BY Q.ORD_MES, Q.ORD_REF, Q.ORD_INI, Q."codigo_calculo";
