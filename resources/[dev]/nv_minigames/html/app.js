/* nv_minigames — NUI vanilla (sem build).
 *
 * Protocolo:
 *   Lua -> NUI : { action:'start', game:<id>, options:{...} }
 *   Lua -> NUI : { action:'abort' }
 *   NUI -> Lua : POST /finish { success:boolean }
 */

(function () {
  'use strict';

  var RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'nv_minigames';
  var stage = document.getElementById('stage');
  var active = null;

  /* ------------------------------------------------------------------ util */

  function el(tag, cls, html) {
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (html != null) n.innerHTML = html;
    return n;
  }

  function clamp(v, min, max) {
    return v < min ? min : v > max ? max : v;
  }

  function rand(min, max) {
    return Math.random() * (max - min) + min;
  }

  function randInt(min, max) {
    return Math.floor(rand(min, max + 1));
  }

  function post(name, data) {
    fetch('https://' + RESOURCE + '/' + name, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).catch(function () {});
  }

  /* Resolve a dificuldade para um objeto de parametros do jogo. */
  function pick(presets, options) {
    var base = presets[options.difficulty] || presets.medium;
    var out = {};
    for (var k in base) out[k] = base[k];
    /* Qualquer chave passada pelo Lua sobrescreve o preset. */
    for (var o in options) if (options[o] != null && o !== 'difficulty') out[o] = options[o];
    return out;
  }

  /* --------------------------------------------------------------- chrome */

  /**
   * Monta o painel padrao (cabecalho + area do jogo + dica).
   * Devolve helpers para o jogo manipular estado visual.
   */
  function buildPanel(title, rounds, hintHTML) {
    var panel = el('div', 'panel');

    var head = el('div', 'head');
    head.appendChild(el('div', 'title', title));

    var pips = el('div', 'pips');
    var pipEls = [];
    for (var i = 0; i < rounds; i++) {
      var p = el('i', 'pip');
      pipEls.push(p);
      pips.appendChild(p);
    }
    if (rounds > 1) head.appendChild(pips);
    panel.appendChild(head);

    var body = el('div', 'body');
    panel.appendChild(body);

    if (hintHTML) panel.appendChild(el('div', 'hint', hintHTML));

    /* Barra do tempo restante. O limite sempre existiu -- a partida falhava
       sozinha ao estourar -- mas era invisivel, entao o jogador perdia sem
       entender por que. Fica no rodape do painel, esvaziando da direita para
       a esquerda. */
    var timerWrap = el('div', 'timer');
    var timerFill = el('i', 'timer-fill');

    timerWrap.appendChild(timerFill);
    panel.appendChild(timerWrap);

    stage.appendChild(panel);

    return {
      panel: panel,
      body: body,
      timerFill: timerFill,
      setProgress: function (n) {
        for (var i = 0; i < pipEls.length; i++) pipEls[i].classList.toggle('done', i < n);
      },
      flash: function (won) {
        panel.classList.add(won ? 'win' : 'lose');
      },
    };
  }

  /* Anima a barra de tempo ate o fim do limite.

     Anima por rAF em vez de uma transicao CSS de N segundos porque a barra
     precisa PARAR onde estava quando a partida termina antes da hora -- uma
     transicao continuaria correndo sozinha durante o flash de vitoria. */
  function startTimer(limit) {
    if (!active || !active.ui || !active.ui.timerFill) return;

    var fill = active.ui.timerFill;
    var began = Date.now();

    function tick() {
      if (!active || active.done) return;

      var left = 1 - (Date.now() - began) / limit;

      if (left <= 0) {
        fill.style.width = '0%';
        return;
      }

      fill.style.width = left * 100 + '%';

      /* Ultimos 25%: pulsa. E o aviso de que o tempo vai acabar, para quem
         esta olhando o jogo e nao o rodape. */
      if (left <= 0.25) fill.classList.add('low');

      active.timerRaf = requestAnimationFrame(tick);
    }

    tick();
  }

  /* ---------------------------------------------------------- ciclo de vida */

  function stop() {
    if (!active) return;
    if (active.raf) cancelAnimationFrame(active.raf);
    if (active.timerRaf) cancelAnimationFrame(active.timerRaf);
    if (active.timer) clearTimeout(active.timer);
    if (active.onKey) window.removeEventListener('keydown', active.onKey);
    active = null;
    stage.innerHTML = '';
  }

  /* Encerra a partida: mostra o resultado por um instante e avisa o Lua. */
  function finish(success) {
    if (!active || active.done) return;
    active.done = true;

    if (active.raf) cancelAnimationFrame(active.raf);
    if (active.timerRaf) cancelAnimationFrame(active.timerRaf);
    if (active.ui) active.ui.flash(success);
    if (active.onKey) window.removeEventListener('keydown', active.onKey);

    var panel = active.ui && active.ui.panel;
    setTimeout(function () {
      if (panel) panel.classList.add('is-out');
      setTimeout(function () {
        stop();
        post('finish', { success: !!success });
      }, 130);
    }, 260);
  }

  /* Registra o handler de teclado do jogo (ESC sempre cancela). */
  function bindKeys(handler) {
    active.onKey = function (e) {
      if (e.repeat) return;
      if (e.code === 'Escape') return finish(false);
      handler(e);
    };
    window.addEventListener('keydown', active.onKey);
  }

  function loop(fn) {
    var last = performance.now();
    function tick(now) {
      if (!active || active.done) return;
      var dt = (now - last) / 1000;
      last = now;
      fn(dt);
      if (active && !active.done) active.raf = requestAnimationFrame(tick);
    }
    active.raf = requestAnimationFrame(tick);
  }

  /* ================================================================== JOGOS */

  var GAMES = {};

  /* ----------------------------------------------------------- 1. LOCKED --
   * Anel giratorio: trave a agulha dentro do setor vermelho.
   * Cada acerto avanca um pino, sorteia novo setor e acelera. */

  GAMES.locked = function (options) {
    var cfg = pick(
      {
        easy: { pins: 3, zone: 62, speed: 150 },
        medium: { pins: 4, zone: 46, speed: 210 },
        hard: { pins: 5, zone: 32, speed: 285 },
      },
      options
    );

    var ui = buildPanel('Lockpick', cfg.pins, 'Trave no setor <kbd>Espaço</kbd>');
    active.ui = ui;

    var R = 72;
    var CX = 86;
    var C = 2 * Math.PI * R;

    var wrap = el('div', 'locked-ring');
    wrap.innerHTML =
      '<svg viewBox="0 0 172 172">' +
      '<circle class="track" cx="' + CX + '" cy="' + CX + '" r="' + R + '"/>' +
      '<circle class="zone" cx="' + CX + '" cy="' + CX + '" r="' + R + '"/>' +
      '<line class="needle" x1="' + CX + '" y1="2" x2="' + CX + '" y2="28"/>' +
      '</svg>' +
      '<div class="core"><b>1</b><span>pino</span></div>';
    ui.body.appendChild(wrap);

    var zoneEl = wrap.querySelector('.zone');
    var needleEl = wrap.querySelector('.needle');
    var counterEl = wrap.querySelector('.core b');

    var angle = 0;
    var dir = 1;
    var speed = cfg.speed;
    var zoneStart = 0;
    var solved = 0;

    function nextPin() {
      /* Mantem o setor longe da agulha para nao "cair no colo" do jogador. */
      var d, gap;
      do {
        zoneStart = rand(0, 360);
        d = (zoneStart - angle + 360) % 360;
        gap = Math.min(d, 360 - d);
      } while (gap < 70);

      var len = (cfg.zone / 360) * C;
      zoneEl.setAttribute('stroke-dasharray', len + ' ' + (C - len));
      zoneEl.setAttribute('transform', 'rotate(' + (zoneStart - 90) + ' ' + CX + ' ' + CX + ')');
      counterEl.textContent = String(solved + 1);
    }

    function inZone() {
      var d = (angle - zoneStart + 360) % 360;
      return d <= cfg.zone;
    }

    nextPin();

    loop(function (dt) {
      angle = (angle + dir * speed * dt + 360) % 360;
      needleEl.setAttribute('transform', 'rotate(' + angle + ' ' + CX + ' ' + CX + ')');
    });

    bindKeys(function (e) {
      if (e.code !== 'Space' && e.code !== 'Enter') return;
      if (!inZone()) return finish(false);

      solved++;
      ui.setProgress(solved);
      if (solved >= cfg.pins) return finish(true);

      dir *= -1;
      speed *= 1.14;
      nextPin();
    });
  };

  /* ------------------------------------------------------------ 2. MINES --
   * Revele as casas seguras sem tocar em nenhuma mina. */

  GAMES.mines = function (options) {
    var cfg = pick(
      {
        easy: { size: 4, mines: 3, reveals: 5 },
        medium: { size: 5, mines: 5, reveals: 6 },
        hard: { size: 5, mines: 8, reveals: 7 },
      },
      options
    );

    var total = cfg.size * cfg.size;
    cfg.mines = clamp(cfg.mines, 1, total - 1);
    cfg.reveals = clamp(cfg.reveals, 1, total - cfg.mines);

    var ui = buildPanel('Minas', cfg.reveals, 'Revele ' + cfg.reveals + ' casas seguras');
    active.ui = ui;

    /* Sorteia as posicoes das minas sem repeticao. */
    var bombs = {};
    var placed = 0;
    while (placed < cfg.mines) {
      var idx = randInt(0, total - 1);
      if (!bombs[idx]) {
        bombs[idx] = true;
        placed++;
      }
    }

    var grid = el('div', 'mines-grid');
    grid.style.gridTemplateColumns = 'repeat(' + cfg.size + ', 42px)';
    ui.body.appendChild(grid);

    var opened = 0;
    var tiles = [];

    function revealAll() {
      for (var i = 0; i < tiles.length; i++) {
        if (bombs[i] && !tiles[i].classList.contains('boom')) {
          tiles[i].classList.add('reveal');
          tiles[i].textContent = '✖';
        }
      }
    }

    for (var i = 0; i < total; i++) {
      (function (index) {
        var tile = el('div', 'tile');
        tile.addEventListener('click', function () {
          if (!active || active.done || tile.classList.contains('open') || tile.classList.contains('boom')) return;

          if (bombs[index]) {
            tile.classList.add('boom');
            tile.textContent = '✖';
            revealAll();
            return finish(false);
          }

          tile.classList.add('open');
          tile.textContent = '●';
          opened++;
          ui.setProgress(opened);
          if (opened >= cfg.reveals) finish(true);
        });
        tiles.push(tile);
        grid.appendChild(tile);
      })(i);
    }

    bindKeys(function () {});
  };

  /* -------------------------------------------------------- 3. SKILL BAR --
   * Cursor em vaivem: pare dentro do setor a cada rodada. */

  GAMES.skillbar = function (options) {
    var cfg = pick(
      {
        easy: { rounds: 2, zone: 24, speed: 62 },
        medium: { rounds: 3, zone: 16, speed: 92 },
        hard: { rounds: 4, zone: 10, speed: 128 },
      },
      options
    );

    var ui = buildPanel('Perícia', cfg.rounds, 'Pare no setor <kbd>Espaço</kbd>');
    active.ui = ui;

    var bar = el('div', 'bar');
    bar.innerHTML = '<div class="zone"></div><div class="cursor"></div>';
    ui.body.appendChild(bar);

    var zoneEl = bar.querySelector('.zone');
    var cursorEl = bar.querySelector('.cursor');

    var pos = 0;
    var dir = 1;
    var speed = cfg.speed;
    var zoneStart = 0;
    var done = 0;

    function nextRound() {
      /* Evita sortear o setor exatamente sob o cursor. */
      var tries = 0;
      do {
        zoneStart = rand(6, 94 - cfg.zone);
        tries++;
      } while (tries < 20 && pos > zoneStart - 8 && pos < zoneStart + cfg.zone + 8);

      zoneEl.style.left = zoneStart + '%';
      zoneEl.style.width = cfg.zone + '%';
    }

    nextRound();

    loop(function (dt) {
      pos += dir * speed * dt;
      if (pos >= 100) {
        pos = 100;
        dir = -1;
      } else if (pos <= 0) {
        pos = 0;
        dir = 1;
      }
      cursorEl.style.left = pos + '%';
    });

    bindKeys(function (e) {
      if (e.code !== 'Space' && e.code !== 'Enter') return;
      if (pos < zoneStart || pos > zoneStart + cfg.zone) return finish(false);

      done++;
      ui.setProgress(done);
      if (done >= cfg.rounds) return finish(true);

      speed *= 1.16;
      nextRound();
    });
  };

  /* --------------------------------------------------- 4. PROGRESS TIMING --
   * A barra enche uma unica vez por rodada: acerte a janela na passagem. */

  GAMES.timing = function (options) {
    var cfg = pick(
      {
        easy: { rounds: 2, window: 20, duration: 2600 },
        medium: { rounds: 3, window: 13, duration: 2100 },
        hard: { rounds: 4, window: 8, duration: 1700 },
      },
      options
    );

    var ui = buildPanel('Sincronia', cfg.rounds, 'Acerte a janela <kbd>Espaço</kbd>');
    active.ui = ui;

    var box = el('div', 'timing');
    box.innerHTML = '<div class="window"></div><div class="fill"></div>';
    ui.body.appendChild(box);

    var winEl = box.querySelector('.window');
    var fillEl = box.querySelector('.fill');

    var progress = 0;
    var winStart = 0;
    var done = 0;
    var armed = true;

    function nextRound() {
      progress = 0;
      armed = true;
      /* A janela nunca encosta nas pontas, para sempre haver reacao possivel. */
      winStart = rand(22, 88 - cfg.window);
      winEl.style.left = winStart + '%';
      winEl.style.width = cfg.window + '%';
      winEl.classList.remove('hit');
      fillEl.style.width = '0%';
    }

    nextRound();

    loop(function (dt) {
      progress += (dt * 1000 * 100) / cfg.duration;
      if (progress >= 100) {
        progress = 100;
        fillEl.style.width = '100%';
        /* Deixou a janela passar sem apertar. */
        if (armed) return finish(false);
        return;
      }
      fillEl.style.width = progress + '%';
    });

    bindKeys(function (e) {
      if (e.code !== 'Space' && e.code !== 'Enter') return;
      if (!armed) return;
      armed = false;

      if (progress < winStart || progress > winStart + cfg.window) return finish(false);

      winEl.classList.add('hit');
      done++;
      ui.setProgress(done);
      if (done >= cfg.rounds) return finish(true);

      setTimeout(function () {
        if (active && !active.done) nextRound();
      }, 200);
    });
  };

  /* Aliases aceitos pelo Lua. */
  GAMES.skill_bar = GAMES.skillbar;
  GAMES.progress_timing = GAMES.timing;

  /* ------------------------------------------------------------- mensagens */

  window.addEventListener('message', function (event) {
    var data = event.data || {};

    if (data.action === 'abort') {
      stop();
      return;
    }

    if (data.action !== 'start') return;

    var game = GAMES[data.game];
    if (!game) {
      post('finish', { success: false });
      return;
    }

    stop();
    active = { done: false };

    var options = data.options || {};
    game(options);

    /* Rede de seguranca: nenhuma partida pode travar o jogador para sempre. */
    var limit = Number(options.timeout) || 30000;

    active.timer = setTimeout(function () {
      finish(false);
    }, limit);

    startTimer(limit);
  });
})();
