/* مكتبة الخلفيات الحية — وحدة منفصلة تحمل عند فتح اللوحة فقط (7: dynamic import).
   لا تحفظ روابط ملفات المزودين في أي مكان دائم: المفضلة تحفظ {provider, mediaId, type} فقط.
   المعاينة من روابط المزود مباشرة (عرض مؤقت)، والملف الكامل يجلبه الخادم عند الإنشاء ثم يحذفه. */
const $ = (s, r = document) => r.querySelector(s);
const FAV_KEY = 'ayt_bg_favs';
const ST = { type: 'image', col: 'sky', q: '', page: 1, items: [], busy: false, done: false, playing: null, dlg: null, mode: 'search', orient: '' };
let OPT = window.AYT_OPT || (window.AYT_OPT = { dim: 35, blur: '', slow: '' });

function favs() { try { return JSON.parse(localStorage.getItem(FAV_KEY) || '[]').filter(f => f && f.provider && f.mediaId && f.type) } catch (e) { return [] } }
function saveFavs(a) { try { localStorage.setItem(FAV_KEY, JSON.stringify(a.map(f => ({ provider: f.provider, mediaId: String(f.mediaId), type: f.type })))) } catch (e) { } }
function isFav(it) { return favs().some(f => f.provider === it.provider && f.mediaId === String(it.mediaId) && f.type === it.type) }
function toggleFav(it) { let a = favs(); if (isFav(it)) a = a.filter(f => !(f.provider === it.provider && f.mediaId === String(it.mediaId) && f.type === it.type)); else a.unshift({ provider: it.provider, mediaId: String(it.mediaId), type: it.type }); saveFavs(a.slice(0, 60)) }
const PNAME = { pixabay: 'Pixabay', pexels: 'Pexels' };
const PURL = { pixabay: 'https://pixabay.com/', pexels: 'https://www.pexels.com/' };
const esc = s => String(s || '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function preconnect() {
  for (const h of ['https://cdn.pixabay.com', 'https://pixabay.com', 'https://images.pexels.com', 'https://videos.pexels.com']) {
    if (document.querySelector(`link[rel=preconnect][href="${h}"]`)) continue;
    const l = document.createElement('link'); l.rel = 'preconnect'; l.href = h; l.crossOrigin = ''; document.head.appendChild(l);
  }
}

