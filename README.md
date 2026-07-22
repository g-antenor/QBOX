# Kit de Contexto IA — Projeto FiveM (Fullstack Lua)

Este diretório é um **kit de prompts/contexto** para ser copiado na raiz de qualquer
recurso/projeto FiveM. Ele padroniza como **Claude Code**, **Codex (OpenAI)** e
**Gemini CLI** devem entender, criar, corrigir e alterar scripts Lua (client/server/shared)
e interfaces NUI (HTML/CSS/JS), sem depender de qual assistente está sendo usado.

## Como funciona

Cada assistente lê um arquivo de entrada diferente, mas todos apontam para os
**mesmos documentos-fonte** em `docs/`, evitando divergência de comportamento:

| Assistente     | Arquivo de entrada lido automaticamente | O que ele faz |
|----------------|------------------------------------------|----------------|
| Claude Code    | `CLAUDE.md` + `.claude/settings.json` (hooks) + `.claude/commands/*` | Segue as regras e roda hooks de validação a cada edição |
| Codex CLI      | `AGENTS.md` | Segue as mesmas regras, sem hooks nativos (checklist manual embutida) |
| Gemini CLI     | `GEMINI.md` | Segue as mesmas regras, sem hooks nativos (checklist manual embutida) |

`CLAUDE.md`, `AGENTS.md` e `GEMINI.md` têm o **mesmo conteúdo de regras**, cada um
apenas adaptado ao formato que o respectivo assistente espera. Nenhum conhecimento
de projeto deve viver *só* dentro de um desses três arquivos — regras de negócio,
arquitetura, padrão de código e design system ficam em `docs/`.

## Estrutura

```
.
├── CLAUDE.md              # entrada Claude Code
├── AGENTS.md              # entrada Codex CLI
├── GEMINI.md              # entrada Gemini CLI
├── .claude/
│   ├── settings.json      # hooks de validação (só Claude Code executa nativamente)
│   ├── hooks/
│   │   ├── validate-lua.sh    # valida sintaxe/estilo Lua antes/depois de editar
│   │   └── impact-scan.sh     # varre o repo em busca de dependentes de uma função/evento
│   └── commands/
│       ├── novo-recurso.md    # /novo-recurso — bootstrap de resource novo
│       └── impacto.md         # /impacto — gera relatório de impacto antes de alterar algo
└── docs/
    ├── ARQUITETURA.md         # convenção de pastas/arquivos de um resource FiveM
    ├── PADRAO-CODIGO-LUA.md   # como modularizar, nomear, exportar funções
    ├── RASTREAMENTO-IMPACTO.md# processo de mapear impacto antes de editar/corrigir
    ├── SISTEMA-DESIGN.md      # paleta, tipografia e componentes de NUI
    └── MAPA-SCRIPTS.md        # tabela viva: resource ↔ resource, quem depende de quem
```

## Primeiro uso em um projeto novo

1. Copie esta pasta inteira para a raiz do repositório FiveM.
2. Rode o comando (Claude Code) `/novo-recurso` ou peça manualmente (Codex/Gemini)
   para o assistente preencher `docs/MAPA-SCRIPTS.md` e `docs/SISTEMA-DESIGN.md`
   com base no código já existente (eles começam como *templates vazios*).
3. A partir daí, toda solicitação de correção/criação/alteração deve seguir o
   fluxo descrito em `docs/RASTREAMENTO-IMPACTO.md` antes de tocar em código.

## Princípios inegociáveis (resumo)

- **Nunca** engordar um único arquivo: lógica nova = função nova, e se o arquivo
  já está grande, nova lógica = novo módulo (`.lua` separado) exportado/importado.
- **Sempre** mapear impacto (quem chama, quem exporta, quais eventos) antes de
  editar algo que já existe.
- **Sempre** atualizar `docs/MAPA-SCRIPTS.md` quando um script novo for criado
  ou uma dependência mudar.
- Front-end (NUI) só é alterado depois de consultar/atualizar `docs/SISTEMA-DESIGN.md`.
