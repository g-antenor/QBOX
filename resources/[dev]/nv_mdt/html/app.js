/* ==========================================================================
   nv_mdt — terminal

   A tela desenha o que o servidor manda e devolve cliques. Todo preço é
   recalculado no servidor: o que aparece aqui enquanto o operador monta uma
   consulta ou uma ordem de serviço é PRÉVIA, não a cobrança.
   ========================================================================== */

const resource = (typeof GetParentResourceName === 'function')
  ? GetParentResourceName()
  : 'nv_mdt';

const el = (id) => document.getElementById(id);

const dom = {
  root: el('root'),
  deptTabs: el('deptTabs'),
  deptSwitch: el('deptSwitch'),
  close: el('close'),
  sideTitle: el('sideTitle'),
  sideSub: el('sideSub'),
  nav: el('nav'),
  stage: el('stage')
};

const state = {
  tabs: [],
  cfg: {},
  dept: null,       // aba ativa (objeto de tabs)
  page: null,       // página ativa dentro do departamento
  ctx: {},          // estado por página (cidadão aberto, peças marcadas...)
  pages: {}         // paginação por lista
};

// ------------------------------------------------------------------ util --

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

/*
 * O `n` não é redundante. Um `null` no meio dos argumentos (remover alguém dos
 * procurados manda `charId, null`) vira um buraco quando o JSON é decodificado
 * em Lua, e `#args` para de contar ali — o argumento seguinte sumiria em
 * silêncio. Mandando o tamanho explícito, o `table.unpack` do lado Lua sabe
 * quantos argumentos existem de verdade.
 */

/** Consulta: devolve o retorno cru do callback do servidor. */
const call = (endpoint, ...args) => post('call', { endpoint, args, n: args.length });

/** Ação: o Lua mostra a notificação de erro/sucesso. */
const action = (endpoint, success, ...args) =>
  post('action', { endpoint, success, args, n: args.length });

function make(tag, className, text) {
  const node = document.createElement(tag);

  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;

  return node;
}

function actionMenu(buttons) {
  if (buttons.length === 1) return buttons[0];

  const wrap = make('div', 'action-menu');
  const toggle = make('button', 'icon-btn action-toggle', '⋯');
  const list = make('div', 'action-menu-list');

  toggle.title = 'Mais opções';
  toggle.setAttribute('aria-label', 'Mais opções');
  buttons.forEach((button) => {
    button.classList.remove('small');
    list.appendChild(button);
  });
  toggle.addEventListener('click', (event) => {
    event.stopPropagation();
    document.querySelectorAll('.action-menu.open').forEach((menu) => {
      if (menu !== wrap) menu.classList.remove('open');
    });
    wrap.classList.toggle('open');
  });
  list.addEventListener('click', () => wrap.classList.remove('open'));
  wrap.append(toggle, list);
  return wrap;
}

function money(value) {
  return '$' + Number(value || 0).toLocaleString('pt-BR');
}

/** Ícone inline. Sem emoji: eles variam de tamanho e fonte entre sistemas. */
function icon(path, size) {
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  const p = document.createElementNS('http://www.w3.org/2000/svg', 'path');

  svg.setAttribute('viewBox', '0 0 24 24');
  if (size) { svg.style.width = size + 'px'; svg.style.height = size + 'px'; }
  p.setAttribute('d', path);
  svg.appendChild(p);

  return svg;
}

const ICONS = {
  shield: 'M12 2 4 5v6c0 5 3.4 9.4 8 11 4.6-1.6 8-6 8-11V5l-8-3Z',
  cross: 'M10 2h4v6h6v4h-6v10h-4V12H4V8h6V2Z',
  wrench: 'M21 6a5 5 0 0 1-6.7 4.7l-7 7a2 2 0 1 1-2.8-2.9l7-7A5 5 0 0 1 18 3l-3 3 3 3 3-3Z',
  dashboard: 'M3 3h8v8H3V3Zm10 0h8v5h-8V3Zm0 7h8v11h-8V10ZM3 13h8v8H3v-8Z',
  report: 'M5 2h11l3 3v17H5V2Zm3 6h8v2H8V8Zm0 4h8v2H8v-2Zm0 4h5v2H8v-2Z',
  search: 'M10 3a7 7 0 1 0 4.4 12.4L20 21l1-1-5.6-5.6A7 7 0 0 0 10 3Zm0 2a5 5 0 1 1 0 10 5 5 0 0 1 0-10Z',
  wanted: 'M12 2 2 20h20L12 2Zm-1 6h2v6h-2V8Zm0 8h2v2h-2v-2Z',
  invoice: 'M5 2h14v20l-3-2-4 2-4-2-3 2V2Zm3 5h8v2H8V7Zm0 4h8v2H8v-2Zm0 4h5v2H8v-2Z',
  weapon: 'M3 10h11l3-3h4v5h-5l-2 2h-3l-1 6H6l1-6H3v-4Z',
  document: 'M6 2h9l4 4v16H6V2Zm8 2v4h4M9 12h6v2H9v-2Zm0 4h6v2H9v-2Z',
  map: 'M3 5 9 2l6 3 6-3v17l-6 3-6-3-6 3V5Zm6-1v13l6 3V7L9 4Z',
  team: 'M8 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm8-1a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM1 21v-2c0-3 3-5 7-5s7 2 7 5v2H1Zm14-7c4 0 8 2 8 5v2h-6v-2c0-2-1-3-2-5Z',
  call: 'M20 15v4a2 2 0 0 1-2 2C9 20 4 15 3 6a2 2 0 0 1 2-2h4l1 5-3 2c1 3 3 5 6 6l2-3 5 1Z',
  history: 'M12 3a9 9 0 1 1-8.5 6H1l3-4 4 4H5.5A7 7 0 1 0 12 5v5l4 3-1 2-5-4V3h2Z',
  camera: 'M3 6h4l2-3h6l2 3h4v15H3V6Zm9 3a4 4 0 1 0 0 8 4 4 0 0 0 0-8Z',
  user: 'M12 12a5 5 0 1 0 0-10 5 5 0 0 0 0 10Zm0 2c-5 0-9 2.5-9 5.5V22h18v-2.5C21 16.5 17 14 12 14Z',
  car: 'M5 11l1.5-4.5A2 2 0 0 1 8.4 5h7.2a2 2 0 0 1 1.9 1.5L19 11h1a1 1 0 0 1 1 1v5h-3v2h-3v-2H9v2H6v-2H3v-5a1 1 0 0 1 1-1h1Zm2.2-.5h9.6l-1-3H8.2l-1 3ZM6.5 15a1.2 1.2 0 1 0 0-2.4 1.2 1.2 0 0 0 0 2.4Zm11 0a1.2 1.2 0 1 0 0-2.4 1.2 1.2 0 0 0 0 2.4Z'
};

// ------------------------------------------------------------ paginação --

const PAGE_KEYS = {};

function paginate(items, key) {
  const size = state.cfg.pageSize || 6;
  const total = Math.max(1, Math.ceil(items.length / size));

  if (!PAGE_KEYS[key]) PAGE_KEYS[key] = 0;
  if (PAGE_KEYS[key] > total - 1) PAGE_KEYS[key] = total - 1;

  const start = PAGE_KEYS[key] * size;

  return { slice: items.slice(start, start + size), page: PAGE_KEYS[key], total };
}

function pager(container, key, info, redraw) {
  if (info.total <= 1) return;

  const bar = make('div', 'pager');
  const prev = make('button', 'btn small', '‹');
  const next = make('button', 'btn small', '›');

  prev.disabled = info.page === 0;
  next.disabled = info.page >= info.total - 1;
  prev.addEventListener('click', () => { PAGE_KEYS[key] -= 1; redraw(); });
  next.addEventListener('click', () => { PAGE_KEYS[key] += 1; redraw(); });

  bar.append(prev, make('span', 'pager-label', `${info.page + 1} / ${info.total}`), next);
  container.appendChild(bar);
}

// ------------------------------------------------------------ construtores --

function card(title, subtitle, iconPath) {
  const box = make('div', 'profile-card');
  const head = make('div', 'profile-header');
  const avatar = make('div', 'profile-avatar');

  avatar.appendChild(icon(iconPath || ICONS.user));

  const text = make('div');

  text.appendChild(make('div', 'profile-name', title));
  if (subtitle) text.appendChild(make('div', 'profile-sub', subtitle));

  head.append(avatar, text);
  box.appendChild(head);

  return box;
}

function grid(fields) {
  const box = make('div', 'profile-grid');

  fields.forEach(([label, value, badgeClass]) => {
    const f = make('div', 'profile-field');

    f.appendChild(make('span', 'k', label));

    if (badgeClass) f.appendChild(make('span', `badge ${badgeClass}`, value));
    else f.appendChild(make('span', 'v', value));

    box.appendChild(f);
  });

  return box;
}

function record(title, meta, desc, danger) {
  const item = make('div', `record-item${danger ? ' danger' : ''}`);
  const head = make('div', 'record-title');

  head.appendChild(make('span', null, title));
  item.appendChild(head);

  if (meta) item.appendChild(make('div', 'record-meta', meta));
  if (desc) item.appendChild(make('div', 'record-desc', desc));

  return { item, head };
}

function section(title) {
  const box = make('div', 'section-block');

  if (title) box.appendChild(make('div', 'section-block-title', title));

  return box;
}

function field(label, inputEl) {
  const box = make('div', 'field');

  box.appendChild(make('label', 'field-label', label));
  box.appendChild(inputEl);

  return box;
}

function input(placeholder, value) {
  const node = make('input', 'field-input');

  node.type = 'text';
  node.placeholder = placeholder || '';
  if (value) node.value = value;

  return node;
}

function textarea(placeholder) {
  const node = make('textarea', 'textarea');

  node.placeholder = placeholder || '';

  return node;
}

