/* ========================================
   == SQL 1012 - CADASTRO DE COLABORADOR ==
   ======================================== */

/*== VERSÃO AJUSTADA PARA TRATAR CONTRATOS COM MAIS DE UMA EMPRESA AO LONGO DE SEU CONTRATO ==*/

/*VERSÃO DEFINITIVA*/

--SELECT * FROM V_DADOS_COLAB_AVT


/*=== V2 | 1012 CADASTRO DO COLABORADOR ===*/

WITH base AS (
    /* Contratos normais (sem dupla empresa) */
    SELECT
        v.cod_emp,
        v.cod_contrato,
        v.des_pessoa,
        v.primeiro_nome,
        v.data_admissao,
        v.des_funcao,
        v.sexo,
        v.cod_est_civil,
        v.cod_instrucao,
        v.data_nascimento,
        v.cod_nacionalidade,
        v.data_cheg_brasil,
        v.class_trab_estrang,
        v.nro_carteira_estrang,
        v.nro_ctps,
        v.nro_serie_ctps,
        v.cod_uf_ctps,
        v.data_exp_ctps,
        v.cpf,
        v.nro_pis_pasep,
        v.data_pis_pasep,
        v.cod_banco,
        v.cod_age_pgto,
        v.nro_conta_pgto,
        v.cod_tipo_aposent,
        v.data_aposentadoria,
        v.cod_raca_cor,
        v.cod_deficiencia,
        v.cod_unidade,
        v.data_opcao_fgts,
        v.nro_conta_fgts
    FROM v_dados_colab_avt v
    WHERE NOT EXISTS (
        SELECT 1
        FROM grz_cod_contrato_duas_empresas g
        WHERE g.cod_contrato = v.cod_contrato
    )
	AND V.DATA_ADMISSAO <= '19/01/2026' --DATA DE CORTE

    UNION ALL

    /* Contratos com dupla empresa (vista alternativa) */
    SELECT
        v2.cod_emp,
        v2.cod_contrato,
        v2.des_pessoa,
        v2.primeiro_nome,
        v2.data_admissao,
        v2.des_funcao,
        v2.sexo,
        v2.cod_est_civil,
        v2.cod_instrucao,
        v2.data_nascimento,
        v2.cod_nacionalidade,
        v2.data_cheg_brasil,
        v2.class_trab_estrang,
        v2.nro_carteira_estrang,
        v2.nro_ctps,
        v2.nro_serie_ctps,
        v2.cod_uf_ctps,
        v2.data_exp_ctps,
        v2.cpf,
        v2.nro_pis_pasep,
        v2.data_pis_pasep,
        v2.cod_banco,
        v2.cod_age_pgto,
        v2.nro_conta_pgto,
        v2.cod_tipo_aposent,
        v2.data_aposentadoria,
        v2.cod_raca_cor,
        v2.cod_deficiencia,
        v2.cod_unidade,
        v2.data_opcao_fgts,
        v2.nro_conta_fgts
    FROM v_dados_colab_avt2 v2
    WHERE EXISTS (
        SELECT 1
        FROM grz_cod_contrato_duas_empresas g
        WHERE g.cod_contrato = v2.cod_contrato
    )
	AND V2.DATA_ADMISSAO <= '19/01/2026' --DATA DE CORTE
),
pairs AS (
    /* pares únicos CPF x contrato (pra não sofrer multiplicação das views) */
    SELECT DISTINCT
           cpf,
           cod_contrato
    FROM base
    WHERE cpf IS NOT NULL
      AND cod_contrato IS NOT NULL
),
cpf_multi AS (
    /* SEM COUNT: se existe outro contrato diferente pro mesmo CPF => multi */
    SELECT DISTINCT p1.cpf
    FROM pairs p1
    JOIN pairs p2
      ON p2.cpf = p1.cpf
     AND p2.cod_contrato <> p1.cod_contrato
)
SELECT DISTINCT b.cod_emp AS "codigo_empresa",
                1 AS "tipo_colaborador",
                b.cod_contrato AS "cadastro_colaborador",
                SUBSTR(b.des_pessoa, 1, 40) AS "nome_funcionario",
                b.primeiro_nome AS "apelido_funcionario",
                TO_CHAR(b.data_admissao, 'DD/MM/YYYY') AS "data_admissao",
                
                CASE
                  WHEN b.des_funcao LIKE 'DIRETOR%' THEN
                   2
                  WHEN b.des_funcao LIKE '%ESTAGIARIO%' THEN
                   5
                  WHEN b.des_funcao LIKE '%APRENDIZ%' THEN
                   6
                  ELSE
                   1
                END AS "tipo_contrato",
                
                b.sexo AS "sexo",
                
                CASE
                  WHEN b.cod_est_civil = 1 THEN
                   b.cod_est_civil
                  WHEN b.cod_est_civil = 2 THEN
                   b.cod_est_civil
                  WHEN b.cod_est_civil = 3 THEN
                   6
                  WHEN b.cod_est_civil = 4 THEN
                   3
                  WHEN b.cod_est_civil = 5 THEN
                   4
                  WHEN b.cod_est_civil = 6 THEN
                   7
                  ELSE
                   9
                END AS "estado_civil",
                
                b.cod_instrucao AS "grau_instrucao",
                b.data_nascimento AS "data_nascimento",
                b.cod_nacionalidade AS "codigo_nacionalidade",
                TO_CHAR(b.data_cheg_brasil, 'YYYY') AS "ano_chegada",
                b.class_trab_estrang AS "class_condicao_estrangeiro", --classificacao_condicao_estrangeiro
                b.nro_carteira_estrang AS "carteira_estrangeiro", 
                
                NULL AS "data_val_carteira_estrangeiro", --data_validade_carteira_estrangeiro
                NULL AS "data_val_carteira_trabalho", --data_validade_carteira_trabalho
                
                b.nro_ctps       AS "numero_carteira_trabalho",
                b.nro_serie_ctps AS "serie_carteira_trabalho",
                b.cod_uf_ctps    AS "uf_carteira_trabalho",
                b.data_exp_ctps  AS "data_expe_carteira_trabalho", --data_expedicao_carteira_trabalho  
                
                b.cpf            AS "numero_cpf",
                b.nro_pis_pasep  AS "numero_pis_pasep",
                b.data_pis_pasep AS "data_cadastramento_pis_pasep",
                
                'N' AS "contribuicao_sindical_ano",
                'R' AS "modo_pagamento_salario",
                
                b.cod_banco      AS "codigo_banco",
                b.cod_age_pgto   AS "codigo_agencia",
                b.nro_conta_pgto AS "conta_bancaria",
                NULL             AS "digito_conta_bancaria",
                
                b.cod_tipo_aposent   AS "tipo_aposentadoria",
                b.data_aposentadoria AS "data_aposentadoria",
                
                /* >>> CAMPO DO LAYOUT LOutCon: S/U <<< */
                CASE
                  WHEN cm.cpf IS NOT NULL THEN
                   'S'
                  ELSE
                   'U'
                END AS "outro_contrato_trabalho",
                
                NULL AS "teto_inss_outro_contrato",
                NULL AS "deficiente",
                
                CASE
                  WHEN b.cod_raca_cor = 1 THEN
                   5
                  WHEN b.cod_raca_cor = 2 THEN
                   1
                  WHEN b.cod_raca_cor = 4 THEN
                   2
                  WHEN b.cod_raca_cor = 6 THEN
                   3
                  WHEN b.cod_raca_cor = 8 THEN
                   4
                  WHEN b.cod_raca_cor = 9 THEN
                   0
                  ELSE
                   NULL
                END AS "raca_cor",
                
                b.cod_deficiencia AS "codigo_deficiencia",
                NULL AS "categoria_sefip",
                NULL AS "codigo_movimento_sefip",
                'N' AS "beneficiario_reabilitado",
                NULL AS "tipo_documento_estrangeiro",
                3 AS "tipo_conta",
                'N' AS "aposentadoria_apenas_por_idade",
                b.data_cheg_brasil AS "data_chegada_brasil",
                
                CASE
                  WHEN b.cod_unidade IN (659, 183, 242, 269, 467, 605) THEN
                   'S'
                  ELSE
                   'N'
                END AS "recebe_adiantamento_salario",
                
                'S' AS "recebe_13_salario",
                'N' AS "lista_colaborador_rais",
                'S' AS "emitir_cartao_ponto",
                '1' AS "colab_consi_calculo_ronda", --colaborador_considerado_calculo_ronda
                
                CASE
                  WHEN b.cod_unidade IN (659, 183, 242, 269, 467, 605) THEN
                   'Q'
                  ELSE
                   'M'
                END AS "periodo_pagamento",
                
                'S' AS "optante_fgts",
                b.data_opcao_fgts AS "data_opcao_fgts",
                b.nro_conta_fgts AS "conta_fgts",
                
                1 AS "local_organograma",
                1 AS "tabela_organograma"
  FROM base b
  LEFT JOIN cpf_multi cm
    ON cm.cpf = b.cpf;
