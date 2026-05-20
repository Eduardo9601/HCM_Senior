/* == 1013 - Cadastro Complementar de Colaborador ==
   ================================================= */

/*== versão ajustada para tratar contratos com mais de um empresa ao longo de seu contrato ==*/

/*VERSÃO DEFINITIVA*/

select distinct A.cod_emp as "codigo_empresa",
                1 as "tipo_colaborador",
                A.cod_contrato as "cadastro_empregado",
                A.num_ficha_registro as "numero_ficha_registro",
                1 as "codigo_pais",
                case
                  when A.cod_uf is not null then
                   A.cod_uf
                  else
                   null
                end as "estado",
                CASE 
                    WHEN A.cod_ibge IS NOT NULL THEN
                      A.cod_ibge
                    ELSE
                     null
                END as "cidade",
                A.cod_bairro as "bairro",
                CASE 
                    WHEN A.cod_cep IS NOT NULL THEN 
                      A.cod_cep 
                    ELSE
                      NULL
                END as "cep",
                A.tipo_logra as "tipo_logradouro",
                case
                  when A.des_logra is not null then
                   substr(A.des_logra, 1, 40)
                  else
                   'AJUSTAR'
                end as "endereco_residencial",
                A.numero as "numero",
                A.complemento as "complemento_endereco",
                P.COD_PAIS_HCM as "codigo_pais_nascimento",
                A.cod_uf_nascimento as "estado_nascimento",
                A.cod_ibge_nascto as "cidade_nascimento",
                A.nro_identidade as "numero_carteira_identidade",
                
                -- NVL com 2 args + SUBSTR pra limitar tamanho
                substr(nvl(A.emissor_rg, 'AJUSTAR'), 1, 20) as "orgao_emissor_identidade", --orgao_emissor_carteira_identidade
                
                null                  as "cidade_emissao_documento",
                A.uf_rg               as "estado_emissao_documento",
                A.data_emi_identidade as "data_expedicao_documento",
                
                -- se for número: NVL(2 args) + TO_CHAR + SUBSTR
                substr(to_char(nvl(A.nro_zona_titulo, 1)), 1, 3) as "zona_titulo_eleitor",
                substr(to_char(nvl(A.nro_secao_titulo, 1)), 1, 4) as "secao_titulo_eleitor",
                
                A.nro_titulo as "numero_titulo_eleitor",
                A.nro_habilitacao as "numero_carteira_habilitacao",
                A.cod_categoria_hab as "categoria_carteira_habilitacao",
                A.data_validade_hab as "data_validade_habilitacao", --data_validade_carteira_habilitacao
                A.des_orgao_hab as "orgao_emissor_cnh",
                null as "uf_orgao_emissor_cnh",
                SUBSTR(NVL(TRIM(A.nro_reservista), 'AJUSTAR'), 1, 13) AS "numero_certificado_reservista",
                null as "categoria_reservista", --categoria_certificado_reservista
                null as "data_exp_reg_profissional", --data_expedicao_registro_profissional
                null as "data_vencto_reg_profissional", --data_vencimento_registro_profissional
                null as "registro_conselho_profissional",
                null as "duracao_contrato_trabalho",
                null as "prorrogacao_contrato_trabalho",
                null as "email_particular",
                null as "email_comercial",
                A.des_pessoa as "nome_completo",
                55 as "codigo_ddi_telefone",
                
                -- cod_ddd também
                substr(to_char(nvl(A.cod_ddd, 1)), 1, 3) as "codigo_ddd_telefone",
                
                A.fone_cel         as "numero_telefone",
                null               as "codigo_ddi_telefone_2",
                null               as "codigo_ddd_telefone_2",
                null               as "numero_telefone_2",
                A.primeiro_nome    as "nome_social",
                A.data_emissao_hab as "data_primeira_habilitacao",
                A.data_emissao_hab as "data_expedicao_cnh"
  from v_dados_colab_avt A
  LEFT JOIN GRZ_TMP_PAISES_HCM P
    ON P.CODIGO_PAIS_RFB = A.COD_PAIS
 where A.cod_contrato not in
       (select cod_contrato from grz_cod_contrato_duas_empresas)
   --and A.cod_ibge is NOT null
   AND A.DATA_ADMISSAO < '23/04/2026' --DATA DE CORTE
   --AND A.COD_CONTRATO = 378523 
  

