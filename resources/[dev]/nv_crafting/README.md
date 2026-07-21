# nv_crafting

As bancadas e receitas ficam em `config.lua`. O formato de coordenada e o
mesmo do ox_inventory (`vec3(x, y, z)`). O resource e iniciado automaticamente
por `start [dev]` no `server.cfg`.

## Acesso

- `public = true`: qualquer jogador pode usar.
- `access = { set = 'nome', minGrade = 1, permission = 'craft' }`: exige o
  grupo, o grade minimo e a permissao `group.nome.craft` configurada no cargo
  pelo painel do `nv_orgs`.

O `ox_target` faz o filtro visual por grupo/grade. O servidor repete essa
validacao, confere a distancia e a permissao antes de abrir e antes de entregar
o item.

## Prop

Use `prop = { enabled = true, model = 'prop_tool_box_04', offset = vec3(...) }`
para criar uma caixa de ferramentas. Com `enabled = false` (ou sem `prop`), a
bancada continua utilizavel por uma zona invisivel.

O ponto do `ox_target` e o marcador no chao sao criados independentemente do
prop. Use `marker = false` dentro de um projeto para ocultar apenas o marcador.

## Receita

```lua
{
    id = 'lockpick', item = 'lockpick', label = 'Lockpick', count = 2,
    duration = 5000, ingredients = { scrapmetal = 5 }
}
```

Todos os nomes precisam existir em `ox_inventory/data/items.lua`.

Os resultados ficam na bandeja compartilhada da propria bancada. Cada unidade
e uma entrada separada, pode ser retirada individualmente por qualquer jogador
com acesso ou em conjunto pelo botao **Pegar todos**. A fila vive em memoria e
e limpa ao reiniciar o resource.

Para fabricar, selecione um projeto e arraste cada material da coluna esquerda
para o encaixe correspondente. Ao clicar em **Fabricar item**, a interface fecha
e a animacao roda no personagem. Depois, abra a bancada novamente pelo target
para encontrar o resultado na coluna direita.

O campo **Quantidade** multiplica materiais, duracao e resultados. O limite
global e `Config.MaxCraftQuantity` e tambem e validado no servidor.

## Editor do MDT da mecanica

Pontos privados com `access.set` aparecem na aba **Crafting** do MDT da oficina
que possui o mesmo set. Cargos com a permissao `craft` podem criar, editar e
excluir receitas usando o catalogo completo do ox_inventory. As receitas ficam
em `nv_crafting_recipes` e entram na bancada sem reiniciar os resources.

Receitas estaticas podem declarar `layout` para posicionar os encaixes em um
formato visual. `columns` e `rows` definem a grade; cada ingrediente em `slots`
aceita `column`, `row`, `width` e `height`. O layout nao altera o consumo nem a
validacao do servidor.

Materiais sao sempre consumidos. Itens adicionados como ferramentas usam o
percentual de desgaste configurado quando o slot possui durabilidade; quando o
item nao possui durabilidade, uma unidade e consumida por fabricacao.
