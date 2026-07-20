/* ==========================================================================
   nv_chat - interface
   ========================================================================== */
const chat = document.getElementById('chat');
const messages = document.getElementById('messages');
const inputRow = document.getElementById('inputRow');
const input = document.getElementById('input');
const prefix = document.getElementById('prefix');

let config = {
  fadeAfter: 5,
  maxMessages: 40,
  maxLength: 240,
  defaultChannel: 'local',
  channels: {}
};

let fadeTimer = null;
let isOpen = false;

const post = (name, data) =>
  fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data || {})
  }).catch(() => {});

/* ---------------- visibilidade ---------------- */
function show() {
  clearTimeout(fadeTimer);
  chat.classList.remove('faded');
}

/* Some depois de `fadeAfter` segundos - nunca enquanto estiver digitando. */
function scheduleFade() {
  clearTimeout(fadeTimer);

  if (isOpen) return;

  fadeTimer = setTimeout(() => chat.classList.add('faded'), config.fadeAfter * 1000);
}

/* ---------------- mensagens ---------------- */
function channelOf(name) {
  return config.channels[name] || {};
}

/* Todo texto vindo do jogo entra como texto, nunca como HTML. */
function span(className, text) {
  const el = document.createElement('span');
  el.className = className;
  el.textContent = text;
  return el;
}

function addMessage(data) {
  const channelName = data.channel || config.defaultChannel;
  const channel = channelOf(channelName);

  const line = document.createElement('div');
  line.className = 'msg ' + channelName;

  /* O canal local nao precisa de etiqueta: e o normal. */
  if (channel.label && channelName !== 'local' && channelName !== 'sistema') {
    const tag = span('tag', channel.label);
    if (channel.color) tag.style.color = channel.color;
    line.appendChild(tag);
  }

  if (data.author) {
    let author = data.author;

    /* DM mostra a direcao: "para Fulano" / "de Fulano". */
    if (data.meta && data.meta.direction) {
      author = `${data.meta.direction} ${data.author} [${data.meta.id}]`;
    }

    line.appendChild(span('author', author + ': '));
  }

  line.appendChild(span('body', data.text || ''));
  messages.appendChild(line);

  while (messages.children.length > config.maxMessages) {
    messages.removeChild(messages.firstChild);
  }

  messages.scrollTop = messages.scrollHeight;

  show();
  scheduleFade();
}

/* ---------------- entrada ---------------- */
/* A etiqueta acompanha o comando digitado, para o jogador ver em qual canal
   a mensagem vai sair antes de enviar. */
function updatePrefix() {
  const match = input.value.match(/^\/(\S+)/);
  let label = channelOf(config.defaultChannel).label || 'LOCAL';
  let color = '';

  if (match) {
    const typed = match[1].toLowerCase();

    for (const name in config.channels) {
      const channel = config.channels[name];
      if (channel.internal || !channel.commands) continue;

      if (Object.values(channel.commands).includes(typed)) {
        label = channel.label;
        color = channel.color || '';
        break;
      }
    }
  }

  prefix.textContent = label;
  prefix.style.color = color || '';
}

function openChat() {
  isOpen = true;
  chat.classList.add('open');
  show();

  input.value = '';
  updatePrefix();
  input.focus();
}

function closeChat() {
  isOpen = false;
  chat.classList.remove('open');
  input.value = '';
  input.blur();
  scheduleFade();
}

input.addEventListener('input', () => {
  if (input.value.length > config.maxLength) {
    input.value = input.value.slice(0, config.maxLength);
  }

  updatePrefix();
});

document.addEventListener('keydown', event => {
  if (!isOpen) return;

  if (event.key === 'Enter') {
    event.preventDefault();
    const text = input.value.trim();
    closeChat();
    post('send', { text });
  } else if (event.key === 'Escape') {
    event.preventDefault();
    closeChat();
    post('cancel');
  }
});

/* ---------------- ponte com o cliente ---------------- */
const HANDLERS = {
  config(data) {
    config = Object.assign(config, data);
    updatePrefix();
    scheduleFade();
  },

  open: openChat,
  close: closeChat,
  message: addMessage,

  clear() {
    messages.innerHTML = '';
  }
};

window.addEventListener('message', event => {
  const handler = HANDLERS[event.data.action];
  if (handler) handler(event.data.data);
});

scheduleFade();
post('ready');
