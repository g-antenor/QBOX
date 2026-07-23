# Rastreamento de Impacto

Processo obrigatório antes de **corrigir, criar ou alterar** algo que já existe
no projeto. Objetivo: entender onde e como mudar algo com o menor raio de
efeito colateral possível — evitando quebrar outros scripts e evitando editar
mais arquivos do que o necessário.

## Quando aplicar

- Correção de bug em função/evento já existente.
- Alteração de comportamento de algo que outros resources podem consumir.
- Qualquer alteração em arquivo com mais de um resource dependente.

Criação de algo 100% novo, sem dependentes, não precisa do processo completo —
mas ainda exige atualizar `docs/MAPA-SCRIPTS.md` ao final.

## Passo a passo

1. **Identifique o alvo**: nome da função, evento, export ou caminho do arquivo.
2. **Rode a varredura**: `.claude/hooks/impact-scan.sh <alvo>` (ou peça ao
   assistente para rodar/simular manualmente via busca no repositório).
3. **Classifique os pontos de impacto encontrados**:
   - *Direto*: chama a função/evento/export diretamente.
   - *Indireto*: depende do resultado/efeito colateral (ex.: espera um evento
     disparado por quem você vai alterar).
   - *Configuração*: usa constantes/config do arquivo alvo.
4. **Escreva um mini relatório** (pode ser só no chat, não precisa de arquivo
   novo) no formato:

```
Alvo: esx_garage:server:storeVehicle
Arquivos que chamam diretamente: 
  - resources/esx_garage/client/main.lua (linha X)
  - resources/qb_dealership/server/sell.lua (linha Y)
Impacto indireto:
  - qb_dealership espera o evento ser concluído antes de remover o veículo da loja
Config usada:
  - shared/config.lua → Config.MaxVehiclesPerGarage
Plano mínimo de alteração:
  - Alterar apenas a validação dentro de storeVehicle, sem mudar assinatura
```

5. **Execute a menor alteração possível** que resolve o problema, evitando
   reescrever arquivos inteiros ou "aproveitar para refatorar" sem necessidade.
6. **Atualize a documentação**:
   - `docs/MAPA-SCRIPTS.md`, se dependências mudaram.
   - Histórico abaixo, com 3-5 linhas.

## Histórico de Alterações

> Cada entrada: data, alvo, resumo do que mudou e por quê. Mantenha curto.

