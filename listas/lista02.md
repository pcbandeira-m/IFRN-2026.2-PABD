# LISTA DE EXERCÍCIOS 2 - Views, Indexes e Triggers

## Orientações gerais

A base `dvdrental` representa uma locadora e contém 15 tabelas, incluindo `film`, `inventory`, `rental`, `payment`, `customer`, `staff`, `store`, `category` e tabelas associativas.

Lembre-se de validar todas as questões, realizando as devidas consultas.

---

## Questão 01 - View de Performance da Equipe

A gerência quer um painel rápido para avaliar o desempenho dos funcionários. Crie uma view chamada `v_staff_performance` que exiba:

- `staff_id` e o nome completo do funcionário;
- endereço (cidade + país) onde a loja dele está localizada;
- A quantidade total de locações (`rentals`) processadas por ele;
- O valor total arrecadado através dos pagamentos que ele registrou.

*Dica*: Use LEFT JOIN para não excluir funcionários recém-contratados que ainda não processaram locações, e COALESCE para tratar nulos como zero.

### Resolução:
```sql
CREATE VIEW v_staff_performance AS
SELECT
    staff_id AS id_funcionario,
    first_name || ' ' || last_name AS nome_completo,
    
```

---

## Questão 02 - View Materializada de Receita por Categoria

O relatório de receita por categoria de filme é muito pesado, pois exige cruzar `category`, `film_category`, `inventory`, `rental` e `payment`. Crie uma Materialized View chamada `mv_category_total_sales` que liste o nome da categoria e o total de receita gerado por ela. Crie um índice único na MV que permita que ela seja atualizada de forma não-bloqueante (CONCURRENTLY). Escreva o comando SQL para recarregar os dados da MV sem bloquear as consultas dos usuários do sistema.

### Resolução:
```sql
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_category_total_sales AS
SELECT

```

---

## Questão 03 - Otimizando Filmes Atrasados

O sistema de cobrança roda a cada hora buscando locações que ainda não foram devolvidas (`return_date IS NULL`) para calcular multas. Como a tabela `rental` é grande e a maioria dos filmes já foi devolvida, um *Seq Scan* é muito caro. Crie um índice (parcial?) na tabela `rental` que indexe apenas as locações em aberto. Em seguida, escreva a consulta e use o `EXPLAIN ANALYZE` para provar que o índice está sendo utilizado.

### Resolução:
```sql
CREATE INDEX IF NOT EXISTS open_rentals
ON rental(rental_date)
WHERE rental_date IS NULL;

EXPLAIN ANALYZE
SELECT * FROM rental WHERE rental_date IS NULL;

/*
#### Sem índices ####

                                                                         QUERY PLAN                                                                          
-------------------------------------------------------------------------------------------------------------------------------------------------------------
 Index Scan using idx_unq_rental_rental_date_inventory_id_customer_id on rental  (cost=0.29..6.06 rows=1 width=36) (actual time=0.056..0.056 rows=0 loops=1)
   Index Cond: (rental_date IS NULL)
 Planning Time: 0.219 ms
 Execution Time: 0.067 ms


#### Com índice parcial ####

                                                      QUERY PLAN                                                      
----------------------------------------------------------------------------------------------------------------------
 Index Scan using open_rentals on rental  (cost=0.12..4.16 rows=1 width=36) (actual time=0.002..0.002 rows=0 loops=1)
 Planning Time: 0.195 ms
 Execution Time: 0.014 ms
*/
```

---

## Questão 04 - Busca Inteligente de Sinopses

Os clientes reclamam que a busca por palavras-chave na descrição dos filmes (`description`) usando `LIKE '%palavra%'` está lenta e não encontra variações da palavra (ex: "act", "acting", "actor"). Crie um índice adequado para melhorar o desempenho na busca. Em seguida, escreva uma consulta par buscar *documentary* e *drama* na descrição. Use o `EXPLAIN ANALYZE` para provar que o índice está sendo utilizado.

---

## Questão 05 - Histórico do Cliente

Sempre que o cliente abre seu perfil no aplicativo, o sistema busca o histórico de pagamentos dele, ordenados do mais recente para o mais antigo:

`SELECT * FROM payment WHERE customer_id = X ORDER BY payment_date DESC`.

Para otimizar essa consulta específica, crie um índice multicoluna na tabela `payment`. Qual coluna deve vir primeiro no índice e por quê?