const CSS = `.bglib{width:min(980px,calc(100vw - 24px));max-height:calc(100vh - 24px);display:flex;flex-direction:column}
.bglib[open]{display:flex}.bglib .bglib-body{padding:14px 16px 18px;overflow-y:auto;text-align:center}
.bglib-note{margin:0 0 10px;font-size:var(--text-sm);color:var(--c-text-muted)}
.bglib-tabs{max-width:420px;margin:0 auto 12px}
.bglib-cols{justify-content:center;flex-wrap:nowrap;overflow-x:auto;padding:2px 2px 8px;scrollbar-width:thin}
.bglib-cols button{flex:none;min-height:40px}
.bglib-cols button[aria-pressed=true]{background:var(--c-primary);border-color:var(--c-primary);color:var(--c-on-primary)}
.bglib-q{max-width:520px;margin:8px auto 14px;display:block}
.bglib-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;text-align:start}
@media(max-width:700px){.bglib-grid{grid-template-columns:repeat(2,1fr)}}
.bglib-item{position:relative;border-radius:var(--r-card);overflow:hidden;background:var(--c-surface-2);aspect-ratio:3/4}
.bglib-item.skel{min-height:0}
.bglib-pick{all:unset;cursor:pointer;display:block;position:absolute;inset:0}
.bglib-pick:focus-visible{outline:3px solid var(--c-focus);outline-offset:-3px}
.bglib-pick img,.bglib-vid{position:absolute;inset:0;width:100%;height:100%;object-fit:cover}
.bglib-badge{position:absolute;top:8px;inset-inline-start:8px;background:rgba(11,31,23,.75);color:#fff;font-size:11.5px;border-radius:999px;padding:1px 8px}
.bglib-fav,.bglib-rep{position:absolute;top:6px;border:0;border-radius:999px;background:rgba(255,255,255,.88);color:#2C5E37;cursor:pointer;min-width:34px;height:34px;font:600 12px/1 var(--f-ui);padding:0 9px}
.bglib-fav{inset-inline-end:6px;font-size:16px}.bglib-fav[aria-pressed=true]{background:#2C5E37;color:#fff}
.bglib-rep{inset-inline-end:46px;opacity:0;transition:opacity .2s}
.bglib-item:hover .bglib-rep,.bglib-item:focus-within .bglib-rep{opacity:1}
@media(hover:none){.bglib-rep{opacity:1}}
.bglib-by{position:absolute;inset:auto 0 0 0;padding:16px 8px 6px;font-size:11px;color:#fff;background:linear-gradient(transparent,rgba(0,0,0,.6));white-space:nowrap;overflow:hidden;text-overflow:ellipsis;pointer-events:none}
.bglib-empty{color:var(--c-text-muted);margin:24px 0}
.bglib-more{height:1px}
.bglib-attr{font-size:var(--text-xs);color:var(--c-text-muted);margin:16px 0 0}
.bglib-sel{display:grid;grid-template-columns:72px 1fr;gap:8px 12px;align-items:center;margin-top:12px;padding:10px;border:1px solid var(--c-line);border-radius:var(--r-card);background:var(--c-surface);text-align:start}
.bglib-sel img{width:72px;height:72px;object-fit:cover;border-radius:8px}
.bglib-sel b{display:block;font-size:var(--text-sm)}.bglib-sel span{font-size:var(--text-xs);color:var(--c-text-muted)}
.bglib-sel #bgLibClear{grid-column:1/-1;justify-self:start;font-size:var(--text-xs)}
.bglib-opts{grid-column:1/-1;display:flex;flex-wrap:wrap;gap:8px 16px;align-items:center}
.bglib-opts label{display:flex;align-items:center;gap:8px;margin:0;font-weight:500;font-size:var(--text-sm)}
.bglib-opts input[type=range]{width:140px;accent-color:var(--c-primary)}
.bglib-opts select{width:auto;padding:6px 10px}
.bglib-credit{font-size:var(--text-xs);color:var(--c-text-muted);margin:8px 0 0;text-align:center}`;
function css() { if (document.getElementById('bglibCss')) return; const s = document.createElement('style'); s.id = 'bglibCss'; s.textContent = CSS; document.head.appendChild(s) }
css();

function build() {
  const d = document.createElement('dialog'); d.className = 'modal bglib'; d.setAttribute('aria-labelledby', 'bglibT');
  d.innerHTML = `<div class="mh"><b id="bglibT">مكتبة الخلفيات</b><button type="button" class="x" aria-label="إغلاق">×</button></div>
<div class="bglib-body">
<p class="bglib-note">اختر خلفية تليق بكلام الله</p>
<div class="seg bglib-tabs" role="tablist"><label><input type="radio" name="bgltype" value="image" checked><span>صور</span></label><label><input type="radio" name="bgltype" value="video"><span>فيديو متحرك</span></label><label><input type="radio" name="bgltype" value="fav"><span>مفضلتي</span></label></div>
<div class="chips bglib-cols" role="group" aria-label="المجموعات"></div>
<input type="search" class="bglib-q" placeholder="ابحث: سماء، بحر، مطر…" aria-label="ابحث عن خلفية">
<div class="bglib-grid" role="list"></div>
<p class="bglib-empty" hidden>لم نجد خلفيات مناسبة. جرب كلمة أخرى أو اختر من المجموعات</p>
<div class="bglib-more" aria-hidden="true"></div>
<p class="bglib-attr">الخلفيات من <a href="https://pixabay.com/" target="_blank" rel="noopener">Pixabay</a> و<a href="https://www.pexels.com/" target="_blank" rel="noopener">Pexels</a></p>
</div>`;
  document.body.appendChild(d);
  $('.x', d).onclick = () => d.close();
  d.addEventListener('close', stopAll);
  d.querySelectorAll('input[name=bgltype]').forEach(r => r.onchange = () => { ST.type = r.value === 'fav' ? ST.type : r.value; ST.mode = r.value === 'fav' ? 'fav' : 'search'; reset() });
  let t; $('.bglib-q', d).oninput = e => { clearTimeout(t); t = setTimeout(() => { ST.q = e.target.value.trim(); ST.col = ST.q ? '' : 'sky'; paintCols(); reset() }, 600) };
  const io = new IntersectionObserver(es => { if (es.some(e => e.isIntersecting)) load() }, { root: $('.bglib-body', d), rootMargin: '400px' });
  io.observe($('.bglib-more', d));
  return d;
}

