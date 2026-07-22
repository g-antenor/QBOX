/* ==========================================================================
   nv_orgs — painel

   A tela nao decide nada: desenha o que o servidor manda e devolve cliques.
   Toda validacao que importa (admin, set unico, limites) e refeita no
   servidor, porque qualquer coisa daqui pode ser forjada.

   A lista de cargos e sempre 1 = mais alto. A conversao para o grade do
   ox_core (que e o inverso) acontece no servidor, em `Orgs.positionToGrade`.
   ========================================================================== */

document.documentElement.style.backgroundColor = 'transparent';
document.body.style.backgroundColor = 'transparent';

const resource = (typeof GetParentResourceName === 'function')
  ? GetParentResourceName()
  : 'nv_orgs';

const el = (id) => document.getElementById(id);

const dom = {
  tablet: el('tablet'),
  subtitle: el('subtitle'),
  close: el('close'),
  list: el('list'),
  listEmpty: el('listEmpty'),
  newBtn: el('new'),
  placeholder: el('placeholder'),
  editor: el('editor'),
  tabMembers: el('tabMembers'),
  fLabel: el('fLabel'),
  fSet: el('fSet'),
  setHint: el('setHint'),
  fStyle: el('fStyle'),
  subtypeField: el('subtypeField'),
  fSubtype: el('fSubtype'),
  grades: el('grades'),
  addGrade: el('addGrade'),
  fSearch: el('fSearch'),
  results: el('results'),
  members: el('members'),
  membersEmpty: el('membersEmpty'),
  status: el('status'),
  save: el('save'),
  remove: el('remove'),
  tabResources: el('tabResources'),
  addDoors: el('addDoors'),
  genKey: el('genKey'),
  doors: el('doors'),
  doorsEmpty: el('doorsEmpty'),
  stashes: el('stashes'),
  newContact: el('newContact'),
  contacts: el('contacts'),
  contactsEmpty: el('contactsEmpty'),
  addMember: el('addMember'),
  addStash: el('addStash'),
  stashesEmpty: el('stashesEmpty'),
  placePed: el('placePed'),
  garagePed: el('garagePed'),
  addSpawns: el('addSpawns'),
  spawns: el('spawns'),
  spawnsEmpty: el('spawnsEmpty'),
  addFleet: el('addFleet'),
  fleet: el('fleet'),
  fleetEmpty: el('fleetEmpty'),
  dealershipResource: el('dealershipResource'),
  dealershipPoints: el('dealershipPoints'),
  dealershipEmpty: el('dealershipEmpty'),
  dealershipCategories: el('dealershipCategories'),
  dealershipCategoriesEmpty: el('dealershipCategoriesEmpty'),
  setDealershipPoint: el('setDealershipPoint'),
  setDealershipBlip: el('setDealershipBlip'),
  setDealershipCategories: el('setDealershipCategories'),
  buyDealershipTablet: el('buyDealershipTablet'),
  doorsResource: el('doorsResource'),
  garageResource: el('garageResource'),
  wardrobeResource: el('wardrobeResource'),
  contactResource: el('contactResource'),
  stashResource: el('stashResource'),
  craftResource: el('craftResource'),placeCraft:el('placeCraft'),craftProject:el('craftProject'),craftEmpty:el('craftEmpty'),
  dutyResource: el('dutyResource'), placeDutyPoint: el('placeDutyPoint'), placeServicePed: el('placeServicePed'), dutyPointsList: el('dutyPointsList'),
  addWardrobe: el('addWardrobe'),
  wardrobes: el('wardrobes'),
  wardrobesEmpty: el('wardrobesEmpty'),
  saveOutfit: el('saveOutfit'),
  outfits: el('outfits'),
  outfitsEmpty: el('outfitsEmpty')
};

// Baus nao tem lista fixa: sao criados um a um, e cada um guarda quantos
// cargos do topo o abrem.

const state = {
  list: [],
  styles: [],
  subtypes: {},
  actions: [],
  limits: { maxGrades: 12, setMin: 3, setMax: 20, labelMax: 50, searchMin: 2 },
  /** null = criando uma nova; string = editando esse set. */
  editing: null,
  draft: null,
  members: [],
  doors: [],
  contacts: [],
  stashes: [],
  spawns: [],
  fleet: [],
  garagePed: null,
  wardrobes: [],
  outfits: [],
  mechanicLifts: [],
  craftProject:null,
  busy: false,
  searchTimer: null
};

// ------------------------------------------------------------ paginacao --

/** Acima disto a lista ganha paginas. */
const PAGE_SIZE = 5;

/** Pagina atual de cada lista. Fora do `state` porque e estado de TELA, e nao
 *  dado: recarregar a lista nao deve jogar o admin de volta para a pagina 1. */
const pages = { list: 0, members: 0, doors: 0, contacts: 0, stashes: 0, spawns: 0, fleet: 0, wardrobes: 0, outfits: 0 };

/**
 * Recorta a fatia visivel de uma lista.
 * Corrige a pagina para tras quando a lista encolhe -- remover o unico item da
 * ultima pagina deixaria a tela vazia sem explicacao.
 */
function paginate(items, key) {
  const total = Math.max(1, Math.ceil(items.length / PAGE_SIZE));

  if (pages[key] > total - 1) pages[key] = total - 1;

  const start = pages[key] * PAGE_SIZE;

  return { slice: items.slice(start, start + PAGE_SIZE), page: pages[key], total };
}

/** Barra de paginas. Nao aparece quando tudo cabe numa pagina so. */
function appendPager(container, key, info, redraw) {
  if (info.total <= 1) return;

  const bar = make('div', 'pager');

  const prev = make('button', 'mini', '‹');
  prev.type = 'button';
  prev.disabled = info.page === 0;
  prev.title = 'Pagina anterior';
  prev.addEventListener('click', () => { pages[key] -= 1; redraw(); });

  const next = make('button', 'mini', '›');
  next.type = 'button';
  next.disabled = info.page >= info.total - 1;
  next.title = 'Proxima pagina';
  next.addEventListener('click', () => { pages[key] += 1; redraw(); });

  bar.append(prev, make('span', 'pager-label', `${info.page + 1} / ${info.total}`), next);
  container.appendChild(bar);
}

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