- `2026-07-22` — `docs/MAPA-SCRIPTS.md` — Varredura inicial e preenchimento completo do mapa de scripts da base: mapeados 30+ resources (`[ox]`, `[dev]`, `[pe]`, terceiros), exports públicos, eventos de rede client/server e configurações compartilhadas.
- `2026-07-22` — `nv_garage` / `nv_orgs` — Adicionado envio de coordenadas (`coords`) nos veículos listados, botão "Marcar no Minimapa" na NUI e callback `track` no client para definir Waypoint no GPS.
- `2026-07-22` — `npwd` / `nv_garage` — Integração do App de Garagem do celular (NPWD) com `nv_garage`: renderização dinâmica dos veículos, exibição da garagem/localização e botão para marcar a garagem/veículo no minimapa.
- `2026-07-22` — `npwd` / `nv_garage` — Aprimorado o botão "Rastrear Veículo" na NUI do celular e estendido o cálculo de coordenadas para veículos em circulação ao vivo (`live.coords`), estacionados na rua (`parkedSpot`), guardados e no pátio.
- `2026-07-22` — `npwd` — Correção do problema de travamento em carregamento infinito: inclusão de `@ox_lib/init.lua` no `fxmanifest.lua`, `pcall` com callback NUI garantido em `client/garage.lua` e timeout com `AbortController` na NUI.
- `2026-07-22` — `npwd` — Simplificação visual do cartão de veículo no celular: removidos tipo/classe do carro, ícones extras de localização e grade de estatísticas.
- `2026-07-22` — `npwd` — Exibição exclusiva do nome limpo do local (ex.: "Pillbox Hill") na embed do cartão do veículo no celular, removendo prefixos de estacionamento.
- `2026-07-22` — `npwd` — Remoção do container embed de localização para veículos que estejam fora da garagem e alteração da etiqueta de status de "Fora" para "Na Rua".
- `2026-07-22` — `npwd` — Remoção total do container embed para todos os veículos: o nome limpo da garagem (ex.: "Pillbox Hill") é exibido diretamente na badge superior direita.
- `2026-07-22` — `npwd` / `nv_garage` — Sincronização em tempo real ao guardar/retirar veículos (cruzamento com `Ox.GetVehicles` na memória), atualização automática da lista ao abrir o celular/app e bloqueio da abertura do Menu de Pausa (ESC) do FiveM.
- `2026-07-22` — `npwd` / `nv_garage` — Implementado rastreamento visual no minimapa com Blip Sprite 161 (garagens) e Sprite 225 (carro na rua) em laranja (cor 47). Adicionada verificação de bloqueador de sinal ativo para impedir rastreamento de veículos jammeados.
- `2026-07-22` — `npwd` / `nv_garage` — Veículos apreendidos direcionam o rastreamento (Blip Sprite 161 laranja) para as coordenadas oficiais do Pátio de Apreensão (`Config.Garages['patio']`).
- `2026-07-22` — `npwd` / `nv_garage` — Adicionado temporizador automático de 30 segundos (`30000ms`) para a remoção automática do blip de rastreamento (Sprite 161/225) do minimapa.
- `2026-07-22` — `npwd` / `nv_garage` — Removidas as funções de geração de rota (`SetBlipRoute`) e waypoint do GPS (`SetNewWaypoint`). O rastreamento agora exibe exclusivamente o Blip Sprite 161 laranja no local por 30s.
- `2026-07-22` — `npwd` / `nv_delivery` — Criado o sistema exportado de notificação do celular (`exports.npwd:createNotification` / `Notify`), adicionados pop-ups push com suporte às marcas 24/7 e Xero Gas, e removidas as notificações antigas via `ox_lib:notify` dos eventos de reabastecimento.
- `2026-07-22` — `npwd` / `nv_delivery` / `nv_adminmenu` — Removidas as notificações via `ox_lib:notify` ao acionar os eventos no `nv_adminmenu` e vinculado o disparo ao evento de rede `npwd:serverCreateNotification` com `AddEventHandler` e gerador de `notisId` para exibição instantânea no celular.
- `2026-07-22` — `npwd` — Removida a notificação do canto superior da tela e implementada a animação de slide-up parcial (*peek*) no canto inferior direito do próprio celular, exibindo o topo do aparelho e a notificação interna ao receber alertas no bolso.
- `2026-07-22` — `npwd` / `ox_core` / `nv_mdt` — Redesign completo do App Banco (Maze Bank): saldo dinâmico em tempo real, fluxo de transferência com input e alerta visual de saldo insuficiente, extrato detalhado de movimentações e nova aba "Faturas" com listagem de faturas pendentes da tabela `nv_mdt_invoices`, botão responsivo "Pagar Todas" e modal de confirmação animado.
- `2026-07-22` — `npwd` / `ox_banking` / `nv_mdt` — Atualizado o fluxo de transferência para utilizar o Número de Telefone único de cada cidadão, aplicado o verde da marca nos botões de confirmação, removido a legenda 'Disponível', sincronizados os logs com `ox_banking` e adicionado o envio de notificações de notificação push no celular (`npwd:serverCreateNotification`) ao receber transferências ou novas faturas (multas policiais, faturas judiciais e ordens de serviço mecânicas).
- `2026-07-22` — `npwd` — Corrigido erro de callback inexistente (`npwd:bank:getData` does not exist): adicionada a importação `@ox_lib/init.lua` nos `server_scripts` do `fxmanifest.lua` e substituída a sintaxe `?.charId` incompatível por sintaxe Lua nativa em `dist/game/server/bank.lua`.
- `2026-07-22` — `npwd` — Padronizado o carregamento do `ox_lib` via `shared_script '@ox_lib/init.lua'` no `fxmanifest.lua` (conforme padrão oficial dos demais recursos `[ox]` e `[dev]`) e adicionado tratamento resiliente com `pcall` e `lib.callback.await` em `dist/game/client/bank.lua`.
- `2026-07-22` — `npwd` / `ox_core` — Diagnosticada e corrigida a causa raiz exata do erro de callback inexistente (`npwd:bank:getData` does not exist): removida a tentativa de chamada a `exports.ox_core:GetOx()` na linha 5 de `dist/game/server/bank.lua` (função inexistente no `ox_core` que interrompia a execução do arquivo na inicialização do resource). Adicionado `print` de confirmação `[npwd:bank] Módulo bancário carregado com sucesso.` e isolamento com `pcall` em todas as rotinas exportadas.
- `2026-07-22` — `npwd` / `oxmysql` — Adicionada a inclusão da biblioteca `'@oxmysql/lib/MySQL.lua'` nos `server_scripts` e dependência `'oxmysql'` em `fxmanifest.lua` do NPWD, e adicionado o fallback seguro `local MySQL = MySQL or exports.oxmysql` no topo de `dist/game/server/bank.lua` para resolver o erro `attempt to index a nil value (global 'MySQL')`.
- `2026-07-22` — `npwd` / `ox_core` — Removido botão redundante de reload do cabeçalho do Banco, padronizadas as badges de faturas com a paleta verde oficial e o nome real da organização emissora (via `exports.ox_core:GetGroup`), adicionada formatação abreviada inteligente (`K`/`M`/`B`) com `white-space: nowrap` no extrato financeiro para evitar quebra de valores, ajustado o tamanho de fonte responsivo do saldo em conta para grandes quantias e adicionada limitação `99+` na badge de contagem de faturas.
- `2026-07-22` — `npwd` / `nv_mdt` / `ox_core` — Atualizado o `INSERT INTO nv_mdt_invoices` no `server/mechanic.lua` do `nv_mdt` para salvar o nome da organização emissora (`org.set`) na coluna `kind`. Atualizada a função em `dist/game/server/bank.lua` para realizar consulta direta na tabela `accounts` (`WHERE owner = ? AND type = 'personal'`), garantindo a exibição exata do saldo total em conta e a resolução do nome da oficina na badge da fatura.
- `2026-07-22` — `nv_phone` (antigo `npwd`) — Atualizada a nomenclatura do script para `nv_phone` (Celular NV2) no `fxmanifest.lua`, `MAPA-SCRIPTS.md` e referências visuais das telas da NUI (`NV2 Phone`, `NV2 Pay`, logs de console e mensagens bancárias).
- `2026-07-22` — `nv_phone` — Removidos os 4 aplicativos da Dock (Telefone, Mensagens, Câmera/Galeria e Ajustes) do `app-grid` principal em `dist/html/index.html`. Cada aplicativo agora possui localização única na tela inicial do celular, eliminando ícones duplicados.
- `2026-07-22` — `nv_phone` — Redesign completo da tela de Ajustes em `dist/html/index.html`: ocultados/removidos todos os emuladores de testes (clima e notificações) e adicionadas as seções completas de configuração do NPWD (Conta/Dispositivo, Modo Avião, Não Perturbe, Volume e Seleção de Toques, Modo Claro/Escuro, Cores da Case Física e Informações do Dispositivo).
- `2026-07-22` — `nv_phone` — Corrigida a limitação de rolagem vertical no Chromium NUI: alterado o container `.view` para `display: block; overflow-y: auto !important; padding: 14px 14px 50px 14px` com cabeçalhos de aplicativos fixos (`position: sticky; top: 0`), garantindo rolagem fluida e 100% dos dados acessíveis com barra discreta de 4px.
- `2026-07-22` — `nv_phone` / `ox_core` — Atualizada a consulta do servidor em `dist/game/server/bank.lua` para retornar o nome real e número de telefone do cidadão (`charName` e `phoneNumber`), vinculando dinamicamente ao card de perfil em Ajustes. Atualizado o `.app-header` com background translúcido `backdrop-filter: blur(20px)` estendido de ponta a ponta (`margin: -14px -14px 14px -14px`) e fixado no topo (`position: sticky; top: -14px`).
- `2026-07-22` — `nv_phone` — Corrigido o erro de sintaxe em `dist/game/server/bank.lua` (linha 290: `unexpected symbol near ')'`) adicionando o fechamento do bloco `if #statement == 0 then`.
- `2026-07-22` — `nv_phone` / `ox_core` — Corrigida a busca do nome do cidadão em `dist/game/server/bank.lua` alterando a consulta MySQL para a coluna `fullName` da tabela `characters`. Atualizadas as informações de dispositivo no `dist/html/index.html` para Modelo: **NV2 Phone**, Sistema Operacional: **NV2 OS v2.0.3** e removida a linha de Armazenamento.
- `2026-07-22` — `nv_phone` — Adicionado disparo automático de `fetchBankData()` ao abrir o NUI do celular ou acessar o aplicativo de Ajustes, garantindo o carregamento instantâneo do nome do player e número de telefone (`Tel: ...`). Aplicada estilização responsiva (`white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 220px`) com `min-width: 0` para suporte gracioso a nomes de cidadãos extensos.
- `2026-07-22` — `nv_phone` / `ox_core` — Alinhada a consulta do servidor em `dist/game/server/bank.lua` ao esquema exato do `install.sql` do `ox_core`: busca encadeada de `firstName`, `lastName`, `fullName` e `phoneNumber` tanto no objeto `GetPlayer(source)` quanto na tabela `characters`.
- `2026-07-22` — `nv_phone` — Reformulação completa do aplicativo de Telefone/Discador: ajustados os botões numéricos do teclado para formato 100% circular (`58x58px`), definida a aba **Recentes** como padrão ao abrir, adicionada filtragem em tempo real por campo de busca e botão de criação de contato na aba **Contatos**, substituído o botão do cabeçalho para **Compartilhar Contato** com varredura de cidadãos próximos (até 5m) e criado o pop-up interativo para **Aceitar / Recusar** contatos recebidos com salvamento no telefone. Criados os módulos `dist/game/client/phone.lua` e `dist/game/server/phone.lua`.
- `2026-07-22` — `nv_phone` — Implementado sistema completo de gerenciamento de chamadas: tela dedicada para chamada ativa (`#view-call-active`) com cronômetro em tempo real, botões de mutar microfone, alto-falante, desligar e minimização para segundo plano através de banner estilo Dynamic Island com controles rápidos. Desenvolvida tela de chamada recebida (`#view-call-incoming`) com opções Atender/Recusar/Ignorar em segundo plano, notificação pop-up para celular fechado e temporizador automático de 60 segundos que registra a chamada como **Perdida** caso não haja atendimento.
- `2026-07-22` — `nv_phone` — Corrigida a tela preta ao disparar chamadas definindo `.phone-screen[data-app="call-active"]` e `#view-call-active` com gradiente e layout flexbox visível. Adicionada formatação automática com espaços para números digitados (`233 695 5555`) com botão rápido de apagar digito (`fa-delete-left`) sem alterar o layout do teclado. Reestruturados os modais de criar contato, compartilhar contato por proximidade e aceitar/recusar contato para serem 100% **internos à tela do celular** (`#phoneScreen` com `position: absolute; inset: 0`).
- `2026-07-22` — `nv_phone` — Corrigido o aninhamento HTML de `#view-phone`: fechada a tag `</div>` de `#view-phone` antes de `#view-call-active` e `#view-call-incoming`, tornando-os containers de primeiro nível diretos em `#phoneScreen`. Isso resolveu 100% o problema onde a desativação de `#view-phone` ocultava a tela de chamada ativa.
- `2026-07-22` — `nv_phone` — Refinamentos completos da experiência de chamadas: removidas as notificações toast de mutar/desmutar e desligar, removido o título "Em Chamada" do cabeçalho com fundo 100% transparente, removido o botão redundante de minimizar no grid, ajustada a contagem de segundos para iniciar apenas após a chamada ser atendida (exibindo "Chamando..." enquanto disca/toca), padronizados os banners flutuantes para o estilo visual de notificações com o Avatar inicial do contato e criado o **Painel de Testes** em Ajustes (`testIncomingCall()`, `testReceiveContact()`, `testMissedCall()`).
- `2026-07-22` — `nv_phone` — Alterado o texto de status de chamada recebida para **"Ligando..."**. Corrigida a função `declineIncomingCall()` para executar `goHome()` e fechar imediatamente a tela de chamada ao recusar. Adicionados eventos de notificação e som frontend no `client/phone.lua` para chamadas recebidas (`npwd:onIncomingCallNotification`) e chamadas perdidas (`npwd:onMissedCallNotification`).
- `2026-07-22` — `nv_phone` — Criados 2 novos tipos de evento de notificação em `spawnNotification()`: `incoming_call` (notificação persistente sem timeout auto-hide, com botões Atender/Recusar e clique que abre a tela de chamada) e `missed_call` (notificação de chamada perdida com clique direto para a aba **Recentes** do Telefone).
- `2026-07-22` — `nv_phone` — Implementado sistema real de chamadas entre jogadores em Lua (`client/phone.lua` e `server/phone.lua`): discagem com validação de existência do número (se inexistente/offline, aguarda 5s em "Chamando..." e exibe "Número não existe", gravando no histórico de Recentes). Transformada a lista de contatos em um **Acordeão Expansível**: ao clicar no contato, revela as opções 📞 Ligar, 💬 Mensagem e ✏️ Editar (com modal interno de edição). Ajustado o cabeçalho `.app-header` para background 100% transparente em todos os aplicativos.
- `2026-07-22` — `nv_phone` — Adicionado gerenciamento de foco de teclado (`npwd:setNuiFocusInput` + `SetNuiFocusKeepInput(false)`) ao clicar em qualquer campo de texto (`<input>` / `<textarea>`), impedindo que o jogador ande ou abra o chat (tecla T) enquanto digita. Adicionada a opção 🗑️ **Excluir** para remover contatos da lista e registros de chamadas do histórico em **Recentes**. Harmonizada a paleta de cores dos ícones e textos de todos os botões do acordeão com o background (Ligar `#10b981`, Mensagem `#38bdf8`, Editar `#fbbf24`, Excluir `#ef4444`).
- `2026-07-22` — `nv_phone` — Implementada a **Persistência Completa em Banco de Dados MySQL (`oxmysql`)**:
  1. **Tabela `npwd_phone_contacts`**: Criação (`saveContact`), Edição (`updateContact`) e Remoção (`deleteContact`) de contatos são salvas e sincronizadas por `identifier` do personagem.
  2. **Tabela `npwd_calls`**: Todas as chamadas realizadas, atendidas, recusadas e perdidas são persistidas automaticamente, permitindo carregar o histórico de **Recentes** (`getRecents`) e excluir chamadas (`deleteRecentCall`).
