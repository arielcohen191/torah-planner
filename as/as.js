/* "בנעליים של" בכל הכלים · כנפי רוח
   מנהל המערכת בוחר איש צוות בלוח ההנהלה (מסך "בנעליים של"), והמצב נשמר בדפדפן עד יציאה יזומה.
   הקובץ נטען בכל כלי לפני הקוד של הכלי: כל קריאה לשרת נשלחת בשם איש הצוות שנבחר, וכל שמירה נחסמת (צפייה בלבד).
   במפת כיתה, שמוגנת בקוד אישי, מנהל המערכת מזדהה בקוד שלו והשרת מנפיק אסימון צפייה זמני (mk_as_start).
   הלוח עצמו (/hanhala/) מנהל את המצב בעצמו וקורא את אותו מפתח (kr_as). */
(function(){
  'use strict';
  var KEY='kr_as';
  function get(){try{var a=JSON.parse(localStorage.getItem(KEY)||'null');return a&&a.phone&&a.real?a:null}catch(e){return null}}
  function set(a){try{if(a)localStorage.setItem(KEY,JSON.stringify(a));else localStorage.removeItem(KEY)}catch(e){}}
  if(/^\/hanhala(\/|$)/.test(location.pathname)||!window.fetch)return;
  var of=window.fetch.bind(window);
  /* קריאות שמותר להעביר; כל השאר נחשב שמירה ונחסם */
  var READ=/^(hanhala_(me|data|my|summary)|milui_(login|state|who)|toranut_(load|versions_list|version_get)|mk_(check_phone|login|get|get_settings|my_q|staff_list|staff_map|photos)|ped_data|get_\w+|list_plans|check_code|check_owner|planner_staff|feedback_mine)$/;
  var note='';
  function esc(x){return String(x==null?'':x).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]})}
  function json(o,st){return new Response(JSON.stringify(o),{status:st,headers:{'Content-Type':'application/json'}})}
  /* אסימון צפייה למפת כיתה: מונפק פעם אחת עם הטלפון והקוד של מנהל המערכת עצמו */
  var pending=null;
  function token(a,b,url,init){
    if(a.mk)return Promise.resolve(a.mk);
    if(pending)return pending;
    pending=of(url.replace(/\/rpc\/[A-Za-z0-9_]+/,'/rpc/mk_as_start'),Object.assign({},init,{body:JSON.stringify({p_phone:b.p_phone,p_pin:b.p_pin,p_target:a.phone})}))
      .then(function(r){return r.json()}).then(function(j){pending=null;
        if(j&&j.token){var c=get();if(c&&c.phone===a.phone){c.mk=j.token;set(c)}note='';bar();return j.token}
        note=j&&j.error==='no_target'?'אין לו/לה גישה למפת הכיתה, ולכן מוצגת התצוגה שלך':j&&j.error==='forbidden'?'במפת הכיתה המצב פתוח רק למנהל המערכת, ולכן מוצגת התצוגה שלך':'';bar();return null})
      .catch(function(){pending=null;return null});
    return pending;
  }
  window.fetch=function(input,init){
    var a=get(),url=typeof input==='string'?input:(input&&input.url)||'',m=/\/rest\/v1\/rpc\/([A-Za-z0-9_]+)/.exec(url);
    if(!a||!m||!init||typeof init.body!=='string')return of(input,init);
    var fn=m[1],b;try{b=JSON.parse(init.body)}catch(e){return of(input,init)}
    if(!b||typeof b!=='object')return of(input,init);
    if(!READ.test(fn)){toast();return Promise.resolve(json({message:'view_only',error:'view_only'},403))}
    if(/^mk_/.test(fn)){
      if(!('p_pin' in b))return of(input,init);
      var own={p_phone:b.p_phone,p_pin:b.p_pin};
      var go=function(retry){return token(a,own,url,init).then(function(t){
        if(!t)return of(input,init);
        var nb=Object.assign({},b,{p_phone:a.phone,p_pin:'kr-as:'+t});
        return of(input,Object.assign({},init,{body:JSON.stringify(nb)})).then(function(r){
          if(retry)return r;
          return r.clone().json().then(function(j){
            if(j&&j.error==='bad'){var c=get();if(c){delete c.mk;set(c);a=c}return go(true)}   /* האסימון פג: מנפיקים חדש פעם אחת */
            return r},function(){return r})})})};
      return go(false);
    }
    if('p_phone' in b){b.p_phone=a.phone;init=Object.assign({},init,{body:JSON.stringify(b)})}
    return of(input,init);
  };
  function stop(){var a=get();set(null);
    var done=function(){location.reload()};
    if(a&&a.mk&&window.KR_AS_CFG){of(KR_AS_CFG.url+'/rest/v1/rpc/mk_as_stop',{method:'POST',headers:{apikey:KR_AS_CFG.key,Authorization:'Bearer '+KR_AS_CFG.key,'Content-Type':'application/json'},body:JSON.stringify({p_token:a.mk})}).then(done,done)}
    else done()}
  window.KR_AS={get:get,stop:stop};
  window.KR_AS_CFG={url:'https://onocjgbtensczpdbeanf.supabase.co',key:'sb_publishable_JpV-E-qPnV9ZdnRnY9Kv8Q_TaRzCnyc'};
  var el=null,tt=null;
  function bar(){var a=get();if(!document.body)return;
    if(!a){if(el){el.remove();el=null;document.body.style.paddingBottom=''}return}
    if(!el){el=document.createElement('div');el.className='kras';el.setAttribute('role','status');document.body.appendChild(el);
      var st=document.createElement('style');st.textContent='.kras{position:fixed;inset:auto 0 0 0;z-index:60;display:flex;flex-wrap:wrap;align-items:center;justify-content:center;gap:6px 14px;padding:8px 14px calc(8px + env(safe-area-inset-bottom,0px));background:#5b3fa8;color:#fff;font:500 15px/1.35 Heebo,Assistant,system-ui,sans-serif;direction:rtl;box-shadow:0 -2px 10px rgba(20,20,60,.25)}'+
        '.kras b{font-weight:700}.kras button{font:600 15px Heebo,Assistant,system-ui,sans-serif;min-height:40px;padding:0 16px;border-radius:10px;border:0;background:#fff;color:#3b2780;cursor:pointer}.kras button:focus-visible{outline:3px solid #ffd54a;outline-offset:2px}'+
        '.kras a{color:#fff}.kras-t{position:fixed;left:50%;bottom:76px;transform:translateX(-50%);z-index:61;background:#1f2a37;color:#fff;padding:10px 16px;border-radius:10px;font:600 15px Heebo,Assistant,system-ui,sans-serif;direction:rtl;box-shadow:0 6px 20px rgba(0,0,0,.3)}@media print{.kras,.kras-t{display:none}}';
      document.head.appendChild(st)}
    el.innerHTML='<span>את/ה בנעליים של <b>'+esc(a.name||'')+'</b> · צפייה בלבד'+(note?' · '+esc(note):'')+'</span><button type="button">חזרה אליי</button><a href="/hanhala/#viewas">החלפת איש צוות</a>';
    el.querySelector('button').onclick=stop;
    document.body.style.paddingBottom=(el.offsetHeight+8)+'px';
  }
  function toast(){if(!document.body)return;var t=document.querySelector('.kras-t');if(!t){t=document.createElement('div');t.className='kras-t';t.setAttribute('role','alert');document.body.appendChild(t)}
    t.textContent='במצב "בנעליים של" אי אפשר לשמור שינויים.';clearTimeout(tt);tt=setTimeout(function(){t.remove()},3500)}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',bar);else bar();
  window.addEventListener('storage',function(e){if(e.key===KEY)location.reload()});
})();
