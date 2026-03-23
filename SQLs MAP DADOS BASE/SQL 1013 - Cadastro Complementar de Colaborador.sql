/* =================================================
   == 1013 - Cadastro Complementar de Colaborador ==
   ================================================= */

/*== versão ajustada para tratar contratos com mais de um empresa ao longo de seu contrato ==*/

/*VERSÃO DEFINITIVA*/

select distinct
       cod_emp as "codigo_empresa",
       1 as "tipo_colaborador",
       cod_contrato as "cadastro_empregado",
       num_ficha_registro as "numero_ficha_registro",
       cod_nacionalidade as "codigo_pais",
       case
           when cod_uf is not null then cod_uf
           else 'AJUSTAR'
       end as "estado",
       cod_ibge as "cidade",
       cod_bairro as "bairro",
       cod_cep as "cep",
       tipo_logra as "tipo_logradouro",
       case
           when des_logra is not null then 
            substr(des_logra, 1, 40)
           else 'AJUSTAR'
       end as "endereco_residencial",
       numero as "numero",
       complemento as "complemento_endereco",
       cod_pais_nascto as "codigo_pais_nascimento",
       cod_uf_nascimento as "estado_nascimento",
       cod_ibge_nascto as "cidade_nascimento",
       nro_identidade as "numero_carteira_identidade",

       -- NVL com 2 args + SUBSTR pra limitar tamanho
       substr(nvl(emissor_rg, 'AJUSTAR'), 1, 20) as "orgao_emissor_identidade",   --orgao_emissor_carteira_identidade

       null as "cidade_emissao_documento",
       uf_rg as "estado_emissao_documento",
       data_emi_identidade as "data_expedicao_documento",

       -- se for número: NVL(2 args) + TO_CHAR + SUBSTR
       substr(to_char(nvl(nro_zona_titulo, 1)), 1, 3) as "zona_titulo_eleitor",
       substr(to_char(nvl(nro_secao_titulo, 1)), 1, 4) as "secao_titulo_eleitor",

       nro_titulo as "numero_titulo_eleitor",
       nro_habilitacao as "numero_carteira_habilitacao",
       cod_categoria_hab as "categoria_carteira_habilitacao",
       data_validade_hab as "data_validade_habilitacao",   --data_validade_carteira_habilitacao
       des_orgao_hab as "orgao_emissor_cnh",
       null as "uf_orgao_emissor_cnh",
       SUBSTR(NVL(TRIM(nro_reservista), 'AJUSTAR'), 1, 13) AS "numero_certificado_reservista",
       null as "categoria_reservista",     --categoria_certificado_reservista
       null as "data_exp_reg_profissional",    --data_expedicao_registro_profissional
       null as "data_vencto_reg_profissional",   --data_vencimento_registro_profissional
       null as "registro_conselho_profissional",
       null as "duracao_contrato_trabalho",
       null as "prorrogacao_contrato_trabalho",
       null as "email_particular",
       des_email as "email_comercial",
       des_pessoa as "nome_completo",
       55 as "codigo_ddi_telefone",

       -- cod_ddd também
       substr(to_char(nvl(cod_ddd, 1)), 1, 3) as "codigo_ddd_telefone",

       fone_cel as "numero_telefone",
       null as "codigo_ddi_telefone_2",
       null as "codigo_ddd_telefone_2",
       null as "numero_telefone_2",
       primeiro_nome as "nome_social",
       data_emissao_hab as "data_primeira_habilitacao",
       data_emissao_hab as "data_expedicao_cnh"
from v_dados_colab_avt
where cod_contrato not in (select cod_contrato from grz_cod_contrato_duas_empresas)
  and cod_ibge is NOT null
  AND DATA_ADMISSAO <= '19/01/2026' --DATA DE CORTE

union

select distinct
       cod_emp as "codigo_empresa",
       1 as "tipo_colaborador",
       cod_contrato as "cadastro_empregado",
       num_ficha_registro as "numero_ficha_registro",
       cod_nacionalidade as "codigo_pais",
       case
           when cod_uf is not null then cod_uf
           else 'AJUSTAR'
       end as "estado",
       cod_ibge as "cidade",
       cod_bairro as "bairro",
       cod_cep as "cep",
       tipo_logra as "tipo_logradouro",
       case
           when des_logra is not null then 
            substr(des_logra, 1, 40)
           else 'AJUSTAR'
       end as "endereco_residencial",
       numero as "numero",
       complemento as "complemento_endereco",
       cod_pais_nascto as "codigo_pais_nascimento",
       cod_uf_nascimento as "estado_nascimento",
       cod_ibge_nascto as "cidade_nascimento",
       nro_identidade as "numero_carteira_identidade",

       -- NVL com 2 args + SUBSTR pra limitar tamanho
       substr(nvl(emissor_rg, 'AJUSTAR'), 1, 20) as "orgao_emissor_identidade",   --orgao_emissor_carteira_identidade

       null as "cidade_emissao_documento",
       uf_rg as "estado_emissao_documento",
       data_emi_identidade as "data_expedicao_documento",

       -- se for número: NVL(2 args) + TO_CHAR + SUBSTR
       substr(to_char(nvl(nro_zona_titulo, 1)), 1, 3) as "zona_titulo_eleitor",
       substr(to_char(nvl(nro_secao_titulo, 1)), 1, 4) as "secao_titulo_eleitor",

       nro_titulo as "numero_titulo_eleitor",
       nro_habilitacao as "numero_carteira_habilitacao",
       cod_categoria_hab as "categoria_carteira_habilitacao",
       data_validade_hab as "data_validade_habilitacao",   --data_validade_carteira_habilitacao
       des_orgao_hab as "orgao_emissor_cnh",
       null as "uf_orgao_emissor_cnh",
       SUBSTR(NVL(TRIM(nro_reservista), 'AJUSTAR'), 1, 13) AS "numero_certificado_reservista",
       null as "categoria_reservista",     --categoria_certificado_reservista
       null as "data_exp_reg_profissional",    --data_expedicao_registro_profissional
       null as "data_vencto_reg_profissional",   --data_vencimento_registro_profissional
       null as "registro_conselho_profissional",
       null as "duracao_contrato_trabalho",
       null as "prorrogacao_contrato_trabalho",
       null as "email_particular",
       des_email as "email_comercial",
       des_pessoa as "nome_completo",
       55 as "codigo_ddi_telefone",

       -- cod_ddd também
       substr(to_char(nvl(cod_ddd, 1)), 1, 3) as "codigo_ddd_telefone",

       fone_cel as "numero_telefone",
       null as "codigo_ddi_telefone_2",
       null as "codigo_ddd_telefone_2",
       null as "numero_telefone_2",
       primeiro_nome as "nome_social",
       data_emissao_hab as "data_primeira_habilitacao",
       data_emissao_hab as "data_expedicao_cnh"
from v_dados_colab_avt2
where cod_contrato in (select cod_contrato from grz_cod_contrato_duas_empresas)
  and cod_ibge is NOT null
  AND DATA_ADMISSAO <= '19/01/2026' --DATA DE CORTE;