- `2026-07-22` — `nv_phone` — Removidos **100% dos dados mock** do aplicativo de Telefone (`contactsData = []`, `recentsData = []`, fallbacks de jogadores próximos e placeholders HTML do DOM). Todas as listas agora utilizam puramente os dados reais do banco MySQL e interações em tempo real.
- `2026-07-22` — `nv_phone` — Corrigido o erro de edição de contato `Cannot read properties of undefined (reading 'trim')` passando `avatar: ''` e `display` em todas as requisições NUI e server Lua. Reformuladas as opções de ação dos contatos e de recentes para exibirem **APENAS ÍCONES** (estilo botão circular 4x1 responsivo sem rótulos de texto). Adicionada a função `formatPhoneNumber()` aplicando a máscara visual correta nos números exibidos no aplicativo.
- `2026-07-22` — `nv_phone` — Substituído o botão "+ Criar" ao lado da barra de busca de contatos por um botão responsivo contendo **APENAS ÍCONE** (`<i class="fa-solid fa-user-plus"></i>` com borda e fundo em transparência `#10b981`), padronizando 100% da interface do aplicativo.
- `2026-07-22` — `nv_phone` — Implementado o **Aplicativo de Mensagens / SMS 100% Funcional com Persistência MySQL e Tempo Real**:
  1. **Servidor (`server/phone.lua`)**: Implementadas as rotinas de busca de conversas (`npwd:getConversations`), histórico de mensagens (`npwd:getMessages`), envio (`npwd:serverSendMessage`) e remoção (`npwd:serverDeleteConversation`), persistindo em `npwd_messages`, `npwd_messages_conversations` e `npwd_messages_participants`.
  2. **Cliente (`client/phone.lua`)**: NUI Callbacks de mensagens e escutadores de rede (`npwd:clientReceiveMessage`, `npwd:onIncomingMessageNotification`), reproduzindo o som de mensagem do GTA V (`Event_Message_In`) e gerando notificações de push em tempo real.
  3. **Front-End (`index.html`)**: Interface dinâmica com lista de conversas ativas, busca, balões de conversa (enviadas/recebidas), envio por `Enter` ou botão 📤, modal interno de **Nova Mensagem** por número de telefone e atualização instantânea de balões em tempo real.

