/* =====================================
   == SQL 1008 - CADASTRO DE AGÊNCIAS ==
   ===================================== */
 ---NOME AGENNCIA, UF E CIDADE NÃO EXISTE POIS NUNCA FOI CADASTRADO  
 
SELECT B.COD_BANCO AS CODBAN,
       A.COD_AGENCIA AS CODAGE,
	   SUBSTR(D.NOME_PESSOA, 1, 30) NOMAGE,
       'RS' AS CODEST,--NAO TEM CADASTRO
       '4314100'  AS CODCID,--NAO TEM CADASTRO
       A.DIGITO AS DIGAGE
FROM AGENCIA A 
JOIN BANCO B ON B.COD_BANCO = A.COD_BANCO
JOIN JURIDICA C ON C.COD_PESSOA = A.COD_PESSOA
LEFT JOIN PESSOA D ON D.COD_PESSOA = A.COD_PESSOA

ORDER BY B.COD_BANCO, A.COD_AGENCIA










-- ===========================================
-- Script: agencias_sem_padding.sql
-- Saída: linhas delimitadas por ';' (coluna única concatenada)
-- Pasta: G:\HCM_SENIOR\Arquivos_Gerados
-- Nome: agencias_YYYYMMDD_HHMM.csv
-- ===========================================

-- ====== Performance / limpeza ======
SET TERMOUT OFF
SET FEEDBACK OFF
SET VERIFY OFF
SET PAUSE OFF

-- ====== Formatação ======
SET LINESIZE 32767
SET TRIMSPOOL ON
SET TRIMOUT ON
SET TAB OFF
SET PAGESIZE 1000000
SET NEWPAGE 0

-- ====== Sem cabeçalho ======
SET HEADING OFF

-- ====== Nome dinâmico ======
COLUMN dt_csv NEW_VALUE dt_csv
SELECT TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MI') AS dt_csv FROM dual;

-- ====== Spool ======
SPOOL "G:\HCM_SENIOR\Arquivos_Gerados\agencias_&dt_csv..csv"

-- ====== Cabeçalho (primeira linha) ======
PROMPT codigo_banco,codigo_agencia,nome_agencia,estado,codigo_cidade,digito_agencia 

-- ====== Consulta (coluna única com ';') ======
SELECT
       /*codigo_banco*/ TRIM(TO_CHAR(B.COD_BANCO))            || ';' ||
       /*codigo_agencia*/ TRIM(TO_CHAR(A.COD_AGENCIA))          || ';' ||
       /*nome_agencia*/ TRIM(NVL(SUBSTR(D.NOME_PESSOA, 1, 30), ''))       || ';' ||
       /*estado*/ TRIM(NVL('RS', ''))               || ';' ||
       /*codigo_cidade*/ TRIM(NVL(TO_CHAR('4314100'), ''))   || ';' ||
       /*digito_agencia*/ TRIM(NVL(TO_CHAR(A.DIGITO), ''))
FROM AGENCIA   A
JOIN BANCO     B ON B.COD_BANCO  = A.COD_BANCO
JOIN JURIDICA  C ON C.COD_PESSOA = A.COD_PESSOA
LEFT JOIN PESSOA D ON D.COD_PESSOA = A.COD_PESSOA
ORDER BY B.COD_BANCO, A.COD_AGENCIA;

-- ====== Finalização ======
SPOOL OFF
SET TERMOUT ON
