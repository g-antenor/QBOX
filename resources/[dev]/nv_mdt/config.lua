Config = {}

-- ============================================================================
-- ACESSO
--
-- Quem abre o MDT nao e definido por uma lista de grupos aqui: e definido pelo
-- SUBTIPO da organizacao no nv_orgs (police / hospital / mecanica). Assim,
-- criar uma segunda corporacao de policia no painel de organizacoes ja da
-- acesso ao MDT dela, sem editar config nenhum.
-- ============================================================================
Config.Command = 'mdt'

-- Tecla sugerida (nil desativa o keybind; o comando continua valendo).
Config.Keybind = nil

-- Subtipo do nv_orgs -> departamento do MDT.
Config.Departments = {
    police   = { id = 'policia',  label = 'Policia',  icon = 'shield' },
    hospital = { id = 'hospital', label = 'Hospital', icon = 'cross' },
    mecanica = { id = 'mecanica', label = 'Oficina',  icon = 'wrench' }
}

-- ============================================================================
-- LICENCAS
-- Reaproveitam as do ox_core (`ox_licenses`), em vez de tabela propria: assim
-- a CNH que o MDT le e a mesma que qualquer outro resource ja usa.
-- ============================================================================
Config.Licenses = {
    driver = 'driver',
    weapon = 'weapon'
}

-- ============================================================================
-- POLICIA
-- ============================================================================
Config.Police = {
    -- Tipos de multa. `value` em dinheiro do servidor.
    fines = {
        { key = '01', label = 'Excesso de velocidade',        value = 250 },
        { key = '02', label = 'Estacionamento irregular',     value = 80 },
        { key = '03', label = 'Uso de celular ao dirigir',    value = 150 },
        { key = '04', label = 'Nao uso de cinto de seguranca', value = 120 },
        { key = '05', label = 'Avanco de sinal vermelho',     value = 300 },
        { key = '06', label = 'Conduzir sem CNH',             value = 500 },
        { key = '07', label = 'Poluicao sonora',              value = 180 },
        { key = '08', label = 'Direcao perigosa',             value = 400 }
    },

    --[[
        TIPOS PENAIS

        Era uma lista de strings soltas. Agora cada tipo carrega as multas que
        costumam vir com ele (`fines`, por `key` da lista acima), e a tela
        pre-seleciona essas multas quando o policial escolhe o tipo.

        Isso resolve um problema real de mesa: o policial que registra "Direcao
        perigosa" as vezes esquece de cobrar a multa correspondente, e a
        cobranca vira uma decisao individual em vez de uma regra. Continuam
        sendo sugestoes -- da para desmarcar e da para somar outras.

        A MESMA lista alimenta "Registrar prisao" e "Motivo da procura": um
        procurado por homicidio e o mesmo tipo penal que uma prisao por
        homicidio, e manter duas listas garantiria que elas divergissem.
    ]]
    arrestTypes = {
        { key = 'roubo',      label = 'Roubo',                 fines = {} },
        { key = 'furto',      label = 'Furto',                 fines = {} },
        { key = 'porte',      label = 'Porte ilegal de arma',  fines = {} },
        { key = 'trafico',    label = 'Trafico de drogas',     fines = {} },
        { key = 'homicidio',  label = 'Homicidio',             fines = {} },
        { key = 'resistencia',label = 'Resistencia a prisao',  fines = {} },
        { key = 'agressao',   label = 'Agressao',              fines = {} },
        { key = 'desacato',   label = 'Desacato a autoridade', fines = {} },
        { key = 'receptacao', label = 'Receptacao',            fines = {} },
        { key = 'sequestro',  label = 'Sequestro',             fines = {} },
        { key = 'transito',   label = 'Crime de transito',     fines = { '01', '05', '08' } },
        { key = 'fuga',       label = 'Fuga em veiculo',       fines = { '01', '08' } }
    },

    -- Reducoes de pena oferecidas no registro de prisao (%).
    reductions = { 0, 10, 15, 25, 50 },

    -- Tipos de ocorrencia.
    reportTypes = {
        { value = 'furto',    label = 'Furto' },
        { value = 'roubo',    label = 'Roubo' },
        { value = 'transito', label = 'Transito' },
        { value = 'agressao', label = 'Agressao' },
        { value = 'outro',    label = 'Outro' }
    },

    --[[
        PORTE DE ARMA

        Qualquer prisao registrada bloqueia o porte. A lista abaixo existe para
        o caso de voce querer que SO certos crimes bloqueiem: deixe vazia ({})
        para "qualquer prisao bloqueia", ou liste os motivos que bloqueiam.
    ]]
    gunBlockReasons = {},

    -- Documentos da corporacao (texto puro, exibido na aba Documentos).
    documents = {
        {
            id = 'codigo',
            label = 'Codigo',
            text = [[CODIGO PENAL DO DEPARTAMENTO

Art. 1 - Todo cidadao tem direito a um tratamento justo durante abordagens.
Art. 2 - O uso de forca letal so e autorizado em caso de risco iminente a vida.
Art. 3 - Toda prisao deve ser acompanhada de leitura de direitos e registro no MDT.
Art. 4 - Evidencias devem ser anexadas antes da conclusao do registro de prisao.]]
        },
        {
            id = 'modulacao',
            label = 'Modulacao',
            text = [[MODULACAO DE RADIO

Canal 1 - Comando Geral
Canal 2 - Patrulhamento Zona Sul
Canal 3 - Patrulhamento Zona Norte
Canal 4 - Operacoes Taticas
Canal 5 - Transito]]
        },
        {
            id = 'procedimento',
            label = 'Procedimento',
            text = [[PROCEDIMENTO OPERACIONAL PADRAO

1. Identifique-se antes de qualquer abordagem.
2. Solicite documentos do cidadao.
3. Em caso de infracao, registre a multa correspondente no MDT.
4. Em caso de prisao, selecione os motivos e descreva a ocorrencia.
5. Atualize a lista de procurados quando aplicavel.]]
        }
    }
}

