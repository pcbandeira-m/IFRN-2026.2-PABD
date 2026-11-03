/* 
##################################################
---- Questão 1: Cadastro de Cliente e Perfil ----
################################################## 
*/ 

BEGIN;

INSERT INTO customer (first_name, last_name)
VALUES ('Barbara', 'Moreira');
 
ROLLBACK;

/* Não, o registro não foi salvo e é possível verificar através do comando SELECT retornando um total de 0 rows. Isso ocorre por conta do princípio da Atomicidade, que garante que todas as operações dentro do bloco sejam executadas e salvas com sucesso, ou nenhuma é gravada. Se pelo menos uma das instruções falhar, o banco aplica o ROLLBACK. */ 