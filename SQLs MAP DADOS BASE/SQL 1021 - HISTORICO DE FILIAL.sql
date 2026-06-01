/* == SQL 1021 - HISTORICO DE FILIAL ==
   ==================================== */

/*==== VERSÃO AJUSTADA - MANTÉM RETORNO PARA MESMA FILIAL EM DATAS DIFERENTES
       REMOVE APENAS FILIAL REPETIDA EM SEQUÊNCIA ===*/

WITH
PARAMETROS AS (
    SELECT TO_DATE('23/04/2026','DD/MM/YYYY') AS DT_CORTE
    FROM DUAL
),

/* 0) Contratos válidos: admitidos antes da data de corte */
CONTRATOS_VALIDOS AS (
    SELECT C.COD_CONTRATO
    FROM V_DADOS_CONTRATO_AVT C
    CROSS JOIN PARAMETROS P
    GROUP BY C.COD_CONTRATO, P.DT_CORTE
    HAVING MIN(TRUNC(C.DATA_ADMISSAO)) < P.DT_CORTE
),

/* 1) Base principal da view.
      Não filtrar COD_NIVEL_ORG, pois o colaborador pode estar alocado em nível 4, 5 ou 6.
      A filial correta para o arquivo vem da EDICAO_ORG_3. */
BASE_ORGANOGRAMA AS (
    SELECT
        V.COD_EMP,
        V.DES_EMP,
        V.COD_CONTRATO,
        V.NOME_PESSOA,
        TRUNC(V.DATA_INI_ORG) AS DATA_INI_ORG,
        TRUNC(V.DATA_FIM_ORG) AS DATA_FIM_ORG,
        V.COD_ORGANOGRAMA,
        V.DES_UNIDADE  AS CENTRO_CUSTO,
        V.EDICAO_ORG_3 AS COD_FILIAL,
        V.NOME3        AS NOME_FILIAL,
        V.COD_NIVEL_ORG
    FROM VH_EST_ORG_CONTRATO_AVT V
    WHERE V.COD_EMP IS NOT NULL
      AND V.EDICAO_ORG_3 IS NOT NULL
      AND V.EDICAO_ORG_3 NOT IN ('157', '173')

      /* Data corte somente pela admissão do colaborador */
      AND EXISTS (
          SELECT 1
          FROM CONTRATOS_VALIDOS CV
          WHERE CV.COD_CONTRATO = V.COD_CONTRATO
      )

      -- Filtro para teste:
      -- AND V.COD_CONTRATO IN (388606, 389622)
),

/* 2) Remove apenas duplicidade técnica da própria view.
      Se vier mais de uma linha para a mesma empresa/filial/data,
      prioriza o nível 3 quando existir, mas sem filtrar os demais níveis. */
BASE_SEM_DUPLICIDADE_TECNICA AS (
    SELECT
        COD_EMP,
        DES_EMP,
        COD_CONTRATO,
        NOME_PESSOA,
        DATA_INI_ORG,
        DATA_FIM_ORG,
        COD_ORGANOGRAMA,
        CENTRO_CUSTO,
        COD_FILIAL,
        NOME_FILIAL,
        COD_NIVEL_ORG
    FROM (
        SELECT
            B.*,
            ROW_NUMBER() OVER (
                PARTITION BY
                    B.COD_CONTRATO,
                    B.COD_EMP,
                    B.DATA_INI_ORG,
                    B.DATA_FIM_ORG,
                    B.COD_FILIAL
                ORDER BY
                    CASE
                        WHEN B.COD_NIVEL_ORG = 3 THEN 1
                        WHEN B.COD_NIVEL_ORG = 4 THEN 2
                        WHEN B.COD_NIVEL_ORG = 5 THEN 3
                        WHEN B.COD_NIVEL_ORG = 6 THEN 4
                        ELSE 9
                    END,
                    B.COD_ORGANOGRAMA
            ) AS RN_TECNICO
        FROM BASE_ORGANOGRAMA B
    )
    WHERE RN_TECNICO = 1
),

