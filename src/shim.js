/* Netlify build: connects the planner to Supabase. Open access, like a shared file:
   everyone sees and can edit everything. The only question asked is the teacher's name,
   which groups "my plans" and works the same on any device. */
(function(){
  var URL_=window.PLANNER_CFG.url, KEY=window.PLANNER_CFG.key, CODE='open', PIN='open';
  function ls(k,v){try{if(v===undefined)return localStorage.getItem(k);if(v===null)localStorage.removeItem(k);else localStorage.setItem(k,v)}catch(e){return null}}
  async function rpc(fn,args){
    if(ls('planner-demo')&&DEMO[fn])return DEMO[fn](args||{});
    var r=await fetch(URL_+'/rest/v1/rpc/'+fn,{method:'POST',headers:{'apikey':KEY,'Authorization':'Bearer '+KEY,'Content-Type':'application/json'},body:JSON.stringify(args)});
    var t=await r.text(),j=t?JSON.parse(t):null;
    if(!r.ok){var e=new Error((j&&j.message)||'error');e.code='unavailable';throw e}
    return j;
  }
  function normName(n){return String(n||'').replace(/["'״׳`]/g,'').replace(/^\s*(הרב|הר'|ר')\s+/,'').replace(/\s+/g,' ').trim()}
  /* identity = phone number: 050-1234567, 0501234567 and +972501234567 are the same teacher; only a hash is stored */
  function normPhone(p){var d=String(p||'').replace(/\D/g,'');if(d.indexOf('972')===0)d='0'+d.slice(3);return d}
  async function phoneId(p){var b=await crypto.subtle.digest('SHA-256',new TextEncoder().encode('tel:'+normPhone(p)));return 'p'+Array.from(new Uint8Array(b)).map(function(x){return x.toString(16).padStart(2,'0')}).join('').slice(0,40)}

  /* ---------- מצב הדגמה: 050-0000000 רכז/ת חומש ונביא, 050-0000001 מורה. כל התוכניות בדויות, ושום דבר לא נשלח לשרת או נשמר בו.
     התוכנית האמיתית של בית הספר (מיפוי תכנית הלימודים, חגים) נקראת מהשרת כרגיל, כי היא לא אישית. ---------- */
  var DEMO_USERS={'0500000000':{name:'נועם ישראלי',role:'coord',subjects:['torah','navi']},'0500000001':{name:'יונתן אדלר',role:'teacher'}};
  var DEMO_ID={};
  function demoIds(){return Promise.all(Object.keys(DEMO_USERS).map(function(ph){return phoneId(ph).then(function(id){DEMO_ID[ph]=id})}))}
  var DEMO_FIX=[ // [מורה, טלפון בדוי או null, שכבה, כיתה, מקצוע, ספר, מאיזה פרק, עד איזה פרק (null = סוף הספר), שעות בשבוע לפי יום, קצב, אחוז מהשבועות שסומנו "בוצע"]
    ['נועם ישראלי','0500000000','ה','7','torah','שמות',1,24,{0:1,2:1,4:1},7,1],
    ['נועם ישראלי','0500000000','ה','7','navi','שמואל א',1,16,{1:1,3:1},12,0.9],
    ['נועם ישראלי','0500000000','ה','7','mishna','ברכות',1,null,{0:1,3:1},1.2,1],
    ['יונתן אדלר','0500000001','ה','8','torah','שמות',1,24,{0:1,2:1,4:1},7,0.75],
    ['יונתן אדלר','0500000001','ה','8','navi','שמואל א',1,16,{1:1,3:1},12,0.8],
    ['הרב שלמה אוחיון',null,'ד','1','torah','ויקרא',1,null,{0:1,1:1,3:1},9,1],
    ['הרב יאיר שושן',null,'ג','2','torah','בראשית',1,25,{0:2,2:1,4:1},9,0.85],
    ['הרב עמיחי דהן',null,'ו','2','torah','דברים',1,null,{1:1,4:1},8,0.6],
    ['הרב אלחנן ברק',null,'ו','1','navi','מלכים א',1,14,{0:1,2:1},13,1],
    ['הרב משה טל',null,'ד','2','navi','שופטים',1,null,{2:1,4:1},9,0.9],
    ['הרב דוד כהן',null,'ה','7','halacha','קיצור שולחן ערוך',1,30,{1:1},0.5,1]];
  function demoIdx(U,perek,last){ // אינדקס היחידה הראשונה (או האחרונה) בפרק
    var re=new RegExp('^פרק '),hits=[];U.forEach(function(u,i){if(u.ch===perek||u.c===perek||u.chapter===perek)hits.push(i)});
    if(hits.length)return last?hits[hits.length-1]:hits[0];
    return last?U.length-1:0}
  function demoBuild(){
    var st={teachers:{},roles:{admins:{},coords:{},pending:[]}},today=new Date().toISOString().slice(0,10);
    Object.keys(DEMO_USERS).forEach(function(ph){var u=DEMO_USERS[ph];if(u.role==='coord')st.roles.coords[DEMO_ID[ph]]={name:u.name,tail:ph.slice(-3),subjects:u.subjects}});
    DEMO_FIX.forEach(function(f,i){
      var uid=f[1]?DEMO_ID[f[1]]:'pdemo'+i;var U=window.units(f[4],f[5],'')||[];
      var P={v:2,teacher:f[0],grade:f[2],cls:f[3],subject:f[4],book:f[5],mode:'seq',scope:'pace',breaks:{on:true,test:false,every:1,review:2},more:[],blocked:[],marathons:[],otherText:'',
        startIdx:demoIdx(U,f[6],false),endIdx:f[7]==null?U.length-1:demoIdx(U,f[7],true),days:f[8],pace:f[9],startDate:'2026-09-02',endDate:'2027-06-18',progress:{}};
      try{var H=allHol(),R=window.compute(P,H);window.weeks(P,R,H).filter(function(w){return w.label&&w.sun<=today}).forEach(function(w,k,a){P.progress[w.sun]={d:k<Math.round(a.length*f[10])}})}catch(e){}
      try{P.summary=window.summary(P)}catch(e){}
      P.updatedAt=new Date(Date.now()-(i*37+5)*36e5).toISOString();
      var t=st.teachers[uid]||(st.teachers[uid]={teacher:f[0],plans:{}});t.plans['pdemo'+i]=P;t.updatedAt=P.updatedAt});
    return st}
  function demoState(){var s=null;try{s=JSON.parse(sessionStorage.getItem('planner-demo-state'))}catch(e){}if(!s){s=demoBuild();demoSave(s)}return s}
  function demoSave(s){try{sessionStorage.setItem('planner-demo-state',JSON.stringify(s))}catch(e){}}
  var DEMO={
    list_plans:async function(){await demoIds();var s=demoState();return Object.keys(s.teachers).map(function(id){return {id:id,data:{teacher:s.teachers[id].teacher,updatedAt:s.teachers[id].updatedAt,plans:s.teachers[id].plans},updated_at:s.teachers[id].updatedAt}})},
    save_plans:async function(a){var s=demoState();s.teachers[a.owner_id]={teacher:a.payload.teacher,updatedAt:a.payload.updatedAt,plans:a.payload.plans||{}};demoSave(s);return true},
    get_roles:async function(){await demoIds();return demoState().roles},
    save_roles:async function(a){var s=demoState();s.roles=a.roles;demoSave(s);return true},
    planner_staff:async function(){await demoIds();return Object.keys(DEMO_USERS).map(function(ph){return {pid:DEMO_ID[ph],name:DEMO_USERS[ph].name}})}
  };
  var owner={id:ls('planner-id')||null,name:ls('planner-name')||''};
  function snap(id,data){return {id:id,exists:!!data,data:function(){return data},metadata:{fromCache:false,hasPendingWrites:false}}}
  var curr=null,currSubs=[],rolesSubs=[];var cache=null,settings=null,docSubs=[],colSubs=[],setSubs=[];
  function emit(){
    var mine=cache&&cache.find(function(r){return r.id===owner.id});
    docSubs.forEach(function(f){f(snap(owner.id,mine?mine.data:null))});
    colSubs.forEach(function(f){var docs=(cache||[]).map(function(r){return snap(r.id,r.data)});f({docs:docs,size:docs.length,empty:!docs.length})});
  }
  async function refresh(){try{cache=await rpc('list_plans',{code:CODE});emit()}catch(e){}}
  async function refreshSettings(){try{settings=await rpc('get_settings',{code:CODE});setSubs.forEach(function(f){f(snap('school',settings))})}catch(e){}}
  var db={
    doc:function(p){
      if(p==='settings/roles')return {
        set:async function(d){await rpc('save_roles',{code:CODE,roles:d});rolesSubs.forEach(function(f){f(snap('roles',d))})},
        onSnapshot:function(f){rolesSubs.push(f);rpc('get_roles',{code:CODE}).then(function(r){f(snap('roles',r||{}))}).catch(function(){f(snap('roles',{}))});return function(){}}};
      if(p==='settings/curriculum')return {
        set:async function(d){await rpc('save_curriculum',{code:CODE,map:d.map||{}});curr=d;currSubs.forEach(function(f){f(snap('curriculum',curr))})},
        onSnapshot:function(f){currSubs.push(f);rpc('get_curriculum',{code:CODE}).then(function(r){curr=r;f(snap('curriculum',r))}).catch(function(){});return function(){}}};
      if(p==='settings/school')return {
        set:async function(d){await rpc('save_settings',{code:CODE,holidays:d.holidays||[]});await refreshSettings()},
        onSnapshot:function(f){setSubs.push(f);if(settings)f(snap('school',settings));else refreshSettings();return function(){}}};
      return {
        set:async function(d){await rpc('save_plans',{code:CODE,owner_id:p.split('/')[1]||owner.id,owner_key:PIN,payload:d});await refresh()},
        onSnapshot:function(f){docSubs.push(f);if(cache)emit();else refresh();return function(){}}};
    },
    collection:function(){return {onSnapshot:function(f){colSubs.push(f);if(cache)emit();else refresh();return function(){}}}}
  };
  setInterval(function(){if(!document.hidden)refresh()},45000);
  var avatar=function(){return 'data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 36 36"><rect width="36" height="36" rx="18" fill="#2f6fd6"/><text x="18" y="23" font-size="15" text-anchor="middle" fill="#fff" font-family="Arial">'+(normName(owner.name)[0]||'?')+'</text></svg>')};
  var user={id:async function(){return owner.id},canEdit:async function(){return false},can:async function(){return true},isOwner:async function(){return false},
    me:async function(){return {id:owner.id,name:owner.name,avatarUrl:avatar(),isOwner:false,canEdit:false}}};
  var downloads={save:async function(o){var b=o.data instanceof Blob?o.data:new Blob([o.data]);var a=document.createElement('a');a.href=URL.createObjectURL(b);a.download=o.filename;document.body.appendChild(a);a.click();setTimeout(function(){URL.revokeObjectURL(a.href);a.remove()},1500)}};

  /* one question on first visit: the teacher's name */
  var ready=new Promise(function(resolve){
    function ask(){
      var box=document.createElement('div');box.id='gate';
      box.innerHTML='<div class="gate-card"><div class="mark">כ״ר</div><h1>מתכנן הספק · תשפ״ז</h1><p>כנפי רוח · תכנון שנתי בלימודי הקודש</p><form id="gateForm">'+
        '<label class="f">מספר הטלפון שלך<input id="gatePhone" type="tel" inputmode="tel" autocomplete="tel" placeholder="050-1234567" dir="ltr" style="text-align:right" required></label>'+
        '<label class="f">השם שלך<input id="gateName" autocomplete="name" placeholder="לדוגמה: הרב יוסף לוי" required></label>'+
        '<p class="note-line" style="margin:0">עם אותו מספר נכנסים מכל מחשב או טלפון ורואים את אותן תוכניות.</p>'+
        '<button class="btn primary" type="submit">יאללה, מתחילים</button><p class="note-line" id="gateMsg" role="alert" style="margin:0"></p></form></div>';
      document.body.appendChild(box);
      var P=document.getElementById('gatePhone'),N=document.getElementById('gateName'),M=document.getElementById('gateMsg');
      // known number -> fill the name it was saved with
      P.addEventListener('change',async function(){if(normPhone(P.value).length<9)return;var du=DEMO_USERS[normPhone(P.value)];if(du){N.value=du.name;M.textContent='משתמש הדגמה: כל הנתונים בדויים ושום דבר לא נשמר.';return}var id=await phoneId(P.value);try{var list=await rpc('list_plans',{code:CODE});var r=list.find(function(x){return x.id===id});if(r&&r.data&&r.data.teacher&&!N.value){N.value=r.data.teacher;M.textContent='שמחים לראות אותך שוב!';return}}catch(e){}
        try{var st=await staff.list();var t=(st||[]).find(function(x){return x.pid===id});if(t&&!N.value){N.value=t.name;M.textContent='מצאנו אותך ברשימת הצוות. אפשר לתקן את השם.'}}catch(e){}});
      document.getElementById('gateForm').addEventListener('submit',async function(e){e.preventDefault();
        var ph=normPhone(P.value),n=N.value.trim();
        if(!/^0[2-9][0-9]{7,8}$/.test(ph)){M.textContent='נא לכתוב מספר טלפון תקין.';return}
        if(normName(n).length<2){M.textContent='נא לכתוב את השם המלא.';return}
        ls('planner-demo',DEMO_USERS[ph]?ph:null);if(DEMO_USERS[ph])try{sessionStorage.removeItem('planner-demo-state')}catch(e){}
        owner.name=n;owner.id=await phoneId(ph);ls('planner-name',n);ls('planner-id',owner.id);box.remove();resolve()});
      setTimeout(function(){P.focus()},50);
    }
    async function start(){if(owner.id&&owner.id.charAt(0)==='p'&&owner.name)resolve();else ask()}
    if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start);else start();
  });
  var staffP=null,staff={list:function(){return staffP||(staffP=rpc('planner_staff',{}).catch(function(){staffP=null;return []}))}};
  window.claude={standalone:true,use:async function(n){await ready;return {db:db,user:user,downloads:downloads,staff:staff}[n]||null}};

  ready.then(function(){
    /* always-visible user chip in the top bar (desktop and phone) */
    var tb=document.querySelector('.topbar'),td=document.getElementById('today');
    if(tb&&td){var wrap=document.createElement('div');wrap.style.cssText='display:flex;gap:8px;align-items:center;flex-wrap:wrap;justify-content:flex-end';
      var chip=document.createElement('button');chip.type='button';chip.className='userchip';chip.title='החלפת משתמש';
      chip.innerHTML='<span class="uav"></span><span class="unm"></span><span class="usw">החלפה</span>';
      chip.querySelector('.uav').textContent=(normName(owner.name)[0]||'?');chip.querySelector('.unm').textContent=owner.name;
      chip.onclick=function(){if(chip.dataset.armed){ls('planner-name',null);ls('planner-id',null);ls('planner-demo',null);location.reload();return}chip.dataset.armed='1';chip.querySelector('.usw').textContent='ללחוץ שוב ליציאה';setTimeout(function(){delete chip.dataset.armed;chip.querySelector('.usw').textContent='החלפה'},3500)};
      td.parentNode.insertBefore(wrap,td);wrap.appendChild(chip);wrap.appendChild(td);}
    var foot=document.querySelector('.rail-foot');
    if(foot){var b=document.createElement('button');b.className='btn ghost';b.style.cssText='color:var(--rail-ink);padding:6px 0;margin-top:8px';b.textContent='לא '+owner.name+'? יציאה';b.onclick=function(){ls('planner-name',null);ls('planner-id',null);ls('planner-demo',null);location.reload()};foot.appendChild(document.createElement('br'));foot.appendChild(b)}
  });
})();
