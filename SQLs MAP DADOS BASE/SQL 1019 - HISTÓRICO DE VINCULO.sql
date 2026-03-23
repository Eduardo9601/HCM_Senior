/* ===============================
   == 1019 - HISTÓRICO DE VÍNCULO ==
   =============================== */

/*VERSÃO DEFINITIVA*/

/*=== 1019 - vinculo === */


select distinct /* 1) codigo_empresa vigente na data da admissão */
                org.cod_nivel2 as "codigo_empresa",
                1 as "tipo_colaborador",
                ct.cod_contrato as "cadastro_colaborador",
                to_char(ct.data_admissao, 'DD/MM/YYYY') as "data_alteracao",
                nvl(ct.cod_vinculo_empreg, 0) as "codigo_vinculo"
  from v_dados_contrato_avt ct
 outer apply (
              /* escolhe 1 organograma “melhor” p/ a data da alteração do cargo */
              select h.cod_organograma
                from (select h.*,
                              case
                                when trunc(h.data_inicio) <=
                                     trunc(ct.data_admissao) and
                                     trunc(nvl(h.data_fim, date '9999-12-31')) >=
                                     trunc(ct.data_admissao) then
                                 1
                                when trunc(h.data_inicio) <=
                                     trunc(ct.data_admissao) then
                                 2
                                else
                                 3
                              end as rk,
                              case
                                when trunc(h.data_inicio) <=
                                     trunc(ct.data_admissao) and
                                     trunc(nvl(h.data_fim, date '9999-12-31')) >=
                                     trunc(ct.data_admissao) then
                                 0
                                when trunc(h.data_inicio) <=
                                     trunc(ct.data_admissao) then
                                 trunc(ct.data_admissao) - trunc(h.data_inicio)
                                else
                                 trunc(h.data_inicio) - trunc(ct.data_admissao)
                              end as dist
                         from rhfp0310 h
                        where h.cod_contrato = ct.cod_contrato) h
               order by rk,
                         dist,
                         case
                           when rk in (1, 2) then
                            h.data_inicio
                         end desc,
                         case
                           when rk = 3 then
                            h.data_inicio
                         end asc
               fetch first 1 row only) hist
  left join rhfp0401 org
    on org.cod_organograma = hist.cod_organograma
  WHERE ORG.COD_NIVEL2 IS NOT NULL
   AND CT.DATA_ADMISSAO <= '19/01/2026' --DATA DE CORTE
 order by ct.cod_contrato, to_char(ct.data_admissao, 'DD/MM/YYYY')