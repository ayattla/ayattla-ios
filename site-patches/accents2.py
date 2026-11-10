# tool accents v1.1 for ayattla.com styles/theme.css (run inside /root/ayattla-repo): stronger page head, buttons in the tool color.
p = 'styles/theme.css'; s = open(p, encoding='utf-8').read()
assert 'tool accents v1 ' in s and 'tool accents v1.1' not in s
G = {'#9A6516': ['duas', 'tasbih'], '#1D6670': ['prayer-times', 'qibla', 'nearby-mosques', 'prayer-guide'],
     '#2E4380': ['hijri', 'occasions', 'sawm-tracker'], '#7A5F28': ['zakat', 'qada-salah'],
     '#7A4E2D': ['hadith', 'hadith-checker', 'hadith-card']}
css = ['', '/* tool accents v1.1 (2026-11-10): رأس الصفحة وأزرارها بلون الأداة في الوضع الفاتح */',
       'main:has(#list.az-list){--tacc:var(--az-acc)}']
for c, sl in G.items():
    css.append(','.join('html:not([data-theme=dark]):has(link[rel="canonical"][href$="/tools/%s"]) main' % x for x in sl)
               + '{--c-primary:color-mix(in srgb,%s 86%%,#000);--c-primary-ink:color-mix(in srgb,%s 80%%,#000);--c-primary-soft:color-mix(in srgb,%s 10%%,#fff)}' % (c, c, c))
css += ['html:has(link[rel="canonical"][href*="/tools/"]) main .page-head{background:linear-gradient(180deg,color-mix(in srgb,var(--tacc,var(--s-green)) 14%,var(--c-surface)) 0%,var(--c-surface) 85%)!important;border-color:color-mix(in srgb,var(--tacc,var(--s-green)) 22%,transparent)}',
        'html:has(link[rel="canonical"][href*="/tools/"]) main .page-head .tool-ico{background:var(--tacc,var(--s-green));color:#fff}', '']
open(p, 'a', encoding='utf-8').write('\n'.join(css)); print('appended', len(css), 'lines')
