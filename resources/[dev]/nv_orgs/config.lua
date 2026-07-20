Config = {}

-- ============================================================================
-- ACESSO
-- ============================================================================

-- Comando que abre o painel.
Config.Command = 'orgs'

-- Quem e admin. Mesmo criterio ja usado pelo nv_adminmenu, para nao existirem
-- duas nocoes de "admin" no servidor.
Config.Admin = {
    -- Principal do ACE que libera o painel.
    ace = 'command',

    -- Grupos do ox_core que tambem liberam.
    groups = { 'admin', 'superadmin', 'god' }
}

-- ============================================================================
-- ESTILOS
--
-- Vira a coluna `type` de `ox_groups`, que o ox_core ja tem. `GetGroupsByType`
-- passa a funcionar de graca para outros resources ("me da todas as gangs").
-- ============================================================================
Config.Styles = {
    { value = 'state', label = 'Organizacao estatal' },
    { value = 'job',   label = 'Job' },
    { value = 'gang',  label = 'Gang' }
}

-- ============================================================================
-- SUBTIPOS
--
-- Refinam um estilo. So aparecem quando o estilo escolhido esta na chave
-- abaixo -- hoje so a organizacao estatal tem subtipos (policia, hospital,
-- mecanica), mas a estrutura serve para qualquer estilo.
--
-- O subtipo e guardado por organizacao e exposto a outros resources pelo
-- export `GetOrgSubtype(set)`, para o dispatch/hospital saberem "esta
-- organizacao e uma policia" sem depender do nome do set.
-- ============================================================================
Config.Subtypes = {
    state = {
        { value = 'police',   label = 'Policia' },
        { value = 'hospital', label = 'Hospital' },
        { value = 'dealership', label = 'Concessionaria' }
    },
    job = {
        { value = 'restaurant', label = 'Restaurante' },
        { value = 'mechanic', label = 'Mecanica' },
        { value = 'custom', label = 'Custom' }
    },
    gang = {
        { value = 'drugs', label = 'Drogas' },
        { value = 'weapons', label = 'Armas' }
    }
}

-- ============================================================================
-- ACOES POR CARGO
--
-- Viram permissoes do ox_core: `SetGroupPermission(set, grade, action, 'allow')`.
-- Qualquer resource checa com `player.hasPermission('group.<set>.<action>')`.
--
-- Como o ox_core nao persiste permissoes, elas sao guardadas em
-- `nv_org_grade_actions` e reaplicadas no boot.
-- ============================================================================
--
-- `styles` limita a acao a certos estilos. SEM o campo, a acao vale para
-- todos -- e assim que se declara uma acao comum. Com ele, so os estilos
-- listados a enxergam no formulario, e o servidor recusa a gravacao das
-- demais.
--
-- As acoes de bau sairam daqui de proposito. O acesso ao bau passou a ser
-- definido no proprio bau ("os N cargos do topo"), e manter uma permissao
-- paralela dizendo a mesma coisa criaria duas fontes de verdade -- daquelas
-- que discordam justamente no dia em que alguem precisa abrir o bau.
--
-- ATENCAO: marcar a acao CONCEDE a permissao no ox_core
-- (`group.<set>.<acao>`), mas nao faz nada acontecer sozinho. Quem consome e
-- o resource que checa `player.hasPermission(...)`. As acoes abaixo alem de
-- `hire` e `contacts` ainda nao tem consumidor neste servidor -- estao aqui
-- para os proximos passos, e nao porque ja funcionam.
Config.Actions = {
    -- ------------------------------------------------------- comuns --
    { value = 'hire',      label = 'Contratar e demitir' },
    { value = 'contacts',  label = 'Acesso a contatos' },
    { value = 'bank',      label = 'Movimentar conta da organizacao' },

    -- ----------------------------------------- estatais e empregos --
    { value = 'vehicles',  label = 'Retirar veiculos da frota', styles = { 'state', 'job' } },
    { value = 'wardrobe',  label = 'Usar o vestiario',          styles = { 'state', 'job' } },
    { value = 'invoices',  label = 'Emitir cobrancas',          styles = { 'state', 'job' } },

    -- ------------------------------------------- so estatais --
    { value = 'duty',      label = 'Bater ponto (em servico)',  styles = { 'state' } },
    { value = 'dealership', label = 'Gerenciar concessionaria', styles = { 'state' } },

    -- ------------------------------------------------ so gangs --
    { value = 'territory', label = 'Gerenciar territorio',      styles = { 'gang' } },
    { value = 'contacts',         label = 'Acesso a contatos' },
    { value = 'hire',             label = 'Contratar' }
}