function make(tag, className, text) {
  const node = document.createElement(tag);

  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;

  return node;
}

function setStatus(text, kind) {
  dom.status.textContent = text;
  dom.status.className = `status${kind ? ' ' + kind : ''}`;
}

function styleLabel(value) {
  const found = state.styles.find((s) => s.value === value);

  return found ? found.label : value;
}

/** Rotulo do subtipo, ou vazio se o estilo nao tem ou nada foi escolhido. */
function subtypeLabel(style, subtype) {
  if (!subtype) return '';

  const list = state.subtypes[style];

  if (!Array.isArray(list)) return '';

  const found = list.find((s) => s.value === subtype);

  return found ? found.label : '';
}

/** Papel bancario deduzido da posicao — espelha Config.Grades.accountRoles. */
function roleFor(position) {
  if (position === 1) return 'owner (acesso total ao caixa)';
  if (position === 2) return 'manager (saca e deposita)';
  return 'contributor (so deposita)';
}

// ------------------------------------------------------------------ lista --

function renderList() {
  dom.list.replaceChildren();
  dom.listEmpty.classList.toggle('hidden', state.list.length > 0);

  const info = paginate(state.list, 'list');

  info.slice.forEach((org) => {
    const card = make('div', 'org');

    card.classList.toggle('active', org.set_name === state.editing);
    card.appendChild(make('div', 'org-name', org.label));

    const meta = make('div', 'org-meta');

    meta.appendChild(make('span', 'set', org.set_name));
    meta.appendChild(make('span', null, subtypeLabel(org.style, org.subtype) || styleLabel(org.style)));
    meta.appendChild(make('span', null, `${org.members || 0} membro(s)`));

    if (org.balance !== null && org.balance !== undefined) {
      meta.appendChild(make('span', null, `$${Number(org.balance).toLocaleString('pt-BR')}`));
    }

    card.appendChild(meta);
    card.addEventListener('click', () => selectOrg(org.set_name));

    dom.list.appendChild(card);
  });

  appendPager(dom.list, 'list', info, renderList);
}

async function refreshList() {
  const list = await post('refresh');

  state.list = Array.isArray(list) ? list : [];
  renderList();
}

// ----------------------------------------------------------------- estilo --

/** Marca o botao do estilo atual, sem recriar nada. */
function markStyle(selected) {
  dom.fStyle.querySelectorAll('button').forEach((button) => {
    button.classList.toggle('active', button.dataset.value === selected);
  });
}

function renderStyles(selected) {
  dom.fStyle.replaceChildren();

  state.styles.forEach((style) => {
    // Sem classe propria: o CSS estiliza por `.seg button`.
    const button = make('button', null, style.label);

    button.type = 'button';
    button.dataset.value = style.value;
    button.classList.toggle('active', style.value === selected);

    // Apenas troca as classes. Chamar `renderStyles` aqui destruia o proprio
    // botao no meio do clique, e o estilo selecionado se perdia -- so o
    // primeiro da lista parecia funcionar, porque ele ja estava marcado.
    button.addEventListener('click', () => {
      if (state.draft.style === style.value) return;

      state.draft.style = style.value;
      markStyle(style.value);

      // O subtipo pertence ao estilo. Ao trocar, o antigo deixa de valer
      // (uma estatal virou gang: "policia" nao existe mais ali), entao ele e
      // zerado e o controle e redesenhado para o novo estilo.
      state.draft.subtype = null;
      renderSubtype();

      // Trocar o estilo muda quais acoes existem. As que deixaram de valer
      // saem do rascunho na hora: mante-las marcadas por baixo faria a tela
      // mostrar uma coisa e o servidor gravar outra.
      pruneActions();
      renderGrades();
    });

    dom.fStyle.appendChild(button);
  });
}

/** Subtipos do estilo atual, ou lista vazia se ele nao tem. */
function subtypesForStyle() {
  const list = state.subtypes[state.draft ? state.draft.style : ''];

  return Array.isArray(list) ? list : [];
}

/** Desenha o seletor de subtipo, ou o esconde quando o estilo nao tem. */
function renderSubtype() {
  const list = subtypesForStyle();

  // Estilo sem subtipo: o campo some inteiro, para nao deixar um controle
  // vazio ocupando espaco.
  dom.subtypeField.classList.toggle('hidden', list.length === 0);

  dom.fSubtype.replaceChildren();

  if (list.length === 0) return;

  list.forEach((sub) => {
    const button = make('button', null, sub.label);

    button.type = 'button';
    button.dataset.value = sub.value;
    button.classList.toggle('active', sub.value === state.draft.subtype);

    button.addEventListener('click', () => {
      // Clicar no que ja esta ativo desmarca: subtipo e opcional.
      state.draft.subtype = state.draft.subtype === sub.value ? null : sub.value;
      markSubtype();
    });

    dom.fSubtype.appendChild(button);
  });
}

/** Marca o botao do subtipo atual, sem recriar (mesmo motivo do estilo). */
function markSubtype() {
  dom.fSubtype.querySelectorAll('button').forEach((button) => {
    button.classList.toggle('active', button.dataset.value === state.draft.subtype);
  });
}

// ----------------------------------------------------------------- cargos --

/** Acoes visiveis para o estilo escolhido: as comuns mais as exclusivas. */
function actionsForStyle() {
  const style = state.draft ? state.draft.style : null;

  return state.actions.filter((action) => {
    // Sem `styles` a acao vale para todos os estilos.
    if (!Array.isArray(action.styles)) return true;

    return action.styles.includes(style);
  });
}

/** Tira do rascunho as acoes que o estilo atual nao aceita. */
function pruneActions() {
  const allowed = new Set(actionsForStyle().map((a) => a.value));

  state.draft.grades.forEach((grade) => {
    grade.actions = (grade.actions || []).filter((a) => allowed.has(a));
  });
}