/* 3) Identifica filial e empresa anteriores na sequência cronológica */
BASE_COM_MOVIMENTO_ANTERIOR AS (
    SELECT
        B.*,

        LAG(B.COD_FILIAL) OVER (
            PARTITION BY B.COD_CONTRATO
            ORDER BY
                B.DATA_INI_ORG,
                NVL(B.DATA_FIM_ORG, DATE '2999-12-31'),
                B.COD_ORGANOGRAMA
        ) AS COD_FILIAL_ANTERIOR,

        LAG(B.COD_EMP) OVER (
            PARTITION BY B.COD_CONTRATO
            ORDER BY
                B.DATA_INI_ORG,
                NVL(B.DATA_FIM_ORG, DATE '2999-12-31'),
                B.COD_ORGANOGRAMA
        ) AS COD_EMP_ANTERIOR

    FROM BASE_SEM_DUPLICIDADE_TECNICA B
),

/* 4) Mantém apenas movimentos reais de filial.
      Regra principal:
      - primeira linha do contrato: mantém;
      - mudou de filial: mantém;
      - mudou de empresa: mantém, mesmo que o código da filial seja igual;
      - mesma empresa + mesma filial em sequência: remove;
      - se foi e voltou depois para a mesma filial: mantém, pois a filial anterior será diferente. */
MOVIMENTOS_REAIS_FILIAL AS (
    SELECT *
    FROM BASE_COM_MOVIMENTO_ANTERIOR
    WHERE COD_FILIAL_ANTERIOR IS NULL
       OR COD_FILIAL <> COD_FILIAL_ANTERIOR
       OR COD_EMP <> COD_EMP_ANTERIOR
),

/* 5) Recalcula empresa anterior considerando apenas os movimentos reais */
MOVIMENTOS_COM_EMPRESA_ANT AS (
    SELECT
        M.*,
        LAG(M.COD_EMP) OVER (
            PARTITION BY M.COD_CONTRATO
            ORDER BY
                M.DATA_INI_ORG,
                NVL(M.DATA_FIM_ORG, DATE '2999-12-31'),
                M.COD_ORGANOGRAMA
        ) AS COD_EMP_ANT_MOVIMENTO
    FROM MOVIMENTOS_REAIS_FILIAL M
),

/* 6) Marca novo segmento de empresa.
      Segmento 1 = admissão.
      Segmento 2 em diante = transferência de empresa. */
MOVIMENTOS_MARCADOS AS (
    SELECT
        M.*,
        CASE
            WHEN M.COD_EMP_ANT_MOVIMENTO IS NULL THEN 1
            WHEN M.COD_EMP <> M.COD_EMP_ANT_MOVIMENTO THEN 1
            ELSE 0
        END AS FLAG_NOVO_SEGMENTO_EMPRESA
    FROM MOVIMENTOS_COM_EMPRESA_ANT M
),

