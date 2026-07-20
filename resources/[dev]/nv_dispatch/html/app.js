/* ==========================================================================
   nv_dispatch — NUI

   Desenha alertas e os remove sozinha. Nao recebe cliques: a tela nunca tem
   foco, entao tudo que o jogador pode fazer com um alerta e pela tecla que o
   proprio cartao anuncia.
   ========================================================================== */

const stack = document.getElementById('stack');

/* Quantos cartoes ficam empilhados. O cliente manda o valor do config junto do
   primeiro alerta; ate la, um padrao razoavel. */
let maxOnScreen = 4;

function svg(id) {
    const node = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    const use = document.createElementNS('http://www.w3.org/2000/svg', 'use');

    use.setAttribute('href', `#${id}`);
    node.appendChild(use);

    return node;
}

function make(tag, className, text) {
    const node = document.createElement(tag);

    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;

    return node;
}

function remove(card) {
    if (card.dataset.leaving) return;

    card.dataset.leaving = '1';
    card.classList.add('leaving');

    /* Espera a animacao de saida terminar. `animationend` seria mais preciso,
       mas um cartao removido enquanto a aba esta oculta nunca dispara o evento
       e ficaria na tela para sempre. */
    setTimeout(() => card.remove(), 300);
}

function build(alert, duration, markKey) {
    const card = make('div', 'alert');

    card.style.setProperty('--prio', `var(--${alert.priority || 'media'})`);

    const head = make('div', 'head');

    head.appendChild(svg(alert.icon || 'ic-pino'));
    head.appendChild(make('div', 'title', alert.label || 'Ocorrencia'));

    if (alert.code) head.appendChild(make('span', 'code', alert.code));

    card.appendChild(head);

    if (alert.detail) card.appendChild(make('div', 'detail', alert.detail));

    const foot = make('div', 'foot');

    foot.appendChild(svg('ic-pino'));
    foot.appendChild(make('span', 'street', alert.street || 'Local desconhecido'));

    if (markKey) foot.appendChild(make('span', 'key', `${markKey} · rota`));

    card.appendChild(foot);

    /* A contagem e feita por transicao de CSS em vez de requestAnimationFrame:
       sao ate quatro barras vivas ao mesmo tempo e nenhuma precisa de precisao
       de frame — precisam apenas ir chegando ao fim. */
    const timer = make('div', 'timer');
    const fill = make('div', 'timer-fill');

    timer.appendChild(fill);
    card.appendChild(timer);

    stack.prepend(card);

    requestAnimationFrame(() => {
        fill.style.transition = `transform ${duration}ms linear`;
        fill.style.transform = 'scaleX(0)';
    });

    setTimeout(() => remove(card), duration);

    /* Poda pelo fim da pilha: o cartao mais antigo e o de baixo, porque os
       novos entram por cima. */
    while (stack.children.length > maxOnScreen) {
        remove(stack.lastElementChild);
    }
}

window.addEventListener('message', (event) => {
    const data = event.data;

    if (!data || data.action !== 'alert' || !data.alert) return;

    if (Number.isFinite(data.maxOnScreen)) maxOnScreen = data.maxOnScreen;

    build(data.alert, Number(data.duration) || 15000, data.markKey);
});
