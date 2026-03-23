/*== MODELO EXEMPLO DE EXPORTAÇÃO DE DADOS DO SQL PARA CSV COM COMANDO SPOOL ==*/


SELECT DISTINCT
       COD_EMP AS NUMEMP,
       1 AS TIPCOL,
       COD_CONTRATO AS NUMCAD,
       --DES_PESSOA AS NOMFUM,
       SUBSTR(DES_PESSOA, 1, 40) AS NOMFUM,
       PRIMEIRO_NOME AS APEFUM,
       DATA_ADMISSAO AS DATADM,
       CASE
           WHEN DES_FUNCAO LIKE 'DIRETOR%' THEN
            2
           WHEN DES_FUNCAO LIKE '%ESTAGIARIO%' THEN
            5
           WHEN DES_FUNCAO LIKE '%APRENDIZ%' THEN 
            6
           /*WHEN DES_FUNCAO LIKE '%APRENDIZ%' THEN 
            7*/
           ELSE
            1
       END AS TIPCON,
       SEXO AS TIPSEX,
       CASE
           WHEN COD_EST_CIVIL = 1 THEN 
            COD_EST_CIVIL
           WHEN COD_EST_CIVIL = 2 THEN 
            COD_EST_CIVIL
           WHEN COD_EST_CIVIL = 3 THEN 
            6
           WHEN COD_EST_CIVIL = 4 THEN 
            3
           WHEN COD_EST_CIVIL = 5 THEN 
            4
           WHEN COD_EST_CIVIL = 6 THEN 
            7
           ELSE
            9            
       END AS ESTCIV,
       COD_INSTRUCAO AS GRAINS,
       DATA_NASCIMENTO AS DATNAS,
       COD_NACIONALIDADE AS CODNAC,
       NULL AS ANOCHE, --VALIDAR - Ñ ENCONTRATO NA BASE
       NULL AS VISEST, --VALIDAR - Ñ ENCONTRATO NA BASE
       NULL AS REGEST, --VALIDAR - Ñ ENCONTRATO NA BASE
       NULL AS DVLEST, --VALIDAR - Ñ ENCONTRATO NA BASE
       NULL AS DVLCTP, --VALIDAR - Ñ ENCONTRATO NA BASE
       NRO_CTPS AS NUMCTP,
       NRO_SERIE_CTPS AS SERCTP,
       DATA_EXP_CTPS AS DEXCTP,
       CPF AS NUMCPF,
       NRO_PIS_PASEP AS NUMPIS,
       NULL AS DCDPIS, --VALIDAR - Ñ ENCONTRATO NA BASE
       'N' AS PAGSIN,
       'R' AS MODPAG,
       COD_BANCO AS CODBAN,
       COD_AGE_PGTO AS CODAGE,
       NULL AS DIGBAN,
       COD_TIPO_APOSENT AS TIPAPO,
       DATA_APOSENTADORIA AS DATAPO,
       NULL AS OUTCON, --VALIDAR - Ñ ENCONTRATO NA BASE
       NULL AS OUTTET, --VALIDAR - Ñ ENCONTRATO NA BASE
       NULL AS DEFFIS,
       CASE
           WHEN COD_RACA_COR = 1 THEN
            5
           WHEN COD_RACA_COR = 2 THEN
            1
           WHEN COD_RACA_COR = 4 THEN
            2
           WHEN COD_RACA_COR = 6 THEN
            3
           WHEN COD_RACA_COR = 8 THEN
            4
           WHEN COD_RACA_COR = 9 THEN
            0
           ELSE
            NULL
       END AS RACCOR,
       COD_DEFICIENCIA,
       NULL AS CATSEF, --VALIDAR - Ñ ENCONTRATO NA BASE
       NULL AS MOVSEF, --VALIDAR - Ñ ENCONTRATO NA BASE
       'N' AS BENREA,
       NULL AS DOCEST, --VALIDAR - Ñ ENCONTRATO NA BASE
       3 AS TPCTBA,
       'N' AS APOIDA,
       DATA_CHEG_BRASIL AS DATCHE,
       CASE
          WHEN COD_UNIDADE IN (659,183,242,269,467,605) THEN
            'S'
           ELSE
            'N'
       END AS RECADI,
       'S' AS REC13S,
       'N' AS LISRAI,
       'S' AS EMICAR,
       '1' AS CONRHO,
       CASE
           WHEN COD_UNIDADE IN (659,183,242,269,467,605) THEN
            'Q'
           ELSE
            'M'
       END AS PERPAG,
       'S' AS TIPOPC,
       DATA_OPCAO_FGTS AS DATOPC,
       NRO_CONTA_FGTS AS CONFGT
       
FROM V_DADOS_COLAB_AVT
--where cod_contrato = 389622




