/* ===================================
   == SQL 1007 - CADASTRO DE BANCOS ==
   =================================== */
   
 
SELECT
       A.COD_BANCO      AS CODIGO_BANCO,
       SUBSTR(C.NOME_PESSOA, 1, 30) AS NOME_BANCO
FROM BANCO A 
JOIN JURIDICA B ON B.COD_PESSOA = A.COD_PESSOA
LEFT JOIN PESSOA C ON C.COD_PESSOA = B.COD_PESSOA
ORDER BY A.COD_BANCO;




-- ===========================================
-- Script: bancos_sem_padding.sql
-- Saída: linhas delimitadas por ';' (coluna única concatenada)
-- Pasta: G:\HCM_SENIOR\Arquivos_Gerados
-- Nome: bancos_YYYYMMDD_HHMM.csv
-- ===========================================

-- Performance / limpeza
SET TERMOUT OFF
SET FEEDBACK OFF
SET VERIFY OFF
SET PAUSE OFF

-- Formatação
SET LINESIZE 32767
SET TRIMSPOOL ON
SET TRIMOUT ON
SET TAB OFF
SET PAGESIZE 1000000
SET NEWPAGE 0

-- Sem cabeçalho automático
SET HEADING OFF

-- Nome dinâmico
COLUMN dt_csv NEW_VALUE dt_csv
SELECT TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MI') AS dt_csv FROM dual;

-- Spool
SPOOL "G:\HCM_SENIOR\Arquivos_Gerados\bancos_&dt_csv..csv"

-- Cabeçalho (primeira linha)
PROMPT CODIGO_BANCO;NOME_BANCO

-- Consulta (coluna única com ';')
SELECT
       /* CODIGO_BANCO */ TRIM(NVL(TO_CHAR(A.COD_BANCO), '')) || ';' ||
       /* NOME_BANCO */ TRIM(NVL(SUBSTR(C.NOME_PESSOA, 1, 30), '')) AS linha
FROM BANCO A
JOIN JURIDICA B ON B.COD_PESSOA = A.COD_PESSOA
LEFT JOIN PESSOA C ON C.COD_PESSOA = B.COD_PESSOA
ORDER BY A.COD_BANCO;

-- Finalização
SPOOL OFF
SET TERMOUT ON
