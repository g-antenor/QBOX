# Sistema de Design — NUI (Front-end dos Resources)

Este documento é o **mapa de estilo vivo** do projeto. Antes de criar ou
alterar qualquer interface NUI (HTML/CSS/JS/React), o assistente deve:

1. **Ler** este arquivo inteiro.
2. Se a interface a ser alterada já existir e este arquivo estiver desatualizado
   em relação a ela, **primeiro atualizar este documento** com o que já está
   implementado (paleta, fontes, componentes), e só depois aplicar a mudança.
3. Se for uma interface nova, **seguir os padrões aqui definidos** em vez de
   inventar um estilo novo isolado.

> Este arquivo nasce como template. Na primeira execução em um projeto real,
> o assistente deve escanear `resources/*/nui/` (CSS/HTML existentes) e
> preencher as seções abaixo com os valores reais encontrados.

## Paleta de cores

| Token             | Valor (hex) | Uso                                  |
|--------------------|------------|----------------------------------------|
| `--color-bg`       | `#TODO`    | fundo principal dos painéis            |
| `--color-surface`  | `#TODO`    | cards/containers internos              |
| `--color-primary`  | `#TODO`    | ações principais, destaque de marca    |
| `--color-secondary`| `#TODO`    | ações secundárias                      |
| `--color-success`  | `#TODO`    | confirmações, status positivo          |
| `--color-warning`  | `#TODO`    | alertas                                |
| `--color-danger`   | `#TODO`    | erros, ações destrutivas               |
| `--color-text`     | `#TODO`    | texto principal                        |
| `--color-text-muted`| `#TODO`   | texto secundário/legendas               |

## Tipografia

- Fonte principal: `TODO` (ex.: Inter, Rajdhani, Montserrat — comum em HUDs FiveM)
- Escala de tamanho: `TODO` (ex.: 12/14/16/20/28px)
- Peso padrão de títulos: `TODO`

## Espaçamento e grid

- Unidade base: `TODO` (ex.: 4px ou 8px, com múltiplos para padding/margin)
- Raio de borda padrão (`border-radius`): `TODO`
- Sombra padrão de cards/painéis: `TODO`

## Componentes-base (catálogo)

Para cada componente já existente em algum resource, registre aqui para que
novos resources reaproveitem em vez de recriar do zero:

