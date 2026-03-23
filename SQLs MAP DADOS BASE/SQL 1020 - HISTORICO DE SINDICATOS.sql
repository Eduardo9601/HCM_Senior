/* ====================================
   == 1020 - HISTÓRICO DE SINDICATOS ==
   ==================================== */

--VERSÃO ALTERNATIVA --EXPORTAÇÃO DIRETA PELO SQL

/*VERSÃO DEFINITIVA*/


/*=== 1020 - SINDICATOS (LOTE 1 - ATÉ DT_CORTE) ===*/
WITH
PARAM AS (SELECT DATE '2026-01-19' AS DT_CORTE FROM DUAL),
CONTRATOS_OK AS (
  SELECT C.COD_CONTRATO
    FROM V_DADOS_CONTRATO_AVT C
   CROSS JOIN PARAM P
   GROUP BY C.COD_CONTRATO, P.DT_CORTE
  HAVING MIN(NVL(TRUNC(C.DATA_ADMISSAO), DATE '1900-01-01')) <= P.DT_CORTE
)

SELECT DISTINCT
       org.cod_nivel2 as "codigo_empresa",
       1 as "tipo_colaborador",
       sd.cod_contrato as "cadastro_colaborador",
       to_char(sd.data_inicio, 'DD/MM/YYYY') as "data_alteracao",
       nvl(sd.cod_sindicato, 0) as "codigo_sindicato",
       sd.ind_mens_sindicato as "socio_sindicato",
       'S' as "possui_banco_horas"
  FROM vh_hist_sindicatos_cont_avt sd
  JOIN CONTRATOS_OK ok
    ON ok.cod_contrato = sd.cod_contrato
  CROSS JOIN PARAM P
 OUTER APPLY (
      select h.cod_organograma
        from (select h.*,
                     case
                       when trunc(h.data_inicio) <= trunc(sd.data_inicio)
                        and trunc(nvl(h.data_fim, date '9999-12-31')) >= trunc(sd.data_inicio) then 1
                       when trunc(h.data_inicio) <= trunc(sd.data_inicio) then 2
                       else 3
                     end as rk,
                     case
                       when trunc(h.data_inicio) <= trunc(sd.data_inicio)
                        and trunc(nvl(h.data_fim, date '9999-12-31')) >= trunc(sd.data_inicio) then 0
                       when trunc(h.data_inicio) <= trunc(sd.data_inicio) then trunc(sd.data_inicio) - trunc(h.data_inicio)
                       else trunc(h.data_inicio) - trunc(sd.data_inicio)
                     end as dist
                from rhfp0310 h
               where h.cod_contrato = sd.cod_contrato) h
       order by rk,
                dist,
                case when rk in (1,2) then h.data_inicio end desc,
                case when rk = 3 then h.data_inicio end asc
       fetch first 1 row only
 ) hist
  left join rhfp0401 org
    on org.cod_organograma = hist.cod_organograma
 where org.cod_nivel2 is not null
   AND TRUNC(sd.data_inicio) <= P.DT_CORTE
 order by sd.cod_contrato, to_char(sd.data_inicio, 'DD/MM/YYYY');