- `2026-07-22` — `nv_phone` — Corrigido o erro de tela azul/escura ao abrir o App de Mensagens: fechada a tag `</div>` de `#view-call-incoming` e removida a tag corrompida `</div>v>`, restaurando a exibição de `#view-messages` como container visível independente de primeiro nível.
- `2026-07-22` — `nv_phone` — Corrigida a notificação acidental do Banco *"Erro: Digite o número de telefone do destinatário"*: atribuído o atributo explícito `type="button"` ao botão de transferência bancária (evitando acionamento padrão ao pressionar `Enter` em inputs de outros apps) e adicionada verificação estrita em `promptConfirmTransfer()` garantindo execução única quando a aba `#view-bank` estiver ativa.
- `2026-07-22` — `nv_phone` — Refatorado o layout da tela de Chat (`#view-chat-detail`): posicionado o input de envio na **parte inferior (rodapé)** com espaço de toque adequado, configurado scroll interno independente em `.messages-history` (`flex: 1; overflow-y: auto;`) e implementada a **Memória de Posição de Scroll por Conversa**:
  1. Ao abrir uma conversa pela primeira vez na sessão/após reiniciar o script, a rolagem vai automaticamente para o fim (mensagem mais recente `scrollHeight`).
  2. Ao navegar e rolar pela conversa na sessão, a posição exata de leitura é salva em `chatScrollPositions[key]` e restaurada perfeitamente ao retornar à conversa.
