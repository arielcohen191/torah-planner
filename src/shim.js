/* Netlify build: connects the planner to Supabase through code-checked RPC functions.
   The page talks to window.claude.use(...) exactly like the Claude-hosted version.
   Login = school code + teacher name + personal PIN (chosen on first login). Same name+PIN on any device = same plans. */
(function(){
  var URL_=window.PLANNER_CFG.url, KEY=window.PLANNER_CFG.key;
  function ls(k,v){try{if(v===undefined)return localStorage.getItem(k);if(v===null)localStorage.removeItem(k);else localStorage.setItem(k,v)}catch(e){return null}}
  async function rpc(fn,args){
    var r=await fetch(URL_+'/rest/v1/rpc/'+fn,{method:'POST',headers:{'apikey':KEY,'Authorization':'Bearer '+KEY,'Content-Type':'application/json'},body:JSON.stringify(args)});
    var t=await r.text(),j=t?JSON.parse(t):null;
    if(!r.ok){var m=(j&&j.message)||'error';var e=new Error(m);e.code=/not_owner|not_admin/.test(m)?'invalid_argument':/bad_code/.test(m)?'revoked':'unavailable';e.raw=m;if(/bad_code/.test(m)){signOut()}throw e}
    return j;
  }
  /* a stable id per teacher name: spacing, quotes and the "הרב" prefix don't matter */
  function normName(n){return String(n||'').replace(/["'״׳`]/g,'').replace(/^\s*(הרב|הר'|ר')\s+/,'').replace(/\s+/g,' ').trim()}
  async function nameId(n){var b=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(normName(n)));return 'n'+Array.from(new Uint8Array(b)).map(function(x){return x.toString(16).padStart(2,'0')}).join('').slice(0,40)}
  var sess=null;try{sess=JSON.parse(ls('planner-session')||'null')}catch(e){}
  var role=null,code=sess&&sess.code,owner=sess?{id:sess.id,key:sess.pin,name:sess.name}:{id:null,key:null,name:''},ready;
  function signOut(){ls('planner-session',null);location.reload()}
  function snap(id,data){return {id:id,exists:!!data,data:function(){return data},metadata:{fromCache:false,hasPendingWrites:false}}}
  var cache=null,settings=null,docSubs=[],colSubs=[],setSubs=[];
  function emit(){
    var mine=cache&&cache.find(function(r){return r.id===owner.id});
    docSubs.forEach(function(f){f(snap(owner.id,mine?mine.data:null))});
    colSubs.forEach(function(f){var docs=(cache||[]).map(function(r){return snap(r.id,r.data)});f({docs:docs,size:docs.length,empty:!docs.length})});
  }
  async function refresh(){try{cache=await rpc('list_plans',{code:code,owner_id:owner.id,owner_key:owner.key});emit()}catch(e){}}
  async function refreshSettings(){try{settings=await rpc('get_settings',{code:code});setSubs.forEach(function(f){f(snap('school',settings))})}catch(e){}}
  var db={
    doc:function(p){
      if(p==='settings/school')return {
        set:async function(d){await rpc('save_settings',{code:code,holidays:d.holidays||[]});await refreshSettings()},
        onSnapshot:function(f){setSubs.push(f);if(settings)f(snap('school',settings));else refreshSettings();return function(){}}};
      return {
        set:async function(d){await rpc('save_plans',{code:code,owner_id:p.split('/')[1]||owner.id,owner_key:owner.key,payload:d});await refresh()},
        onSnapshot:function(f){docSubs.push(f);if(cache)emit();else refresh();return function(){}}};
    },
    collection:function(){return {onSnapshot:function(f){colSubs.push(f);if(cache)emit();else refresh();return function(){}}}}
  };
  setInterval(function(){if(code&&!document.hidden)refresh()},45000);
  var user={id:async function(){return owner.id},canEdit:async function(){return role==='admin'},can:async function(){return true},isOwner:async function(){return role==='admin'},
    me:async function(){return {id:owner.id,name:owner.name,avatarUrl:'data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 36 36"><rect width="36" height="36" rx="18" fill="#2f6fd6"/><text x="18" y="23" font-size="15" text-anchor="middle" fill="#fff" font-family="Arial">'+(normName(owner.name)[0]||'?')+'</text></svg>'),isOwner:role==='admin',canEdit:role==='admin'}}};
  var downloads={save:async function(o){var b=o.data instanceof Blob?o.data:new Blob([o.data]);var a=document.createElement('a');a.href=URL.createObjectURL(b);a.download=o.filename;document.body.appendChild(a);a.click();setTimeout(function(){URL.revokeObjectURL(a.href);a.remove()},1500)}};

  /* login gate */
  ready=new Promise(function(resolve){
    function gate(msg){
      var box=document.createElement('div');box.id='gate';
      box.innerHTML='<div class="gate-card"><div class="mark">כ״ר</div><h1>מתכנן הספק · תשפ״ז</h1><p>כנפי רוח · כניסה לצוות</p><form id="gateForm">'+
        '<label class="f">קוד בית הספר<input id="gateCode" type="password" autocomplete="off" required></label>'+
        '<label class="f">השם שלך<input id="gateName" autocomplete="name" placeholder="לדוגמה: הרב יוסף לוי" required></label>'+
        '<label class="f">קוד אישי (4 ספרות)<input id="gatePin" type="password" inputmode="numeric" pattern="[0-9]{4,8}" maxlength="8" autocomplete="current-password" required></label>'+
        '<p class="note-line" style="margin:0">בכניסה הראשונה בוחרים קוד אישי. איתו נכנסים מכל מחשב או טלפון ורואים את אותן תוכניות.</p>'+
        '<button class="btn primary" type="submit">כניסה</button><p class="note-line" id="gateMsg" role="alert"></p></form></div>';
      document.body.appendChild(box);
      var M=document.getElementById('gateMsg');M.textContent=msg||'';
      if(sess&&sess.name)document.getElementById('gateName').value=sess.name;
      document.getElementById('gateForm').addEventListener('submit',async function(e){e.preventDefault();
        var c=document.getElementById('gateCode').value.trim(),n=document.getElementById('gateName').value.trim(),pin=document.getElementById('gatePin').value.trim();
        if(normName(n).length<2){M.textContent='נא לכתוב את השם המלא.';return}
        if(!/^[0-9]{4,8}$/.test(pin)){M.textContent='הקוד האישי הוא 4 עד 8 ספרות.';return}
        M.textContent='בודק…';
        var r=null;try{r=await rpc('check_code',{code:c})}catch(err){}
        if(!r){M.textContent='קוד בית הספר לא נכון. בדקו מול הרכז.';return}
        var id=await nameId(n),st=null;try{st=await rpc('check_owner',{code:c,owner_id:id,pin:pin})}catch(err){}
        if(st==='bad'){M.textContent='הקוד האישי לא מתאים לשם הזה. אם שכחת אותו, פנו לרכז לאיפוס.';return}
        if(!st){M.textContent='אין חיבור לשרת כרגע. נסו שוב בעוד רגע.';return}
        code=c;role=r;owner={id:id,key:pin,name:n};ls('planner-session',JSON.stringify({code:c,id:id,pin:pin,name:n}));box.remove();resolve();
      });
      setTimeout(function(){var i=document.getElementById(sess&&sess.name?'gateCode':'gateCode');if(i)i.focus()},50);
    }
    async function start(){
      if(!sess||!code||!owner.id)return gate();
      var r=null,st=null;try{r=await rpc('check_code',{code:code});if(r)st=await rpc('check_owner',{code:code,owner_id:owner.id,pin:owner.key})}catch(e){}
      if(r&&(st==='ok'||st==='new')){role=r;resolve()}else gate('צריך להתחבר מחדש.');
    }
    if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start);else start();
  });
  window.claude={standalone:true,use:async function(n){await ready;return {db:db,user:user,downloads:downloads}[n]||null}};

  ready.then(function(){
    var foot=document.querySelector('.rail-foot');
    if(foot){var b=document.createElement('button');b.className='btn ghost';b.style.cssText='color:var(--rail-ink);padding:6px 0;margin-top:8px';b.textContent='יציאה';b.onclick=signOut;foot.appendChild(document.createElement('br'));foot.appendChild(b)}
  });
})();