| Componente     | Onde vive (arquivo/resource)         | Descrição rápida |
|----------------|----------------------------------------|-------------------|
| Botão Primário (.action) | `resources/[dev]/nv_garage/html/style.css` | Botão principal vermelho com destaque (Crimson Edge) |
| Botão Secundário (.action-secondary) | `resources/[dev]/nv_garage/html/style.css` | Botão secundário de apoio com ícone e borda sutil para ações auxiliares (ex.: marcar no minimapa) |
| App de Garagem no Phone (#view-garage) | `resources/[pe]/npwd/dist/html/index.html` | Interface dinâmica da garagem no celular NPWD com estatísticas do veículo e botão de marcação no GPS |
| Menu Dropdown (.pw-menu) | `resources/[pe]/npwd/dist/html/index.html` | Menu de contexto (três pontinhos) ancorado a um botão via `openMenuAt()`; fundo sólido (`--phone-bg` + blur); usado no menu de anexo (+) e na lista de conversas (excluir). Na conversa, o botão de ligar voltou a ser um ícone de telefone direto |
| Preview de Resposta (.reply-preview) | `resources/[pe]/npwd/dist/html/index.html` | Barra acima do input citando a mensagem sendo respondida; citação no balão via `.msg-reply-quote` |
| Painel de Emoji (.emoji-panel) | `resources/[pe]/npwd/dist/html/index.html` | Grade de emojis inserida no input; aberta pelo botão de anexo (+) `.btn-attach` |
| Balão de Mensagem (.msg-bubble) | `resources/[pe]/npwd/dist/html/index.html` | Balão de chat (incoming/outgoing) com suporte a imagem (`.msg-image`), citação e botão de responder ao hover |
| App Drop Feed (#view-twitter) | `resources/[pe]/npwd/dist/html/index.html` | Interface do aplicativo Drop padronizada com `.app-header`, perfil no canto superior direito, feed único sem abas, cards `.tweet-card` com apenas comentários e curtidas, botão flutuante `.drop-fab`, modal `#dropProfileModal` e rodapé de 3 ícones `.drop-bottom-nav` |
| Barra Inferior Drop (.drop-bottom-nav) | `resources/[pe]/npwd/dist/html/index.html` | Navegação inferior do Drop com três ícones interativos (`.nav-icon`) |
| Modal Exclusão de Nota (#modalDeleteNote) | `resources/[pe]/npwd/dist/html/index.html` | Modal de confirmação para exclusão de notas no editor com botões Sim (Excluir) e Não (Cancelar) |
| Câmera (#cameraOverlay) | `resources/[pe]/npwd/dist/html/index.html` | Overlay de câmera em tela cheia (fora do `#phoneWrapper`, que é ocultado via `body.cam-open`): viewfinder `.cam-frame` (portrait/landscape), botão disparo `.cam-shutter`, selfie `.cam-flip`, orientação, miniatura da última foto e flash `.cam-flash`. Renderiza sobre a câmera do jogo (`screenshot-basic`) |
| Galeria (#view-gallery) | `resources/[pe]/npwd/dist/html/index.html` | Grid de fotos persistidas (`.photo-grid#galleryGrid`) + visualizador `#galleryViewer` com excluir; alimentada por `npwd:getPhotos` |
| Topbar por app (.app-header) | `resources/[pe]/npwd/dist/html/index.html` | Cabeçalho com fundo no tom do app via `--hdr` por `[data-app]` + blur. Navegação: chevron de voltar só em `.view.keep-back` (sub-telas); `.home-bar` some no Home e volta ao menu principal nos apps |
| Busca na conversa (.chat-search-bar) | `resources/[pe]/npwd/dist/html/index.html` | Barra de busca + resultados `.chat-search-results` (via `npwd:searchMessages`) que levam à mensagem (realce `.msg-jump`); paginação com `.load-older` e menu `openChatMenu` (Buscar/Ligar) |

## Regras de consistência

- Nova interface **sempre** reaproveita tokens de cor/tipografia daqui — não
  criar cor "one-off" sem justificar e registrar aqui.
- Se um resource precisar de um componente parecido com um já catalogado,
  **reaproveitar/estender** o componente existente (extrair para um local
  compartilhado se dois ou mais resources passarem a usá-lo), não duplicar o
  CSS/markup.
- Ao introduzir um padrão visual novo (nova cor, componente, espaçamento),
  **atualizar esta tabela na mesma tarefa** — não deixar para depois.

## Histórico de mudanças de estilo

- `2026-07-22` — Criado componente `.action-secondary` e ícone `#ic-local` na NUI do `nv_garage` para ação de marcação de minimapa / GPS waypoint.
- `2026-07-22` — Implementada renderização dinâmica dos cartões de veículo no App de Garagem do celular `npwd` integrado ao `nv_garage`.
- `2026-07-22` — `npwd` App Mensagens: novos componentes `.pw-menu` (dropdown de três pontinhos), `.reply-preview` + `.msg-reply-quote` (responder mensagem), `.emoji-panel` + `.btn-attach` (anexos/emoji) e `.msg-image` (foto no balão). Barras de rolagem estilizadas para `.messages-history`/`.chat-list`/`#conversationsContainer` e seleção de texto (`user-select: text`) habilitada nas views de mensagens e telefone.
- `2026-07-22` — `npwd` App Drop: reformulação completa com cabeçalho com logo cyan, abas "Para você"/"Seguindo", cards de tweets interativos com anexos de imagem, curtidas/retweets dinâmicos, botão flutuante (FAB) e modal de composição de post `#dropComposeModal`.
- `2026-07-22` — `npwd` App Drop: padronização visual com os demais apps (.app-header), substituição da engrenagem pelo botão de Perfil (`#dropProfileModal`), remoção de abas (feed único), remoção do ícone de e-mail do rodapé (3 ícones) e remoção dos contadores de retweet e visualizações das postagens.
- `2026-07-22` — `npwd` App Drop: estilização de barra de rolagem fina customizada em cyan (`.drop-feed::-webkit-scrollbar`), rolagem suave (`scroll-behavior: smooth`), tratamento defensivo de quebra de texto/mídias e aprimoramento responsivo total do feed e rodapé.
- `2026-07-22` — `npwd` App Drop: aumentado o espaçamento das bordas laterais nos cartões de postagem (`.tweet-card`: `padding: 16px 22px`, `gap: 14px`) para proporcionar maior respiro visual na tela do aparelho.
- `2026-07-22` — `npwd` App Drop: reformulação dos cartões para containers isolados (`background: var(--phone-card)`, `border-radius: 16px`, `margin-bottom: 12px`) com recuo lateral de `14px` em `.drop-feed`, eliminando o toque direto nas bordas físicas do celular e na barra de rolagem.
- `2026-07-22` — `npwd` App Drop: ajustado a margem (`margin: 0 0 4px 0`) e padding (`padding: 14px 20px 8px 20px`) do cabeçalho `#view-twitter .app-header` para conceder `20px` de recuo lateral no botão voltar e no perfil, afastando-os das bordas metálicas da tela.
- `2026-07-22` — `npwd` App Drop: adicionados componentes `.drop-format-toolbar` e `.drop-compose-body` (editor Rich Text com suporte a negrito, listas e mídias), `.drop-profile-tabs` + `.drop-gallery-grid` (abas de Postagens e Galeria no perfil) e modal `#dropEditProfileModal` para edição de Nome de exibição e foto de Avatar.
- `2026-07-22` — `npwd` App Drop: adicionado modal de cadastro/registro de conta (`#dropAuthModal`) para criação de `@username` único e fixo (com campo desabilitado `#dropEditHandleDisabled` em `#dropEditProfileModal` para impedir alteração posterior) e dados de senha.
- `2026-07-23` — `npwd` App Notas: alterada a cor do ícone `fa-solid fa-floppy-disk` no botão "Salvar Nota" para azul (`#3b82f6`) e criado o modal `#modalDeleteNote` com confirmação de exclusão da nota.
- `2026-07-23` — `npwd` App Quack: rebranding completo do aplicativo Drop para **Quack** — nova marca visual com ícone de patinho (SVG/Duck), paleta temática em amarelo/amber (`#f59e0b`, `#facc15`, `#d97706`), barra de rolagem amarela e exibição obrigatória do formulário de criação de conta (`#dropAuthModal`) no primeiro acesso ao abrir o aplicativo.
- `2026-07-23` — `npwd` App Quack: reestruturação dos cartões de posts (`.tweet-user`: `flex-direction: column`) exibindo o Nome de exibição na primeira linha, o `@username` na segunda e o conteúdo na terceira. Adicionado suporte responsivo com quebra de linha (`word-break: break-word` / `overflow-wrap: anywhere`) para nomes extensos sem estourar o container, além de destacar o `@` do usuário em amarelo (`#f59e0b`) nos modais e feed.
- `2026-07-23` — `npwd` App Quack: criada a tela de Login (`#dropLoginModal`) como modal principal de entrada no Quack ao abrir sem autenticação, exigindo `@username` e senha de acesso. Adicionados botões/links de alternância para o modal de cadastro (`#dropAuthModal`) e autenticação contra banco de contas salvas.
- `2026-07-23` — `npwd` / `nv_phone`: elevada a sobreposição da barra inferior `.home-bar` para `z-index: 99999`, garantindo visibilidade e interatividade constante sobre qualquer tela ou modal ativo (incluindo autenticação do Quack). Adicionado fechamento automático de modais ao acionar `goHome()` e botão de fechar (`X`) nos modais de Login/Cadastro.
- `2026-07-23` — `npwd` App Quack: adicionados alertas de erro visuais (`#dropLoginErrorAlert` e `#dropRegErrorAlert`) nos modais de Login e Cadastro, validação estrita de campos obrigatórios e duplicados no registro e menu de 3 pontos (`#dropProfileOptionsMenu`) no perfil com opções **Editar Perfil** e **Deslogar**.
- `2026-07-23` — `npwd` App Matchmaker: reformulação completa da NUI do Match (`#view-match`) — adicionados modais de Login (`#matchLoginModal`), Cadastro (`#matchRegisterModal`), Configuração de Perfil (`#matchProfileConfigModal` com 6 fotos, Bio, O que procura, Tags, botões "Inativar" e "Excluir"), Feed com gestos de Swipe/Drag (Like/Dislike), modal celebrativo "Deu Match! 🎉" com "Iniciar Chat", aba de Chats com busca por nome em tempo real, tela de conversa com seletor de emojis (`#matchEmojiPickerBox`) e barra de rolagem customizada rosa/magenta (`.match-scroll`).
- `2026-07-23` — `nv_phone`: corrigido o aninhamento HTML do elemento `.home-bar` para o interior de `.phone-screen` e adicionada a regra CSS `.phone-screen:not([data-app="home"]) .home-bar { display: block; }`, garantindo que a barra de voltar fique rigidamente contida na tela física do celular e visível exclusivamente ao acessar um aplicativo.
