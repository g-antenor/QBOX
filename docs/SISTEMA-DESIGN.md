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