- `2026-07-22` — `nv_phone` — Corrigido o erro de script Lua `@npwd/dist/game/server/phone.lua:24: attempt to call a nil value (method 'get')` e a exibição de `undefined` no modal de compartilhar contato:
  1. **Servidor (`server/phone.lua`)**: Adicionada checagem defensiva `type(pObj.get) == 'function'` e `pcall` em `getPlayerData()` e `getCharIdentifier()`, tratando com segurança todas as estruturas de dados do `ox_core`.
  2. **Front-End (`index.html`)**: Adicionada fallback `displayName = p.name || ('Cidadão ' + p.id)` em `renderNearbyPlayersList()`, impedindo que o texto `undefined` apareça na lista de jogadores próximos.
- `2026-07-22` — `nv_phone` — Corrigida a resolução do nome dos jogadores no aplicativo de telefone: alterado `getPlayerData()` para extrair o **Nome de Personagem Roleplay (RP)** diretamente do objeto do personagem no `ox_core` ou via consulta SQL à tabela `characters` (`firstName`, `lastName`, `fullName`), eliminando a exibição do nome de conta FiveM/Steam (ex: "duduziin").
- `2026-07-22` — `nv_phone` — Implementada a **Notificação Flutuante de Contato Recebido (estilo chamada)** e corrigido o envio entre jogadores:
  1. **Servidor (`server/phone.lua`)**: Ajustada a função `npwd:serverShareContact` para transmitir o contato com o ID numérico correto e disparar `npwd:onIncomingContactNotification` ao alvo.
  2. **Cliente (`client/phone.lua`)**: Adicionado escutador com efeito sonoro `Event_Message_In` e mensagem NUI.
  3. **Front-End (`index.html`)**: Adicionado o tipo de notificação `incoming_contact` exibido no topo (celular aberto ou fechado) com botões circulares interativos de **Aceitar** (✅) e **Recusar** (❌), permitindo abrir o modal de salvamento com um único clique.
