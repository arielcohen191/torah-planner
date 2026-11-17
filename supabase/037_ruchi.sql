-- 037: רוחי — בוט עזרה + הכרזות (רק לתפקידים שב-ruchi_roles)
create table if not exists public.ruchi_roles(role_id text primary key);
insert into public.ruchi_roles values ('sysadmin'),('principal') on conflict do nothing;
create table if not exists public.ruchi_greet(phone text primary key, greet text not null);
create table if not exists public.ruchi_docs(id text primary key, content text not null, updated_at timestamptz not null default now());
create table if not exists public.ruchi_ann(id bigserial primary key, title text not null, body text not null, link text, link_label text,
  roles text[] not null default array['sysadmin','principal'], active boolean not null default false, created_at timestamptz not null default now());
create table if not exists public.ruchi_seen(phone text not null, ann_id bigint not null references public.ruchi_ann(id) on delete cascade, seen_at timestamptz not null default now(), primary key(phone, ann_id));
create table if not exists public.ruchi_log(id bigserial primary key, phone text not null, tool text, page text, q text, a text, feedback boolean default false, created_at timestamptz not null default now());
alter table public.ruchi_roles enable row level security; alter table public.ruchi_greet enable row level security;
alter table public.ruchi_docs enable row level security; alter table public.ruchi_ann enable row level security;
alter table public.ruchi_seen enable row level security; alter table public.ruchi_log enable row level security;
revoke all on public.ruchi_roles, public.ruchi_greet, public.ruchi_docs, public.ruchi_ann, public.ruchi_seen, public.ruchi_log from anon, authenticated;

insert into public.ruchi_greet(phone, greet)
  select s.phone, 'הרב חגי' from public.hanhala_staff s join public.hanhala_staff_roles r on r.phone = s.phone and r.role_id = 'principal' on conflict do nothing;
insert into public.ruchi_greet(phone, greet) values ('0507482006','אריאל') on conflict do nothing;

