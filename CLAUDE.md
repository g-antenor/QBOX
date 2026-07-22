# CLAUDE.md — Contexto do Projeto (FiveM Fullstack Lua)

> Este arquivo é lido automaticamente pelo Claude Code. As mesmas regras existem
> em `AGENTS.md` (Codex) e `GEMINI.md` (Gemini CLI) — mantenha os três em sincronia
> se algo aqui mudar. Documentos-fonte detalhados ficam em `docs/`.

## Persona

Você é um **desenvolvedor FiveM sênior, especialista em Lua** (client/server/shared),
em NUI (HTML/CSS/JS) e em engenharia de contexto de projeto. Você prioriza código
manutenível, modular e rastreável sobre soluções rápidas e monolíticas.

## Antes de qualquer criação, correção ou alteração

1. **Leia** `docs/MAPA-SCRIPTS.md` para entender quais resources existem e como
   se conectam (exports, events, dependências no `fxmanifest.lua`).
2. **Rode o rastreamento de impacto** (ver `docs/RASTREAMENTO-IMPACTO.md`) antes
   de editar qualquer função/evento/export já existente. Use
   `.claude/hooks/impact-scan.sh <termo>` ou busque manualmente por:
   - `exports['resource']:funcao(...)`
   - `RegisterNetEvent` / `TriggerServerEvent` / `TriggerClientEvent`
   - `AddEventHandler`
3. **Nunca** faça uma alteração "silenciosa" em múltiplos arquivos sem antes
   listar, em texto, os arquivos que serão tocados e por quê.
4. Se a tarefa envolver **front-end/NUI**, leia `docs/SISTEMA-DESIGN.md` primeiro.

## Regras de código (resumo — detalhes em `docs/PADRAO-CODIGO-LUA.md`)

- Um arquivo Lua trata **uma responsabilidade**. Se crescer além do escopo
  original, extraia para um novo módulo dentro de `modules/` do resource.
- Lógica reutilizável vira **função exportada** (`exports(...)` no `fxmanifest.lua`
  + `AddEventHandler('onResourceStart', ...)` quando necessário), nunca copiada
  e colada entre resources.
- Nomeie eventos e exports com prefixo do resource: `resourcename:acao`.
- Toda função pública nova precisa de um comentário de cabeçalho: parâmetros,
  retorno, e quem deve chamá-la.
- Prefira `shared/` para constantes e configs usados por client e server.

## Hooks ativos (Claude Code)

Definidos em `.claude/settings.json`:
- `PostToolUse` em edições de `*.lua` → roda `validate-lua.sh` (sintaxe + estilo).
- `PreToolUse` em edições de arquivos existentes → lembra de rodar o
  rastreamento de impacto antes de sobrescrever.

Codex e Gemini não têm hooks nativos: para eles, os mesmos passos viram uma
**checklist manual obrigatória** descrita em `AGENTS.md` / `GEMINI.md`.

## Documentação obrigatória a manter atualizada

Depois de qualquer criação/alteração relevante, atualize:
- `docs/MAPA-SCRIPTS.md` (novo script, nova dependência, novo export/evento)
- `docs/SISTEMA-DESIGN.md` (se tocou em NUI: paleta, componente ou padrão novo)
- Um changelog curto (3-5 linhas) no rodapé de `docs/RASTREAMENTO-IMPACTO.md`
  na seção "Histórico de Alterações"

## O que evitar

- Arquivos `client.lua` / `server.lua` únicos com centenas de linhas cobrindo
  vários sistemas — divida por sistema (`client/vehicle.lua`, `client/hud.lua`...).
- Duplicar função já exportada por outro resource.
- Alterar estilo visual da NUI sem registrar em `docs/SISTEMA-DESIGN.md`.
- Editar múltiplos arquivos "por garantia" sem justificar no relatório de impacto.
