/* כפתור "משוב" לכל כלי באתר: נשמר בטבלת dev_feedback ומוצג לאריאל בלוח ההנהלה (מסך "משובים").
   נטען בכל דף: <script src="/feedback/badge.js" defer></script> */
(function(){
  'use strict';
  if(window.__kfb)return;window.__kfb=1;
  var CFG={url:'https://onocjgbtensczpdbeanf.supabase.co',key:'sb_publishable_JpV-E-qPnV9ZdnRnY9Kv8Q_TaRzCnyc'};
  var p=location.pathname;
  var TOOL=/^\/milui/.test(p)?'מילוי מקום':/^\/toranut/.test(p)?'תורנויות חצר':/^\/sayarot/.test(p)?'סיירות':/^\/mapat-kita/.test(p)?'מפת כיתה':/^\/hanhala/.test(p)?'לוח הנהלה':/^\/horim/.test(p)?'יום הורים':/^\/shiluv/.test(p)?'כלי השילוב':'מתכנן הספק';
  function ls(k){try{return localStorage.getItem(k)||''}catch(e){return ''}}
  function lsSet(k,v){try{localStorage.setItem(k,v)}catch(e){}}
  function esc(x){return String(x==null?'':x).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]})}
  /* מזהה מכשיר אקראי: לפיו (או לפי הטלפון) המשתמש רואה את הפניות הקודמות שלו */
  function token(){var t=ls('fb_token');if(!/^[A-Za-z0-9_-]{16,64}$/.test(t)){var a=new Uint8Array(18);try{crypto.getRandomValues(a)}catch(e){for(var i=0;i<a.length;i++)a[i]=Math.random()*256}
    t=Array.prototype.map.call(a,function(n){return ('0'+n.toString(16)).slice(-2)}).join('');lsSet('fb_token',t)}return t}
  function myPhone(){var m='';try{m=(JSON.parse(ls('mapat-kita-session')||'null')||{}).phone||''}catch(e){}return ls('fb_phone')||ls('hanhala_phone')||ls('milui_phone')||m}
  function call(fn,p){return fetch(CFG.url+'/rest/v1/rpc/'+fn,{method:'POST',headers:{apikey:CFG.key,Authorization:'Bearer '+CFG.key,'Content-Type':'application/json'},body:JSON.stringify({p:p})})
    .then(function(r){if(!r.ok)return r.text().then(function(t){throw new Error(t)});return r.json()})}
  var KIND={bug:'תקלה',idea:'רעיון',question:'שאלה'},STAT={new:['התקבל','#5b6878'],doing:['בטיפול','#a85a00'],done:['טופל','#3f7d21']};
  var css=''+
  '.kfb-btn{position:fixed;left:14px;bottom:calc(14px + env(safe-area-inset-bottom,0px));z-index:40;display:inline-flex;align-items:center;gap:6px;min-height:40px;padding:0 14px;border:0;border-radius:999px;background:#26323f;color:#fff;font:600 14px/1 Heebo,Assistant,system-ui,sans-serif;box-shadow:0 3px 10px rgba(31,42,55,.25);cursor:pointer;opacity:.9}'+
  '.kfb-btn:hover{opacity:1}.kfb-btn:focus-visible{outline:3px solid #2f7fd6;outline-offset:2px}'+
  '.kfb-btn svg{width:18px;height:18px;flex:none}'+
  '@media print{.kfb-btn{display:none}}'+
  '.kfb-dlg{border:0;border-radius:14px;padding:0;width:min(460px,calc(100vw - 24px));max-height:calc(100vh - 24px);box-shadow:0 20px 60px rgba(20,30,50,.35);color:#1f2a37;font-family:Heebo,Assistant,system-ui,sans-serif;direction:rtl}'+
  '.kfb-dlg::backdrop{background:rgba(20,28,38,.5)}'+
  '.kfb-dlg form{display:flex;flex-direction:column;gap:14px;padding:22px}'+
  '.kfb-dlg h2{margin:0;font-size:20px}.kfb-dlg p{margin:0;color:#5b6878;font-size:15px}'+
  '.kfb-dlg label{display:flex;flex-direction:column;gap:5px;font-weight:600;font-size:15px}'+
  '.kfb-dlg input,.kfb-dlg textarea{font:400 16px Heebo,Assistant,system-ui,sans-serif;border:1.5px solid #c9d1db;border-radius:10px;padding:10px 12px;background:#fff;color:inherit;width:100%;box-sizing:border-box}'+
  '.kfb-dlg textarea{min-height:110px;resize:vertical}'+'.kfb-m{margin:6px 0 0;padding:6px 10px;border-radius:8px;background:#f2f4f7;font-size:14px}.kfb-m.dev{background:#e8f1fb}.kfb-rep{margin-top:6px}.kfb-rep textarea{min-height:60px}.kfb-rs{font-size:13px;opacity:.8}.sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0)}'+'.kfb-file{display:inline-flex!important;align-items:center;gap:6px;cursor:pointer;border:1.5px dashed #9aa7b6;border-radius:10px;padding:10px 12px;font-weight:500}.kfb-file input{position:absolute;opacity:0;width:1px;height:1px}.kfb-file:focus-within{outline:3px solid #2f7fd6}.kfb-prev{display:flex;align-items:center;gap:10px;margin-top:8px}.kfb-prev button{font:500 15px Heebo,Assistant,system-ui,sans-serif;border:1.5px solid #c9d1db;background:#fff;border-radius:10px;padding:8px 12px;cursor:pointer;color:inherit}.kfb-prev img{max-height:90px;max-width:140px;border:1px solid #c9d1db;border-radius:8px}'+
  '.kfb-dlg input:focus,.kfb-dlg textarea:focus{outline:3px solid #2f7fd6;outline-offset:1px;border-color:#2f7fd6}'+
  '.kfb-kinds{display:flex;flex-wrap:wrap;gap:8px;border:0;margin:0;padding:0}.kfb-kinds legend{font-weight:600;font-size:15px;margin-bottom:6px;padding:0}'+
  '.kfb-kinds label{flex-direction:row;align-items:center;gap:8px;min-height:44px;padding:0 14px;border:1.5px solid #c9d1db;border-radius:10px;font-weight:500;cursor:pointer}'+
  '.kfb-kinds input{width:18px;height:18px;margin:0;accent-color:#2f7fd6}.kfb-kinds label:has(input:checked){border-color:#2f7fd6;background:#eef5fc}'+
  '.kfb-row{display:grid;grid-template-columns:1fr 1fr;gap:10px}@media (max-width:420px){.kfb-row{grid-template-columns:1fr}}'+
  '.kfb-act{display:flex;gap:10px;flex-wrap:wrap}'+
  '.kfb-act button{min-height:48px;padding:0 20px;border-radius:10px;font:600 17px Heebo,Assistant,system-ui,sans-serif;cursor:pointer;border:0;background:#2f7fd6;color:#fff}'+
  '.kfb-act button.sec{background:#fff;color:#1f2a37;border:1.5px solid #c9d1db}'+
  '.kfb-act button:disabled{opacity:.6;cursor:default}'+
  '.kfb-err{color:#c62a20;font-weight:600;font-size:15px}.kfb-ok{color:#3f7d21;font-weight:600;font-size:17px}'+
  '.kfb-meta{font-size:13px;color:#5b6878}'+
  '.kfb-link{align-self:flex-start;background:none;border:0;padding:6px 0;min-height:44px;color:#2f7fd6;font:600 15px Heebo,Assistant,system-ui,sans-serif;text-decoration:underline;cursor:pointer}'+
  '.kfb-list{display:flex;flex-direction:column;gap:10px;margin:0;padding:0;list-style:none;overflow:auto;max-height:55vh}'+
  '.kfb-list li{border:1.5px solid #c9d1db;border-radius:10px;padding:10px 12px}'+
  '.kfb-list .h{display:flex;flex-wrap:wrap;justify-content:space-between;gap:4px 10px;font-size:13px;color:#5b6878}'+
  '.kfb-list .st{font-weight:700}.kfb-list .b{white-space:pre-wrap;font-size:15px;margin-top:4px;overflow-wrap:anywhere}';
  function init(){
    var st=document.createElement('style');st.textContent=css;document.head.appendChild(st);
    var b=document.createElement('button');b.type='button';b.className='kfb-btn';b.setAttribute('aria-label','שליחת משוב למפתח');
    b.innerHTML='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M4 5h16v11H9l-5 4z"/></svg><span>משוב</span>';
    document.body.appendChild(b);
    /* אם בתחתית המסך יש סרגל קבוע (למשל ניווט תחתון בנייד), הכפתור עולה מעליו */
    function place(){
      if(d&&d.open)return;
      var off=0,y=innerHeight-4;
      document.elementsFromPoint(24,y).forEach(function(el){
        if(el===b||b.contains(el)||el===document.body||el===document.documentElement)return;
        for(var n=el;n&&n!==document.body;n=n.parentElement){var ps=getComputedStyle(n).position;
          if(ps==='fixed'||ps==='sticky'){var r=n.getBoundingClientRect();if(r.width>innerWidth*.6&&r.top>innerHeight*.5)off=Math.max(off,innerHeight-r.top);break}}
      });
      b.style.bottom=off?'calc('+Math.round(off+10)+'px + env(safe-area-inset-bottom,0px))':'';
    }
    place();setTimeout(place,300);setTimeout(place,1000);addEventListener('resize',place);addEventListener('click',function(){setTimeout(place,200)});setInterval(place,2000);
    var d=document.createElement('dialog');d.className='kfb-dlg';d.setAttribute('aria-labelledby','kfb-t');document.body.appendChild(d);
    function form(){SHOT=null;
      var nm=ls('fb_name'),ph=myPhone();
      d.innerHTML='<form method="dialog" novalidate><h2 id="kfb-t">משוב למפתח</h2><p>תקלה, רעיון או שאלה על הכלי. ההודעה מגיעה ישירות לאריאל.</p>'+
        '<fieldset class="kfb-kinds"><legend>על מה מדובר</legend>'+
        '<label><input type="radio" name="kind" value="bug" checked>תקלה</label><label><input type="radio" name="kind" value="idea">רעיון לשיפור</label><label><input type="radio" name="kind" value="question">שאלה</label></fieldset>'+
        '<fieldset class="kfb-kinds"><legend>כמה זה דחוף (לא חובה)</legend>'+
        '<label><input type="radio" name="urg" value="1">דחוף</label><label><input type="radio" name="urg" value="2">חשוב</label><label><input type="radio" name="urg" value="3">יכול לחכות</label></fieldset>'+
        '<label>מה קרה או מה כדאי לשנות<textarea name="body" maxlength="2000" required placeholder="למשל: במסך מילוי מקום, כשלוחצים על שמירה לא קורה כלום"></textarea></label>'+
        '<div class="kfb-shot"><label class="kfb-file">📷 צירוף צילום מסך (לא חובה)<input type="file" name="shot" accept="image/*"></label><div class="kfb-prev" hidden></div></div>'+'<div class="kfb-row"><label>שם<input name="name" maxlength="60" required autocomplete="name"></label>'+
        '<label>טלפון לחזרה (לא חובה)<input name="phone" type="tel" inputmode="tel" autocomplete="tel"></label></div>'+
        '<div class="kfb-meta">יצורף אוטומטית: '+TOOL+' · '+location.pathname+'</div>'+
        '<div class="kfb-err" role="alert" hidden></div>'+
        '<div class="kfb-act"><button type="submit">שליחה</button><button type="button" class="sec" data-close>ביטול</button></div>'+
        '<button type="button" class="kfb-link" data-mine>הפניות הקודמות שלי</button></form>';
      d.querySelector('[name=name]').value=nm;d.querySelector('[name=phone]').value=ph;
    }
    var SHOT=null;
    function shrink(file){return new Promise(function(ok,no){var u=URL.createObjectURL(file),im=new Image();im.onload=function(){var m=1600,w=im.naturalWidth,h=im.naturalHeight,r=Math.min(1,m/Math.max(w,h)),c=document.createElement('canvas');c.width=Math.round(w*r);c.height=Math.round(h*r);var x=c.getContext('2d');x.fillStyle='#fff';x.fillRect(0,0,c.width,c.height);x.drawImage(im,0,0,c.width,c.height);URL.revokeObjectURL(u);var q=.8,d=c.toDataURL('image/jpeg',q);while(d.length>850000&&q>.3){q-=.15;d=c.toDataURL('image/jpeg',q)}d.length>850000?no():ok(d)};im.onerror=function(){URL.revokeObjectURL(u);no()};im.src=u})}
    d.addEventListener('change',function(e){if(e.target.name!=='shot')return;var f=e.target.files&&e.target.files[0],pv=d.querySelector('.kfb-prev'),err=d.querySelector('.kfb-err');SHOT=null;pv.hidden=true;pv.innerHTML='';if(!f)return;
      shrink(f).then(function(x){SHOT=x;pv.innerHTML='<img src="'+x+'" alt="הצילום שיצורף"><button type="button" class="sec" data-unshot>הסרת הצילום</button>';pv.hidden=false}).catch(function(){e.target.value='';err.textContent='לא הצלחנו לקרוא את התמונה. נסו צילום אחר.';err.hidden=false})});
    function repBox(w){w.innerHTML='<label class="kfb-row" style="margin:6px 0 0"><span class="sr">הוספה לפנייה</span><textarea maxlength="2000" placeholder="מה עוד חשוב לדעת? (הפנייה תיפתח מחדש)"></textarea></label><div class="kfb-act" style="margin-top:6px"><button type="button" data-repsend>שליחה</button><span class="kfb-rs" role="status"></span></div>';w.querySelector('textarea').focus()}
    function repSend(w){var t=w.querySelector('textarea'),rs=w.querySelector('.kfb-rs'),bt=w.querySelector('[data-repsend]');if(!t.value.trim()){t.focus();return}
      bt.disabled=true;rs.textContent='שולח…';call('feedback_reply',{id:+w.dataset.id,body:t.value,phone:myPhone(),token:token()}).then(function(){
        var li=w.closest('li'),m=document.createElement('div');m.className='kfb-m';m.innerHTML='<b>אני:</b> '+esc(t.value);w.before(m);w.innerHTML='<span class="kfb-rs">נשלח. הפנייה נפתחה מחדש.</span>'})
      .catch(function(){bt.disabled=false;rs.textContent='לא נשלח. נסו שוב.'})}
    function mine(){
      d.innerHTML='<form method="dialog"><h2 id="kfb-t">הפניות הקודמות שלי</h2><p role="status">טוען…</p><div class="kfb-act"><button type="button" class="sec" data-new>פנייה חדשה</button><button type="button" class="sec" data-close>סגירה</button></div></form>';
      var st=d.querySelector('p');
      call('feedback_mine',{phone:myPhone(),token:token()}).then(function(list){
        if(!list||!list.length){st.textContent='עוד לא נשלחו פניות מהמכשיר הזה.';return}
        markSeen(list);
        st.textContent=list.length===1?'פנייה אחת':list.length+' פניות';
        var ul=document.createElement('ul');ul.className='kfb-list';
        ul.innerHTML=list.map(function(x){var s=STAT[x.status]||STAT.new,dt=new Date(x.created_at);
          return '<li><div class="h"><span>'+esc(KIND[x.kind]||'')+' · '+esc(x.tool)+' · '+dt.getDate()+'.'+(dt.getMonth()+1)+'</span><span class="st" style="color:'+s[1]+'">'+s[0]+'</span></div><div class="b">'+esc(x.body)+'</div>'+
            (x.msgs||[]).map(function(m){return '<div class="kfb-m'+(m.dev?' dev':'')+'"><b>'+(m.dev?'תשובה':'אני')+':</b> '+esc(m.body)+'</div>'}).join('')+
            '<div class="kfb-rep" data-id="'+x.id+'"><button type="button" class="sec" data-rep>המשך התכתבות</button></div></li>'}).join('');
        st.after(ul);
      }).catch(function(){st.textContent='הפניות לא נטענו. בדקו את החיבור ונסו שוב.'});
    }
    b.addEventListener('click',function(){form();d.showModal();d.querySelector('textarea').focus()});
    /* תשובה חדשה מהמפתח: קופצת פעם אחת בכניסה הבאה, ואחרי "קראתי" לא חוזרת (נשמר בשרת, בכל המכשירים) */
    function unseen(list){var out=[];(list||[]).forEach(function(x){var ms=(x.msgs||[]).filter(function(m){return m.dev&&!m.seen});if(ms.length)out.push({f:x,ms:ms})});return out}
    function markSeen(list){var ids=[];unseen(list).forEach(function(u){u.ms.forEach(function(m){if(m.id)ids.push(m.id)})});
      if(ids.length)call('feedback_seen',{phone:myPhone(),token:token(),ids:ids}).catch(function(){})}
    function popReplies(){
      if(d.open||/[?&](k|p)=/.test(location.search))return;
      call('feedback_mine',{phone:myPhone(),token:token()}).then(function(list){var u=unseen(list);if(!u.length||d.open)return;
        d.innerHTML='<form method="dialog"><h2 id="kfb-t">'+(u.length===1?'יש תשובה לפנייה שלך':'יש תשובות ל־'+u.length+' פניות שלך')+'</h2><ul class="kfb-list">'+
          u.map(function(x){var dt=new Date(x.f.created_at);return '<li><div class="h"><span>'+esc(KIND[x.f.kind]||'')+' · '+esc(x.f.tool)+' · '+dt.getDate()+'.'+(dt.getMonth()+1)+'</span></div><div class="b" style="color:#5b6878">'+esc(String(x.f.body).slice(0,160))+(String(x.f.body).length>160?'…':'')+'</div>'+
            x.ms.map(function(m){return '<div class="kfb-m dev"><b>תשובה:</b> '+esc(m.body)+'</div>'}).join('')+'</li>'}).join('')+
          '</ul><div class="kfb-act"><button type="button" data-seen>קראתי</button><button type="button" class="sec" data-seenmine>להמשך התכתבות</button></div></form>';
        d.showModal();d.querySelector('[data-seen]').focus();
        d.querySelector('[data-seen]').onclick=function(){markSeen(list);d.close()};
        d.querySelector('[data-seenmine]').onclick=function(){markSeen(list);mine()};
      }).catch(function(){})}
    setTimeout(popReplies,1500);
    /* פתיחה מבחוץ עם טיוטה מוכנה (רוחי) */
    window.KFB={mine:function(){mine();if(!d.open)d.showModal()},open:function(o){o=o||{};form();var k=d.querySelector('[name=kind][value="'+(o.kind||'bug')+'"]');if(k)k.checked=true;
      var t=d.querySelector('textarea[name=body]');if(t&&o.body)t.value=o.body;d.showModal();if(t){t.focus();t.setSelectionRange(t.value.length,t.value.length)}}};
    d.addEventListener('click',function(e){if(e.target.closest('[data-unshot]')){SHOT=null;var i=d.querySelector('[name=shot]');if(i)i.value='';var pv=d.querySelector('.kfb-prev');pv.hidden=true;pv.innerHTML='';return}if(e.target.closest('[data-rep]'))return repBox(e.target.closest('.kfb-rep'));if(e.target.closest('[data-repsend]'))return repSend(e.target.closest('.kfb-rep'));if(e.target.closest('[data-mine]'))return mine();if(e.target.closest('[data-new]')){form();d.querySelector('textarea').focus();return}if(e.target.closest('[data-close]')||e.target===d)d.close()});
    d.addEventListener('submit',function(e){
      e.preventDefault();var f=e.target,err=f.querySelector('.kfb-err'),btn=f.querySelector('button[type=submit]');
      var body=f.body.value.trim(),name=f.name.value.trim(),phone=f.phone.value.trim();
      function show(m){err.textContent=m;err.hidden=false}
      if(!body){show('צריך לכתוב מה קרה.');f.body.focus();return}
      if(!name){show('צריך למלא שם.');f.name.focus();return}
      btn.disabled=true;btn.textContent='שולח…';err.hidden=true;
      call('feedback_send',{name:name,phone:phone,tool:TOOL,kind:(f.querySelector('[name=kind]:checked')||{}).value||'bug',body:body,page:location.pathname+location.hash,ua:navigator.userAgent,token:token(),urgency:(f.querySelector('[name=urg]:checked')||{}).value||null,shot:SHOT})
      .then(function(){SHOT=null;
        lsSet('fb_name',name);if(phone)lsSet('fb_phone',phone);
        f.innerHTML='<h2 id="kfb-t">תודה!</h2><p class="kfb-ok">המשוב נשלח לאריאל.</p><div class="kfb-act"><button type="button" data-close>סגירה</button><button type="button" class="sec" data-mine>הפניות שלי</button></div>';
        f.querySelector('[data-close]').focus()})
      .catch(function(x){btn.disabled=false;btn.textContent='שליחה';show(/bad_shot/.test(String(x&&x.message))?'הצילום גדול מדי. נסו צילום אחר.':/rate/.test(String(x&&x.message))?'נשלחו הרבה משובים בדקות האחרונות. נסו שוב בעוד כמה דקות.':'השליחה נכשלה. בדקו את החיבור ונסו שוב.')});
    });
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init);else init();
  /* רוחי (בוט העזרה) נטען יחד עם כפתור המשוב בכל הכלים */
  (function(){var sc=document.createElement('script');sc.src='/help/ruchi.js';sc.defer=true;document.head.appendChild(sc)})();
})();
