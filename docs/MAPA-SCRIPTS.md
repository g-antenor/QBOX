# Mapa de Scripts — Resources e Dependências

Tabela viva que descreve **cada resource**, o que ele expõe (exports/events)
e de quem depende. Deve ser atualizada a cada criação/alteração relevante
(ver `docs/RASTREAMENTO-IMPACTO.md`).

## Índice de resources

| Resource | Função/propósito | Depende de | É dependido por |
|---|---|---|---|
| `oxmysql` | Abstração/pool de conexões MySQL/MariaDB | Nenhum | `ox_core`, `ox_inventory`, `ox_banking`, `nv_garage`, `nv_mdt`, `nv_orgs`, `nv_mechanic`, `nv_shops`, `nv_dealership`, `nv_crafting`, `nv_delivery` |
| `ox_core` | Core RPG (personagens, grupos/orgs, permissões, moedas) | `oxmysql`, `ox_lib` | `ox_inventory`, `ox_banking`, `ox_doorlock`, `nv_adminmenu`, `nv_garage`, `nv_hud`, `nv_mdt`, `nv_orgs`, `nv_mechanic`, `nv_shops`, `nv_dealership`, `nv_delivery`, `nv_radio` |
| `ox_lib` | UI/Utilitários (menus, dialogs, progressbar, notificações, zonas) | Nenhum | Todos os scripts `[ox]` e `[dev]` |
| `ox_inventory` | Inventário, stashes, lojas, drops, durabilidade e metadados | `ox_core`, `ox_lib`, `oxmysql` | `nv_shops`, `nv_recycle`, `nv_crafting`, `nv_orgs`, `nv_mechanic`, `nv_hunting`, `nv_props`, `nv_deliverybox`, `nv_delivery`, `ox_fuel` |
| `ox_target` | Sistema de interatividade por mira 3D (raycast/target) | `ox_lib` | `nv_shops`, `nv_recycle`, `nv_sit`, `nv_orgs`, `nv_mechanic`, `nv_garage`, `nv_delivery`, `ox_fuel`, `ox_doorlock` |
| `ox_doorlock` | Gerenciamento de fechaduras/trancas de portas | `ox_core`, `ox_lib`, `ox_target`, `oxmysql` | `nv_orgs` |
| `ox_fuel` | Sistema de combustível de veículos e galões | `ox_lib`, `ox_target`, `ox_inventory` | `nv_delivery`, `nv_garage` |
| `ox_banking` | Sistema de contas bancárias, caixas eletrônicos e extratos | `ox_core`, `ox_lib`, `oxmysql` | `nv_mdt`, `nv_dealership`, `nv_orgs`, `nv_delivery` |
| `ox_commands` | Gerenciador de comandos de chat com permissões | `ox_core`, `ox_lib` | `nv_chat` |
| `nv_adminmenu` | Painel administrativo (jogadores, veículos, handling, coords) | `ox_core`, `ox_lib` | N/A (Staff/Admins) |
| `nv_chat` | Sistema de chat com canais (OOC, Me, Do, Anúncio, Staff) | `ox_core`, `ox_lib`, `ox_commands` | Servidor geral |
| `nv_crafting` | Fabricação/crafting de itens e receitas dinâmicas por org | `ox_core`, `ox_lib`, `ox_inventory`, `oxmysql` | `nv_orgs` |
| `nv_dealership` | Concessionária NUI com teste drive, catálogo 3D e financiamento | `ox_core`, `ox_lib`, `ox_banking`, `oxmysql` | `nv_orgs` |
| `nv_delivery` | Entregas de suprimentos (postinhos de gasolina e lojas 24/7) | `ox_core`, `ox_lib`, `ox_inventory`, `ox_target`, `nv_dispatch` | `nv_shops`, `ox_fuel` |
| `nv_deliverybox` | Sistema de entrega de caixas e encomendas urbanas | `ox_core`, `ox_lib`, `ox_inventory`, `ox_target` | N/A (Emprego) |
| `nv_dispatch` | Central de emergências/chamados (alertas, GPS, blips) | `ox_core`, `ox_lib` | `nv_garage`, `nv_delivery`, `nv_orgs` |
| `nv_garage` | Garagens públicas, privadas, apreendidos (impound) e chaves | `ox_core`, `ox_lib`, `ox_target`, `oxmysql`, `nv_dispatch` | `nv_orgs`, `nv_mechanic` |
| `nv_hud` | Interface HUD (status, estresse, velocímetro, rádio, notificações) | `ox_core`, `ox_lib`, `pma-voice` | `nv_radio`, Servidor geral |
| `nv_hunting` | Atividades de caça e pesca (minigames, varas, iscas) | `ox_core`, `ox_lib`, `ox_inventory`, `nv_minigames` | N/A (Atividade) |
| `nv_mdt` | Mobile Data Terminal (Polícia/Justiça - boletins, multas, ordens) | `ox_core`, `ox_lib`, `oxmysql`, `ox_banking` | `nv_mechanic`, `nv_orgs` |
| `nv_mechanic` | Mecânica avançada, peças, reparos, incêndios e ordens de serviço | `ox_core`, `ox_lib`, `ox_inventory`, `ox_target`, `oxmysql`, `nv_mdt` | `nv_garage`, `nv_mdt` |
| `nv_minigames` | Minigames genéricos (lockpick, skillbar, campo minado) | `ox_lib` | `nv_recycle`, `nv_hunting`, `nv_garage` |
| `nv_orgs` | Gestão de facções/polícia (duty, stashes, garagens, fardamentos) | `ox_core`, `ox_lib`, `ox_inventory`, `ox_target`, `oxmysql` | `nv_crafting`, `nv_mechanic`, `nv_mdt` |
| `nv_props` | Spawn e sincronização de props/itens largados no mapa | `ox_lib`, `ox_inventory` | Servidor geral |
| `nv_radio` | Interface NUI de rádio com frequências e VOIP | `ox_core`, `ox_lib`, `pma-voice`, `nv_hud` | Servidor geral |
| `nv_recycle` | Reciclagem e coleta de lixo (prensagem, desmanche, venda) | `ox_core`, `ox_lib`, `ox_inventory`, `ox_target`, `nv_minigames` | N/A (Emprego) |
| `nv_shops` | Lojas dinâmicas de itens com PEDS e reabastecimento | `ox_core`, `ox_lib`, `ox_inventory`, `ox_target`, `oxmysql` | `nv_delivery` |
| `nv_sit` | Interatividade para sentar em cadeiras e bancos | `ox_lib`, `ox_target` | Servidor geral |
| `pma-voice` | Sistema VOIP 3D e rádio | Nenhum | `nv_hud`, `nv_radio` |
| `illenium-appearance` | Personalização de personagens, roupas e barbearia | `ox_core`, `ox_lib`, `oxmysql` | `nv_orgs` |
| `npwd` | Smartphone NUI avançado | `ox_core`, `oxmysql` | Servidor geral |
| `rpemotes-reborn` | Animações, emotes e expressões | Nenhum | Servidor geral |

