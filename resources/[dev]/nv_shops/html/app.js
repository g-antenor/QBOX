/* ==========================================================================
   nv_shops — NUI

   Vitrine, nada mais. Os precos e o estoque desenhados aqui vieram do
   servidor, e e o servidor que os confere de novo na hora de cobrar: adulterar
   esta tela muda o que o jogador VE, nunca o que ele PAGA.
   ========================================================================== */

const resource = (typeof GetParentResourceName === 'function')
    ? GetParentResourceName()
    : 'nv_shops';

const el = {
    root:        document.getElementById('root'),
    shopTitle:   document.getElementById('shopTitle'),
    categoryList:document.getElementById('categoryList'),
    wallet:      document.getElementById('walletValue'),
    stageTitle:  document.getElementById('stageTitle'),
    search:      document.getElementById('searchInput'),
    grid:        document.getElementById('productGrid'),
    close:       document.getElementById('btnClose'),
    receiptStore:document.getElementById('receiptStore'),
    receiptDate: document.getElementById('receiptDate'),
    receiptCode: document.getElementById('receiptCode'),
    items:       document.getElementById('receiptItems'),
    count:       document.getElementById('rCount'),
    total:       document.getElementById('rTotal'),
    error:       document.getElementById('errorMsg'),
    checkout:    document.getElementById('btnCheckout')
};

// Icone por categoria, preenchido na abertura a partir do que o servidor manda.
let CATEGORY_ICON = {};

const state = {
    shopId: null,
    products: [],
    categories: [],
    cart: {},
    money: 0,
    activeCategory: 'todos',
    search: '',
    sending: false
};

// -------------------------------------------------------------- utilidades --

function money(value) {
    return '$ ' + Math.round(value).toLocaleString('pt-BR');
}

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

function showError(message) {
    if (!message) {
        el.error.classList.add('hidden');
        return;
    }

    el.error.textContent = message;
    el.error.classList.remove('hidden');
}

// ------------------------------------------------------------- categorias --

function renderCategories() {
    el.categoryList.replaceChildren();

    const all = [{ id: 'todos', label: 'Todos', icon: 'ic-todos' }, ...state.categories];

    all.forEach((cat) => {
        const item = make('div', 'side-item' + (cat.id === state.activeCategory ? ' active' : ''));

        item.appendChild(icon(cat.icon || 'ic-todos'));
        item.appendChild(make('span', null, cat.label));

        item.addEventListener('click', () => {
            state.activeCategory = cat.id;
            renderCategories();
            renderProducts();
        });

        el.categoryList.appendChild(item);
    });
}

// --------------------------------------------------------------- produtos --

function stockLabel(product) {
    if (product.stock <= 0) return { text: 'Sem estoque', cls: 'none' };
    if (product.stock <= 5) return { text: `Últimas ${product.stock}`, cls: 'low' };

    return { text: `${product.stock} em estoque`, cls: '' };
}

/** Quanto ainda cabe: estoque menos o que ja esta no carrinho. */
function available(product) {
    const inCart = state.cart[product.name]?.qty || 0;

    return product.stock - inCart;
}

function renderProducts() {
    const cat = state.categories.find((c) => c.id === state.activeCategory);

    el.stageTitle.textContent = state.search
        ? `Resultados para "${state.search}"`
        : (cat ? cat.label : 'Todos os produtos');

    el.grid.replaceChildren();

    const filtered = state.products.filter((p) => {
        const matchesCat = state.activeCategory === 'todos' || p.category === state.activeCategory;
        const matchesSearch = !state.search || p.label.toLowerCase().includes(state.search);

        return matchesCat && matchesSearch;
    });

    if (!filtered.length) {
        el.grid.appendChild(make('div', 'empty-note', 'Nenhum produto encontrado'));
        return;
    }

    filtered.forEach((product) => {
        const out = product.stock <= 0;
        const card = make('div', 'product-card' + (out ? ' out' : ''));
        const iconWrap = make('div', 'product-icon');

        iconWrap.appendChild(icon(CATEGORY_ICON[product.category] || 'ic-todos'));
        card.appendChild(iconWrap);
        card.appendChild(make('div', 'product-name', product.label));
        card.appendChild(make('div', 'product-price', money(product.price)));

        const stock = stockLabel(product);

        card.appendChild(make('div', `product-stock ${stock.cls}`, stock.text));

        if (!out) card.addEventListener('click', () => addToCart(product));

        el.grid.appendChild(card);
    });
}

// --------------------------------------------------------- carrinho / nota --

