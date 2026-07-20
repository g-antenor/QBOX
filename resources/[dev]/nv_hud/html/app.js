/* ==========================================================================
   nv_hud - camada de interface
   ========================================================================== */
const stage = document.getElementById('stage');
const backdrop = document.getElementById('backdrop');
const ghost = document.getElementById('minimapGhost');

const DEFAULT_POSITIONS = {
  'hud-compass-compact': { left: 1.0,  top: 70.0 },
  'hud-compass':         { left: 50,   top: 3, center: true },
  'hud-status':          { left: 18.5, top: 86 },
  'hud-voice':           { left: 88,   top: 85 },
  'hud-vehicle':         { left: 50,   top: 76, center: true }
};

const STATUS_ELEMENTS = {
  vida:   { cell: 'cell-vida',   ring: 'ringVida',   val: 'valVida' },
  colete: { cell: 'cell-colete', ring: 'ringColete', val: 'valColete' },
  fome:   { cell: 'cell-fome',   ring: 'ringFome',   val: 'valFome' },
  sede:   { cell: 'cell-sede',   ring: 'ringSede',   val: 'valSede' },
  stress: { cell: 'cell-stress', ring: 'ringStress', val: 'valStress' }
};

let settings = null;
let critical = { vida: 20, colete: 20, fome: 20, sede: 20, stress: 80, fuel: 15 };
let idle = { vida: 100, colete: 0, fome: 100, sede: 100, stress: 0 };
let engineLimits = { damaged: 700, destroyed: 100 };
let fuelLimits = { low: 45, critical: 20 };
let compassOnlyInVehicle = true;
let minimapCfg = {
  shapes: {
    quadrado: { w: 0.290, h: 0.185, left: 0.013, bottom: 0.063 },
    redondo:  { w: 0.270, h: 0.229, left: 0.013, bottom: 0.069 }
  },
  nudgeStep: 0.004
};

let panelOpen = false;
let dragMode = false;
let selected = null;

const state = {
  vida: 100, colete: 0, fome: 100, sede: 100, stress: 0,
  heading: 0, street: '', region: '',
  micRange: 0, micTalking: false,
  radioOn: false, radioFreq: 0, radioTalking: false,
  inVehicle: false, speed: 0, fuel: 100, gear: 'N',
  engineOn: false, engineHealth: 1000, belt: false, locked: false
};

const post = (name, data) =>
  fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data || {})
  }).catch(() => {});

/* ---------------- posicoes ---------------- */
function applyPosition(id) {
  const el = document.getElementById(id);
  if (!el) return;

  const saved = settings && settings.positions ? settings.positions[id] : null;
  const pos = saved || DEFAULT_POSITIONS[id];
  if (!pos) return;

  el.style.left = pos.left + '%';
  el.style.top = pos.top + '%';
  el.style.transform = (!saved && pos.center) ? 'translateX(-50%)' : 'none';
}

function applyAllPositions() {
  Object.keys(DEFAULT_POSITIONS).forEach(applyPosition);

  /* A moldura do minimapa tem geometria propria, derivada do radar. */
  applyMinimapBox();
}

/* ---------------- minimapa ----------------
   A moldura usa exatamente os mesmos numeros que o Lua manda para o radar
   real. Se divergirem, a moldura mente sobre onde o radar esta. */
/* Geometria da moldura para o formato atual.
   w/h vem em fracao da ALTURA da tela, que e como o radar do GTA se dimensiona
   em qualquer proporcao de monitor. */
function minimapFrame() {
  const shapes = minimapCfg.shapes || {};

  return shapes[settings.minimapShape] || shapes.quadrado ||
    { w: 0.29, h: 0.185, left: 0.013, bottom: 0.063 };
}

/* Mesma correcao de ultrawide que o Lua aplica no radar. Sem ela a moldura
   ficaria parada enquanto o radar desliza para a esquerda em telas largas. */
function aspectOffset() {
  const aspect = window.innerWidth / window.innerHeight;
  const base = 1920 / 1080;

  return aspect > base ? ((base - aspect) / 3.6) - 0.008 : 0;
}

/* A moldura nao tem como perguntar ao jogo onde o radar foi parar: ela parte
   da posicao do radar vanilla e soma o mesmo deslocamento que o Lua manda
   para os componentes. Arrastar a moldura move os dois juntos. */
