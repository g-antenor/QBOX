/* ==========================================================================
   nv_garage — NUI

   O painel nao decide nada: ele desenha o que o cliente manda e devolve
   cliques. Toda validacao (dono, distancia, garagem certa) mora no servidor.
   ========================================================================== */

const resource = (typeof GetParentResourceName === 'function')
    ? GetParentResourceName()
    : 'nv_garage';

const el = {
    root: document.getElementById('root'),
    garageLabel: document.getElementById('garageLabel'),
    list: document.getElementById('list'),
    empty: document.getElementById('empty'),
    detail: document.getElementById('detail'),
    metrics: document.getElementById('detailMetrics'),
    infoLocal: document.getElementById('infoLocal'),
    infoModelo: document.getElementById('infoModelo'),
    infoPlaca: document.getElementById('infoPlaca'),
    infoSituacao: document.getElementById('infoSituacao'),
    rowTaxa: document.getElementById('rowTaxa'),
    infoTaxa: document.getElementById('infoTaxa'),
    action: document.getElementById('actionButton'),
    notice: document.getElementById('notice'),
    closeList: document.getElementById('closeList'),
    closeDetail: document.getElementById('closeDetail')
};

const state = {
    list: [],
    bars: { good: 70, warn: 35 },
    selected: null,
    sending: false,
    impound: false,
    strict: false,
    fee: 0
};

const METRICS = [
    { key: 'fuel', icon: 'ic-combustivel', label: 'Combustivel' },
    { key: 'engine', icon: 'ic-motor', label: 'Motor' },
    { key: 'body', icon: 'ic-lataria', label: 'Lataria' },
    { key: 'tyres', icon: 'ic-lataria', label: 'Pneus' }
];

const STATUS_LABEL = {
    stored: 'Guardado',
    out: 'Fora da garagem',
    impound: 'Apreendido'
};

// ------------------------------------------------------------- utilidades --

/** Faixa de cor de um valor 0-100. */
function band(value) {
    if (value >= state.bars.good) return 'good';
    if (value >= state.bars.warn) return 'warn';
    return 'bad';
}

function clamp(value) {
    const number = Number(value);

    if (!Number.isFinite(number)) return 0;

    return Math.max(0, Math.min(100, Math.round(number)));
}