- `2026-07-22` — `nv_phone` — Reformulado o **Ciclo de Vida de Chamadas de Voz** e eliminação de elementos visuais fora da moldura do celular:
  1. **Remoção de Scripts Legados (`fxmanifest.lua`)**: Removidas as referências aos arquivos compilados TypeScript legados (`client.js` e `server.js`), eliminando popups pretos e sobreposições indesejadas no canto superior da tela do jogo.
  2. **Confinamento 100% no Aparelho (`index.html`)**: Removida a criação de containers fixos na `document.body` (`showIncomingCallBannerClosed`), garantindo que todas as notificações e chamadas fiquem contidas dentro da moldura física do celular (`#phoneScreen`).
  3. **Lógica de Chamada Infinita & Desconexão Estrita (`server/phone.lua` & `client/phone.lua`)**:
     - Enquanto o chamador não desligar, a ligação permanece chamando continuamente sem expirar arbitrariamente por tempo.
     - Se quem ligou desligar antes do atendimento, o destinatário recebe automaticamente uma **Notificação de Chamada Perdida** e a ligação é encerrada.
     - Se o destinatário recusar a ligação, a notificação **Chamada Recusada** é transmitida para ambos os lados e a chamada é finalizada imediatamente em ambos os aparelhos.
- `2026-07-22` — `nv_phone` — Implementada a **Animação do Personagem na Orelha**, **Integração de Voz pma-voice** e exportações `isPhoneVisible` / `setPhoneVisible`:
  1. **Animação & Prop 3D (`client/phone.lua`)**: Criador dinâmico de prop do celular (`p_amb_phone_01` acoplado na mão direita `SKEL_R_Hand`) e animações realistas: `cellphone_text_read_base` ao usar o aplicativo e `cellphone_call_listen_base` (telefone na orelha) durante chamadas ativas ou em andamento.
  2. **Integração de Voz (`pma-voice`)**: Conexão automática em canal de rádio/ligação de áudio de alta qualidade via `exports['pma-voice']:setCallChannel(callChannel)` ao atender a chamada e limpeza ao desligar.
  3. **Exportações & Correção de Erro (`cl_controls.lua` & `client/phone.lua`)**: Exportados `isPhoneVisible` e `setPhoneVisible` em `client/phone.lua` e adicionadas verificações defensivas com `pcall` em `cl_controls.lua`, corrigindo o erro `No such export isPhoneVisible`.
- `2026-07-22` — `nv_phone` — Corrigida a abertura da interface NUI do telefone ao usar item ou tecla:
  1. **Servidor/Cliente (`client/phone.lua`)**: Atualizado `setPhoneVisible(true)` para disparar obrigatoriamente `SetNuiFocus(true, true)` e a mensagem NUI `{ action: "open" }`, exibindo a interface visual do celular.
  2. **Atalho Teclado & Eventos de Integração (`client/phone.lua`)**: Adicionado atalho nativo de teclado `F1` (`RegisterKeyMapping('phone', ...)`), comando `/phone` e registradas as rotas de rede `npwd:open`, `npwd:close`, `npwd:toggle`, `npwd:setPhoneVisible` para compatibilidade total com o inventário (`ox_inventory`).
- `2026-07-22` — `nv_phone` — Corrigida a movimentação da mira/câmera do jogo ao usar o telefone:
  1. **Servidor/Cliente (`client/phone.lua`)**: Configurado `SetNuiFocusKeepInput(false)` em `setPhoneVisible()`, garantindo que a entrada do mouse seja capturada exclusivamente pela interface NUI sem rotacionar a visão do personagem.
  2. **Bloqueio de Controles (`cl_controls.lua`)**: Adicionada a desativação contínua dos controles de olhar/mira (`DisableControlAction` 1, 2, 24, 25, 140, 257) quando `exports.npwd:isPhoneVisible()` retornar `true`.