-- ===========================================
-- Saída sem espaços antes do ';' (uma única coluna concatenada)
-- Ajustado para Oracle 12.1 (sem aliases longos) e corrigido ORA-01791
-- Pasta: G:\HCM_SENIOR\Arquivos_Gerados
-- Nome: colaboradores_YYYYMMDD_HHMM.csv
-- ===========================================

-- Performance / limpeza
SET TERMOUT OFF
SET FEEDBACK OFF
SET VERIFY OFF
SET PAUSE OFF

-- Formatação geral
SET LINESIZE 32767
SET TRIMSPOOL ON
SET TRIMOUT ON
SET TAB OFF
SET PAGESIZE 1000000
SET NEWPAGE 0
SET HEADING OFF    -- evita cabeçalho automático do SQL*Plus

-- Nome dinâmico com data/hora
COLUMN dt_csv NEW_VALUE dt_csv
SELECT TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MI') AS dt_csv FROM dual;

-- Spool
SPOOL "G:\HCM_SENIOR\Arquivos_Gerados\colaboradores_&dt_csv..csv"

-- Cabeçalho (primeira linha do arquivo) - nomes em minúsculo, ordem solicitada
PROMPT codigo_empresa;tipo_colaborador;cadastro_colaborador;nome_funcionario;apelido_funcionario;data_admissao;tipo_contrato;sexo;estado_civil;grau_instrucao;data_nascimento;codigo_nacionalidade;ano_chegada;classificacao_condicao_estrangeiro;carteira_estrangeiro;data_validade_carteira_estrangeiro;data_validade_carteira_trabalho;numero_carteira_trabalho;serie_carteira_trabalho;uf_carteira_trabalho;data_expedicao_carteira_trabalho;numero_cpf;numero_pis_pasep;data_cadastramento_pis_pasep;contribuicao_sindical_ano;modo_pagamento_salario;codigo_banco;codigo_agencia;conta_bancaria;digito_conta_bancaria;tipo_aposentadoria;data_aposentadoria;outro_contrato_trabalho;teto_inss_outro_contrato;deficiente;raca_cor;codigo_deficiencia;categoria_sefip;codigo_movimento_sefip;beneficiario_reabilitado;tipo_documento_estrangeiro;tipo_conta;aposentadoria_apenas_por_idade;data_chegada_brasil;recebe_adiantamento_salario;recebe_13_salario;lista_colaborador_rais;emitir_cartao_ponto;colaborador_considerado_calculo_ronda;periodo_pagamento;optante_fgts;data_opcao_fgts;conta_fgts;local_organograma;tabela_organograma