-- ============================================================================
-- HOSPITAL
-- ============================================================================
Config.Hospital = {
    -- Motivos de atendimento.
    reasons = {
        { key = 'r1', label = 'Ferimento por arma de fogo' },
        { key = 'r2', label = 'Fratura' },
        { key = 'r3', label = 'Corte profundo' },
        { key = 'r4', label = 'Queimadura' },
        { key = 'r5', label = 'Intoxicacao' },
        { key = 'r6', label = 'Overdose' },
        { key = 'r7', label = 'Atropelamento' },
        { key = 'r8', label = 'Parada cardiaca' }
    },

    -- Recursos/medicamentos cobrados.
    resources = {
        { key = 'm1', label = 'Bandagem',          value = 50 },
        { key = 'm2', label = 'Soro Fisiologico',  value = 80 },
        { key = 'm3', label = 'Analgesico',        value = 60 },
        { key = 'm4', label = 'Antibiotico',       value = 120 },
        { key = 'm5', label = 'Kit de Sutura',     value = 150 },
        { key = 'm6', label = 'Adrenalina',        value = 200 },
        { key = 'm7', label = 'Oxigenio',          value = 90 }
    },

    -- Regioes do corpo do diagrama. `key` vai para o banco.
    bodyZones = {
        { key = 'head',  label = 'Cabeca' },
        { key = 'torso', label = 'Tronco' },
        { key = 'armL',  label = 'Braco E' },
        { key = 'armR',  label = 'Braco D' },
        { key = 'legL',  label = 'Perna E' },
        { key = 'legR',  label = 'Perna D' }
    },

    -- Precos.
    pricePerInjury = 100,  -- por ponto de gravidade (0 a 3)
    pricePerHour   = 10,
    rescueFee      = 500,
    maxSeverity    = 3
}

-- ============================================================================
-- MECANICA
-- ============================================================================
Config.Mechanic = {
    -- Pecas do diagrama e o preco de cada uma.
    parts = {
        { key = 'bumperF', label = 'Para-choque Dianteiro', value = 120 },
        { key = 'hood',    label = 'Capo',                  value = 180 },
        { key = 'engine',  label = 'Motor',                 value = 450 },
        { key = 'doorFL',  label = 'Porta Dianteira Esquerda', value = 160 },
        { key = 'roof',    label = 'Teto',                  value = 300 },
        { key = 'doorFR',  label = 'Porta Dianteira Direita', value = 160 },
        { key = 'doorRL',  label = 'Porta Traseira Esquerda', value = 150 },
        { key = 'doorRR',  label = 'Porta Traseira Direita',  value = 150 },
        { key = 'trunk',   label = 'Porta-malas',           value = 140 },
        { key = 'bumperR', label = 'Para-choque Traseiro',  value = 120 }
    },

    towFee = 150
}

-- ============================================================================
-- CHAMADOS
--
-- O MDT nao gera chamados sozinho -- ele os EXIBE. Outros resources alimentam
-- pelo export `AddCall(dept, data)`; o hospital tambem registra na propria
-- tela. Sem um dispatch instalado, a lista fica vazia, e isso e honesto: e
-- melhor do que inventar ocorrencias que nao existem.
-- ============================================================================
Config.Calls = {
    -- Quantos aparecem no dashboard.
    dashboardLimit = 6,

    -- Quantos ficam guardados por departamento (os mais antigos caem fora).
    keep = 60
}

-- ============================================================================
-- FATURAS PENDENTES
--
-- Multas e custos de prisao nao saem do bolso na hora: viram divida. O cidadao
-- pode nao ter o dinheiro durante a abordagem, e uma multa que so existe se
-- houver saldo nao e uma multa -- e um pedagio para quem por acaso estava com
-- dinheiro.
-- ============================================================================
Config.Invoices = {
    -- Juros por dia de atraso, sobre o valor ORIGINAL (juros simples).
    dailyRate = 0.10,

    -- Teto de dias cobrados. Depois disso a divida congela: juros que crescem
    -- para sempre produzem um numero impagavel, e uma divida impagavel deixa de
    -- ser consequencia e vira personagem abandonado.
    maxDays = 3,

    -- Conta usada na cobranca forcada. `money` = dinheiro em maos.
    account = 'money',

    -- A cobranca forcada pode deixar a conta NEGATIVA.
    --
    -- E o ponto do recurso: sem isto, nao ter saldo seria uma forma de nunca
    -- pagar, e bastaria andar quebrado para ser imune a multa.
    allowNegative = true
}

-- Periodos do filtro de ocorrencias (dias). `nil` = sem limite.
Config.ReportPeriods = {
    { key = '1',   label = 'Hoje',           days = 1 },
    { key = '7',   label = 'Ultimos 7 dias', days = 7 },
    { key = '30',  label = 'Ultimos 30 dias', days = 30 },
    { key = 'all', label = 'Tudo',           days = nil }
}

-- Itens por pagina nas listas.
Config.PageSize = 6
