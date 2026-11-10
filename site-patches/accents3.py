# tool cards accents v1 for ayattla.com styles/theme.css (run inside /root/ayattla-repo): tool cards (home + /tools/) colored by meaning.
p = 'styles/theme.css'; s = open(p, encoding='utf-8').read()
assert 'tool accents v1.1' in s and 'tool cards accents' not in s
G = {('#9A6516', '#D9A441'): ['azkar', 'duas', 'tasbih'],
     ('#1D6670', '#5FB3BC'): ['prayer-times', 'qibla', 'nearby-mosques', 'prayer-guide'],
     ('#2E4380', '#93A6E0'): ['hijri', 'occasions', 'sawm-tracker'],
     ('#7A5F28', '#CBB06E'): ['zakat', 'qada-salah'],
     ('#7A4E2D', '#C9935E'): ['hadith', 'hadith-checker', 'hadith-card']}
css = ['', '/* tool cards accents v1 (2026-11-10): بطاقات الأدوات في الرئيسية وصفحة الأدوات بلون معنى كل أداة */',
       'nav.tools a{--tacc:var(--s-green)}']
for (lt, dk), sl in G.items():
    css.append(','.join('nav.tools a[href="/tools/%s"]' % x for x in sl) + '{--tacc:%s}' % lt)
    css.append(','.join('[data-theme=dark] nav.tools a[href="/tools/%s"]' % x for x in sl) + '{--tacc:%s}' % dk)
css += ['nav.tools a .ico{background:color-mix(in srgb,var(--tacc) 11%,var(--c-surface))!important;color:var(--tacc)!important;transition:background .2s,color .2s}',
        'nav.tools a:is(:hover,:focus-visible){border-color:color-mix(in srgb,var(--tacc) 50%,transparent)!important}',
        'nav.tools a:is(:hover,:focus-visible) .ico{background:var(--tacc)!important;color:var(--c-surface)!important}',
        'nav.tools a:focus-visible{outline:3px solid var(--tacc);outline-offset:2px}',
        '@media (prefers-reduced-motion:reduce){nav.tools a .ico{transition:none}}', '']
open(p, 'a', encoding='utf-8').write('\n'.join(css)); print('appended', len(css), 'lines')