/** Lista de botões de seleção múltipla. Devolve o Set com o que está marcado. */
function pickList(container, options, selected, onChange) {
  const set = selected || new Set();

  options.forEach((opt) => {
    const key = opt.key !== undefined ? opt.key : opt;
    const label = opt.label !== undefined ? opt.label : opt;
    const button = make('button', 'pick', opt.value ? `${label} — ${money(opt.value)}` : label);

    button.classList.toggle('on', set.has(key));
    button.addEventListener('click', () => {
      if (set.has(key)) set.delete(key); else set.add(key);
      button.classList.toggle('on', set.has(key));
      if (onChange) onChange(set);
    });

    container.appendChild(button);
  });

  return set;
}

// ============================================================== POLÍCIA ===

const POLICE_NAV = [
  { id: 'dashboard', label: 'Dashboard' },
  { id: 'ocorrencias', label: 'Ocorrências' },
  { id: 'cidadao', label: 'Cidadão' },
  { id: 'procurados', label: 'Procurados' },
  { id: 'veiculos', label: 'Veículos' },
  { id: 'faturas', label: 'Faturas pendentes' },
  { id: 'armas', label: 'Porte de arma' },
  { id: 'documentos', label: 'Documentos' },
  { id: 'mapa', label: 'Live Map' },
  { id: 'cameras', label: 'Câmeras' },
  { id: 'comandos', label: 'Efetivo' }
];

/** Rótulo de um tipo de ocorrência, pela chave. */
function reportLabel(value) {
  const found = (state.cfg.police.reportTypes || []).find((t) => t.value === value);

  return found ? found.label : value;
}

/** Rótulo de um tipo penal, pela chave. */
function typeLabel(key) {
  const found = (state.cfg.police.arrestTypes || []).find((t) => t.key === key);

  return found ? found.label : key;
}

/**
 * Barra de abas interna. Devolve o container; o conteúdo é redesenhado pelo
 * `onPick`, e não escondido — manter seis painéis montados e alternar `hidden`
 * mantém seis listas vivas na memória e seis lugares para um estado velho
 * sobreviver a um refresh.
 */
function tabBar(items, active, onPick) {
  const bar = make('div', 'seg');

  items.forEach((item) => {
    const button = make('button', null, item.label);

    button.classList.toggle('active', item.id === active);
    button.addEventListener('click', () => onPick(item.id));
    bar.appendChild(button);
  });

  return bar;
}

/**
 * Seletor de cidadãos para a lista de envolvidos.
 *
 * A busca é a MESMA de `searchCitizen`, e é de propósito: o TODO pede que o
 * campo devolva "nome, tipo já existente e descrição", o que só é possível se o
 * envolvido for um cadastro de verdade e não um texto livre. Ainda assim aceita
 * nome solto — testemunha sem cadastro existe, e recusá-la deixaria a
 * ocorrência incompleta.
 */
function involvedPicker() {
  const box = section('Envolvidos');
  const chosen = [];
  const list = make('div', 'record-list');
  const row = make('div', 'row-inline');
  const search = field('Buscar cidadão', input('Nome, ID (#12) ou State ID...'));
  const addBtn = make('button', 'btn', 'Buscar');
  const results = make('div', 'record-list');
  const freeBtn = make('button', 'btn small', 'Adicionar sem cadastro');

  results.style.marginTop = '8px';

  const drawChosen = () => {
    list.replaceChildren();

    if (chosen.length === 0) {
      list.appendChild(make('div', 'empty-note', 'Nenhum envolvido adicionado.'));
      return;
    }

    chosen.forEach((person, index) => {
      const { item, head } = record(person.name,
        person.charId ? `#${person.charId}` : 'Sem cadastro');
      const remove = make('button', 'btn small', 'Remover');

      remove.addEventListener('click', () => {
        chosen.splice(index, 1);
        drawChosen();
      });

      head.appendChild(remove);
      list.appendChild(item);
    });
  };

  const add = (person) => {
    /* Duas linhas iguais numa ocorrência não somam informação: se o charId já
       está na lista, o clique é um engano de dedo, não uma intenção. */
    if (person.charId && chosen.some((p) => p.charId === person.charId)) return;

    chosen.push(person);
    results.replaceChildren();
    search.querySelector('input').value = '';
    drawChosen();
  };

  const run = async () => {
    const term = search.querySelector('input').value.trim();

    results.replaceChildren();

    if (!term) return;

    const found = (await call('nv_mdt:police:searchCitizen', term)) || [];

    if (found.length === 0) {
      results.appendChild(make('div', 'empty-note', 'Nada encontrado.'));
      return;
    }

    found.forEach((person) => {
      const { item } = record(person.fullName,
        `#${person.charId} · ${person.stateId || ''} · ${person.dob || ''}`.trim());

      item.classList.add('clickable');
      item.addEventListener('click', () => add({ charId: person.charId, name: person.fullName }));
      results.appendChild(item);
    });
  };

  addBtn.addEventListener('click', run);
  search.querySelector('input').addEventListener('keydown', (e) => { if (e.key === 'Enter') run(); });

  freeBtn.addEventListener('click', () => {
    const name = search.querySelector('input').value.trim();

    if (name) add({ charId: null, name });
  });

  row.append(search, addBtn, freeBtn);
  box.append(row, results, list);
  drawChosen();

  return { box, chosen };
}

// ------------------------------------------------------------ ocorrências --

async function policeOcorrencias(stage) {
  stage.appendChild(make('div', 'page-title', 'Ocorrências'));

  if (state.ctx.reportForm) return reportForm(stage);

  /* Lista primeiro, formulário atrás de um botão. A ocorrência é consultada
     muitas vezes e criada poucas: abrir direto no formulário colocava o gesto
     raro na frente do gesto comum. */
  const bar = make('div', 'row-inline');
  const search = input('Buscar por cidadão, responsável ou descrição...');
  const periodSeg = make('div', 'seg');
  const newBtn = make('button', 'btn primary', 'Nova ocorrência');

  let period = state.ctx.reportPeriod || 'all';

  (state.cfg.police.periods || []).forEach((p) => {
    const button = make('button', null, p.label);

    button.classList.toggle('active', p.key === period);
    button.addEventListener('click', () => {
      period = p.key;
      state.ctx.reportPeriod = p.key;
      periodSeg.querySelectorAll('button').forEach((x) => x.classList.toggle('active', x === button));
      draw();
    });

    periodSeg.appendChild(button);
  });

  newBtn.addEventListener('click', () => {
    state.ctx.reportForm = true;
    go('ocorrencias');
  });

  bar.append(field('Buscar', search), newBtn);

  const box = section();
  box.append(bar, make('label', 'field-label', 'Período'), periodSeg);
  stage.appendChild(box);

  const list = make('div', 'record-list');
  stage.appendChild(list);

  const draw = async () => {
    list.replaceChildren();
    list.appendChild(make('div', 'empty-note', 'Carregando...'));

    const reports = (await call('nv_mdt:police:reports', {
      search: search.value.trim(), period
    })) || [];

    list.replaceChildren();

    if (reports.length === 0) {
      list.appendChild(make('div', 'empty-note', 'Nenhuma ocorrência encontrada.'));
      return;
    }

    const redraw = () => {
      list.replaceChildren();

      const info = paginate(reports, 'reports');

      info.slice.forEach((r) => {
        const { item, head } = record(r.citizen || 'Não identificado',
          `${r.created} · ${r.author}`);

        /* O tipo é um badge e não parte do título: numa lista longa, a cor é o
           que deixa varrer a coluna sem ler cada linha. */
        head.insertBefore(make('span', 'badge warn', reportLabel(r.type)), head.firstChild.nextSibling);

        const view = make('button', 'btn small', 'Visualizar');

        view.addEventListener('click', () => showReport(r));
        head.appendChild(view);

        list.appendChild(item);
      });

      pager(list, 'reports', info, redraw);
    };

    redraw();
  };

  let timer = null;

  search.addEventListener('input', () => {
    /* Espera a digitação parar. Sem isso cada tecla dispara uma consulta ao
       banco, e as respostas chegam fora de ordem — a lista pisca resultados de
       um termo que já não está no campo. */
    clearTimeout(timer);
    timer = setTimeout(draw, 300);
  });

  draw();
}

/** Detalhe completo de uma ocorrência, num painel sobreposto. */
function showReport(report) {
  const overlay = make('div', 'overlay');
  const panel = make('div', 'overlay-panel');
  const head = make('div', 'overlay-head');

  head.appendChild(make('div', 'page-title', reportLabel(report.type)));

  const closeBtn = make('button', 'icon-btn', '✕');

  closeBtn.addEventListener('click', () => overlay.remove());
  head.appendChild(closeBtn);
  panel.appendChild(head);

  panel.appendChild(grid([
    ['Cidadão', report.citizen || '—'],
    ['Telefone', report.phone || '—'],
    ['Responsável', report.author],
    ['Data', report.created]
  ]));

  const involved = Array.isArray(report.involved) ? report.involved : [];

  if (involved.length > 0) {
    const box = section('Envolvidos');
    const list = make('div', 'record-list');

    involved.forEach((person) => {
      const { item } = record(person.name, person.charId ? `#${person.charId}` : 'Sem cadastro');

      /* Envolvido com cadastro leva ao perfil: é o caminho que qualquer um
         tenta fazer ao ler um nome numa ocorrência. */
      if (person.charId) {
        item.classList.add('clickable');
        item.addEventListener('click', () => {
          overlay.remove();
          state.ctx.citizenId = person.charId;
          go('cidadao');
        });
      }

      list.appendChild(item);
    });

    box.appendChild(list);
    panel.appendChild(box);
  }

  const desc = section('Descrição');

  desc.appendChild(make('div', 'doc-content', report.notes || '(sem descrição)'));
  panel.appendChild(desc);

  overlay.appendChild(panel);
  overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.remove(); });
  dom.root.appendChild(overlay);
}