async function post(endpoint, payload) {
    try {
        const response = await fetch(`https://${resource}/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(payload || {})
        });

        return await response.json();
    } catch (err) {
        return null;
    }
}

/** Cria um elemento com classe e texto, para nao repetir o mesmo bloco. */
function make(tag, className, text) {
    const node = document.createElement(tag);

    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;

    return node;
}

function icon(id, className) {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    const use = document.createElementNS('http://www.w3.org/2000/svg', 'use');

    if (className) svg.setAttribute('class', className);
    use.setAttribute('href', `#${id}`);
    svg.appendChild(use);

    return svg;
}

/** Barra de progresso colorida pela faixa. */
function bar(value) {
    const wrap = make('div', 'bar');
    const fill = make('div', `bar-fill ${band(value)}`);

    fill.style.width = `${value}%`;
    wrap.appendChild(fill);

    return wrap;
}

// ------------------------------------------------------------------ lista --

function buildCard(vehicle) {
    const card = make('div', 'vehicle');

    card.dataset.vin = vehicle.vin;

    const top = make('div', 'vehicle-top');
    const title = make('div', 'vehicle-title');

    title.appendChild(make('div', 'vehicle-name', vehicle.name));
    title.appendChild(make('div', 'vehicle-sub', `${vehicle.plate} • ${vehicle.class}`));
    top.appendChild(title);

    /* Um carro guardado em OUTRA garagem parecia idêntico a um guardado aqui:
       mesma etiqueta ausente, mesmo botão "Retirar". A etiqueta nomeia a
       garagem de verdade — é a única forma de o cartão dizer a verdade sem
       abrir o detalhe. */
    if (vehicle.status !== 'stored') {
        top.appendChild(make('span', `tag ${vehicle.status}`, vehicle.status === 'out' ? 'Fora' : 'Patio'));
    } else if (!vehicle.here) {
        top.appendChild(make('span', 'tag elsewhere', vehicle.garageLabel || 'Outra garagem'));
    }

    card.appendChild(top);

    const row = make('div', 'metrics-row');

    METRICS.forEach(({ key, icon: iconId, label }) => {
        const cell = make('div');
        const head = make('div', 'metric-label');

        head.appendChild(icon(iconId));
        head.appendChild(make('span', null, label));
        cell.appendChild(head);
        cell.appendChild(bar(clamp(vehicle[key])));

        row.appendChild(cell);
    });

    card.appendChild(row);
    card.addEventListener('click', () => select(vehicle.vin));

    return card;
}

function renderList() {
    el.list.replaceChildren();

    if (!state.list.length) {
        el.empty.classList.remove('hidden');
        return;
    }

    el.empty.classList.add('hidden');
    state.list.forEach((vehicle) => el.list.appendChild(buildCard(vehicle)));
}

function markSelection() {
    el.list.querySelectorAll('.vehicle').forEach((card) => {
        card.classList.toggle('selected', card.dataset.vin === state.selected);
    });
}

// --------------------------------------------------------------- detalhes --

function buildMetric(vehicle, { key, icon: iconId, label }) {
    const block = make('div', 'metric-big');
    const head = make('div', 'metric-head');
    const value = clamp(vehicle[key]);

    head.appendChild(icon(iconId));
    head.appendChild(make('span', 'name', label));

    const number = make('span', 'value', `${value}%`);

    number.style.color = `var(--${band(value)})`;
    head.appendChild(number);

    block.appendChild(head);
    block.appendChild(bar(value));

    return block;
}

function renderDetail() {
    const vehicle = state.list.find((item) => item.vin === state.selected);

    if (!vehicle) {
        el.detail.classList.add('hidden');
        return;
    }

    el.detail.classList.remove('hidden');

    el.metrics.replaceChildren();
    METRICS.forEach((metric) => el.metrics.appendChild(buildMetric(vehicle, metric)));

    /* `garageLabel` vem do servidor e é o nome da garagem onde o carro está.
       Antes isto lia o título do painel aberto, o que fazia todo carro guardado
       alegar estar exatamente onde o jogador estava. */
    el.infoLocal.textContent = vehicle.status === 'stored'
        ? (vehicle.garageLabel || 'Garagem')
        : STATUS_LABEL[vehicle.status];

    el.infoModelo.textContent = vehicle.model;
    el.infoPlaca.textContent = vehicle.plate;

    el.infoSituacao.textContent = vehicle.status === 'stored' && !vehicle.here
        ? 'Guardado em outra garagem'
        : (STATUS_LABEL[vehicle.status] || '-');

    /* Só o valor da retirada: a composição (base + diária + conserto) fica
       fora de propósito, o que interessa é quanto sai do bolso. */
    const fee = Number(vehicle.fee) || 0;
    const showFee = state.impound && vehicle.status === 'impound';

    el.rowTaxa.classList.toggle('hidden', !showFee);

    if (showFee) {
        el.infoTaxa.textContent = `$${fee.toLocaleString('pt-BR')}`;
    }

    renderAction(vehicle);
}

function renderAction(vehicle) {
    el.notice.classList.add('hidden');
    el.action.classList.remove('hidden');
    el.action.disabled = state.sending;

    if (state.organization && vehicle.authorized !== true) {
        el.action.classList.add('hidden');
        el.notice.textContent = 'Seu cargo nao possui autorizacao para movimentar a frota.';
        el.notice.classList.remove('hidden');
        return;
    }

    if (state.organization && vehicle.status === 'impound') {
        const fee = Number(vehicle.fee) || 0;
        el.action.textContent = fee > 0
            ? `Liberar veiculo — $${fee.toLocaleString('pt-BR')}`
            : 'Liberar veiculo';
        el.action.onclick = () => submit('takeOut', { id: vehicle.id });
        el.notice.textContent = 'A taxa sera descontada do caixa da organizacao.';
        el.notice.classList.remove('hidden');
        return;
    }

    if (state.organization && vehicle.status === 'out') {
        el.action.classList.add('hidden');
        el.notice.textContent = 'Estacione o veiculo em uma vaga da organizacao para guarda-lo.';
        el.notice.classList.remove('hidden');
        return;
    }

    // No patio a unica acao possivel e liberar, e ela custa dinheiro -- o
    // valor vai no proprio botao, para ninguem pagar sem ver o preco.
    // A taxa vem POR VEICULO: depende dos dias parados e de ter chegado
    // destruido.
    if (state.impound) {
        const fee = Number(vehicle.fee) || 0;

        el.action.textContent = fee > 0
            ? `Liberar veiculo — $${fee.toLocaleString('pt-BR')}`
            : 'Liberar veiculo';

        el.action.onclick = () => submit('takeOut', { id: vehicle.id });

        el.notice.textContent = 'Pagamento em dinheiro, em maos.';
        el.notice.classList.remove('hidden');
        return;
    }

    if (vehicle.status === 'impound') {
        el.action.classList.add('hidden');
        el.notice.textContent = 'Este veiculo esta no patio de apreensao.';
        el.notice.classList.remove('hidden');
        return;
    }

    if (vehicle.status === 'out') {
        el.action.textContent = 'Guardar veiculo';
        el.action.onclick = () => submit('store', { plate: vehicle.plate });
        return;
    }

    /* Com `strictReturn` ligado, o servidor recusa retirar um carro guardado em
       outra garagem. O botão sumia? Não — ele aparecia, era clicado e falhava.
       Aqui ele diz onde ir buscar. */
    if (state.strict && !vehicle.here) {
        el.action.classList.add('hidden');
        el.notice.textContent = `Este veiculo esta em ${vehicle.garageLabel || 'outra garagem'}.`;
        el.notice.classList.remove('hidden');
        return;
    }

    el.action.textContent = vehicle.here === false
        ? `Trazer de ${vehicle.garageLabel || 'outra garagem'}`
        : 'Retirar veiculo';
    el.action.onclick = () => submit('takeOut', { id: vehicle.id });
}

function select(vin) {
    state.selected = vin;
    markSelection();
    renderDetail();
}

// ----------------------------------------------------------------- acoes --

async function submit(endpoint, payload) {
    if (state.sending) return;

    state.sending = true;
    el.action.disabled = true;

    await post(endpoint, payload);

    // Sucesso fecha o menu pelo lado do cliente; falha volta o botao ao normal
    // com a notificacao ja na tela.
    state.sending = false;
    el.action.disabled = false;
}

function close() {
    if (el.root.classList.contains('hidden')) return;

    el.root.classList.add('hidden');
    post('close');
}

function open(data) {
    state.list = Array.isArray(data.list) ? data.list : [];
    state.bars = data.bars || state.bars;
    state.selected = null;
    state.sending = false;

    /* Sem esta linha `state.impound` ficava undefined e o painel caia no ramo
       que esconde o botao: no patio dava para ver o carro mas nao para
       libera-lo. */
    state.impound = data.impound === true;
    state.strict = data.strict === true;
    state.organization = data.organization === true;

    el.garageLabel.textContent = data.label || '-';
    el.detail.classList.add('hidden');
    el.root.classList.remove('hidden');

    renderList();

    // Abre ja com o primeiro selecionado: um painel vazio ao lado da lista
    // parece um bug, nao uma escolha.
    if (state.list.length) select(state.list[0].vin);
}

// ---------------------------------------------------------------- eventos --

// ==========================================================================
// CONTROLE DO VEICULO
//
// Painel separado da garagem: trancas e portas, aberto pela tecla de tranca.
// O cliente manda o retrato do veiculo, a NUI so devolve cliques -- quem
// decide se a porta abre ou se a tranca cede continua sendo o jogo/servidor.
// ==========================================================================

const ctl = {
    root: document.getElementById('control'),
    name: document.getElementById('ctlName'),
    sub: document.getElementById('ctlSub'),
    close: document.getElementById('ctlClose'),
    lock: document.getElementById('ctlLock'),
    lockIcon: document.getElementById('ctlLockIcon'),
    lockState: document.getElementById('ctlLockState'),
    lockHint: document.getElementById('ctlLockHint'),
    doors: document.getElementById('ctlDoors'),
    empty: document.getElementById('ctlEmpty')
};

// Capo e porta-malas ganham icone proprio: sao os dois que o jogador procura
// com mais frequencia, e "Porta 4" nao diz nada.
const DOOR_ICON = { 4: 'ic-capo', 5: 'ic-mala' };

const controlState = { open: false, doors: [], locked: false, canLock: true };

function renderLock() {
    const locked = controlState.locked;

    ctl.lock.classList.toggle('locked', locked);
    ctl.lock.classList.toggle('unlocked', !locked);
    ctl.lock.disabled = !controlState.canLock;

    ctl.lockIcon.firstElementChild.setAttribute(
        'href', locked ? '#ic-tranca' : '#ic-tranca-aberta'
    );

    ctl.lockState.textContent = locked ? 'Trancado' : 'Destrancado';
    ctl.lockHint.textContent = controlState.canLock
        ? (locked ? 'Clique para destrancar' : 'Clique para trancar')
        : 'Voce nao tem a chave deste veiculo';
}

function renderDoors() {
    ctl.doors.replaceChildren();

    if (!controlState.doors.length) {
        ctl.empty.classList.remove('hidden');
        return;
    }

    ctl.empty.classList.add('hidden');

    controlState.doors.forEach((door) => {
        const button = make('button', `door${door.open ? ' open' : ''}`);

        button.type = 'button';

        // Capo/porta-malas na linha inteira; portas de verdade em duas colunas.
        if (door.index >= 4) button.classList.add('wide');

        button.appendChild(icon(DOOR_ICON[door.index] || 'ic-porta'));

        const text = make('div', 'door-text');

        text.appendChild(make('div', 'door-name', door.label));
        text.appendChild(make('div', 'door-state', door.open ? 'Aberta' : 'Fechada'));
        button.appendChild(text);

        button.addEventListener('click', () => {
            // Reflete na hora e confirma no proximo update: esperar o round-trip
            // deixava o botao com cara de travado.
            door.open = !door.open;
            renderDoors();
            post('control:door', { index: door.index });
        });

        ctl.doors.appendChild(button);
    });
}

function renderControl(data) {
    controlState.doors = Array.isArray(data.doors) ? data.doors : [];
    controlState.locked = data.locked === true;
    controlState.canLock = data.canLock !== false;

    ctl.name.textContent = data.name || 'Controle do Veiculo';
    ctl.sub.textContent = data.plate || '-';

    renderLock();
    renderDoors();
}

function openControl(data) {
    controlState.open = true;
    ctl.root.classList.remove('hidden');
    renderControl(data);
}

function closeControl() {
    if (!controlState.open) return;

    controlState.open = false;
    ctl.root.classList.add('hidden');
    post('control:close');
}

ctl.close.addEventListener('click', closeControl);
ctl.lock.addEventListener('click', () => post('control:lock'));

// ---------------------------------------------------------------- eventos --

window.addEventListener('message', (event) => {
    const data = event.data;

    if (!data || typeof data.action !== 'string') return;

    if (data.action === 'open') return open(data);
    if (data.action === 'close') return el.root.classList.add('hidden');

    if (data.action === 'control:open') return openControl(data);
    if (data.action === 'control:update') {
        // Chega de fora (porta aberta por outro jogador, tranca mudada pelo
        // servidor). So aplica com o painel aberto.
        if (controlState.open) renderControl(data);
        return;
    }
    if (data.action === 'control:close') {
        controlState.open = false;
        ctl.root.classList.add('hidden');
        return;
    }
});

window.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape') return;

    // Os dois nunca ficam abertos juntos, mas a ordem importa: o painel de
    // controle e o que estara na frente se acontecer.
    if (controlState.open) return closeControl();

    close();
});

el.closeList.addEventListener('click', close);
el.closeDetail.addEventListener('click', () => {
    state.selected = null;
    markSelection();
    el.detail.classList.add('hidden');
});
