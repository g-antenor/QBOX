-- ============================================================================
-- nv_garage
--
-- Tabela propria em vez de coluna nova em `vehicles`: o schema do ox_core e
-- dele, e um ALTER TABLE ali some no proximo update do framework. Aqui a
-- chave estrangeira garante que o estado morre junto com o veiculo.
-- ============================================================================

CREATE TABLE IF NOT EXISTS `nv_vehicle_state` (
  `vin`     CHAR(17) NOT NULL,
  `locked`  TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`vin`),
  CONSTRAINT `nv_vehicle_state_vin_fk`
    FOREIGN KEY (`vin`) REFERENCES `vehicles` (`vin`)
    ON DELETE CASCADE ON UPDATE CASCADE
);
