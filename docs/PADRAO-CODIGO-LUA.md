# Padrão de Código Lua — Modularização e Reuso

Objetivo: evitar arquivos volumosos e lógica duplicada, tornando cada mudança
pequena, localizada e fácil de revisar.

## Regra central

> Um arquivo = uma responsabilidade. Uma função = um propósito claro e
> testável isoladamente. Lógica repetida em 2+ lugares = função exportada.

## Passo a passo ao criar lógica nova

1. **Pergunte**: essa lógica pertence a um sistema já existente (ex.: `vehicle.lua`)
   ou é um sistema novo? Se for novo, crie um arquivo novo — não anexe a um
   arquivo genérico existente.
2. **Pergunte**: essa função será usada por outro script/resource? Se sim, ela
   deve nascer como export (ver seção abaixo), não como função solta que
   depois alguém copia e cola.
3. Escreva a função com comentário de cabeçalho:

```lua
--- Abre o menu de veículos do jogador.
-- @param playerId number: id do servidor do jogador
-- @param garageName string: identificador da garagem
-- @return boolean sucesso
local function openVehicleMenu(playerId, garageName)
  -- ...
end
```

4. Se o arquivo já ultrapassou ~300 linhas, **não** adicione a função nele —
   crie `modules/<sistema>/<novo_arquivo>.lua` e exporte o necessário para o
   arquivo principal do sistema consumir.

## Exportando funções entre arquivos do mesmo resource

Dentro do mesmo resource (sem passar pela rede), use um padrão de "módulo Lua"
simples, sem depender de `exports` nativo do FiveM (que é para *entre resources*):

```lua
-- modules/garage/persistence.lua
Garage = Garage or {}
Garage.Persistence = {}

function Garage.Persistence.save(playerId, vehicleData)
  -- ...
end

return Garage.Persistence
```

```lua
-- server/garage.lua
local Persistence = require('modules/garage/persistence') -- ou via shared table global, conforme fx_version

RegisterNetEvent('esx_garage:server:storeVehicle', function(vehicleData)
  Garage.Persistence.save(source, vehicleData)
end)
```

> FiveM não roda `require` de forma consistente entre client/server sem
> configuração — na dúvida, use tabelas globais namespaced (`Garage.Persistence`)
> carregadas via `shared_scripts`/ordem no `fxmanifest.lua`, e documente a ordem
   de carga no topo do arquivo.

## Exportando entre resources diferentes (`exports` nativo)

```lua
-- resource A: fxmanifest.lua → exports { 'getPlayerJob' }
exports('getPlayerJob', function(playerId)
  return Core.getPlayer(playerId).job
end)
```

```lua
-- resource B
local job = exports['resource_a']:getPlayerJob(playerId)
```

Sempre documente exports novos em `docs/MAPA-SCRIPTS.md`, incluindo assinatura
e quem consome.

## Checklist antes de finalizar uma alteração

- [ ] A função nova tem comentário de cabeçalho?
- [ ] O arquivo alterado continua com uma única responsabilidade clara?
- [ ] Se algo foi duplicado, foi extraído para função/módulo compartilhado?
- [ ] Eventos/exports novos seguem a convenção de nome (`docs/ARQUITETURA.md`)?
- [ ] `docs/MAPA-SCRIPTS.md` foi atualizado?