function applyMinimapBox() {
  const f = minimapFrame();
  const W = window.innerWidth;
  const H = window.innerHeight;

  const boxW = f.w * H;
  const boxH = f.h * H;

  const offset = settings.minimapOffset || { x: 0, y: 0 };
  /* Calibragem exclusiva da moldura: encosta a borda no radar sem mover o
     radar de lugar. E o que as setas ajustam. */
  const border = settings.borderOffset || { x: 0, y: 0 };

  const left = (f.left + aspectOffset() + offset.x + border.x) * W;
  const bottom = (f.bottom - offset.y + border.y) * H;

  const item = document.getElementById('hud-minimap');
  item.style.left = left + 'px';
  item.style.top = (H - bottom - boxH) + 'px';
  item.style.transform = 'none';

  ghost.style.width = boxW + 'px';
  ghost.style.height = boxH + 'px';
}

window.addEventListener('resize', () => {
  if (settings) applyMinimapBox();
});

/* ---------------- visibilidade ---------------- */
function isVisible(name) {
  return !!(settings && settings.visible && settings.visible[name]);
}

function toggle(id, visible) {
  const el = document.getElementById(id);
  if (el) el.classList.toggle('hidden', !visible);
}

/* Decide se um status aparece.
     auto    - esconde o que estiver no valor ideal (nada a comunicar)
     todos   - exibe os cinco, sempre
     selecao - exibe todos os marcados na lista, independente do valor

   Escolha explicita manda mais que regra automatica: em "todos" e "selecao"
   o item aparece porque o jogador pediu, mesmo em 100% ou zerado. A regra do
   colete (so com colete equipado) vale apenas no modo automatico. */
function statusVisible(key) {
  const mode = settings.statusMode || 'auto';

  if (mode === 'todos') return true;
  if (mode === 'selecao') return isVisible(key);

  if (key === 'colete') return state.colete > 0;

  return state[key] !== idle[key];
}

function applyVisibility() {
  if (!settings) return;

  /* No modo de edicao tudo aparece, mesmo o que dependeria de contexto
     (veiculo, radio ligado, status no valor ideal). Sem isso o jogador nao
     consegue posicionar a bussola e o velocimetro estando a pe. */
  const editing = dragMode;

  let anyStatus = false;

  Object.keys(STATUS_ELEMENTS).forEach(key => {
    const visible = editing || statusVisible(key);
    if (visible) anyStatus = true;

    /* A celula sai do fluxo flex: as vizinhas fecham o espaco sozinhas. */
    document.getElementById(STATUS_ELEMENTS[key].cell).classList.toggle('hidden', !visible);
  });

  /* Grupo inteiro vazio nao deve deixar contorno no modo de edicao. */
  toggle('hud-status', anyStatus);

  toggle('hud-minimap', editing || isVisible('minimap'));

  /* Bussola so faz sentido dirigindo: a pe ela vira ruido. */
  const compassOn = editing ||
    (isVisible('compass') && (!compassOnlyInVehicle || state.inVehicle));

  toggle('hud-compass', compassOn && settings.compassStyle === 'padrao');
  toggle('hud-compass-compact', compassOn && settings.compassStyle === 'compacta');

  const micOn = editing || isVisible('mic');
  const radioOn = editing || (isVisible('radio') && state.radioOn);

  document.getElementById('micWidget').classList.toggle('hidden', !micOn);
  document.getElementById('radioWidget').classList.toggle('hidden', !radioOn);
  toggle('hud-voice', micOn || radioOn);

  toggle('hud-vehicle', editing || (isVisible('vehicle') && state.inVehicle));
}

function applySettings(next) {
  settings = next;

  if (!settings.positions || Array.isArray(settings.positions)) settings.positions = {};
  if (!settings.visible) settings.visible = {};
  if (!settings.minimapOffset) settings.minimapOffset = { x: 0, y: 0 };
  if (!settings.borderOffset) settings.borderOffset = { x: 0, y: 0 };

  stage.classList.toggle('status-square', settings.statusShape === 'quadrado');
  stage.classList.toggle('minimap-round', settings.minimapShape === 'redondo');
  stage.classList.toggle('no-percent', settings.showPercent === false);

  applyMinimapBox();
  applyAllPositions();
  applyVisibility();
  syncPanel();
  renderAll();
}

