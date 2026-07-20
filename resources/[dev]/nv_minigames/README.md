# nv_minigames

Quatro minigames em NUI vanilla (sem build), tema **Crimson Edge**, todos
exibidos **centralizados no bottom** — mesmo eixo vertical da progressbar do
ox_lib (`--stage-bottom: 10vh` em `html/style.css`).

## Jogos

| `game` | Como joga | Falha quando |
|---|---|---|
| `locked` | Anel giratório: pressione **Espaço** com a agulha dentro do setor vermelho. Cada acerto avança um pino, inverte o sentido e acelera. | Trava fora do setor |
| `mines` | Grade de casas: clique revelando apenas as seguras até completar a meta. | Clica numa mina |
| `skillbar` | Cursor em vaivém: pressione **Espaço** dentro do setor, uma vez por rodada. | Para fora do setor |
| `timing` | A barra enche uma vez por rodada: pressione **Espaço** enquanto ela cruza a janela. | Aperta fora da janela, ou deixa a barra completar |

**ESC** cancela qualquer partida (conta como falha).

---

## Como chamar

Todos os exports são **bloqueantes** e devolvem `boolean` (sucesso/falha), no
mesmo estilo do `lib.skillCheck` do ox_lib. Chame de dentro de uma thread
(`CreateThread`, handler de evento, `onSelect` do ox_target) — o export usa
`Citizen.Await`.

### 1. Por preset — forma recomendada

Registre a dificuldade em [`config.lua`](config.lua) e chame pelo nome. O
código que usa o minigame não carrega número nenhum, e balancear a atividade
vira uma edição de config:

```lua
if exports.nv_minigames:Start('arrombar_porta') then
    -- destrancou
else
    -- falhou
end
```

Ajuste pontual sem criar um preset novo (o segundo argumento sobrescreve):

```lua
exports.nv_minigames:Start('arrombar_porta', { pins = 6, timeout = 20000 })
```

### 2. Direto, sem preset

Quando não vale a pena nomear:

```lua
exports.nv_minigames:Locked({ difficulty = 'hard' })
exports.nv_minigames:Mines({ size = 6, mines = 9, reveals = 8 })
exports.nv_minigames:SkillBar({ rounds = 4 })
exports.nv_minigames:ProgressTiming({ difficulty = 'easy' })

-- genérico
exports.nv_minigames:Play('locked', { difficulty = 'medium' })
```

### 3. Cancelar

```lua
exports.nv_minigames:Cancel()   -- aborta a partida em andamento (conta como falha)
```

### Exemplo real (ox_target)

```lua
exports.ox_target:addBoxZone({
    coords = vec3(0.0, 0.0, 0.0),
    size = vec3(1, 1, 2),
    options = {
        {
            label = 'Arrombar',
            icon = 'fa-solid fa-lock',
            onSelect = function()
                if exports.nv_minigames:Start('arrombar_porta') then
                    lib.notify({ type = 'success', description = 'Destrancado' })
                else
                    lib.notify({ type = 'error', description = 'Você falhou' })
                end
            end
        }
    }
})
```

---

## Config

Arquivo: [`config.lua`](config.lua).

### `Config.Default`

Aplicado a qualquer chamada que não especifique:

```lua
Config.Default = {
    difficulty = 'medium',  -- 'easy' | 'medium' | 'hard'
    timeout    = 30000,     -- ms até a partida falhar sozinha
}
```

### `Config.Presets`

Cada preset **precisa** de `game`. Todo o resto é opcional e sobrescreve o
preset de dificuldade interno do jogo:

```lua
Config.Presets = {
    ['arrombar_veiculo'] = {
        game       = 'locked',   -- obrigatório
        difficulty = 'hard',     -- base
        pins       = 5,          -- sobrescreve o preset 'hard'
        timeout    = 25000,
    },
}
```

Presets que já vêm prontos: `arrombar_porta`, `arrombar_veiculo`, `cofre`,
`desarmar`, `hackear`, `reparo`, `lockpick_rapido`, `abastecer`, `ignicao`.

### Presets em uso pelos resources

Estes já estão ligados. Mexer neles muda a dificuldade da atividade inteira —
o resource que chama não carrega número nenhum.

| Preset | Jogo | Quem usa |
|---|---|---|
| `arrombar_tranca` | `skillbar` | `nv_garage` — lockpick na tranca do veículo |
| `ligacao_direta` | `skillbar` | `nv_garage` — alicate/lockpick no contato (**errar toma choque e tira vida**) |
| `reciclagem` | `skillbar` | `nv_recycle` — vasculhar a sucata (passa `zone`/`speed` por rodada) |
| `esfolar` | `timing` | `nv_hunting` — cada corte na carcaça |
| `pescar_t0`…`pescar_t4` | `timing` | `nv_hunting` — um por tier do peixe |

### Parâmetros por jogo

| `game` | Parâmetros |
|---|---|
| `locked` | `pins` (nº de pinos), `zone` (graus do setor), `speed` (graus/s) |
| `mines` | `size` (lado da grade), `mines` (nº de minas), `reveals` (casas seguras a revelar) |
| `skillbar` | `rounds`, `zone` (% da barra), `speed` (%/s) |
| `timing` | `rounds`, `window` (% da barra), `duration` (ms por rodada) |

Valores maiores de `zone`/`window` = **mais fácil**. Maiores de `speed` = mais difícil.

### `Config.AllowUnknownPreset`

```lua
Config.AllowUnknownPreset = false
Config.Fallback = { game = 'skillbar', difficulty = 'medium' }
```

Com `false` (padrão), um preset inexistente imprime aviso no console e devolve
`false` — bom para pegar erro de digitação em desenvolvimento. Com `true`, cai
no `Config.Fallback` em vez de falhar.

---

## Teste rápido

```
/minigame locked hard          # jogo cru
/minigame mines
/minigamepreset                # lista os presets disponíveis
/minigamepreset arrombar_porta # roda um preset
```

O resultado sai no console (F8).

---

## Nota sobre o ox_lib

O posicionamento bottom-center da progressbar / progressCircle / skillCheck do
ox_lib é aplicado por `resources/[ox]/ox_lib/patch-bottom-ui.js`. Se o ox_lib
for atualizado ou reconstruído, rode de novo:

```
node resources/[ox]/ox_lib/patch-bottom-ui.js
```

Os offsets (`10vh` / `16vh`) ficam no topo desse script e devem acompanhar
`--stage-bottom` aqui em `html/style.css`.