## Exports públicos

| Resource | Export | Assinatura | Consumido por |
|---|---|---|---|
| `nv_hud` | `notify` | `exports.nv_hud:notify(data)` | Servidor geral |
| `nv_hud` | `SetRadioFrequency` | `exports.nv_hud:SetRadioFrequency(freq)` | `nv_radio` |
| `nv_hud` | `SetRadioChannel` | `exports.nv_hud:SetRadioChannel(channel)` | `nv_radio` |
| `nv_radio` | `useRadio` | `exports.nv_radio:useRadio()` | `ox_inventory` |
| `nv_radio` | `openRadio` | `exports.nv_radio:openRadio()` | `nv_hud` |
| `nv_radio` | `getFrequency` | `exports.nv_radio:getFrequency() -> string/number` | `nv_hud` |
| `nv_dispatch` | `Alert` | `exports.nv_dispatch:Alert(source, category, coords, data)` | `nv_garage`, `nv_delivery` |
| `nv_dispatch` | `Send` | `exports.nv_dispatch:Send(category, coords, data)` | Servidor geral |
| `nv_dispatch` | `VehicleTheft` | `exports.nv_dispatch:VehicleTheft(source, coords, data)` | `nv_garage` |
| `nv_dispatch` | `StopVehicleTheft` | `exports.nv_dispatch:StopVehicleTheft(source, alertId)` | `nv_garage` |
| `nv_dispatch` | `MoveVehicleTheft` | `exports.nv_dispatch:MoveVehicleTheft(source, alertId, coords)` | `nv_garage` |
| `nv_dispatch` | `MarkLatest` | `exports.nv_dispatch:MarkLatest()` | Client geral |
| `nv_dispatch` | `MarkCoords` | `exports.nv_dispatch:MarkCoords(x, y)` | Client geral |
| `nv_mechanic` | `GetSnapshot` | `exports.nv_mechanic:GetSnapshot(vin/vehicle) -> table` | `nv_garage` |
| `nv_mechanic` | `SaveSnapshot` | `exports.nv_mechanic:SaveSnapshot(vin, data)` | `nv_garage` |
| `nv_mechanic` | `ApplyToEntity` | `exports.nv_mechanic:ApplyToEntity(vin, entity)` | `nv_garage` |
| `nv_mechanic` | `RestoreVehicle` | `exports.nv_mechanic:RestoreVehicle(netId, mechanicSource)` | `nv_garage` |
| `nv_mechanic` | `ListOrders` | `exports.nv_mechanic:ListOrders(set) -> table` | `nv_mdt` |
| `nv_mechanic` | `StartOrder` | `exports.nv_mechanic:StartOrder(set, id) -> bool` | `nv_mdt` |
| `nv_mechanic` | `CancelOrder` | `exports.nv_mechanic:CancelOrder(set, id, reason) -> bool` | `nv_mdt` |
| `nv_mechanic` | `CompleteOrder` | `exports.nv_mechanic:CompleteOrder(set, id, payment, ...)` | `nv_mdt` |
| `nv_mechanic` | `useToolbox` | `exports.nv_mechanic:useToolbox()` | `ox_inventory` |
| `nv_mechanic` | `useExtinguisher` | `exports.nv_mechanic:useExtinguisher()` | `ox_inventory` |
| `nv_minigames` | `Start` | `exports.nv_minigames:Start(name, overrides) -> bool` | `nv_recycle`, `nv_hunting` |
| `nv_minigames` | `Play` | `exports.nv_minigames:Play(game, options) -> bool` | Client geral |
| `nv_minigames` | `Locked` | `exports.nv_minigames:Locked(options) -> bool` | `nv_garage` |
| `nv_minigames` | `Mines` | `exports.nv_minigames:Mines(options) -> bool` | Client geral |
| `nv_minigames` | `SkillBar` | `exports.nv_minigames:SkillBar(options) -> bool` | Client geral |
| `nv_minigames` | `ProgressTiming` | `exports.nv_minigames:ProgressTiming(options) -> bool` | Client geral |
| `nv_garage` | `GetImpoundFee` | `exports.nv_garage:GetImpoundFee(vin) -> number` | `nv_mdt` |
| `nv_garage` | `ClearImpound` | `exports.nv_garage:ClearImpound(vin)` | `nv_mdt` |
| `nv_garage` | `MarkOut` | `exports.nv_garage:MarkOut(vin)` | `nv_mdt` |
| `nv_garage` | `GiveKey` | `exports.nv_garage:GiveKey(source, plate, label)` | `nv_dealership` |
| `nv_garage` | `RemoveKey` | `exports.nv_garage:RemoveKey(source, plate)` | `nv_dealership` |
| `nv_garage` | `GetPlayerVehicles` | `exports.nv_garage:GetPlayerVehicles(source) -> table` | `npwd` (Phone) |
| `nv_garage` | `installBlocker` | `exports.nv_garage:installBlocker()` | `ox_inventory` |
| `nv_garage` | `removeBlocker` | `exports.nv_garage:removeBlocker()` | `ox_inventory` |
| `nv_mdt` | `open` | `exports.nv_mdt:open()` | Client geral |
| `nv_mdt` | `openGuest` | `exports.nv_mdt:openGuest()` | Client geral |
| `nv_mdt` | `openInvoiceModal` | `exports.nv_mdt:openInvoiceModal(data)` | Client geral |
| `nv_mdt` | `AddAutomaticReport` | `exports.nv_mdt:AddAutomaticReport(data)` | `nv_dispatch` |
| `nv_mdt` | `AddCall` | `exports.nv_mdt:AddCall(dept, data)` | `nv_dispatch` |
| `nv_mdt` | `PendingTotal` | `exports.nv_mdt:PendingTotal(charId) -> number` | `ox_banking` |
| `nv_orgs` | `GetOrgSubtype` | `exports.nv_orgs:GetOrgSubtype(set) -> string` | `nv_crafting`, `nv_mechanic` |
| `nv_orgs` | `GetOrgByNumber` | `exports.nv_orgs:GetOrgByNumber(number) -> table` | `nv_mdt` |
| `nv_orgs` | `useKey` | `exports.nv_orgs:useKey(...)` | `ox_inventory` |
| `nv_orgs` | `open` | `exports.nv_orgs:open()` | Client geral |
| `nv_orgs` | `GetServicePed` | `exports.nv_orgs:GetServicePed(set) -> number` | `nv_orgs` |
| `nv_crafting` | `GetEditableProjects` | `exports.nv_crafting:GetEditableProjects()` | `nv_orgs` |
| `nv_crafting` | `GetOrgRecipes` | `exports.nv_crafting:GetOrgRecipes(set) -> table` | `nv_orgs` |
| `nv_crafting` | `SaveOrgRecipe` | `exports.nv_crafting:SaveOrgRecipe(set, data)` | `nv_orgs` |
| `nv_crafting` | `DeleteOrgRecipe` | `exports.nv_crafting:DeleteOrgRecipe(set, id)` | `nv_orgs` |
| `nv_shops` | `GetRestockQueue` | `exports.nv_shops:GetRestockQueue() -> table` | `nv_delivery` |
| `nv_shops` | `DrainShops` | `exports.nv_shops:DrainShops()` | Cron / Admin |
| `nv_dealership` | `GetCatalog` | `exports.nv_dealership:GetCatalog() -> table` | Server geral |
| `nv_dealership` | `open` | `exports.nv_dealership:open()` | Client geral |
| `nv_delivery` | `startShop247Event` | `exports.nv_delivery:startShop247Event()` | `nv_shops` |
| `nv_delivery` | `startGasEvent` | `exports.nv_delivery:startGasEvent()` | `ox_fuel` |
| `nv_adminmenu` | `OpenPanel` | `exports.nv_adminmenu:OpenPanel()` | Client geral |
| `nv_adminmenu` | `openHandlingMenu` | `exports.nv_adminmenu:openHandlingMenu()` | Client geral |
| `nv_adminmenu` | `CoordsOverlay` | `exports.nv_adminmenu:CoordsOverlay()` | Client geral |
| `nv_hunting` | `useRod` | `exports.nv_hunting:useRod()` | `ox_inventory` |
| `nv_props` | `SpawnDrop` | `exports.nv_props:SpawnDrop(item, coords)` | Server geral |