async function reportForm(stage) {
  const back = make('button', 'btn small', '‹ Voltar ao histórico');

  back.addEventListener('click', () => {
    state.ctx.reportForm = false;
    go('ocorrencias');
  });

  stage.appendChild(back);

  /* Nome e telefone vêm do servidor e são somente leitura. O formulário pede
     "quem está fazendo a ocorrência" — se fosse digitável, seria o campo onde
     se assina o nome de outra pessoa. */
  const self = (await call('nv_mdt:police:self')) || {};

  const who = section('Responsável');
  const nameField = input('', self.name || '');
  const phoneField = input('', self.phone || '—');

  nameField.readOnly = true;
  phoneField.readOnly = true;
  nameField.classList.add('readonly');
  phoneField.classList.add('readonly');

  const whoRow = make('div', 'row-inline');

  whoRow.append(field('Nome', nameField), field('Telefone', phoneField));
  who.appendChild(whoRow);
  stage.appendChild(who);

  const form = section('Dados da ocorrência');
  const citizen = input('Nome do cidadão principal');
  const seg = make('div', 'seg');

  let type = state.cfg.police.reportTypes[0].value;

  state.cfg.police.reportTypes.forEach((t) => {
    const button = make('button', null, t.label);

    button.classList.toggle('active', t.value === type);
    button.addEventListener('click', () => {
      type = t.value;
      seg.querySelectorAll('button').forEach((x) => x.classList.toggle('active', x === button));
    });

    seg.appendChild(button);
  });

  const notes = textarea('Descreva o ocorrido...');

  form.append(field('Cidadão', citizen), make('label', 'field-label', 'Tipo'), seg,
    field('Descrição', notes));
  stage.appendChild(form);

  const picker = involvedPicker();

  stage.appendChild(picker.box);

  const submit = make('button', 'btn primary', 'Registrar ocorrência');

  submit.addEventListener('click', async () => {
    const result = await action('nv_mdt:police:addReport', 'Ocorrência registrada.', {
      type,
      citizen: citizen.value.trim(),
      phone: self.phone || null,
      involved: picker.chosen,
      notes: notes.value.trim()
    });

    if (result && result.ok) {
      state.ctx.reportForm = false;
      go('ocorrencias');
    }
  });

  stage.appendChild(submit);
}

// ---------------------------------------------------------------- cidadão --

/** Busca reutilizável: campo + resultados clicáveis. */
function searchBox(placeholder, endpoint, onPick) {
  const box = section();
  const row = make('div', 'row-inline');
  const field_ = field('Buscar', input(placeholder));
  const btn = make('button', 'btn', 'Buscar');
  const results = make('div', 'record-list');

  results.style.marginTop = '10px';
  row.append(field_, btn);
  box.append(row, results);

  const run = async () => {
    const term = field_.querySelector('input').value.trim();

    results.replaceChildren();

    if (!term) return;

    const found = (await call(endpoint, term)) || [];

    if (found.length === 0) {
      results.appendChild(make('div', 'empty-note', 'Nada encontrado.'));
      return;
    }

    found.forEach((item) => {
      const { item: node } = record(item.fullName || item.plate,
        `#${item.charId || ''} ${item.stateId || ''}`.trim());

      node.classList.add('clickable');
      node.addEventListener('click', () => onPick(item));
      results.appendChild(node);
    });
  };

  btn.addEventListener('click', run);
  field_.querySelector('input').addEventListener('keydown', (e) => { if (e.key === 'Enter') run(); });

  return box;
}

async function policeCidadao(stage) {
  stage.appendChild(make('div', 'page-title', 'Cidadão'));

  const area = make('div');

  stage.appendChild(searchBox('Nome, ID (#12) ou State ID...', 'nv_mdt:police:searchCitizen',
    (item) => showCitizen(area, item.charId)));
  stage.appendChild(area);

  if (state.ctx.citizenId) showCitizen(area, state.ctx.citizenId, state.ctx.citizenTab);
}

const CITIZEN_TABS = [
  { id: 'historico', label: 'Histórico' },
  { id: 'multas', label: 'Multas' },
  { id: 'prisoes', label: 'Prisões' },
  { id: 'veiculos', label: 'Veículos' },
  { id: 'faturas', label: 'Faturas' },
  { id: 'procurado', label: 'Procurado' }
];

async function showCitizen(area, charId, tab) {
  state.ctx.citizenId = charId;
  state.ctx.citizenTab = tab || 'historico';

  area.replaceChildren();

  const c = await call('nv_mdt:police:citizen', charId);

  if (!c) {
    area.appendChild(make('div', 'empty-note', 'Cidadão não encontrado.'));
    return;
  }

  const box = card(c.fullName, `ID #${c.charId} · ${c.stateId}`, ICONS.user);

  box.appendChild(grid([
    ['Nascimento', c.dob || '—'],
    ['Telefone', c.phoneNumber || '—'],
    ['CNH', c.driver ? 'Válida' : 'Sem CNH', c.driver ? 'ok' : 'danger'],
    ['Porte de arma', c.weapon ? 'Registrado' : 'Sem registro', c.weapon ? 'ok' : 'warn'],
    ['Procurado', c.wanted ? 'Sim' : 'Não', c.wanted ? 'danger' : 'ok'],
    ['Em aberto', money(c.invoicesTotal), c.invoicesTotal > 0 ? 'danger' : 'ok']
  ]));

  const actions = make('div', 'btn-row');

  actions.style.marginTop = '10px';

  const fineBtn = make('button', 'btn', 'Aplicar multa');
  const arrestBtn = make('button', 'btn', 'Registrar prisão');
  const cnhBtn = make('button', 'btn', c.driver ? 'Cassar CNH' : 'Conceder CNH');

  cnhBtn.addEventListener('click', async () => {
    const result = await action('nv_mdt:police:setLicense',
      c.driver ? 'CNH cassada.' : 'CNH concedida.', charId, 'driver', !c.driver);

    if (result && result.ok) showCitizen(area, charId, state.ctx.citizenTab);
  });

  actions.appendChild(actionMenu([fineBtn, arrestBtn, cnhBtn]));
  box.appendChild(actions);
  area.appendChild(box);

  const panels = make('div');

  area.appendChild(panels);

  fineBtn.addEventListener('click', () => {
    panels.replaceChildren(fineForm(area, c));
  });

  arrestBtn.addEventListener('click', () => {
    panels.replaceChildren(arrestForm(area, c));
  });

  const content = make('div');

  area.appendChild(tabBar(CITIZEN_TABS, state.ctx.citizenTab,
    (id) => showCitizen(area, charId, id)));
  area.appendChild(content);

  drawCitizenTab(content, area, c, state.ctx.citizenTab);
}

function drawCitizenTab(content, area, c, tab) {
  content.replaceChildren();

  if (tab === 'multas') return drawFines(content, c);
  if (tab === 'prisoes') return drawArrests(content, c);
  if (tab === 'veiculos') return drawCitizenVehicles(content, c);
  if (tab === 'faturas') return drawInvoices(content, area, c);
  if (tab === 'procurado') return drawWanted(content, area, c);

  /* Histórico é a mistura das duas linhas do tempo. A pergunta "o que já
     aconteceu com essa pessoa" não separa multa de prisão — quem quer só um dos
     dois tem a aba dedicada ao lado. */
  const box = section('Histórico');
  const list = make('div', 'record-list');
  const events = [];

  (c.fines || []).forEach((f) => events.push({
    when: f.created, title: f.label, meta: `Multa · ${f.officer}`, value: f.value, danger: false
  }));

  (c.arrests || []).forEach((a) => events.push({
    when: a.created, title: a.reasons, meta: `Prisão · ${a.officer}`, desc: a.notes, danger: true
  }));

  if (events.length === 0) {
    list.appendChild(make('div', 'empty-note', 'Nada registrado.'));
  } else {
    /* Ordena por data desc. As datas vêm formatadas como dd/mm/aaaa HH:mm, que
       não ordena como texto — por isso a chave é remontada como aaaammdd. */
    const key = (s) => {
      const m = /(\d{2})\/(\d{2})\/(\d{4})\s+(\d{2}):(\d{2})/.exec(s || '');

      return m ? `${m[3]}${m[2]}${m[1]}${m[4]}${m[5]}` : '0';
    };

    events.sort((a, b) => key(b.when).localeCompare(key(a.when)));

    events.forEach((e) => {
      const { item, head } = record(e.title, `${e.when} · ${e.meta}`, e.desc, e.danger);

      if (e.value) head.appendChild(make('span', null, money(e.value)));
      list.appendChild(item);
    });
  }

  box.appendChild(list);
  content.appendChild(box);
}

function drawFines(content, c) {
  const box = section(`Multas — total aplicado ${money(c.finesTotal)}`);
  const list = make('div', 'record-list');

  if (!c.fines || c.fines.length === 0) {
    list.appendChild(make('div', 'empty-note', 'Nenhuma multa.'));
  } else {
    c.fines.forEach((f) => {
      const { item, head } = record(f.label, `${f.created} · ${f.officer}`);

      head.appendChild(make('span', null, money(f.value)));
      list.appendChild(item);
    });
  }

  box.appendChild(list);
  content.appendChild(box);
}

function drawArrests(content, c) {
  const box = section('Prisões');
  const list = make('div', 'record-list');

  if (!c.arrests || c.arrests.length === 0) {
    list.appendChild(make('div', 'empty-note', 'Nenhuma prisão.'));
  } else {
    c.arrests.forEach((a) => {
      const { item, head } = record(a.reasons, `${a.created} · ${a.officer}`,
        a.notes || '(sem descrição)', true);

      if (a.reduction > 0) {
        head.appendChild(make('span', 'badge warn', `-${a.reduction}% de pena`));
      }

      if (a.evidence) {
        item.appendChild(make('div', 'record-desc', `Evidência: ${a.evidence}`));
      }

      list.appendChild(item);
    });
  }

  box.appendChild(list);
  content.appendChild(box);
}

