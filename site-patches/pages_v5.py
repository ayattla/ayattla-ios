# pages v5 (owner request, 2026-11-10) for ayattla.com styles/theme.css (run inside /root/ayattla-repo).
p = 'styles/theme.css'; s = open(p, encoding='utf-8').read()
assert 'cards v4' in s and 'pages v5' not in s
CSS = '''
/* pages v5 (2026-11-10، طلب المالك): مسار التنقل كشارة، خط متدرج بدل النجمة تحت العناوين، شارة «خطوة بخطوة»، بطاقات الشرح والمزايا بيضاء بإطار وظل ناعم، مسافات بين الأقسام، حقول وأزرار أوضح عند التركيز والتمرير. الخلفيات كما هي */
nav.crumbs{display:inline-flex!important;flex-wrap:wrap;align-items:center;gap:6px;width:fit-content;max-width:100%;margin-inline:auto;padding:6px 14px!important;border-radius:999px;background:color-mix(in srgb,var(--s-green,#2E9145) 7%,var(--c-surface,#fff));border:1px solid color-mix(in srgb,var(--s-green,#2E9145) 18%,transparent);font-size:12.5px!important;font-weight:600;color:var(--c-text-muted,#5A6B61)}
nav.crumbs a{color:var(--s-green,#2E9145)!important;text-decoration:none!important}
nav.crumbs a:hover{text-decoration:underline!important}
nav.crumbs [aria-current]{color:var(--c-text,#1F2A22)}
main h2::after{background:linear-gradient(90deg,var(--gold,#C3A66B),var(--s-green,#2E9145))!important;width:44px!important;height:4px!important;border-radius:999px!important;-webkit-mask:none!important;mask:none!important;opacity:1!important}
section.howto:has(> ol) > h2::before{content:"خطوة بخطوة";display:block;width:fit-content;margin:0 auto 10px;padding:4px 14px;border-radius:999px;font-size:12px;font-weight:700;color:var(--s-green,#2E9145);background:color-mix(in srgb,var(--s-green,#2E9145) 9%,var(--c-surface,#fff));border:1px solid color-mix(in srgb,var(--s-green,#2E9145) 25%,transparent)}
:is(.howto ol>li,.howto ul>li,.lp-cards>*){background:var(--c-surface,#fff)!important;border:1px solid var(--s-line,#E3EBE5)!important;border-radius:20px!important;box-shadow:0 4px 16px rgba(15,31,23,.04)!important}
main>:is(.panel,section.howto,.lp-cards,.faq,.related){margin-block-start:20px}
main :is(input:not([type=checkbox]):not([type=radio]):not([type=range]),select,textarea){border-radius:12px!important;transition:border-color .2s,box-shadow .2s}
main :is(input,select,textarea):hover{border-color:color-mix(in srgb,var(--s-green,#2E9145) 35%,var(--s-line,#E3EBE5))}
main :is(input,select,textarea):focus-visible{outline:none!important;border-color:var(--s-green,#2E9145)!important;box-shadow:0 0 0 3px color-mix(in srgb,var(--s-green,#2E9145) 18%,transparent)!important}
main .btn:not(.line){box-shadow:0 4px 12px color-mix(in srgb,var(--s-green,#2E9145) 22%,transparent);transition:transform .2s,box-shadow .2s}
main .btn:not(.line):is(:hover,:focus-visible){transform:translateY(-2px);box-shadow:0 8px 18px color-mix(in srgb,var(--s-green,#2E9145) 30%,transparent)}
[data-theme=dark] :is(.howto ol>li,.howto ul>li,.lp-cards>*){border-color:var(--c-line,#1E3A30)!important;box-shadow:none!important}
@media (prefers-reduced-motion:reduce){main .btn,main :is(input,select,textarea){transition:none}main .btn:hover{transform:none}}
'''
open(p, 'a', encoding='utf-8').write(CSS); print('pages v5 appended')