union


select distinct
       A2.cod_emp as "codigo_empresa",
       1 as "tipo_colaborador",
       A2.cod_contrato as "cadastro_empregado",
       A2.num_ficha_registro as "numero_ficha_registro",
       1 as "codigo_pais",
       case
           when A2.cod_uf is not null then A2.cod_uf
           else NULL
       end as "estado",
       CASE 
           WHEN A2.cod_ibge IS NOT NULL THEN
             A2.cod_ibge
           ELSE
            null
       END as "cidade",
       A2.cod_bairro as "bairro",
       CASE 
          WHEN A2.cod_cep IS NOT NULL THEN 
            A2.cod_cep 
          ELSE
            NULL
       END as "cep",
       A2.tipo_logra as "tipo_logradouro",
       case
           when A2.des_logra is not null then 
            substr(A2.des_logra, 1, 40)
           else 'AJUSTAR'
       end as "endereco_residencial",
       A2.numero as "numero",
       A2.complemento as "complemento_endereco",
       A2.cod_pais_nascto as "codigo_pais_nascimento",
       A2.cod_uf_nascimento as "estado_nascimento",
       A2.cod_ibge_nascto as "cidade_nascimento",
       A2.nro_identidade as "numero_carteira_identidade",

       -- NVL com 2 args + SUBSTR pra limitar tamanho
       substr(nvl(A2.emissor_rg, 'AJUSTAR'), 1, 20) as "orgao_emissor_identidade",   --orgao_emissor_carteira_identidade

       null as "cidade_emissao_documento",
       A2.uf_rg as "estado_emissao_documento",
       A2.data_emi_identidade as "data_expedicao_documento",

       -- se for número: NVL(2 args) + TO_CHAR + SUBSTR
       substr(to_char(nvl(A2.nro_zona_titulo, 1)), 1, 3) as "zona_titulo_eleitor",
       substr(to_char(nvl(A2.nro_secao_titulo, 1)), 1, 4) as "secao_titulo_eleitor",

       A2.nro_titulo as "numero_titulo_eleitor",
       A2.nro_habilitacao as "numero_carteira_habilitacao",
       A2.cod_categoria_hab as "categoria_carteira_habilitacao",
       A2.data_validade_hab as "data_validade_habilitacao",   --data_validade_carteira_habilitacao
       A2.des_orgao_hab as "orgao_emissor_cnh",
       null as "uf_orgao_emissor_cnh",
       SUBSTR(NVL(TRIM(A2.nro_reservista), 'AJUSTAR'), 1, 13) AS "numero_certificado_reservista",
       null as "categoria_reservista",     --categoria_certificado_reservista
       null as "data_exp_reg_profissional",    --data_expedicao_registro_profissional
       null as "data_vencto_reg_profissional",   --data_vencimento_registro_profissional
       null as "registro_conselho_profissional",
       null as "duracao_contrato_trabalho",
       null as "prorrogacao_contrato_trabalho",
       null as "email_particular",
       NULL as "email_comercial",
       A2.des_pessoa as "nome_completo",
       55 as "codigo_ddi_telefone",

       -- cod_ddd também
       substr(to_char(nvl(A2.cod_ddd, 1)), 1, 3) as "codigo_ddd_telefone",

       A2.fone_cel as "numero_telefone",
       null as "codigo_ddi_telefone_2",
       null as "codigo_ddd_telefone_2",
       null as "numero_telefone_2",
       A2.primeiro_nome as "nome_social",
       A2.data_emissao_hab as "data_primeira_habilitacao",
       A2.data_emissao_hab as "data_expedicao_cnh"
from v_dados_colab_avt2 A2
LEFT JOIN GRZ_TMP_PAISES_HCM P2 ON P2.CODIGO_PAIS_RFB = A2.COD_PAIS
where A2.cod_contrato in (select cod_contrato from grz_cod_contrato_duas_empresas)
  --and A2.cod_ibge is NOT null
  AND A2.DATA_ADMISSAO < '23/04/2026' --DATA DE CORTE;
  





/*

SELECT * FROM V_DADOS_COLAB_AVT
WHERE STATUS = 0
AND COD_NACIONALIDADE <> 10

select * from GRZ_TMP_PAISES_HCM


select * from GRZ_TMP_NACIONALIDADES_HCM
*/