function drawCitizenVehicles(content, c) {
  const box = section('Veículos no nome');
  const list = make('div', 'record-list');

  if (!c.vehicles || c.vehicles.length === 0) {
    list.appendChild(make('div', 'empty-note', 'Nenhum veículo registrado.'));
  } else {
    c.vehicles.forEach((v) => {
      const { item, head } = record(v.plate, v.model);
      const view = make('button', 'btn small', 'Consultar veículo');

      /* Leva à aba de veículos com a placa já consultada: o caminho
         cidadão → carro é o mais percorrido de todo o MDT, e obrigar a copiar a
         placa à mão é o tipo de atrito que faz o policial usar o /veh do admin
         em vez do terminal. */
      view.addEventListener('click', () => {
        state.ctx.plate = v.plate;
        go('veiculos');
      });

      head.appendChild(view);
      list.appendChild(item);
    });
  }

  box.appendChild(list);
  content.appendChild(box);
}

function drawInvoices(content, area, c) {
  const cfg = state.cfg.police.invoices || { dailyRate: 0.1, maxDays: 3 };
  const box = section(`Faturas em aberto — ${money(c.invoicesTotal)}`);
  const list = make('div', 'record-list');
  const invoices = c.invoices || [];

  if (invoices.length === 0) {
    list.appendChild(make('div', 'empty-note', 'Nenhuma fatura em aberto.'));
    box.appendChild(list);
    content.appendChild(box);
    return;
  }

  const selected = new Set();

  invoices.forEach((inv) => {
    const { item, head } = record(inv.label, `${inv.created} · ${inv.officer}`);
    const check = make('input');

    check.type = 'checkbox';
    check.className = 'check';
    check.addEventListener('change', () => {
      if (check.checked) selected.add(inv.id); else selected.delete(inv.id);
    });

    head.insertBefore(check, head.firstChild);

    /* Mostrar original e corrigido lado a lado explica o atraso sozinho. Só o
       número final pareceria erro de digitação para quem lembra do valor da
       multa. */
    if (inv.interest > 0) {
      head.appendChild(make('span', 'badge warn', `+${inv.days}d`));
      head.appendChild(make('span', 'strike', money(inv.value)));
    }

    head.appendChild(make('span', null, money(inv.total)));
    list.appendChild(item);
  });

  box.appendChild(list);

  box.appendChild(make('div', 'muted',
    `Juros de ${Math.round(cfg.dailyRate * 100)}% ao dia sobre o valor original, até ${cfg.maxDays} dias.`));

  const row = make('div', 'btn-row');
  const chargeAll = make('button', 'btn primary', `Cobrar tudo — ${money(c.invoicesTotal)}`);
  const chargeSome = make('button', 'btn', 'Cobrar selecionadas');

  chargeAll.addEventListener('click', async () => {
    const result = await action('nv_mdt:police:chargeInvoices', 'Faturas cobradas.', c.charId, null);

    if (result && result.ok) showCitizen(area, c.charId, 'faturas');
  });

  chargeSome.addEventListener('click', async () => {
    if (selected.size === 0) return;

    const result = await action('nv_mdt:police:chargeInvoices', 'Faturas cobradas.',
      c.charId, Array.from(selected));

    if (result && result.ok) showCitizen(area, c.charId, 'faturas');
  });

  row.appendChild(actionMenu([chargeAll, chargeSome]));
  box.appendChild(row);
  content.appendChild(box);
}

function drawWanted(content, area, c) {
  const box = section('Procurado');

  if (c.wanted) {
    box.appendChild(grid([
      ['Motivo', c.wanted.reason],
      ['Tipo', c.wanted.type ? typeLabel(c.wanted.type) : '—'],
      ['Registrado por', c.wanted.officer],
      ['Data', c.wanted.created || '—']
    ]));

    if (c.wanted.evidence) {
      const ev = section('Evidência');

      ev.appendChild(make('div', 'doc-content', c.wanted.evidence));
      box.appendChild(ev);
    }

    const remove = make('button', 'btn primary', 'Remover dos procurados');

    remove.addEventListener('click', async () => {
      const result = await action('nv_mdt:police:setWanted', 'Removido dos procurados.', c.charId, null);

      if (result && result.ok) showCitizen(area, c.charId, 'procurado');
    });

    box.appendChild(remove);
    content.appendChild(box);
    return;
  }

  /* O formulário de procurado usa a MESMA lista de tipos da prisão: procurado
     por homicídio e preso por homicídio são o mesmo tipo penal, e duas listas
     divergiriam na primeira edição. */
  const reason = input('Motivo da procura');
  const seg = make('div', 'seg');
  const evidence = textarea('Links, descrição de provas, testemunhas...');

  let kind = null;

  (state.cfg.police.arrestTypes || []).forEach((t) => {
    const button = make('button', null, t.label);

    button.addEventListener('click', () => {
      kind = kind === t.key ? null : t.key;
      seg.querySelectorAll('button').forEach((x) => {
        x.classList.toggle('active', kind !== null && x === button);
      });
    });

    seg.appendChild(button);
  });

  const submit = make('button', 'btn primary', 'Adicionar aos procurados');

  submit.addEventListener('click', async () => {
    const result = await action('nv_mdt:police:setWanted', 'Lista atualizada.', c.charId, {
      reason: reason.value.trim(), type: kind, evidence: evidence.value.trim()
    });

    if (result && result.ok) showCitizen(area, c.charId, 'procurado');
  });

  box.append(field('Motivo', reason), make('label', 'field-label', 'Tipo'), seg,
    field('Evidência', evidence), submit);
  content.appendChild(box);
}

// ------------------------------------------------------- multa e prisão --

function fineForm(area, c) {
  const panel = section('Aplicar multa');
  const picks = make('div', 'pick-list');
  const total = make('div', 'ms-total');
  const chosen = new Set();

  const updateTotal = () => {
    let sum = 0;

    state.cfg.police.fines.forEach((f) => { if (chosen.has(f.key)) sum += f.value; });
    total.replaceChildren(document.createTextNode('Total: '), make('span', null, money(sum)));
  };

  pickList(picks, state.cfg.police.fines, chosen, updateTotal);
  updateTotal();

  const notes = textarea('Descrição do que motivou a multa...');
  const apply = make('button', 'btn primary', 'Aplicar multa(s)');

  apply.addEventListener('click', async () => {
    if (chosen.size === 0) return;

    const result = await action('nv_mdt:police:fine', 'Multa aplicada.',
      c.charId, Array.from(chosen), notes.value.trim());

    if (result && result.ok) showCitizen(area, c.charId, 'faturas');
  });

  panel.append(picks, total, field('Descrição', notes), apply);

  return panel;
}

function arrestForm(area, c) {
  const panel = section('Registrar prisão');
  const typePicks = make('div', 'pick-list');
  const finePicks = make('div', 'pick-list');
  const types = new Set();
  const fines = new Set();
  const total = make('div', 'ms-total');

  const updateTotal = () => {
    let sum = 0;

    state.cfg.police.fines.forEach((f) => { if (fines.has(f.key)) sum += f.value; });
    total.replaceChildren(document.createTextNode('Multas: '), make('span', null, money(sum)));
  };

  const drawFinePicks = () => {
    finePicks.replaceChildren();
    pickList(finePicks, state.cfg.police.fines, fines, updateTotal);
    updateTotal();
  };

  /* Marcar um tipo penal ADICIONA as multas ligadas a ele, e desmarcar não as
     tira. É deliberado: o policial pode ter marcado uma multa à mão, e um
     clique no tipo errado não deve apagar uma decisão que ele já tomou. Tirar é
     sempre um gesto explícito na lista de baixo. */
  pickList(typePicks, state.cfg.police.arrestTypes, types, () => {
    state.cfg.police.arrestTypes.forEach((t) => {
      if (types.has(t.key)) (t.fines || []).forEach((key) => fines.add(key));
    });

    drawFinePicks();
  });

  drawFinePicks();

  const notes = textarea('Descreva o ocorrido...');
  const evidence = textarea('Evidências: links, descrição de provas, testemunhas...');
  const reductionSeg = make('div', 'seg');

  let reduction = 0;

  (state.cfg.police.reductions || [0]).forEach((value) => {
    const button = make('button', null, value === 0 ? 'Sem redução' : `${value}%`);

    button.classList.toggle('active', value === reduction);
    button.addEventListener('click', () => {
      reduction = value;
      reductionSeg.querySelectorAll('button').forEach((x) => x.classList.toggle('active', x === button));
    });

    reductionSeg.appendChild(button);
  });

  const submit = make('button', 'btn primary', 'Registrar prisão');

  submit.addEventListener('click', async () => {
    if (types.size === 0) return;

    const result = await action('nv_mdt:police:arrest', 'Prisão registrada.', c.charId, {
      types: Array.from(types),
      fines: Array.from(fines),
      reduction,
      notes: notes.value.trim(),
      evidence: evidence.value.trim()
    });

    if (result && result.ok) showCitizen(area, c.charId, 'prisoes');
  });

  panel.append(
    make('label', 'field-label', 'Tipo penal'), typePicks,
    make('label', 'field-label', 'Multas aplicadas'), finePicks, total,
    field('Descrição do ocorrido', notes),
    make('label', 'field-label', 'Redução de pena'), reductionSeg,
    field('Evidência', evidence),
    submit);

  /* A redução reduz cadeia, não dívida — dizer isso na tela evita a pergunta
     que apareceria toda vez que um valor não batesse com o esperado. */
  panel.appendChild(make('div', 'muted',
    'A redução de pena não desconta as multas: ela vale sobre o tempo de reclusão.'));

  return panel;
}

// ------------------------------------------------------------- procurados --

