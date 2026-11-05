/* מנוע שיבוץ תורנויות חצר · כנפי רוח
   רץ בדפדפן (window.Toranut) וב־Node (require). אין תלות חיצונית. */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.Toranut = factory();
})(this, function () {
  'use strict';

  const DAYS = ['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי'];
  const LAYERS = ['א', 'ב', 'ג', 'ד', 'ה', 'ו'];

  /* ---------- הגדרות ברירת מחדל (ניתנות לעריכה במסך) ---------- */
  const DEFAULT_CONFIG = {
    shifts: [
      { id: 'm',  label: 'בוקר 7:45–8:00',            kind: 'morning', after: 0, days: [0, 1, 2, 3, 4, 5] },
      { id: 'b1', label: 'הפסקה ראשונה (10)',         kind: 'break',   after: 2, days: [0, 1, 2, 3, 4, 5] },
      { id: 'b2', label: 'הפסקה שנייה (12)',          kind: 'break',   after: 4, days: [0, 1, 2, 3, 4] },
      { id: 'e1', label: 'סיום 12:55 (שישי 11:55)',   kind: 'end',     after: 6, fri: 4, days: [0, 1, 2, 3, 4, 5] },
      { id: 'e2', label: 'סיום 13:35',                kind: 'end',     after: 7, days: [1, 2, 3, 4] }
    ],
    // layer: שכבה קבועה; yard: שם המגרש בטבלת חלוקת החצרות (השכבה משתנה לפי יום)
    stations: [
      { id: 'gate_m',  name: 'שער ביה"ס',                         shifts: ['m'], prio: 1 },
      { id: 'bldA_m',  name: 'כניסה למבנה א׳ / מנהלה',            shifts: ['m'] },
      { id: 'yard_m',  name: 'חצר מרכזית / דשא סינטטי',           shifts: ['m'] },
      { id: 'ahmash',  name: 'אחמ"ש (פטרול)',                      shifts: ['b1', 'b2'], ahmash: true, patrol: true, prio: 1 },
      { id: 'office',  name: 'ספסל כניסה למנהלה (מגרש משולב)',     shifts: ['b1', 'b2'], yard: 'מגרש משולב', seat: true },
      { id: 'synth',   name: 'ספסל דשא סינטטי',                    shifts: ['b1', 'b2'], yard: 'דשא סינטטי', seat: true },
      { id: 'grass',   name: 'מגרש דשא גדול',                      shifts: ['b1', 'b2'], yard: 'דשא גדול' },
      { id: 'backUp',  name: 'חצר אחורית עליון',                   shifts: ['b1', 'b2'], yard: 'מגרש עליון' },
      { id: 'backLo',  name: 'חצר אחורית תחתון',                   shifts: ['b1', 'b2'], yard: 'פינג פונג + תחתון' },
      { id: 'concr',   name: 'ספסלי בטון מעל המנהלה (חדש)',        shifts: ['b1', 'b2'], seat: true, prio: 3 },
      { id: 'flA',     name: 'קומת שכבה א',                        shifts: ['b1', 'b2'], layer: 'א', floor: true },
      { id: 'flB',     name: 'קומת שכבה ב',                        shifts: ['b1', 'b2'], layer: 'ב', floor: true },
      { id: 'flC',     name: 'קומת שכבה ג',                        shifts: ['b1', 'b2'], layer: 'ג', floor: true },
      { id: 'flD1',    name: 'קומת שכבה ד / חדר מדעים',            shifts: ['b1', 'b2'], layer: 'ד', floor: true },
      { id: 'flD2',    name: 'קומת שכבה ד / מרכז למידה',           shifts: ['b1', 'b2'], layer: 'ד', floor: true },
      { id: 'flE',     name: 'כניסה לקומת ה׳ (וכדורסל)',           shifts: ['b1', 'b2'], layer: 'ה', floor: true, yard: 'כדורסל' },
      { id: 'flF',     name: 'כניסה לקומת ו׳ (ופינג־פונג)',        shifts: ['b1', 'b2'], layer: 'ו', floor: true },
      { id: 'gate_e',  name: 'שער ורחבת יציאה',                    shifts: ['e1', 'e2'], prio: 1 },
      { id: 'clear_e', name: 'פינוי חצרות (פטרול)',                shifts: ['e1', 'e2'], patrol: true }
    ],
    // חלוקת מגרשים: שכבה לכל יום (ראשון…שישי). מתוך הגיליון "חלוקת מגרשים וחצרות".
    yards: {
      b1: {
        'מגרש משולב': ['ה', 'אב', 'ו', 'ד', 'ב', 'ג'],
        'דשא סינטטי': ['ב', 'ג', 'ב', 'ג', 'ה', 'ו'],
        'פינג פונג + תחתון': ['ג', 'ד', 'ה', 'ו', 'ו', 'ה'],
        'כדורסל': ['ד', 'ו', 'ד', 'ה', 'ג', 'ד'],
        'מגרש עליון': ['א', 'א', 'א', 'א', 'א', 'א'],
        'דשא גדול': ['ו', 'ה', 'ג', 'ב', 'ד', 'אב']
      },
      b2: {
        'מגרש משולב': ['ו', 'ד', 'ג', 'ב', 'ה'],
        'דשא סינטטי': ['ב', 'ג', 'ה', 'ג', 'ב'],
        'פינג פונג + תחתון': ['ד', 'ה', 'ד', 'ה', 'ו'],
        'כדורסל': ['ג', 'ב', 'ו', 'ו', 'ה'],
        'מגרש עליון': ['א', 'א', 'א', 'א', 'א'],
        'דשא גדול': ['ה', 'ו', 'ב', 'ד', 'ג']
      }
    },
    // מכסות לפי הכללים
    quota: { '45': 3, '3': 2, '12': 2, aide: 2, ahmash: 2 }
  };

  /* ---------- עזרים ---------- */
  const norm = s => String(s || '').replace(/^הרב\s+/, '').replace(/[`'"׳״]/g, '').replace(/[-–]/g, ' ').replace(/\s+/g, ' ').trim();
  const toks = s => norm(s).split(' ').filter(Boolean);
  function lev(a, b) {
    if (a === b) return 0; if (Math.abs(a.length - b.length) > 1) return 2;
    const m = a.length, n = b.length, d = [];
    for (let i = 0; i <= m; i++) { d[i] = [i]; }
    for (let j = 0; j <= n; j++) d[0][j] = j;
    for (let i = 1; i <= m; i++) for (let j = 1; j <= n; j++)
      d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
    return d[m][n];
  }
  const near = (t, list) => list.some(x => lev(t, x) <= (t.length > 3 ? 1 : 0));

  /** מציאת המורה במערכת השעות לפי שם משפחה + שם פרטי */
  function matchTimetable(last, first, tt) {
    const L = toks(last), F = toks(first);
    let best = null;
    for (const name of Object.keys(tt)) {
      const T = toks(name);
      if (!L.every(x => near(x, T))) continue;
      if (!F.length || !near(F[0], T)) continue;
      best = name; break;
    }
    return best;
  }

  const digits = s => String(s || '').split('').filter(c => /[0-5]/.test(c)).map(Number);
  const uniq = a => [...new Set(a)];

  /** טופס בתמצית ← רשומת איש צוות. tt = {שם: {id, p:[6 מחרוזות], l}} */
  function buildStaff(rows, tt) {
    const staff = [], usedTT = {};
    rows.forEach(r => {
      const [last, first, role, l1, l2, dcat, days, obstacle, opt, pref, noM, noE, note] = r;
      const ttName = matchTimetable(last, first, tt);
      if (ttName) usedTT[ttName] = 1;
      const layers = l1 === '*' ? '*' : uniq([l1, l2].filter(x => x && x !== '*')).join('') + (l2 === '*' ? '*' : '');
      const roleName = { T: 'teacher', A: 'aide', M: 'admin', O: 'other' }[role] || 'teacher';
      staff.push({
        id: 's' + (staff.length + 1),
        name: (first + ' ' + last).replace(/\s+/g, ' ').trim(),
        tt: ttName || null,
        role: roleName,
        layers,
        days: digits(days),
        dcat: dcat,
        status: 'in',
        ahmash: 'no',
        option: opt,
        pref: digits(pref),
        noMorning: digits(noM),
        noEnd: digits(noE),
        noShift: [],
        only: [],
        target: null,
        wantsMorning: false, wantsEnd: false, prefB2: false, seat: false,
        obstacle: obstacle || '', note: note || '', flag: '', form: true
      });
    });
    // מורים שבמערכת אבל לא מילאו שאלון
    Object.keys(tt).forEach(name => {
      if (usedTT[name]) return;
      const t = tt[name];
      const days = t.p.map((p, i) => /[^.]/.test(p) ? i : -1).filter(i => i >= 0 && !(i === 0 && /^\.+SS\.$/.test(t.p[0])));
      staff.push({
        id: 's' + (staff.length + 1), name: norm(name).split(' ').slice(1).join(' ') + ' ' + norm(name).split(' ')[0],
        tt: name, role: 'teacher', layers: (t.l || '').slice(0, 2) || '*', days, dcat: days.length >= 4 ? '45' : days.length === 3 ? '3' : '12',
        status: 'in', ahmash: 'no', option: 'N', pref: [], noMorning: [], noEnd: [], noShift: [], only: [], target: null,
        wantsMorning: false, wantsEnd: false, prefB2: false, seat: false, obstacle: '', note: '', flag: 'לא מילא/ה את השאלון — נלקח ממערכת השעות', form: false
      });
    });
    return staff;
  }

  /** ברירות מחדל לפי הכללים של המנהל והערות חופשיות בשאלון */
  function applyDefaults(staff) {
    const has = (s, ...names) => names.some(n => { const T = toks(s.name); return toks(n).every(x => near(x, T)); });
    const OUT = ['הודיה בן חמו', 'שירה בן עוליאל', 'יעל אוחנה', 'זוהר יוסיפוב', 'זכריה סלומון'];
    const AHMASH_ONLY = ['גילה פרטוש', 'אתי ארגי', 'אוריה עובד', 'עומר אידלסברג'];
    const AHMASH_CAN = ['מיטל אבוחצירא', 'ברקת מאור', 'אדיר בוסי'];
    staff.forEach(s => {
      if (OUT.some(n => has(s, n))) { s.status = 'out'; s.flag = 'ברשימת הסייעות שלא עושות תורנות (כללים)'; }
      if (/בת שירות|בנות שירות/.test(s.obstacle)) { s.status = 'out'; s.flag = 'בת שירות'; }
      if (AHMASH_ONLY.some(n => has(s, n))) s.ahmash = 'only';
      if (AHMASH_CAN.some(n => has(s, n))) s.ahmash = 'can';
      if (has(s, 'אלדד בר משה')) { s.only = ['b1@5', 'm@0', 'm@1', 'm@2', 'm@3', 'm@4', 'm@5']; s.wantsMorning = true; }
      if (has(s, 'שרה מיארה')) { s.only = ['b2@0']; s.target = 1; }
      if (has(s, 'נעמי לב')) s.noShift = ['b1@0', 'b1@3', 'b1@4', 'b1@5'];
      if (has(s, 'נפתלי בדלבייב')) { s.wantsMorning = true; s.prefB2 = true; }
      if (has(s, 'רעם טל')) { s.wantsMorning = true; s.prefB2 = true; }
      if (has(s, 'ברכי דהאן')) s.wantsMorning = true;
      if (has(s, 'אוריאן גזלה')) s.prefB2 = true;
      if (has(s, 'מוריה אבגי')) s.wantsEnd = true;
      if (has(s, 'ג׳ייסון ליפשטיין')) s.wantsEnd = true;
      if (has(s, 'שני חדרי')) s.seat = true;
      if (has(s, 'מיכל אושרי') && s.role === 'teacher') s.noEnd = [0, 1, 2, 3, 4, 5];
      if (has(s, 'דינה דהן')) s.noMorning = [0, 1, 2, 3, 4, 5];
      if (has(s, 'מיכל הסקין')) { s.noMorning = [0, 1, 2, 3, 4, 5]; s.noShift = ['e2@1', 'e2@2', 'e2@3', 'e2@4']; }
      if (has(s, 'יעל זרוג')) s.noMorning = [0, 1, 2, 3, 4, 5];
      // דגלים להחלטת הנהלה (לא משנים את השיבוץ — רק מסומנים)
      if (s.status === 'in' && s.obstacle && !s.flag) s.flag = 'ציין/ה מניעה — להחלטת הנהלה';
      if (s.ahmash === 'only' && !s.form) s.flag = 'הנהלה/אחמ"ש — לא מילא/ה שאלון';
    });
    return staff;
  }

  /* ---------- נוכחות לפי מערכת השעות ---------- */
  function afterHour(shift, day) { return day === 5 && shift.fri != null ? shift.fri : shift.after; }

  function presence(s, shift, day, tt) {
    if (!s.days.includes(day)) return { ok: false, why: 'לא עובד/ת ביום הזה' };
    const t = s.tt && tt[s.tt];
    if (!t) return { ok: true };
    const p = t.p[day] || '........';
    const has = h => h >= 1 && h <= 8 && p[h - 1] && p[h - 1] !== '.';
    const lesson = h => p[h - 1] === 'L';
    const a = afterHour(shift, day);
    if (shift.kind === 'morning') return has(1) ? { ok: true } : { ok: false, why: 'לא מתחיל/ה בשעה הראשונה' };
    if (shift.kind === 'break') {
      let before = false, aft = false;
      for (let h = 1; h <= a; h++) if (has(h)) before = true;
      for (let h = a + 1; h <= 8; h++) if (has(h)) aft = true;
      if (!before || !aft) return { ok: false, why: 'לא נמצא/ת בבית הספר בזמן ההפסקה' };
      return { ok: true, calm: !lesson(a + 1) };
    }
    if (shift.kind === 'end') {
      if (!has(a)) return { ok: false, why: 'מסיים/ת לפני הסיום' };
      if (lesson(a + 1)) return { ok: false, why: 'מלמד/ת בשעה שאחרי' };
      return { ok: true };
    }
    return { ok: true };
  }

  function formAllows(s, shift, day) {
    const key = shift.id + '@' + day;
    if (s.status !== 'in') return 'לא משובץ/ת (הוחרג/ה)';
    if (s.only && s.only.length && !s.only.includes(key)) return 'הגבלה אישית';
    if (s.noShift && s.noShift.includes(key)) return 'הגבלה אישית';
    if (shift.kind === 'morning' && s.noMorning.includes(day)) return 'ביקש/ה לא בבוקר ביום הזה';
    if (shift.kind === 'end' && s.noEnd.includes(day)) return 'ביקש/ה לא בסוף יום ביום הזה';
    return null;
  }

  function stationLayer(cfg, st, shift, day) {
    if (st.layer) return st.layer;
    if (st.yard && cfg.yards[shift.id] && cfg.yards[shift.id][st.yard]) return cfg.yards[shift.id][st.yard][day] || '';
    return '';
  }

  function stationOk(s, st, layer) {
    if (s.ahmash === 'only') return !!st.ahmash;
    if (st.ahmash) return s.ahmash === 'can';
    if (s.role === 'aide') {
      if (!st.floor) return false;
      return s.layers === '*' || s.layers.includes('*') || s.layers.includes(layer);
    }
    if (s.seat && st.patrol) return false;
    return true;
  }

  function targetOf(cfg, s) {
    if (s.target != null && s.target !== '') return +s.target;
    if (s.ahmash === 'only') return cfg.quota.ahmash;
    if (s.role === 'aide') return cfg.quota.aide;
    return cfg.quota[s.dcat] != null ? cfg.quota[s.dcat] : 3;
  }

  /* ---------- PRNG ---------- */
  function rng(seed) { let a = seed >>> 0; return () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }

  /* ---------- הכנה: כל העמדות + מי כשיר לכל עמדה ---------- */
  function prepare(cfg, staff, tt) {
    const SH = {}; cfg.shifts.forEach(x => SH[x.id] = x);
    const positions = [];
    cfg.shifts.forEach(shift => shift.days.forEach(day => cfg.stations.forEach(st => {
      if (!st.shifts.includes(shift.id)) return;
      const layer = stationLayer(cfg, st, shift, day);
      const elig = [], calm = {};
      staff.forEach((s, i) => {
        if (formAllows(s, shift, day)) return;
        const pr = presence(s, shift, day, tt); if (!pr.ok) return;
        if (!stationOk(s, st, layer)) return;
        elig.push(i); calm[i] = pr.calm !== false;
      });
      positions.push({ key: shift.id + '@' + day + '@' + st.id, shift, day, st, layer, elig, calm });
    })));
    const opts = staff.map(() => 0);
    positions.forEach(p => p.elig.forEach(i => opts[i]++));
    return { SH, positions, opts, targets: staff.map(s => targetOf(cfg, s)) };
  }

  function scoreOf(cfg, s, i, pos, st8, prep, rand) {
    const { shift, day, st, layer } = pos;
    const tgt = prep.targets[i], used = st8.load[i];
    let sc = 0;
    if (s.role === 'aide') sc -= 1.5;
    if (s.ahmash === 'can' && !st.ahmash) sc -= 1;
    if (st.ahmash && s.ahmash === 'only') sc += 2;
    sc += 2 * (tgt - used) / Math.max(1, tgt);
    sc += 4 / (1 + prep.opts[i]);
    // שכבה
    const L = s.layers || '';
    if (layer) {
      if (L.includes('*')) sc += 1;
      else if ([...layer].includes(L[0])) sc += 4;
      else if ([...layer].some(x => L.includes(x))) sc += 2;
    }
    // אותה עמדה כמו בתורנויות האחרות
    if (st8.stUsed[i][st.id]) sc += 3;
    // יום תורנות מרוכז
    const dayUnits = st8.dayUsed[i];
    const duty = (s.dcat === '45' || s.dcat === '3') && s.role !== 'aide' && s.ahmash !== 'only';
    if (duty) {
      if (dayUnits[day]) sc += 5;
      else {
        const hasPair = Object.values(dayUnits).some(n => n >= 2);
        const single = Object.keys(dayUnits).some(d => dayUnits[d] === 1);
        if (hasPair && shift.id === 'b1') sc += 2;
        if (!hasPair && single) sc -= 2;
      }
    } else if (s.dcat === '12' && shift.id === 'b1' && !st8.hasB1[i]) sc += 2;
    // עדיפות ימים
    const rank = s.pref.indexOf(day);
    if (rank === 0) sc += 2.5; else if (rank === 1) sc += 1.5; else if (rank === 2) sc += 0.8;
    // יום/שעה רגועים
    if (shift.kind === 'break' && pos.calm[i]) sc += 1;
    if (shift.kind === 'morning') sc += s.wantsMorning ? 5 : 0;
    if (shift.id === 'b2' && s.prefB2) sc += 2;
    if (shift.kind === 'end') { if (s.wantsEnd) sc += 4; if (dayUnits[day]) sc += 3; }
    if (s.seat && st.seat) sc += 4;
    return sc + rand() * 1.5;
  }

  function runOnce(cfg, staff, prep, seed) {
    const rand = rng(seed);
    const n = staff.length;
    const st8 = {
      load: new Array(n).fill(0),
      at: staff.map(() => ({})),
      dayUsed: staff.map(() => ({})),
      stUsed: staff.map(() => ({})),
      hasB1: new Array(n).fill(false)
    };
    const open = prep.positions.slice();
    const assign = {}, unfilled = [];
    let total = 0;
    const can = (i, pos) => st8.load[i] < prep.targets[i] && !st8.at[i][pos.shift.id + '@' + pos.day];
    while (open.length) {
      let bi = -1, bc = Infinity;
      const cellOpen = {};
      for (const p of open) { const ck = p.shift.id + '@' + p.day; cellOpen[ck] = (cellOpen[ck] || 0) + 1; }
      for (let k = 0; k < open.length; k++) {
        let c = 0; const p = open[k];
        for (const i of p.elig) if (can(i, p)) c++;
        // עדיפות עמדה קודם; אחר כך המשבצת שבה הכי מעט אנשים פנויים ביחס לעמדות שנשארו בה
        const w = (p.st.prio || 2) * 1000 + c / cellOpen[p.shift.id + '@' + p.day] + rand() * 0.3;
        if (w < bc) { bc = w; bi = k; }
      }
      const pos = open.splice(bi, 1)[0];
      let best = -1, bs = -Infinity;
      for (const i of pos.elig) {
        if (!can(i, pos)) continue;
        const sc = scoreOf(cfg, staff[i], i, pos, st8, prep, rand);
        if (sc > bs) { bs = sc; best = i; }
      }
      if (best < 0) { unfilled.push(pos); continue; }
      assign[pos.key] = best; total += bs;
      st8.load[best]++; st8.at[best][pos.shift.id + '@' + pos.day] = 1;
      st8.dayUsed[best][pos.day] = (st8.dayUsed[best][pos.day] || 0) + 1;
      st8.stUsed[best][pos.st.id] = (st8.stUsed[best][pos.st.id] || 0) + 1;
      if (pos.shift.id === 'b1') st8.hasB1[best] = true;
    }
    return { assign, unfilled, total, load: st8.load, dayUsed: st8.dayUsed };
  }

  /** הרצה: כמה סבבים, נשאר הטוב ביותר. locked = {posKey: staffId} שיבוצים ידניים קבועים */
  function solve(cfg, staff, tt, opts) {
    opts = opts || {};
    const iters = opts.iterations || 120;
    const locked = opts.locked || {};
    const idx = {}; staff.forEach((s, i) => idx[s.id] = i);
    const prep = prepare(cfg, staff, tt);
    // שיבוצים נעולים: מורידים מהעמדות הפתוחות ומקטינים מכסה
    const lockedPos = prep.positions.filter(p => locked[p.key] && idx[locked[p.key]] != null);
    if (lockedPos.length) {
      prep.positions = prep.positions.filter(p => !(locked[p.key] && idx[locked[p.key]] != null));
      lockedPos.forEach(p => { const i = idx[locked[p.key]]; prep.targets[i] = Math.max(0, prep.targets[i] - 1); });
      // מי שנעול באותה משמרת לא יכול להיות שוב באותה משמרת — מטופל ע"י סינון
      const busy = {}; lockedPos.forEach(p => busy[idx[locked[p.key]] + '|' + p.shift.id + '@' + p.day] = 1);
      prep.positions.forEach(p => p.elig = p.elig.filter(i => !busy[i + '|' + p.shift.id + '@' + p.day]));
    }
    let best = null;
    for (let k = 0; k < iters; k++) {
      const r = runOnce(cfg, staff, prep, (opts.seed || 7) * 1000 + k);
      const v = r.unfilled.length * 1000 - r.total;
      if (!best || v < best.v) { best = r; best.v = v; }
    }
    const assign = {};
    Object.keys(best.assign).forEach(k => assign[k] = staff[best.assign[k]].id);
    lockedPos.forEach(p => assign[p.key] = locked[p.key]);
    return report(cfg, staff, tt, assign);
  }

  /* ---------- דוח: מה מלא, מה תקוע ולמה ---------- */
  function report(cfg, staff, tt, assign) {
    const SH = {}; cfg.shifts.forEach(x => SH[x.id] = x);
    const ST = {}; cfg.stations.forEach(x => ST[x.id] = x);
    const byId = {}; staff.forEach(s => byId[s.id] = s);
    const all = [];
    cfg.shifts.forEach(shift => shift.days.forEach(day => cfg.stations.forEach(st => {
      if (st.shifts.includes(shift.id)) all.push({ key: shift.id + '@' + day + '@' + st.id, shift, day, st, layer: stationLayer(cfg, st, shift, day) });
    })));
    const load = {}; staff.forEach(s => load[s.id] = []);
    Object.keys(assign).forEach(k => { if (load[assign[k]]) load[assign[k]].push(k); });
    const unfilled = all.filter(p => !assign[p.key]);

    // לכל משבצת (משמרת+יום): ביקוש מול היצע, ולמה אנשים לא זמינים
    const cells = {};
    all.forEach(p => {
      const ck = p.shift.id + '@' + p.day;
      const c = cells[ck] || (cells[ck] = { shift: p.shift, day: p.day, demand: 0, filled: 0, unfilled: [] });
      c.demand++; if (assign[p.key]) c.filled++; else c.unfilled.push(p);
    });
    Object.values(cells).forEach(c => {
      if (!c.unfilled.length) return;
      const why = {}; let free = 0, busyQuota = 0;
      staff.forEach(s => {
        if (s.status !== 'in') return;
        const f = formAllows(s, c.shift, c.day);
        if (f) { why[f] = (why[f] || 0) + 1; return; }
        const pr = presence(s, c.shift, c.day, tt);
        if (!pr.ok) { why[pr.why] = (why[pr.why] || 0) + 1; return; }
        const k = c.shift.id + '@' + c.day;
        if (load[s.id].some(x => x.startsWith(k + '@'))) return; // כבר משובץ/ת כאן
        if (load[s.id].length >= targetOf(cfg, s)) { busyQuota++; return; }
        free++;
      });
      c.why = why; c.atQuota = busyQuota; c.freeButIneligible = free;
    });
    Object.values(cells).forEach(c => {
      // כמה אנשים בכלל יכולים להיות כאן (בלי להתחשב במכסה)
      c.possible = staff.filter(s => s.status === 'in' && !formAllows(s, c.shift, c.day) && presence(s, c.shift, c.day, tt).ok).length;
    });

    const people = staff.map(s => {
      const tgt = s.status === 'in' ? targetOf(cfg, s) : 0;
      const got = load[s.id].length;
      const days = {}; load[s.id].forEach(k => { const d = +k.split('@')[1]; days[d] = (days[d] || 0) + 1; });
      const pattern = Object.values(days).some(n => n >= 2);
      return { id: s.id, name: s.name, role: s.role, status: s.status, target: tgt, got, slots: load[s.id], pattern, flag: s.flag };
    });

    const supply = people.reduce((a, p) => a + p.target, 0);
    return {
      assign, unfilled: unfilled.map(p => p.key), cells,
      people,
      stats: {
        demand: all.length, filled: all.length - unfilled.length, open: unfilled.length,
        supply, staffIn: staff.filter(s => s.status === 'in').length, staffOut: staff.filter(s => s.status !== 'in').length
      }
    };
  }

  /* ---------- ייבוא מהגיליון (שורות גולמיות) ---------- */
  const DAYMAP = { 'ראשון': 0, 'שני': 1, 'שלישי': 2, 'רביעי': 3, 'חמישי': 4, 'שישי': 5 };
  const daysOf = txt => uniq((String(txt || '').match(/יום (ראשון|שני|שלישי|רביעי|חמישי|שישי)/g) || []).map(x => DAYMAP[x.slice(4)])).join('');
  const layerOf = txt => { const m = String(txt || '').match(/שכבה ([א-ו])/); return m ? m[1] : /לרוחב/.test(txt) ? '*' : ''; };
  /** values: מערך דו־ממדי מהגיליון (שורת כותרת בשורה 2). מחזיר שורות בפורמט התמציתי */
  function parseSheet(values) {
    const rows = [];
    const hi = values.findIndex(r => r && r.some(c => /שם משפחה/.test(c)));
    for (let r = hi + 1; r < values.length; r++) {
      const v = values[r]; if (!v || !v[1]) continue;
      const roleTxt = v[3] || '';
      const role = /תומך|סייע/.test(roleTxt) ? 'A' : /מנהלה|הנהלה/.test(roleTxt) ? 'M' : /אחר/.test(roleTxt) ? 'O' : 'T';
      const dc = /1–2|1-2/.test(v[6]) ? '12' : /^3/.test(v[6]) ? '3' : '45';
      const obstacle = /^לא\. אין מניעה/.test(v[8] || '') ? '' : (v[8] || '');
      const opt = /אפשרות א/.test(v[9]) ? 'A' : /אפשרות ב/.test(v[9]) ? 'B' : 'N';
      const pref = [v[10], v[11], v[12]].map(x => { const m = String(x || '').match(/יום (ראשון|שני|שלישי|רביעי|חמישי|שישי)/); return m ? DAYMAP[m[1]] : ''; }).join('');
      const cant = txt => /יכול\/ה בכל ימי העבודה שלי/.test(txt) && !/לא יכול/.test(txt) ? '' : daysOf(String(txt || '').replace(/יכול\/ה בכל ימי העבודה שלי,?/, ''));
      rows.push([String(v[1]).trim(), String(v[2] || '').trim(), role, layerOf(v[4]), layerOf(v[5]), dc, daysOf(v[7]), obstacle.trim(), opt, pref, cant(v[13]), cant(v[14]), String(v[16] || '').trim()]);
    }
    return rows;
  }

  return { DAYS, LAYERS, DEFAULT_CONFIG, buildStaff, applyDefaults, parseSheet, solve, report, presence, formAllows, targetOf, stationLayer, matchTimetable };
});
