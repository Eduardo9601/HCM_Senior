/* ================================
   == 1015 - HISTÓRICO DE CARGOS ==

--VERSÃO DIRETA --EXPORTAÇÃO DIRETA DA CONSULTA PARA EXCEL E CONVERTIDA PARA CSV

/*VERSÃO DEFINITIVA*/

/*=== 1015 cargos ===*/

WITH
PARAM AS (
  SELECT DATE '2026-01-19' AS DT_CORTE FROM DUAL
),
/* contratos “existentes” no lote importado (admissão <= corte) */
CONTRATOS_OK AS (
  SELECT C.COD_CONTRATO
    FROM V_DADOS_CONTRATO_AVT C
   CROSS JOIN PARAM P
   GROUP BY C.COD_CONTRATO, P.DT_CORTE
  HAVING MIN(NVL(TRUNC(C.DATA_ADMISSAO), DATE '1900-01-01')) <= P.DT_CORTE
  
)


select distinct /* codigo_empresa: vigente > anterior > futura (desempate por distância) */
                org.cod_nivel2 as "codigo_empresa",
                1 as "tipo_colaborador",
                ch.cod_contrato as "cadastro_colaborador",
                to_char(ch.data_ini_clh, 'DD/MM/YYYY') as "data_alteracao",
                1 as "estrutura_cargo",
                ch.cod_funcao as "codigo_cargo",
                case
                    when ch.cod_motivo = 43 then
                      1
                    when ch.cod_motivo = 22 then
                      2
                    when ch.cod_motivo = 23 then
                      9
                    when ch.cod_motivo in (6, 90, 100) then
                      3
                    when ch.cod_motivo = 24 then
                      4
                    when ch.cod_motivo = 25 then
                      5
                    when ch.cod_motivo = 26 then
                      12
                    when ch.cod_motivo = 485 then
                      10
                    when ch.cod_motivo = 421 then
                      15
                    when ch.cod_motivo = 429 then
                      16
                    when ch.cod_motivo = 431 then
                      11
                    when ch.cod_motivo = 459 then
                      17
                    when ch.cod_motivo = 479 then
                      13
                    else
                      999
                end as "motivo_alteracao"
  from vh_cargo_contrato_avt ch
  JOIN CONTRATOS_OK OK ON OK.COD_CONTRATO = CH.COD_CONTRATO
  CROSS JOIN PARAM P
 outer apply (
              /* escolhe 1 organograma “melhor” p/ a data da alteração do cargo */
              select h.cod_organograma
                from (select h.*,
                              case
                                when trunc(h.data_inicio) <=
                                     trunc(ch.data_ini_clh) and
                                     trunc(nvl(h.data_fim, date '9999-12-31')) >=
                                     trunc(ch.data_ini_clh) then
                                 1
                                when trunc(h.data_inicio) <=
                                     trunc(ch.data_ini_clh) then
                                 2
                                else
                                 3
                              end as rk,
                              case
                                when trunc(h.data_inicio) <=
                                     trunc(ch.data_ini_clh) and
                                     trunc(nvl(h.data_fim, date '9999-12-31')) >=
                                     trunc(ch.data_ini_clh) then
                                 0
                                when trunc(h.data_inicio) <=
                                     trunc(ch.data_ini_clh) then
                                 trunc(ch.data_ini_clh) - trunc(h.data_inicio)
                                else
                                 trunc(h.data_inicio) - trunc(ch.data_ini_clh)
                              end as dist
                         from rhfp0310 h
                        where h.cod_contrato = ch.cod_contrato) h
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
 where org.cod_nivel2 is not null   
 AND TRUNC(ch.data_ini_clh) <= P.DT_CORTE
 order by ch.cod_contrato, to_char(ch.data_ini_clh, 'DD/MM/YYYY'), ORG.COD_NIVEL2;