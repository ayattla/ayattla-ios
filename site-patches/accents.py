# Appends azkar v2.1 + per-tool accents to styles/theme.css of ayattla.com (run inside /root/ayattla-repo).
from urllib.parse import quote
p = 'styles/theme.css'; s = open(p, encoding='utf-8').read()
assert 'tool accents v1' not in s and s.count('azkar v2 (2026-11-10)') == 1
SV = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'>{}</svg>"
ICON = {
 0: "<circle cx='12' cy='12' r='4'/><path d='M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4'/>",
 1: "<path d='M3 17h18M7 17a5 5 0 0 1 10 0M12 5v4M5.6 10.6l1.4 1.4M18.4 10.6 17 12M6 21h12'/>",
 2: "<path d='M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z'/>",
 3: "<path d='M3 17h18M7 17a5 5 0 0 1 10 0M12 3v6M9 6l3-3 3 3M6 21h12'/>"}
u = lambda k: 'url("data:image/svg+xml,' + quote(SV.format(ICON[k]), safe="/:=' ") + '")'
css = ['', '/* azkar v2.1 (2026-11-10): أيقونة لكل وقت، رأس الصفحة بلون الوقت، واحتفاء عند الإتمام */',
 'main:has(#list.az-list){--s-green:var(--az-acc);--s-soft:var(--az-soft)}',
 'main:has(#list.az-list) .page-head{background:var(--az-band);transition:background .3s}',
 'main:has(#list.az-list) #cats button:is([data-i="0"],[data-i="1"],[data-i="2"],[data-i="3"])::before{content:"";display:inline-block;width:18px;height:18px;margin-inline-end:6px;vertical-align:-4px;background:currentColor;-webkit-mask:var(--az-ic) center/contain no-repeat;mask:var(--az-ic) center/contain no-repeat}']
for k in ICON:
    css.append('main:has(#list.az-list) #cats button[data-i="%d"]{--az-ic:%s}' % (k, u(k)))
css += ['main:has(#prog[style*="100%"]) #msg{font-size:1.15em;color:var(--az-acc)}',
 'main:has(#prog[style*="100%"])>.panel{box-shadow:0 0 0 3px color-mix(in srgb,var(--az-acc) 35%,transparent)}',
 '@media (prefers-reduced-motion:reduce){main:has(#list.az-list) .page-head{transition:none}}',
 '', '/* tool accents v1 (2026-11-10): لون من معنى كل أداة داخل main فقط. القرآن وصناعة المحتوى باللون الأساسي */']
G = {'dawn': ('#9A6516', '#D9A441', ['duas', 'tasbih']),
     'sky': ('#1D6670', '#5FB3BC', ['prayer-times', 'qibla', 'nearby-mosques', 'prayer-guide']),
     'night': ('#2E4380', '#93A6E0', ['hijri', 'occasions', 'sawm-tracker']),
     'gold': ('#7A5F28', '#CBB06E', ['zakat', 'qada-salah']),
     'ink': ('#7A4E2D', '#C9935E', ['hadith', 'hadith-checker', 'hadith-card'])}
def sel(slugs, dark=False):
    pre = 'html[data-theme=dark]' if dark else 'html'
    return ','.join('%s:has(link[rel="canonical"][href$="/tools/%s"]) main' % (pre, x) for x in slugs)
for name, (lt, dk, slugs) in G.items():
    css.append(sel(slugs) + '{--tacc:%s;--s-green:%s;--s-green-d:color-mix(in srgb,%s 82%%,#000);--s-soft:color-mix(in srgb,%s 7%%,#fff);--s-grad:linear-gradient(135deg,%s 0%%,color-mix(in srgb,%s 72%%,#000) 100%%);--s-grad-soft:linear-gradient(135deg,color-mix(in srgb,%s 11%%,transparent),color-mix(in srgb,%s 4%%,transparent))}' % ((lt,) * 8))
    css.append(sel(slugs, True) + '{--tacc:%s;--s-green:%s;--s-soft:color-mix(in srgb,%s 14%%,var(--c-surface))}' % (dk, dk, dk))
css += ['html:has(link[rel="canonical"][href*="/tools/"]) main .page-head .tool-ico{background:var(--s-soft);color:var(--tacc,var(--s-green))}',
        'html:has(link[rel="canonical"][href*="/tools/"]) main .page-head{background-image:var(--s-grad-soft)}', '']
open(p, 'a', encoding='utf-8').write('\n'.join(css)); print('appended', len(css), 'lines')