- `2026-07-22` — `nv_phone` — Corrigido o fluxo assíncrono do App de Mensagens (abrir conversa, enviar/receber em tempo real) e adicionado indicador "digitando...":
  1. **Bug crítico de entrega (`server/phone.lua`)**: `findOnlinePlayerByNumber` era chamada em `npwd:serverSendMessage` antes de sua declaração `local function` (nil em runtime), impedindo a entrega ao destinatário. A função foi movida para o topo (antes das rotinas de mensagens/chamadas).
  2. **Bug de UI (`index.html`)**: removida a função `openChat(name)` duplicada (1 argumento) que sobrescrevia a versão real `openChat(contactName, targetNumber, conversationId)`, impedindo o carregamento do histórico e o envio com destino; ajustado o botão "Mensagem" dos contatos para passar o número.
  3. **Fonte única da verdade**: cada mensagem agora carrega a flag `self` (definida no servidor em `getMessages` e no eco de `serverSendMessage`), eliminando o balão duplicado do remetente e resolvendo com precisão enviado/recebido (`outgoing`/`incoming`).
  4. **Indicador "digitando..." em tempo real**: novos eventos `npwd:serverSetTyping` (client→server) e `npwd:clientTyping` (server→client) + callback NUI `npwd:setTyping`, com bolha animada de três pontos, debounce de 2.5s e auto-hide de segurança.
- `2026-07-22` — `nv_phone` — Ajustes finos no ciclo de chamadas de voz:
  1. **Animação por estado (`client/phone.lua`)**: quem RECEBE não faz mais a animação de telefone na orelha enquanto toca — apenas ao atender (`npwd:clientCallConnected`); quem LIGA já faz a animação ao iniciar. Ao desligar/encerrar, o jogador passa a fazer a animação de "olhar o celular" (`endCallAnimation`).
  2. **Timeout de 1 min autoritativo no servidor (`server/phone.lua`)**: `SetTimeout(60000)` com `token` de sessão encerra a chamada para ambos e registra **perdida** (chamador recebe `callEnded 'no_answer'`, receptor recebe `clientMissedCall`). Removido o timeout duplicado da NUI.
  3. **Mudo real (`client/phone.lua` + `index.html`)**: novo callback NUI `npwd:setCallMute` usando `MumbleSetActive(false/true)` para silenciar/reativar a voz aos demais da ligação.
  4. **Viva voz por proximidade (`npwd:serverSetSpeaker`)**: jogadores num raio de **1m** entram/saem do canal da chamada via `exports['pma-voice']:setPlayerCall`, ouvindo o interlocutor; limpeza automática ao encerrar. Novo callback NUI `npwd:setCallSpeaker` (viva voz desligado por padrão).
  5. **Recentes em pt-BR (`index.html`)**: data formatada como `DD/MM/AAAA HH:MM` (`formatRecentDate`) e **tempo total** da chamada exibido em atendidas (`callDurationLabel`, a partir do atendimento).
  6. **Compartilhar contato**: com a UI aberta exibe o **modal** de aceitar/recusar; com a UI fechada exibe a **notificação** cujo check aceita/salva e o X recusa direto (dedupe da notificação duplicada no cliente).

- `2026-07-22` — `nv_phone` — Corrigido o viva voz da chamada que não funcionava: o raio de detecção de jogadores próximos em `npwd:setCallSpeaker` (`client/phone.lua`) era de apenas `1.0m` — pequeno demais para captar alguém em pé ao lado, então ninguém era adicionado ao canal (`pma-voice:setPlayerCall`). Ampliado para `2.8m` via constante `SPEAKER_RADIUS`, sem alterar a lógica do servidor.
- `2026-07-22` — `nv_phone` — Correções de conversa, notificações e recentes:
  1. **Nome do contato sumindo (`index.html`)**: criados `normalizePhone`/`resolveContactName`; a lista de conversas e os recentes agora resolvem o nome comparando números sem máscara (hífen/parênteses), e re-renderizam quando os contatos chegam depois (corrige nome virar número).
  2. **Notificação de mensagem só fora da conversa (`index.html`)**: o handler `npwd:createNotification` ignora mensagens (`app: 'messages'`) quando a conversa com o remetente já está aberta (compara `senderNumber` × `activeChatState.targetNumber`).
  3. **Recentes com dados corretos (`server/phone.lua` + `index.html`)**: `getPhoneRecents` calcula `contact` (o outro lado) e `direction` (`outgoing`/`incoming`) em relação ao meu número; status de não atendida/inexistente passou a ser **"Finalizado"**. Removidos os registros otimistas locais (fonte única = banco, recarregado via `refreshRecentsSoon`).
  4. **Layout do recente (`index.html`)**: três linhas — nome/número, status + tempo (atendidas), data/hora.
  5. **Retorno de tela (`index.html`)**: `callReturnView`/`returnFromCall` — ligar/receber guarda a tela atual; recusar/encerrar volta para onde o jogador estava (em vez de sempre ir para a home).
  6. **Chamada em andamento ao fechar a UI (`index.html`)**: `showOngoingCallNotification` + branch `ongoing_call` mantêm a notificação de chamada ativa com cronômetro ao vivo; reabrir o celular volta direto para a tela da ligação.

