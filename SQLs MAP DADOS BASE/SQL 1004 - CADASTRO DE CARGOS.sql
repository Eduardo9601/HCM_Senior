
/* ===================================
   == SQL 1004 - CADASTRO DE CARGOS ==
   =================================== */
   --AJUSTANDO



SELECT 
    1 AS codigo_estrutura_cargos,                            -- estrutura fixa = 1 (conforme layout)
    TO_CHAR(COD_CLH) AS codigo_cargo,             -- código do cargo
    -- TÍTULO REDUZIDO (OBRIGATÓRIO, 30)
    CASE 
        WHEN LENGTH(NOME_CLH) <= 30 THEN
            NOME_CLH
        ELSE
            SUBSTR(
                TRIM(
                    REGEXP_REPLACE(
                        -- abreviações básicas
                        REPLACE(
                        REPLACE(
                        REPLACE(
                        REPLACE(
                        REPLACE(
                            NOME_CLH,
                            'ASSISTENTE', 'ASSIST.'
                        ),
                            'AUXILIAR', 'AUX.'
                        ),
                            'ANALISTA', 'ANAL.'
                        ),
                            'ADMINISTRATIVO', 'ADM.'
                        ),
                            'FINANCEIRO', 'FIN.'
                        ),
                        -- remove artigos/conectivos: DE, DA, DO, DAS, DOS, E, EM
                        '\b(DE|DA|DO|DAS|DOS|E|EM)\b',
                        '',
                        1, 0, 'i'
                    )
                ),
                1,
                30
            )
    END AS titulo_reduzido,

    -- TÍTULO COMPLETO (NÃO obrigatório, 60)
	
;;;;;;;;;

    CASE 
        WHEN LENGTH(NOME_CLH) <= 60 THEN
            NOME_CLH
        ELSE
            SUBSTR(NOME_CLH, 1, 60)
    END AS titulo_completo,

    COD_CBO_2002 AS numero_cbo_2002,
    NULL      AS data_criacao,
    NULL         AS data_extincao,
    'N'         AS cnh_obrigatorio,
    'N'         AS OCLOBR,
    NULL         AS sigla_conselho_profissional

FROM RHFP0500;



----------

-- ===========================================
-- Script: cargos_sem_padding.sql
-- Saída: linhas delimitadas por ';' (coluna única concatenada)
-- Pasta: G:\HCM_SENIOR\Arquivos_Gerados
-- Nome: cargos_YYYYMMDD_HHMM.csv
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
SPOOL "G:\HCM_SENIOR\Arquivos_Gerados\cargos_&dt_csv..csv"

-- ====== Cabeçalho (primeira linha) ======
PROMPT codigo_estrutura_cargos;codigo_cargo;titulo_reduzido;titulo_completo;numero_cbo_2002;data_criacao;data_extincao;cnh_obrigatorio;OCLOBR;sigla_conselho_profissional
-- ====== Consulta (coluna única com ';') ======
SELECT
       /* codigo_estrutura_cargos (fixo=1) */ '1' || ';' ||
       /* codigo_cargo */          TRIM(TO_CHAR(COD_CLH)) || ';' ||
       /* titulo_reduzido (reduzido máx 30, com abreviações e remoção de conectivos) */
       TRIM(
         CASE
           WHEN LENGTH(NOME_CLH) <= 30 THEN NOME_CLH
           ELSE SUBSTR(
                  TRIM(
                    REGEXP_REPLACE(
                      REPLACE(
                      REPLACE(
                      REPLACE(
                      REPLACE(
                      REPLACE(
                        NOME_CLH,
                        'ASSISTENTE',    'ASSIST.'
                      ),
                        'AUXILIAR',      'AUX.'
                      ),
                        'ANALISTA',      'ANAL.'
                      ),
                        'ADMINISTRATIVO','ADM.'
                      ),
                        'FINANCEIRO',    'FIN.'
                      ),
                      '\b(DE|DA|DO|DAS|DOS|E|EM)\b',  -- remove artigos/conectivos
                      '',
                      1, 0, 'i'
                    )
                  ),
                  1,
                  30
                )
         END
       ) || ';' ||
       /* titulo_completo (completo máx 60) */
       TRIM(
         CASE
           WHEN LENGTH(NOME_CLH) <= 60 THEN NOME_CLH
           ELSE SUBSTR(NOME_CLH, 1, 60)
         END
       ) || ';' ||
       /* numero_cbo_2002 */
       TRIM(NVL(TO_CHAR(COD_CBO_2002), '')) || ';' ||
       /* data_criacao (formato texto YYYY-MM-DD) */
        TRIM(NVL(NULL, '')) || ';' ||
       /* data_extincao */
       TRIM(NVL(NULL, '')) || ';' ||
       /* cnh_obrigatorio */
       TRIM(NVL('N', '')) || ';' ||
       /* OCLOBR */
       TRIM(NVL('N', '')) || ';' ||
       /* sigla_conselho_profissional */
       TRIM(NVL(NULL, ''))
FROM RHFP0500;

-- ====== Finalização ======
SPOOL OFF
SET TERMOUT ON


