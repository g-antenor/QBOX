/* nv_adminmenu — tablet de handling.
 *
 * Lua -> NUI : { action:'open', vehicle, categories, values }
 *              { action:'close' }
 *              { action:'status', text, ok }
 * NUI -> Lua : POST /handling_save { values }
 *              POST /handling_test { values }
 *              POST /handling_close
 */

(function () {
  'use strict';

  var RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'nv_adminmenu';

  var tablet = document.getElementById('tablet');
  var tabsEl = document.getElementById('tabs');
  var fieldsEl = document.getElementById('fields');
  var vehicleEl = document.getElementById('vehicle');
  var statusEl = document.getElementById('status');

  var categories = [];
  var values = {};   // key -> number | {x,y,z}
  var initial = {};  // cópia do estado recebido, para marcar o que mudou
  var active = 0;

  function post(name, data) {
    fetch('https://' + RESOURCE + '/' + name, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).catch(function () {});
  }

  function setStatus(text, ok) {
    statusEl.textContent = text;
    statusEl.classList.toggle('ok', !!ok);
  }

  /* Um valor difere do que veio do jogo? Usado para destacar o input. */
  function isChanged(key) {
    var a = values[key];
    var b = initial[key];

    if (typeof a === 'object' && a !== null) {
      return a.x !== b.x || a.y !== b.y || a.z !== b.z;
    }
    return a !== b;
  }

  function numberInput(key, value, axis) {
    var input = document.createElement('input');
    input.type = 'number';
    input.step = 'any';
    input.value = value;

    input.addEventListener('input', function () {
      var parsed = parseFloat(input.value);
      if (isNaN(parsed)) return;

      if (axis) values[key][axis] = parsed;
      else values[key] = parsed;

      input.classList.toggle('changed', isChanged(key));
    });

    input.classList.toggle('changed', isChanged(key));
    return input;
  }

  function renderFields() {
    fieldsEl.innerHTML = '';

    var category = categories[active];
    if (!category) return;

    category.fields.forEach(function (field) {
      var row = document.createElement('div');
      row.className = 'row';

      var label = document.createElement('div');
      label.className = 'label';
      label.innerHTML = '<b></b><code></code>';
      label.querySelector('b').textContent = field.label;
      label.querySelector('code').textContent = field.key;
      row.appendChild(label);

      var inputs = document.createElement('div');
      inputs.className = 'inputs';

      if (field.kind === 'vector') {
        ['x', 'y', 'z'].forEach(function (axis) {
          var wrap = document.createElement('div');
          wrap.className = 'axis';

          var tag = document.createElement('span');
          tag.textContent = axis;

          wrap.appendChild(tag);
          wrap.appendChild(numberInput(field.key, values[field.key][axis], axis));
          inputs.appendChild(wrap);
        });
      } else {
        inputs.appendChild(numberInput(field.key, values[field.key]));
      }

      row.appendChild(inputs);

      // Botão de ajuda por campo: explica o ponto sem sair da tela.
      var helpBtn = document.createElement('button');
      helpBtn.className = 'help-btn';
      helpBtn.textContent = '?';
      helpBtn.title = 'O que é isso?';
      row.appendChild(helpBtn);

      var help = document.createElement('div');
      help.className = 'help hidden';
      help.textContent = field.help;

      helpBtn.addEventListener('click', function () {
        help.classList.toggle('hidden');
        helpBtn.classList.toggle('open');
      });

      fieldsEl.appendChild(row);
      fieldsEl.appendChild(help);
    });
  }

  function renderTabs() {
    tabsEl.innerHTML = '';

    categories.forEach(function (category, index) {
      var tab = document.createElement('button');
      tab.className = 'tab' + (index === active ? ' active' : '');
      tab.innerHTML = '<span></span><small></small>';
      tab.querySelector('span').textContent = category.name;
      tab.querySelector('small').textContent = category.fields.length + ' parâmetros';

      tab.addEventListener('click', function () {
        active = index;
        renderTabs();
        renderFields();
      });

      tabsEl.appendChild(tab);
    });
  }

  function close() {
    tablet.classList.add('hidden');
    post('handling_close');
  }

  document.getElementById('close').addEventListener('click', close);

  document.getElementById('test').addEventListener('click', function () {
    tablet.classList.add('hidden');
    post('handling_test', { values: values });
  });

  document.getElementById('save').addEventListener('click', function () {
    post('handling_save', { values: values });
  });

  window.addEventListener('keydown', function (event) {
    if (tablet.classList.contains('hidden')) return;
    if (event.code === 'Escape') close();
  });

  window.addEventListener('message', function (event) {
    var data = event.data || {};

    if (data.action === 'open') {
      categories = data.categories || [];
      values = data.values || {};
      initial = JSON.parse(JSON.stringify(values));
      active = 0;

      vehicleEl.textContent = data.vehicle || '—';
      setStatus('Ajuste os valores e use Testar para dirigir.', false);

      renderTabs();
      renderFields();
      tablet.classList.remove('hidden');
      return;
    }

    if (data.action === 'close') {
      tablet.classList.add('hidden');
      return;
    }

    if (data.action === 'status') {
      setStatus(data.text || '', data.ok);
    }
  });
})();