function renderGrades() {
  dom.grades.replaceChildren();

  const total = state.draft.grades.length;

  state.draft.grades.forEach((grade, index) => {
    const position = index + 1;
    const row = make('div', 'grade');
    const top = make('div', 'grade-top');

    top.appendChild(make('span', 'grade-pos', String(position)));

    const input = document.createElement('input');

    input.type = 'text';
    input.maxLength = 50;
    input.value = grade.label || '';
    input.placeholder = 'Nome do cargo';
    input.addEventListener('input', () => { grade.label = input.value; });
    top.appendChild(input);

    // Subir / descer mudam a hierarquia, entao redesenham tudo: a posicao e o
    // papel bancario de todos os cargos abaixo mudam junto.
    const up = make('button', 'mini', '↑');
    up.type = 'button';
    up.disabled = index === 0;
    up.title = 'Subir';
    up.addEventListener('click', () => moveGrade(index, -1));

    const down = make('button', 'mini', '↓');
    down.type = 'button';
    down.disabled = index === total - 1;
    down.title = 'Descer';
    down.addEventListener('click', () => moveGrade(index, 1));

    const del = make('button', 'mini danger', '✕');
    del.type = 'button';
    del.disabled = total <= 1;
    del.title = 'Remover cargo';
    del.addEventListener('click', () => {
      state.draft.grades.splice(index, 1);
      renderGrades();
    });

    top.append(up, down, del);
    row.appendChild(top);

    const actions = make('div', 'grade-actions');

    actionsForStyle().forEach((action) => {
      const label = make('label', 'check');
      const box = document.createElement('input');

      box.type = 'checkbox';
      box.checked = (grade.actions || []).includes(action.value);
      box.addEventListener('change', () => {
        grade.actions = grade.actions || [];

        if (box.checked) {
          if (!grade.actions.includes(action.value)) grade.actions.push(action.value);
        } else {
          grade.actions = grade.actions.filter((a) => a !== action.value);
        }
      });

      label.appendChild(box);
      label.appendChild(make('span', null, action.label));
      actions.appendChild(label);
    });

    row.appendChild(actions);
    row.appendChild(make('div', 'role-hint', `Caixa: ${roleFor(position)}`));

    dom.grades.appendChild(row);
  });

  dom.addGrade.disabled = total >= state.limits.maxGrades;
}

function moveGrade(index, delta) {
  const target = index + delta;
  const grades = state.draft.grades;

  if (target < 0 || target >= grades.length) return;

  [grades[index], grades[target]] = [grades[target], grades[index]];
  renderGrades();
}

// ---------------------------------------------------------------- editor --

function showEditor(show) {
  dom.editor.classList.toggle('hidden', !show);
  dom.placeholder.classList.toggle('hidden', show);
  dom.save.classList.toggle('hidden', !show);
  dom.remove.classList.toggle('hidden', !show || !state.editing);

  // Membros e recursos so existem para uma organizacao ja criada: nao da para
  // contratar nem posicionar bau de algo que ainda nao tem set no banco.
  dom.tabMembers.classList.toggle('hidden', !state.editing);
  dom.tabResources.classList.toggle('hidden', !state.editing);
}

function fillEditor() {
  dom.fLabel.value = state.draft.label || '';
  dom.fSet.value = state.draft.set || '';

  // O set e a chave primaria e vira principal do ACE; mudar depois quebraria
  // character_groups, portas e targets que ja apontam para ele.
  dom.fSet.disabled = Boolean(state.editing);
  dom.setHint.textContent = state.editing ? '(nao pode mudar)' : '(nao muda depois de criado)';

  renderStyles(state.draft.style);
  renderSubtype();
  renderGrades();
  showEditor(true);
  switchTab('config');
}

function newOrg() {
  state.editing = null;
  state.draft = {
    set: '',
    label: '',
    style: state.styles[0] ? state.styles[0].value : 'job',
    subtype: null,
    grades: [{ label: '', actions: [] }]
  };

  renderList();
  fillEditor();
  setStatus('Preencha os campos e salve.');
  dom.fLabel.focus();
}

async function selectOrg(set) {
  const org = await post('get', { set });

  if (!org) return setStatus('Nao foi possivel carregar a organizacao.', 'error');

  state.editing = set;
  state.draft = {
    set: org.set_name,
    label: org.label,
    style: org.style,
    subtype: org.subtype || null,
    grades: (org.grades || []).map((g) => ({ label: g.label, actions: g.actions || [] }))
  };

  if (state.draft.grades.length === 0) state.draft.grades.push({ label: '', actions: [] });

  renderList();
  fillEditor();
  loadMembers();
  setStatus(`Editando ${org.label}.`);
}

// ------------------------------------------------------------------ abas --

function switchTab(name) {
  document.querySelectorAll('.tab').forEach((tab) => {
    tab.classList.toggle('active', tab.dataset.tab === name);
  });

  document.querySelectorAll('.tab-body').forEach((body) => {
    body.classList.toggle('hidden', body.dataset.body !== name);
  });
}

document.querySelectorAll('.tab').forEach((tab) => {
  tab.addEventListener('click', () => {
    switchTab(tab.dataset.tab);

    // Recursos sao consultados na hora de abrir a aba, e nao junto com o
    // resto: portas e baus mudam por fora (pelo /doorlock, por outro admin) e
    // um dado velho aqui viraria um clique em algo que nao existe mais.
    if (tab.dataset.tab === 'resources') loadResources();
  });
});

// --------------------------------------------------------------- membros --

async function loadMembers() {
  if (!state.editing) return;

  const members = await post('members', { set: state.editing });

  state.members = Array.isArray(members) ? members : [];
  renderMembers();
}

