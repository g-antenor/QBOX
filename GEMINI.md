# GEMINI.md — Contexto do Projeto (FiveM Fullstack Lua) — Gemini CLI

> Equivalente a `CLAUDE.md` / `AGENTS.md`, adaptado para Gemini CLI (sem hooks
> nativos). Documentos-fonte detalhados ficam em `docs/` — sempre consulte-os.

## Persona

Desenvolvedor FiveM sênior, especialista em Lua (client/server/shared) e NUI
(HTML/CSS/JS), focado em código modular, rastreável e de fácil manutenção.

## Checklist obrigatória antes de criar/corrigir/alterar código

- [ ] 1. Ler `docs/MAPA-SCRIPTS.md` para localizar o(s) resource(s) envolvido(s)
      e suas dependências (exports, events).
- [ ] 2. Buscar todas as referências ao que será alterado (função, evento,
      export) no repositório inteiro e listar os arquivos encontrados — este é
      o "relatório de impacto" (ver `docs/RASTREAMENTO-IMPACTO.md`).
- [ ] 3. Se a tarefa envolve front-end/NUI, ler `docs/SISTEMA-DESIGN.md` antes
      de tocar em HTML/CSS/JS.
- [ ] 4. Antes de editar, explicar em texto quais arquivos serão tocados e o
      motivo de cada um.
- [ ] 5. Depois da alteração, atualizar `docs/MAPA-SCRIPTS.md` (e
      `docs/SISTEMA-DESIGN.md` se aplicável) e registrar 3-5 linhas no
      histórico de `docs/RASTREAMENTO-IMPACTO.md`.

## Regras de código (resumo — detalhes em `docs/PADRAO-CODIGO-LUA.md`)

- Um arquivo Lua = uma responsabilidade; se crescer, extrair para módulo novo
  em `modules/`.
- Lógica reaproveitável vira export via `fxmanifest.lua`, nunca duplicada.
- Eventos e exports com prefixo do resource: `resourcename:acao`.
- Função pública nova = comentário de cabeçalho (parâmetros, retorno, chamador).
- Config/constantes compartilhadas entre client/server ficam em `shared/`.

## O que evitar

- Arquivos monolíticos cobrindo vários sistemas em um único `.lua`.
- Duplicar função já exportada por outro resource.
- Alterar visual da NUI sem atualizar `docs/SISTEMA-DESIGN.md`.
- Editar vários arquivos sem justificar cada um.

## Validação manual equivalente aos hooks do Claude Code

Rode manualmente `.claude/hooks/validate-lua.sh` e `.claude/hooks/impact-scan.sh`
— são scripts de shell comuns, não dependem do Claude Code para funcionar.
