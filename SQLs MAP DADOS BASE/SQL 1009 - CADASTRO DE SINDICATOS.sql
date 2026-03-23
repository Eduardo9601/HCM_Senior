/* =======================================
   == SQL 1009 - CADASTRO DE SINDICATOS ==
   ======================================= */
   
  
   

SELECT
       A.COD_SINDICATO              AS codigo,
       C.NOME_PESSOA                AS nome,
       'AJUSTAR'                    AS sigla,
       B.CGC                        AS numero_cnpj,
       A.MES_BASE_DISSIDIO          AS mes_data_base,
       A.COD_ENTIDADE_SIND          AS codigo_entidade,
       D.NOME_LOGRA                 AS endereco,
       B.NUMERO                     AS numero_endereco, 
       B.COMPLEMENTO                AS complemento_endereco,
       /* CODIGO_IBGE (com fallback) */
       COALESCE(M.COD_IBGE, B.COD_MUNIC) AS codigo_cidade,
       B.CEP                        AS codigo_cep,
       NULL                         AS entidade_sindical_alfa
FROM RHFP0329 A 
JOIN JURIDICA B
     ON B.COD_PESSOA = A.COD_PESSOA   and b.cgc is not null
JOIN PESSOA C
     ON C.COD_PESSOA = A.COD_PESSOA
    AND C.COD_PESSOA = B.COD_PESSOA
LEFT JOIN LOGRA D
       ON D.COD_LOGRA = B.COD_LOGRA
/* Mapeia COD_MUNIC -> (NOME_MUNIC, UF) a partir da PESSOA_FISICA (deduplicado) */
LEFT JOIN (
    SELECT DISTINCT
           PF.COD_MUNIC,
           PF.COD_UF,
           PF.NOME_MUNIC
    FROM PESSOA_FISICA PF
    WHERE PF.COD_MUNIC IS NOT NULL
) PF_MUNI
       ON PF_MUNI.COD_MUNIC = B.COD_MUNIC
/* Casa com a tabela IBGE ignorando acentos/caixa e considerando UF */
LEFT JOIN MUNIBGE M
       ON NLSSORT(M.NOME_MUNIC, 'NLS_SORT=BINARY_AI') = NLSSORT(PF_MUNI.NOME_MUNIC, 'NLS_SORT=BINARY_AI')
      AND M.COD_UF = PF_MUNI.COD_UF
    
ORDER BY A.COD_SINDICATO;



-- ===========================================
-- Script: sindicatos_sem_padding.sql
-- Saída: linhas delimitadas por ';' (coluna única concatenada, sem espaços extras)
-- Pasta: G:\HCM_SENIOR\Arquivos_Gerados
-- Nome: sindicatos_YYYYMMDD_HHMM.csv
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
SPOOL "G:\HCM_SENIOR\Arquivos_Gerados\sindicatos_&dt_csv..csv"

-- ====== Cabeçalho (primeira linha) ======
PROMPT CODIGO;NOME;SIGLA;NUMERO_CNPJ;MES_DATA_BASE;CODIGO_ENTIDADE;ENDERECO;NUMERO_ENDERECO;COMPLEMENTO_ENDERECO;CODIGO_CIDADE;CODIGO_CEP;ENTIDADE_SINDICAL_ALFA

-- ====== Consulta (coluna única com ';') ======
SELECT
       /* CODIGO              */ TRIM(NVL(TO_CHAR(A.COD_SINDICATO), ''))                || ';' ||
       /* NOME                */ TRIM(NVL(C.NOME_PESSOA, ''))                           || ';' ||
       /* SIGLA               */ TRIM(NVL('AJUSTAR', ''))                                || ';' ||
       /* NUMERO_CNPJ         */ TRIM(NVL(B.CGC, ''))                                   || ';' ||
       /* MES_DATA_BASE       */ TRIM(NVL(TO_CHAR(A.MES_BASE_DISSIDIO), ''))            || ';' ||
       /* CODIGO_ENTIDADE     */ TRIM(NVL(TO_CHAR(
                                         CASE 
                                           WHEN A.COD_ENTIDADE_SIND IS NOT NULL 
                                            AND REGEXP_LIKE(TRIM(A.COD_ENTIDADE_SIND), '^\d+$')
                                           THEN TO_NUMBER(TRIM(A.COD_ENTIDADE_SIND))
                                           ELSE NULL
                                         END), ''))                                     || ';' ||
       /* ENDERECO            */ TRIM(NVL(D.NOME_LOGRA, ''))                            || ';' ||
       /* NUMERO_ENDERECO     */ TRIM(NVL(TO_CHAR(B.NUMERO), ''))                       || ';' ||
       /* COMPLEMENTO_ENDERECO*/ TRIM(NVL(B.COMPLEMENTO, ''))                           || ';' ||
       /* CODIGO_CIDADE       */ TRIM(NVL(TO_CHAR(COALESCE(M.COD_IBGE, B.COD_MUNIC)), '')) || ';' ||
       /* CODIGO_CEP          */ TRIM(NVL(TO_CHAR(B.CEP), ''))                          || ';' ||
       /* ENTIDADE_SINDICAL_ALFA */ TRIM(NVL(NULL, ''))                                 AS linha
FROM RHFP0329 A 
JOIN JURIDICA B
     ON B.COD_PESSOA = A.COD_PESSOA
    AND B.CGC IS NOT NULL
JOIN PESSOA C
     ON C.COD_PESSOA = A.COD_PESSOA
    AND C.COD_PESSOA = B.COD_PESSOA
LEFT JOIN LOGRA D
       ON D.COD_LOGRA = B.COD_LOGRA
/* Mapeia COD_MUNIC -> (NOME_MUNIC, UF) a partir da PESSOA_FISICA (deduplicado) */
LEFT JOIN (
    SELECT DISTINCT
           PF.COD_MUNIC,
           PF.COD_UF,
           PF.NOME_MUNIC
    FROM PESSOA_FISICA PF
    WHERE PF.COD_MUNIC IS NOT NULL
) PF_MUNI
       ON PF_MUNI.COD_MUNIC = B.COD_MUNIC
/* Casa com a tabela IBGE ignorando acentos/caixa e considerando UF */
LEFT JOIN MUNIBGE M
       ON NLSSORT(M.NOME_MUNIC, 'NLS_SORT=BINARY_AI') = NLSSORT(PF_MUNI.NOME_MUNIC, 'NLS_SORT=BINARY_AI')
      AND M.COD_UF = PF_MUNI.COD_UF
ORDER BY A.COD_SINDICATO;

-- ====== Finalização ======
SPOOL OFF
SET TERMOUT ON