- `2026-07-22` — `nv_phone` — Três correções no telefone (chamada por notificação, viva voz e contatos duplicados):
  1. **Chamada recebida via notificação (`index.html`)**: os campos da tela `call-incoming` só eram preenchidos com o celular aberto — ao abrir pela notificação apareciam vazios (**"Desconhecido / chamando"**). Agora `receiveIncomingCall` popula sempre via `populateIncomingCallScreen()`, e o `onClick`/reabertura da notificação só age se a chamada ainda estiver `ringing`.
  2. **"Minimizar" na chamada recebida (`index.html`)**: `ignoreIncomingCallToBackground` mostrava o banner **"Em chamada"** (aparência de atendida) numa chamada ainda tocando; passou a apenas voltar à home e **reexibir a notificação de chamada recebida**, mantendo atender/recusar (o timeout de 60s do servidor segue encerrando como perdida).
  3. **Viva voz para quem está na chamada (`server/phone.lua`)**: `serverSetSpeaker`/`clearSpeaker` deixaram de pular jogadores que já estão em outra ligação — agora **todos os próximos** entram no canal do viva voz e o canal anterior de cada um é guardado (`speakerAdded[bysrc] = canalAnterior`) e **restaurado** ao desligar o viva voz/encerrar, sem quebrar ligações alheias.
  4. **Contato duplicado (`server/phone.lua`)**: novo helper `contactExists` (compara número sem máscara); `saveSharedContact` avisa "já existe" em vez de inserir de novo, e `serverAddContact` também deduplica.

- `2026-07-22` — `nv_phone` (NUI `index.html`) — Melhorias no App de Mensagens e notificações:
  1. **Scroll/design**: barras de rolagem estilizadas para conversas e histórico (`overscroll-behavior: contain`); posição de scroll por conversa unificada em `chatKey()` (pelo número), reabrindo onde o jogador parou.
  2. **Excluir conversa**: botão de três pontinhos na lista → `openConversationMenu`/`deleteConversation` (usa o evento existente `npwd:deleteConversation`); na conversa, o ícone de telefone virou menu `openChatMenu` com **Ligar**/**Desligar**.
  3. **Selecionar/copiar**: `user-select: text` nas views `#view-messages`, `#view-chat-detail` e `#view-phone`.
  4. **Notificações**: swipe (arrastar p/ cima ou lados) fecha a notificação (`initNotificationSwipe`), sem disparar o clique.
  5. **Anexos (+)**: botão `.btn-attach` abre menu com **Foto** (modal de URL da galeria → balão com `.msg-image` + visualizador) e **Emoji** (`.emoji-panel`).
  6. **Responder**: botão de responder no balão → preview acima do input e citação no balão. Imagem e resposta são codificadas no próprio texto (`§IMG§`, `§R§…§/R§`) via `encodeMessage`/`decodeMessage`, sem alterar o schema do banco.

- `2026-07-22` — `nv_phone` / `ox_core` — Corrigidos os erros de transferência e pagamento de fatura no App Banco e o nome da org na embed da fatura (`server/bank.lua`):
  1. **Métodos da conta (causa raiz de ambos os erros)**: o objeto de `exports.ox_core:GetCharacterAccount` cruza a fronteira de export como tabela pura (só `accountId`), **sem** `removeBalance`/`addBalance`. Chamá-los dava `nil` → transferência e pagamento sempre falhavam. Criado o helper `callAccount(account, metodo, params)` usando `exports.ox_core:CallAccount(accountId, metodo, params)` (mesmo proxy do wrapper oficial `OxAccount`).
  2. **Destinatário da transferência**: `getCharIdFromPhoneNumber` consultava a coluna inexistente `phone_number` (o correto no ox_core é `phoneNumber`) e usava `p:getPhoneNumber()` (método perdido na serialização). Reescrito para buscar em `characters.phoneNumber` (sem máscara) e resolver o source via `GetPlayerFromCharId`.
  3. **Export incorreto**: `GetPlayerByCharId` (inexistente) → `GetPlayerFromCharId` em todo o `bank.lua` (afetava notificação ao destinatário e emissão de faturas).
  4. **Org na embed verde**: `GetGroup` não é exportado pelo ox_core; a resolução do emissor passou a usar a tabela `ox_groups` (`name` → `label`) como via principal, com mapeamento de tipo (`multa`/`prisao` → "Polícia Militar") como fallback.

[diff_block_end]