-- ============================================================================
-- CARGOS
-- ============================================================================
Config.Grades = {
    -- Limite de cargos por organizacao.
    max = 12,

    --[[
        PAPEL BANCARIO AUTOMATICO

        O ox_core amarra o acesso ao caixa da empresa ao `accountRole` do cargo
        (tabela `account_roles`: viewer, contributor, manager, owner). Em vez de
        pedir isso no formulario, deduzimos da posicao -- que e a informacao que
        o admin ja esta dando:

          posicao 1 (o mais alto) -> owner
          posicao 2               -> manager
          demais                  -> contributor

        Mude aqui se a sua estrutura for outra.
    ]]
    accountRoles = {
        [1] = 'owner',
        [2] = 'manager',
        default = 'contributor'
    }
}

-- ============================================================================
-- ORGANIZACAO
-- ============================================================================
Config.Org = {
    -- O `set` e a chave primaria em `ox_groups` e vira o principal do ACE.
    -- Nao pode mudar depois de criado: `character_groups`, `ox_doorlock` e as
    -- opcoes de target guardam esse nome.
    setPattern = '^[a-z][a-z0-9_]*$',
    setMinLength = 3,
    setMaxLength = 20,  -- limite da coluna `ox_groups`.`name`

    labelMaxLength = 50, -- limite da coluna `ox_groups`.`label`

    -- Toda organizacao nasce com conta de sociedade (caixa da empresa).
    hasAccount = true,

    -- Cor do grupo (usada pelo ox_core em blips/UI). nil = sem cor.
    colour = nil
}

-- Icones disponibilizados no seletor de blip. Os nomes ficam em PT-BR no
-- painel; o id e o sprite nativo do GTA/FiveM.
Config.DealershipBlips = {
    { value = 225, label = 'Veiculo' },
    { value = 326, label = 'Concessionaria' },
    { value = 357, label = 'Garagem' },
    { value = 523, label = 'Garagem de veiculos' },
    { value = 1, label = 'Local padrao' },
    { value = 280, label = 'Estrela' },
    { value = 431, label = 'Oficina' },
    { value = 446, label = 'Reparos automotivos' },
    { value = 50, label = 'Loja' },
    { value = 52, label = 'Loja de conveniencia' },
    { value = 59, label = 'Armas' },
    { value = 60, label = 'Policia' },
    { value = 61, label = 'Hospital' },
    { value = 71, label = 'Barbearia' },
    { value = 73, label = 'Loja de roupas' },
    { value = 76, label = 'Helicoptero' },
    { value = 80, label = 'Heliporto' },
    { value = 85, label = 'Bar' },
    { value = 93, label = 'Boate' },
    { value = 106, label = 'Taxi' },
    { value = 108, label = 'Banco' },
    { value = 110, label = 'Casa' },
    { value = 121, label = 'Ponto de observacao' },
    { value = 135, label = 'Cinema' },
    { value = 136, label = 'Barco' },
    { value = 162, label = 'Informacao' },
    { value = 164, label = 'Objetivo' },
    { value = 171, label = 'Ponto de interesse' },
    { value = 205, label = 'Caminhao' },
    { value = 226, label = 'Moto' },
    { value = 227, label = 'Bicicleta' },
    { value = 237, label = 'Combustivel' },
    { value = 269, label = 'Deposito' },
    { value = 318, label = 'Elevador' },
    { value = 354, label = 'Chave' },
    { value = 361, label = 'Posto de combustivel' },
    { value = 374, label = 'Lavagem de veiculos' },
    { value = 408, label = 'Corrida' },
    { value = 478, label = 'Caminhao de carga' },
    { value = 525, label = 'Armazem' }
}

-- ============================================================================
-- BAUS
--
-- Quantos quiser, criados um a um. Cada bau define QUANTOS CARGOS DO TOPO o
-- abrem (1 = so o chefe), e um deles pode ser marcado como o da gerencia.
--
-- Guardamos a posicao, nao o grade: o grade depende de quantos cargos existem,
-- e gravar ele faria "os 2 do topo" virar "os 3 do topo" no dia em que alguem
-- adicionasse um cargo.
-- ============================================================================
Config.Stash = {
    defaultSlots  = 50,
    defaultWeight = 100000,  -- em gramas (100 kg)

    maxSlots  = 500,
    maxWeight = 2000000,     -- 2 t

    -- Tamanho da zona de target do bau, em metros.
    zoneSize = 1.6,

    -- Distancia maxima para o target aparecer.
    targetDistance = 2.0
}

