/* nv_radio — NUI.
 *
 * Lua -> NUI : { action:'open', presets, min, max }
 *              { action:'state', state:{ power, frequency, label, volume, micClick } }
 *              { action:'close' }
 * NUI -> Lua : POST /power     { on }
 *              POST /frequency { value }
 *              POST /volume    { value }
 *              POST /micclick  { on }
 *              POST /close
 */

(function () {
  'use strict';

  var RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'nv_radio';

  var el = function (id) {
    return document.getElementById(id);
  };

  var radioEl = el('radio');
  var screenEl = el('screen');
  var freqEl = el('freq');
  var statusEl = el('status');
  var labelEl = el('label');
  var inputEl = el('input');
  var savedEl = el('saved');
  var saveEl = el('save');
  var volumeEl = el('volume');
  var volvalEl = el('volval');
  var micEl = el('micclick');
  var powerEl = el('power');

  var state = { power: false, frequency: 1, label: '', volume: 20, micClick: true, isSaved: false };
  var bounds = { min: 1, max: 500, maxVolume: 60, maxSaved: 6 };

  function post(name, data) {
    fetch('https://' + RESOURCE + '/' + name, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).catch(function () {});
  }

  function clamp(value) {
    return Math.min(bounds.max, Math.max(bounds.min, value));
  }

  /* Uma casa decimal: é a resolução que o Lua converte em canal. */
  function round(value) {
    return Math.round(value * 10) / 10;
  }

  function render() {
    freqEl.textContent = state.frequency.toFixed(1);
    statusEl.textContent = state.power ? 'TRANSMITINDO' : 'DESLIGADO';
    labelEl.textContent = state.power ? state.label : '—';

    screenEl.classList.toggle('on', state.power);

    powerEl.textContent = state.power ? 'Desligar' : 'Ligar';
    powerEl.classList.toggle('on', state.power);

    // Não sobrescreve enquanto o jogador está digitando o valor.
    if (document.activeElement !== inputEl) {
      inputEl.value = state.frequency.toFixed(1);
    }

    volumeEl.value = state.volume;
    volvalEl.textContent = state.volume;

    micEl.textContent = state.micClick ? 'ON' : 'OFF';
    micEl.classList.toggle('off', !state.micClick);

    saveEl.textContent = state.isSaved ? 'Remover' : 'Salvar atual';
    saveEl.classList.toggle('on', !!state.isSaved);

    Array.prototype.forEach.call(savedEl.children, function (button) {
      if (!button.dataset.frequency) return;

      var active = state.power && round(parseFloat(button.dataset.frequency)) === round(state.frequency);
      button.classList.toggle('active', active);
    });
  }

  /* Lista de frequências que o próprio jogador guardou. */
  function renderSaved(list) {
    savedEl.innerHTML = '';

    if (!list || !list.length) {
      var empty = document.createElement('div');
      empty.className = 'empty';
      empty.textContent = 'Nenhuma frequência salva';
      savedEl.appendChild(empty);
      return;
    }

    list.forEach(function (entry) {
      var button = document.createElement('button');
      button.className = 'preset';
      button.dataset.frequency = entry.frequency;
      button.textContent = Number(entry.frequency).toFixed(1);

      if (entry.label && entry.label !== 'LIVRE') {
        button.textContent = entry.label + ' · ' + Number(entry.frequency).toFixed(1);
      }

      button.addEventListener('click', function () {
        post('frequency', { value: Number(entry.frequency) });
      });

      savedEl.appendChild(button);
    });
  }

  function close() {
    radioEl.classList.add('hidden');
    post('close');
  }

  /* ------------------------------------------------------------ eventos -- */

  Array.prototype.forEach.call(document.querySelectorAll('.step'), function (button) {
    button.addEventListener('click', function () {
      var next = clamp(round(state.frequency + parseFloat(button.dataset.step) * 0.1));
      post('frequency', { value: next });
    });
  });

  inputEl.addEventListener('change', function () {
    var parsed = parseFloat(inputEl.value);

    if (isNaN(parsed)) {
      inputEl.value = state.frequency.toFixed(1);
      return;
    }

    post('frequency', { value: clamp(round(parsed)) });
  });

  volumeEl.addEventListener('input', function () {
    state.volume = parseInt(volumeEl.value, 10);
    volvalEl.textContent = state.volume;
    post('volume', { value: state.volume });
  });

  saveEl.addEventListener('click', function () {
    post('save');
  });

  micEl.addEventListener('click', function () {
    state.micClick = !state.micClick;
    render();
    post('micclick', { on: state.micClick });
  });

  powerEl.addEventListener('click', function () {
    post('power', { on: !state.power });
  });

  el('close').addEventListener('click', close);

  window.addEventListener('keydown', function (event) {
    if (radioEl.classList.contains('hidden')) return;
    if (event.code === 'Escape') close();
  });

  window.addEventListener('message', function (event) {
    var data = event.data || {};

    if (data.action === 'open') {
      bounds.min = data.min || 1;
      bounds.max = data.max || 500;
      bounds.maxVolume = data.maxVolume || 60;
      bounds.maxSaved = data.maxSaved || 6;

      volumeEl.max = bounds.maxVolume;
      radioEl.classList.remove('hidden');
      return;
    }

    if (data.action === 'state') {
      state = data.state || state;
      renderSaved(data.saved);
      render();
      return;
    }

    if (data.action === 'close') {
      radioEl.classList.add('hidden');
    }
  });
})();