let COLS = [];
function paintCols() {
  const box = $('.bglib-cols', ST.dlg);
  box.innerHTML = COLS.map(c => `<button type="button" data-c="${c.id}" aria-pressed="${ST.col === c.id}">${esc(c.label)}</button>`).join('');
  box.querySelectorAll('button').forEach(b => b.onclick = () => { ST.col = b.dataset.c; ST.q = ''; $('.bglib-q', ST.dlg).value = ''; paintCols(); reset() });
}

function skeleton(n) { return Array.from({ length: n }, () => '<div class="bglib-item skel" aria-hidden="true"></div>').join('') }

function reset() { ST.page = 1; ST.items = []; ST.done = false; $('.bglib-grid', ST.dlg).innerHTML = skeleton(8); $('.bglib-empty', ST.dlg).hidden = true; load(true) }

async function load(first) {
  if (ST.busy || ST.done) return; ST.busy = true;
  const grid = $('.bglib-grid', ST.dlg);
  try {
    let items = [];
    if (ST.mode === 'fav') {
      const fs = favs();
      items = (await Promise.all(fs.map(f => fetch(`/api/media/item?provider=${f.provider}&id=${encodeURIComponent(f.mediaId)}&type=${f.type}`).then(r => r.ok ? r.json() : null).catch(() => null)))).filter(Boolean);
      ST.done = true;
    } else {
      const p = new URLSearchParams({ type: ST.type, q: ST.q, category: ST.q ? '' : ST.col, page: ST.page, orientation: ST.orient });
      const j = await fetch('/api/media/search?' + p).then(r => r.json());
      items = j.items || []; ST.page++; if (!items.length || ST.page > 10) ST.done = true;
    }
    if (first) grid.innerHTML = '';
    grid.insertAdjacentHTML('beforeend', items.map((it, i) => card(it, ST.items.length + i)).join(''));
    ST.items.push(...items);
    bindItems();
    if (!ST.items.length) $('.bglib-empty', ST.dlg).hidden = false;
  } catch (e) {
    if (first) grid.innerHTML = ''; ST.done = true;
    if (!ST.items.length) $('.bglib-empty', ST.dlg).hidden = false;
  } finally { ST.busy = false }
}

function card(it, i) {
  const w = 240, h = Math.round(w * ((it.height || 9) / (it.width || 16))) || 135;
  return `<div class="bglib-item" role="listitem" data-i="${i}">
<button type="button" class="bglib-pick" aria-label="اختيار خلفية ${it.type === 'video' ? 'فيديو' : 'صورة'} من ${PNAME[it.provider]}">
<img src="${esc(it.thumbUrl)}" alt="" loading="lazy" decoding="async" width="${w}" height="${Math.min(h, 427)}">
${it.type === 'video' ? '<span class="bglib-badge">فيديو</span>' : ''}</button>
<button type="button" class="bglib-fav" aria-pressed="${isFav(it)}" aria-label="أضف إلى المفضلة">♥</button>
<button type="button" class="bglib-rep" aria-label="إبلاغ عن خلفية غير مناسبة">إبلاغ</button>
</div>`;
}

function stopAll() { if (ST.playing) { ST.playing.pause(); ST.playing.remove(); ST.playing = null } }
function play(el, it) {
  if (it.type !== 'video' || !it.previewUrl) return;
  stopAll();
  const v = document.createElement('video'); v.muted = true; v.defaultMuted = true; v.playsInline = true; v.setAttribute('playsinline', ''); v.loop = true; v.preload = 'none'; v.src = it.previewUrl; v.className = 'bglib-vid';
  el.querySelector('.bglib-pick').appendChild(v); v.play().catch(() => { }); ST.playing = v;
}