async function policeProcurados(stage) {
  stage.appendChild(make('div', 'page-title', 'Procurados'));

  const list = make('div', 'record-list');
  const wanted = (await call('nv_mdt:police:wantedList')) || [];

  if (wanted.length === 0) {
    list.appendChild(make('div', 'empty-note', 'Ninguém procurado no momento.'));
  } else {
    wanted.forEach((w) => {
      const { item, head } = record(w.fullName, `${w.created} · ${w.officer}`, w.reason, true);

      if (w.type) head.appendChild(make('span', 'badge danger', typeLabel(w.type)));

      const view = make('button', 'btn small', 'Visualizar');
      const remove = make('button', 'btn small', 'Remover');

      view.addEventListener('click', () => {
        state.ctx.citizenId = w.charId;
        state.ctx.citizenTab = 'procurado';
        go('cidadao');
      });

      remove.addEventListener('click', async () => {
        const result = await action('nv_mdt:police:setWanted', 'Removido.', w.charId, null);

        if (result && result.ok) go('procurados');
      });

      head.appendChild(actionMenu([view, remove]));
      list.appendChild(item);
    });
  }

  stage.appendChild(list);
}

// --------------------------------------------------------------- veículos --

const VEHICLE_TABS = [
  { id: 'apreensoes', label: 'Apreensões' },
  { id: 'multas', label: 'Multas do proprietário' },
  { id: 'roubo', label: 'Denúncia de roubo' }
];

async function policeVeiculos(stage) {
  stage.appendChild(make('div', 'page-title', 'Veículos'));

  const area = make('div');
  const box = section();
  const row = make('div', 'row-inline');
  const plate = field('Placa', input('ABC1234', state.ctx.plate || ''));
  const btn = make('button', 'btn', 'Consultar');

  row.append(plate, btn);
  box.appendChild(row);

  const lookup = async () => {
    const value = plate.querySelector('input').value.trim().toUpperCase();

    area.replaceChildren();

    if (!value) return;

    state.ctx.plate = value;

    const v = await call('nv_mdt:police:vehicle', value);

    if (!v) {
      area.appendChild(make('div', 'empty-note', 'Veículo não encontrado.'));
      return;
    }

    drawVehicle(area, v, lookup);
  };

  btn.addEventListener('click', lookup);
  plate.querySelector('input').addEventListener('keydown', (e) => { if (e.key === 'Enter') lookup(); });

  stage.append(box, area);

  /* Chegou pela ficha de um cidadão: a placa já veio preenchida, e fazer o
     policial clicar em "Consultar" seria pedir confirmação de algo que ele
     acabou de pedir. */
  if (state.ctx.plate) lookup();

  const stolenBox = section('Roubados no momento');
  const stolenList = make('div', 'record-list');
  const stolen = (await call('nv_mdt:police:stolenList')) || [];

  if (stolen.length === 0) {
    stolenList.appendChild(make('div', 'empty-note', 'Nenhum veículo com alerta.'));
  } else {
    stolen.forEach((s) => {
      const { item, head } = record(`${s.plate} — ${s.model || '?'}`,
        `Proprietário: ${s.owner || '—'}`, null, true);
      const view = make('button', 'btn small', 'Consultar');

      view.addEventListener('click', () => {
        state.ctx.plate = s.plate;
        go('veiculos');
      });

      head.appendChild(view);
      stolenList.appendChild(item);
    });
  }

  stolenBox.appendChild(stolenList);
  stage.appendChild(stolenBox);
}

function drawVehicle(area, v, refresh) {
  const info = card(v.plate, `${v.model} · ${v.owner || 'sem dono'}`, ICONS.car);

  info.appendChild(grid([
    ['Proprietário', v.owner || '—'],
    ['Situação', v.stolen ? 'Roubado' : 'Regular', v.stolen ? 'danger' : 'ok'],
    ['Local', v.stored || 'Na rua'],
    ['VIN', v.vin || '—']
  ]));

  const vehicleActions = [];
  const track = make('button', 'btn small', 'Rastrear veículo');

  track.addEventListener('click', async () => {
    const result = await post('trackVehicle', { plate: v.plate });

    if (!result || !result.ok) {
      info.appendChild(make('div', 'empty-note',
        result?.error || 'Não foi possível iniciar o rastreamento.'));
    }
  });
  vehicleActions.push(track);

  if (v.ownerId) {
    const owner = make('button', 'btn small', 'Abrir ficha do proprietário');

    owner.addEventListener('click', () => {
      state.ctx.citizenId = v.ownerId;
      state.ctx.citizenTab = 'historico';
      go('cidadao');
    });

    vehicleActions.push(owner);
  }

  info.appendChild(actionMenu(vehicleActions));

  area.appendChild(info);

  const content = make('div');
  const tab = state.ctx.vehicleTab || 'apreensoes';

  area.appendChild(tabBar(VEHICLE_TABS, tab, (id) => {
    state.ctx.vehicleTab = id;
    area.replaceChildren();
    drawVehicle(area, v, refresh);
  }));

  area.appendChild(content);

  if (tab === 'multas') {
    const box = section('Multas do proprietário');
    const list = make('div', 'record-list');

    /* O registro de multa é POR PESSOA. Associá-las ao carro seria mentira: o
       proprietário pode ter sido multado dirigindo outro veículo. O rótulo da
       aba diz de quem são. */
    if (!v.ownerFines || v.ownerFines.length === 0) {
      list.appendChild(make('div', 'empty-note', 'Nenhuma multa do proprietário.'));
    } else {
      v.ownerFines.forEach((f) => {
        const { item, head } = record(f.label, f.created);

        head.appendChild(make('span', null, money(f.value)));
        list.appendChild(item);
      });
    }

    box.appendChild(list);
    content.appendChild(box);
    return;
  }

  if (tab === 'roubo') {
    const box = section('Denúncia de roubo');

    box.appendChild(grid([
      ['Situação atual', v.stolen ? 'Com alerta de roubo' : 'Sem alerta',
        v.stolen ? 'danger' : 'ok']
    ]));

    const toggle = make('button', 'btn primary',
      v.stolen ? 'Remover alerta de roubo' : 'Registrar denúncia de roubo');

    toggle.addEventListener('click', async () => {
      const result = await action('nv_mdt:police:setStolen', 'Situação atualizada.',
        v.plate, !v.stolen);

      if (result && result.ok) refresh();
    });

    box.appendChild(toggle);
    content.appendChild(box);
    return;
  }

  const box = section('Apreensões');
  const list = make('div', 'record-list');

  if (!v.seizures || v.seizures.length === 0) {
    list.appendChild(make('div', 'empty-note', 'Nenhuma apreensão.'));
  } else {
    v.seizures.forEach((s) => list.appendChild(
      record(s.reason, `${s.created} · ${s.officer}`, null, true).item));
  }

  box.appendChild(list);

  const reason = input('Motivo da apreensão');
  const register = make('button', 'btn primary', 'Registrar apreensão');

  register.addEventListener('click', async () => {
    const result = await action('nv_mdt:police:seize', 'Apreensão registrada.',
      v.plate, reason.value.trim());

    if (result && result.ok) refresh();
  });

  box.append(field('Motivo', reason), register);
  content.appendChild(box);
}

// ----------------------------------------------------- faturas pendentes --

async function policeFaturas(stage) {
  stage.appendChild(make('div', 'page-title', 'Faturas pendentes'));

  const rows = (await call('nv_mdt:police:invoiceList')) || [];
  const list = make('div', 'record-list');

  if (rows.length === 0) {
    list.appendChild(make('div', 'empty-note', 'Ninguém com faturas em aberto.'));
    stage.appendChild(list);
    return;
  }

  const draw = () => {
    list.replaceChildren();

    const info = paginate(rows, 'invoices');

    info.slice.forEach((r) => {
      const { item, head } = record(r.fullName,
        `#${r.charId} · ${r.stateId || ''} · ${r.count} fatura(s)`);

      /* O atraso vem antes do valor de propósito: é ele que explica por que o
         total não bate com a soma das multas. */
      if (r.oldest > 0) head.appendChild(make('span', 'badge warn', `${r.oldest}d`));

      head.appendChild(make('span', null, money(r.total)));

      const open = make('button', 'btn small', 'Abrir ficha');
      const charge = make('button', 'btn small', 'Cobrar tudo');

      open.addEventListener('click', () => {
        state.ctx.citizenId = r.charId;
        state.ctx.citizenTab = 'faturas';
        go('cidadao');
      });

      charge.addEventListener('click', async () => {
        const result = await action('nv_mdt:police:chargeInvoices', 'Faturas cobradas.',
          r.charId, null);

        if (result && result.ok) go('faturas');
      });

      head.appendChild(actionMenu([open, charge]));
      list.appendChild(item);
    });

    pager(list, 'invoices', info, draw);
  };

  draw();
  stage.appendChild(list);
}

// ------------------------------------------------------------------ resto --

async function policeArmas(stage) {
  stage.appendChild(make('div', 'page-title', 'Porte de arma'));

  const area = make('div');

  stage.appendChild(searchBox('Nome ou ID do cidadão...', 'nv_mdt:police:searchCitizen', async (item) => {
    area.replaceChildren();

    const check = await call('nv_mdt:police:gunCheck', item.charId);

    if (!check) return;

    const box = card(item.fullName, `#${item.charId} · ${item.stateId}`, ICONS.user);

    box.appendChild(grid([
      ['Elegibilidade', check.eligible ? 'Elegível' : 'Não elegível', check.eligible ? 'ok' : 'danger'],
      ['Porte atual', check.licensed ? 'Registrado' : 'Sem registro', check.licensed ? 'ok' : 'warn']
    ]));

    if (!check.eligible && check.reason) {
      box.appendChild(make('div', 'record-meta', check.reason));
    }

    const btn = make('button', 'btn primary', check.licensed ? 'Cassar porte' : 'Conceder porte');

    btn.style.marginTop = '10px';
    btn.disabled = !check.licensed && !check.eligible;
    btn.addEventListener('click', async () => {
      const result = await action('nv_mdt:police:setLicense',
        check.licensed ? 'Porte cassado.' : 'Porte concedido.',
        item.charId, 'weapon', !check.licensed);

      if (result && result.ok) area.replaceChildren();
    });

    box.appendChild(btn);
    area.appendChild(box);
  }));

  stage.appendChild(area);
}