/* ---------------- status ---------------- */
function renderStatus() {
  Object.keys(STATUS_ELEMENTS).forEach(key => {
    const el = STATUS_ELEMENTS[key];
    const cell = document.getElementById(el.cell);
    const value = state[key];

    /* O anel e um conic-gradient: o preenchimento e a variavel --pct, nao
       uma largura. Manter isso em CSS deixa a transicao por conta do
       browser em vez de um rAF nosso. */
    document.getElementById(el.ring).style.setProperty('--pct', value);
    document.getElementById(el.val).textContent = value + '%';

    let isCritical;

    if (key === 'stress') {
      isCritical = value >= critical.stress;
    } else if (key === 'colete') {
      /* Sem colete a celula nem aparece, entao alerta so faz sentido acima
         de zero. */
      isCritical = value > 0 && value <= critical.colete;
    } else {
      isCritical = value <= (critical[key] !== undefined ? critical[key] : 20);
    }

    cell.classList.toggle('critical', isCritical);
  });

  applyVisibility();
}

/* ---------------- bussola ---------------- */
const COMPASS_DIRS = { 0: 'N', 45: 'NE', 90: 'E', 135: 'SE', 180: 'S', 225: 'SW', 270: 'W', 315: 'NW' };

function buildCompass() {
  const track = document.getElementById('compassTrack');

  for (let deg = -90; deg <= 450; deg += 15) {
    const norm = ((deg % 360) + 360) % 360;
    const mark = document.createElement('div');

    mark.className = 'compass-mark' + (COMPASS_DIRS[norm] !== undefined ? ' major' : '');
    mark.textContent = COMPASS_DIRS[norm] !== undefined ? COMPASS_DIRS[norm] : '·';
    track.appendChild(mark);
  }
}

function headingToLetter(heading) {
  const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  return dirs[Math.round((((heading % 360) + 360) % 360) / 45) % 8];
}

/* O client manda a direcao a cada 100ms. Pular direto para cada valor deixa a
   regua "picotada"; entao guardamos uma direcao exibida que persegue a real a
   cada quadro, sempre pelo caminho angular mais curto (senao, ao cruzar
   0/360, a regua daria uma volta inteira ao contrario). */
let shownHeading = 0;

function stepCompass() {
  const target = ((state.heading % 360) + 360) % 360;
  let diff = target - shownHeading;

  if (diff > 180) diff -= 360;
  if (diff < -180) diff += 360;

  shownHeading = (shownHeading + diff * 0.2 + 360) % 360;

  const markCenter = (shownHeading + 90) * 2 + 15;
  document.getElementById('compassTrack').style.transform = `translateX(${130 - markCenter}px)`;
  document.getElementById('compassCompactDir').textContent = headingToLetter(shownHeading);

  requestAnimationFrame(stepCompass);
}

function renderCompass() {
  const region = state.region || '—';
  const street = state.street || 'Rua desconhecida';

  document.getElementById('compassRegion').textContent = region;
  document.getElementById('compassStreet').textContent = street;
  document.getElementById('compassCompactRegion').textContent = region;
  document.getElementById('compassCompactStreet').textContent = street;
}

/* ---------------- voz e radio ---------------- */
function renderMic() {
  const widget = document.getElementById('micWidget');

  /* As barras acesas usam currentColor, entao acompanham o estado do widget:
     cinza claro parado, vermelho enquanto fala. */
  document.querySelectorAll('#micBars i').forEach((bar, i) => {
    bar.classList.toggle('lit', i < state.micRange);
  });

  widget.classList.toggle('talking', state.micTalking);
}

function renderRadio() {
  /* Frequencia vem pronta do nv_radio, no mesmo formato do aparelho (X.Y). */
  const freq = Number(state.radioFreq) || 0;

  document.getElementById('radioCh').textContent = freq.toFixed(1);
  document.getElementById('radioWidget').classList.toggle('talking', state.radioTalking);
}

/* ---------------- veiculo ---------------- */
function renderVehicle() {
  toggle('hud-vehicle', isVisible('vehicle') && state.inVehicle);

  document.getElementById('vhSpeedVal').textContent = state.speed;
  document.getElementById('vhGear').textContent = state.gear;

  /* A faixa vive no container: barra, icone e numero herdam a mesma cor. */
  const fuelBox = document.getElementById('vhFuel');
  fuelBox.classList.toggle('critical', state.fuel <= fuelLimits.critical);
  fuelBox.classList.toggle('low', state.fuel > fuelLimits.critical && state.fuel <= fuelLimits.low);

  document.getElementById('vhFuelFill').style.width = state.fuel + '%';
  document.getElementById('vhFuelVal').textContent = state.fuel + '%';

  /* Motor: danificado pisca, destruido fica vermelho fixo. */
  const engine = document.getElementById('vhEngineIcon');
  const health = state.engineHealth;

  engine.classList.toggle('danger', health <= engineLimits.destroyed);
  engine.classList.toggle('warn', health > engineLimits.destroyed && health <= engineLimits.damaged);
  engine.classList.toggle('on', state.engineOn && health > engineLimits.damaged);

  /* Sem cinto pisca em vermelho. */
  const belt = document.getElementById('vhBeltIcon');
  belt.classList.toggle('warn', !state.belt);
  belt.classList.toggle('on', state.belt);

  /* Icone muda entre cadeado fechado e aberto. */
  const lock = document.getElementById('vhLockIcon');
  lock.querySelector('use').setAttribute('href', state.locked ? '#ic-trancado' : '#ic-destrancado');
  lock.classList.toggle('on', state.locked);
}