function bindItems() {
  ST.dlg.querySelectorAll('.bglib-item:not([data-b])').forEach(el => {
    el.dataset.b = 1; const it = ST.items[+el.dataset.i]; if (!it) return;
    const pick = el.querySelector('.bglib-pick');
    pick.onclick = () => choose(it);
    pick.onmouseenter = () => play(el, it); pick.onmouseleave = stopAll;
    let lp; pick.addEventListener('touchstart', () => { lp = setTimeout(() => play(el, it), 450) }, { passive: true });
    pick.addEventListener('touchend', () => clearTimeout(lp));
    el.querySelector('.bglib-fav').onclick = e => { toggleFav(it); e.currentTarget.setAttribute('aria-pressed', isFav(it)) };
    el.querySelector('.bglib-rep').onclick = e => {
      fetch('/api/media/report', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ provider: it.provider, mediaId: it.mediaId }) }).catch(() => { });
      el.remove(); try { track('bg_report', { provider: it.provider }) } catch (_) { }
    };
  });
}

function choose(it) {
    window.AYT_BG_AUTO = false;
  window.AYT_RM = `${it.provider}:${it.mediaId}:${it.type}`;
  window.AYT_CREDIT = { provider: it.provider, authorName: it.authorName, authorUrl: it.authorUrl, pageUrl: it.pageUrl };
  showSel(it);
  ST.dlg.close();
  try { track('bg_library_pick', { provider: it.provider, type: it.type }) } catch (_) { }
  if (typeof window.AYT_BG_CHANGED === 'function') window.AYT_BG_CHANGED();
}

function showSel(it) {
  const box = $('#bgLibSel'); if (!box) return;
  box.hidden = false;
  box.innerHTML = `<img src="${esc(it.thumbUrl)}" alt="" width="72" height="72" decoding="async">
<div><b>${it.type === 'video' ? 'خلفية فيديو متحرك' : 'خلفية صورة'}</b>
</div>
<button type="button" class="linkbtn" id="bgLibClear">الرجوع للخلفيات المدمجة</button>
<div class="bglib-opts">
<label>تعتيم الخلفية <output id="bgDimV">${OPT.dim}%</output><input type="range" id="bgDim" min="0" max="60" step="5" value="${OPT.dim}"></label>
<label class="switch"><input type="checkbox" id="bgBlur" ${OPT.blur ? 'checked' : ''}>تمويه خفيف</label>
${it.type === 'video' ? `<label>إبطاء الخلفية <select id="bgSlow"><option value="">بلا إبطاء</option><option value="0.75" ${OPT.slow === '0.75' ? 'selected' : ''}>0.75x</option><option value="0.5" ${OPT.slow === '0.5' ? 'selected' : ''}>0.5x</option></select></label>` : ''}
</div>`;
  $('#bgLibClear').onclick = () => { window.AYT_RM = ''; window.AYT_CREDIT = null; box.hidden = true; box.innerHTML = ''; if (window.AYT_BG_CHANGED) window.AYT_BG_CHANGED(); document.dispatchEvent(new Event('ayt-bg')) };
  $('#bgDim').oninput = e => { OPT.dim = +e.target.value; $('#bgDimV').textContent = OPT.dim + '%' };
  $('#bgDim').onchange = () => window.AYT_BG_CHANGED && window.AYT_BG_CHANGED();
  $('#bgBlur').onchange = e => { OPT.blur = e.target.checked ? '1' : ''; window.AYT_BG_CHANGED && window.AYT_BG_CHANGED() };
  const sl = $('#bgSlow'); if (sl) sl.onchange = e => { OPT.slow = e.target.value };
}

export async function open(orientation) {
  preconnect();
  ST.orient = orientation || '';
  if (!ST.dlg) {
    ST.dlg = build();
    try { const j = await fetch('/api/media/collections').then(r => r.json()); COLS = j.collections || [] } catch (e) { COLS = [] }
    paintCols();
  }
  ST.dlg.showModal();
  reset();
}

