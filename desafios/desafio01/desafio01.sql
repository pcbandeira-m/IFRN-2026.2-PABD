/*
## Questão 1 - Resumo por piloto/temporada

O painel analítico precisa de um resumo rápido por piloto/temporada sem consultar a gigantesca `race_data` a cada acesso. Crie uma materialized view `mv_driver_season_summary` que agregue os resultados de corrida (`type = 'RACE_RESULT'`) mostrando: ano, piloto, total de corridas, vitórias, pódios, abandonos (DNFs) e total de pontos. Inclua um índice único e o comando de `REFRESH CONCURRENTLY`. Para testar, exibir o resumo das 10 últimas temporadas de Ayrton Senna.
*/

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_driver_season_summary AS
SELECT
    r.year ano,
    sd.driver_id id_piloto,
    d.full_name piloto,
    d.total_race_entries total_corridas,
    d.total_race_wins vitorias,
    d.total_podiums podios,
    d.total_points total_pontos
FROM
    race_data rd
JOIN season_driver sd ON (sd.driver_id = d.id)
JOIN race r ON (r.id = rd.race_id)
JOIN driver d ON (d.id = rd.driver_id)
GROUP BY r.year
ORDER BY d.full_name


/*
## Questão 3 - Impedir exclusão de piloto com histórico

Crie uma trigger para impedir a exclusão de um piloto da tabela `driver` caso existam registros na `race_data` vinculados a ele. Lance uma exceção com o nome do piloto. Para testar, tente excluir Ayrton Senna da tabela `driver`. Logo após, exclua algum piloto sem registros em `race_data`.
*/

CREATE OR REPLACE FUNCTION prevent_driver_del()
    RETURNS trigger
    LANGUAGE plpgsql
AS $$
BEGIN
    if exists (select 1 from driver where driver_id = OLD.driver_id) then
        raise exception 'Não é permitido excluir pilotos com registros na tabela race_data', OLD.driver_id;
    end if;

    return old;
END;

DROP TRIGGER IF EXISTS trg_prevent_driver_del on driver;
create trigger trg_prevent_driver_del
before delete on driver
for each row
execute function prevent_driver_del();