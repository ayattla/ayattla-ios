// Faithful transcription of ayattla.com/tools/prayer-times calculation (2026-11-02).
const rad=Math.PI/180,dsin=d=>Math.sin(d*rad),dcos=d=>Math.cos(d*rad),dtan=d=>Math.tan(d*rad),darcsin=x=>Math.asin(x)/rad,darccos=x=>Math.acos(Math.max(-1,Math.min(1,x)))/rad,darctan2=(y,x)=>Math.atan2(y,x)/rad,darccot=x=>Math.atan(1/x)/rad,fix=(a,b)=>{a=a-b*Math.floor(a/b);return a<0?a+b:a};
function sunPos(jd){const D=jd-2451545,g=fix(357.529+.98560028*D,360),q=fix(280.459+.98564736*D,360),L=fix(q+1.915*dsin(g)+.020*dsin(2*g),360),e=23.439-.00000036*D,RA=darctan2(dcos(e)*dsin(L),dcos(L))/15;return{decl:darcsin(dsin(e)*dsin(L)),eqt:q/15-fix(RA,24)}}
function julian(y,m,d){if(m<=2){y-=1;m+=12}const A=Math.floor(y/100),B=2-A+Math.floor(A/4);return Math.floor(365.25*(y+4716))+Math.floor(30.6001*(m+1))+d+B-1524.5}
function times(dt,lat,lng,tz,fa,is){const jd=julian(dt.y,dt.m,dt.d)-lng/(15*24),mid=t=>fix(12-sunPos(jd+t).eqt,24);
 const ang=(a,t,ccw)=>{const d=sunPos(jd+t).decl,T=darccos((-dsin(a)-dsin(d)*dsin(lat))/(dcos(d)*dcos(lat)))/15;return mid(t)+(ccw?-T:T)};
 const asr=t=>{const d=sunPos(jd+t).decl;return ang(-darccot(1+dtan(Math.abs(lat-d))),t)};const adj=t=>t+tz-lng/15;
 const r={fajr:adj(ang(fa,5/24,true)),sunrise:adj(ang(.833,6/24,true)),dhuhr:adj(mid(.5)),asr:adj(asr(13/24)),maghrib:adj(ang(.833,18/24))};
 r.isha=is>30?r.maghrib+(is===90&&dt.ram?120:is)/60:adj(ang(is,18/24));return r}
const hm=h=>{h=fix(h+.5/60,24);const H=Math.floor(h),M=Math.floor((h-H)*60);return String(H).padStart(2,'0')+':'+String(M).padStart(2,'0')};
function tzOff(zone,d){const p=new Intl.DateTimeFormat('en-US',{timeZone:zone,hourCycle:'h23',year:'numeric',month:'numeric',day:'numeric',hour:'numeric',minute:'numeric'}).formatToParts(d),g=t=>+p.find(x=>x.type===t).value;return(Date.UTC(g('year'),g('month')-1,g('day'),g('hour'),g('minute'))-Math.floor(d.getTime()/60000)*60000)/3600000}
module.exports={times,hm,tzOff,julian,sunPos};
