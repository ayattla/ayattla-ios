# cards v4 (owner audit, 2026-11-10) for ayattla.com styles/theme.css (run inside /root/ayattla-repo). Cards only; page backgrounds untouched.
p = 'styles/theme.css'; s = open(p, encoding='utf-8').read()
assert 'tool cards accents v1' in s and 'cards v4' not in s
CSS = '''
/* cards v4 (2026-11-10، تدقيق المالك): مسافات وظلال ناعمة، أيقونات بتدرج لون الأداة، بطاقة مميزة بعرض الشبكة، عمودان على الجوال، شارة «جديد»، بحث وفلاتر ثابتة في صفحة الأدوات. البطاقات فقط، خلفيات الصفحات كما هي */
nav.tools{gap:18px!important}
nav.tools a{border:1px solid #E3EBE5!important;box-shadow:0 4px 6px -1px rgba(15,31,23,.05),0 2px 4px -2px rgba(15,31,23,.04)!important;transition:transform .2s cubic-bezier(.2,.7,.1,1),box-shadow .2s,border-color .2s}
nav.tools a:is(:hover,:focus-visible){box-shadow:0 14px 28px -14px rgba(15,31,23,.22)!important;transform:translateY(-2px)}
nav.tools a .ico{background:linear-gradient(135deg,color-mix(in srgb,var(--tacc,#2E9145) 20%,#fff),color-mix(in srgb,var(--tacc,#2E9145) 7%,#fff))!important;color:var(--tacc,#2E9145)!important;border-radius:16px!important;box-shadow:inset 0 0 0 1px color-mix(in srgb,var(--tacc,#2E9145) 22%,transparent)}
nav.tools a:is(:hover,:focus-visible) .ico{background:linear-gradient(135deg,var(--tacc,#2E9145),color-mix(in srgb,var(--tacc,#2E9145) 72%,#000))!important;color:#fff!important}
nav.tools em.new{background:linear-gradient(135deg,rgba(226,176,74,.24),rgba(46,145,69,.12))!important;border:1px solid rgba(226,176,74,.4);color:#7A5F28!important;border-radius:999px!important;font-weight:600}
nav.tools a[href="/tools/ayah-card"]{grid-column:1/-1;flex-direction:row!important;justify-content:center;align-items:center;gap:18px;text-align:start;background:linear-gradient(135deg,#fff 0%,color-mix(in srgb,#2E9145 7%,#fff) 100%)!important;border-color:color-mix(in srgb,#2E9145 30%,#E3EBE5)!important}
nav.tools a[href="/tools/ayah-card"] .ico{width:60px!important;height:60px!important;flex:0 0 60px}
[data-theme=dark] nav.tools a{border-color:var(--c-line,#1E3A30)!important}
[data-theme=dark] nav.tools a .ico{background:color-mix(in srgb,var(--tacc,#2E9145) 22%,var(--c-surface))!important}
[data-theme=dark] nav.tools a[href="/tools/ayah-card"]{background:var(--c-surface)!important}
[data-theme=dark] nav.tools em.new{color:#E7C982!important}
#tf button{transition:background .2s,color .2s,transform .15s}
#tf button:active{transform:scale(.97)}
@media (min-width:641px){main>.tools-filter{position:sticky;top:72px;z-index:6;background:color-mix(in srgb,var(--c-bg,#fff) 94%,transparent);padding-block:10px;border-radius:0 0 16px 16px}}
@media (max-width:640px){nav.tools{grid-template-columns:1fr 1fr!important;gap:12px!important}nav.tools a{padding:16px 12px!important}nav.tools a span{font-size:12.5px;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}nav.tools a[href="/tools/ayah-card"]{flex-direction:column!important;text-align:center}}
@media (prefers-reduced-motion:reduce){nav.tools a,#tf button{transition:none}nav.tools a:hover{transform:none}}
'''
open(p, 'a', encoding='utf-8').write(CSS); print('cards v4 appended')