### Resolução:
```sql
CREATE INDEX IF NOT EXISTS idx_payment_history_by_costumer
ON payment(customer_id, payment_date);

EXPLAIN ANALYZE
SELECT * FROM payment 
WHERE customer_id = 1 
ORDER BY payment_date DESC;

/*
#### Sem índice ####

                                                            QUERY PLAN                                                             
-----------------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=73.13..73.20 rows=30 width=26) (actual time=0.056..0.059 rows=30 loops=1)
   Sort Key: payment_date DESC
   Sort Method: quicksort  Memory: 26kB
   ->  Bitmap Heap Scan on payment  (cost=4.52..72.39 rows=30 width=26) (actual time=0.037..0.045 rows=30 loops=1)
         Recheck Cond: (customer_id = 1)
         Heap Blocks: exact=3
         ->  Bitmap Index Scan on idx_fk_customer_id  (cost=0.00..4.51 rows=30 width=0) (actual time=0.010..0.010 rows=30 loops=1)
               Index Cond: (customer_id = 1)
 Planning Time: 0.155 ms
 Execution Time: 0.083 ms


 #### Com índice ####

                                                                   QUERY PLAN                                                                   
------------------------------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=73.13..73.20 rows=30 width=26) (actual time=0.074..0.076 rows=30 loops=1)
   Sort Key: payment_date DESC
   Sort Method: quicksort  Memory: 26kB
   ->  Bitmap Heap Scan on payment  (cost=4.52..72.39 rows=30 width=26) (actual time=0.055..0.063 rows=30 loops=1)
         Recheck Cond: (customer_id = 1)
         Heap Blocks: exact=3
         ->  Bitmap Index Scan on idx_payment_history_by_costumer  (cost=0.00..4.51 rows=30 width=0) (actual time=0.049..0.049 rows=30 loops=1)
               Index Cond: (customer_id = 1)
 Planning Time: 0.266 ms
 Execution Time: 0.102 ms
*/
```

---

## Questão 06 - Login Case-Insensitive

O suporte técnico frequentemente busca clientes pelo e-mail, mas os atendentes não se preocupam com letras maiúsculas ou minúsculas (ex: buscam por `MARY.SMITH@...` quando o e-mail está gravado como `mary.smith@...`). Crie um **Índice Funcional** (Expression Index) na tabela `customer` que permita buscas rápidas e *case-insensitive* na coluna `email`. Crie uma consulta usando `EXPLAIN ANALYZE` para provar que o índice está sendo utilizado.

---

## Questão 07 - Validação de Datas

Ocorreu um bug no front-end que permitiu inserir locações onde a data de devolução (`return_date`) era *anterior* à data de locação (`rental_date`), gerando multas negativas. Crie um trigger `BEFORE INSERT OR UPDATE` na tabela `rental` que lance uma exceção (`RAISE EXCEPTION`) caso o `NEW.return_date` seja menor que o `NEW.rental_date`. Lembre-se de tratar o caso onde o `return_date` é `NULL` (o filme ainda está com o cliente). Realize 2 consultas teste para validar (sucesso/falha);

---

## Questão 08 - Auditoria de Preços

A administração suspeita que gerentes de loja estão alterando o custo de substituição (`replacement_cost`) de filmes raros sem autorização. Crie uma tabela de auditoria chamada `film_cost_audit` (`film_id`, `old_cost`, `new_cost`, `changed_at`) e uma trigger `AFTER UPDATE` na tabela `film` que insira um registro nessa tabela **apenas** se o `replacement_cost` for efetivamente modificado (utilize a cláusula `WHEN` na criação da trigger).

---

## Questão 09 - Proteção de Catálogo

Para evitar "buracos" no catálogo e erros de chave estrangeira órfã, o banco de dados não deve permitir a exclusão de um idioma da tabela `language` caso existam filmes cadastrados que o utilizem (seja como idioma original ou de áudio). Crie uma trigger `BEFORE DELETE` na tabela `language` que verifique as tabelas `film` (`language_id` e `original_language_id`). Se houver filmes vinculados, a exclusão deve ser abortada com uma mensagem de erro amigável.

---

## Questão 10 - Sincronização de Estatísticas

Para evitar contar as linhas da tabela `rental` toda vez que quisermos saber quantos filmes um cliente já alugou, vamos manter uma tabela de estatísticas.

- Crie a tabela `customer_rental_stats` (`customer_id` PK, `total_rentals` INT DEFAULT 0).
- Popule-a inicialmente com os dados atuais.
- Crie uma trigger `AFTER INSERT` na tabela `rental` que, a cada nova locação, atualize (incremento `+1`) o contador do respectivo cliente na tabela de estatísticas (verifique a existência).