## Eventos de rede (client ↔ server)

| Evento | Disparado por | Ouvido por | Payload |
|---|---|---|---|
| `nv_dispatch:carTheft` | `nv_garage` (client) | `nv_dispatch` (server) | `(coords, data)` |
| `nv_dispatch:carTheftStopped` | `nv_garage` (client) | `nv_dispatch` (server) | `(alertId)` |
| `nv_dispatch:carTheftMoved` | `nv_garage` (client) | `nv_dispatch` (server) | `(alertId, coords)` |
| `nv_dispatch:robbery` | Client (assalto) | `nv_dispatch` (server) | `(coords)` |
| `nv_dispatch:atmRobbery` | Client (caixa eletrônico) | `nv_dispatch` (server) | `(coords)` |
| `nv_dispatch:atmExplosion` | Client (explosão ATM) | `nv_dispatch` (server) | `(coords)` |
| `nv_garage:lockpickWear` | `nv_garage` (client) | `nv_garage` (server) | `(outcome)` |
| `nv_garage:dispatchTheft` | `nv_garage` (client) | `nv_garage` (server) | `(coords, data)` |
| `nv_garage:blockerSignalLost` | `nv_garage` (client) | `nv_garage` (server) | `(coords, data)` |
| `nv_mechanic:save` | `nv_mechanic` (client) | `nv_mechanic` (server) | `(netId, data)` |
| `nv_mechanic:explode` | `nv_mechanic` (client) | `nv_mechanic` (server) | `(netId)` |
| `nv_mechanic:extinguish` | `nv_mechanic` (client) | `nv_mechanic` (server) | `(netId)` |
| `nv_mechanic:applyRepair` | `nv_mechanic` (server) | `nv_mechanic` (client) | `(netId, kind, index)` |
| `nv_mechanic:applyOrderPart` | `nv_mechanic` (server) | `nv_mechanic` (client) | `(netId, key)` |
| `nv_mechanic:finalizeVehicle` | `nv_mechanic` (server) | `nv_mechanic` (client) | `(netId)` |
| `nv_mechanic:orderState` | `nv_mechanic` (server) | `nv_mechanic` (client) | `(orderData)` |
| `nv_mdt:forceCloseUi` | `nv_mdt` (server) | `nv_mdt` (client) | `()` |
| `nv_mdt:openGuest` | `nv_mdt` (server) | `nv_mdt` (client) | `(data)` |
| `nv_mdt:openMechanicOrder` | `nv_mdt` (server/client) | `nv_mdt` (client) | `(order)` |
| `nv_mdt:openInvoiceModal` | `nv_mdt` (server) | `nv_mdt` (client) | `(invoiceData)` |
| `nv_mdt:client:jail` | `nv_mdt` (server) | `nv_mdt` (client) | `(duration)` |
| `nv_orgs:requestWardrobes` | `nv_orgs` (client) | `nv_orgs` (server) | `()` |
| `nv_orgs:requestStashes` | `nv_orgs` (client) | `nv_orgs` (server) | `()` |
| `nv_orgs:requestGarages` | `nv_orgs` (client) | `nv_orgs` (server) | `()` |
| `nv_orgs:syncDutyPoints` | `nv_orgs` (server) | `nv_orgs` (client) | `(cacheData)` |
| `nv_props:placeItem` | `nv_props` (client) | `nv_props` (server) | `(itemName, coords, rotation)` |
| `nv_props:syncDrops` | `nv_props` (server) | `nv_props` (client) | `(drops)` |
| `nv_radio:report` | `nv_radio` (client) | `nv_radio` (server) | `(frequency)` |
| `nv_recycle:server:rewardItem` | `nv_recycle` (client) | `nv_recycle` (server) | `(round, isFinalRound)` |
| `nv_recycle:server:sellItem` | `nv_recycle` (client) | `nv_recycle` (server) | `(itemName)` |
| `nv_recycle:server:sellAll` | `nv_recycle` (client) | `nv_recycle` (server) | `()` |
| `nv_delivery:cancelJob` | `nv_delivery` (client) | `nv_delivery` (server) | `(deleteHandItem)` |