function renderAll() {
  renderStatus();
  renderCompass();
  renderMic();
  renderRadio();
  renderVehicle();
}

/* ---------------- painel ---------------- */
function syncPanel() {
  document.querySelectorAll('.seg').forEach(seg => {
    const value = settings[seg.dataset.setting];
    seg.querySelectorAll('button').forEach(btn => btn.classList.toggle('active', btn.dataset.value === value));
  });

  document.querySelectorAll('[data-vis]').forEach(cb => { cb.checked = isVisible(cb.dataset.vis); });
  document.querySelectorAll('[data-flag]').forEach(cb => { cb.checked = settings[cb.dataset.flag] !== false; });

  /* A lista de status so tem efeito no modo "Selecionar"; nos outros ela fica
     apagada para nao dar a impressao de que controla algo. */
  const picking = (settings.statusMode || 'auto') === 'selecao';
  document.querySelectorAll('.vis-row.status-pick').forEach(row => {
    row.classList.toggle('inactive', !picking);
  });

}

const save = () => post('saveSettings', settings);

document.querySelectorAll('.seg').forEach(seg => {
  seg.querySelectorAll('button').forEach(btn => {
    btn.addEventListener('click', () => {
      settings[seg.dataset.setting] = btn.dataset.value;
      applySettings(settings);
      save();
    });
  });
});

document.querySelectorAll('[data-vis]').forEach(cb => {
  cb.addEventListener('change', () => {
    settings.visible[cb.dataset.vis] = cb.checked;
    applyVisibility();
    save();
  });
});

document.querySelectorAll('[data-flag]').forEach(cb => {
  cb.addEventListener('change', () => {
    settings[cb.dataset.flag] = cb.checked;
    applySettings(settings);
    save();
  });
});


/* ---------------- navegacao ---------------- */
function setDragMode(enabled) {
  dragMode = enabled;
  stage.classList.toggle('edit-mode', enabled);
  backdrop.classList.toggle('shown', panelOpen && !enabled);

  if (!enabled && selected) {
    selected.classList.remove('selected');
    selected = null;
  }

  /* Entrar/sair da edicao muda o que fica visivel. */
  applyVisibility();
}

function setPanelOpen(open) {
  panelOpen = open;
  if (!open) setDragMode(false);
  else backdrop.classList.add('shown');
}

document.getElementById('btnStartDrag').addEventListener('click', () => setDragMode(true));
document.getElementById('btnFinishDrag').addEventListener('click', () => setDragMode(false));

document.getElementById('btnResetPositions').addEventListener('click', () => {
  settings.positions = {};
  settings.minimapOffset = { x: 0, y: 0 };
  applyAllPositions();
  save();
});

document.getElementById('btnResetAll').addEventListener('click', () => post('resetSettings'));
document.getElementById('btnClose').addEventListener('click', () => post('close'));
document.getElementById('btnCloseFoot').addEventListener('click', () => post('close'));

backdrop.addEventListener('mousedown', event => {
  if (event.target === backdrop) post('close');
});

/* ---------------- teclado ---------------- */
const ARROWS = {
  ArrowLeft:  [-1, 0],
  ArrowRight: [1, 0],
  ArrowUp:    [0, 1],
  ArrowDown:  [0, -1]
};

/* Setas ajustam SO a moldura, para encostar a borda no radar. Arrastar com o
   mouse e que move o minimapa inteiro (radar + moldura). Separar os dois
   evita o vaivem de alinhar um e desalinhar o outro. */
document.addEventListener('keydown', event => {
  if (!dragMode || !selected || selected.id !== 'hud-minimap') return;

  const delta = ARROWS[event.key];
  if (!delta) return;

  event.preventDefault();

  if (!settings.borderOffset) settings.borderOffset = { x: 0, y: 0 };

  const step = minimapCfg.nudgeStep;
  settings.borderOffset.x += delta[0] * step;
  settings.borderOffset.y += delta[1] * step;

  applyMinimapBox();
  save();
});