function addToCart(product) {
    if (state.sending) return;

    // O limite e o estoque real: deixar somar alem disso so adiaria a recusa
    // para depois do clique em "Finalizar".
    if (available(product) <= 0) {
        return showError(`Sem estoque de ${product.label}.`);
    }

    const line = state.cart[product.name];

    if (line) line.qty += 1;
    else state.cart[product.name] = { product, qty: 1 };

    showError(null);
    renderProducts();
    renderReceipt();
}

function changeQty(name, delta) {
    const line = state.cart[name];
    if (!line) return;

    if (delta > 0 && available(line.product) <= 0) {
        return showError(`Sem estoque de ${line.product.label}.`);
    }

    line.qty += delta;

    if (line.qty <= 0) delete state.cart[name];

    showError(null);
    renderProducts();
    renderReceipt();
}

function getTotal() {
    return Object.values(state.cart).reduce((sum, l) => sum + l.product.price * l.qty, 0);
}

function renderReceipt() {
    el.items.replaceChildren();

    const lines = Object.values(state.cart);

    if (!lines.length) {
        el.items.appendChild(make('div', 'receipt-empty', 'Carrinho vazio — escolha um produto ao lado'));
    } else {
        lines.forEach((line) => {
            const row = make('div');
            const head = make('div', 'receipt-item-name');

            head.appendChild(make('span', 'lt', line.product.label));
            head.appendChild(make('span', null, money(line.product.price * line.qty)));
            row.appendChild(head);

            const sub = make('div', 'receipt-item-sub');

            sub.appendChild(make('span', 'receipt-item-unit', `${money(line.product.price)} un`));

            const stepper = make('span', 'qty-stepper');
            const dec = make('span', 'qty-btn', '−');
            const inc = make('span', 'qty-btn', '+');
            const rm = make('span', 'remove-btn', '×');

            dec.addEventListener('click', () => changeQty(line.product.name, -1));
            inc.addEventListener('click', () => changeQty(line.product.name, 1));
            rm.addEventListener('click', () => changeQty(line.product.name, -line.qty));

            stepper.appendChild(dec);
            stepper.appendChild(make('span', 'qty-val', String(line.qty)));
            stepper.appendChild(inc);
            stepper.appendChild(rm);
            sub.appendChild(stepper);

            row.appendChild(sub);
            el.items.appendChild(row);
        });
    }

    const total = getTotal();
    const count = lines.reduce((sum, l) => sum + l.qty, 0);

    el.count.textContent = String(count);
    el.total.textContent = money(total);

    // O botao ja diz por que nao da: descobrir a falta de dinheiro so depois
    // de clicar seria uma viagem inutil.
    const broke = total > state.money;

    el.checkout.disabled = state.sending || !count || broke;
    el.checkout.textContent = broke ? 'Dinheiro insuficiente' : 'Finalizar compra';
}

// ------------------------------------------------------------------ fluxo --

async function checkout() {
    if (state.sending || !Object.keys(state.cart).length) return;

    state.sending = true;
    el.checkout.disabled = true;
    el.checkout.textContent = 'Processando...';

    const cart = Object.values(state.cart).map((l) => ({ name: l.product.name, qty: l.qty }));
    const result = await post('buy', { shopId: state.shopId, cart });

    state.sending = false;

    if (result && result.ok) {
        state.cart = {};
        close();
        return;
    }

    showError((result && result.error) || 'Não foi possível concluir a compra.');
    renderReceipt();
}

function close() {
    if (el.root.classList.contains('hidden')) return;

    el.root.classList.add('hidden');
    post('close');
}

function open(data) {
    state.shopId = data.id;
    state.products = data.products || [];
    state.categories = data.categories || [];
    state.money = data.money || 0;
    state.cart = {};
    state.activeCategory = 'todos';
    state.search = '';
    state.sending = false;

    CATEGORY_ICON = {};
    state.categories.forEach((c) => { CATEGORY_ICON[c.id] = c.icon; });

    el.shopTitle.textContent = data.label || 'Loja';
    el.receiptStore.textContent = (data.label || 'LOJA').toUpperCase();
    el.receiptDate.textContent = new Date().toLocaleString('pt-BR');
    el.receiptCode.textContent = String(data.id).padStart(4, '0') + ' 0000 0000';
    el.wallet.textContent = money(state.money);
    el.search.value = '';

    showError(null);
    renderCategories();
    renderProducts();
    renderReceipt();

    el.root.classList.remove('hidden');
}

// ---------------------------------------------------------------- eventos --

el.search.addEventListener('input', (event) => {
    state.search = event.target.value.trim().toLowerCase();
    renderProducts();
});

el.close.addEventListener('click', close);
el.checkout.addEventListener('click', checkout);

window.addEventListener('message', (event) => {
    const data = event.data;

    if (!data || typeof data.action !== 'string') return;

    if (data.action === 'open') return open(data);
    if (data.action === 'close') return el.root.classList.add('hidden');
});

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') close();
});