## Configs compartilhadas relevantes

| Resource | Arquivo | O que controla |
|---|---|---|
| `nv_mdt` | `config.lua` | Permissões por departamento, crimes, multas, prazos de prisão e faturas |
| `nv_orgs` | `shared/config.lua` | Definição de organizações, cargos, stashes, pontos de duty e fardamentos |
| `nv_garage` | `config.lua` | Zonas de garagens, preços de impound, locomoção e chaves de veículos |
| `nv_shops` | `config.lua` | Localização de lojas, modelos de ped atendentes, catálogo e itens de recebimento |
| `nv_mechanic` | `config.lua` | Peças, tempos de reparo, kits de ferramentas, extintores e oficinas parceiras |
| `nv_dealership` | `config.lua` | Categorias de veículos, coordenadas dos showrooms, pontos de spawn e test drive |
| `nv_delivery` | `config.lua` | Rotas de entregas, postos de combustível, lojas 24/7 e pagamentos |
| `nv_recycle` | `config.lua` | Modelos de lixeiras, recompensas de materiais reciclados e preços de venda |
| `nv_crafting` | `config.lua` | Bancadas de trabalho, receitas base e permissões por facção |
| `nv_hud` | `config.lua` | Posição dos elementos da HUD, cores de estresse/fome/sede e atualizações |

## Como manter atualizado

- Novo resource criado → nova linha no "Índice de resources".
- Novo export/evento público → nova linha na tabela correspondente.
- Resource removido/renomeado → atualizar todas as tabelas que o referenciam,
  não só apagar a linha (verificar quem dependia dele primeiro).
