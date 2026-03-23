/* ====================================
   == SQL 1011 - CADASTRO DE BAIRROS ==
   ==================================== */
   
   

SELECT
    m.cod_ibge     AS codigo_cidade,
    pf.nome_munic  AS nome_cidade,
    pf.cod_uf,
    pf.cod_bairro  AS codigo_bairro,
    pf.nome_bairro,
    pf.cep         AS cep_bairro
   
FROM pessoa_fisica pf
LEFT JOIN grz_folha.munibge m
       ON UPPER(m.nome_munic) = UPPER(pf.nome_munic)
     -- AND m.cod_uf = pf.cod_uf
WHERE pf.cod_munic > 0
and NOME_bairro is not null
GROUP BY
    pf.nome_munic,
    pf.cod_uf,
    pf.cod_bairro,
    pf.nome_bairro,
    pf.cep,
    m.cod_ibge
ORDER BY 1;




-- ===========================================
-- Script: bairros_sem_padding.sql
-- Saída: linhas delimitadas por ';' (coluna única concatenada, sem espaços extras)
-- Pasta: G:\HCM_SENIOR\Arquivos_Gerados
-- Nome: bairros_YYYYMMDD_HHMM.csv
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
SPOOL "G:\HCM_SENIOR\Arquivos_Gerados\bairros_IBGE_&dt_csv..csv"

-- ====== Cabeçalho (primeira linha) ======
PROMPT CODIGO_CIDADE;NOME_CIDADE;COD_UF;CODIGO_BAIRRO;NOME_BAIRRO;CEP_BAIRRO

-- ====== Consulta (coluna única com ';') ======
SELECT linha
FROM (
    SELECT DISTINCT
           /* coluna única concatenada para exportação */
           TRIM(NVL(TO_CHAR(m.cod_ibge), ''))      || ';' ||
           TRIM(NVL(pf.nome_munic, ''))            || ';' ||
           TRIM(NVL(TO_CHAR(pf.cod_uf), ''))       || ';' ||
           TRIM(NVL(TO_CHAR(pf.cod_bairro), ''))   || ';' ||
           TRIM(NVL(pf.nome_bairro, ''))           || ';' ||
           TRIM(NVL(TO_CHAR(pf.cep), ''))          AS linha,
           /* colunas auxiliares usadas apenas para ordenação externa */
           m.cod_ibge       AS ord_cod_ibge,
           pf.nome_munic    AS ord_nome_munic,
           pf.cod_bairro    AS ord_cod_bairro
    FROM pessoa_fisica pf
    LEFT JOIN munibge m
           -- comparação acento/caixa-insensível
           ON NLSSORT(m.nome_munic, 'NLS_SORT=BINARY_AI') = NLSSORT(pf.nome_munic, 'NLS_SORT=BINARY_AI')
          -- AND m.cod_uf = pf.cod_uf  -- recomendo manter se houver homônimos em UFs diferentes
    WHERE pf.cod_munic > 0
      AND pf.nome_bairro IS NOT NULL

)
ORDER BY
    ord_cod_ibge,
    ord_nome_munic,
    ord_cod_bairro;

-- ====== Finalização ======
SPOOL OFF
SET TERMOUT ON