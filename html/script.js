// ============================================================
//  CIRESAR — NUI  (click a cherry → it tumbles in 3D into the
//  basket, and the basket fills up)
// ============================================================

(function () {
    'use strict';

    const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'ciresar';

    // ── i18n (inline — never split NUI lang into a separate file) ──
    const LANG = {
        en: { title: 'Cherry Picking', sub: 'Click the cherries', basket: 'Basket',
              hud: 'Cherry Basket', hintA: 'Click cherries', hintB: 'to close',
              sellTitle: 'Sell Cherries', sellSub: 'Cherry Vendor', have: 'Cherries',
              priceL: 'Price / cherry', estL: 'Estimated', cancel: 'Cancel', sellAll: 'Sell all',
              sold: (n, t) => 'Sold ' + n + ' cherries for ' + t, sellErr: 'Sale failed' },
        ro: { title: 'Cules de Cirese', sub: 'Apasa pe cirese', basket: 'Cos',
              hud: 'Cos cu Cirese', hintA: 'Apasa pe cirese', hintB: 'ca sa inchizi',
              sellTitle: 'Vinde Cirese', sellSub: 'Vanzator Cirese', have: 'Cirese',
              priceL: 'Pret / cireasa', estL: 'Estimat', cancel: 'Anuleaza', sellAll: 'Vinde tot',
              sold: (n, t) => 'Ai vandut ' + n + ' cirese pentru ' + t, sellErr: 'Vanzarea a esuat' },
    };
    let T = LANG.en;

    // ── elements ──
    const $ = (id) => document.getElementById(id);
    const mgEl       = $('mg');
    const stage      = $('stage');
    const cherriesEl = $('cherries');
    const basketSvg  = $('basket-svg');
    const rim        = $('rim');
    const fillRect   = $('fillRect');
    const fillTop    = $('fillTop');

    const mgTitle    = $('mg-title');
    const mgSub      = $('mg-sub');
    const mgCountEl  = $('mg-count');
    const mgCapEl    = $('mg-cap');
    const mgMeterCnt = $('mg-meter-count');
    const mgMeterCap = $('mg-meter-cap');
    const mgMeterFil = $('mg-meter-fill');
    const mgBasketLb = $('mg-basket-label');
    const mgHint     = $('mg-hint');
    const mgCloseBtn = $('mg-close');

    const hud        = $('hud');
    const hudTitle   = $('hud-title');
    const hudCount   = $('hud-count');
    const hudCap     = $('hud-cap');
    const hudFill    = $('hud-fill');

    const sellEl     = $('sell');
    const sellTitle  = $('sell-title');
    const sellSub    = $('sell-sub');
    const sellHaveL  = $('sell-have-lbl');
    const sellHave   = $('sell-have');
    const sellPriceL = $('sell-price-lbl');
    const sellPrice  = $('sell-price');
    const sellEstL   = $('sell-est-lbl');
    const sellEst    = $('sell-est');
    const sellBody   = $('sell-body');
    const sellResult = $('sell-result');
    const sellDone   = $('sell-done-txt');
    const sellFooter = $('sell-footer');
    const sellCancel = $('sell-cancel');
    const sellConfirm= $('sell-confirm');
    const sellX      = $('sell-x');

    // Cherry anchor points (% of the stage) over the tree canopy.
    const CHERRY_SLOTS = [
        { x: 42, y: 14 }, { x: 52, y: 11 }, { x: 60, y: 14 },
        { x: 35, y: 21 }, { x: 48, y: 18 }, { x: 58, y: 19 }, { x: 66, y: 23 },
        { x: 31, y: 30 }, { x: 43, y: 27 }, { x: 53, y: 26 }, { x: 63, y: 29 }, { x: 70, y: 33 },
        { x: 37, y: 38 }, { x: 48, y: 36 }, { x: 58, y: 37 }, { x: 66, y: 41 },
    ];

    // ── state ──
    let mgOpen     = false;
    let mgCount    = 0;
    let mgCapacity = 50;
    let curFill    = 0;       // 0..1 (basket fill, smoothed)
    let fillRaf    = null;
    let audioCtx   = null;

    // ── basket fill geometry (SVG units) ──
    const F_BOTTOM = 131, F_TOP = 58, F_RANGE = F_BOTTOM - F_TOP;

    function setFillImmediate(pct) {
        curFill = Math.max(0, Math.min(1, pct));
        const h = curFill * F_RANGE;
        fillRect.setAttribute('y', F_BOTTOM - h);
        fillRect.setAttribute('height', h);
        fillTop.setAttribute('cy', F_BOTTOM - h);
        fillTop.setAttribute('opacity', h > 2 ? 0.9 : 0);
        fillTop.setAttribute('rx', 46 + 14 * curFill);   // surface widens toward the rim
    }

    function tweenFill(target) {
        target = Math.max(0, Math.min(1, target));
        if (fillRaf) cancelAnimationFrame(fillRaf);
        const start = curFill, t0 = performance.now(), dur = 430;
        (function step(now) {
            const k = Math.min(1, (now - t0) / dur);
            const e = 1 - Math.pow(1 - k, 3);
            setFillImmediate(start + (target - start) * e);
            if (k < 1) fillRaf = requestAnimationFrame(step); else fillRaf = null;
        })(t0);
    }

    // ── sound (Web Audio, no asset files) ──
    function chime() {
        try {
            if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
            const osc = audioCtx.createOscillator(), g = audioCtx.createGain();
            osc.connect(g); g.connect(audioCtx.destination);
            const t = audioCtx.currentTime;
            osc.type = 'triangle';
            osc.frequency.setValueAtTime(950, t);
            osc.frequency.exponentialRampToValueAtTime(520, t + 0.11);
            g.gain.setValueAtTime(0.28, t);
            g.gain.exponentialRampToValueAtTime(0.001, t + 0.17);
            osc.start(t); osc.stop(t + 0.17);
        } catch (e) {}
    }

    // ── display sync ──
    function updateDisplay(count, animate) {
        mgCount = count;
        mgCountEl.textContent  = count;
        mgMeterCnt.textContent = count;
        const pct = mgCapacity > 0 ? count / mgCapacity : 0;
        mgMeterFil.style.width = (pct * 100) + '%';
        if (animate) tweenFill(pct); else setFillImmediate(pct);
    }

    function plusOne() {
        const r = rim.getBoundingClientRect();
        const s = stage.getBoundingClientRect();
        const p = document.createElement('div');
        p.className = 'plus-one';
        p.textContent = '+1';
        p.style.left = (r.left - s.left + r.width / 2) + 'px';
        p.style.top  = (r.top  - s.top  - 6) + 'px';
        stage.appendChild(p);
        setTimeout(() => p.remove(), 900);
    }

    function basketBounce() {
        basketSvg.animate([
            { transform: 'translateY(0) scale(1,1)' },
            { transform: 'translateY(2px) scale(1.05,0.93)', offset: 0.4 },
            { transform: 'translateY(0) scale(1,1)' },
        ], { duration: 260, easing: 'cubic-bezier(.34,1.4,.64,1)' });
    }

    function post(name, body) {
        fetch(`https://${RES}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body || {}),
        }).catch(() => {});
    }

    // ── the money shot: cherry detaches, tumbles, drops into the basket ──
    function onCherryClick(cherry) {
        if (cherry.classList.contains('gone')) return;
        cherry.classList.add('gone');

        post('pick', {});   // tell the server immediately

        const c = cherry.getBoundingClientRect();
        const r = rim.getBoundingClientRect();
        const dx = (r.left + r.width / 2) - (c.left + c.width / 2);
        const dy = (r.top  + r.height * 0.35) - (c.top + c.height / 2);
        const spin = Math.random() < 0.5 ? 1 : -1;

        const anim = cherry.animate([
            { transform: 'translate(-50%,0) translate3d(0,0,0) rotateX(0deg) rotateZ(0deg) scale(1)', opacity: 1, offset: 0 },
            { transform: `translate(-50%,0) translate3d(${dx * 0.22}px,-34px,110px) rotateX(150deg) rotateZ(${spin * 120}deg) scale(1.12)`, opacity: 1, offset: 0.30 },
            { transform: `translate(-50%,0) translate3d(${dx * 0.62}px,${dy * 0.5}px,30px) rotateX(330deg) rotateZ(${spin * 260}deg) scale(0.82)`, opacity: 1, offset: 0.62 },
            { transform: `translate(-50%,0) translate3d(${dx}px,${dy}px,-45px) rotateX(520deg) rotateZ(${spin * 420}deg) scale(0.46)`, opacity: 1, offset: 0.92 },
            { transform: `translate(-50%,0) translate3d(${dx}px,${dy + 12}px,-75px) rotateX(560deg) scale(0.30)`, opacity: 0, offset: 1 },
        ], { duration: 740, easing: 'cubic-bezier(.45,.05,.55,.95)', fill: 'forwards' });

        chime();

        anim.onfinish = () => {
            cherry.remove();
            mgCount = Math.min(mgCount + 1, mgCapacity);
            updateDisplay(mgCount, true);
            plusOne();
            basketBounce();
            checkEnd();
        };
    }

    function checkEnd() {
        if (mgCount >= mgCapacity) { setTimeout(closeMinigame, 650); return; }
        if (cherriesEl.querySelectorAll('.cherry:not(.gone)').length === 0) {
            setTimeout(closeMinigame, 750);
        }
    }

    function openMinigame(cherryCount, current, capacity, lang) {
        applyLang(lang || 'en');
        mgCapacity = capacity;
        mgCount    = current;
        mgOpen     = true;
        mgCapEl.textContent    = capacity;
        mgMeterCap.textContent = capacity;
        updateDisplay(current, false);

        cherriesEl.innerHTML = '';
        stage.querySelectorAll('.plus-one').forEach((e) => e.remove());

        const slots = [...CHERRY_SLOTS]
            .sort(() => Math.random() - 0.5)
            .slice(0, Math.min(cherryCount, CHERRY_SLOTS.length));

        slots.forEach((s) => {
            const c = document.createElement('div');
            c.className = 'cherry';
            c.style.left = s.x + '%';
            c.style.top  = s.y + '%';
            c.addEventListener('click', () => onCherryClick(c));
            cherriesEl.appendChild(c);
        });

        mgEl.classList.remove('uk-hidden');
    }

    function closeMinigame() {
        if (!mgOpen) return;
        mgOpen = false;
        mgEl.classList.add('uk-hidden');
        const remaining = cherriesEl.querySelectorAll('.cherry:not(.gone)').length;
        post('close', { remaining });
    }

    function applyLang(l) {
        T = LANG[l] || LANG.en;
        mgTitle.textContent    = T.title;
        mgSub.textContent      = T.sub;
        mgBasketLb.textContent = T.basket;
        mgHint.innerHTML       = T.hintA + ' · <b>ESC</b> ' + T.hintB;
        hudTitle.textContent   = T.hud;
    }

    // ── sell panel ──
    function money(n) { return '$' + Math.round(n).toLocaleString('en-US'); }

    function openSell(count, pmin, pmax) {
        sellTitle.textContent   = T.sellTitle;
        sellSub.textContent     = T.sellSub;
        sellHaveL.textContent   = T.have;
        sellPriceL.textContent  = T.priceL;
        sellEstL.textContent    = T.estL;
        sellCancel.textContent  = T.cancel;
        sellConfirm.textContent = T.sellAll;

        sellHave.textContent  = count;
        sellPrice.textContent = money(pmin) + ' – ' + money(pmax);
        sellEst.textContent   = money(count * pmin) + ' – ' + money(count * pmax);

        sellBody.classList.remove('uk-hidden');
        sellResult.classList.add('uk-hidden');
        sellFooter.classList.remove('uk-hidden');
        sellConfirm.classList.remove('disabled');
        sellEl.classList.remove('uk-hidden');
    }

    function closeSell() {
        if (sellEl.classList.contains('uk-hidden')) return;
        sellEl.classList.add('uk-hidden');
        post('sellClose', {});
    }

    function doSell() {
        if (sellConfirm.classList.contains('disabled')) return;
        sellConfirm.classList.add('disabled');
        post('sellConfirm', {});
    }

    function showSellResult(data) {
        sellDone.textContent = data.error ? T.sellErr : T.sold(data.count, money(data.total));
        sellDone.style.color = data.error ? 'var(--bad)' : 'var(--good)';
        sellBody.classList.add('uk-hidden');
        sellFooter.classList.add('uk-hidden');
        sellResult.classList.remove('uk-hidden');
        setTimeout(closeSell, 1700);
    }

    // ── own toast (only used when core_ui is absent) ──
    function showToast(kind, msg) {
        const wrap = $('toast');
        const el = document.createElement('div');
        const cls = kind === 'good' ? ' good' : kind === 'warn' ? ' warn' : kind === 'bad' ? ' bad' : '';
        el.className = 'uk-toast' + cls;
        el.textContent = msg;
        wrap.appendChild(el);
        setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 250); }, 3200);
    }

    // ── input ──
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' || e.keyCode === 27) {
            if (mgOpen) closeMinigame();
            else if (!sellEl.classList.contains('uk-hidden')) closeSell();
        }
    });
    mgCloseBtn.addEventListener('click', closeMinigame);
    sellCancel.addEventListener('click', closeSell);
    sellX.addEventListener('click', closeSell);
    sellConfirm.addEventListener('click', doSell);

    // ── message router ──
    window.addEventListener('message', (event) => {
        let data = event.data;
        if (typeof data === 'string') { try { data = JSON.parse(data); } catch (e) { return; } }
        if (!data || !data.type) return;

        switch (data.type) {
            case 'open':
                openMinigame(data.cherryCount, data.current || 0, data.capacity || 50, data.lang);
                break;
            case 'hud':
                // Persistent HUD follows the server. The minigame counter stays
                // purely optimistic (cherries in flight would otherwise be
                // double-counted) — it's capped at capacity and selling is
                // server-authoritative, so it can't be exploited.
                hudCount.textContent = data.count;
                hudCap.textContent   = data.capacity;
                hudFill.style.width  = ((data.count / data.capacity) * 100) + '%';
                break;
            case 'showHUD':
                hud.classList.remove('uk-hidden');
                break;
            case 'hideHUD':
                hud.classList.add('uk-hidden');
                break;
            case 'sell':
                applyLang(data.lang || 'en');
                openSell(data.count || 0, data.priceMin || 0, data.priceMax || 0);
                break;
            case 'sellResult':
                showSellResult(data);
                break;
            case 'toast':
                showToast(data.kind, data.message || '');
                break;
        }
    });

})();
