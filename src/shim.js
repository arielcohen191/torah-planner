/* Netlify build: connects the planner to Supabase through code-checked RPC functions.
   The page talks to window.claude.use(...) exactly like the Claude-hosted version. */
(function(){
  var URL_=window.PLANNER_CFG.url, KEY=window.PLANNER_CFG.key;
  function ls(k,v){try{if(v===undefined)return localStorage.getItem(k);if(v===null)localStorage.removeItem(k);else localStorage.setItem(k,v)}catch(e){return null}}
  function rid(n){var a=new Uint8Array(n);crypto.getRandomValues(a);return Array.from(a,function(b){return 'abcdefghijklmnopqrstuvwxyz0123456789'[b%36]}).join('')}
  var owner;try{owner=JSON.parse(ls('planner-owner')||'null')}catch(e){}
  if(!owner||!owner.id||!owner.key){owner={id:'t'+rid(15),key:rid(32)};ls('planner-owner',JSON.stringify(owner))}
  async function rpc(fn,args){
    var r=await fetch(URL_+'/rest/v1/rpc/'+fn,{method:'POST',headers:{'apikey':KEY,'Authorization':'Bearer '+KEY,'Content-Type':'application/json'},body:JSON.stringify(args)});
    var t=await r.text(),j=t?JSON.parse(t):null;
    if(!r.ok){var m=(j&&j.message)||'error';var e=new Error(m);e.code=/not_owner|not_admin/.test(m)?'invalid_argument':/bad_code/.test(m)?'revoked':'unavailable';e.raw=m;if(/bad_code/.test(m)){ls('planner-code',null);location.reload()}throw e}
    return j;
  }
  var role=null,code=ls('planner-code'),ready;
  function snap(id,data){return {id:id,exists:!!data,data:function(){return data},metadata:{fromCache:false,hasPendingWrites:false}}}
  var cache=null,settings=null,docSubs=[],colSubs=[],setSubs=[];
  function emit(){
    var mine=cache&&cache.find(function(r){return r.id===owner.id});
    docSubs.forEach(function(f){f(snap(owner.id,mine?mine.data:null))});
    colSubs.forEach(function(f){var docs=(cache||[]).map(function(r){return snap(r.id,r.data)});f({docs:docs,size:docs.length,empty:!docs.length})});
  }
  async function refresh(){try{cache=await rpc('list_plans',{code:code});emit()}catch(e){}}
  async function refreshSettings(){try{settings=await rpc('get_settings',{code:code});setSubs.forEach(function(f){f(snap('school',settings))})}catch(e){}}
  var db={
    doc:function(p){
      if(p==='settings/school')return {
        set:async function(d){await rpc('save_settings',{code:code,holidays:d.holidays||[]});await refreshSettings()},
        onSnapshot:function(f){setSubs.push(f);if(settings)f(snap('school',settings));else refreshSettings();return function(){}}};
      return {
        set:async function(d){await rpc('save_plans',{code:code,owner_id:owner.id,owner_key:owner.key,payload:d});await refresh()},
        onSnapshot:function(f){docSubs.push(f);if(cache)emit();else refresh();return function(){}}};
    },
    collection:function(){return {onSnapshot:function(f){colSubs.push(f);if(cache)emit();else refresh();return function(){}}}}
  };
  setInterval(function(){if(code&&!document.hidden)refresh()},45000);
  var user={id:async function(){return owner.id},canEdit:async function(){return role==='admin'},can:async function(){return true},isOwner:async function(){return role==='admin'},me:async function(){throw new Error('none')}};
  var downloads={save:async function(o){var b=o.data instanceof Blob?o.data:new Blob([o.data]);var a=document.createElement('a');a.href=URL.createObjectURL(b);a.download=o.filename;document.body.appendChild(a);a.click();setTimeout(function(){URL.revokeObjectURL(a.href);a.remove()},1500)}};

  /* login gate */
  ready=new Promise(function(resolve){
    async function tryCode(c){try{var r=await rpc('check_code',{code:c});return r}catch(e){return null}}
    function gate(msg){
      var box=document.createElement('div');box.id='gate';
      box.innerHTML='<div class="gate-card"><div class="mark">כ״ר</div><h1>מתכנן הספק · תשפ״ז</h1><p>כנפי רוח · הכניסה לצוות בלבד</p><form id="gateForm"><label class="f">קוד בית הספר<input id="gateCode" autocomplete="current-password" type="password" required></label><button class="btn primary" type="submit">כניסה</button><p class="note-line" id="gateMsg" role="alert"></p></form></div>';
      document.body.appendChild(box);
      document.getElementById('gateMsg').textContent=msg||'';
      document.getElementById('gateForm').addEventListener('submit',async function(e){e.preventDefault();var c=document.getElementById('gateCode').value.trim();document.getElementById('gateMsg').textContent='בודק…';
        var r=await tryCode(c);if(!r){document.getElementById('gateMsg').textContent='הקוד לא נכון. בדקו מול הרכז.';return}
        code=c;role=r;ls('planner-code',c);box.remove();resolve()});
      setTimeout(function(){var i=document.getElementById('gateCode');if(i)i.focus()},50);
    }
    function start(){if(!code)return gate();tryCode(code).then(function(r){if(r){role=r;resolve()}else{ls('planner-code',null);code=null;gate('הקוד השתנה. נא להזין את הקוד החדש.')}})}
    if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start);else start();
  });
  window.claude={standalone:true,use:async function(n){await ready;return {db:db,user:user,downloads:downloads}[n]||null}};

  /* device transfer + sign-out, added once the page is ready */
  ready.then(function(){
    var foot=document.querySelector('.rail-foot');
    if(foot){var b=document.createElement('button');b.className='btn ghost';b.style.cssText='color:var(--rail-ink);padding:6px 0;margin-top:8px';b.textContent=role==='admin'?'יציאה (רכז)':'יציאה';b.onclick=function(){ls('planner-code',null);location.reload()};foot.appendChild(document.createElement('br'));foot.appendChild(b)}
    var mine=document.getElementById('v-mine');if(!mine)return;
    var w=document.createElement('div');w.className='w';
    w.innerHTML='<div class="w-h"><h2>עבודה ממחשב אחר</h2></div><div class="w-b"><p class="hint">התוכניות שלך משויכות למכשיר הזה. כדי לערוך אותן גם ממחשב או טלפון אחר, העתיקו את קוד ההעברה והדביקו אותו שם.</p><div class="fields"><label class="f">קוד ההעברה של המכשיר הזה<input id="xferOut" readonly></label><label class="f">הדבקת קוד ממכשיר אחר<input id="xferIn" placeholder="הדביקו כאן"></label></div><div class="actions"><button class="btn" id="xferCopy">העתקה</button><button class="btn primary" id="xferUse">שימוש בקוד שהודבק</button></div><p class="note-line" id="xferMsg"></p></div>';
    mine.appendChild(w);
    document.getElementById('xferOut').value=owner.id+'.'+owner.key;
    document.getElementById('xferCopy').onclick=async function(){var i=document.getElementById('xferOut');try{await navigator.clipboard.writeText(i.value);document.getElementById('xferMsg').textContent='הועתק.'}catch(e){i.select()}};
    document.getElementById('xferUse').onclick=function(){var v=document.getElementById('xferIn').value.trim().split('.');if(v.length!==2||v[1].length<16){document.getElementById('xferMsg').textContent='הקוד לא תקין.';return}
      ls('planner-owner',JSON.stringify({id:v[0],key:v[1]}));location.reload()};
  });
})();
