/*=== 1027 - HISTÓRICO E-SOCIAL === */

--DE ACORDO COM AS CATEGORIAS DO E-SOCIAL, ESTE BUSCA TODO O HISTÓRICO DE CADA FUNCIONARIO
----------------------------------------------------

/*VERSÃO DEFINITIVA*/

SELECT DISTINCT
       A.COD_EMPRESA     AS "codigo_empresa",
       1                 AS "tipo_colaborador",
       A.COD_CONTRATO    AS "cadastro_colaborador",
       B.DATA_REFERENCIA AS "data_alteracao",
       A.COD_CATEG       AS "categoria_colaborador"
  FROM RHES1201 A
  JOIN RHFP1003 B ON B.COD_MESTRE_EVENTO = A.COD_MESTRE_EVENTO
  JOIN RHFP0300 C ON C.COD_CONTRATO = A.COD_CONTRATO
  WHERE C.DATA_INICIO <= '19/01/2026' --DATA DE CORTE
  --AND C.COD_CONTRATO = 389622
 ORDER BY B.DATA_REFERENCIA