document.addEventListener('keyup', event => {
  if (event.key !== 'Escape' || !panelOpen) return;

  if (dragMode) setDragMode(false);
  else post('close');
});

/* ---------------- arrastar o minimapa ----------------
   Diferente dos outros itens: aqui a posicao final nao e do elemento HTML, e
   sim um deslocamento em fracao de tela aplicado ao radar do jogo. A moldura
   e o radar leem o mesmo numero, entao andam juntos. */
function dragMinimap(event, el) {
  const f = minimapFrame();
  const W = window.innerWidth;
  const H = window.innerHeight;

  const rect = el.getBoundingClientRect();
  const grabX = event.clientX - rect.left;
  const grabY = event.clientY - rect.top;

  el.setPointerCapture(event.pointerId);

  let queued = false;

  const onMove = move => {
    const left = Math.min(Math.max(move.clientX - grabX, 0), W - rect.width);
    const top = Math.min(Math.max(move.clientY - grabY, 0), H - rect.height);

    /* Converte a posicao na tela de volta para deslocamento em relacao ao
       lugar original do radar. */
    settings.minimapOffset = {
      x: left / W - f.left - aspectOffset(),
      y: f.bottom - (H - top - rect.height) / H
    };

    applyMinimapBox();

    if (!queued) {
      queued = true;
      requestAnimationFrame(() => {
        queued = false;
        post('minimapOffset', settings.minimapOffset);
      });
    }
  };

  const onUp = () => {
    el.removeEventListener('pointermove', onMove);
    el.removeEventListener('pointerup', onUp);

    post('minimapOffset', settings.minimapOffset);
    save();
  };

  el.addEventListener('pointermove', onMove);
  el.addEventListener('pointerup', onUp);
}

/* ---------------- arrastar ---------------- */
function makeDraggable(el) {
  el.addEventListener('pointerdown', event => {
    if (!dragMode) return;
    event.preventDefault();

    /* O minimapa arrasta como qualquer outro item, so que o resultado vira
       deslocamento em fracao de tela para os componentes do radar. */
    if (el.id === 'hud-minimap') {
      if (selected) selected.classList.remove('selected');
      selected = el;
      el.classList.add('selected');

      dragMinimap(event, el);
      return;
    }

    if (selected) selected.classList.remove('selected');
    selected = el;
    el.classList.add('selected');

    const rect = el.getBoundingClientRect();
    const offsetX = event.clientX - rect.left;
    const offsetY = event.clientY - rect.top;

    el.style.transform = 'none';
    el.setPointerCapture(event.pointerId);

    let queued = false;

    const onMove = move => {
      const x = Math.min(Math.max(move.clientX - offsetX, 0), window.innerWidth - rect.width);
      const y = Math.min(Math.max(move.clientY - offsetY, 0), window.innerHeight - rect.height);

      el.style.left = (x / window.innerWidth * 100) + '%';
      el.style.top = (y / window.innerHeight * 100) + '%';
    };

    const onUp = () => {
      el.removeEventListener('pointermove', onMove);
      el.removeEventListener('pointerup', onUp);

      settings.positions[el.id] = {
        left: parseFloat(el.style.left),
        top: parseFloat(el.style.top)
      };

      save();
    };

    el.addEventListener('pointermove', onMove);
    el.addEventListener('pointerup', onUp);
  });
}

document.querySelectorAll('.hud-item').forEach(makeDraggable);

/* ---------------- ponte com o cliente ---------------- */
const HANDLERS = {
  settings(data) {
    if (data.critical) critical = data.critical;
    if (data.idle) idle = data.idle;
    if (data.engine) engineLimits = data.engine;
    if (data.fuel) fuelLimits = data.fuel;
    if (data.compassOnlyInVehicle !== undefined) compassOnlyInVehicle = data.compassOnlyInVehicle;
    if (data.minimap) minimapCfg = Object.assign(minimapCfg, data.minimap);

    applySettings(data.settings);
  },

  state(data) {
    Object.assign(state, data);
    renderAll();
  },

  visible(shown) {
    stage.classList.toggle('shown', shown === true);
  },

  paused(paused) {
    stage.classList.toggle('paused', paused === true);
  },

  panel(open) {
    setPanelOpen(open === true);
  }
};

window.addEventListener('message', event => {
  const handler = HANDLERS[event.data.action];
  if (handler) handler(event.data.data);
});

buildCompass();
stepCompass();
post('ready');
