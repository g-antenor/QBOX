# Arquitetura — Convenção de Resource FiveM

Este documento define a estrutura padrão que **todo resource** do projeto deve
seguir. Ele existe para que qualquer assistente (Claude/Codex/Gemini) crie e
edite código de forma previsível.

## Estrutura de pastas de um resource

```
resources/[nome_do_resource]/
├── fxmanifest.lua
├── client/
│   ├── main.lua          # bootstrap/coordenação, pouca lógica de negócio
│   ├── <sistema_a>.lua   # ex: vehicle.lua, hud.lua, menu.lua
│   └── <sistema_b>.lua
├── server/
│   ├── main.lua
│   ├── <sistema_a>.lua
│   └── <sistema_b>.lua
├── shared/
│   ├── config.lua        # configs/constantes usadas por client e server
│   └── utils.lua         # funções puras reaproveitáveis (sem side-effect de rede)
├── modules/               # lógica extraída de um sistema que cresceu demais
│   └── <sistema_a>/
│       ├── init.lua
│       └── helpers.lua
└── nui/                   # apenas se o resource tiver interface
    ├── index.html
    ├── src/
    └── dist/ (build, se aplicável)
```

## Regras de nomenclatura

- Nome do resource: `snake_case`, prefixo do sistema quando fizer parte de um
  conjunto (ex.: `esx_garage`, `qb_inventory`).
- Eventos: `resourcename:contexto:acao` (ex.: `esx_garage:client:openMenu`).
- Exports: verbo + substantivo, sem prefixo redundante do resource (o prefixo
  já vem do `exports['resourcename']`).
- Arquivos: `snake_case.lua`, nome descreve o **sistema**, não o "tipo" genérico
  (evite `functions.lua`, `misc.lua`, `utils2.lua`).

## `fxmanifest.lua` — checklist mínima

```lua
fx_version 'cerulean'
game 'gta5'

client_scripts {
  'shared/config.lua',
  'client/main.lua',
  'client/*.lua'
}

server_scripts {
  'shared/config.lua',
  'server/main.lua',
  'server/*.lua'
}

exports {
  'nomeDaFuncaoExportada'
}

server_exports {
  'nomeDaFuncaoExportadaServer'
}
```

> Evite `client/*.lua`/`server/*.lua` com wildcard quando a ordem de carga
> importa (dependências entre arquivos) — nesse caso liste explicitamente.

## Quando extrair para `modules/`

Extraia um sistema de `client/<sistema>.lua` ou `server/<sistema>.lua` para
`modules/<sistema>/` quando:
- O arquivo passar de ~300 linhas (aviso automático do hook `validate-lua.sh`), ou
- O sistema tiver mais de uma responsabilidade clara (ex.: "garagem" cobrindo
  UI + lógica de spawn + lógica de persistência → 3 módulos), ou
- Mais de um resource precisar reaproveitar parte dessa lógica.

Veja `docs/PADRAO-CODIGO-LUA.md` para o passo a passo de modularização.
