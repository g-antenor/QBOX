Config = {}

Config.InteractionDistance = 2.0
Config.ServerDistance = 4.0
Config.MaxCraftQuantity = 50
Config.InventoryImagePath = 'https://cfx-nui-ox_inventory/web/images/'

-- Indicador no chao desativado; a bancada continua acessivel pelo ox_target.
-- Um projeto especifico ainda pode habilita-lo com `marker = { enabled = true }`.
Config.Marker = {
    enabled = false,
    drawDistance = 25.0,
    type = 1,
    scale = vec3(0.55, 0.55, 0.18),
    color = { r = 229, g = 43, b = 67, a = 155 },
    zOffset = -0.92
}

-- Cada projeto e uma bancada independente. Use vec3 como em data/crafting.lua
-- do ox_inventory. `public = true` ignora set/cargo. Para organizacoes, o
-- jogador precisa pertencer ao set, ter o grade minimo E possuir a permissao
-- group.<set>.<permission (a permissao e configurada no cargo pelo nv_orgs).
Config.Projects = {
    {
        id = 'oficina_publica',
        label = 'Oficina Publica',
        subtitle = 'Bancada comunitaria',
        coords = vec3(-1147.083008, -2002.662109, 13.180260),
        heading = 315.0,
        public = true,

        -- Opcional. false/nil cria apenas a zona; true usa os valores abaixo.
        prop = {
            enabled = true,
            model = 'prop_tool_box_04',
            offset = vec3(0.0, 0.0, 0.0)
        },

        recipes = {
            {
                id = 'lockpick',
                item = 'lockpick',
                label = 'Lockpick',
                description = 'Ferramenta de abertura improvisada',
                count = 2,
                duration = 5000,
                ingredients = {
                    scrapmetal = 5
                }
            },
            {
                -- Prototipo comunitario: os encaixes formam uma pistola.
                id = 'pistol_shape_test',
                item = 'WEAPON_PISTOL',
                label = 'Pistola 9mm',
                description = 'Prototipo comunitario de montagem por formato',
                count = 1,
                duration = 12000,
                ingredients = {
                    pistol_slide = 1,
                    pistol_barrel = 1,
                    pistol_grip = 1,
                    pistol_trigger = 1,
                    pistol_magazine = 1
                },
                -- A grade e apenas visual; quantidades continuam validadas
                -- pelo servidor a partir de ingredients.
                layout = {
                    -- Modelo do preview: cinco colunas, tres linhas e cada
                    -- componente ocupando um encaixe independente.
                    columns = 5,
                    rows = 3,
                    slots = {
                        pistol_grip     = { column = 1, row = 2 },
                        pistol_trigger  = { column = 2, row = 2 },
                        pistol_barrel   = { column = 3, row = 2 },
                        pistol_slide    = { column = 4, row = 2 },
                        pistol_magazine = { column = 3, row = 3 }
                    }
                }
            }
        }
    },

    -- Exemplo de bancada privada. Troque o set pelas organizacoes existentes.
    -- {
    --     id = 'armas_nv2', label = 'NV2 Underground Workshop',
    --     subtitle = 'Projetos restritos da organizacao',
    --     coords = vec3(-345.374969, -130.687088, 39.009613), heading = 70.0,
    --     access = { set = 'nv2', minGrade = 1, permission = 'craft' },
    --     prop = { enabled = false },
    --     recipes = {
    --         { id = 'lockpick', item = 'lockpick', label = 'Lockpick', count = 1,
    --           duration = 5000, ingredients = { scrapmetal = 5 } }
    --     }
    -- }
}

-- Receitas usadas pelas bancadas posicionadas no nv_orgs. A chave pode ser
-- um subtipo (mecanica, restaurant, drugs), um estilo (job, gang, state) ou
-- `default`. O subtipo tem prioridade sobre o estilo.
Config.RecipesByType = {
    mecanica = {
        {
            id='lockpick', item='lockpick', label='Lockpick', count=2,
            description='Ferramenta de abertura improvisada', duration=5000,
            ingredients={scrapmetal=5},
            -- Durabilidade: desgaste em %. Sem durabilidade: consome 1 item.
            tools={toolbox=5}
        }
    },
    -- restaurant = { ... }, drugs = { ... }, weapons = { ... },
    -- job = { ... }, gang = { ... }, state = { ... },
    default = {}
}
