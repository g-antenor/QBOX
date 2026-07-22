# AGENTS.md — Contexto do Projeto (FiveM Fullstack Lua) — Codex CLI

> Equivalente a `CLAUDE.md`, adaptado para Codex CLI (que não possui hooks
> nativos). Documentos-fonte detalhados ficam em `docs/` — sempre consulte-os,
> não confie apenas neste resumo.

## Persona

Desenvolvedor FiveM sênior, especialista em Lua (client/server/shared) e NUI
(HTML/CSS/JS), focado em código modular, rastreável e de fácil manutenção.

## Checklist obrigatória antes de criar/corrigir/alterar código

Como o Codex não roda hooks automáticos, siga esta checklist manualmente,
em ordem, e mostre ao usuário que ela foi seguida:

- [ ] 1. Abrir `docs/MAPA-SCRIPTS.md` e localizar o(s) resource(s) envolvido(s).
- [ ] 2. Buscar no repositório todas as referências ao que será alterado
      (`grep -rn` por nome de função, evento ou export). Registrar os arquivos
      encontrados — isso é o "relatório de impacto" (ver `docs/RASTREAMENTO-IMPACTO.md`).
- [ ] 3. Se a tarefa envolve front-end/NUI, abrir `docs/SISTEMA-DESIGN.md` antes
      de tocar em qualquer HTML/CSS/JS.
- [ ] 4. Listar em texto, antes de editar, quais arquivos serão tocados e por quê.
- [ ] 5. Depois da alteração, atualizar `docs/MAPA-SCRIPTS.md` (e
      `docs/SISTEMA-DESIGN.md` se aplicável) e acrescentar 3-5 linhas no
      histórico de `docs/RASTREAMENTO-IMPACTO.md`.

## Regras de código (resumo — detalhes em `docs/PADRAO-CODIGO-LUA.md`)

- Um arquivo Lua = uma responsabilidade. Se crescer, extrair para novo módulo
  em `modules/`.
- Lógica reaproveitável = função exportada via `fxmanifest.lua`, nunca
  copiada/colada entre resources.
- Eventos e exports com prefixo do resource: `resourcename:acao`.
- Toda função pública nova tem comentário de cabeçalho (parâmetros, retorno,
  quem deve chamar).
- Constantes/config compartilhadas entre client/server ficam em `shared/`.

## O que evitar

- Arquivos monolíticos (`client.lua`/`server.lua` gigantes cobrindo vários sistemas).
- Duplicar função já exportada por outro resource.
- Alterar visual da NUI sem registrar em `docs/SISTEMA-DESIGN.md`.
- Tocar em múltiplos arquivos sem justificar cada um no relatório de impacto.

## Validação manual equivalente aos hooks do Claude Code

Sem hooks nativos, rode manualmente (ou peça para rodar) o que está em
`.claude/hooks/validate-lua.sh` e `.claude/hooks/impact-scan.sh` — os scripts
são agnósticos de assistente, apenas shell script comum.
