/* nv_adminmenu — painel de administração.

   A tela não decide nada: envia a ação e o alvo, e o servidor revalida admin
   em cada uma. Roda ao lado do app.js do handling, na mesma NUI. */

(function () {
  'use strict';

  var resource = typeof GetParentResourceName === 'function'
    ? GetParentResourceName()
    : 'nv_adminmenu';

  var root = document.getElementById('admin');
  var tabsEl = document.getElementById('adminTabs');
  var contentEl = document.getElementById('adminContent');
  var statusEl = document.getElementById('adminStatus');
  var subEl = document.getElementById('adminSub');

  var state = {
    open: false,
    tab: 'jogador',
    players: [],
    items: [],
    vehicles: [],
    self: null,
    noclip: false,
    /* Alvo padrão das ações de item/veículo. `null` = eu mesmo. */
    target: null,
    itemQuery: '',
    vehicleQuery: '',
    playerQuery: '',
    /* Alinhador de props: espelho do estado que vive no client.lua. */
    props: { model: '', dict: '', anim: '', bone: 0, presets: [], saved: [] }
  };

  /* ------------------------------------------------------------ utils --- */

  function post(name, data) {
    return fetch('https://' + resource + '/' + name, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {})
    }).catch(function () {});
  }

  function el(tag, cls, text) {
    var node = document.createElement(tag);
    if (cls) node.className = cls;
    if (text !== undefined) node.textContent = text;
    return node;
  }

  function status(text, ok) {
    statusEl.textContent = text;
    statusEl.classList.toggle('ok', !!ok);
  }

  /** Botão de ação com título e explicação. */
  function card(title, hint, onClick, active) {
    var b = el('button', 'card' + (active ? ' on' : ''));
    b.type = 'button';
    b.appendChild(el('b', null, title));
    if (hint) b.appendChild(el('small', null, hint));
    b.addEventListener('click', onClick);
    return b;
  }

  function sectionTitle(text) {
    return el('div', 'section-title', text);
  }

  /** Id do alvo atual, ou o próprio admin. */
  function targetId() {
    return state.target || (state.self && state.self.id);
  }

  function targetName() {
    if (!state.target) return 'você';

    for (var i = 0; i < state.players.length; i++) {
      if (state.players[i].id === state.target) {
        return state.players[i].char || state.players[i].name;
      }
    }

    return 'id ' + state.target;
  }

  /* Seletor de alvo, reaproveitado por itens e veículos. Sem ele, "dar item"
     só serviria para si mesmo — que é o caso raro, não o comum. */
  function targetSelect() {
    var sel = el('select', 'select');

    var mine = el('option', null, 'Para mim');
    mine.value = '';
    sel.appendChild(mine);

    state.players.forEach(function (p) {
      if (state.self && p.id === state.self.id) return;

      var o = el('option', null, '[' + p.id + '] ' + (p.char || p.name));
      o.value = String(p.id);
      sel.appendChild(o);
    });

    sel.value = state.target ? String(state.target) : '';
    sel.addEventListener('change', function () {
      state.target = sel.value ? Number(sel.value) : null;
      status('Alvo: ' + targetName());
    });

    return sel;
  }

  /* ------------------------------------------------------------- abas --- */

  var TABS = [
    { id: 'jogador', label: 'Meu Personagem', hint: 'Noclip, vida, colete' },
    { id: 'jogadores', label: 'Jogadores', hint: 'Trazer, ir até, reviver' },
    { id: 'itens', label: 'Itens', hint: 'Buscar e entregar' },
    { id: 'veiculos', label: 'Veículos', hint: 'Spawn, reparar, registrar' },
    { id: 'mundo', label: 'Mundo', hint: 'Clima, hora, eventos' },
    { id: 'ferramentas', label: 'Ferramentas', hint: 'Coords, handling, orgs' },
    { id: 'props', label: 'Props', hint: 'Alinhar em ossos' },
    { id: 'comandos', label: 'Comandos', hint: 'Referência rápida' }
  ];

  function renderTabs() {
    tabsEl.innerHTML = '';

    TABS.forEach(function (tab) {
      var b = el('button', 'tab' + (tab.id === state.tab ? ' active' : ''));
      b.type = 'button';
      b.appendChild(document.createTextNode(tab.label));
      b.appendChild(el('small', null, tab.hint));
      b.addEventListener('click', function () {
        state.tab = tab.id;
        renderTabs();
        renderContent();
      });
      tabsEl.appendChild(b);
    });
  }

  /* -------------------------------------------------- aba: meu personagem */

  function renderSelf() {
    var grid = el('div', 'grid');

    grid.appendChild(card('Noclip', 'Voar pelo mapa', function () {
      post('panel_action', { action: 'noclip' });
    }, state.noclip));

    grid.appendChild(card('Reviver', 'Levanta e cura por completo', function () {
      post('panel_action', { action: 'revive' });
      status('Você foi revivido.', true);
    }));

    grid.appendChild(card('Curar', 'Vida cheia, sem limpar o sangue', function () {
      post('panel_action', { action: 'heal' });
      status('Vida restaurada.', true);
    }));

    grid.appendChild(card('Colete', 'Colete no máximo', function () {
      post('panel_action', { action: 'armour' });
      status('Colete equipado.', true);
    }));

    grid.appendChild(card('Invisível', 'Alterna a visibilidade do seu ped', function (e) {
      post('panel_action', { action: 'invisible' });
      e.currentTarget.classList.toggle('on');
    }));

    grid.appendChild(card('Modo Deus', 'Ignora dano', function (e) {
      post('panel_action', { action: 'godmode' });
      e.currentTarget.classList.toggle('on');
    }));

    grid.appendChild(card('Ir ao marcador', 'Teleporta para o waypoint do mapa', function () {
      post('panel_action', { action: 'waypoint' });
    }));

    grid.appendChild(card('Roupas / Ped', 'Abre o editor de aparência', function () {
      post('panel_action', { action: 'pedmenu' });
      close();
    }));

    contentEl.appendChild(sectionTitle('Ações rápidas'));
    contentEl.appendChild(grid);
  }

  /* ------------------------------------------------------ aba: jogadores */

  function renderPlayers() {
    var bar = el('div', 'toolbar');
    var search = el('input', 'search');

    search.type = 'text';
    search.placeholder = 'Buscar por nome ou id...';
    search.value = state.playerQuery;
    search.addEventListener('input', function () {
      state.playerQuery = search.value.trim().toLowerCase();
      renderContent(true);
    });

    bar.appendChild(search);
    contentEl.appendChild(bar);

    var list = el('div', 'list');
    var query = state.playerQuery;
    var found = 0;

    state.players.forEach(function (p) {
      var haystack = (p.name + ' ' + (p.char || '') + ' ' + p.id).toLowerCase();
      if (query && haystack.indexOf(query) === -1) return;

      found++;

      var row = el('div', 'item');
      var info = el('div', 'info');

      info.appendChild(el('b', null, p.char || p.name));
      info.appendChild(el('code', null, '[' + p.id + '] ' + p.name));
      row.appendChild(info);

      if (p.isSelf) row.appendChild(el('span', 'tag self', 'Você'));

      var actions = el('div', 'row-actions');

      [
        ['Trazer', 'bring'],
        ['Ir até', 'goto'],
        ['Reviver', 'revive'],
        ['Curar', 'heal'],
        ['Admin', 'admin']
      ].forEach(function (pair) {
        var b = el('button', 'mini', pair[0]);
        b.type = 'button';
        b.addEventListener('click', function (ev) {
          ev.stopPropagation();
          post('panel_player', { action: pair[1], target: p.id });
        });
        actions.appendChild(b);
      });

      var kill = el('button', 'mini danger', 'Matar');
      kill.type = 'button';
      kill.addEventListener('click', function (ev) {
        ev.stopPropagation();
        post('panel_player', { action: 'kill', target: p.id });
      });
      actions.appendChild(kill);

      row.appendChild(actions);

      /* Clicar na linha escolhe o alvo das outras abas: é o gesto natural
         depois de encontrar a pessoa na lista. */
      row.addEventListener('click', function () {
        state.target = p.isSelf ? null : p.id;
        status('Alvo: ' + targetName(), true);
      });

      list.appendChild(row);
    });

    if (!found) list.appendChild(el('div', 'empty', 'Nenhum jogador encontrado'));

    contentEl.appendChild(sectionTitle(state.players.length + ' jogador(es) online'));
    contentEl.appendChild(list);
  }

  /* ---------------------------------------------------------- aba: itens */

  function renderItems() {
    var note = el('div', 'note');
    note.innerHTML = 'Escolha o destinatário, digite a quantidade e clique no item. ' +
      'Armas e munições vêm marcadas — <b>clicar entrega na hora</b>.';
    contentEl.appendChild(note);

    var bar = el('div', 'toolbar');
    var search = el('input', 'search');

    search.type = 'text';
    search.placeholder = 'Buscar item por nome...';
    search.value = state.itemQuery;
    search.addEventListener('input', function () {
      state.itemQuery = search.value.trim().toLowerCase();
      renderContent(true);
    });

    var qty = el('input', 'qty');
    qty.type = 'number';
    qty.min = '1';
    qty.max = '1000';
    qty.value = state.qty || '1';
    qty.addEventListener('change', function () {
      state.qty = qty.value;
    });

    bar.appendChild(search);
    bar.appendChild(qty);
    bar.appendChild(targetSelect());
    contentEl.appendChild(bar);

    var list = el('div', 'list');
    var query = state.itemQuery;
    var shown = 0;

    for (var i = 0; i < state.items.length; i++) {
      var item = state.items[i];

      if (query) {
        var hay = (item.label + ' ' + item.name).toLowerCase();
        if (hay.indexOf(query) === -1) continue;
      }

      /* Teto de 60 linhas: o catálogo tem centenas de itens, e desenhar todos
         a cada tecla digitada trava a NUI. Quem não achou refina a busca. */
      if (shown >= 60) break;

      shown++;
      list.appendChild(buildItemRow(item, qty));
    }

    if (!shown) {
      list.appendChild(el('div', 'empty',
        query ? 'Nenhum item encontrado' : 'Catálogo vazio'));
    }

    contentEl.appendChild(sectionTitle('Catálogo do inventário'));
    contentEl.appendChild(list);
  }

  function buildItemRow(item, qtyInput) {
    var row = el('div', 'item');
    var info = el('div', 'info');

    info.appendChild(el('b', null, item.label));
    info.appendChild(el('code', null, item.name));
    row.appendChild(info);

    if (item.weapon) row.appendChild(el('span', 'tag weapon', 'Arma'));
    else if (item.ammo) row.appendChild(el('span', 'tag ammo', 'Munição'));

    row.addEventListener('click', function () {
      var count = Number(qtyInput.value) || 1;

      post('panel_give', { item: item.name, count: count, target: targetId() });
      status(count + 'x ' + item.label + ' → ' + targetName(), true);
    });

    return row;
  }

  /* ------------------------------------------------------- aba: veículos */

  function renderVehicles() {
    var grid = el('div', 'grid');

    grid.appendChild(card('Reparar', 'Conserta o veículo atual', function () {
      post('panel_action', { action: 'fix' });
      status('Veículo reparado.', true);
    }));

    grid.appendChild(card('Limpar', 'Tira a sujeira da lataria', function () {
      post('panel_action', { action: 'clean' });
    }));

    grid.appendChild(card('Apagar', 'Remove o veículo em que você está', function () {
      post('panel_action', { action: 'deleteVehicle' });
    }));

    contentEl.appendChild(sectionTitle('Veículo atual'));
    contentEl.appendChild(grid);

    var note = el('div', 'note');
    note.innerHTML = '<b>Spawn</b> cria o veículo aqui, temporário. ' +
      '<b>Registrar</b> coloca no nome do alvo, guardado na garagem mais próxima.';

    contentEl.appendChild(sectionTitle('Catálogo'));
    contentEl.appendChild(note);

    var bar = el('div', 'toolbar');
    var search = el('input', 'search');

    search.type = 'text';
    search.placeholder = 'Buscar por marca, nome ou modelo...';
    search.value = state.vehicleQuery;
    search.addEventListener('input', function () {
      state.vehicleQuery = search.value.trim().toLowerCase();
      renderContent(true);
    });

    bar.appendChild(search);
    bar.appendChild(targetSelect());
    contentEl.appendChild(bar);

    var list = el('div', 'list');
    var query = state.vehicleQuery;
    var shown = 0;

    for (var i = 0; i < state.vehicles.length; i++) {
      var veh = state.vehicles[i];

      if (query) {
        var hay = (veh.label + ' ' + veh.name).toLowerCase();
        if (hay.indexOf(query) === -1) continue;
      }

      if (shown >= 60) break;
      shown++;

      list.appendChild(buildVehicleRow(veh));
    }

    if (!shown) {
      list.appendChild(el('div', 'empty',
        query ? 'Nenhum veículo encontrado' : 'Digite para buscar'));
    }

    contentEl.appendChild(list);
  }

  function buildVehicleRow(veh) {
    var row = el('div', 'item');
    var info = el('div', 'info');

    info.appendChild(el('b', null, veh.label));
    info.appendChild(el('code', null, veh.name));
    row.appendChild(info);

    var actions = el('div', 'row-actions');

    var spawn = el('button', 'mini', 'Spawn');
    spawn.type = 'button';
    spawn.addEventListener('click', function (ev) {
      ev.stopPropagation();
      post('panel_action', { action: 'spawnVehicle', model: veh.name });
      status('Spawn: ' + veh.label, true);
    });

    var give = el('button', 'mini', 'Registrar');
    give.type = 'button';
    give.addEventListener('click', function (ev) {
      ev.stopPropagation();
      post('panel_vehicle', { model: veh.name, target: targetId() });
      status(veh.label + ' → ' + targetName(), true);
    });

    actions.appendChild(spawn);
    actions.appendChild(give);
    row.appendChild(actions);

    return row;
  }

  /* --------------------------------------------------------- aba: mundo */

  var WEATHER = [
    ['EXTRASUNNY', 'Sol forte'], ['CLEAR', 'Limpo'], ['CLOUDS', 'Nublado'],
    ['OVERCAST', 'Encoberto'], ['RAIN', 'Chuva'], ['THUNDER', 'Tempestade'],
    ['FOGGY', 'Neblina'], ['SMOG', 'Poluição'], ['XMAS', 'Neve']
  ];

  function renderWorld() {
    var grid = el('div', 'grid');

    WEATHER.forEach(function (w) {
      grid.appendChild(card(w[1], w[0], function () {
        post('panel_world', { kind: 'weather', value: w[0] });
        status('Clima: ' + w[1], true);
      }));
    });

    contentEl.appendChild(sectionTitle('Clima (para todos)'));
    contentEl.appendChild(grid);

    var hours = el('div', 'grid');

    [['Amanhecer', 6], ['Meio-dia', 12], ['Tarde', 17], ['Anoitecer', 20], ['Madrugada', 3]]
      .forEach(function (h) {
        hours.appendChild(card(h[0], String(h[1]).padStart(2, '0') + ':00', function () {
          post('panel_world', { kind: 'time', value: h[1] });
          status('Hora: ' + h[0], true);
        }));
      });

    contentEl.appendChild(sectionTitle('Hora (para todos)'));
    contentEl.appendChild(hours);

    var events = el('div', 'grid');

    events.appendChild(card('Evento: Postos', 'Coloca os postos em nível crítico', function () {
      post('panel_action', { action: 'eventGas' });
      status('Evento de postos disparado.', true);
    }));

    events.appendChild(card('Evento: Lojas 24/7', 'Zera o estoque e chama entregadores', function () {
      post('panel_action', { action: 'eventShops' });
      status('Evento das lojas disparado.', true);
    }));

    contentEl.appendChild(sectionTitle('Eventos'));
    contentEl.appendChild(events);
  }

  /* ---------------------------------------------------- aba: ferramentas */

  function renderTools() {
    var grid = el('div', 'grid');

    grid.appendChild(card('Handling', 'Editor de dirigibilidade do veículo', function () {
      post('panel_action', { action: 'handling' });
      close();
    }));

    grid.appendChild(card('Copiar coordenadas', 'Leitura ao vivo: ENTER vec4, TAB vec3', function () {
      post('panel_action', { action: 'coords' });
      close();
    }));

    grid.appendChild(card('Selecionar prop', 'Mira laser que copia o nome do modelo', function () {
      post('panel_action', { action: 'propSelect' });
      close();
    }));

    grid.appendChild(card('Organizações', 'Polícia, hospital, jobs e gangs', function () {
      post('panel_action', { action: 'orgs' });
      close();
    }));

    grid.appendChild(card('Parar animações', 'Solta o prop e limpa as tasks', function () {
      post('panel_action', { action: 'stopAnim' });
    }));

    grid.appendChild(card('Recarregar skin', 'Reaplica a aparência do personagem', function () {
      post('panel_action', { action: 'refreshSkin' });
    }));

    contentEl.appendChild(sectionTitle('Ferramentas de desenvolvimento'));
    contentEl.appendChild(grid);
  }

  /* ---------------------------------------------------------- aba: props */

  /** Campo rotulado do formulário de props. */
  function field(label, value, hint, numeric) {
    var wrap = el('label', 'field');

    wrap.appendChild(el('span', null, label));

    var input = el('input');
    input.type = numeric ? 'number' : 'text';
    input.value = value === undefined || value === null ? '' : String(value);
    if (hint) input.placeholder = hint;

    wrap.appendChild(input);
    wrap.input = input;

    return wrap;
  }

  function renderProps() {
    var p = state.props;

    var note = el('div', 'note');
    note.innerHTML = 'O editor abre <b>no mundo</b> e o painel se fecha — ' +
      'senão o prop ficaria escondido atrás desta tela. ' +
      '<b>WASD/QE</b> movem, <b>setas e PageUp/Down</b> giram, ' +
      '<b>ENTER</b> salva e <b>BACKSPACE</b> sai.';
    contentEl.appendChild(note);

    var form = el('div', 'form');

    var fModel = field('Modelo do prop', p.model, 'prop_amb_beer_bottle');
    var fDict = field('Dicionário de animação', p.dict, 'amb@world_human_drinking@coffee@male@idle_a');
    var fAnim = field('Nome da animação', p.anim, 'idle_c');
    var fBone = field('ID do osso', p.bone, '28422', true);

    [fModel, fDict, fAnim, fBone].forEach(function (f) { form.appendChild(f); });

    contentEl.appendChild(sectionTitle('Configuração'));
    contentEl.appendChild(form);

    var startBar = el('div', 'toolbar');
    var start = el('button', 'btn primary', 'Iniciar editor');
    start.type = 'button';
    start.addEventListener('click', function () {
      /* Guarda no estado local também: se o painel reabrir antes do próximo
         `panel:open`, os campos voltam preenchidos com o que foi digitado. */
      p.model = fModel.input.value;
      p.dict = fDict.input.value;
      p.anim = fAnim.input.value;
      p.bone = fBone.input.value;

      post('panel_action', {
        action: 'propAlign',
        model: p.model,
        dict: p.dict,
        anim: p.anim,
        bone: p.bone
      });

      close();
    });

    startBar.appendChild(start);
    contentEl.appendChild(startBar);

    /* -- presets -- */

    var presets = el('div', 'grid');

    (p.presets || []).forEach(function (preset) {
      presets.appendChild(card(preset.label, preset.model, function () {
        p.model = preset.model;
        p.dict = preset.dict;
        p.anim = preset.anim;
        p.bone = preset.bone;

        fModel.input.value = preset.model;
        fDict.input.value = preset.dict;
        fAnim.input.value = preset.anim;
        fBone.input.value = String(preset.bone);

        status('Preset carregado: ' + preset.label, true);
      }));
    });

    if ((p.presets || []).length) {
      contentEl.appendChild(sectionTitle('Predefinições'));
      contentEl.appendChild(presets);
    }

    /* -- salvos -- */

    var list = el('div', 'list');
    var saved = p.saved || [];

    saved.forEach(function (s) {
      var row = el('div', 'item');
      var info = el('div', 'info');

      info.appendChild(el('b', null, s.label));
      info.appendChild(el('code', null, s.model + ' · ' + s.anim + ' · osso ' + s.bone));
      row.appendChild(info);

      var actions = el('div', 'row-actions');

      var hold = el('button', 'mini', 'Equipar');
      hold.type = 'button';
      hold.addEventListener('click', function (ev) {
        ev.stopPropagation();
        post('panel_action', { action: 'holdProp', model: s.model, anim: s.anim });
        close();
      });

      var edit = el('button', 'mini', 'Editar');
      edit.type = 'button';
      edit.addEventListener('click', function (ev) {
        ev.stopPropagation();

        fModel.input.value = s.model;
        if (s.dict) fDict.input.value = s.dict;
        fAnim.input.value = s.anim;
        fBone.input.value = String(s.bone);

        contentEl.scrollTop = 0;
        status('Campos preenchidos com "' + s.label + '".', true);
      });

      actions.appendChild(hold);
      actions.appendChild(edit);
      row.appendChild(actions);

      list.appendChild(row);
    });

    if (!saved.length) {
      list.appendChild(el('div', 'empty', 'Nenhum alinhamento salvo ainda'));
    }

    contentEl.appendChild(sectionTitle('Alinhamentos salvos'));
    contentEl.appendChild(list);
  }

  /* ------------------------------------------------------ aba: comandos */

  var COMMANDS = [
    ['/adminmenu', 'Abre este painel'],
    ['/painel', 'Abre este painel (atalho)'],
    ['/handling', 'Editor de handling do veículo atual'],
    ['/handlingreset', 'Desfaz as alterações de handling'],
    ['/nvgaragecoords', 'Copia a posição atual como vec3/vec4'],
    ['/247debug', 'Estado do serviço de entrega 24/7'],
    ['/shopstock <id>', 'Estoque e caixa de uma loja'],
    ['/shoprestock <id>', 'Repõe o estoque (0 = todas)'],
    ['/minigame <nome>', 'Testa um minigame por preset'],
    ['/holditem <modelo> <anim>', 'Equipa um alinhamento salvo'],
    ['/stopitem', 'Interrompe animação e remove o prop da mão'],
    ['/refreshskin', 'Recarrega a aparência'],
    ['ensure <resource>', 'Sobe ou reinicia um resource (F8 ou chat)'],
    ['restart <resource>', 'Reinicia um resource já rodando'],
    ['refresh', 'Relê a pasta resources em busca de novidades']
  ];

  function renderCommands() {
    var note = el('div', 'note');
    note.innerHTML = 'Comandos de console (<b>ensure</b>, <b>restart</b>, <b>refresh</b>) ' +
      'funcionam no F8 e no chat, e exigem admin.';
    contentEl.appendChild(note);

    var box = el('div', 'list');
    var inner = el('div');
    inner.style.padding = '4px 12px';

    COMMANDS.forEach(function (c) {
      var row = el('div', 'cmd');
      row.appendChild(el('code', null, c[0]));
      row.appendChild(el('span', null, c[1]));
      inner.appendChild(row);
    });

    box.appendChild(inner);

    contentEl.appendChild(sectionTitle('Referência'));
    contentEl.appendChild(box);
  }

  /* ------------------------------------------------------------ render -- */

  var RENDER = {
    jogador: renderSelf,
    jogadores: renderPlayers,
    itens: renderItems,
    veiculos: renderVehicles,
    mundo: renderWorld,
    ferramentas: renderTools,
    props: renderProps,
    comandos: renderCommands
  };

  /** `keepScroll` preserva a rolagem ao redigitar na busca — sem isso a lista
      saltaria para o topo a cada tecla. */
  function renderContent(keepScroll) {
    var top = keepScroll ? contentEl.scrollTop : 0;
    var focused = document.activeElement;
    var wasSearch = focused && focused.classList.contains('search');
    var caret = wasSearch ? focused.selectionStart : null;

    contentEl.innerHTML = '';
    (RENDER[state.tab] || renderSelf)();
    contentEl.scrollTop = top;

    if (wasSearch) {
      var next = contentEl.querySelector('.search');

      if (next) {
        next.focus();
        if (caret !== null) next.setSelectionRange(caret, caret);
      }
    }
  }

  /* ------------------------------------------------------------- ciclo -- */

  function open(data) {
    state.open = true;
    state.players = data.players || [];
    state.items = data.items || [];
    state.vehicles = data.vehicles || [];
    state.noclip = !!data.noclip;
    state.self = null;

    if (data.props) {
      state.props = data.props;
      state.props.presets = data.props.presets || [];
      state.props.saved = data.props.saved || [];
    }

    for (var i = 0; i < state.players.length; i++) {
      if (state.players[i].isSelf) state.self = state.players[i];
    }

    subEl.textContent = (state.self ? state.self.name : 'Administrador') +
      ' · ' + state.players.length + ' online';

    status('Selecione uma categoria.');
    renderTabs();
    renderContent();

    root.classList.remove('hidden');
  }

  function close() {
    if (!state.open) return;

    state.open = false;
    root.classList.add('hidden');
    post('panel_close');
  }

  document.getElementById('adminClose').addEventListener('click', close);
  document.getElementById('adminCloseBtn').addEventListener('click', close);

  document.getElementById('adminNoclip').addEventListener('click', function () {
    post('panel_action', { action: 'noclip' });
    close();
  });

  window.addEventListener('message', function (event) {
    var data = event.data || {};

    if (data.action === 'panel:open') return open(data);
    if (data.action === 'panel:close') {
      state.open = false;
      root.classList.add('hidden');
    }
    if (data.action === 'panel:noclip') {
      state.noclip = !!data.value;
      if (state.open && state.tab === 'jogador') renderContent(true);
    }
  });

  window.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && state.open) close();
  });
})();
