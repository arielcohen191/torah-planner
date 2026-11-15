/* מצב הדגמה · כנפי רוח
   משתמש בדוי (טלפון 050-0000000, סיסמה במפת הכיתה: 1234) עם כיתה בדויה ה׳7, מורים בדויים ונתונים מלאים.
   שום דבר לא נשלח לשרת ולא נשמר: כל הקריאות של המשתמש הזה נענות כאן, בדפדפן.
   התאריכים מחושבים מהיום, כך שההדגמה נראית "חיה" בכל יום שפותחים אותה. */
(function(){
  'use strict';
  const PHONE='0500000000',PIN='1234',CLS="ה' 7",CLS2="ה' 8",CLS3="ה' 9";
  const digits=p=>String(p||'').replace(/\D/g,'').replace(/^972/,'0');
  const isDemo=p=>digits(p)===PHONE;

  const pad=n=>String(n).padStart(2,'0');
  const iso=d=>d.getFullYear()+'-'+pad(d.getMonth()+1)+'-'+pad(d.getDate());
  const parse=s=>{const p=s.split('-');return new Date(+p[0],+p[1]-1,+p[2])};
  const add=(s,n)=>{const d=parse(s);d.setDate(d.getDate()+n);return iso(d)};
  const dow=s=>parse(s).getDay();
  const school=s=>{let d=s;while(dow(d)===6)d=add(d,1);return d};
  const TODAY=school(iso(new Date()));
  const nextDay=s=>{let d=add(s,1);while(dow(d)===6)d=add(d,1);return d};
  const TOMORROW=nextDay(TODAY);

  const T={noam:'ישראלי נועם',michal:'לוי מיכל',david:'הרב כהן דוד',shira:'אברהמי שירה',yael:'מזרחי יעל',uri:'פרידמן אורי',tamar:'גבאי תמר'};
  const ME=T.noam;
  // מערכת השעות של ה׳7: [מקצוע, מורה] לכל שעה, ראשון עד שישי
  const GRID=[
    [['חומש','noam'],['עברית','michal'],['מתמטיקה','michal'],['אנגלית','shira'],['משנה','noam'],['חנ"ג','uri']],
    [['נביא','noam'],['מתמטיקה','michal'],['מדעים','yael'],['עברית','michal'],['הלכה','david'],['אנגלית','shira']],
    [['חומש','noam'],['אנגלית','shira'],['מתמטיקה','michal'],['מדעים','yael'],['שיחת חינוך','noam'],['אמנות','tamar']],
    [['משנה','noam'],['עברית','michal'],['חנ"ג','uri'],['מתמטיקה','michal'],['נביא','noam'],['הלכה','david']],
    [['חומש','noam'],['מדעים','yael'],['אנגלית','shira'],['עברית','michal'],['מתמטיקה','michal'],['מוזיקה','tamar']],
    [['פרשת השבוע','noam'],['עברית','michal'],['הלכה','david'],['שיחת חינוך','noam']]
  ];
  // השעות של נועם מחוץ לכיתה שלו
  const EXTRA=[[0,6,'שיעור','חומש',[CLS2]],[1,3,'שיעור','חומש',[CLS2]],[1,6,'חלון','',[]],[2,6,'שיעור','נביא',[CLS2]],[3,3,'שהייה','',[]],[4,6,'פרטני','',[]],[0,7,'שהייה','',[]]];
  let sid=1;const SLOTS=[];
  GRID.forEach((row,d)=>row.forEach((c,i)=>SLOTS.push({id:sid++,day:d,hour:i+1,kind:'שיעור',subject:c[0],teacher:T[c[1]],classes:[CLS]})));
  EXTRA.forEach(x=>SLOTS.push({id:sid++,day:x[0],hour:x[1],kind:x[2],subject:x[3]||x[2],teacher:ME,classes:x[4],detail:x[2]==='שהייה'?"צוות ה'":null}));

  // היעדרויות (נבחרות לפי היום, כך שבכל יום יש מה להראות): המורה עם הכי הרבה שעות בכיתה היום נעדר כל היום,
  // מורה נוסף נעדר בשעות שלו, ונועם עצמו נעדר שעתיים ביום הלימודים הבא
  const cnt={};SLOTS.filter(s=>s.day===dow(TODAY)&&s.classes.includes(CLS)&&s.teacher!==ME).forEach(s=>(cnt[s.teacher]=cnt[s.teacher]||[]).push(s.hour));
  const byLoad=Object.keys(cnt).sort((x,y)=>cnt[y].length-cnt[x].length);
  const A1=byLoad[0]||T.shira,A2=byLoad[1]||T.yael;
  const ABS=[{id:901,name:A1,from:TODAY,to:TODAY,hours:null},{id:902,name:A2,from:TODAY,to:TODAY,hours:cnt[A2]||[3]},{id:903,name:ME,from:TOMORROW,to:TOMORROW,hours:SLOTS.filter(s=>s.teacher===ME&&s.kind==='שיעור'&&s.day===dow(TOMORROW)).map(s=>s.hour).sort((x,y)=>x-y).slice(0,2)}];
  const absAt=(name,date,h)=>ABS.find(a=>a.name===name&&a.from<=date&&a.to>=date&&(!a.hours||a.hours.includes(h)));
  // מי מחליף: לסירוגין מחליף / איחוד / עוד פתוח
  const ASG=[];
  [TODAY,TOMORROW].forEach(date=>{let n=0;SLOTS.filter(s=>s.day===dow(date)&&s.kind==='שיעור'&&absAt(s.teacher,date,s.hour)).forEach(s=>{
    const k=s.teacher===ME?(n++===0?0:2):(n++%3);
    if(k===0)ASG.push({date,slot_id:s.id,status:'assigned',sub:s.teacher===ME?T.michal:(s.teacher===T.uri?T.tamar:T.uri),note:null});
    else if(k===1)ASG.push({date,slot_id:s.id,status:'other',sub:null,note:"איחוד עם ה׳8"});
  })});
  // נועם ממלא מקום היום בשעה שהוא פנוי
  const myToday=SLOTS.filter(s=>s.teacher===ME&&s.day===dow(TODAY)&&s.kind==='שיעור').map(s=>s.hour);
  const freeH=[1,2,3,4,5,6].find(h=>!myToday.includes(h))||7;

  const DUTY=['m@0@yard_m','b1@1@synth','b2@3@flE','e1@4@gate_e'];

  function my(){
    const mine=SLOTS.filter(s=>s.teacher===ME);
    return {teacher:{id:-1,name:ME},
      slots:mine.map(s=>[s.id,s.day,s.hour,s.kind,s.kind==='שיעור'?s.subject:'',s.classes,s.detail||null,null]),
      absences:ABS.filter(a=>a.name===ME).map(a=>({id:a.id,from:a.from,to:a.to,hours:a.hours})),
      covered:ASG.filter(x=>mine.some(s=>s.id===x.slot_id)),
      covering:[{date:TODAY,hour:freeH,subject:(SLOTS.find(s=>s.teacher===A1)||{}).subject||'שיעור',classes:[CLS2],for:A1,status:'assigned'}],
      homeroom:[{class:CLS,synced_at:new Date(Date.now()-36e5).toISOString(),
        slots:SLOTS.filter(s=>s.classes.includes(CLS)).map(s=>[s.day,s.hour,s.kind,s.subject,s.teacher,s.id]),
        absent:ASG.filter(x=>SLOTS.some(s=>s.id===x.slot_id&&s.classes.includes(CLS))),
        tabs:ABS.map(a=>({name:a.name,from:a.from,to:a.to,hours:a.hours}))}],
      duty:{keys:DUTY,yards:null,subs:[]},
      plans:[
        {subject:'torah',book:'שמות',grade:'ה',cls:'7',summary:{ok:true,from:'פרק א פסוק א',to:'פרק כד פסוק יח',count:660,unit:'פסוקים',finish:add(TODAY,170)},end:'2027-06-20'},
        {subject:'navi',book:'שמואל א',grade:'ה',cls:'7',summary:{ok:true,from:'פרק א פסוק א',to:'פרק טז פסוק כג',count:406,unit:'פסוקים',finish:add(TODAY,160)},end:'2027-06-20'},
        {subject:'mishna',book:'ברכות',grade:'ה',cls:'7',summary:{ok:true,from:'פרק א משנה א',to:'פרק ט משנה ה',count:57,unit:'משניות',finish:add(TODAY,150)},end:'2027-06-20'}]};
  }
  const meObj={name:ME,roles:[],role_label:'',tools:[],levels:{},layers:[],staff:false,can_manage:false,prefs:{}};

  /* ---------- מפת כיתה: 24 תלמידים בדויים ---------- */
  const NAMES=['אביתר אלון','אוריה ברק','אלחנן גולן','אריאל דהן','בניה הלפרין','דביר וקנין','הלל זכאי','ידידיה חדד','יהונתן טל','יואב יעקובי','יצחק כרמי','ישי לנדאו',
    'מתן מור','נבו נחמיאס','נריה סעדה','עדו עמר','עמיחי פרץ','צור צדוק','רועי קורן','שגיא רוזן','שילה שמעוני','שמואל תורג׳מן','תום אדרי','יאיר בן חיים'];
  const HOB=['כדורגל','נגינה בגיטרה','קריאת ספרים','שחמט','ציור','רכיבה על אופניים','בישול','בנייה בלגו','שחייה','תכנות'];
  const ST=['לב טוב ואכפתיות','שמחת חיים ואופטימיות','דרך ארץ וכבוד','אחריות וארגון','נחישות והתמדה','סקרנות אינטלקטואלית','יושרה ואמינות','יצירתיות וחשיבה מקורית','כישורים מעשיים / פיזיים','מנהיגות והובלה'];
  let seed=7;const rnd=()=>(seed=(seed*16807)%2147483647)/2147483647;
  const pick=a=>a[Math.floor(rnd()*a.length)];
  // פרופיל לכל תלמיד: 0 תקין, 1 בינוני, 2 דורש התערבות
  const PROFILE=[0,0,1,0,2,0,0,1,0,0,2,0,1,0,0,0,1,0,2,0,0,1,0,0];
  function code(p){const r=rnd();if(p===0)return r<.85?'1':'2';if(p===1)return r<.45?'1':r<.9?'2':'3';return r<.25?'1':r<.55?'2':'3'}
  function rows(){
    seed=7;
    return NAMES.map((n,i)=>{const p=PROFILE[i],r=new Array(64).fill('');
      r[1]=String(i+1);r[2]=n;
      r[3]=pick(['תלמיד חרוץ ונעים, אהוב על החברים','שואל שאלות מעמיקות בשיעורי תורה','עוזר לחברים בלי שמבקשים ממנו','מוביל בהפסקות ובפעילויות','שקט ומתמיד, מתקדם יפה']);
      r[4]=[pick(ST),pick(ST)].join(', ');r[5]=pick(HOB);
      r[6]=p===2?pick(['קושי בריכוז לאורך השיעור','מתקשה בהבנת הנקרא','קשיים חברתיים בהפסקות']):'';
      r[7]=i===4||i===18?'2':i===10?'3':'1';
      r[8]=i===7?'2':i===15?'4':'1';r[9]=i===7?'בוטנים':i===15?'אגוזים — מזרק אפיפן בתיק':'';
      r[10]=i===21||i===23?'3':'1';r[11]=i===23?'3':'1';
      r[12]=i===12?'2':i===18?'3':'1';r[13]=i===18?'2':i===10?'3':'1';r[14]=i===10?'4':'1';r[15]=i===3||i===16?'3':'1';
      [16,17,18,20,22,23,24,25,28,29,30,31,32,33,34,36,40,44,48].forEach(c=>r[c]=code(p));
      if(p===2){r[18]='3';r[22]='3'}
      r[19]=r[18]==='3'?'מתפרץ בכעס כשמתוסכל, צריך ליווי צמוד':'';
      r[21]=r[20]==='3'?'מבודד בהפסקות, כדאי לחבר לקבוצה':'';
      r[35]=r[22]==='3'?'מתקשה לשבת לאורך זמן ולהתחיל משימה לבד':'';
      r[26]=p===2?pick(['שילוב (2 ש"ש), הוראה מתקנת','שיחות עם היועצת','קבוצת כישורים חברתיים']):p===1&&rnd()<.4?'תגבור בקריאה':'';
      r[27]=i===3?'אבא במילואים מתחילת השנה':i===23?'עלה מצרפת לפני שנה':'';
      return r});
  }
  function reading(){seed=11;return {students:NAMES.map((n,i)=>{const p=PROFILE[i],s=p===2?45+Math.round(rnd()*15):p===1?62+Math.round(rnd()*18):78+Math.round(rnd()*20);
    return {n,s:String(s),p:s>=90?4:s>=80?3:s>=70?2:s>=60?1:0,c:s<60?'זקוק לתרגול שטף יומי':''}})}}
  let Q=null;
  /* ישיבות פדגוגיות: החלטות לכיתה ה׳7 (נשמרות רק בזיכרון של הדף) */
  let PID=10;const PDEC=[
    {id:1,created_at:add(TODAY,-20)+'T10:00:00Z',by:'רכזת שכבה ה׳',class:CLS,nature:'לימודי',scope:'student',students:[NAMES[4],NAMES[10]],answer:'תגבור קריאה פעמיים בשבוע עם המורה לשילוב',owner:'רכזת',due:add(TODAY,-3),status:'doing',notes:'התחיל בשבוע שעבר, חסרה שעה ביום חמישי',edit:true},
    {id:2,created_at:add(TODAY,-20)+'T10:05:00Z',by:'רכזת שכבה ה׳',class:CLS,nature:'רגשי',scope:'student',students:[NAMES[18]],answer:'שיחה עם ההורים ותיאום מפגש עם היועצת',owner:'מחנך',due:add(TODAY,4),status:'open',notes:null,edit:true},
    {id:3,created_at:add(TODAY,-20)+'T10:09:00Z',by:'רכזת שכבה ה׳',class:CLS,nature:'חברתי',scope:'class',students:[],answer:'פעילות גיבוש כיתתית לפני חנוכה',owner:'מחנך',due:add(TODAY,10),status:'open',notes:null,edit:true},
    {id:4,created_at:add(TODAY,-40)+'T10:00:00Z',by:'נועם ישראלי',class:CLS,nature:'התנהגותי',scope:'student',students:[NAMES[12]],answer:'כרטיס מעקב יומי עם חיזוק בסוף השבוע',owner:'מחנך',due:add(TODAY,-12),status:'done',notes:'עובד יפה, ממשיכים',edit:true}];
  /* תצוגת מורה מקצועי (כמו _mk_limited_rows בשרת): רק העמודות המותרות, והציונים רק במקצועות שהוא מלמד בכיתה */
  const SUBJ_COLS=[0,1,2,4,5,7,8,9,10,11,15,16,17,18,20,22,23,24,25,31,32,33,34];
  function subjRows(rs,grades){const ok=new Set(SUBJ_COLS);grades.forEach(g=>[0,1].forEach(k=>ok.add(g+k)));
    return rs.map(r=>r.map((x,i)=>ok.has(i)?x:''))}

  /* המשימות שלי (כלי המשימות): אישיות, ומשימות עם שותפים */
  const TPEOPLE=Object.values(T).filter(n=>n!==ME).map((n,i)=>({k:'d'+i,name:n}));
  let TID=4;const TODO=[{id:1,urgency:1,importance:1,title:'להחזיר טפסי טיול למזכירות',due:add(TODAY,-2),note:'חסרים עוד שלושה אישורים',done_at:null,created_at:add(TODAY,-6)+'T08:00:00Z',mine:true,by:ME,partners:[]},
    {id:2,title:'להכין דף חזרה לקראת המבחן',due:TODAY,note:null,done_at:null,created_at:add(TODAY,-3)+'T08:00:00Z',mine:true,by:ME,partners:[]},
    {id:3,title:'לתאם שיחה עם ההורים של אחד התלמידים',due:null,note:null,done_at:null,created_at:add(TODAY,-1)+'T08:00:00Z',mine:true,by:ME,partners:[]},
    {id:4,title:'להזין ציוני מחצית לגיליון',due:add(TODAY,3),note:'כל המחנכים בשכבה',done_at:null,created_at:add(TODAY,-2)+'T08:00:00Z',mine:false,by:'הנהלת בית הספר',my_note:null,closed:false,
      partners:[{k:'me',name:ME,done_at:null}].concat(TPEOPLE.slice(0,2).map((x,i)=>({k:x.k,name:x.name,done_at:i?null:add(TODAY,-1)+'T12:00:00Z'})))}];
  function rpc(fn,a){
    a=a||{};
    switch(fn){
      case 'hanhala_me':return meObj;
      case 'hanhala_data':return {me:meObj,classes:[CLS,CLS2],staff_n:7};
      case 'hanhala_my':return my();
      case 'hanhala_save_prefs':return null;
      case 'ped_data':return {me:{name:ME,lvl:0,tid:-1,layers:[],can_meet:false,homeroom:[CLS],principal:false},classes:[CLS],students:{[CLS]:NAMES},decisions:PDEC,meetings:[],homerooms:[],teachers:Object.values(T).map(n=>({name:n,classes:[...new Set(SLOTS.filter(x=>x.teacher===n).flatMap(x=>x.classes))]}))};
      case 'ped_save_decision':{const p=a.p||{};PDEC.push({id:++PID,created_at:new Date().toISOString(),by:'נועם ישראלי',class:p.class,nature:p.nature,scope:p.scope,students:p.scope==='student'?p.students:[],answer:p.answer,owner:p.owner,due:p.due,status:'open',notes:null,edit:true,nature_other:p.nature==='אחר'?p.nature_other:null,owner_name:p.owner==='מורה מקצועי'?p.owner_name:null});PDEC.sort((x,y)=>x.due<y.due?-1:1);return PID}
      case 'ped_update_decision':{const d=PDEC.find(x=>x.id===a.p_id),p=a.p||{};if(d){if(p.status)d.status=p.status;if('notes' in p)d.notes=p.notes||null;if(p.due)d.due=p.due;if(p.owner){d.owner=p.owner;d.owner_name=p.owner==='מורה מקצועי'?p.owner_name:null}}return null}
      case 'tasks_list':return {name:ME,report:false,people:TPEOPLE,tasks:TODO};
      case 'tasks_save':{const p=a.p||{};let x=TODO.find(y=>y.id===p.id);if(!x){x={id:++TID,created_at:new Date().toISOString(),done_at:null,mine:true,by:ME,partners:[]};TODO.push(x)}x.title=p.title;x.due=p.due||null;x.note=p.note||null;x.urgency=p.urgency||null;x.importance=p.importance||null;
        if(p.partners)x.partners=p.partners.map(k=>(x.partners.find(q=>q.k===k)||{k,name:(TPEOPLE.find(q=>q.k===k)||{}).name,done_at:null,note:null}));return x.id}
      case 'tasks_done':{const x=TODO.find(y=>y.id===a.p_id);if(x){x.done_at=a.p_done?new Date().toISOString():null;const m=x.partners.find(q=>q.k==='me');if(m)m.done_at=x.done_at}return null}
      case 'tasks_note':{const x=TODO.find(y=>y.id===a.p_id);if(x)x.my_note=a.p_note||null;return null}
      case 'tasks_delete':{const i=TODO.findIndex(y=>y.id===a.p_id);if(i>=0)TODO.splice(i,1);return null}
      case 'mk_check_phone':return {status:'pin'};
      case 'mk_login':case 'mk_create_pin':return a.p_pin===PIN||a.p_new_pin?{name:'נועם ישראלי',role:'teacher',class_name:CLS,classes:[{class_name:CLS,has_data:true,teacher:'נועם ישראלי'},{class_name:CLS2,has_data:true,teacher:'מחנך ה׳8',limited:true},{class_name:CLS3,has_data:true,teacher:'מחנך ה׳9',limited:true}],can_manage:false}:{error:'bad'};
      case 'mk_shiluv_pick':try{sessionStorage.setItem('kr_demo_pick',JSON.stringify(a.p_students||[]))}catch(e){}return {ok:true,n:(a.p_students||[]).length};
      case 'mk_get':if(a.p_class===CLS3){ /* כיתת הדגמה למורה שילוב: בוחרים תלמידים בכניסה הראשונה */
          let pick=null;try{pick=JSON.parse(sessionStorage.getItem('kr_demo_pick'))}catch(e){}
          const all=rows(),ok=new Set([0,1,2,4,5,6,7,8,9,10,11,15,16,17,18,20,22,23,24,25,26,31,32,33,34,36,37,40,41,44,45,48,49]);
          const pr=pick?all.filter(r=>pick.includes(r[2])).map(r=>r.map((x,i)=>ok.has(i)?x:'')):null;
          return {class_name:CLS3,teacher:'מחנך ה׳9',limited:true,shiluv:true,picked:pick||[],pick_set:pick!==null,roster:all.map(r=>[r[1],r[2]]),rows:pr,reading:null,voices:[],synced_at:new Date(Date.now()-36e5).toISOString()}}
        if(a.p_class===CLS2)return {class_name:CLS2,teacher:'מחנך ה׳8',limited:true,subjects:['מתמטיקה'],rows:subjRows(rows(),[40]),reading:null,voices:[],synced_at:new Date(Date.now()-36e5).toISOString(),sync_url:null};
        return {class_name:CLS,teacher:'נועם ישראלי',rows:rows(),reading:reading(),voices:[],synced_at:new Date(Date.now()-36e5).toISOString(),sync_url:null};
      case 'mk_my_q':return Q||{};
      case 'mk_save_q':Q={part_a:a.p_part_a,part_b:a.p_part_b};return {ok:true};
      case 'mk_change_pin':return {error:'forbidden'};
      default:return {error:'forbidden'};
    }
  }
  window.KR_DEMO={phone:PHONE,pin:PIN,isDemo,rpc,note:'מצב הדגמה: המשתמש, הכיתה, המורים והתלמידים בדויים. שום שינוי לא נשמר.'};
})();
