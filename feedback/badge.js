/* כפתור "משוב" לכל כלי באתר: נשמר בטבלת dev_feedback ומוצג לאריאל בלוח ההנהלה (מסך "משובים").
   נטען בכל דף: <script src="/feedback/badge.js" defer></script> */
(function(){
  'use strict';
  if(window.__kfb)return;window.__kfb=1;
  var CFG={url:'https://onocjgbtensczpdbeanf.supabase.co',key:'sb_publishable_JpV-E-qPnV9ZdnRnY9Kv8Q_TaRzCnyc'};
  var p=location.pathname;
  var TOOL=/^\/milui/.test(p)?'מילוי מקום':/^\/toranut/.test(p)?'תורנויות חצר':/^\/sayarot/.test(p)?'סיירות':/^\/mapat-kita/.test(p)?'מפת כיתה':/^\/hanhala/.test(p)?'לוח הנהלה':'מתכנן הספק';
  function ls(k){try{return localStorage.getItem(k)||''}catch(e){return ''}}
  function lsSet(k,v){try{localStorage.setItem(k,v)}catch(e){}}
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
  '.kfb-dlg textarea{min-height:110px;resize:vertical}'+
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
  '.kfb-meta{font-size:13px;color:#5b6878}';
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
    function form(){
      var nm=ls('fb_name'),ph=ls('fb_phone')||ls('hanhala_phone')||ls('milui_phone');
      d.innerHTML='<form method="dialog" novalidate><h2 id="kfb-t">משוב למפתח</h2><p>תקלה, רעיון או שאלה על הכלי. ההודעה מגיעה ישירות לאריאל.</p>'+
        '<fieldset class="kfb-kinds"><legend>על מה מדובר</legend>'+
        '<label><input type="radio" name="kind" value="bug" checked>תקלה</label><label><input type="radio" name="kind" value="idea">רעיון לשיפור</label><label><input type="radio" name="kind" value="question">שאלה</label></fieldset>'+
        '<label>מה קרה או מה כדאי לשנות<textarea name="body" maxlength="2000" required placeholder="למשל: במסך מילוי מקום, כשלוחצים על שמירה לא קורה כלום"></textarea></label>'+
        '<div class="kfb-row"><label>שם<input name="name" maxlength="60" required autocomplete="name"></label>'+
        '<label>טלפון לחזרה (לא חובה)<input name="phone" type="tel" inputmode="tel" autocomplete="tel"></label></div>'+
        '<div class="kfb-meta">יצורף אוטומטית: '+TOOL+' · '+location.pathname+'</div>'+
        '<div class="kfb-err" role="alert" hidden></div>'+
        '<div class="kfb-act"><button type="submit">שליחה</button><button type="button" class="sec" data-close>ביטול</button></div></form>';
      d.querySelector('[name=name]').value=nm;d.querySelector('[name=phone]').value=ph;
    }
    b.addEventListener('click',function(){form();d.showModal();d.querySelector('textarea').focus()});
    d.addEventListener('click',function(e){if(e.target.closest('[data-close]')||e.target===d)d.close()});
    d.addEventListener('submit',function(e){
      e.preventDefault();var f=e.target,err=f.querySelector('.kfb-err'),btn=f.querySelector('button[type=submit]');
      var body=f.body.value.trim(),name=f.name.value.trim(),phone=f.phone.value.trim();
      function show(m){err.textContent=m;err.hidden=false}
      if(!body){show('צריך לכתוב מה קרה.');f.body.focus();return}
      if(!name){show('צריך למלא שם.');f.name.focus();return}
      btn.disabled=true;btn.textContent='שולח…';err.hidden=true;
      fetch(CFG.url+'/rest/v1/rpc/feedback_send',{method:'POST',headers:{apikey:CFG.key,Authorization:'Bearer '+CFG.key,'Content-Type':'application/json'},
        body:JSON.stringify({p:{name:name,phone:phone,tool:TOOL,kind:(f.querySelector('[name=kind]:checked')||{}).value||'bug',body:body,page:location.pathname+location.hash,ua:navigator.userAgent}})})
      .then(function(r){if(!r.ok)return r.text().then(function(t){throw new Error(t)});
        lsSet('fb_name',name);if(phone)lsSet('fb_phone',phone);
        f.innerHTML='<h2 id="kfb-t">תודה!</h2><p class="kfb-ok">המשוב נשלח לאריאל.</p><div class="kfb-act"><button type="button" data-close>סגירה</button></div>';
        f.querySelector('[data-close]').focus()})
      .catch(function(x){btn.disabled=false;btn.textContent='שליחה';show(/rate/.test(String(x&&x.message))?'נשלחו הרבה משובים בדקות האחרונות. נסו שוב בעוד כמה דקות.':'השליחה נכשלה. בדקו את החיבור ונסו שוב.')});
    });
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init);else init();
})();
