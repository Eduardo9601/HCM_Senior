/* ====================================================================
   == SQL 1006 - CADASTRO DE MOTIVOS DE ALTERAÇÃO DE CARGOS/SALÁRIOS ==
   ==================================================================== */
   

   
SELECT A.COD_MOTIVO AS CODMOT,
       A.NOME_MOTIVO AS NOMMOT,
       B.NOME_TIPO_MOTIVO AS TIPMOT,
       A.COD_TIPO_MOTIVO AS MTVALT,
       NULL AS TIPOMVT
FROM RHFP0323 A
JOIN RHFP0115 B ON A.COD_TIPO_MOTIVO = B.COD_TIPO_MOTIVO
WHERE A.COD_TIPO_MOTIVO = 1




---

-- ===========================================
-- Script: motivos_sem_padding.sql
-- Saída: linhas delimitadas por ';' (coluna única concatenada)
-- Pasta: G:\HCM_SENIOR\Arquivos_Gerados
-- Nome: motivos_YYYYMMDD_HHMM.csv
-- Filtro: A.COD_TIPO_MOTIVO = 1
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

-- ====== Sem cabeçalho automático ======
SET HEADING OFF

-- ====== Nome dinâmico ======
COLUMN dt_csv NEW_VALUE dt_csv
SELECT TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MI') AS dt_csv FROM dual;

-- ====== Spool ======
SPOOL "G:\HCM_SENIOR\Arquivos_Gerados\motivos_&dt_csv..csv"

-- ====== Cabeçalho (primeira linha) ======
PROMPT CODMOT;NOMMOT;TIPMOT;MTVALT;TIPOMVT

-- ====== Consulta (coluna única com ';') ======
SELECT
       /* CODMOT  */ TRIM(TO_CHAR(A.COD_MOTIVO))       || ';' ||
       /* NOMMOT  */ TRIM(NVL(A.NOME_MOTIVO, ''))      || ';' ||
       /* TIPMOT  */ TRIM(NVL(B.NOME_TIPO_MOTIVO, '')) || ';' ||
       /* MTVALT  */ TRIM(TO_CHAR(A.COD_TIPO_MOTIVO))  || ';' ||
       /* TIPOMVT */ TRIM(NVL(NULL, ''))
FROM RHFP0323 A
INNER JOIN RHFP0115 B
        ON A.COD_TIPO_MOTIVO = B.COD_TIPO_MOTIVO
WHERE A.COD_TIPO_MOTIVO = 1
ORDER BY A.COD_MOTIVO;

-- ====== Finalização ======
SPOOL OFF
SET TERMOUT ON