function renderMembers() {
  dom.members.replaceChildren();
  dom.membersEmpty.classList.toggle('hidden', state.members.length > 0);

  const total = state.draft.grades.length;
  const info = paginate(state.members, 'members');

  info.slice.forEach((member) => {
    const row = make('div', 'member');
    const dot = make('span', `online${member.online ? ' on' : ''}`);

    dot.title = member.online ? 'Online' : 'Offline';
    row.appendChild(dot);

    const name = make('div', 'member-name', member.fullName);

    name.appendChild(make('em', null, member.stateId));
    row.appendChild(name);

    const select = document.createElement('select');

    for (let position = 1; position <= total; position += 1) {
      const option = document.createElement('option');

      option.value = String(position);
      option.textContent = `${position}. ${state.draft.grades[position - 1].label || 'Sem nome'}`;
      option.selected = position === member.position;
      select.appendChild(option);
    }

    select.addEventListener('change', async () => {
      const result = await post('setGrade', {
        set: state.editing,
        charId: member.charId,
        position: Number(select.value)
      });

      if (result && result.ok) loadMembers();
      else loadMembers();
    });

    row.appendChild(select);

    const fire = make('button', 'mini danger', '✕');

    fire.type = 'button';
    fire.title = 'Demitir';
    fire.addEventListener('click', async () => {
      const result = await post('fire', { set: state.editing, charId: member.charId });

      if (result && result.ok) {
        loadMembers();
        refreshList();
      }
    });

    row.appendChild(fire);
    dom.members.appendChild(row);
  });

  appendPager(dom.members, 'members', info, renderMembers);
}

function hideResults() {
  dom.results.classList.add('hidden');
  dom.results.replaceChildren();
}