/* الخلفية الافتراضية في كل التصاميم (طلب المالك، 1 نوفمبر 2026): صورة مسجد من المجموعة المعتمدة،
   ثم الليل، وإن تعذرت المكتبة تبقى الخلفيات المدمجة كما هي. لا يغير أي اختيار قام به الزائر. */
export function select(it, auto) {
    if (!it || !it.provider || !it.mediaId) return false;
    window.AYT_RM = `${it.provider}:${it.mediaId}:${it.type || 'image'}`;
    window.AYT_CREDIT = { provider: it.provider, authorName: it.authorName, authorUrl: it.authorUrl, pageUrl: it.pageUrl };
    window.AYT_BG_AUTO = !!auto;
    showSel(it);
    if (typeof window.AYT_BG_CHANGED === 'function') window.AYT_BG_CHANGED();
    document.dispatchEvent(new Event('ayt-bg'));
    return true;
}
export async function selectRm(rm) {
    const p = String(rm || '').split(':');
    if (p.length !== 3 || !p[1] || !PNAME[p[0]]) return false;
    try {
        const r = await fetch(`/api/media/item?provider=${encodeURIComponent(p[0])}&id=${encodeURIComponent(p[1])}&type=${p[2] === 'video' ? 'video' : 'image'}`);
        if (!r.ok) return false;
        return select(await r.json(), false);
    } catch (e) { return false }
}
export async function pickDefault(orientation, busy) {
    for (const c of ['mosques', 'night']) {
        try {
            const j = await fetch(`/api/media/search?type=image&category=${c}&page=1${orientation ? '&orientation=' + orientation : ''}`).then(r => r.json());
            const all = (j.items || []).filter(x => x && x.mediaId), cur = all.filter(x => x.curated), pool = cur.length ? cur : all.slice(0, 6);
            if (!pool.length) continue;
            if (window.AYT_RM || (busy && busy())) return true;
            return select(pool[Math.floor(Math.random() * pool.length)], true);
        } catch (e) { }
    }
    return false;
}

/* شريط اختيار سريع بجوار الخلفية المختارة: صور المساجد المعتمدة فقط (بعد فحص بصري) */
export async function quickStrip(box, cols) {
    if (typeof box === 'string') box = $(box);
    if (!box) return;
    if (!document.getElementById('bgqCss')) {
        const st = document.createElement('style'); st.id = 'bgqCss';
        st.textContent = '.bgq{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:8px;width:100%;max-width:100%;margin-bottom:10px}'
            + '.bgq button{display:block;width:100%;min-width:0;aspect-ratio:3/4;height:auto;padding:0;border:2px solid transparent;border-radius:12px;overflow:hidden;background:var(--c-surface-2);cursor:pointer}'
            + '.bgq button[aria-pressed=true]{border-color:var(--c-accent);box-shadow:0 0 0 2px var(--c-surface) inset}'
            + '.bgq button:focus-visible{outline:2px solid var(--c-focus,var(--c-accent));outline-offset:2px}'
            + '.bgq img{width:100%;height:100%;object-fit:cover;display:block}';
        document.head.appendChild(st);
    }
    let items = [];
    for (const c of (cols || ['mosques'])) {
        try { const j = await fetch(`/api/media/search?type=image&category=${c}&page=1`).then(r => r.json()); items = items.concat((j.items || []).filter(x => x && x.curated && x.mediaId)).slice(0, 10) } catch (e) { }
    }
    if (!items.length) return;
    box.innerHTML = ''; box.classList.add('bgq'); box.setAttribute('role', 'group'); box.setAttribute('aria-label', 'صور مساجد');
    const mark = () => box.querySelectorAll('button').forEach(b => b.setAttribute('aria-pressed', String(window.AYT_RM === b.dataset.rm)));
    for (const it of items) {
        const b = document.createElement('button');
        b.type = 'button'; b.dataset.rm = `${it.provider}:${it.mediaId}:${it.type}`; b.title = 'استخدم هذه الخلفية';
        b.innerHTML = `<img src="${esc(it.thumbUrl)}" alt="" loading="lazy" width="72" height="104">`;
        b.onclick = () => { select(it, false); mark() };
        box.appendChild(b);
    }
    mark(); box.hidden = false;
    document.addEventListener('ayt-bg', mark);
}