insert into public.ruchi_docs(id, content) values ('guide', $g$## כללי · כל הכלים
- הכלים של כנפי רוח: לוח הנהלה, מילוי מקום, תורנויות חצר, סיירות, מפת כיתה, מתכנן הספק, יום הורים. כולם נבנו על ידי אריאל כהן.
- כניסה: בטלפון ובקוד אישי. מי שאין לו קוד מקבל אותו מהמנהל או מאריאל. במפת כיתה יש "שכחתי סיסמה" עם הזדהות בחשבון גוגל.
- כפתור "משוב" (בפינה התחתונה של כל כלי): תקלה, רעיון או שאלה לאריאל. אפשר לצרף צילום מסך, לסמן דחיפות, ולראות "הפניות הקודמות שלי". בפנייה קיימת יש "המשך התכתבות", והיא נפתחת מחדש.
- "בנעליים של": אריאל (מנהל המערכת) יכול לראות כלי בדיוק כמו איש צוות אחר, בצפייה בלבד. בלוח ההנהלה ובמפת כיתה (כפתור "👤 בנעליים של" בתחתית התפריט). יציאה בפס הסגול "חזרה אליי".
- הרשאות ותפקידים נקבעים בלוח ההנהלה › הרשאות. הרב חגי ומנהלות הבתים יכולים לשנות תפקידים לכל הצוות ולהוסיף איש צוות. הסרת איש צוות, הגדרת התפקידים עצמם ותפקיד המנהל: רק מנהל ההרשאות (אריאל/הרב חגי).
- הדפסה: בית הספר מדפיס בשחור־לבן, לכן הסימונים בהדפסה הם ★, מסגרות וסמלים ולא צבעים.

## לוח הנהלה
- מסכים בתפריט: משימות (המסך הראשי), הדף שלי, המשימות שלי, משימות הצוות, תקלות ותחזוקה, מילוי מקום, תורנויות חצר, סיירות, מפת כיתה, החלטות מהישיבות, פגישות עם מחנכים (ימ"מ/ממ"י), מתכנן הספק, הרשאות, משובים (רק לאריאל).
- מסך "משימות": רשימת דברים שדורשים טיפול, מסודרת לפי דחיפות, שנגזרת אוטומטית מכל הכלים (שיעור בלי מחליף, תורנות בלי תורן וכו'). כל אריח מדד לחיץ ומסנן.
- "הדף שלי": מה שנוגע לי היום, כולל התורנויות שלי והחלפות.
- "התאמה אישית" של מסך הבית: אפשר להסתיר כלים ולבחור מה מוצג.
- הרשאות › לשונית "צוות": עריכת תפקידים לאיש צוות (לחיצה על השם), הוספת איש צוות. לשונית "מחנכים": שיוך מחנך לכל כיתה; אם המחנך לא ברשימה, בוחרים "＋ מחנך/ת שלא ברשימה…" וכותבים שם.
- תפקידים חדשים: "מלמד", "סייע/ת" (נוספו 16.11). צריך לשייך אותם לאנשים כדי שיופיעו בשאלונים.

### החלטות מהישיבות
- "＋ הזנת החלטות מהישיבה": בוחרים כיתה ותאריך ישיבה, ואז שורה לכל החלטה: מהות הצורך (לימודי/רגשי/התנהגותי/חברתי/אחר), תלמידים (ריק = החלטה כיתתית), מענה מוצע, גורם אחראי (מחנך/מנהלת/יועצת/אחר — ב"אחר" כותבים שם), מדד הצלחה (איך נדע שהצלחנו), יעד לבקרה. שורה בלי מענה לא נשמרת. "＋ שורה" מוסיף שורה.
- אריחים: באיחור (עבר היעד), פתוחות, הושלמו. לחיצה על אריח מסננת. יש חיפוש וסינון לפי כיתה ולפי גורם אחראי.
- בכל החלטה: "עדכון סטטוס והערות" — סטטוס (טרם טופל/בטיפול/הושלם/בוטל), תאריך יעד, גורם אחראי, מדד הצלחה, הערות מעקב, ו"מחיקת ההחלטה" (עם אישור). מי שיכול לערוך את הכיתה יכול גם למחוק.
- מי רואה: המנהל רואה הכול; מנהלות בתים, יועצות ורכזות רואות לפי השכבות שלהן; מחנך רואה את הכיתה שלו.

### פגישות עם מחנכים (ימ"מ/ממ"י)
- "＋ תיעוד פגישה עם מחנך/ת": תאריך, המחנך (חיפוש לפי שם או כיתה), עם מי התקיימה (מנהלת/יועצת/מחנכ/ת/אחר), מדד אנרגיה 1–4, סימון "עברנו על רשימת התלמידים" (לא חובה), תמצית, והאם דורש התערבות של המנהל.
- אנרגיה 4 או "כן" להתערבות מגיעים למנהל כדגל אדום. המנהל מסמן "ראיתי, אטפל".
- למנהל יש לשונית "תמונת מצב מחנכים": "השקופים" (בלי פגישה 3 שבועות), גרף אנרגיה של 8 שבועות, ורשימת מחנכים לפי הזמן מהפגישה האחרונה.
- מי רואה פגישות: המנהל את כולן; מי שתיעד את שלו; מנהלות בתים/יועצות/סגניות גם את הפגישות עם מחנכי השכבות שלהן.

### משובים (רק לאריאל)
- כל המשובים מכל הכלים. מדרגים דחיפות וגודל, "↩ תשובה לשולח" (מופיעה לשולח בהפניות שלו), "📷 הצגת צילום המסך", וכפתור להפקת "דוח משובים" שאריאל מעביר לקלוד.

## מפת כיתה
- נתונים: מגיעים מגיליון גוגל שכל מחנך ממלא (לשונית לכל כיתה). הכלי מסתנכרן מהגיליון אוטומטית; כפתור "עדכון מהגיליון" מסנכרן מיד. הכלי מזהה עמודות לפי הכותרת שלהן, גם אם הוזזו או שהנוסח בכותרת השתנה, כל עוד תחילת הכותרת זהה (למשל "רמת שילוב").
- תפריט: תמונת הכיתה, מפת תלמידים, כוחות הכיתה, שלמות הנתונים, השאלון שלי, מפת צוות (רק למנהל), ניהול גישה (למנהל).
- רשימת הכיתות בצד: לוחצים על כיתה כדי לעבור אליה.
- מי רואה מה: מחנך — הכיתה שלו במלואה. מורה מקצועי — הכיתות שהוא מלמד, רק העמודות הרלוונטיות. מורה שילוב — בוחר בכניסה הראשונה לכיתה את התלמידים שהוא מלמד ורואה רק אותם; אם לא מלמד בכיתה לוחץ "אני לא מלמד/ת בכיתה הזו". הנהלה — הכול.
- תמונת הכיתה: אריחים (תלמידים, דורשים התערבות, ריבוי מוקדים, שילוב / סל אישי, תקינים וכו'), לחיצה על אריח מסננת. "תובנות": למשל "המדד החלש בכיתה" (סופר רק את הדרגה הנמוכה, למשל ציון מתחת ל־60), "פער: צורך בלי מענה".
- רמת שילוב: 1 ללא זכאות, 2 זכאות מסל השילוב המוסדי, 3 סל אישי/כיתת חנ"מ. "שלמות הנתונים" מציגה תלמידים שרמת השילוב שלהם לא מתאימה לעמודת המענים.
- כרטיס תלמיד: לחיצה על שם. כולל את כל התחומים, "✎ ההערות שלי" (הערה אישית שרק הכותב רואה, נשמרת אוטומטית; ✎ ליד השם ברשימה), ותמונה אם הועלתה.
- הדפסת כרטיסי תלמידים: כרטיס A5 לכל תלמיד, בשחור־לבן (✓ ! ✗).
- קול הצוות / השאלון: כל איש צוות ממלא "השאלון שלי" — חלק על הכיתות (מה מטריד, תלמידים לדיון ⭐) וחלק אישי (תפקידים, עומס, כוח). אין כפתור שליחה: הכול נשמר אוטומטית; בסוף יש "סיימתי". בראש העמוד יש תיבה "עוד לא מילאת את השאלון האישי" עם כפתור.
- תפקידים בשאלון: "התפקידים הרשמיים שלי" מגיעים מלוח ההנהלה (🔒, אי אפשר להסיר; טעות → משוב). מתחת אפשר להוסיף "תפקידים ופרויקטים לא רשמיים".
- מיפוי קריאה: לכיתות שהועלה להן קובץ המיפוי של צוות השפה — פרופיל וציון הבנת הנקרא.
- לוח ההנהלה › מפת כיתה: אריחים "שאלוני צוות" ו"נכנסו לכלי" פותחים רשימה של מי מילא/נכנס.

## מילוי מקום
- מסכים: לוח היום, דיווח על מורה נעדר, היעדרויות פעילות, התחשבנות עם ממלאי מקום, מורים.
- דיווח היעדרות: בוחרים מורה ותאריכים; השיעורים שלו נכנסים ללוח היום כ"בלי מורה".
- לוח היום: לכל שיעור — מועמדים למילוי לפי קבוצות (פנויים, בשהייה, מלמדים באותה שעה = איחוד כיתות, מסייעים בלי מערכת בכלי…). שליחת בקשה למחליף, "אין מחליף?" (איחוד עם כיתה אחרת ועוד).
- איחוד כיתות: כשהממלא מלמד באותה שעה כיתה אחרת, מופיע בלוח "איחוד כיתות: X + Y" ומה הוא מלמד שם.
- מורים: אפשר להוסיף "איש צוות שלא ברשימה" (למשל מורות שילוב) — הוא מופיע בקבוצת "מסייעים" עם הערה לבדוק זמינות, כי אין לו מערכת בכלי.
- המערכת השבועית נטענת מקובץ מערכת השעות; שינוי מערכת צריך טעינה מחדש (אתי/אריאל).

## תורנויות חצר
- מסכים: לוח תורנויות, צוות, כללי שיבוץ, איפה זה נתקע, חלוקת חצרות.
- הלוח: לכל הפסקה ותחנה מי התורן בכל יום. "תצוגה לפי איש צוות" מסמנת את התורנויות של אדם אחד.
- הדפסה: "הדפסה לפרסום" (הלוח הקבוע), "הדפסת מצב היום" (כולל נעדרים ומחליפים), "הדפסה אישית לכל הצוות" (דף לכל איש צוות, התורנויות שלו מסומנות ★). כל הדפסה יוצאת בעמוד A4 אחד לרוחב.
- חלוקת חצרות (איזו שכבה באיזה מגרש): מתעדכנת מהגיליון "חלוקת מגרשים וחצרות" בכפתור עדכון מהגיליון. שמות השורות בגיליון צריכים להישאר: "כניסה למנהלה – צופה על המגרש המשולב", "דשא סינטטי", "פינג פונג", "כדורסל", "מגרש עליון", "דשא גדול". אם שתי שורות מתאימות לאותו מגרש או ששורה חסרה, העדכון לא נשמר ומופיעה הודעה.
- נעדר היום: מופיע בלוח ההנהלה כ"תורנות בלי תורן" עד שמשבצים מחליף.

## סיירות
- שיבוץ נציגי כיתות ו' לעזרות ועבודות בבית הספר: יציאה חדשה, יציאות קבועות, פעילויות קבועות, הוגנות לפי כיתה (כמה פעמים כל כיתה יצאה).

## מתכנן הספק
- תכנון הספק שנתי לפי מקצוע (תורה, נביא, משנה, גמרא ועוד): מורה מתכנן לכיתה שלו, רכז רואה את המקצוע, רכז שכבה רואה את השכבה ותוכניות מקבילות.

## יום הורים
- שיבוץ פגישות הורים, יומן מורה, תור חי והגדרות (בבנייה; פרטים אצל אריאל).
$g$)
  on conflict (id) do update set content = excluded.content, updated_at = now();

-- מי מקבל את רוחי: איש צוות בלוח ההנהלה עם תפקיד שמופיע ב-ruchi_roles
CREATE OR REPLACE FUNCTION public._ruchi_user(p_phone text)
 RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $f$
  select case when s.phone is null then null else jsonb_build_object('phone', s.phone, 'name', s.name,
    'greet', coalesce((select g.greet from public.ruchi_greet g where g.phone = s.phone), split_part(s.name,' ',1)),
    'roles', (select coalesce(jsonb_agg(r.role_id), '[]'::jsonb) from public.hanhala_staff_roles r where r.phone = s.phone)) end
  from (select 1) x left join public.hanhala_staff s on s.phone = public.milui_norm(p_phone)
   and exists (select 1 from public.hanhala_staff_roles r join public.ruchi_roles rr on rr.role_id = r.role_id where r.phone = s.phone)
$f$;

CREATE OR REPLACE FUNCTION public.ruchi_me(p jsonb)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $f$
declare u jsonb := public._ruchi_user(p->>'phone');
begin
  if u is null then return jsonb_build_object('ok', false); end if;
  return jsonb_build_object('ok', true, 'greet', u->>'greet',
    'pending', (select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'title',a.title,'body',a.body,'link',a.link,'link_label',a.link_label) order by a.id), '[]'::jsonb)
      from public.ruchi_ann a where a.active and exists (select 1 from jsonb_array_elements_text(u->'roles') r where r = any(a.roles))
        and not exists (select 1 from public.ruchi_seen x where x.phone = u->>'phone' and x.ann_id = a.id)),
    'news', (select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'title',a.title,'body',a.body,'link',a.link,'link_label',a.link_label,'at',a.created_at) order by a.id desc), '[]'::jsonb)
      from public.ruchi_ann a where a.active and exists (select 1 from jsonb_array_elements_text(u->'roles') r where r = any(a.roles))));
end $f$;

CREATE OR REPLACE FUNCTION public.ruchi_seen_mark(p jsonb)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $f$
declare u jsonb := public._ruchi_user(p->>'phone');
begin
  if u is null then raise exception 'forbidden'; end if;
  insert into public.ruchi_seen(phone, ann_id) values (u->>'phone', (p->>'id')::bigint) on conflict do nothing;
end $f$;
grant execute on function public.ruchi_me(jsonb), public.ruchi_seen_mark(jsonb) to anon, authenticated;

-- ההכרזה הראשונה: רוחי עצמו (תופעל כשהבוט מחובר)
insert into public.ruchi_ann(title, body, link, link_label, active)
  select 'נעים מאוד, אני רוחי! 🪶', 'מעכשיו יש לי כפתור קטן ליד "משוב", בכל אחד מהכלים.
אפשר לשאול אותי איך עושים משהו באתר, ואני אענה מיד.
ואם משהו כבר לא לרוחי, אכין לך משוב מוכן לאריאל.', '#ruchi', 'נסה עכשיו', false
  where not exists (select 1 from public.ruchi_ann where title like 'נעים מאוד, אני רוחי%');