-- Consulta (uma coluna concatenada; sem aliases)
SELECT DISTINCT
    TRIM(TO_CHAR(COD_EMP)) || ';' ||
    TRIM(TO_CHAR(1)) || ';' ||
    TRIM(TO_CHAR(COD_CONTRATO)) || ';' ||
    --TRIM(NVL(DES_PESSOA, '')) || ';' ||
    TRIM(NVL(SUBSTR(DES_PESSOA, 1, 40), ''))       || ';' ||
    TRIM(NVL(PRIMEIRO_NOME, '')) || ';' ||
    NVL(TO_CHAR(DATA_ADMISSAO, 'DD/MM/YYYY'), '') || ';' ||
    TRIM(TO_CHAR(
        CASE
            WHEN DES_FUNCAO LIKE 'DIRETOR%'     THEN 2
            WHEN DES_FUNCAO LIKE '%ESTAGIARIO%' THEN 5
            WHEN DES_FUNCAO LIKE '%APRENDIZ%'   THEN 6
            ELSE 1
        END
    )) || ';' ||
    TRIM(NVL(SEXO, '')) || ';' ||
    TRIM(TO_CHAR(
        CASE
            WHEN COD_EST_CIVIL = 1 THEN 1
            WHEN COD_EST_CIVIL = 2 THEN 2
            WHEN COD_EST_CIVIL = 3 THEN 6
            WHEN COD_EST_CIVIL = 4 THEN 3
            WHEN COD_EST_CIVIL = 5 THEN 4
            WHEN COD_EST_CIVIL = 6 THEN 7
            ELSE 9
        END
    )) || ';' ||
    TRIM(NVL(TO_CHAR(COD_INSTRUCAO), '')) || ';' ||
    NVL(TO_CHAR(DATA_NASCIMENTO, 'DD/MM/YYYY'), '') || ';' ||
    TRIM(NVL(TO_CHAR(COD_NACIONALIDADE), '')) || ';' ||
    TRIM(NVL(NULL, '')) || ';' ||                         -- ano_chegada (validar)
    TRIM(NVL(NULL, '')) || ';' ||                         -- classificacao_condicao_estrangeiro (validar)
    TRIM(NVL(NULL, '')) || ';' ||                         -- carteira_estrangeiro (validar)
    TRIM(NVL(NULL, '')) || ';' ||                         -- data_validade_carteira_estrangeiro (validar)
    TRIM(NVL(NULL, '')) || ';' ||                         -- data_validade_carteira_trabalho (validar)
    TRIM(NVL(TO_CHAR(NRO_CTPS), '')) || ';' ||
    TRIM(NVL(TO_CHAR(NRO_SERIE_CTPS), '')) || ';' ||
    TRIM(NVL(NULL, '')) || ';' ||                         -- uf_carteira_trabalho (validar)
    NVL(TO_CHAR(DATA_EXP_CTPS, 'DD/MM/YYYY'), '') || ';' ||
    SUBSTR(REGEXP_REPLACE(TRIM(NVL(TO_CHAR(CPF), '')), '[^0-9]', ''), 1, 11) || ';' ||
    SUBSTR(REGEXP_REPLACE(TRIM(NVL(TO_CHAR(NRO_PIS_PASEP), '')), '[^0-9]', ''), 1, 11) || ';' ||
    TRIM(NVL(NULL, '')) || ';' ||                         -- data_cadastramento_pis_pasep (validar)
    'N' || ';' ||                                         -- contribuicao_sindical_ano
    'R' || ';' ||                                         -- modo_pagamento_salario
    TRIM(NVL(TO_CHAR(COD_BANCO), '')) || ';' ||
    TRIM(NVL(TO_CHAR(COD_AGE_PGTO), '')) || ';' ||
    TRIM(NVL(NULL, '')) || ';' ||                         -- conta_bancaria (validar)
    TRIM(NVL(NULL, '')) || ';' ||                         -- digito_conta_bancaria (validar)
    TRIM(NVL(TO_CHAR(COD_TIPO_APOSENT), '')) || ';' ||
    NVL(TO_CHAR(DATA_APOSENTADORIA, 'DD/MM/YYYY'), '') || ';' ||
    TRIM(NVL(NULL, '')) || ';' ||                         -- outro_contrato_trabalho (validar)
    TRIM(NVL(NULL, '')) || ';' ||                         -- teto_inss_outro_contrato (validar)
    TRIM(NVL(NULL, '')) || ';' ||                         -- deficiente (validar)
    TRIM(NVL(TO_CHAR(
        CASE
            WHEN COD_RACA_COR = 1 THEN 5
            WHEN COD_RACA_COR = 2 THEN 1
            WHEN COD_RACA_COR = 4 THEN 2
            WHEN COD_RACA_COR = 6 THEN 3
            WHEN COD_RACA_COR = 8 THEN 4
            WHEN COD_RACA_COR = 9 THEN 0
            ELSE NULL
        END
    ), '')) || ';' ||
    TRIM(NVL(TO_CHAR(COD_DEFICIENCIA), '')) || ';' ||
    TRIM(NVL(NULL, '')) || ';' ||                         -- categoria_sefip (validar)
    TRIM(NVL(NULL, '')) || ';' ||                         -- codigo_movimento_sefip (validar)
    'N' || ';' ||                                         -- beneficiario_reabilitado
    TRIM(NVL(NULL, '')) || ';' ||                         -- tipo_documento_estrangeiro (validar)
    TRIM(TO_CHAR(3)) || ';' ||                            -- tipo_conta
    'N' || ';' ||                                         -- aposentadoria_apenas_por_idade
    NVL(TO_CHAR(DATA_CHEG_BRASIL, 'DD/MM/YYYY'), '') || ';' ||
    CASE WHEN COD_UNIDADE IN (659,183,242,269,467,605) THEN 'S' ELSE 'N' END || ';' ||  -- recebe_adiantamento_salario
    'S' || ';' ||                                         -- recebe_13_salario
    'N' || ';' ||                                         -- lista_colaborador_rais
    'S' || ';' ||                                         -- emitir_cartao_ponto
    '1' || ';' ||                                         -- colaborador_considerado_calculo_ronda
    CASE WHEN COD_UNIDADE IN (659,183,242,269,467,605) THEN 'Q' ELSE 'M' END || ';' ||  -- periodo_pagamento
    'S' || ';' ||                                         -- optante_fgts
    NVL(TO_CHAR(DATA_OPCAO_FGTS, 'DD/MM/YYYY'), '') || ';' ||
    TRIM(NVL(TO_CHAR(NRO_CONTA_FGTS), '')) || ';' ||
    '1' || ';' ||                         -- local_organograma (validar)
    '1'                                 -- tabela_organograma (validar)
FROM V_DADOS_COLAB_AVT
ORDER BY 1;

SPOOL OFF
SET TERMOUT ON