/* 7) Numera os segmentos de empresa */
MOVIMENTOS_SEGMENTADOS AS (
    SELECT
        M.*,
        SUM(M.FLAG_NOVO_SEGMENTO_EMPRESA) OVER (
            PARTITION BY M.COD_CONTRATO
            ORDER BY
                M.DATA_INI_ORG,
                NVL(M.DATA_FIM_ORG, DATE '2999-12-31'),
                M.COD_ORGANOGRAMA
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS NR_SEGMENTO_EMPRESA
    FROM MOVIMENTOS_MARCADOS M
),

/* 8) Filial atual do contrato.
      Não depende de DATA_FIM_ORG = 31/12/2999.
      Pega o último movimento real do contrato dentro da view. */
FILIAL_ATUAL AS (
    SELECT *
    FROM (
        SELECT
            M.*,
            ROW_NUMBER() OVER (
                PARTITION BY M.COD_CONTRATO
                ORDER BY
                    M.DATA_INI_ORG DESC,
                    NVL(M.DATA_FIM_ORG, DATE '2999-12-31') DESC,
                    M.COD_ORGANOGRAMA DESC
            ) AS RN_ATUAL
        FROM MOVIMENTOS_SEGMENTADOS M
    )
    WHERE RN_ATUAL = 1
),

/* 9) Histórico anterior:
      todos os movimentos reais que não são o último movimento do contrato.

      Importante:
      Aqui NÃO remove mais a mesma filial da atual.
      Exemplo 052 -> 606 -> 052:
      deve retornar 052 e 606 conforme as datas/movimentos reais. */
FILIAL_ANTERIOR AS (
    SELECT M.*
    FROM MOVIMENTOS_SEGMENTADOS M
    JOIN FILIAL_ATUAL A
      ON A.COD_CONTRATO = M.COD_CONTRATO
    WHERE NOT (
            M.COD_EMP         = A.COD_EMP
        AND M.DATA_INI_ORG    = A.DATA_INI_ORG
        AND NVL(M.DATA_FIM_ORG, DATE '2999-12-31') = NVL(A.DATA_FIM_ORG, DATE '2999-12-31')
        AND M.COD_FILIAL      = A.COD_FILIAL
        AND M.COD_ORGANOGRAMA = A.COD_ORGANOGRAMA
    )
),

/* 10) Resultado tratado */
RESULTADO_FILIAL AS (
    SELECT
        F.COD_EMP,
        F.DES_EMP,
        F.COD_CONTRATO,
        F.NOME_PESSOA,
        F.DATA_INI_ORG,
        F.DATA_FIM_ORG,
        F.COD_ORGANOGRAMA,
        F.CENTRO_CUSTO,
        F.COD_FILIAL,
        F.NOME_FILIAL,
        F.NR_SEGMENTO_EMPRESA,
        1 AS ORDEM_REGISTRO
    FROM FILIAL_ANTERIOR F

    UNION ALL

    SELECT
        A.COD_EMP,
        A.DES_EMP,
        A.COD_CONTRATO,
        A.NOME_PESSOA,
        A.DATA_INI_ORG,
        A.DATA_FIM_ORG,
        A.COD_ORGANOGRAMA,
        A.CENTRO_CUSTO,
        A.COD_FILIAL,
        A.NOME_FILIAL,
        A.NR_SEGMENTO_EMPRESA,
        2 AS ORDEM_REGISTRO
    FROM FILIAL_ATUAL A
),

/* 11) Dados canônicos do contrato */
DADOS_CONTRATO AS (
    SELECT
        COD_CONTRATO,
        CASE
            WHEN COD_TIPO_ADMISSAO = 5 THEN 6
            ELSE COD_TIPO_ADMISSAO
        END AS TIPO_ADMISSAO,
        NUM_FICHA_REGISTRO
    FROM (
        SELECT
            C.*,
            ROW_NUMBER() OVER (
                PARTITION BY C.COD_CONTRATO
                ORDER BY
                    CASE WHEN C.NUM_FICHA_REGISTRO IS NOT NULL THEN 0 ELSE 1 END,
                    CASE WHEN C.DATA_FIM_FICHA = DATE '2999-12-31' THEN 0 ELSE 1 END,
                    NVL(C.DATA_FIM_FICHA, DATE '1900-01-01') DESC,
                    NVL(C.DATA_INI_FICHA, DATE '1900-01-01') DESC
            ) AS RN
        FROM V_DADOS_CONTRATO_AVT C
        WHERE C.COD_CONTRATO IN (
            SELECT DISTINCT COD_CONTRATO
            FROM RESULTADO_FILIAL
        )
    )
    WHERE RN = 1
)

/* =========================
   SELECT FINAL - FORMATO OFICIAL 1021
   ========================= */
SELECT
    R.COD_EMP AS "codigo_empresa",
    1 AS "tipo_colaborador",
    R.COD_CONTRATO AS "cadastro_colaborador",
    TO_CHAR(R.DATA_INI_ORG, 'DD/MM/YYYY') AS "data_alteracao",

    /* Empresa correta no momento da filial */
    R.COD_EMP AS "codigo_nova_empresa",

    R.COD_CONTRATO AS "codigo_novo_cadastro",
    R.COD_FILIAL AS "codigo_nova_filial",

    DC.TIPO_ADMISSAO AS "tipo_admissao",
    NVL(DC.NUM_FICHA_REGISTRO, 0) AS "numero_ficha_registro",

    CASE
        WHEN R.NR_SEGMENTO_EMPRESA = 1 THEN 1
        ELSE 2
    END AS "tipo_admissao_colaborador"

FROM RESULTADO_FILIAL R
LEFT JOIN DADOS_CONTRATO DC
  ON DC.COD_CONTRATO = R.COD_CONTRATO
WHERE R.COD_CONTRATO > 0
 --AND R.COD_CONTRATO IN (388606, 389622, 352683, 377298)
ORDER BY
    R.COD_CONTRATO,
    R.DATA_INI_ORG,
    R.ORDEM_REGISTRO,
    R.COD_EMP,
    R.COD_FILIAL;






/*==========================================================================*/



/*==== VERSÃO 2 ALTERNATIVA - OFICIAL - TRATANDO CASOS DE PING PONG - 
       ALTERAÇÕES DIFERENTES MAS MESMA FILIAL===*/

/* == SQL 1021 - HISTORICO DE FILIAL ==
   ==================================== */



WITH
PARAMETROS AS (
    SELECT TO_DATE('23/04/2026','DD/MM/YYYY') AS DT_CORTE
    FROM DUAL
),

/* 0) Contratos válidos: admitidos antes da data de corte */
CONTRATOS_VALIDOS AS (
    SELECT C.COD_CONTRATO
    FROM V_DADOS_CONTRATO_AVT C
    CROSS JOIN PARAMETROS P
    GROUP BY C.COD_CONTRATO, P.DT_CORTE
    HAVING MIN(TRUNC(C.DATA_ADMISSAO)) < P.DT_CORTE
),

/* 1) Base principal da view.
      Não filtrar COD_NIVEL_ORG, pois o colaborador pode estar alocado em nível 4, 5 ou 6.
      A filial do arquivo vem da EDICAO_ORG_3. */
BASE_ORGANOGRAMA AS (
    SELECT
        V.COD_EMP,
        V.DES_EMP,
        V.COD_CONTRATO,
        V.NOME_PESSOA,
        TRUNC(V.DATA_INI_ORG) AS DATA_INI_ORG,
        TRUNC(V.DATA_FIM_ORG) AS DATA_FIM_ORG,
        V.COD_ORGANOGRAMA,
        V.DES_UNIDADE  AS CENTRO_CUSTO,
        V.EDICAO_ORG_3 AS COD_FILIAL,
        V.NOME3        AS NOME_FILIAL,
        V.COD_NIVEL_ORG
    FROM VH_EST_ORG_CONTRATO_AVT V
    CROSS JOIN PARAMETROS P
    WHERE V.COD_EMP IS NOT NULL
      AND V.EDICAO_ORG_3 IS NOT NULL
      AND V.EDICAO_ORG_3 NOT IN ('157', '173')

      /* data corte do colaborador */
      AND EXISTS (
          SELECT 1
          FROM CONTRATOS_VALIDOS CV
          WHERE CV.COD_CONTRATO = V.COD_CONTRATO
      )

      /* histórico somente até a data corte */
      --AND TRUNC(V.DATA_INI_ORG) < P.DT_CORTE

      -- Filtro para teste:
      -- AND V.COD_CONTRATO IN (388606, 389622)
),

--select count(cod_contrato) from BASE_ORGANOGRAMA

/* 2) Remove apenas duplicidade técnica da própria view.
      Se vier mais de uma linha para a mesma empresa/filial/data,
      prioriza o nível 3 quando existir, mas sem filtrar os demais níveis. */
BASE_SEM_DUPLICIDADE_TECNICA AS (
    SELECT
        COD_EMP,
        DES_EMP,
        COD_CONTRATO,
        NOME_PESSOA,
        DATA_INI_ORG,
        DATA_FIM_ORG,
        COD_ORGANOGRAMA,
        CENTRO_CUSTO,
        COD_FILIAL,
        NOME_FILIAL,
        COD_NIVEL_ORG
    FROM (
        SELECT
            B.*,
            ROW_NUMBER() OVER (
                PARTITION BY
                    B.COD_CONTRATO,
                    B.COD_EMP,
                    B.DATA_INI_ORG,
                    B.DATA_FIM_ORG,
                    B.COD_FILIAL
                ORDER BY
                    CASE
                        WHEN B.COD_NIVEL_ORG = 3 THEN 1
                        WHEN B.COD_NIVEL_ORG = 4 THEN 2
                        WHEN B.COD_NIVEL_ORG = 5 THEN 3
                        WHEN B.COD_NIVEL_ORG = 6 THEN 4
                        ELSE 9
                    END,
                    B.COD_ORGANOGRAMA
            ) AS RN_TECNICO
        FROM BASE_ORGANOGRAMA B
    )
    WHERE RN_TECNICO = 1
),

/* 3) Identifica filial e empresa anteriores na sequência cronológica */
BASE_COM_MOVIMENTO_ANTERIOR AS (
    SELECT
        B.*,

        LAG(B.COD_FILIAL) OVER (
            PARTITION BY B.COD_CONTRATO
            ORDER BY
                B.DATA_INI_ORG,
                NVL(B.DATA_FIM_ORG, DATE '2999-12-31'),
                B.COD_ORGANOGRAMA
        ) AS COD_FILIAL_ANTERIOR,

        LAG(B.COD_EMP) OVER (
            PARTITION BY B.COD_CONTRATO
            ORDER BY
                B.DATA_INI_ORG,
                NVL(B.DATA_FIM_ORG, DATE '2999-12-31'),
                B.COD_ORGANOGRAMA
        ) AS COD_EMP_ANTERIOR

    FROM BASE_SEM_DUPLICIDADE_TECNICA B
),

/* 4) Mantém apenas movimentos reais.
      Regras:
      - se mudou só centro de custo e continuou na mesma filial/empresa, ignora;
      - se mudou filial, mantém;
      - se mudou empresa, mantém mesmo que o código da filial seja igual;
      - se foi e voltou para uma filial em outro momento, mantém como movimento real. */
MOVIMENTOS_REAIS_FILIAL AS (
    SELECT *
    FROM BASE_COM_MOVIMENTO_ANTERIOR
    WHERE COD_FILIAL_ANTERIOR IS NULL
       OR COD_FILIAL <> COD_FILIAL_ANTERIOR
       OR COD_EMP <> COD_EMP_ANTERIOR
),

/* 5) Recalcula empresa anterior considerando apenas os movimentos reais */
MOVIMENTOS_COM_EMPRESA_ANT AS (
    SELECT
        M.*,
        LAG(M.COD_EMP) OVER (
            PARTITION BY M.COD_CONTRATO
            ORDER BY
                M.DATA_INI_ORG,
                NVL(M.DATA_FIM_ORG, DATE '2999-12-31'),
                M.COD_ORGANOGRAMA
        ) AS COD_EMP_ANT_MOVIMENTO
    FROM MOVIMENTOS_REAIS_FILIAL M
),

/* 6) Marca novo segmento de empresa.
      Segmento 1 = admissão.
      Segmento 2 em diante = transferência de empresa. */
MOVIMENTOS_MARCADOS AS (
    SELECT
        M.*,
        CASE
            WHEN M.COD_EMP_ANT_MOVIMENTO IS NULL THEN 1
            WHEN M.COD_EMP <> M.COD_EMP_ANT_MOVIMENTO THEN 1
            ELSE 0
        END AS FLAG_NOVO_SEGMENTO_EMPRESA
    FROM MOVIMENTOS_COM_EMPRESA_ANT M
),

/* 7) Numera os segmentos de empresa */
MOVIMENTOS_SEGMENTADOS AS (
    SELECT
        M.*,
        SUM(M.FLAG_NOVO_SEGMENTO_EMPRESA) OVER (
            PARTITION BY M.COD_CONTRATO
            ORDER BY
                M.DATA_INI_ORG,
                NVL(M.DATA_FIM_ORG, DATE '2999-12-31'),
                M.COD_ORGANOGRAMA
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS NR_SEGMENTO_EMPRESA
    FROM MOVIMENTOS_MARCADOS M
),

/* 8) Filial atual do contrato.
      Não depende de DATA_FIM_ORG = 31/12/2999.
      Pega o último movimento real do contrato dentro da view. */
FILIAL_ATUAL AS (
    SELECT *
    FROM (
        SELECT
            M.*,
            ROW_NUMBER() OVER (
                PARTITION BY M.COD_CONTRATO
                ORDER BY
                    M.DATA_INI_ORG DESC,
                    NVL(M.DATA_FIM_ORG, DATE '2999-12-31') DESC,
                    M.COD_ORGANOGRAMA DESC
            ) AS RN_ATUAL
        FROM MOVIMENTOS_SEGMENTADOS M
    )
    WHERE RN_ATUAL = 1
),

/* 9) Histórico candidato:
      todos os movimentos reais que não são o último movimento do contrato. */
FILIAL_HISTORICO_CANDIDATO AS (
    SELECT M.*
    FROM MOVIMENTOS_SEGMENTADOS M
    JOIN FILIAL_ATUAL A
      ON A.COD_CONTRATO = M.COD_CONTRATO
    WHERE NOT (
            M.COD_EMP         = A.COD_EMP
        AND M.DATA_INI_ORG    = A.DATA_INI_ORG
        AND NVL(M.DATA_FIM_ORG, DATE '2999-12-31') = NVL(A.DATA_FIM_ORG, DATE '2999-12-31')
        AND M.COD_FILIAL      = A.COD_FILIAL
        AND M.COD_ORGANOGRAMA = A.COD_ORGANOGRAMA
    )
),

/* 10) Remove do histórico a mesma filial atual da mesma empresa.
       Exemplo:
       052 -> 606 -> 052 atual
       Histórico deve retornar apenas 606.

       Observação:
       A comparação considera COD_EMP + COD_FILIAL para não remover filial igual
       de empresa diferente. */
FILIAL_HIST_SEM_FILIAL_ATUAL AS (
    SELECT H.*
    FROM FILIAL_HISTORICO_CANDIDATO H
    JOIN FILIAL_ATUAL A
      ON A.COD_CONTRATO = H.COD_CONTRATO
    WHERE NOT (
            H.COD_EMP    = A.COD_EMP
        AND H.COD_FILIAL = A.COD_FILIAL
    )
),

/* 11) Trata ping-pong histórico.
       Se a mesma filial da mesma empresa apareceu mais de uma vez no histórico,
       mantém somente a ocorrência mais recente dela. */
FILIAL_ANTERIOR AS (
    SELECT *
    FROM (
        SELECT
            H.*,
            ROW_NUMBER() OVER (
                PARTITION BY
                    H.COD_CONTRATO,
                    H.COD_EMP,
                    H.COD_FILIAL
                ORDER BY
                    H.DATA_INI_ORG DESC,
                    NVL(H.DATA_FIM_ORG, DATE '2999-12-31') DESC,
                    H.COD_ORGANOGRAMA DESC
            ) AS RN_FILIAL_HISTORICA
        FROM FILIAL_HIST_SEM_FILIAL_ATUAL H
    )
    WHERE RN_FILIAL_HISTORICA = 1
),

/* 12) Resultado tratado da lógica nova */
RESULTADO_FILIAL AS (
    SELECT
        F.COD_EMP,
        F.DES_EMP,
        F.COD_CONTRATO,
        F.NOME_PESSOA,
        F.DATA_INI_ORG,
        F.DATA_FIM_ORG,
        F.COD_ORGANOGRAMA,
        F.CENTRO_CUSTO,
        F.COD_FILIAL,
        F.NOME_FILIAL,
        F.NR_SEGMENTO_EMPRESA,
        1 AS ORDEM_REGISTRO
    FROM FILIAL_ANTERIOR F

    UNION ALL

    SELECT
        A.COD_EMP,
        A.DES_EMP,
        A.COD_CONTRATO,
        A.NOME_PESSOA,
        A.DATA_INI_ORG,
        A.DATA_FIM_ORG,
        A.COD_ORGANOGRAMA,
        A.CENTRO_CUSTO,
        A.COD_FILIAL,
        A.NOME_FILIAL,
        A.NR_SEGMENTO_EMPRESA,
        2 AS ORDEM_REGISTRO
    FROM FILIAL_ATUAL A
),

/* 13) Dados canônicos do contrato */
DADOS_CONTRATO AS (
    SELECT
        COD_CONTRATO,
        CASE
            WHEN COD_TIPO_ADMISSAO = 5 THEN 6
            ELSE COD_TIPO_ADMISSAO
        END AS TIPO_ADMISSAO,
        NUM_FICHA_REGISTRO
    FROM (
        SELECT
            C.*,
            ROW_NUMBER() OVER (
                PARTITION BY C.COD_CONTRATO
                ORDER BY
                    CASE WHEN C.NUM_FICHA_REGISTRO IS NOT NULL THEN 0 ELSE 1 END,
                    CASE WHEN C.DATA_FIM_FICHA = DATE '2999-12-31' THEN 0 ELSE 1 END,
                    NVL(C.DATA_FIM_FICHA, DATE '1900-01-01') DESC,
                    NVL(C.DATA_INI_FICHA, DATE '1900-01-01') DESC
            ) AS RN
        FROM V_DADOS_CONTRATO_AVT C
        WHERE C.COD_CONTRATO IN (
            SELECT DISTINCT COD_CONTRATO
            FROM RESULTADO_FILIAL
        )
    )
    WHERE RN = 1
),


/* Regra 1: duplicidade técnica removida da view */
REGRA_DUPLICIDADE_TECNICA AS (
    SELECT
        '01 - DUPLICIDADE TECNICA DA VIEW' AS REGRA,
        X.COD_CONTRATO,
        X.COD_EMP,
        X.DATA_INI_ORG,
        X.DATA_FIM_ORG,
        X.COD_ORGANOGRAMA,
        X.CENTRO_CUSTO,
        X.COD_FILIAL,
        X.NOME_FILIAL
    FROM (
        SELECT
            B.*,
            ROW_NUMBER() OVER (
                PARTITION BY
                    B.COD_CONTRATO,
                    B.COD_EMP,
                    B.DATA_INI_ORG,
                    B.DATA_FIM_ORG,
                    B.COD_FILIAL
                ORDER BY
                    CASE
                        WHEN B.COD_NIVEL_ORG = 3 THEN 1
                        WHEN B.COD_NIVEL_ORG = 4 THEN 2
                        WHEN B.COD_NIVEL_ORG = 5 THEN 3
                        WHEN B.COD_NIVEL_ORG = 6 THEN 4
                        ELSE 9
                    END,
                    B.COD_ORGANOGRAMA
            ) AS RN_TECNICO
        FROM BASE_ORGANOGRAMA B
    ) X
    WHERE X.RN_TECNICO > 1
),

/* Regra 2: mudança apenas de centro de custo na mesma filial/empresa */
REGRA_CCU_MESMA_FILIAL AS (
    SELECT
        '02 - MUDANCA CC NA MESMA FILIAL' AS REGRA,
        B.COD_CONTRATO,
        B.COD_EMP,
        B.DATA_INI_ORG,
        B.DATA_FIM_ORG,
        B.COD_ORGANOGRAMA,
        B.CENTRO_CUSTO,
        B.COD_FILIAL,
        B.NOME_FILIAL
    FROM BASE_COM_MOVIMENTO_ANTERIOR B
    WHERE B.COD_FILIAL_ANTERIOR IS NOT NULL
      AND B.COD_FILIAL = B.COD_FILIAL_ANTERIOR
      AND B.COD_EMP = B.COD_EMP_ANTERIOR
),

/* Regra 3: histórico removido porque a filial voltou a ser a filial atual */
REGRA_FILIAL_HIST_IGUAL_ATUAL AS (
    SELECT
        '03 - FILIAL HISTORICA IGUAL A ATUAL' AS REGRA,
        H.COD_CONTRATO,
        H.COD_EMP,
        H.DATA_INI_ORG,
        H.DATA_FIM_ORG,
        H.COD_ORGANOGRAMA,
        H.CENTRO_CUSTO,
        H.COD_FILIAL,
        H.NOME_FILIAL
    FROM FILIAL_HISTORICO_CANDIDATO H
    JOIN FILIAL_ATUAL A
      ON A.COD_CONTRATO = H.COD_CONTRATO
    WHERE H.COD_EMP = A.COD_EMP
      AND H.COD_FILIAL = A.COD_FILIAL
),

/* Regra 4: ping-pong histórico, mantendo só a ocorrência mais recente */
REGRA_PING_PONG_HISTORICO AS (
    SELECT
        '04 - PING PONG HISTORICO' AS REGRA,
        X.COD_CONTRATO,
        X.COD_EMP,
        X.DATA_INI_ORG,
        X.DATA_FIM_ORG,
        X.COD_ORGANOGRAMA,
        X.CENTRO_CUSTO,
        X.COD_FILIAL,
        X.NOME_FILIAL
    FROM (
        SELECT
            H.*,
            ROW_NUMBER() OVER (
                PARTITION BY
                    H.COD_CONTRATO,
                    H.COD_EMP,
                    H.COD_FILIAL
                ORDER BY
                    H.DATA_INI_ORG DESC,
                    NVL(H.DATA_FIM_ORG, DATE '2999-12-31') DESC,
                    H.COD_ORGANOGRAMA DESC
            ) AS RN_FILIAL_HISTORICA
        FROM FILIAL_HIST_SEM_FILIAL_ATUAL H
    ) X
    WHERE X.RN_FILIAL_HISTORICA > 1
),

CONTRATOS_IMPACTADOS AS (
    SELECT * FROM REGRA_DUPLICIDADE_TECNICA

    UNION ALL

    SELECT * FROM REGRA_CCU_MESMA_FILIAL

    UNION ALL

    SELECT * FROM REGRA_FILIAL_HIST_IGUAL_ATUAL

    UNION ALL

    SELECT * FROM REGRA_PING_PONG_HISTORICO
)


/* =========================
   SELECT FINAL - FORMATO OFICIAL 1021
   ========================= */
SELECT
    R.COD_EMP AS "codigo_empresa",
    1 AS "tipo_colaborador",
    R.COD_CONTRATO AS "cadastro_colaborador",
    TO_CHAR(R.DATA_INI_ORG, 'DD/MM/YYYY') AS "data_alteracao",

    /* Empresa correta no momento da filial */
    R.COD_EMP AS "codigo_nova_empresa",

    R.COD_CONTRATO AS "codigo_novo_cadastro",
    R.COD_FILIAL AS "codigo_nova_filial",

    DC.TIPO_ADMISSAO AS "tipo_admissao",
    NVL(DC.NUM_FICHA_REGISTRO, 0) AS "numero_ficha_registro",

    CASE
        WHEN R.NR_SEGMENTO_EMPRESA = 1 THEN 1
        ELSE 2
    END AS "tipo_admissao_colaborador"

FROM RESULTADO_FILIAL R
LEFT JOIN DADOS_CONTRATO DC
  ON DC.COD_CONTRATO = R.COD_CONTRATO
WHERE R.COD_CONTRATO > 0
 --AND R.COD_CONTRATO IN (388606, 389622)
ORDER BY
    R.COD_CONTRATO,
    R.DATA_INI_ORG,
    R.ORDEM_REGISTRO,
    R.COD_EMP,
    R.COD_FILIAL;