function policeDocumentos(stage) {
  stage.appendChild(make('div', 'page-title', 'Documentos'));

  const docs = state.cfg.police.documents || [];

  if (docs.length === 0) {
    stage.appendChild(make('div', 'empty-note', 'Nenhum documento cadastrado.'));
    return;
  }

  const tabs = make('div', 'doc-tabs');
  const content = make('div', 'doc-content', docs[0].text);

  docs.forEach((doc, i) => {
    const tab = make('button', 'doc-tab', doc.label);

    tab.classList.toggle('active', i === 0);
    tab.addEventListener('click', () => {
      tabs.querySelectorAll('.doc-tab').forEach((t) => t.classList.toggle('active', t === tab));
      content.textContent = doc.text;
    });

    tabs.appendChild(tab);
  });

  stage.append(tabs, content);
}

async function policeDashboard(stage) {
  await renderDashboard(stage, 'police');
}

async function policeComandos(stage) {
  await renderStaff(stage, 'police');
}

// ------------------------------------------------------------- live map --

async function policeMapa(stage) {
  const toolbar = make('div', 'toolbar');
  toolbar.appendChild(make('div', 'page-title', 'Live Map'));
  const refresh = make('button', 'btn small', 'Atualizar');
  refresh.addEventListener('click', () => go('mapa'));
  toolbar.appendChild(refresh);
  stage.appendChild(toolbar);

  const data = await call('nv_mdt:dashboard', 'police');
  const bounds = await post('mapBounds');
  const wrap = make('div', 'map-wrap');
  const map = make('div', 'map');
  const detail = make('div', 'map-detail');

  map.classList.add('has-image');
  map.style.backgroundImage = "url('assets/map.jpeg')";

  const online = (data && data.online) || [];
  const withCoords = online.filter((p) => p.coords);

  if (withCoords.length === 0) {
    map.appendChild(make('div', 'empty-note', 'Nenhum colega em serviço no momento.'));
  } else {
    withCoords.forEach((p) => {
      // Y invertido: no mundo o Y cresce para o norte, na tela cresce para baixo.
      const x = ((p.coords.x - bounds.minX) / (bounds.maxX - bounds.minX)) * 100;
      const y = 100 - ((p.coords.y - bounds.minY) / (bounds.maxY - bounds.minY)) * 100;

      const dot = make('div', 'map-dot');
      const label = make('div', 'map-label', p.name);

      dot.style.left = `${Math.max(0, Math.min(100, x))}%`;
      dot.style.top = `${Math.max(0, Math.min(100, y))}%`;
      label.style.left = dot.style.left;
      label.style.top = dot.style.top;

      dot.classList.add('clickable');
      dot.addEventListener('click', () => {
        detail.replaceChildren();

        const box = card(p.name, `ID ${p.source}`, ICONS.user);

        box.appendChild(grid([
          ['Posição', `${Math.round(p.coords.x)}, ${Math.round(p.coords.y)}`],
          ['Situação', 'Em serviço', 'ok']
        ]));

        const mark = make('button', 'btn small', 'Marcar no mapa');

        mark.addEventListener('click', () => post('markMap', { x: p.coords.x, y: p.coords.y }));
        box.appendChild(mark);

        detail.appendChild(box);
      });

      map.append(dot, label);
    });
  }

  wrap.append(map, detail);
  stage.appendChild(wrap);

  stage.appendChild(make('div', 'muted', 'Posições aproximadas do efetivo em serviço.'));
}

async function policeCameras(stage) {
  stage.appendChild(make('div', 'page-title', 'Câmeras'));
  const cameras = state.cfg.police.cameras || [];

  if (cameras.length === 0) {
    stage.appendChild(make('div', 'empty-note', 'Nenhuma câmera configurada.'));
    return;
  }

  const grid = make('div', 'cam-grid');
  cameras.forEach((camera) => {
    const tile = make('button', 'cam-tile');
    tile.appendChild(icon(ICONS.camera));
    tile.appendChild(make('span', null, camera.label));
    tile.addEventListener('click', () => post('viewCamera', { id: camera.id }));
    grid.appendChild(tile);
  });
  stage.appendChild(grid);
}

// ============================================================= HOSPITAL ===

const HOSPITAL_NAV = [
  { id: 'dashboard', label: 'Dashboard' },
  { id: 'chamados', label: 'Chamados' },
  { id: 'paciente', label: 'Paciente' },
  { id: 'consulta', label: 'Registrar consulta' },
  { id: 'historico', label: 'Histórico' },
  { id: 'comandos', label: 'Efetivo' }
];

async function hospitalDashboard(stage) {
  await renderDashboard(stage, 'hospital');
}

async function hospitalChamados(stage) {
  stage.appendChild(make('div', 'page-title', 'Chamados'));

  const form = section('Registrar chamado');
  const title = input('Ex: Queda de altura');
  const location = input('Ex: Legion Square');
  const seg = make('div', 'seg');
  let priority = 'media';

  [['baixa', 'Baixa'], ['media', 'Média'], ['alta', 'Alta']].forEach(([value, label]) => {
    const b = make('button', null, label);

    b.classList.toggle('active', value === priority);
    b.addEventListener('click', () => {
      priority = value;
      seg.querySelectorAll('button').forEach((x) => x.classList.toggle('active', x === b));
    });

    seg.appendChild(b);
  });

  const submit = make('button', 'btn primary', 'Registrar chamado');

  submit.addEventListener('click', async () => {
    const result = await action('nv_mdt:hospital:addCall', 'Chamado registrado.', {
      title: title.value.trim(), location: location.value.trim(), priority
    });

    if (result && result.ok) go('chamados');
  });

  form.append(field('Título', title), field('Local', location),
    make('label', 'field-label', 'Prioridade'), seg, submit);
  stage.appendChild(form);

  const list = section('Chamados');
  const box = make('div');
  const calls = (await call('nv_mdt:hospital:calls')) || [];

  const draw = () => {
    box.replaceChildren();

    if (calls.length === 0) {
      box.appendChild(make('div', 'empty-note', 'Nenhum chamado.'));
      return;
    }

    const info = paginate(calls, 'hospCalls');

    info.slice.forEach((c) => box.appendChild(callItem(c)));
    pager(box, 'hospCalls', info, draw);
  };

  draw();
  list.appendChild(box);
  stage.appendChild(list);
}

async function hospitalPaciente(stage) {
  stage.appendChild(make('div', 'page-title', 'Paciente'));

  const area = make('div');

  stage.appendChild(searchBox('Nome ou ID do paciente...', 'nv_mdt:hospital:search',
    (item) => showPatient(area, item.charId)));
  stage.appendChild(area);

  if (state.ctx.patientId) showPatient(area, state.ctx.patientId);
}

async function showPatient(area, charId) {
  state.ctx.patientId = charId;
  area.replaceChildren();

  const p = await call('nv_mdt:hospital:patient', charId);

  if (!p) {
    area.appendChild(make('div', 'empty-note', 'Paciente não encontrado.'));
    return;
  }

  const box = card(p.fullName, `#${p.charId} · ${p.stateId}`, ICONS.user);

  box.appendChild(grid([
    ['Idade', p.age != null ? `${p.age} anos` : '—'],
    ['Nascimento', p.dob || '—'],
    ['Gênero', p.gender || '—'],
    ['Atendimentos', String(p.history.length)]
  ]));

  area.appendChild(box);

  const histBox = section('Histórico de atendimentos');
  const histList = make('div', 'record-list');

  if (p.history.length === 0) histList.appendChild(make('div', 'empty-note', 'Nenhum atendimento.'));
  else p.history.forEach((h) => {
    const { item, head } = record(h.reasons || 'Consulta geral', `${h.created} · ${h.doctor}`);

    head.appendChild(make('span', null, money(h.total)));
    histList.appendChild(item);
  });

  histBox.appendChild(histList);
  area.appendChild(histBox);

  const noteBox = section('Anotações');
  const noteInput = textarea('Nova anotação...');
  const noteBtn = make('button', 'btn', 'Adicionar anotação');
  const noteList = make('div', 'record-list');

  noteList.style.marginTop = '10px';
  noteBtn.addEventListener('click', async () => {
    const result = await action('nv_mdt:hospital:addNote', 'Anotação salva.',
      charId, noteInput.value.trim());

    if (result && result.ok) showPatient(area, charId);
  });

  if (p.notes.length === 0) noteList.appendChild(make('div', 'empty-note', 'Nenhuma anotação.'));
  else p.notes.forEach((n) => noteList.appendChild(
    record(n.author, n.created, n.notes).item));

  noteBox.append(noteInput, noteBtn, noteList);
  area.appendChild(noteBox);
}

