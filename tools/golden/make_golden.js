const fs=require('fs');const {times,hm,tzOff}=require('./reference.js');
const date={y:2026,m:11,d:2,ram:false};const at=new Date(Date.UTC(2026,10,2,9,0));
const keys=['fajr','sunrise','dhuhr','asr','maghrib','isha'];let bad=0;const out=[];
for(const line of fs.readFileSync(__dirname+'/cities.txt','utf8').trim().split('\n')){
 const [name,cfg,site]=line.split('|');const [lat,lng,zone,fa,is]=cfg.split(',');const tz=tzOff(zone,at);
 const r=times(date,+lat,+lng,tz,+fa,+is);const mine=keys.map(k=>hm(r[k]));const exp=site.split(',');
 mine.forEach((v,i)=>{if(v!==exp[i]){bad++;console.log('MISMATCH',name,keys[i],v,exp[i])}});
 out.push({city:name,lat:+lat,lng:+lng,zone,tzHours:tz,fajrAngle:+fa,isha:+is,date:'2026-11-02',
   expected:Object.fromEntries(keys.map((k,i)=>[k,exp[i]])),hours:Object.fromEntries(keys.map(k=>[k,+r[k].toFixed(6)]))});}
fs.writeFileSync(__dirname+'/prayer_times_2026-11-02.json',JSON.stringify({source:'ayattla.com/tools/prayer-times UI, read 2026-11-02',cases:out},null,1));
console.log(out.length,'cities,',bad,'mismatches');