async function runSearch(query) {
  if (!state.editing) return hideResults();

  // Numero e busca por ID, e ID pode ter um digito so. O minimo geral (2)
  // fazia "1" nem sair da tela -- o servidor ja aceitava, mas a chamada nunca
  // acontecia. O "#" e aceito porque e assim que o ID aparece na maioria das
  // telas de admin.
  const bare = query.replace(/^#/, '');
  const minimum = /^\d+$/.test(bare) ? 1 : state.limits.searchMin;

  if (bare.length < minimum) return hideResults();

  const results = await post('search', { set: state.editing, query });

  dom.results.replaceChildren();

  if (!Array.isArray(results) || results.length === 0) {
    hideResults();
    return;
  }

  results.forEach((character) => {
    const item = make('div', 'result', character.fullName);

    // ID e stateId sao coisas diferentes e as duas servem para achar alguem;
    // mostrar as duas evita a busca por ID parecer que nao funcionou.
    item.appendChild(make('span', null, `#${character.charId} · ${character.stateId}`));
    item.addEventListener('mousedown', async (event) => {
      event.preventDefault();

      const result = await post('hire', { set: state.editing, charId: character.charId });

      if (result && result.ok) {
        dom.fSearch.value = '';
        hideResults();
        loadMembers();
        refreshList();
      }
    });

    dom.results.appendChild(item);
  });

  dom.results.classList.remove('hidden');
}

dom.fSearch.addEventListener('input', () => {
  clearTimeout(state.searchTimer);

  const query = dom.fSearch.value.trim();

  // Debounce: sem isso cada tecla vira uma consulta ao banco.
  state.searchTimer = setTimeout(() => runSearch(query), 250);
});

dom.fSearch.addEventListener('blur', () => setTimeout(hideResults, 150));

// O campo de busca sozinho nao dizia que era ali que se contrata. O botao dá
// o ponto de partida; a busca continua sendo o mecanismo.
dom.addMember.addEventListener('click', () => {
  dom.fSearch.focus();
  setStatus(`Digite ao menos ${state.limits.searchMin} letras do nome ou o ID do personagem.`);
});

// -------------------------------------------------------------- recursos --

async function loadResources() {
  if (!state.editing) return;

  const doors = await post('doors', { set: state.editing });
  const stashes = await post('stashList', { set: state.editing });
  const contacts = await post('contacts', { set: state.editing });
  const garage = await post('garage', { set: state.editing });
  const wardrobe = await post('wardrobe', { set: state.editing });
  const dealership = state.draft && state.draft.subtype === 'dealership'
    ? await post('dealership', { set: state.editing }) : null;
  const craftProject=state.draft?await post('craftProject',{set:state.editing}):null;

  renderDoors(Array.isArray(doors) ? doors : []);
  renderStashes(Array.isArray(stashes) ? stashes : []);
  renderContacts(Array.isArray(contacts) ? contacts : []);
  renderGarage(garage && typeof garage === 'object' ? garage : null);
  renderWardrobe(wardrobe && typeof wardrobe === 'object' ? wardrobe : null);
  renderDealership(dealership);
  renderCraftProject(craftProject);
  renderDutyResource();
  applyResourceVisibility();
}

function applyResourceVisibility() {
  const style = state.draft ? state.draft.style : '';
  const subtype = state.draft ? state.draft.subtype : '';
  const rules = {
    dealership: ['doorsResource', 'dealershipResource', 'wardrobeResource','craftResource', 'dutyResource'],
    police: ['doorsResource', 'garageResource', 'wardrobeResource', 'contactResource', 'stashResource','craftResource', 'dutyResource'],
    hospital: ['doorsResource', 'garageResource', 'wardrobeResource', 'contactResource', 'stashResource','craftResource', 'dutyResource'],
    restaurant: ['doorsResource', 'wardrobeResource', 'contactResource', 'stashResource','craftResource', 'dutyResource'],
    mecanica: ['doorsResource', 'garageResource', 'wardrobeResource', 'contactResource', 'stashResource','craftResource', 'dutyResource'],
    custom: ['doorsResource', 'garageResource', 'wardrobeResource', 'contactResource', 'stashResource','craftResource', 'dutyResource'],
    drugs: ['doorsResource', 'garageResource', 'contactResource', 'stashResource','craftResource', 'dutyResource'],
    weapons: ['doorsResource', 'garageResource', 'contactResource', 'stashResource','craftResource', 'dutyResource']
  };
  const fallback = style === 'gang'
    ? ['doorsResource', 'garageResource', 'contactResource', 'stashResource','craftResource', 'dutyResource']
    : ['doorsResource', 'wardrobeResource', 'contactResource', 'stashResource','craftResource', 'dutyResource'];
  const visible = new Set(rules[subtype] || fallback);
  ['doorsResource', 'garageResource', 'dealershipResource', 'wardrobeResource', 'contactResource', 'stashResource','craftResource', 'dutyResource']
    .forEach((id) => dom[id].classList.toggle('hidden', !visible.has(id)));
}

async function renderDutyResource() {
  const data = (await post('getDutyData', { set: state.editing })) || {};
  dom.dutyPointsList.replaceChildren();

  if (!data.dutyPoint && !data.servicePed) {
    dom.dutyPointsList.appendChild(make('div', 'empty-note', 'Nenhum ponto ou PED de serviço configurado.'));
    return;
  }

  if (data.dutyPoint) {
    const item = make('div', 'res-item');
    item.appendChild(make('span', 'name', `Ponto de Serviço (Bater Ponto) · ${Number(data.dutyPoint.x).toFixed(2)}, ${Number(data.dutyPoint.y).toFixed(2)}, ${Number(data.dutyPoint.z).toFixed(2)}`));
    const del = make('button', 'icon danger', '×');
    del.onclick = async () => {
      const out = await post('removeDutyPoint', { set: state.editing });
      if (out?.ok) renderDutyResource();
    };
    item.appendChild(del);
    dom.dutyPointsList.appendChild(item);
  }

  if (data.servicePed) {
    const item = make('div', 'res-item');
    item.appendChild(make('span', 'name', `PED de Serviço (Atendimento) · ${Number(data.servicePed.x).toFixed(2)}, ${Number(data.servicePed.y).toFixed(2)}, ${Number(data.servicePed.z).toFixed(2)}`));
    const del = make('button', 'icon danger', '×');
    del.onclick = async () => {
      const out = await post('removeServicePed', { set: state.editing });
      if (out?.ok) renderDutyResource();
    };
    item.appendChild(del);
    dom.dutyPointsList.appendChild(item);
  }
}

function renderCraftProject(data){state.craftProject=data||null;dom.craftProject.replaceChildren();dom.craftEmpty.classList.toggle('hidden',!!data);if(!data)return;const item=make('div','res-item');item.appendChild(make('span','name',`${data.label} · ${Number(data.x).toFixed(2)}, ${Number(data.y).toFixed(2)} · ${data.prop?'com prop':'sem prop'}`));const del=make('button','icon danger','×');del.onclick=async()=>{const out=await post('deleteCraftProject',{set:state.editing});if(out?.ok)renderCraftProject(null)};item.appendChild(del);dom.craftProject.appendChild(item)}

const dealershipLabels = {
  payment: 'Local de pagamento', truckSpawn: 'Spawn do caminhao', invoiceNpc: 'Retirada da NF',
  trailerSpawn: 'Spawn do trailer', unload: 'Ponto de entrega', preview: 'Previa',
  saleSpawn: 'Spawn da compra', testSpawn: 'Spawn do test-drive', blip: 'Blip e area operacional'
};

function renderDealership(data) {
  const visible = state.draft && state.draft.subtype === 'dealership';
  dom.dealershipResource.classList.toggle('hidden', !visible);
  dom.dealershipPoints.replaceChildren();
  const points = data && data.points ? data.points : {};
  const categories = data && data.categories ? data.categories : {};
  const categoryNames = {
    compact: 'Compactos', sedan: 'Sedans', suv: 'SUVs', coupe: 'Coupes', muscle: 'Muscle',
    sportsclassic: 'Esportivos clássicos', sports: 'Esportivos', super: 'Super', motorcycle: 'Motos',
    offroad: 'Off-road', industrial: 'Industriais', utility: 'Utilitários', van: 'Vans', cycle: 'Bicicletas',
    boat: 'Barcos', helicopter: 'Helicópteros', plane: 'Aviões', service: 'Serviço', emergency: 'Emergência',
    military: 'Militares', commercial: 'Comerciais', train: 'Trens', openwheel: 'Fórmula',
    sport: 'Esportivos (legado)', moto: 'Motos (legado)'
  };
  dom.dealershipCategories.replaceChildren();
  Object.keys(categories).filter((key) => categories[key]).forEach((key) => {
    const item = make('div', 'res-item');
    item.appendChild(make('span', 'name', categoryNames[key] || key));
    const remove = make('button', 'icon danger', '×');
    remove.title = 'Remover categoria de novas compras';
    remove.addEventListener('click', async () => {
      await post('removeDealershipCategory', { set: state.editing, category: key });
      loadResources();
    });
    item.appendChild(remove);
    dom.dealershipCategories.appendChild(item);
  });
  dom.dealershipCategoriesEmpty.classList.toggle('hidden', dom.dealershipCategories.children.length > 0);
  Object.entries(points).forEach(([key, coords]) => {
    const item = make('div', 'res-item');
    item.appendChild(make('span', 'name', dealershipLabels[key] || key));
    item.appendChild(make('span', 'muted', key === 'blip'
      ? `${coords.label || 'Concessionaria'} · raio ${Number(coords.radius || 60)} m`
      : `${Number(coords.x).toFixed(1)}, ${Number(coords.y).toFixed(1)}, ${Number(coords.z).toFixed(1)}`));
    const remove = make('button', 'icon danger', '×');
    remove.title = 'Remover ponto';
    remove.addEventListener('click', async () => {
      await post('removeDealershipPoint', { set: state.editing, point: key });
      loadResources();
    });
    item.appendChild(remove);
    dom.dealershipPoints.appendChild(item);
  });
  dom.dealershipEmpty.classList.toggle('hidden', Object.keys(points).length > 0);
}

dom.setDealershipPoint.addEventListener('click', async () => {
  const result = await post('dealershipPoint', { set: state.editing });
  if (result && result.ok) loadResources();
});

dom.setDealershipBlip.addEventListener('click', async () => {
  const result = await post('dealershipBlip', { set: state.editing });
  if (result && result.ok) loadResources();
});

dom.setDealershipCategories.addEventListener('click', async () => {
  await post('dealershipCategories', { set: state.editing });
  loadResources();
});

dom.buyDealershipTablet.addEventListener('click', async () => {
  await post('buyDealershipTablet', { set: state.editing });
});

function renderContacts(contacts) {
  if (Array.isArray(contacts)) state.contacts = contacts;

  dom.contacts.replaceChildren();
  dom.contactsEmpty.classList.toggle('hidden', state.contacts.length > 0);

  const info = paginate(state.contacts, 'contacts');

  info.slice.forEach((contact) => {
    const item = make('div', 'res-item');

    // O ativo fica em destaque; os antigos ficam apagados, para a lista
    // deixar claro qual papel ainda vale.
    if (!contact.active) item.classList.add('faded');

    item.appendChild(make('span', 'name', contact.display || contact.number));
    item.appendChild(make('span', 'muted', contact.created || ''));
    item.appendChild(make('span', contact.active ? 'tag' : 'tag off',
      contact.active ? 'ativo' : 'inativo'));

    dom.contacts.appendChild(item);
  });

  appendPager(dom.contacts, 'contacts', info, renderContacts);
}

// ------------------------------------------------------- estacionamento --

function renderGarage(garage) {
  if (garage) {
    state.garagePed = garage.ped || null;
    state.spawns = Array.isArray(garage.spawns) ? garage.spawns : [];
    state.fleet = Array.isArray(garage.fleet) ? garage.fleet : [];
  }

  renderGaragePed();
  renderSpawns();
  renderFleet();
}

function renderGaragePed() {
  dom.garagePed.replaceChildren();

  const item = make('div', 'res-item');

  if (!state.garagePed) {
    item.appendChild(make('span', 'muted', 'Nenhum atendente posicionado.'));
    dom.garagePed.appendChild(item);
    return;
  }

  // O campo guarda "modelo x y z heading"; o admin so precisa ver o modelo.
  const model = String(state.garagePed).split(' ')[0];

  item.appendChild(make('span', 'name', model));
  item.appendChild(make('span', 'tag', 'posicionado'));

  const del = make('button', 'mini danger', '✕');

  del.type = 'button';
  del.title = 'Remover atendente';
  del.addEventListener('click', async () => {
    const result = await post('deleteGaragePed', { set: state.editing });

    if (result && result.ok) loadResources();
  });

  item.appendChild(del);
  dom.garagePed.appendChild(item);
}

function renderSpawns() {
  dom.spawns.replaceChildren();
  dom.spawnsEmpty.classList.toggle('hidden', state.spawns.length > 0);

  const info = paginate(state.spawns, 'spawns');

  info.slice.forEach((spawn, index) => {
    const item = make('div', 'res-item');
    const position = info.page * PAGE_SIZE + index + 1;
    const parts = String(spawn.coords).split(' ');

    item.appendChild(make('span', 'name', `Vaga ${position}`));
    item.appendChild(make('span', 'muted',
      `${Number(parts[0]).toFixed(0)}, ${Number(parts[1]).toFixed(0)}, ${Number(parts[2]).toFixed(0)}`));

    const del = make('button', 'mini danger', '✕');

    del.type = 'button';
    del.title = 'Remover vaga';
    del.addEventListener('click', async () => {
      const result = await post('deleteSpawn', { set: state.editing, id: spawn.id });

      if (result && result.ok) loadResources();
    });

    item.appendChild(del);
    dom.spawns.appendChild(item);
  });

  appendPager(dom.spawns, 'spawns', info, renderSpawns);
}

function renderFleet() {
  dom.fleet.replaceChildren();
  dom.fleetEmpty.classList.toggle('hidden', state.fleet.length > 0);

  const info = paginate(state.fleet, 'fleet');

  info.slice.forEach((car) => {
    const item = make('div', 'res-item');

    item.appendChild(make('span', 'name', car.label));
    item.appendChild(make('span', 'muted', car.model));
    item.appendChild(make('span', 'muted',
      car.price > 0 ? `$${Number(car.price).toLocaleString('pt-BR')}` : 'sem custo'));

    // "a partir do cargo N", dito com o nome que o admin acabou de dar.
    const grade = state.draft.grades[Number(car.minPosition) - 1];
    item.appendChild(make('span', 'muted',
      `ate ${grade ? grade.label || `cargo ${car.minPosition}` : `cargo ${car.minPosition}`}`));

    const edit = make('button', 'btn small', 'Editar');

    edit.type = 'button';
    edit.addEventListener('click', () => fleetDialog(car));

    const del = make('button', 'mini danger', '✕');

    del.type = 'button';
    del.title = 'Remover da frota';
    del.addEventListener('click', async () => {
      const result = await post('deleteFleet', { set: state.editing, id: car.id });

      if (result && result.ok) loadResources();
    });

    item.append(edit, del);
    dom.fleet.appendChild(item);
  });

  appendPager(dom.fleet, 'fleet', info, renderFleet);
}

/** Abre o dialogo de veiculo (novo ou edicao) pelo lado do Lua. */
async function fleetDialog(car) {
  const result = await post('fleetDialog', {
    set: state.editing,
    id: car ? car.id : null,
    model: car ? car.model : '',
    label: car ? car.label : '',
    price: car ? car.price : 0,
    minPosition: car ? car.minPosition : gradeTotal(),
    grades: gradeTotal()
  });

  if (result && result.ok) loadResources();
}

dom.placePed.addEventListener('click', () => {
  if (!state.editing) return;

  post('placeGaragePed', { set: state.editing });
});

dom.addSpawns.addEventListener('click', () => {
  if (!state.editing) return;

  post('placeSpawns', { set: state.editing });
});

dom.addFleet.addEventListener('click', () => fleetDialog(null));

dom.placeDutyPoint.addEventListener('click', () => {
  if (!state.editing) return;
  post('placeDutyPoint', { set: state.editing });
});

dom.placeServicePed.addEventListener('click', () => {
  if (!state.editing) return;
  post('placeServicePed', { set: state.editing });
});

// ------------------------------------------------------------ vestiario --

function renderWardrobe(data) {
  if (data) {
    state.wardrobes = Array.isArray(data.points) ? data.points : [];
    state.outfits = Array.isArray(data.outfits) ? data.outfits : [];
  }

  renderWardrobePoints();
  renderOutfits();
}

function renderWardrobePoints() {
  dom.wardrobes.replaceChildren();
  dom.wardrobesEmpty.classList.toggle('hidden', state.wardrobes.length > 0);

  const info = paginate(state.wardrobes, 'wardrobes');

  info.slice.forEach((point, index) => {
    const item = make('div', 'res-item');
    const number = info.page * PAGE_SIZE + index + 1;
    const parts = String(point.coords).split(' ');

    item.appendChild(make('span', 'name', `Ponto ${number}`));
    item.appendChild(make('span', 'muted',
      `${Number(parts[0]).toFixed(0)}, ${Number(parts[1]).toFixed(0)}, ${Number(parts[2]).toFixed(0)}`));

    const grade = state.draft.grades[Number(point.minPosition) - 1];
    item.appendChild(make('span', 'muted',
      `ate ${grade ? grade.label || `cargo ${point.minPosition}` : `cargo ${point.minPosition}`}`));

    const del = make('button', 'mini danger', '✕');

    del.type = 'button';
    del.title = 'Remover ponto';
    del.addEventListener('click', async () => {
      const result = await post('deleteWardrobe', { set: state.editing, id: point.id });

      if (result && result.ok) loadResources();
    });

    item.appendChild(del);
    dom.wardrobes.appendChild(item);
  });

  appendPager(dom.wardrobes, 'wardrobes', info, renderWardrobePoints);
}

/** Corpo legivel: o admin nao deveria precisar decorar nome de modelo. */
function bodyLabel(model) {
  if (model === 'mp_m_freemode_01') return 'masculino';
  if (model === 'mp_f_freemode_01') return 'feminino';

  return model;
}

function renderOutfits() {
  dom.outfits.replaceChildren();
  dom.outfitsEmpty.classList.toggle('hidden', state.outfits.length > 0);

  const info = paginate(state.outfits, 'outfits');

  info.slice.forEach((outfit) => {
    const item = make('div', 'res-item');

    item.appendChild(make('span', 'name', outfit.label));
    item.appendChild(make('span', 'muted', bodyLabel(outfit.model)));

    const grade = state.draft.grades[Number(outfit.minPosition) - 1];
    item.appendChild(make('span', 'muted',
      `ate ${grade ? grade.label || `cargo ${outfit.minPosition}` : `cargo ${outfit.minPosition}`}`));

    // Editar regrava com a roupa que o admin esta vestindo AGORA — e o mesmo
    // fluxo de salvar, so que reaproveitando o registro.
    const edit = make('button', 'btn small', 'Regravar');

    edit.type = 'button';
    edit.title = 'Salva a roupa que voce esta vestindo agora neste uniforme';
    edit.addEventListener('click', async () => {
      const result = await post('saveOutfit', {
        set: state.editing,
        id: outfit.id,
        label: outfit.label,
        minPosition: outfit.minPosition,
        grades: gradeTotal()
      });

      if (result && result.ok) loadResources();
    });

    const del = make('button', 'mini danger', '✕');

    del.type = 'button';
    del.title = 'Remover uniforme';
    del.addEventListener('click', async () => {
      const result = await post('deleteOutfit', { set: state.editing, id: outfit.id });

      if (result && result.ok) loadResources();
    });

    item.append(edit, del);
    dom.outfits.appendChild(item);
  });

  appendPager(dom.outfits, 'outfits', info, renderOutfits);
}

dom.addWardrobe.addEventListener('click', () => {
  if (!state.editing) return;

  post('placeWardrobe', { set: state.editing, grades: gradeTotal() });
});

dom.saveOutfit.addEventListener('click', async () => {
  if (!state.editing) return;

  const result = await post('saveOutfit', { set: state.editing, grades: gradeTotal() });

  if (result && result.ok) loadResources();
});

dom.newContact.addEventListener('click', async () => {
  if (!state.editing || state.busy) return;

  state.busy = true;
  dom.newContact.disabled = true;

  const result = await post('newContact', { set: state.editing });

  state.busy = false;
  dom.newContact.disabled = false;

  if (result && result.ok) loadResources();
});

function renderDoors(doors) {
  if (Array.isArray(doors)) state.doors = doors;

  dom.doors.replaceChildren();
  dom.doorsEmpty.classList.toggle('hidden', state.doors.length > 0);

  const info = paginate(state.doors, 'doors');

  info.slice.forEach((door) => {
    const item = make('div', 'res-item');

    item.appendChild(make('span', 'name', door.label || door.name));

    if (door.coords) {
      const c = door.coords;
      item.appendChild(make('span', 'muted',
        `${Number(c.x).toFixed(0)}, ${Number(c.y).toFixed(0)}, ${Number(c.z).toFixed(0)}`));
    }

    const rename = make('button', 'btn small', 'Renomear');

    rename.type = 'button';
    rename.addEventListener('click', async () => {
      const result = await post('renameDoor', {
        set: state.editing,
        id: door.id,
        label: door.label || ''
      });

      if (result && result.ok) loadResources();
    });

    const del = make('button', 'mini danger', '✕');

    del.type = 'button';
    del.title = 'Remover fechadura';
    del.addEventListener('click', async () => {
      const result = await post('deleteDoor', { set: state.editing, id: door.id });

      // A remocao no ox_doorlock e assincrona (net event + sync). Um respiro
      // antes de recarregar evita a lista voltar com a porta ainda nela.
      if (result && result.ok) setTimeout(loadResources, 400);
    });

    item.append(rename, del);
    dom.doors.appendChild(item);
  });

  appendPager(dom.doors, 'doors', info, renderDoors);
}

/** Quantos cargos a organizacao tem agora — limite do slider de acesso. */
function gradeTotal() {
  return state.draft ? state.draft.grades.length : 1;
}

function renderStashes(stashes) {
  if (Array.isArray(stashes)) state.stashes = stashes;

  dom.stashes.replaceChildren();
  dom.stashesEmpty.classList.toggle('hidden', state.stashes.length > 0);

  const info = paginate(state.stashes, 'stashes');

  info.slice.forEach((stash) => {
    const item = make('div', 'res-item');

    item.appendChild(make('span', 'name', stash.label));

    // "os N do topo" dito em cargos, e nao em numero solto: o admin acabou de
    // nomear esses cargos na aba ao lado.
    const position = Number(stash.minPosition) || 1;
    const names = state.draft.grades
      .slice(0, position)
      .map((g, i) => g.label || `Cargo ${i + 1}`)
      .join(', ');

    item.appendChild(make('span', 'muted', names || `${position} cargo(s)`));

    if (stash.management) item.appendChild(make('span', 'tag', 'gerencia'));

    const edit = make('button', 'btn small', 'Editar');

    edit.type = 'button';
    edit.addEventListener('click', () => {
      post('placeStash', {
        set: state.editing,
        slot: stash.slot,
        label: stash.label,
        minPosition: position,
        management: stash.management === true,
        grades: gradeTotal()
      });
    });

    const del = make('button', 'mini danger', '✕');

    del.type = 'button';
    del.title = 'Remover bau';
    del.addEventListener('click', async () => {
      const result = await post('deleteStash', { set: state.editing, slot: stash.slot });

      if (result && result.ok) loadResources();
    });

    item.append(edit, del);
    dom.stashes.appendChild(item);
  });

  appendPager(dom.stashes, 'stashes', info, renderStashes);
}

dom.addStash.addEventListener('click', () => {
  if (!state.editing) return;

  post('placeStash', { set: state.editing, grades: gradeTotal() });
});

dom.placeCraft.addEventListener('click',()=>{if(state.editing)post('placeCraftProject',{set:state.editing})});

dom.addDoors.addEventListener('click', () => {
  if (!state.editing) return;

  post('placeDoors', { set: state.editing });
});

dom.genKey.addEventListener('click', async () => {
  if (!state.editing || state.busy) return;

  state.busy = true;
  dom.genKey.disabled = true;

  // A chave vai para o inventario do admin, para ele distribuir aos membros —
  // mesmo fluxo do numero de contato.
  await post('genKey', { set: state.editing });

  state.busy = false;
  dom.genKey.disabled = false;
});

// --------------------------------------------------------------- salvar --

function collectDraft() {
  return {
    set: dom.fSet.value.trim().toLowerCase(),
    label: dom.fLabel.value.trim(),
    style: state.draft.style,
    subtype: state.draft.subtype || null,
    grades: state.draft.grades.map((g) => ({
      label: (g.label || '').trim(),
      actions: g.actions || []
    }))
  };
}

/** Espelha as validacoes do servidor, so para responder mais rapido. */
function localCheck(org) {
  if (!org.label) return 'Informe o nome da organizacao.';

  if (!state.editing) {
    if (org.set.length < state.limits.setMin || org.set.length > state.limits.setMax) {
      return `O set precisa ter entre ${state.limits.setMin} e ${state.limits.setMax} caracteres.`;
    }

    if (!/^[a-z][a-z0-9_]*$/.test(org.set)) {
      return 'O set aceita apenas letras minusculas, numeros e _, comecando por letra.';
    }
  }

  if (org.grades.some((g) => !g.label)) return 'Todos os cargos precisam de nome.';

  return null;
}

dom.save.addEventListener('click', async () => {
  if (state.busy) return;

  const org = collectDraft();
  const problem = localCheck(org);

  if (problem) return setStatus(problem, 'error');

  state.busy = true;
  dom.save.disabled = true;
  setStatus('Salvando...');

  const result = state.editing
    ? await post('update', { set: state.editing, org })
    : await post('create', { org });

  state.busy = false;
  dom.save.disabled = false;

  if (!result || !result.ok) {
    return setStatus(result && result.error ? result.error : 'Nao foi possivel salvar.', 'error');
  }

  const set = state.editing || result.value || org.set;

  await refreshList();
  await selectOrg(set);
  setStatus('Salvo.', 'ok');
});

dom.remove.addEventListener('click', async () => {
  if (state.busy || !state.editing) return;

  // Excluir apaga membros e cargos em cascata; vale uma confirmacao.
  if (dom.remove.dataset.armed !== '1') {
    dom.remove.dataset.armed = '1';
    dom.remove.textContent = 'Confirmar exclusao';
    setStatus('Clique de novo para confirmar.', 'error');

    setTimeout(() => {
      dom.remove.dataset.armed = '0';
      dom.remove.textContent = 'Excluir';
    }, 4000);

    return;
  }

  dom.remove.dataset.armed = '0';
  dom.remove.textContent = 'Excluir';
  state.busy = true;

  const result = await post('delete', { set: state.editing });

  state.busy = false;

  if (!result || !result.ok) {
    return setStatus(result && result.error ? result.error : 'Nao foi possivel excluir.', 'error');
  }

  state.editing = null;
  state.draft = null;
  showEditor(false);
  await refreshList();
  setStatus('Organizacao excluida.', 'ok');
});

dom.addGrade.addEventListener('click', () => {
  if (state.draft.grades.length >= state.limits.maxGrades) return;

  state.draft.grades.push({ label: '', actions: [] });
  renderGrades();
});

dom.newBtn.addEventListener('click', newOrg);

// --------------------------------------------------------------- eventos --

function close() {
  if (dom.tablet.classList.contains('hidden')) return;

  dom.tablet.classList.add('hidden');
  post('close');
}

dom.close.addEventListener('click', close);

window.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') close();
});

window.addEventListener('message', (event) => {
  const data = event.data;

  if (!data || typeof data.action !== 'string') return;

  if (data.action === 'close') {
    dom.tablet.classList.add('hidden');
    return;
  }

  if (data.action !== 'open') return;

  state.list = Array.isArray(data.list) ? data.list : [];
  state.styles = Array.isArray(data.styles) ? data.styles : [];
  state.subtypes = (data.subtypes && typeof data.subtypes === 'object') ? data.subtypes : {};
  state.actions = Array.isArray(data.actions) ? data.actions : [];
  state.limits = Object.assign(state.limits, data.limits || {});
  state.editing = null;
  state.draft = null;
  state.members = [];

  renderList();
  showEditor(false);
  hideResults();
  setStatus('Pronto.');
  dom.tablet.classList.remove('hidden');

  // O modo de posicionamento fecha o painel e o reabre; `select` faz a tela
  // voltar na mesma organizacao, na aba de recursos, em vez de jogar o admin
  // de volta na lista.
  if (typeof data.select === 'string') {
    selectOrg(data.select).then(() => {
      switchTab('resources');
      loadResources();
    });
  }
});