async function hospitalConsulta(stage) {
  stage.appendChild(make('div', 'page-title', 'Registrar consulta'));

  const cfg = state.cfg.hospital;
  const chosenPatient = { charId: null, name: '' };
  const picked = make('div', 'record-meta', 'Nenhum paciente selecionado.');

  stage.appendChild(searchBox('Nome ou ID do paciente...', 'nv_mdt:hospital:search', (item) => {
    chosenPatient.charId = item.charId;
    chosenPatient.name = item.fullName;
    picked.textContent = `Paciente: ${item.fullName} (#${item.charId})`;
  }));
  stage.appendChild(picked);

  // motivos
  const reasonBox = section('Motivos');
  const reasonPicks = make('div', 'pick-list');
  const reasons = new Set();

  pickList(reasonPicks, cfg.reasons, reasons);
  reasonBox.appendChild(reasonPicks);
  stage.appendChild(reasonBox);

  // diagrama do corpo
  const bodyBox = section(`Pontos de lesão (clique para 0–${cfg.maxSeverity}, ${money(cfg.pricePerInjury)} por ponto)`);
  const diagram = make('div', 'body-diagram');
  const severity = {};

  cfg.bodyZones.forEach((zone) => {
    severity[zone.key] = 0;

    const part = make('div', `bp bp-${zone.key}`, '0');

    part.dataset.sev = '0';
    part.title = zone.label;
    part.addEventListener('click', () => {
      severity[zone.key] = (severity[zone.key] + 1) % (cfg.maxSeverity + 1);
      part.dataset.sev = String(severity[zone.key]);
      part.textContent = String(severity[zone.key]);
      updateTotal();
    });

    diagram.appendChild(part);
  });

  bodyBox.appendChild(diagram);
  stage.appendChild(bodyBox);

  // recursos
  const resBox = section('Recursos usados');
  const resPicks = make('div', 'pick-list');
  const resources = new Set();

  pickList(resPicks, cfg.resources, resources, () => updateTotal());
  resBox.appendChild(resPicks);
  stage.appendChild(resBox);

  // extras
  const extras = section();
  const hours = make('input', 'field-input');

  hours.type = 'number';
  hours.min = '0';
  hours.step = '0.5';
  hours.value = '1';
  hours.style.maxWidth = '160px';
  hours.addEventListener('input', () => updateTotal());

  const rescue = make('input');
  rescue.type = 'checkbox';
  rescue.addEventListener('change', () => updateTotal());

  const rescueRow = make('label', 'check-row');
  rescueRow.append(rescue, make('span', null, `Teve resgate? (+${money(cfg.rescueFee)})`));

  extras.append(field(`Horas de atendimento (${money(cfg.pricePerHour)}/h)`, hours), rescueRow);
  stage.appendChild(extras);

  // nota
  const receipt = make('div', 'receipt');
  const items = make('div');
  const totalRow = make('div', 'receipt-row total');

  totalRow.append(make('span', null, 'TOTAL'), make('span', null, money(0)));
  receipt.append(
    make('div', 'receipt-store', 'HOSPITAL'),
    make('div', 'receipt-meta', 'Prévia — o valor cobrado é calculado no servidor'),
    make('div', 'receipt-divider'), items, make('div', 'receipt-divider'), totalRow);
  stage.appendChild(receipt);

  function updateTotal() {
    let injuries = 0;

    cfg.bodyZones.forEach((z) => { injuries += (severity[z.key] || 0) * cfg.pricePerInjury; });

    let res = 0;

    cfg.resources.forEach((r) => { if (resources.has(r.key)) res += r.value; });

    const h = Math.max(0, parseFloat(hours.value) || 0) * cfg.pricePerHour;
    const rsc = rescue.checked ? cfg.rescueFee : 0;

    items.replaceChildren();

    [['Lesões', injuries], ['Recursos', res], ['Tempo', h], ['Resgate', rsc]].forEach(([label, value]) => {
      if (!value) return;

      const row = make('div', 'receipt-row');

      row.append(make('span', null, label), make('span', null, money(value)));
      items.appendChild(row);
    });

    totalRow.replaceChildren(make('span', null, 'TOTAL'),
      make('span', null, money(injuries + res + h + rsc)));
  }

  updateTotal();

  const submit = make('button', 'btn primary', 'Registrar consulta');

  submit.addEventListener('click', async () => {
    const result = await action('nv_mdt:hospital:consult', 'Consulta registrada.', {
      charId: chosenPatient.charId,
      name: chosenPatient.name,
      reasons: Array.from(reasons),
      injuries: severity,
      resources: Array.from(resources),
      hours: parseFloat(hours.value) || 0,
      rescue: rescue.checked
    });

    if (result && result.ok) go('historico');
  });

  stage.appendChild(submit);
}

async function hospitalHistorico(stage) {
  stage.appendChild(make('div', 'page-title', 'Histórico de atendimentos'));

  const box = make('div', 'record-list');
  const rows = (await call('nv_mdt:hospital:history')) || [];

  const draw = () => {
    box.replaceChildren();

    if (rows.length === 0) {
      box.appendChild(make('div', 'empty-note', 'Nenhum atendimento registrado.'));
      return;
    }

    const info = paginate(rows, 'hospHist');

    info.slice.forEach((r) => {
      const { item, head } = record(r.name, `${r.created} · ${r.doctor}`, r.reasons || 'Consulta geral');

      head.appendChild(make('span', null, money(r.total)));
      box.appendChild(item);
    });

    pager(box, 'hospHist', info, draw);
  };

  draw();
  stage.appendChild(box);
}

// ============================================================= MECÂNICA ===

const MECHANIC_NAV = [
  { id: 'dashboard', label: 'Dashboard' },
  { id: 'veiculos', label: 'Ordem de serviço' },
  { id: 'historico', label: 'Histórico' },
  { id: 'comandos', label: 'Efetivo' }
];

async function mechanicDashboard(stage) {
  await renderDashboard(stage, 'mecanica');
}

async function mechanicVeiculos(stage) {
  stage.appendChild(make('div', 'page-title', 'Ordem de serviço'));

  const cfg = state.cfg.mechanic;
  const area = make('div');
  const box = section();
  const row = make('div', 'row-inline');
  const plate = field('Placa', input('ABC1234'));
  const btn = make('button', 'btn', 'Consultar');

  row.append(plate, btn);
  box.appendChild(row);
  stage.append(box, area);

  btn.addEventListener('click', async () => {
    const value = plate.querySelector('input').value.trim().toUpperCase();

    area.replaceChildren();

    if (!value) return;

    const v = await call('nv_mdt:mechanic:vehicle', value);

    if (!v) {
      area.appendChild(make('div', 'empty-note', 'Veículo não encontrado.'));
      return;
    }

    area.appendChild(card(v.plate, `${v.model} · ${v.owner || 'sem dono'}`, ICONS.car));

    // diagrama
    const partsBox = section('Peças reparadas');
    const diagram = make('div', 'car-diagram');
    const parts = new Set();

    cfg.parts.forEach((part) => {
      const node = make('div', `car-part cp-${part.key}`, part.label);

      node.addEventListener('click', () => {
        if (parts.has(part.key)) parts.delete(part.key); else parts.add(part.key);
        node.classList.toggle('on', parts.has(part.key));
        updateReceipt();
      });

      diagram.appendChild(node);
    });

    partsBox.appendChild(diagram);
    area.appendChild(partsBox);

    const notes = textarea('Descreva o serviço realizado...');
    const billed = input(v.owner || 'Nome de quem paga');
    const tow = make('input');

    tow.type = 'checkbox';
    tow.addEventListener('change', () => updateReceipt());

    const towRow = make('label', 'check-row');
    towRow.append(tow, make('span', null, `Teve reboque? (+${money(cfg.towFee)})`));

    const extras = section();
    extras.append(field('Descrição', notes), field('Cobrar de', billed), towRow);
    area.appendChild(extras);

    const receipt = make('div', 'receipt');
    const items = make('div');
    const totalRow = make('div', 'receipt-row total');

    totalRow.append(make('span', null, 'TOTAL'), make('span', null, money(0)));
    receipt.append(
      make('div', 'receipt-store', 'OFICINA'),
      make('div', 'receipt-meta', `Ordem de serviço — ${v.plate}`),
      make('div', 'receipt-divider'), items, make('div', 'receipt-divider'), totalRow);
    area.appendChild(receipt);

    function updateReceipt() {
      let total = 0;

      items.replaceChildren();

      cfg.parts.forEach((part) => {
        if (!parts.has(part.key)) return;

        total += part.value;

        const line = make('div', 'receipt-row');

        line.append(make('span', null, part.label), make('span', null, money(part.value)));
        items.appendChild(line);
      });

      if (tow.checked) {
        total += cfg.towFee;

        const line = make('div', 'receipt-row');

        line.append(make('span', null, 'Reboque'), make('span', null, money(cfg.towFee)));
        items.appendChild(line);
      }

      if (items.childElementCount === 0) {
        items.appendChild(make('div', 'receipt-row', 'Nenhuma peça selecionada'));
      }

      totalRow.replaceChildren(make('span', null, 'TOTAL'), make('span', null, money(total)));
    }

    updateReceipt();

    const submit = make('button', 'btn primary', 'Fechar ordem de serviço');

    submit.addEventListener('click', async () => {
      const result = await action('nv_mdt:mechanic:repair', 'Ordem registrada.', {
        plate: v.plate,
        model: v.model,
        parts: Array.from(parts),
        notes: notes.value.trim(),
        billedTo: billed.value.trim() || v.owner,
        tow: tow.checked
      });

      if (result && result.ok) go('historico');
    });

    area.appendChild(submit);

    if (v.repairs.length > 0) {
      const hist = section('Consertos anteriores');
      const list = make('div', 'record-list');

      v.repairs.forEach((r) => {
        const { item, head } = record(r.parts || '—', `${r.created} · ${r.mechanic}`, r.notes);

        head.appendChild(make('span', null, money(r.total)));
        list.appendChild(item);
      });

      hist.appendChild(list);
      area.appendChild(hist);
    }
  });
}

async function mechanicHistorico(stage) {
  stage.appendChild(make('div', 'page-title', 'Histórico de consertos'));

  const box = make('div', 'record-list');
  const rows = (await call('nv_mdt:mechanic:history')) || [];

  const draw = () => {
    box.replaceChildren();

    if (rows.length === 0) {
      box.appendChild(make('div', 'empty-note', 'Nenhum conserto registrado.'));
      return;
    }

    const info = paginate(rows, 'mecHist');

    info.slice.forEach((r) => {
      const { item, head } = record(`${r.plate} — ${r.model || '?'}`,
        `${r.created} · ${r.mechanic} · cobrado de ${r.billedTo || '—'}`,
        `Peças: ${r.parts || '—'}${r.notes ? '\n' + r.notes : ''}`);

      head.appendChild(make('span', null, money(r.total)));
      box.appendChild(item);
    });

    pager(box, 'mecHist', info, draw);
  };

  draw();
  stage.appendChild(box);
}

// ========================================================== compartilhado ===

/**
 * Cartão de chamado, com rota para o local.
 *
 * O botão só aparece quando o chamado TEM posição: chamados registrados à mão
 * (a tela do hospital, por exemplo) não têm, e um botão que não faz nada é pior
 * do que botão nenhum — ele ensina que o botão não funciona.
 */
