/* מנוע שיבוץ תורנויות חצר · כנפי רוח
   רץ בדפדפן (window.Toranut) וב־Node (require). אין תלות חיצונית. */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.Toranut = factory();
})(this, function () {
  'use strict';

  const DAYS = ['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי'];
  const LAYERS = ['א', 'ב', 'ג', 'ד', 'ה', 'ו'];

  /* ---------- הגדרות ברירת מחדל (עמדות ומשמרות; הכללים — בנפרד) ---------- */
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
        'מגרש משולב': ['ה', 'הפסקה פעילה (א-ב)', 'ו', 'ד', 'ב', 'ג'],
        'דשא סינטטי': ['ב', 'ג', 'ב', 'ג', 'ה', 'ו'],
        'פינג פונג + תחתון': ['ג', 'ד', 'ה', 'ו', 'ו', 'ה'],
        'כדורסל': ['ד', 'ו', 'ד', 'ה', 'ג', 'ד'],
        'מגרש עליון': ['א', 'א', 'א', 'א', 'א', 'א'],
        'דשא גדול': ['ו', 'ה', 'ג', 'ב', 'ד', 'א+ב']
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
    // שורות הגיליון "חלוקת מגרשים וחצרות" ← העמדה שהתורן שלה אחראי על המגרש
    yardRows: [
      { key: 'מגרש משולב', name: 'מגרש משולב', st: 'office' },
      { key: 'דשא סינטטי', name: 'דשא סינטטי', st: 'synth' },
      { key: 'פינג פונג + תחתון', name: 'פינג פונג + מגרש תחתון בחצר האחורית', st: 'backLo' },
      { key: 'כדורסל', name: 'מגרש (כדורסל) בין מבנה א-ב למבנה ג-ד', st: 'flE' },
      { key: 'מגרש עליון', name: 'מגרש עליון בחצר האחורית והכניסה למבנה א-ב', st: 'backUp' },
      { key: 'דשא גדול', name: 'מגרש הדשא הגדול', st: 'grass' }
    ]
  };

  /** שכבות מתוך טקסט חופשי: "א+ב", "הפסקה פעילה (א-ב)", "ו" */
  function layerLetters(txt) {
    let t = String(txt || '');
    const m = t.match(/\(([^)]*)\)/); if (m) t = m[1];
    return [...new Set((t.match(/[אבגדהו]/g) || []))].join('');
  }

  /* ---------- עזרים ---------- */
  const norm = s => String(s || '').replace(/^הרב\s+/, '').replace(/[`'"׳״]/g, '').replace(/[-–]/g, ' ').replace(/\s+/g, ' ').trim();
  const toks = s => norm(s).split(' ').filter(Boolean);
  function lev(a, b) {
    if (a === b) return 0; if (Math.abs(a.length - b.length) > 1) return 2;
    const m = a.length, n = b.length, d = [];
    for (let i = 0; i <= m; i++) d[i] = [i];
    for (let j = 0; j <= n; j++) d[0][j] = j;
    for (let i = 1; i <= m; i++) for (let j = 1; j <= n; j++)
      d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
    return d[m][n];
  }
  const near = (t, list) => list.some(x => lev(t, x) <= (t.length > 3 ? 1 : 0));
  const sameName = (a, b) => { const B = toks(b); return toks(a).every(x => near(x, B)); };
  const digits = s => String(s || '').split('').filter(c => /[0-5]/.test(c)).map(Number);
  const uniq = a => [...new Set(a)];
  const ALLD = [0, 1, 2, 3, 4, 5];

  /** מציאת המורה במערכת השעות לפי שם משפחה + שם פרטי */
  function matchTimetable(last, first, tt) {
    const L = toks(last), F = toks(first);
    for (const name of Object.keys(tt)) {
      const T = toks(name);
      if (!L.every(x => near(x, T))) continue;
      if (!F.length || !near(F[0], T)) continue;
      return name;
    }
    return null;
  }

  /* ---------- אנשי צוות מהשאלון (בלי החלטות — אלה בכללים) ---------- */
  /** links: {שם בשאלון: שם במערכת} — קישור ידני כשהשם לא תואם (למשל שם באנגלית) */
  function buildStaff(rows, tt, links) {
    const staff = [], usedTT = {};
    links = links || {};
    rows.forEach(r => {
      const [last, first, role, l1, l2, dcat, days, obstacle, opt, pref, noM, noE, note, post] = r;
      const nm = (first + ' ' + last).replace(/\s+/g, ' ').trim();
      const ttName = (links[nm] && tt[links[nm]]) ? links[nm] : matchTimetable(last, first, tt);
      if (ttName) usedTT[ttName] = 1;
      const layers = l1 === '*' ? '*' : uniq([l1, l2].filter(x => x && x !== '*')).join('') + (l2 === '*' ? '*' : '');
      // השאלון לא תמיד כולל שכבה — אז לוקחים את השכבות שבהן מלמד/ת הכי הרבה שעות לפי מערכת השעות
      const ttL = ttName && tt[ttName] ? String(tt[ttName].l || '').slice(0, 2) : '';
      staff.push({
        id: 's' + (staff.length + 1), name: nm, tt: ttName || null,
        role: { T: 'teacher', A: 'aide', M: 'admin', O: 'other' }[role] || 'teacher',
        layers: layers || ttL, days: digits(days), dcat, option: opt, pref: digits(pref), noMorning: digits(noM), noEnd: digits(noE),
        obstacle: obstacle || '', note: note || '', post: post || '', form: true,
        flag: obstacle ? 'ציין/ה מניעה — להחלטת הנהלה' : ''
      });
    });
    Object.keys(tt).forEach(name => {
      if (usedTT[name]) return;
      const t = tt[name];
      const days = t.p.map((p, i) => /[^.]/.test(p) ? i : -1).filter(i => i >= 0 && !(i === 0 && /^\.+SS\.$/.test(t.p[0])));
      const n = norm(name).split(' ');
      staff.push({
        id: 's' + (staff.length + 1), name: n.slice(1).join(' ') + ' ' + n[0], tt: name, role: 'teacher',
        layers: (t.l || '').slice(0, 2) || '*', days, dcat: days.length >= 4 ? '45' : days.length === 3 ? '3' : '12',
        option: 'N', pref: [], noMorning: [], noEnd: [], obstacle: '', note: '', form: false,
        flag: 'לא מילא/ה את השאלון — נלקח ממערכת השעות'
      });
    });
    return staff;
  }

  /* =================================================================
     כללים
     כל כלל: {id, type, who:{roles,dcats,options,ids}, ...ערכים, on, src, note}
     סדר הרשימה = סדר הקדימות: כלל מאוחר יותר גובר על כלל מוקדם יותר
     לגבי מי ששניהם חלים עליו.
     ================================================================= */
  const ROLE = { teacher: 'מורים', aide: 'סייעות', admin: 'מנהלה', other: 'אחר' };
  const DCAT = { '45': '4 ימים ומעלה', '3': '3 ימים', '12': '1–2 ימים' };
  const OPT = { A: 'אפשרות א׳ (יום מרוכז)', B: 'אפשרות ב׳ (פריסה)', N: 'בלי העדפה' };
  const SHIFT_NAME = { m: 'תורנות בוקר', b1: 'הפסקת 10', b2: 'הפסקת 12', end: 'סוף יום' };
  const PATTERN = { day: 'יום תורנות מרוכז (+ תורנות בודדת ביום אחר)', spread: 'פריסה — תורנות אחת בכל יום', free: 'לפי צורכי המערכת' };
  const STATIONS = { any: 'כל עמדה', noPatrol: 'עמדה סטטית בלבד (לא פטרול)', seat: 'עמדה עם ישיבה', ownFloor: 'רק בקומה של השכבה שלו/ה' };
  const AHMASH = { no: 'לא אחמ"ש', can: 'יכול/ה גם אחמ"ש', only: 'אחמ"ש בלבד' };
  const SOFT = { sameStation: 'אותה עמדה בכל התורנויות', layer: 'ליד תלמידי השכבה (לפי חלוקת החצרות)', calm: 'ביום/שעה רגועים (לא לפני שיעור)', endSame: 'סוף יום — אותו תורן של אותו יום', prefDays: 'הימים המועדפים מהשאלון', near: 'בהפסקה — ליד הכיתה שלימד/ה לפני או ילמד/ה אחרי' };
  const LEVEL = ['כבוי', 'נמוך', 'רגיל', 'גבוה'];

  const TYPES = {
    quota:   { label: 'כמות תורנויות בשבוע' },
    pattern: { label: 'מתכונת' },
    shift:   { label: 'מספר פעמים במשמרת' },
    stations:{ label: 'סוג עמדה' },
    ahmash:  { label: 'אחמ"ש' },
    exclude: { label: 'החרגה משיבוץ' },
    slots:   { label: 'הגבלת ימים/משמרות' },
    post:    { label: 'עמדות מותרות בהפסקות' },
    endFree: { label: 'סוף יום — בלי שיעור פרונטלי בשעה שלפני' },
    soft:    { label: 'שיקול בשיבוץ' },
    note:    { label: 'הנחיה (לא נאכפת)' }
  };

  function key(r) {
    if (r.type === 'shift') return 'shift:' + r.shift + ':' + r.mode;
    if (r.type === 'soft') return 'soft:' + r.factor;
    if (r.type === 'slots') return 'slots:' + r.mode + ':' + (r.slots || []).slice().sort().join(',');
    if (r.type === 'note') return 'note:' + r.id;
    if (r.type === 'post') return 'post';
    if (r.type === 'endFree') return 'endFree';
    return r.type;
  }
  function sig(r) {
    switch (r.type) {
      case 'quota': return '' + r.n;
      case 'pattern': case 'stations': case 'ahmash': return r.v;
      case 'exclude': return r.v === false ? 'in' : 'out';
      case 'endFree': return (r.v === false ? 'off:' : 'on:') + (r.shifts || []).slice().sort().join(',');
      case 'shift': return r.n + (r.hard ? 'h' : 's');
      case 'post': return JSON.stringify([r.stations, r.layers, r.byDay, !!r.soft]);
      case 'soft': return '' + r.w;
      default: return JSON.stringify(r);
    }
  }

  function matches(r, s) {
    const w = r.who || {};
    if (w.ids && w.ids.length) return w.ids.includes(s.id);
    if (w.roles && w.roles.length && !w.roles.includes(s.role)) return false;
    if (w.dcats && w.dcats.length && !w.dcats.includes(s.dcat)) return false;
    if (w.options && w.options.length && !w.options.includes(s.option)) return false;
    return true;
  }
  const setOf = (r, staff) => staff.filter(s => matches(r, s)).map(s => s.id);

  function whoText(r, staff) {
    const w = r.who || {};
    if (w.ids && w.ids.length) {
      const by = {}; (staff || []).forEach(s => by[s.id] = s.name);
      const names = w.ids.map(id => by[id] || '?');
      return names.length > 4 ? names.slice(0, 4).join(', ') + ' ועוד ' + (names.length - 4) : names.join(', ');
    }
    const p = [];
    if (w.roles && w.roles.length) p.push(w.roles.map(x => ROLE[x]).join(' / '));
    if (w.dcats && w.dcats.length) p.push('שעובדים ' + w.dcats.map(x => DCAT[x]).join(' או '));
    if (w.options && w.options.length) p.push('שבחרו ' + w.options.map(x => OPT[x]).join(' או '));
    return p.length ? p.join(', ') : 'כל הצוות';
  }
  function whatText(r) {
    switch (r.type) {
      case 'quota': return r.n + ' תורנויות בשבוע';
      case 'pattern': return PATTERN[r.v];
      case 'shift': return (r.mode === 'max' ? 'לכל היותר ' : 'לפחות ') + (r.n === 1 ? 'פעם אחת' : r.n + ' פעמים') + ' ב' + SHIFT_NAME[r.shift] + (r.hard ? ' (חובה)' : ' (ככל האפשר)');
      case 'stations': return STATIONS[r.v];
      case 'ahmash': return AHMASH[r.v];
      case 'exclude': return r.v === false ? 'משובצים (למרות כלל החרגה)' : 'לא משובצים לתורנות';
      case 'slots': return (r.mode === 'only' ? 'רק ב: ' : 'לא ב: ') + slotsText(r.slots);
      case 'soft': return 'לשבץ ' + SOFT[r.factor] + ' — חשיבות ' + LEVEL[r.w];
      case 'note': return r.text;
      case 'endFree': return (r.v === false ? 'בסוף יום — גם מי שמלמד/ת בשעה שלפני' : 'בסוף יום — רק מי שאין לו/ה שיעור פרונטלי בשעה שלפני') + ' (' + (r.shifts || ['e1']).map(x => ({ e1: '12:55 — שעה 6', e2: '13:35 — שעה 7' }[x] || x)).join(', ') + ')';
      case 'post': return (r.soft ? 'בהפסקות — עדיפות ל: ' : 'בהפסקות — רק ב: ') + postText(r);
    }
    return '';
  }
  function slotsText(slots) {
    const g = {};
    (slots || []).forEach(k => { const [sh, d] = k.split('@'); (g[sh] = g[sh] || []).push(+d); });
    return Object.keys(g).map(sh => (SHIFT_NAME[sh] || { e1: 'סיום 12:55', e2: 'סיום 13:35' }[sh] || sh) + ' ' + (g[sh].length === 6 ? 'בכל הימים' : 'ביום ' + g[sh].sort().map(d => DAYS[d]).join(', '))).join(' · ');
  }
  const ST_NAME = id => { const st = DEFAULT_CONFIG.stations.find(x => x.id === id); return st ? st.name.split(' (')[0] : id; };
  function postText(r) {
    const parts = (r.stations || []).map(ST_NAME);
    if (r.layers) parts.push('חצרות של שכבה ' + [...r.layers].join('/'));
    let t = parts.join(', ') || '—';
    Object.keys(r.byDay || {}).forEach(d => { t += ' · ביום ' + DAYS[+d] + ': ' + r.byDay[d].map(ST_NAME).join(', '); });
    return t;
  }
  /** עמודה R בשאלון ("עמדה/שכבה מועדפת לשיבוץ בהפסקות") ← עמדות */
  const FLOOR = { 'א': ['flA'], 'ב': ['flB'], 'ג': ['flC'], 'ד': ['flD1', 'flD2'], 'ה': ['flE'], 'ו': ['flF'] };
  function postFromText(txt) {
    let t = String(txt || '').replace(/[׳']/g, '').replace(/\s+/g, ' ').trim();
    if (!t) return null;
    if (/לא לשבץ/.test(t)) return { exclude: true };
    const out = { stations: [], layers: '', byDay: {}, soft: /או אחר/.test(t), flags: [] };
    const add = (...ids) => ids.forEach(x => { if (!out.stations.includes(x)) out.stations.push(x); });
    // "ביום שני במגרש המשולב" — חריג ליום מסוים
    t = t.replace(/,?\s*ביום (ראשון|שני|שלישי|רביעי|חמישי|שישי) (ב[^,/]+)/g, (m, d, place) => {
      const sub = postFromText(place.replace(/^ב/, ''));
      if (sub && sub.stations) out.byDay[DAYS.indexOf(d)] = sub.stations;
      return '';
    });
    if (/אחמ"?ש/.test(t)) add('ahmash');
    if (/(^|\/)\s*חצר\s*(\/|$)/.test(t)) add('office', 'synth', 'grass', 'backUp', 'backLo');
    if (/קומת ד\s*\/\s*מרכז למידה/.test(t)) { add('flD2'); t = t.replace(/קומת ד\s*\/\s*מרכז למידה/, ''); }
    if (/דשא גדול|מגרש דשא(?! סינטטי)/.test(t)) add('grass');
    if (/סינטטי/.test(t)) add('synth');
    if (/משולב|כניסה למנהלה/.test(t)) add('office');
    if (/מדעים/.test(t)) add('flD1');
    if (/מרכז למידה/.test(t)) add('flD2');
    if (/ספסלי בטון/.test(t)) add('concr');
    if (/מגרש עליון/.test(t)) add('backUp');
    if (/תחתון|פינג/.test(t)) add('backLo');
    if (/(^|\s)שער/.test(t)) { add('synth'); out.flags.push('"שער" — בהפסקות שובץ בספסל דשא סינטטי (צופה על רחבת השער)'); }
    (t.match(/קומת (?:שכבה )?([אבגדהו])/g) || []).forEach(m => add(...FLOOR[m.slice(-1)]));
    (t.match(/(?:^|[^ת] )שכבה ([אבגדהו])/g) || []).concat(t.match(/^שכבה ([אבגדהו])/) ? [t.match(/^שכבה ([אבגדהו])/)[0]] : []).forEach(m => { const l = m.slice(-1); add(...FLOOR[l]); if (!out.layers.includes(l)) out.layers += l; });
    (t.match(/החצרות של ([אבגדהו])/g) || []).forEach(m => { const l = m.slice(-1); if (!out.layers.includes(l)) out.layers += l; });
    if (!out.stations.length && !out.layers) return { unknown: true };
    return out;
  }
  /** כללים מעמודה R לכל אנשי הצוות (מחליפים כללים קודמים מהעמודה) */
  function postRules(rules, staff) {
    const keep = (rules || []).filter(r => r.src !== 'sheetR');
    const add = [], unknown = [], flags = [];
    // מי שכבר יש לו כלל עמדות שנערך באתר — לא דורסים
    const own = new Set(keep.filter(r => r.type === 'post' && r.who && r.who.ids && r.who.ids.length === 1).map(r => r.who.ids[0]));
    const none = [];
    staff.forEach(s => {
      if (!s.post && !own.has(s.id)) none.push(s.name);
      if (!s.post || own.has(s.id)) return;
      const x = postFromText(s.post);
      if (!x) return;
      if (x.unknown) { unknown.push(s.name + ': ' + s.post); return; }
      if (x.exclude) { add.push({ id: 'R' + s.id, type: 'exclude', v: true, who: { ids: [s.id] }, on: true, src: 'sheetR', note: 'הנחיית המנהל (עמודה R): ' + s.post }); return; }
      x.flags.forEach(f => flags.push(s.name + ': ' + f));
      add.push({ id: 'R' + s.id, type: 'post', stations: x.stations, layers: x.layers, byDay: x.byDay, soft: x.soft, shifts: ['b1', 'b2'], who: { ids: [s.id] }, on: true, src: 'sheetR', note: 'הנחיית המנהל (עמודה R): ' + s.post });
    });
    // מיקום: אחרי כללי הגיליון והשאלון, לפני כללים שנוספו באתר וחריגים אישיים (שגוברים)
    let at = 0; keep.forEach((r, i) => { if (r.src === 'sheet' || r.src === 'form') at = i + 1; });
    return { rules: keep.slice(0, at).concat(add, keep.slice(at)), added: add.length, unknown, flags, none };
  }
  function describe(r, staff) { return r.type === 'note' ? r.text : whoText(r, staff) + ': ' + whatText(r); }

  /** פרופיל לכל אדם: מה הכללים קובעים לגביו, ואיזה כלל קבע */
  function compile(rules, staff) {
    const P = {};
    staff.forEach(s => {
      const p = { excluded: false, target: 2, pattern: 'free', stations: 'any', ahmash: 'no', min: {}, max: {}, hardMax: {}, only: [], never: [], why: {}, post: {}, endFree: {}, src: {} };
      (rules || []).forEach(r => {
        if (r.on === false || r.type === 'note' || !matches(r, s)) return;
        switch (r.type) {
          case 'quota': p.target = +r.n; p.src.quota = r.id; break;
          case 'pattern': p.pattern = r.v; p.src.pattern = r.id; break;
          case 'stations': p.stations = r.v; p.src.stations = r.id; break;
          case 'ahmash': p.ahmash = r.v; p.src.ahmash = r.id; break;
          case 'exclude': p.excluded = r.v !== false; p.src.exclude = r.id; break;
          case 'endFree': (r.shifts || ['e1']).forEach(sh => { p.endFree[sh] = r.v !== false; }); p.src.endFree = r.id; break;
          case 'shift':
            if (r.mode === 'min') { p.min[r.shift] = +r.n; if (p.max[r.shift] != null && p.max[r.shift] < r.n) p.max[r.shift] = +r.n; }
            else { p.max[r.shift] = +r.n; p.hardMax[r.shift] = !!r.hard; if (p.min[r.shift] > r.n) p.min[r.shift] = +r.n; }
            p.src['shift:' + r.shift] = r.id; break;
          case 'post': (r.shifts || ['b1', 'b2']).forEach(sh => { p.post[sh] = r; }); p.src.post = r.id; break;
          case 'slots': {
            (r.mode === 'only' ? p.only : p.never).push(...(r.slots || []));
            const w = r.who || {}, all = !(w.ids && w.ids.length) && !(w.roles && w.roles.length) && !(w.dcats && w.dcats.length) && !(w.options && w.options.length);
            const why = r.note ? 'כלל: ' + r.note : all ? 'כלל לכל הצוות: ' + whatText(r) : (w.ids && w.ids.length === 1) ? 'הגבלה אישית' + (r.src === 'site' ? ' (נוספה באתר)' : '') : 'כלל: ' + whatText(r);
            if (r.mode === 'only') p.why.only = why; else (r.slots || []).forEach(k => { p.why[k] = why; });
            break; }
        }
      });
      P[s.id] = p;
    });
    const W = { sameStation: 2, layer: 2, calm: 2, endSame: 2, prefDays: 2, near: 3 };
    (rules || []).forEach(r => { if (r.on !== false && r.type === 'soft') W[r.factor] = +r.w; });
    return { P, W };
  }

  /** בדיקת סתירות לפני הוספת כלל חדש */
  function conflicts(rules, nr, staff) {
    if (nr.type === 'note') return [];
    const B = new Set(setOf(nr, staff)), out = [];
    const by = {}; staff.forEach(s => by[s.id] = s.name);
    (rules || []).forEach((r, idx) => {
      if (r.on === false || r.type === 'note' || r.id === nr.id) return;
      let clash = false;
      if (key(r) === key(nr) && sig(r) !== sig(nr)) clash = true;
      if (r.type === 'shift' && nr.type === 'shift' && r.shift === nr.shift && r.mode !== nr.mode) {
        const mn = nr.mode === 'min' ? +nr.n : +r.n, mx = nr.mode === 'max' ? +nr.n : +r.n;
        if (mn > mx) clash = true;
      }
      if (r.type === 'slots' && nr.type === 'slots' && r.mode !== nr.mode) {
        const a = new Set(r.slots || []);
        if ((nr.slots || []).some(x => a.has(x))) clash = true;
      }
      if (!clash) return;
      const A = new Set(setOf(r, staff));
      const inter = [...B].filter(x => A.has(x));
      if (!inter.length) return;
      const rel = inter.length === A.size && inter.length === B.size ? 'equal' : inter.length === B.size ? 'sub' : inter.length === A.size ? 'sup' : 'partial';
      out.push({ rule: r, idx, rel, people: inter.map(id => by[id]), others: A.size - inter.length });
    });
    return out;
  }

  /** החלת ההחלטה מהפופ־אפ. choice: 'replace' | 'keep'
      כלל קיים ספציפי יותר (sup) תמיד נשמר וממשיך לגבור — החדש נכנס לפניו */
  function addRule(rules, nr, staff, choice) {
    const cs = conflicts(rules, nr, staff);
    let list = rules.slice();
    if (choice === 'replace') {
      const ids = new Set(cs.filter(c => c.rel !== 'sup').map(c => c.rule.id));
      list = list.filter(r => !ids.has(r.id));
    }
    const sup = cs.filter(c => c.rel === 'sup').map(c => list.findIndex(r => r.id === c.rule.id)).filter(i => i >= 0);
    if (sup.length) list.splice(Math.min(...sup), 0, nr); else list.push(nr);
    return list;
  }

  /** כלל אישי מתוך טבלת הצוות (מחליף כלל אישי קודם מאותו סוג, בלי פופ־אפ) */
  function setPersonal(rules, staffId, type, values) {
    const list = rules.filter(r => !(r.src === 'personal' && r.type === type && r.who && r.who.ids && r.who.ids.length === 1 && r.who.ids[0] === staffId));
    if (values) list.push(Object.assign({ id: newId(), type, who: { ids: [staffId] }, on: true, src: 'personal' }, values));
    return list;
  }
  let _seq = 0;
  const newId = () => 'r' + Date.now().toString(36) + (_seq++).toString(36);

  /** הכללים מהגיליון "כללים" (נוסח 6.11) + מה שעלה מהערות השאלון */
  function defaultRules(staff) {
    const R = [], ids = names => staff.filter(s => names.some(n => sameName(n, s.name))).map(s => s.id);
    const add = (src, r, note) => R.push(Object.assign({ id: 'd' + (R.length + 1), on: true, src, note: note || '' }, r));
    const S = 'sheet', F = 'form';
    // הנחיות כלליות
    add(S, { type: 'soft', factor: 'sameStation', w: 3, who: {} }, 'עמדות קבועות — שיכיר את הנהלים והתורפות (דגש על השער ופינוי החצרות)');
    add(S, { type: 'soft', factor: 'layer', w: 3, who: {} }, 'איש צוות עם תלמידי כיתתו/שכבתו');
    add(S, { type: 'soft', factor: 'calm', w: 2, who: {} }, 'לשבץ מורה ביום רגוע/פחות עמוס שלו');
    add(S, { type: 'soft', factor: 'near', w: 3, who: {} }, 'בהפסקה — ליד הכיתה שלימד/ה לפניה או ילמד/ה אחריה (לפי מערכת השעות)');
    add(S, { type: 'soft', factor: 'prefDays', w: 2, who: {} });
    add(S, { type: 'soft', factor: 'endSame', w: 2, who: {} }, 'סוף יום — לשבץ את אותו תורן');
    add(S, { type: 'note', text: 'למעט הפטרול — עמדות סטטיות, קבועות ומסומנות', who: {} });
    add(S, { type: 'note', text: 'בשער — מאירי פנים ואחראים / מגדילי ראש', who: {} });
    add(S, { type: 'note', text: 'אפוד זוהר לכל התורנים', who: {} });
    // כמויות ומתכונת
    add(S, { type: 'quota', n: 4, who: { dcats: ['45'] } }, 'בכפוף להעדפה בעמודה J');
    add(S, { type: 'pattern', v: 'day', who: { dcats: ['45'], options: ['A'] } });
    add(S, { type: 'pattern', v: 'spread', who: { dcats: ['45'], options: ['B'] } });
    add(S, { type: 'shift', shift: 'b1', mode: 'max', n: 1, hard: false, who: { roles: ['teacher'], dcats: ['45'] } }, 'ככל האפשר לא פעמיים בהפסקת 10');
    add(S, { type: 'shift', shift: 'b1', mode: 'min', n: 2, hard: false, who: { roles: ['teacher'], dcats: ['45'], options: ['B'] } }, 'מי שבחר אפשרות ב׳ — להעדיף פעמיים בהפסקת 10');
    add(S, { type: 'quota', n: 2, who: { dcats: ['3'] } }, 'יום תורנות');
    add(S, { type: 'pattern', v: 'day', who: { dcats: ['3'] } });
    add(S, { type: 'quota', n: 2, who: { dcats: ['12'] } }, 'שתי הפסקות');
    add(S, { type: 'shift', shift: 'b1', mode: 'min', n: 1, hard: false, who: { dcats: ['12'] } }, 'לפחות אחת מהן הפסקת 10');
    // סייעות
    add(S, { type: 'quota', n: 2, who: { roles: ['aide'] } }, 'עד שתי הפסקות בלבד');
    add(S, { type: 'stations', v: 'ownFloor', who: { roles: ['aide'] } }, 'עמדות רגועות שמצריכות השגחה בלבד, בקומת הכיתה שלהן');
    add(S, { type: 'exclude', v: true, who: { ids: ids(['הודיה בן חמו', 'שירה בן עוליאל', 'יעל אוחנה', 'זוהר יוסיפוב', 'זכריה סלומון']) } }, 'סייעות שלא יכולות לעשות תורנות');
    // הנהלה ואחמ"ש
    add(S, { type: 'exclude', v: true, who: { roles: ['admin'] } }, 'מנהלות/יועצות — להחריג; נשבץ ידנית או אחמ"ש');
    add(S, { type: 'ahmash', v: 'only', who: { ids: ids(['גילה פרטוש', 'אתי ארגי', 'אוריה עובד', 'עומר אידלסברג']) } });
    add(S, { type: 'quota', n: 3, who: { ids: ids(['גילה פרטוש', 'אתי ארגי', 'אוריה עובד', 'עומר אידלסברג']) } }, 'הנחה: 11 משמרות אחמ"ש בשבוע ÷ 4');
    add(S, { type: 'ahmash', v: 'can', who: { ids: ids(['מיטל אבוחצירא', 'ברקת מאור', 'אדיר בוסי']) } }, 'בגיליון עם סימן שאלה');
    // מהשאלון
    add(F, { type: 'exclude', v: true, who: { ids: ids(['מוריה לביא', 'הודיה סלע']) } }, 'בנות שירות');
    const one = (name, r, note) => { const x = ids([name]); if (x.length) add(F, Object.assign(r, { who: { ids: x } }), note); };
    const all = sh => ALLD.map(d => sh + '@' + d);
    one('אלדד בר משה', { type: 'slots', mode: 'only', slots: ['b1@5', ...all('m')] }, 'בהפסקות רק בשישי; בשאר הימים בוקר');
    one('אלדד בר משה', { type: 'shift', shift: 'm', mode: 'min', n: 2, hard: false }, 'בוקר בחמישי ובשישי');
    one('שרה מיארה', { type: 'slots', mode: 'only', slots: ['b2@0'] }, 'הפסקת 12 ביום ראשון בלבד');
    one('שרה מיארה', { type: 'quota', n: 1 });
    one('נעמי לב', { type: 'slots', mode: 'never', slots: ['b1@0', 'b1@3', 'b1@4', 'b1@5'] }, 'הפסקה ראשונה רק בשני ובשלישי');
    one('נפתלי בדלבייב', { type: 'shift', shift: 'b2', mode: 'min', n: 1, hard: false }, 'עדיפות להפסקה שנייה ולבוקר');
    one('נפתלי בדלבייב', { type: 'shift', shift: 'm', mode: 'min', n: 1, hard: false });
    one('רעם טל', { type: 'shift', shift: 'm', mode: 'min', n: 1, hard: false }, 'עדיפות לבוקר, אחר כך הפסקה שנייה');
    one('רעם טל', { type: 'shift', shift: 'b2', mode: 'min', n: 1, hard: false });
    one('ברכי דהאן', { type: 'shift', shift: 'm', mode: 'min', n: 1, hard: false }, 'אשמח לתורנות בוקר');
    one('אוריאן גזלה', { type: 'shift', shift: 'b2', mode: 'min', n: 1, hard: false }, 'מעדיפה הפסקה שנייה');
    one('מוריה אבגי', { type: 'shift', shift: 'end', mode: 'min', n: 1, hard: false }, 'אשמח לתורנות סוף יום');
    one('ג׳ייסון ליפשטיין', { type: 'shift', shift: 'end', mode: 'min', n: 1, hard: false }, 'הפסקות ו/או שער בסוף יום');
    one('שני חדרי', { type: 'stations', v: 'seat' }, 'עמדה עם ישיבה (מגבלת גב)');
    one('מיכל אושרי', { type: 'slots', mode: 'never', slots: [...all('e1'), ...all('e2')] }, 'לא בסוף יום (חוששת לאחר)');
    one('דינה דהן', { type: 'slots', mode: 'never', slots: all('m') }, 'אם אפשר — לא בבוקר');
    one('יעל זרוג', { type: 'slots', mode: 'never', slots: all('m') }, 'מתחילה ב־8:30');
    one('מיכל הסקין', { type: 'slots', mode: 'never', slots: [...all('m'), ...all('e2')] }, 'עובדת 8:30–13:00');
    return R;
  }

  /* ---------- נוכחות לפי מערכת השעות ---------- */
  function afterHour(shift, day) { return day === 5 && shift.fri != null ? shift.fri : shift.after; }
  function presence(s, shift, day, tt, P) {
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
      if (P && P.endFree && P.endFree[shift.id] && lesson(a)) return { ok: false, why: 'מלמד/ת שיעור פרונטלי בשעה ' + a + ' (כלל סוף יום)' };
      return { ok: true };
    }
    return { ok: true };
  }

  /** האם הכללים/השאלון מתירים לאדם את המשמרת הזו */
  function formAllows(s, shift, day, p) {
    const k = shift.id + '@' + day;
    if (!p || p.excluded) return 'לא משובץ/ת (הוחרג/ה)';
    if (p.target <= 0) return 'מכסה 0';
    if (p.only.length && !p.only.includes(k)) return p.why.only || 'הגבלה אישית';
    if (p.never.includes(k)) return p.why[k] || 'הגבלה אישית';
    if (shift.kind === 'morning' && s.noMorning.includes(day)) return 'ביקש/ה לא בבוקר ביום הזה';
    if (shift.kind === 'end' && s.noEnd.includes(day)) return 'ביקש/ה לא בסוף יום ביום הזה';
    return null;
  }

  function stationLayer(cfg, st, shift, day) {
    if (st.layer) return st.layer;
    if (st.yard && cfg.yards[shift.id] && cfg.yards[shift.id][st.yard]) return layerLetters(cfg.yards[shift.id][st.yard][day]);
    return '';
  }
  /** האם העמדה ברשימת העמדות המותרות (עמודה R) */
  function postMatch(P, st, layer, day) {
    const list = P.byDay && P.byDay[day] ? P.byDay[day] : (P.stations || []);
    if (list.includes(st.id)) return true;
    if (P.byDay && P.byDay[day]) return false;
    if (P.layers && !st.ahmash && st.yard && [...layer].some(x => P.layers.includes(x))) return true;
    return false;
  }
  function stationOk(s, p, st, layer, shiftId, day) {
    const P = shiftId && p.post && p.post[shiftId];
    if (P && !P.soft) return postMatch(P, st, layer, day) && (!st.ahmash || p.ahmash !== 'no' || (P.stations || []).includes('ahmash'));
    if (p.ahmash === 'only') return !!st.ahmash;
    if (st.ahmash) return p.ahmash === 'can';
    if (p.stations === 'ownFloor') return !!st.floor && (s.layers.includes('*') || [...layer].some(x => s.layers.includes(x)));
    if (p.stations === 'seat') return !!st.seat;
    if (p.stations === 'noPatrol') return !st.patrol;
    return true;
  }
  const shiftGroup = id => (id === 'e1' || id === 'e2') ? 'end' : id;

  /* ---------- PRNG ---------- */
  function rng(seed) { let a = seed >>> 0; return () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }

  /** בהפסקה: 2 = לימד/ה את השכבה בשעה שלפני, 1 = ילמד/ה אותה בשעה שאחרי, 0 = לא */
  function nearClass(s, shift, day, layer, tt) {
    if (shift.kind !== 'break' || !layer) return 0;
    const t = s.tt && tt[s.tt], c = t && t.c && t.c[day];
    if (!c) return 0;
    const a = afterHour(shift, day), L = [...layer];
    if (L.includes(c[a - 1])) return 2;
    if (L.includes(c[a])) return 1;
    return 0;
  }
  function prepare(cfg, staff, tt, C) {
    const positions = [];
    cfg.shifts.forEach(shift => shift.days.forEach(day => cfg.stations.forEach(st => {
      if (!st.shifts.includes(shift.id)) return;
      if (cfg.skip && cfg.skip[shift.id + '@' + day + '@' + st.id]) return;
      const layer = stationLayer(cfg, st, shift, day);
      const elig = [], calm = {}, near = {};
      staff.forEach((s, i) => {
        const p = C.P[s.id];
        if (formAllows(s, shift, day, p)) return;
        const pr = presence(s, shift, day, tt, C.P[s.id]); if (!pr.ok) return;
        if (!stationOk(s, p, st, layer, shift.id, day)) return;
        elig.push(i); calm[i] = pr.calm !== false;
        near[i] = nearClass(s, shift, day, layer, tt);
      });
      positions.push({ key: shift.id + '@' + day + '@' + st.id, shift, day, st, layer, elig, calm, near });
    })));
    const opts = staff.map(() => 0);
    positions.forEach(p => p.elig.forEach(i => opts[i]++));
    return { positions, opts, targets: staff.map(s => C.P[s.id].excluded ? 0 : C.P[s.id].target), C };
  }

  function scoreOf(s, i, pos, st8, prep, rand) {
    const { shift, day, st, layer } = pos, p = prep.C.P[s.id], W = prep.C.W;
    const tgt = prep.targets[i], used = st8.load[i], g = shiftGroup(shift.id);
    const inG = st8.inShift[i][g] || 0;
    let sc = 0;
    if (p.ahmash === 'can') sc += st.ahmash ? -8 : -1;
    if (st.ahmash && p.ahmash === 'only') sc += 6;
    sc += 2 * (tgt - used) / Math.max(1, tgt);
    sc += 4 / (1 + prep.opts[i]);
    // שכבה
    const L = s.layers || '';
    if (layer && W.layer) {
      let b = 0;
      if (L.includes('*')) b = 0.5; else if ([...layer].includes(L[0])) b = 2; else if ([...layer].some(x => L.includes(x))) b = 1;
      sc += b * W.layer;
    }
    if (st8.stUsed[i][st.id]) sc += 1.5 * W.sameStation;
    // מספר פעמים במשמרת
    if (p.max[g] != null && inG >= p.max[g]) sc -= 14;
    if (p.min[g] != null && inG < p.min[g]) sc += 4;
    // מתכונת
    const du = st8.dayUsed[i], onDay = du[day] || 0;
    const top = Object.keys(du).reduce((m, d) => Math.max(m, du[d]), 0);
    if (p.pattern === 'day') {
      const cl = tgt >= 4 ? tgt - 1 : tgt;                                          // גודל יום התורנות
      if (onDay && onDay === top && top < cl) sc += 5;                              // ממשיכים את יום התורנות
      else if (!onDay && top >= cl) sc += 2;                                        // התורנות הבודדת ביום אחר
      else if (!onDay && top && top < cl) sc -= 3;
    } else if (p.pattern === 'spread') {
      sc += onDay ? -6 : 2;
    } else if (onDay) sc += 1;
    // ימים מועדפים
    const rank = s.pref.indexOf(day);
    if (rank >= 0) sc += [1.25, 0.75, 0.4][rank] * W.prefDays;
    if (shift.kind === 'break' && pos.calm[i]) sc += 0.5 * W.calm;
    if (pos.near && pos.near[i] && W.near) sc += (pos.near[i] === 2 ? 1.5 : 1) * W.near;
    if (shift.kind === 'end' && onDay) sc += 1.5 * W.endSame;
    if (p.stations === 'seat' && st.seat) sc += 2;
    if (p.post && p.post[shift.id] && postMatch(p.post[shift.id], st, layer, day)) sc += p.post[shift.id].soft ? 6 : 2;
    return sc + rand() * 1.5;
  }

  function runOnce(staff, prep, seed) {
    const rand = rng(seed), n = staff.length;
    const st8 = { load: new Array(n).fill(0), at: staff.map(() => ({})), dayUsed: staff.map(() => ({})), stUsed: staff.map(() => ({})), inShift: staff.map(() => ({})) };
    const P = prep.C.P;
    const open = prep.positions.slice(), assign = {}, unfilled = [];
    let total = 0;
    const can = (i, pos) => {
      if (st8.load[i] >= prep.targets[i] || st8.at[i][pos.shift.id + '@' + pos.day]) return false;
      const p = P[staff[i].id], g = shiftGroup(pos.shift.id);
      if (p.hardMax[g] && p.max[g] != null && (st8.inShift[i][g] || 0) >= p.max[g]) return false;
      return true;
    };
    while (open.length) {
      let bi = -1, bc = Infinity;
      const cellOpen = {};
      for (const p of open) { const ck = p.shift.id + '@' + p.day; cellOpen[ck] = (cellOpen[ck] || 0) + 1; }
      for (let k = 0; k < open.length; k++) {
        let c = 0; const p = open[k];
        for (const i of p.elig) if (can(i, p)) c++;
        const w = (p.st.prio || 2) * 1000 + c / cellOpen[p.shift.id + '@' + p.day] + rand() * 0.3;
        if (w < bc) { bc = w; bi = k; }
      }
      const pos = open.splice(bi, 1)[0];
      let best = -1, bs = -Infinity;
      for (const i of pos.elig) {
        if (!can(i, pos)) continue;
        const sc = scoreOf(staff[i], i, pos, st8, prep, rand);
        if (sc > bs) { bs = sc; best = i; }
      }
      if (best < 0) { unfilled.push(pos); continue; }
      assign[pos.key] = best; total += bs;
      const g = shiftGroup(pos.shift.id);
      st8.load[best]++; st8.at[best][pos.shift.id + '@' + pos.day] = 1;
      st8.dayUsed[best][pos.day] = (st8.dayUsed[best][pos.day] || 0) + 1;
      st8.stUsed[best][pos.st.id] = (st8.stUsed[best][pos.st.id] || 0) + 1;
      st8.inShift[best][g] = (st8.inShift[best][g] || 0) + 1;
    }
    return { assign, unfilled, total };
  }

  /** cfg = {shifts, stations, yards, rules}. locked = {posKey: staffId} */
  function solve(cfg, staff, tt, opts) {
    opts = opts || {};
    const iters = opts.iterations || 120, locked = opts.locked || {};
    const C = compile(cfg.rules, staff);
    const idx = {}; staff.forEach((s, i) => idx[s.id] = i);
    const prep = prepare(cfg, staff, tt, C);
    const lockedPos = prep.positions.filter(p => locked[p.key] && idx[locked[p.key]] != null);
    if (lockedPos.length) {
      prep.positions = prep.positions.filter(p => !(locked[p.key] && idx[locked[p.key]] != null));
      lockedPos.forEach(p => { const i = idx[locked[p.key]]; prep.targets[i] = Math.max(0, prep.targets[i] - 1); });
      const busy = {}; lockedPos.forEach(p => busy[idx[locked[p.key]] + '|' + p.shift.id + '@' + p.day] = 1);
      prep.positions.forEach(p => p.elig = p.elig.filter(i => !busy[i + '|' + p.shift.id + '@' + p.day]));
    }
    let best = null;
    for (let k = 0; k < iters; k++) {
      const r = runOnce(staff, prep, (opts.seed || 7) * 1000 + k);
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
    const C = compile(cfg.rules, staff);
    const all = [];
    cfg.shifts.forEach(shift => shift.days.forEach(day => cfg.stations.forEach(st => {
      if (st.shifts.includes(shift.id) && !(cfg.skip && cfg.skip[shift.id + '@' + day + '@' + st.id])) all.push({ key: shift.id + '@' + day + '@' + st.id, shift, day, st, layer: stationLayer(cfg, st, shift, day) });
    })));
    const load = {}; staff.forEach(s => load[s.id] = []);
    Object.keys(assign).forEach(k => { if (load[assign[k]]) load[assign[k]].push(k); });
    const unfilled = all.filter(p => !assign[p.key]);
    const tgt = s => C.P[s.id].excluded ? 0 : C.P[s.id].target;
    const cells = {};
    all.forEach(p => {
      const ck = p.shift.id + '@' + p.day;
      const c = cells[ck] || (cells[ck] = { shift: p.shift, day: p.day, demand: 0, filled: 0, unfilled: [] });
      c.demand++; if (assign[p.key]) c.filled++; else c.unfilled.push(p);
    });
    Object.values(cells).forEach(c => {
      const why = {}; let free = 0, atQuota = 0, possible = 0;
      staff.forEach(s => {
        const p = C.P[s.id]; if (p.excluded) return;
        const f = formAllows(s, c.shift, c.day, p);
        if (f) { why[f] = (why[f] || 0) + 1; return; }
        const pr = presence(s, c.shift, c.day, tt, C.P[s.id]);
        if (!pr.ok) { why[pr.why] = (why[pr.why] || 0) + 1; return; }
        possible++;
        if (load[s.id].some(x => x.startsWith(c.shift.id + '@' + c.day + '@'))) return;
        if (load[s.id].length >= tgt(s)) { atQuota++; return; }
        free++;
      });
      Object.assign(c, { why, atQuota, freeButIneligible: free, possible });
    });
    const people = staff.map(s => {
      const p = C.P[s.id], target = tgt(s), got = load[s.id].length;
      const days = {}; load[s.id].forEach(k => { const d = +k.split('@')[1]; days[d] = (days[d] || 0) + 1; });
      const inShift = {}; load[s.id].forEach(k => { const g = shiftGroup(k.split('@')[0]); inShift[g] = (inShift[g] || 0) + 1; });
      const broken = [];
      if (got) {
        Object.keys(p.max).forEach(g => { if ((inShift[g] || 0) > p.max[g]) broken.push('יותר מ־' + p.max[g] + ' ב' + SHIFT_NAME[g]); });
        Object.keys(p.min).forEach(g => { if ((inShift[g] || 0) < p.min[g]) broken.push('פחות מ־' + p.min[g] + ' ב' + SHIFT_NAME[g]); });
        if (p.pattern === 'day' && got >= 2 && !Object.values(days).some(n => n >= 2)) broken.push('בלי יום תורנות מרוכז');
        if (p.pattern === 'spread' && Object.values(days).some(n => n >= 2)) broken.push('יותר מתורנות אחת ביום');
      }
      return { id: s.id, name: s.name, role: s.role, status: p.excluded ? 'out' : 'in', target, got, slots: load[s.id], broken, flag: s.flag, prof: p };
    });
    const supply = people.reduce((a, p) => a + p.target, 0);
    return {
      assign, unfilled: unfilled.map(p => p.key), cells, people,
      stats: { demand: all.length, filled: all.length - unfilled.length, open: unfilled.length, supply,
        staffIn: people.filter(p => p.status === 'in').length, staffOut: people.filter(p => p.status !== 'in').length }
    };
  }


  /* =================================================================
     תיקון מינימלי, מחליפים זמניים
     ================================================================= */
  /** האם אדם יכול לעמוד בעמדה. מחזיר null אם כן, או סיבה */
  function canStand(cfg, s, p, tt, shiftId, day, stId, opts) {
    const sh = cfg.shifts.find(x => x.id === shiftId), st = cfg.stations.find(x => x.id === stId);
    if (!sh || !st || !sh.days.includes(day)) return 'אין משמרת';
    const pp = opts && opts.ignoreExcluded ? Object.assign({}, p, { excluded: false, target: Math.max(1, p.target) }) : p;
    const f = formAllows(s, sh, day, pp); if (f) return f;
    const pr = presence(s, sh, day, tt, pp); if (!pr.ok) return pr.why;
    if (!stationOk(s, pp, st, stationLayer(cfg, st, sh, day), sh.id, day)) return (pp.post && pp.post[sh.id] && !pp.post[sh.id].soft) ? 'לא בעמדה שהמנהל קבע לו/ה (עמודה R)' : 'לא מתאים/ה לעמדה';
    return null;
  }
  const slotOf = k => { const a = k.split('@'); return a[0] + '@' + a[1]; };
  function loads(assign) { const L = {}; Object.keys(assign).forEach(k => { const id = assign[k]; if (id) L[id] = (L[id] || 0) + 1; }); return L; }
  function busyMap(assign) { const B = {}; Object.keys(assign).forEach(k => { if (assign[k]) B[assign[k] + '|' + slotOf(k)] = k; }); return B; }

  function fitScore(cfg, s, p, key, assign, L, target) {
    const [shId, d, stId] = key.split('@'), sh = cfg.shifts.find(x => x.id === shId), st = cfg.stations.find(x => x.id === stId);
    const layer = stationLayer(cfg, st, sh, +d);
    let sc = 3 * (target - (L[s.id] || 0)) / Math.max(1, target);
    if (layer && s.layers) { if ([...layer].includes(s.layers[0])) sc += 2; else if ([...layer].some(x => s.layers.includes(x))) sc += 1; }
    if (Object.keys(assign).some(k => assign[k] === s.id && k.endsWith('@' + stId))) sc += 1.5;
    if (Object.keys(assign).some(k => assign[k] === s.id && k.split('@')[1] === d)) sc += 1;
    return sc;
  }

  /**
   * תיקון אחרי שינוי מערכת / צוות: משאיר כל שיבוץ שעדיין תקין, ומאייש רק את מה שנשבר.
   * קודם מי שמתחת למכסה; אם אין — החלפה בצעד אחד; אחרת "לא נפתר".
   */
  function repair(cfg, staff, tt, assign, locked) {
    const C = compile(cfg.rules, staff), by = {}; staff.forEach(s => by[s.id] = s);
    const keys = [];
    cfg.shifts.forEach(sh => sh.days.forEach(d => cfg.stations.forEach(st => {
      const k = sh.id + '@' + d + '@' + st.id;
      if (st.shifts.includes(sh.id) && !(cfg.skip && cfg.skip[k])) keys.push(k);
    })));
    const valid = (k, id) => { const s = by[id]; if (!s) return false; const [a, d, b] = k.split('@'); return !canStand(cfg, s, C.P[id], tt, a, +d, b); };
    // שיבוץ ידני (נעול) גובר על כללים והעדפות — נשבר רק אם האדם לא נמצא בבית הספר בזמן הזה או הוחרג
    const lockedOk = (k, id) => { const s = by[id]; if (!s || C.P[id].excluded) return false; const [a, d] = k.split('@'); const sh = cfg.shifts.find(x => x.id === a); return !!sh && presence(s, sh, +d, tt).ok; };
    const A = {}, broken = [], lockBroken = [];
    keys.forEach(k => { const id = assign[k]; if (!id) return; const isL = locked && locked[k] === id;
      if (isL ? lockedOk(k, id) : valid(k, id)) A[k] = id; else { broken.push(k); if (isL) lockBroken.push(k); } });
    const tgt = id => C.P[id].excluded ? 0 : C.P[id].target;
    const changes = [], unresolved = [];
    const todo = broken.slice();
    todo.forEach(k => {
      const L = loads(A), B = busyMap(A), slot = slotOf(k), from = assign[k] || null;
      const free = s => !B[s.id + '|' + slot];
      // 1. מישהו מתחת למכסה
      let best = null, bs = -1e9;
      staff.forEach(s => { if (!free(s) || (L[s.id] || 0) >= tgt(s.id) || !valid(k, s.id)) return; const sc = fitScore(cfg, s, C.P[s.id], k, A, L, tgt(s.id)); if (sc > bs) { bs = sc; best = s; } });
      if (best) { A[k] = best.id; changes.push({ key: k, from, to: best.id, kind: 'replace' }); return; }
      // 2. החלפה בצעד אחד: X (במכסה) עובר לכאן, ו־Z (מתחת למכסה) לוקח את המשבצת של X
      for (const X of staff) {
        if (!free(X) || !valid(k, X.id)) continue;
        const mine = Object.keys(A).filter(k2 => A[k2] === X.id && !(locked && locked[k2]));
        for (const k2 of mine) {
          const s2 = slotOf(k2);
          const Z = staff.find(z => z.id !== X.id && (L[z.id] || 0) < tgt(z.id) && !B[z.id + '|' + s2] && valid(k2, z.id));
          if (Z) { A[k] = X.id; A[k2] = Z.id; changes.push({ key: k, from, to: X.id, kind: 'swap', via: k2 }); changes.push({ key: k2, from: X.id, to: Z.id, kind: 'swap', via: k }); return; }
        }
      }
      unresolved.push(k);
    });
    const people = new Set(); changes.forEach(c => { if (c.from) people.add(c.from); if (c.to) people.add(c.to); });
    return { assign: A, broken, changes, unresolved, lockBroken, people: [...people] };
  }

  /** מועמדים למחליף זמני במשבצת. absent = Set של מזהי נעדרים. extra = שיבוצי מחליפים קיימים {key:id} */
  function subCandidates(cfg, staff, tt, assign, absent, key, extra) {
    const C = compile(cfg.rules, staff), [shId, d, stId] = key.split('@'), slot = shId + '@' + d;
    const all = Object.assign({}, assign); Object.keys(extra || {}).forEach(k => all[k] = extra[k]);
    const eff = {}; Object.keys(all).forEach(k => { const id = all[k]; if (id && !absent.has(id)) eff[k] = id; });
    Object.keys(extra || {}).forEach(k => { eff[k] = extra[k]; });
    const L = loads(eff), B = busyMap(eff);
    return staff.filter(s => !absent.has(s.id)).map(s => {
      const p = C.P[s.id], tgt = p.excluded ? 0 : p.target;
      const why = canStand(cfg, s, p, tt, shId, +d, stId, { ignoreExcluded: !!s.temp }) || (B[s.id + '|' + slot] && B[s.id + '|' + slot] !== key ? 'משובץ/ת באותו זמן' : null);
      return { id: s.id, why, load: L[s.id] || 0, target: tgt, temp: !!s.temp, score: why ? -1e9 : (s.temp ? 8 : 0) + ((L[s.id] || 0) < tgt ? 5 : 0) + fitScore(cfg, s, p, key, eff, L, Math.max(1, tgt)) };
    }).sort((a, b) => b.score - a.score);
  }

  /* ---------- ייבוא מהגיליון (שורות גולמיות) ---------- */
  const DAYMAP = { 'ראשון': 0, 'שני': 1, 'שלישי': 2, 'רביעי': 3, 'חמישי': 4, 'שישי': 5 };
  const daysOf = txt => uniq((String(txt || '').match(/יום (ראשון|שני|שלישי|רביעי|חמישי|שישי)/g) || []).map(x => DAYMAP[x.slice(4)])).join('');
  const layerOf = txt => { const m = String(txt || '').match(/שכבה ([א-ו])/); return m ? m[1] : /לרוחב/.test(txt) ? '*' : ''; };
  function parseSheet(values) {
    const rows = [];
    const hi = values.findIndex(r => r && r.some(c => /שם משפחה/.test(c)));
    // עמודת העמדות בהפסקות (שהמנהל הוסיף) — לפי הכותרת, כדי שלא תזוז אם יתווספו עמודות
    let rc = hi >= 0 ? values[hi].findIndex(c => /עמדה.*מועדפת|שיבוץ בהפסקות/.test(c || '')) : -1; if (rc < 0) rc = 17;
    for (let r = hi + 1; r < values.length; r++) {
      const v = values[r]; if (!v || !v[1]) continue;
      const roleTxt = v[3] || '';
      const role = /תומך|סייע/.test(roleTxt) ? 'A' : /מנהלה|הנהלה/.test(roleTxt) ? 'M' : /אחר/.test(roleTxt) ? 'O' : 'T';
      const dc = /1–2|1-2/.test(v[6]) ? '12' : /^3/.test(v[6]) ? '3' : '45';
      const obstacle = /^לא\. אין מניעה/.test(v[8] || '') ? '' : (v[8] || '');
      const opt = /אפשרות א/.test(v[9]) ? 'A' : /אפשרות ב/.test(v[9]) ? 'B' : 'N';
      const pref = [v[10], v[11], v[12]].map(x => { const m = String(x || '').match(/יום (ראשון|שני|שלישי|רביעי|חמישי|שישי)/); return m ? DAYMAP[m[1]] : ''; }).join('');
      const cant = txt => /יכול\/ה בכל ימי העבודה שלי/.test(txt) && !/לא יכול/.test(txt) ? '' : daysOf(String(txt || '').replace(/יכול\/ה בכל ימי העבודה שלי,?/, ''));
      rows.push([String(v[1]).trim(), String(v[2] || '').trim(), role, layerOf(v[4]), layerOf(v[5]), dc, daysOf(v[7]), obstacle.trim(), opt, pref, cant(v[13]), cant(v[14]), String(v[16] || '').trim(), String(v[rc] || '').trim()]);
    }
    return rows;
  }

  return { DAYS, LAYERS, DEFAULT_CONFIG, ROLE, DCAT, OPT, SHIFT_NAME, PATTERN, STATIONS, AHMASH, SOFT, LEVEL, TYPES,
    buildStaff, defaultRules, compile, conflicts, addRule, setPersonal, newId, describe, whoText, whatText, slotsText, key, matches, setOf,
    parseSheet, postFromText, postRules, postText, layerLetters, solve, report, canStand, repair, subCandidates, sameName, presence, formAllows, stationLayer, stationOk, matchTimetable };
});
