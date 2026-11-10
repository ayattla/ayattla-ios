# home v3 for ayattla.com (run inside /root/ayattla-repo): time-of-day opening, full-bleed bands, night stats, dusk CTA.
import re
hp = 'styles/home.css'; h = open(hp, encoding='utf-8').read()
assert 'home v3' not in h
CSS = r'''
/* home v3 (2026-11-10): الافتتاحية بلون وقت الزائر (data-tod يضعه سطر في build_site)، أشرطة ممتدة متعاقبة، الأرقام والدعوة بألوان الليل والذهب */
html,body{overflow-x:clip}
html{--tod1:#E4EFF1;--tod2:#FBFCFA}
html[data-tod=fajr]{--tod1:#FFE2B5;--tod2:#FFF9EE}
html[data-tod=maghrib]{--tod1:#F3C9A2;--tod2:#E2ECEE}
section.opening{background:linear-gradient(180deg,var(--tod1) 0%,var(--tod2) 72%,var(--c-bg,#fff) 100%)}
[data-theme=dark] section.opening{background:linear-gradient(180deg,color-mix(in srgb,var(--tod1) 14%,var(--c-bg)) 0%,var(--c-bg) 100%)}
html[data-tod=night] section.opening{background:radial-gradient(1.6px 1.6px at 8% 18%,rgba(255,255,255,.9) 50%,transparent 52%),radial-gradient(1.2px 1.2px at 22% 62%,rgba(255,255,255,.65) 50%,transparent 52%),radial-gradient(1.4px 1.4px at 41% 10%,rgba(255,255,255,.8) 50%,transparent 52%),radial-gradient(1.2px 1.2px at 57% 44%,rgba(255,255,255,.55) 50%,transparent 52%),radial-gradient(1.6px 1.6px at 76% 14%,rgba(255,255,255,.9) 50%,transparent 52%),radial-gradient(1.2px 1.2px at 92% 52%,rgba(255,255,255,.7) 50%,transparent 52%),radial-gradient(1.3px 1.3px at 33% 34%,rgba(255,255,255,.6) 50%,transparent 52%),radial-gradient(55% 45% at 88% 0%,rgba(226,194,122,.2),transparent 70%),linear-gradient(180deg,#0C1833 0%,#13284A 68%,#1A3654 100%)}
html[data-tod=night] section.opening .op-text h1{color:#E7C982}
html[data-tod=night] section.opening .op-text h1 .ln:first-child{color:#F6F2E9}
html[data-tod=night] section.opening .op-text p.lead{color:#D5DBE6}
html[data-tod=night] section.opening p.trust{color:#C3CBDA}
html[data-tod=night] section.opening ul.perks{background:rgba(255,255,255,.07)!important;border-color:rgba(255,255,255,.16)!important;box-shadow:none!important}
html[data-tod=night] section.opening ul.perks li{color:#E3E7EF!important;background:transparent!important}
:is(.sec-gallery,.sec-tools,#daily){position:relative;isolation:isolate;padding-block:clamp(48px,7vw,88px);content-visibility:visible!important;contain:none!important}
.sec-gallery::before,.sec-tools::before,#daily::before{content:""!important;position:absolute!important;inset:0 calc(50% - 50vw)!important;z-index:-1!important;opacity:1!important;-webkit-mask:none!important;mask:none!important;transform:none!important;width:auto!important;height:auto!important;filter:none!important}
.sec-gallery::before{background:radial-gradient(60% 55% at 50% 0%,rgba(226,194,122,.16),transparent 70%),linear-gradient(180deg,#0F2C21 0%,#11372B 100%)!important}
.sec-gallery>.sec-h h2{color:#F6F2E9}
.sec-gallery>.sec-h p{color:#CFE0D8}
.sec-gallery>.sec-h .eyebrow{background:rgba(226,194,122,.16);color:#E7C982;border-color:rgba(226,194,122,.35)}
.sec-tools::before{background:#F6F2E9!important}
#daily::before{background:linear-gradient(180deg,#FFF3DA 0%,#FFFBF2 100%)!important}
[data-theme=dark] .sec-tools::before{background:#0F2C21!important}
[data-theme=dark] #daily::before{background:linear-gradient(180deg,#1E2716 0%,#0F2C21 100%)!important}
.stats{background:radial-gradient(50% 80% at 15% 0%,rgba(226,194,122,.18),transparent 70%),linear-gradient(135deg,#0C1833 0%,#13284A 55%,#0F2C21 100%)!important;box-shadow:0 24px 50px -28px rgba(12,24,51,.55)!important}
.stats b{color:#E7C982!important}
.stats span{color:#D5DBE6!important}
.cta-band{background:radial-gradient(45% 90% at 85% 0%,rgba(226,194,122,.22),transparent 70%),linear-gradient(135deg,#0C1833 0%,#14304E 50%,#1D6670 100%)!important}
.cta-band h2{color:#F6F2E9!important}
.cta-band a.btn{background:#E2C27A!important;color:#0C1833!important;border-color:#E2C27A!important}
'''
open(hp, 'a', encoding='utf-8').write(CSS)
bp = 'build_site.py'; b = open(bp, encoding='utf-8').read()
anchor = '    home = prune_page(home)\n'
m = re.findall(r'^( *)home = prune_page\(home\)\n', b, re.M)
assert len(m) == 1 and 'data-tod' not in b, m
ind = m[0]
add = (ind + "# home v3: يضع وقت الزائر (فجر/نهار/مغرب/ليل) قبل رسم الافتتاحية حتى لا يتغير لونها بعد الظهور\n"
       + ind + "_tod = '<script>(function(){var h=new Date().getHours();document.documentElement.dataset.tod=h>=4&&h<7?\"fajr\":h>=7&&h<16?\"day\":h>=16&&h<19?\"maghrib\":\"night\"})()</script>'\n"
       + ind + "assert home.count('<section class=\"opening\"') == 1\n"
       + ind + "home = home.replace('<section class=\"opening\"', _tod + '<section class=\"opening\"', 1)\n")
b = b.replace(ind + 'home = prune_page(home)\n', add + ind + 'home = prune_page(home)\n', 1)
open(bp, 'w', encoding='utf-8').write(b); print('home v3 applied')