function callItem(c) {
  const node = make('div', `call-item ${c.priority || 'media'}`);
  const head = make('div', 'call-head');

  head.appendChild(make('div', 'call-title', c.title));

  if (c.x !== null && c.x !== undefined && c.y !== null && c.y !== undefined) {
    const mark = make('button', 'btn small', 'Marcar no mapa');

    mark.addEventListener('click', (e) => {
      e.stopPropagation();
      post('markMap', { x: c.x, y: c.y });
    });

    head.appendChild(mark);
  }

  node.appendChild(head);
  node.appendChild(make('div', 'call-meta', `${c.location || 'Sem local'} · ${c.created}`));

  return node;
}

/** Iniciais de um nome, para quando não há retrato. */
function initials(name) {
  return String(name || '?')
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0].toUpperCase())
    .join('');
}

/**
 * Avatar do efetivo: retrato do GTA quando disponível, iniciais quando não.
 *
 * O retrato só existe para quem está carregado no mundo — um colega do outro
 * lado do mapa não está em streaming. Por isso as iniciais não são um estado de
 * erro, são o caso comum, e precisam parecer intencionais.
 */
function avatarNode(name, url) {
  const box = make('div', 'staff-avatar');

  if (url) {
    const img = make('img');

    img.src = url;
    img.alt = name;
    /* Se a textura sumir entre o pedido e o desenho (o jogador saiu do
       streaming), volta para as iniciais em vez de deixar o ícone quebrado. */
    img.addEventListener('error', () => {
      box.replaceChildren(make('span', null, initials(name)));
    });

    box.appendChild(img);

    return box;
  }

  box.appendChild(make('span', null, initials(name)));

  return box;
}

const STATUS_LABEL = {
  servico: 'Em serviço',
  fora: 'Fora de serviço',
  offline: 'Fora de serviço'
};

async function renderDashboard(stage, subtype) {
  stage.appendChild(make('div', 'page-title', 'Dashboard'));

  const data = await call('nv_mdt:dashboard', subtype);
  const wrap = make('div', 'dash-grid');
  const left = make('div');
  const right = make('div');

  left.appendChild(make('div', 'dash-col-title', 'Últimos chamados'));
  right.appendChild(make('div', 'dash-col-title', 'Em serviço agora'));

  const calls = (data && data.calls) || [];

  if (calls.length === 0) {
    left.appendChild(make('div', 'empty-note', 'Nenhum chamado registrado.'));
  } else {
    calls.forEach((c) => left.appendChild(callItem(c)));
  }

  const online = (data && data.online) || [];

  if (online.length === 0) {
    right.appendChild(make('div', 'empty-note', 'Ninguém em serviço.'));
  } else {
    online.forEach((p) => {
      const row = make('div', 'online-item');
      const name = make('span');

      name.appendChild(make('span', 'online-dot'));
      name.appendChild(document.createTextNode(p.name));
      row.append(name, make('span', 'muted', p.coords ? 'em serviço' : '—'));
      right.appendChild(row);
    });
  }

  wrap.append(left, right);
  stage.appendChild(wrap);
}

async function renderStaff(stage, subtype) {
  stage.appendChild(make('div', 'page-title', 'Efetivo'));

  const rows = (await call('nv_mdt:staff', subtype)) || [];
  const box = make('div', 'staff-list');

  if (rows.length === 0) {
    box.appendChild(make('div', 'empty-note', 'Nenhum membro.'));
    stage.appendChild(box);
    return;
  }

  /* Um pedido só para todos os retratos: cada `RegisterPedheadshot` custa um
     handle e o jogo tem poucos. Pedir de dentro do laço esgotaria o limite na
     primeira corporação com mais de uma dúzia de membros. */
  const ids = rows.filter((r) => r.source).map((r) => r.source);
  const photos = ids.length > 0 ? (await post('headshots', { ids })) || {} : {};

  const draw = () => {
    box.replaceChildren();

    const info = paginate(rows, 'staff');

    info.slice.forEach((s) => {
      const row = make('div', `staff-item ${s.status || 'offline'}`);

      row.appendChild(avatarNode(s.name, photos[String(s.source)]));

      const text = make('div', 'staff-text');

      text.appendChild(make('div', 'staff-name', s.name));
      text.appendChild(make('div', 'staff-rank', s.rank_label || `Cargo ${s.grade}`));
      row.appendChild(text);

      const tags = make('div', 'staff-tags');

      tags.appendChild(make('span', `badge ${s.status === 'servico' ? 'ok' : 'muted-badge'}`,
        STATUS_LABEL[s.status] || 'Fora de serviço'));

      /* A frequência acompanha o status porque é a informação que se procura
         junto: saber que alguém está de serviço sem saber em que canal chamá-lo
         obriga a uma segunda pergunta. */
      if (s.radio) {
        tags.appendChild(make('span', 'badge radio', `${Number(s.radio).toFixed(1)} MHz`));
      } else if (s.status === 'servico') {
        tags.appendChild(make('span', 'badge muted-badge', 'Sem rádio'));
      }

      row.appendChild(tags);
      box.appendChild(row);
    });

    pager(box, 'staff', info, draw);
  };

  draw();
  stage.appendChild(box);
}

// ================================================================ roteador ===

const ROUTES = {
  policia: {
    nav: POLICE_NAV,
    pages: {
      dashboard: policeDashboard,
      ocorrencias: policeOcorrencias,
      cidadao: policeCidadao,
      procurados: policeProcurados,
      veiculos: policeVeiculos,
      faturas: policeFaturas,
      armas: policeArmas,
      documentos: policeDocumentos,
      mapa: policeMapa,
      cameras: policeCameras,
      comandos: policeComandos
    }
  },
  hospital: {
    nav: HOSPITAL_NAV,
    pages: {
      dashboard: hospitalDashboard,
      chamados: hospitalChamados,
      paciente: hospitalPaciente,
      consulta: hospitalConsulta,
      historico: hospitalHistorico,
      comandos: (stage) => renderStaff(stage, 'hospital')
    }
  },
  mecanica: {
    nav: MECHANIC_NAV,
    pages: {
      dashboard: mechanicDashboard,
      veiculos: mechanicVeiculos,
      historico: mechanicHistorico,
      comandos: (stage) => renderStaff(stage, 'mecanica')
    }
  }
};

const NAV_ICONS = {
  ocorrencias: 'report', cidadao: 'user', procurados: 'wanted', veiculos: 'car',
  faturas: 'invoice', armas: 'weapon', documentos: 'document', comandos: 'team',
  chamados: 'call', paciente: 'user', consulta: 'report', cameras: 'camera'
};

function renderNav() {
  const route = ROUTES[state.dept.id];

  dom.nav.replaceChildren();

  route.nav.forEach((item) => {
    const node = make('div', 'nav-item');
    node.appendChild(icon(ICONS[item.icon || NAV_ICONS[item.id] || item.id] || ICONS.document));
    node.appendChild(make('span', null, item.label));

    node.classList.toggle('active', item.id === state.page);
    node.addEventListener('click', () => go(item.id));
    dom.nav.appendChild(node);
  });
}

async function go(pageId) {
  /* Sair da página de ocorrências fecha o formulário. Sem isto, ir ao Cidadão e
     voltar traria de volta um formulário meio preenchido que ninguém pediu — o
     estado sobreviveria à intenção que o criou. */
  if (pageId !== 'ocorrencias') state.ctx.reportForm = false;

  state.page = pageId;
  renderNav();

  dom.stage.replaceChildren();

  const page = ROUTES[state.dept.id].pages[pageId];

  if (!page) return;

  try {
    await page(dom.stage);
  } catch (err) {
    dom.stage.appendChild(make('div', 'empty-note',
      'Não foi possível carregar esta página.'));
  }
}

function selectDept(tab) {
  state.dept = tab;
  document.body.dataset.dept = tab.id;
  state.ctx = {};

  dom.deptTabs.querySelectorAll('.dept-tab').forEach((t) => {
    t.classList.toggle('active', t.dataset.id === tab.id);
  });
  dom.deptTabs.classList.add('hidden');

  dom.sideTitle.textContent = `MDT — ${tab.label}`;
  dom.sideSub.textContent = tab.org || '';

  go('dashboard');
}

function renderTabs() {
  dom.deptTabs.replaceChildren();

  state.tabs.forEach((tab) => {
    const node = make('div', 'dept-tab');

    node.dataset.id = tab.id;
    node.appendChild(icon(ICONS[tab.icon] || ICONS.shield));
    node.appendChild(make('span', null, tab.label));
    node.addEventListener('click', () => selectDept(tab));

    dom.deptTabs.appendChild(node);
  });

  dom.deptSwitch.classList.toggle('hidden', state.tabs.length < 2);
}

// ---------------------------------------------------------------- eventos --

function close() {
  if (dom.root.classList.contains('hidden')) return;

  dom.root.classList.add('hidden');
  post('close');
}

dom.close.addEventListener('click', close);
dom.deptSwitch.addEventListener('click', (event) => {
  event.stopPropagation();
  dom.deptTabs.classList.toggle('hidden');
});
document.addEventListener('click', () => {
  dom.deptTabs.classList.add('hidden');
  document.querySelectorAll('.action-menu.open').forEach((menu) => menu.classList.remove('open'));
});
window.addEventListener('keydown', (e) => { if (e.key === 'Escape') close(); });

window.addEventListener('message', (event) => {
  const data = event.data;

  if (!data || typeof data.action !== 'string') return;

  if (data.action === 'close') {
    dom.root.classList.add('hidden');
    return;
  }

  if (data.action !== 'open') return;

  state.tabs = Array.isArray(data.tabs) ? data.tabs : [];
  state.cfg = data.config || {};

  Object.keys(PAGE_KEYS).forEach((k) => { PAGE_KEYS[k] = 0; });

  renderTabs();
  dom.root.classList.remove('hidden');

  if (state.tabs.length > 0) selectDept(state.tabs[0]);
});
