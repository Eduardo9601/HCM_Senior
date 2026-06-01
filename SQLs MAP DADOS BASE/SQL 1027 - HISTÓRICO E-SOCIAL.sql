/*=== 1027 - HISTÓRICO E-SOCIAL === */

--DE ACORDO COM AS CATEGORIAS DO E-SOCIAL, ESTE BUSCA TODO O HISTÓRICO DE CADA FUNCIONARIO
----------------------------------------------------

/*VERSÃO DEFINITIVA*/


/*VERSÃO ORIGINAL*/
SELECT *
FROM (
    SELECT DISTINCT
           A.COD_EMPRESA     AS "codigo_empresa",
           1                 AS "tipo_colaborador",
           A.COD_CONTRATO    AS "cadastro_colaborador",
           C.DATA_AVANCO     AS "data_alteracao",
           A.COD_CATEG       AS "categoria_colaborador",

           COUNT(DISTINCT A.COD_CATEG) OVER (
               PARTITION BY A.COD_CONTRATO
           ) AS "qtd_categorias_contrato"

      FROM RHES1201 A
      JOIN RHFP1003 B 
        ON B.COD_MESTRE_EVENTO = A.COD_MESTRE_EVENTO
      JOIN RHFP0300 C 
        ON C.COD_CONTRATO = A.COD_CONTRATO
     WHERE C.DATA_AVANCO < DATE '2026-04-23'
)
ORDER BY "data_alteracao";




/*VERSÃO OFICIAL AJUSTADO*/
WITH BASE AS (
    SELECT DISTINCT
           O2.COD_NIVEL2      AS codigo_empresa,
           1                 AS tipo_colaborador,
           C.COD_CONTRATO    AS cadastro_colaborador,
           C.DATA_AVANCO     AS data_alteracao,
           G.COD_ESOCIAL     AS categoria_colaborador,

           MAX(CASE WHEN G.COD_ESOCIAL = 101 THEN 1 ELSE 0 END) OVER (
               PARTITION BY C.COD_CONTRATO
           ) AS TEM_101,

           MAX(CASE WHEN G.COD_ESOCIAL = 103 THEN 1 ELSE 0 END) OVER (
               PARTITION BY C.COD_CONTRATO
           ) AS TEM_103

      FROM RHFP0300 C 
      JOIN RHFP0128 G      
        ON C.COD_CATEGORIA_TRAB = G.COD_CATEGORIA_TRAB
      JOIN RHFP0310 O
        ON O.COD_CONTRATO = C.COD_CONTRATO
      JOIN RHFP0401 O2
        ON O2.COD_ORGANOGRAMA = O.COD_ORGANOGRAMA
     WHERE C.DATA_AVANCO < DATE '2026-04-23'
       --AND C.COD_CONTRATO = 352683
)

/*TRATADO AS (
    SELECT B.*,
           ROW_NUMBER() OVER (
               PARTITION BY B.cadastro_colaborador, B.data_alteracao
               ORDER BY 
                   CASE 
                       WHEN B.TEM_101 = 1 
                        AND B.TEM_103 = 1 
                        AND B.categoria_colaborador = 101 
                       THEN 1

                       WHEN B.TEM_101 = 1 
                        AND B.TEM_103 = 1 
                        AND B.categoria_colaborador = 103 
                       THEN 2

                       ELSE 1
                   END
           ) AS RN
      FROM BASE B
)*/

SELECT codigo_empresa        AS "codigo_empresa",
       tipo_colaborador      AS "tipo_colaborador",
       cadastro_colaborador  AS "cadastro_colaborador",
       data_alteracao        AS "data_alteracao",
       categoria_colaborador AS "categoria_colaborador"
  FROM BASE
 WHERE CADASTRO_COLABORADOR = 352683
 ORDER BY cadastro_colaborador, data_alteracao;