-- ============================================================================
-- CATALOGO DE VEICULOS (frota)
--
-- Ao montar a frota, o admin escolhe o modelo numa LISTA em vez de digitar o
-- spawn code na mao -- errar uma letra criava uma linha de frota que nunca
-- spawna.
--
-- A "concessionaria" (dealership) ainda nao existe como resource. Ate ela
-- existir, a lista sai do proprio catalogo do ox_core
-- (common/data/vehicles.json), que ja e a fonte de verdade dos modelos deste
-- servidor. Quando a dealership for criada, basta apontar `export` para ela e
-- a mesma tela passa a usar o estoque dela, sem mudar mais nada.
-- ============================================================================
Config.Dealership = {
    -- 'oxcore' = usa common/data/vehicles.json do ox_core.
    -- 'export' = chama o export abaixo (para a futura dealership).
    source = 'oxcore',

    -- So vale com source = 'export'. A funcao deve devolver uma lista de
    -- { model = string, label = string }.
    export = { resource = 'nv_dealership', method = 'GetCatalog' },

    -- Categorias do ox_core que entram na lista. Frota de organizacao e de
    -- chao: barco e aviao ficam de fora por padrao para nao poluir a busca.
    -- Deixe vazio ({}) para aceitar todas.
    categories = { land = true },

    -- Teto de itens no select. O ox_core tem centenas de modelos; um select
    -- gigante fica lento. Acima disto o admin refina pela busca do proprio
    -- campo (o select do ox_lib e pesquisavel).
    limit = 600
}

-- ============================================================================
-- CHAVE
--
-- Item fisico que tranca/destranca as portas da organizacao. A regra pedida e
-- a que o ox_doorlock NAO faz sozinho: a chave so funciona para quem TAMBEM e
-- membro. O ox_doorlock trata grupo e item como alternativas (um OU outro);
-- aqui a exigencia e grupo E item, entao a chave passa por uma verificacao
-- propria no servidor em vez de ir para o campo `items` da porta.
-- ============================================================================
Config.Keys = {
    item = 'org_key',

    -- Alcance (m) para a chave alcancar uma porta.
    distance = 2.5
}

-- ============================================================================
-- CONTATO
--
-- Um numero de telefone da organizacao, impresso num pedaco de papel. So UM
-- fica ativo por vez: gerar um novo aposenta o anterior, que continua na lista
-- como historico -- util para saber que um papel velho circulando por ai ja
-- nao vale mais.
--
-- Os numeros tem 10 digitos para casar com o formato do npwd
-- (`general.phoneNumberFormat` = `(\d{3})(\d{3})(\d{4})`). Isso NAO integra o
-- telefone sozinho: o npwd nao expoe API Lua nenhuma. E so o cuidado de nao
-- gerar um numero que uma integracao futura nao conseguiria usar.
-- ============================================================================
Config.Contact = {
    item = 'org_contact',

    -- Quantidade de digitos. 10 = formato do npwd.
    digits = 10,

    -- Tentativas de gerar um numero livre antes de desistir. Colisao e rara,
    -- mas o banco tem indice unico e a falha precisa ser tratada.
    maxAttempts = 20
}

-- ============================================================================
-- MODO DE POSICIONAMENTO
--
-- Usado para criar fechaduras e baus andando pelo mapa, ja que porta exige
-- modelo e heading exatos -- nao da para digitar isso num formulario.
-- ============================================================================
Config.Placement = {
    -- Alcance do raycast que mira a porta, em metros.
    doorRange = 6.0,

    -- Passo das setas ao ajustar a altura do ponto.
    nudgeStep = 0.05,

    -- Alcance do raycast que posiciona baus e vestiarios olhando para o chao.
    aimRange = 12.0,

    -- Distancia maxima entre as duas folhas da mesma fechadura. Uma segunda
    -- porta acima deste limite e recusada para evitar pares incorretos.
    --
    -- 2.2 m cobre porta dupla de delegacia e de garagem sem juntar por engano
    -- duas portas de quartos vizinhos, que costumam ficar bem mais longe.
    doubleDistance = 2.2,

    -- Cor solida do editor de pontos.
    marker = {
        type  = 28,
        scale = vec3(0.9, 0.9, 0.9),
        color = { r = 42, g = 142, b = 255, a = 255 }
    }
}

-- ============================================================================
-- BUSCA DE PERSONAGENS (contratar)
-- ============================================================================
Config.Search = {
    -- Minimo de caracteres antes de consultar o banco.
    minLength = 2,

    -- Teto de resultados por busca.
    limit = 15
}
