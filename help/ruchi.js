/* רוחי · בוט העזרה הטכנית של כנפי רוח.
   נטען אוטומטית מ-feedback/badge.js בכל הכלים. מופיע רק למי שהשרת מאשר (תפקידים בטבלה ruchi_roles).
   1. כפתור עם הדמות מעל כפתור "משוב" → חלון שיחה (שיחה / מה חדש).
   2. הכרזות: הכרזה חדשה קופצת פעם אחת לכל משתמש, עם הדמות. */
(function(){
  'use strict';
  if(window.__ruchi)return;window.__ruchi=1;
  var CFG={url:'https://onocjgbtensczpdbeanf.supabase.co',key:'sb_publishable_JpV-E-qPnV9ZdnRnY9Kv8Q_TaRzCnyc'};
  var p=location.pathname;
  var TOOL=/^\/milui/.test(p)?'מילוי מקום':/^\/toranut/.test(p)?'תורנויות חצר':/^\/sayarot/.test(p)?'סיירות':/^\/mapat-kita/.test(p)?'מפת כיתה':/^\/hanhala/.test(p)?'לוח הנהלה':/^\/horim/.test(p)?'יום הורים':'מתכנן הספק';
  var CHIPS={
    'לוח הנהלה':['איך מוסיפים החלטה מהישיבה?','איך משנים תפקיד לאיש צוות?','מה זה "השקופים"?'],
    'מפת כיתה':['איך מדפיסים כרטיסי תלמידים?','מאיפה מגיעים הנתונים?','איך כותבים הערה על תלמיד?'],
    'מילוי מקום':['איך מדווחים על מורה נעדר?','מה זה איחוד כיתות?','איך מוסיפים איש צוות שלא ברשימה?'],
    'תורנויות חצר':['איך מדפיסים את הלוח?','איך מעדכנים את חלוקת החצרות?','איך רואים תורנויות של אדם אחד?'],
    'סיירות':['מה אפשר לעשות כאן?','איך מוסיפים יציאה?'],
    'יום הורים':['מה אפשר לעשות כאן?'],
    'מתכנן הספק':['מה אפשר לעשות כאן?']
  };
  var AV='/help/avatar-96.webp',FULL='/help/ruchi-head.webp';
  function ls(k){try{return localStorage.getItem(k)||''}catch(e){return ''}}
  function esc(x){return String(x==null?'':x).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]})}
  function br(x){return esc(x).replace(/\n/g,'<br>')}
  function phone(){var m='';try{m=(JSON.parse(ls('mapat-kita-session')||'null')||{}).phone||''}catch(e){}return ls('hanhala_phone')||ls('milui_phone')||m||ls('fb_phone')}
  function rpc(fn,p){return fetch(CFG.url+'/rest/v1/rpc/'+fn,{method:'POST',headers:{apikey:CFG.key,Authorization:'Bearer '+CFG.key,'Content-Type':'application/json'},body:JSON.stringify({p:p})})
    .then(function(r){if(!r.ok)throw new Error('http');return r.status===204?null:r.json()})}
  function ask(body){return fetch(CFG.url+'/functions/v1/ruchi',{method:'POST',headers:{apikey:CFG.key,'Content-Type':'application/json'},body:JSON.stringify(body)})
    .then(function(r){return r.json().catch(function(){return {error:'http'}})})}

  var css=''+
  '.rch-btn{position:fixed;left:14px;bottom:72px;z-index:41;width:52px;height:52px;border-radius:50%;border:3px solid #fff;padding:0;background:#cfe6fb;box-shadow:0 4px 14px rgba(20,40,80,.3);cursor:pointer;overflow:hidden}'+
  '.rch-btn img{width:100%;height:100%;object-fit:cover;display:block}.rch-btn:focus-visible{outline:3px solid #2f7fd6;outline-offset:2px}'+
  '.rch-btn .dot{position:absolute;top:2px;right:2px;width:12px;height:12px;border-radius:50%;background:#e0442f;border:2px solid #fff}'+
  '@media print{.rch-btn,.rch-pan,.rch-ann{display:none!important}}'+
  '.rch-pan{position:fixed;left:14px;bottom:14px;z-index:60;width:min(390px,calc(100vw - 28px));height:min(600px,calc(100vh - 28px));display:flex;flex-direction:column;background:#fff;border-radius:16px;box-shadow:0 20px 60px rgba(20,30,50,.35);direction:rtl;font-family:Heebo,Assistant,system-ui,sans-serif;color:#1f2a37;overflow:hidden}'+
  '.rch-pan[hidden]{display:none}'+
  '.rch-h{display:flex;align-items:center;gap:10px;padding:10px 12px;background:linear-gradient(135deg,#1c4f8a,#2f7fd6);color:#fff}'+
  '.rch-h img{width:40px;height:40px;border-radius:50%;border:2px solid #fff;background:#cfe6fb}.rch-h b{font-size:17px}.rch-h small{display:block;opacity:.85;font-size:12px}'+
  '.rch-h .x{margin-inline-start:auto;background:none;border:0;color:#fff;font-size:22px;min-width:40px;min-height:40px;cursor:pointer}'+
  '.rch-tabs{display:flex;border-bottom:1px solid #e3e8ef}.rch-tabs button{flex:1;min-height:42px;border:0;background:none;font:600 15px inherit;font-family:inherit;color:#5b6878;cursor:pointer;border-bottom:3px solid transparent}'+
  '.rch-tabs button[aria-selected=true]{color:#1c4f8a;border-bottom-color:#2f7fd6}'+
  '.rch-body{flex:1;overflow:auto;padding:12px;display:flex;flex-direction:column;gap:10px;background:#f6f8fb}'+
  '.rch-m{max-width:88%;padding:9px 12px;border-radius:14px;font-size:15px;line-height:1.55;white-space:normal;overflow-wrap:anywhere}'+
  '.rch-m.bot{align-self:flex-start;background:#fff;border:1px solid #e3e8ef;border-top-right-radius:4px}'+
  '.rch-m.me{align-self:flex-end;background:#2f7fd6;color:#fff;border-top-left-radius:4px}'+
  '.rch-m.wait{opacity:.7;font-style:italic}'+
  '.rch-chips{display:flex;flex-wrap:wrap;gap:6px}.rch-chips button{border:1.5px solid #9cc0e8;background:#fff;color:#1c4f8a;border-radius:999px;padding:6px 12px;font:500 14px inherit;font-family:inherit;cursor:pointer;min-height:36px}'+
  '.rch-fb{align-self:stretch;border:1.5px dashed #c9a227;background:#fffbea;border-radius:12px;padding:10px 12px;font-size:14px}'+
  '.rch-fb b{display:block;margin-bottom:4px}.rch-fb p{margin:0 0 8px;white-space:pre-wrap}'+
  '.rch-go{border:0;border-radius:10px;background:#2f7fd6;color:#fff;font:600 15px inherit;font-family:inherit;min-height:40px;padding:0 14px;cursor:pointer}'+
  '.rch-go.sec{background:#fff;color:#1f2a37;border:1.5px solid #c9d1db}'+
  '.rch-in{display:flex;gap:8px;padding:10px;border-top:1px solid #e3e8ef;background:#fff}'+
  '.rch-in textarea{flex:1;resize:none;height:44px;max-height:110px;border:1.5px solid #c9d1db;border-radius:10px;padding:10px;font:400 15px inherit;font-family:inherit}'+
  '.rch-in textarea:focus{outline:3px solid #2f7fd6;outline-offset:1px}'+
  '.rch-news{background:#fff;border:1px solid #e3e8ef;border-radius:12px;padding:10px 12px}.rch-news b{display:block}.rch-news small{color:#5b6878}.rch-news p{margin:4px 0 0;white-space:pre-wrap;font-size:14px}'+
  '.rch-ann{position:fixed;inset:0;z-index:70;display:flex;align-items:center;justify-content:center;background:rgba(20,28,38,.5);direction:rtl;font-family:Heebo,Assistant,system-ui,sans-serif;padding:12px}'+
  '.rch-ann .card{position:relative;background:#fff;border-radius:18px;max-width:440px;width:100%;padding:22px 22px 18px;box-shadow:0 20px 60px rgba(20,30,50,.35);color:#1f2a37;display:flex;flex-direction:column;gap:12px}'+
  '.rch-ann img{width:110px;height:110px;border-radius:50%;object-fit:cover;align-self:center;margin-top:-72px;border:4px solid #fff;box-shadow:0 6px 16px rgba(20,40,80,.3)}'+
  '.rch-ann h2{margin:0;font-size:21px;text-align:center}.rch-ann p{margin:0;white-space:pre-wrap;font-size:16px;line-height:1.6}'+
  '.rch-ann .act{display:flex;gap:10px;justify-content:center;flex-wrap:wrap}';

  var ME=null,HIST=[],pan,btn,body,inp,busy=false;
  function addMsg(cls,html){var m=document.createElement('div');m.className='rch-m '+cls;m.innerHTML=html;body.appendChild(m);body.scrollTop=body.scrollHeight;return m}
  function greet(){body.innerHTML='';
    addMsg('bot','<b>שלום '+esc(ME.greet)+', כאן רוחי 🪶</b><br>אני עוזר טכני לכלים של כנפי רוח. אפשר לשאול אותי איך עושים משהו באתר, או למה משהו מוצג ככה.<br>במה אפשר לעזור?');
    var c=document.createElement('div');c.className='rch-chips';c.innerHTML=(CHIPS[TOOL]||[]).map(function(q){return '<button type="button" data-q="'+esc(q)+'">'+esc(q)+'</button>'}).join('');body.appendChild(c)}
  function send(q){q=String(q||'').trim();if(!q||busy)return;busy=true;inp.value='';
    var ch=body.querySelector('.rch-chips');if(ch)ch.remove();
    addMsg('me',br(q));var w=addMsg('bot wait','רוחי חושב…');
    ask({phone:phone(),tool:TOOL,page:location.pathname+location.hash,q:q,history:HIST}).then(function(r){w.remove();busy=false;
      if(r&&r.answer){HIST.push({role:'user',content:q},{role:'assistant',content:r.answer});HIST=HIST.slice(-8);addMsg('bot',br(r.answer));
        if(r.feedback)fbCard(r.feedback);return}
      var e=r&&r.error;
      addMsg('bot',e==='no_key'?'עוד לא חיברו אותי לשרת, אז אני לא יכול לענות כרגע. 🙂':e==='rate'?'שאלו אותי הרבה בשעה האחרונה. נסו שוב בעוד קצת.':e==='forbidden'?'אני זמין כרגע רק להנהלה.':'משהו השתבש בדרך. אפשר לנסות שוב, או לשלוח משוב לאריאל.');
      if(e&&e!=='rate'&&e!=='forbidden')fbCard({kind:'question',body:q});
    }).catch(function(){w.remove();busy=false;addMsg('bot','אין חיבור כרגע. נסו שוב בעוד רגע.')})}
  function fbCard(f){var c=document.createElement('div');c.className='rch-fb';
    c.innerHTML='<b>📨 משוב מוכן לאריאל</b><p>'+esc(f.body)+'</p><button type="button" class="rch-go" data-fb>פתיחת המשוב לשליחה</button>';
    c.querySelector('[data-fb]').onclick=function(){if(window.KFB){pan.hidden=true;window.KFB.open({kind:f.kind,body:f.body+'\n\n(הוכן על ידי רוחי)'})}};
    body.appendChild(c);body.scrollTop=body.scrollHeight}
  function news(){body.innerHTML='';var L=ME.news||[];
    if(!L.length){addMsg('bot','עוד אין הכרזות. כשיהיה משהו חדש, אספר לך כאן.');return}
    L.forEach(function(a){var d=new Date(a.at),n=document.createElement('div');n.className='rch-news';
      n.innerHTML='<small>'+d.getDate()+'.'+(d.getMonth()+1)+'</small><b>'+esc(a.title)+'</b><p>'+esc(a.body)+'</p>'+(a.link&&a.link!=='#ruchi'?'<a href="'+esc(a.link)+'">'+esc(a.link_label||'מעבר')+' ←</a>':'');body.appendChild(n)})}
  function tab(t){pan.querySelectorAll('.rch-tabs button').forEach(function(b){b.setAttribute('aria-selected',String(b.dataset.t===t))});
    pan.querySelector('.rch-in').style.display=t==='chat'?'':'none';if(t==='chat'){greet();HIST=[]}else news()}
  function open(){pan.hidden=false;tab('chat');setTimeout(function(){inp.focus()},50);var dt=btn.querySelector('.dot');if(dt)dt.remove()}
  function place(){var f=document.querySelector('.kfb-btn');if(!f||!btn)return;var r=f.getBoundingClientRect();if(!r.height)return;btn.style.bottom=Math.round(innerHeight-r.top+10)+'px';btn.style.left=Math.round(r.left)+'px'}

  function build(){
    var st=document.createElement('style');st.textContent=css;document.head.appendChild(st);
    btn=document.createElement('button');btn.type='button';btn.className='rch-btn';btn.setAttribute('aria-label','רוחי, עזרה טכנית');btn.title='רוחי · עזרה';
    btn.innerHTML='<img src="'+AV+'" alt="">';document.body.appendChild(btn);
    pan=document.createElement('section');pan.className='rch-pan';pan.hidden=true;pan.setAttribute('role','dialog');pan.setAttribute('aria-label','רוחי, עזרה טכנית');
    pan.innerHTML='<div class="rch-h"><img src="'+AV+'" alt=""><div><b>רוחי</b><small>עזרה טכנית · '+esc(TOOL)+'</small></div><button type="button" class="x" aria-label="סגירה">✕</button></div>'+
      '<div class="rch-tabs" role="tablist"><button type="button" role="tab" data-t="chat" aria-selected="true">שיחה</button><button type="button" role="tab" data-t="news" aria-selected="false">מה חדש</button></div>'+
      '<div class="rch-body" aria-live="polite"></div>'+
      '<form class="rch-in"><label style="position:absolute;width:1px;height:1px;overflow:hidden" for="rchQ">שאלה לרוחי</label><textarea id="rchQ" maxlength="1500" placeholder="מה רצית לעשות?"></textarea><button class="rch-go" type="submit">שליחה</button></form>';
    document.body.appendChild(pan);body=pan.querySelector('.rch-body');inp=pan.querySelector('textarea');
    btn.onclick=function(){pan.hidden?open():(pan.hidden=true)};
    pan.querySelector('.x').onclick=function(){pan.hidden=true;btn.focus()};
    pan.querySelector('.rch-tabs').onclick=function(e){var b=e.target.closest('button');if(b)tab(b.dataset.t)};
    body.addEventListener('click',function(e){var c=e.target.closest('[data-q]');if(c)send(c.dataset.q)});
    pan.querySelector('form').onsubmit=function(e){e.preventDefault();send(inp.value)};
    inp.addEventListener('keydown',function(e){if(e.key==='Enter'&&!e.shiftKey){e.preventDefault();send(inp.value)}});
    document.addEventListener('keydown',function(e){if(e.key==='Escape'&&!pan.hidden){pan.hidden=true;btn.focus()}});
    place();setInterval(place,1500);addEventListener('resize',place);
    if(location.hash==='#ruchi')open();
  }
  function announce(list){if(!list||!list.length)return;var a=list[0];
    var w=document.createElement('div');w.className='rch-ann';w.setAttribute('role','dialog');w.setAttribute('aria-modal','true');w.setAttribute('aria-labelledby','rchAnnT');
    w.innerHTML='<div class="card"><img src="'+FULL+'" alt="רוחי"><h2 id="rchAnnT">'+esc(a.title)+'</h2><p>'+esc(a.body)+'</p><div class="act">'+
      (a.link?'<button type="button" class="rch-go" data-go>'+esc(a.link_label||'הראה לי')+'</button>':'')+'<button type="button" class="rch-go sec" data-ok>הבנתי</button></div></div>';
    document.body.appendChild(w);var first=w.querySelector('button');if(first)first.focus();
    function done(go){rpc('ruchi_seen_mark',{phone:phone(),id:a.id}).catch(function(){});w.remove();
      if(go){if(a.link==='#ruchi')open();else location.href=a.link}else announce(list.slice(1))}
    w.querySelector('[data-ok]').onclick=function(){done(false)};var g=w.querySelector('[data-go]');if(g)g.onclick=function(){done(true)};
    w.addEventListener('keydown',function(e){if(e.key==='Escape')done(false)})}
  function init(){var ph=phone();if(!ph)return;
    rpc('ruchi_me',{phone:ph}).then(function(r){if(!r||!r.ok)return;ME=r;build();announce(r.pending)}).catch(function(){})}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',function(){setTimeout(init,400)});else setTimeout(init,400);
})();
