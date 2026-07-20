-- ============================================================================
-- nv_orgs
--
-- UMA tabela, e ela existe por um motivo especifico: as permissoes do ox_core
-- vivem em `GlobalState['group.<nome>:permissions']` e NAO sao persistidas em
-- lugar nenhum -- somem a cada restart. Tudo o mais (organizacao, cargos,
-- membros, caixa) ja tem tabela propria no ox_core e nao e duplicado aqui.
--
-- O resource cria esta tabela sozinho no boot; este arquivo existe so para
-- quem preferir aplicar o schema na mao.
-- ============================================================================

CREATE TABLE IF NOT EXISTS `nv_org_grade_actions` (
  `group`  VARCHAR(20) NOT NULL,
  `grade`  TINYINT UNSIGNED NOT NULL,
  `action` VARCHAR(40) NOT NULL,
  PRIMARY KEY (`group`, `grade`, `action`),
  CONSTRAINT `nv_org_grade_actions_group_fk`
    FOREIGN KEY (`group`) REFERENCES `ox_groups` (`name`)
    ON DELETE CASCADE ON UPDATE CASCADE
);
