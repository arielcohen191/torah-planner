-- 016: "הדף שלי" לכל מורה + רמות הרשאה (מנהל / עריכה / צפייה) לכל כלי בתפקיד
-- כל מורה פעיל במערכת השעות (milui_teachers) נכנס ללוח עם הטלפון שלו ורואה רק את הדף האישי שלו.
-- כלים נוספים נפתחים רק דרך תפקיד שמוגדר בהרשאות (ברירת מחדל: בלי גישה).

-- מחנך כיתה
alter table public.milui_classes add column if not exists homeroom_id integer references public.milui_teachers(id) on delete set null;

-- רמת הרשאה לכל כלי בתפקיד: {"milui":"admin","mapat":"edit","hespek":"view"}
alter table public.hanhala_roles add column if not exists levels jsonb not null default '{}'::jsonb;
update public.hanhala_roles r set levels = coalesce((select jsonb_object_agg(t, case when r.id in ('principal','sysadmin') then 'admin' else 'view' end) from unnest(r.tools) t), '{}'::jsonb)
  where r.levels = '{}'::jsonb;

-- התאמת שמות בין הכלים ("אריאל כהן" = "כהן אריאל מרדכי"; "הרב" לא נחשב)
create or replace function public._nm_tokens(t text) returns text[] language sql immutable set search_path to '' as $$
  select coalesce(array_agg(w), '{}') from regexp_split_to_table(btrim(regexp_replace(coalesce(t,''), '[^א-תa-zA-Z ]', '', 'g')), '\s+') w
  where w <> '' and w <> 'הרב' $$;
create or replace function public._nm_match(a text, b text) returns boolean language sql immutable set search_path to '' as $$
  select case when cardinality(x) < 2 or cardinality(y) < 2 then false else x <@ y or y <@ x end
  from (select public._nm_tokens(a) x, public._nm_tokens(b) y) z $$;

-- כניסה: אנשי ההנהלה מהטבלה, ובנוסף כל מורה פעיל לפי הטלפון שבמערכת השעות
create or replace function public._hanhala_me(p_phone text) returns public.hanhala_staff
language plpgsql stable security definer set search_path to '' as $function$
declare s public.hanhala_staff; n text := public.milui_norm(p_phone);
begin
  if n = '' then raise exception 'no_access'; end if;
  select * into s from public.hanhala_staff where phone = n;
  if s.phone is null then
    select n, t.name, false, '{}'::jsonb into s.phone, s.name, s.can_manage, s.prefs
      from public.milui_teachers t where t.active and public.milui_norm(t.phone) = n limit 1;
  end if;
  if s.phone is null then raise exception 'no_access'; end if;
  return s;
end $function$;

create or replace function public._hanhala_payload(s public.hanhala_staff) returns jsonb
language sql stable security definer set search_path to '' as $function$
  select jsonb_build_object('name', s.name,
    'roles', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'label', r.label) order by r.sort)
        from public.hanhala_staff_roles x join public.hanhala_roles r on r.id = x.role_id where x.phone = s.phone), '[]'::jsonb),
    'role_label', coalesce((select string_agg(r.label, ' · ' order by r.sort)
        from public.hanhala_staff_roles x join public.hanhala_roles r on r.id = x.role_id where x.phone = s.phone), ''),
    'tools', coalesce((select jsonb_agg(distinct t) from public.hanhala_staff_roles x join public.hanhala_roles r on r.id = x.role_id,
        unnest(r.tools) t where x.phone = s.phone), '[]'::jsonb),
    'levels', coalesce((select jsonb_object_agg(k, case m when 3 then 'admin' when 2 then 'edit' else 'view' end) from (
        select e.key k, max(case e.value #>> '{}' when 'admin' then 3 when 'edit' then 2 else 1 end) m
        from public.hanhala_staff_roles x join public.hanhala_roles r on r.id = x.role_id, jsonb_each(r.levels) e
        where x.phone = s.phone and e.key = any(r.tools) group by e.key) z), '{}'::jsonb),
    'layers', coalesce((select jsonb_agg(l order by strpos('אבגדהו', l)) from (select distinct l from public.hanhala_staff_roles x
        join public.hanhala_roles r on r.id = x.role_id, unnest(r.layers) l where x.phone = s.phone) z), '[]'::jsonb),
    'staff', exists (select 1 from public.hanhala_staff h where h.phone = s.phone),
    'can_manage', s.can_manage, 'prefs', s.prefs) $function$;

-- הדף האישי: רק נתונים של המורה עצמו
create or replace function public.hanhala_my(p_phone text, p_from date, p_to date) returns jsonb
language plpgsql stable security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); t public.milui_teachers; st public.toranut_state; sid text; out jsonb;
begin
  if p_to < p_from or p_to - p_from > 62 then raise exception 'bad_range'; end if;
  select * into t from public.milui_teachers x where x.active and public.milui_norm(x.phone) = s.phone limit 1;
  if t.id is null then select * into t from public.milui_teachers x where x.active and public._nm_match(x.name, s.name) limit 1; end if;
  out := jsonb_build_object('teacher', case when t.id is null then null else jsonb_build_object('id', t.id, 'name', t.name) end);
  if t.id is not null then
    out := out || jsonb_build_object(
      'slots', (select coalesce(jsonb_agg(jsonb_build_array(x.id, x.day, x.hour, x.kind, x.subject, x.classes, x.detail, x.room) order by x.day, x.hour), '[]'::jsonb)
          from public.milui_slots x where x.teacher_id = t.id),
      'absences', (select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'from', a.date_from, 'to', a.date_to, 'hours', a.hours)), '[]'::jsonb)
          from public.milui_absences a where a.teacher_id = t.id and a.date_from <= p_to and (a.date_to is null or a.date_to >= p_from)),
      'covered', (select coalesce(jsonb_agg(jsonb_build_object('date', x.date, 'slot_id', x.slot_id, 'status', x.status, 'sub', o.name, 'note', x.other_note)), '[]'::jsonb)
          from public.milui_assignments x join public.milui_slots sl on sl.id = x.slot_id left join public.milui_teachers o on o.id = x.substitute_id
          where sl.teacher_id = t.id and x.date between p_from and p_to),
      'covering', (select coalesce(jsonb_agg(jsonb_build_object('date', x.date, 'hour', sl.hour, 'subject', sl.subject, 'classes', sl.classes, 'for', o.name, 'status', x.status) order by x.date, sl.hour), '[]'::jsonb)
          from public.milui_assignments x join public.milui_slots sl on sl.id = x.slot_id join public.milui_teachers o on o.id = sl.teacher_id
          where x.substitute_id = t.id and x.status = 'assigned' and x.date between p_from and p_to),
      'homeroom', (select coalesce(jsonb_agg(jsonb_build_object('class', c.name,
            'slots', (select coalesce(jsonb_agg(jsonb_build_array(x.day, x.hour, x.kind, x.subject, tt.name, x.id) order by x.day, x.hour), '[]'::jsonb)
                from public.milui_slots x join public.milui_teachers tt on tt.id = x.teacher_id where c.name = any(x.classes) and x.kind in ('שיעור','שיעור משותף')),
            'absent', (select coalesce(jsonb_agg(jsonb_build_object('date', x.date, 'slot_id', x.slot_id, 'status', x.status, 'sub', o.name, 'note', x.other_note)), '[]'::jsonb)
                from public.milui_assignments x join public.milui_slots sl on sl.id = x.slot_id left join public.milui_teachers o on o.id = x.substitute_id
                where c.name = any(sl.classes) and x.date between p_from and p_to),
            'tabs', (select coalesce(jsonb_agg(jsonb_build_object('name', ta.name, 'from', a.date_from, 'to', a.date_to, 'hours', a.hours)), '[]'::jsonb)
                from public.milui_absences a join public.milui_teachers ta on ta.id = a.teacher_id
                where a.date_from <= p_to and (a.date_to is null or a.date_to >= p_from)
                  and exists (select 1 from public.milui_slots y where y.teacher_id = ta.id and c.name = any(y.classes))),
            'synced_at', (select d.synced_at from public.mk_class_data d where d.class_name = c.name)) order by c.sort), '[]'::jsonb)
          from public.milui_classes c where c.homeroom_id = t.id));
  end if;
  -- תורנויות: לפי הקישור לשם במערכת השעות (tt), ואם אין, לפי השם
  select * into st from public.toranut_state where id = 1;
  select e->>'id' into sid from jsonb_array_elements(coalesce(st.data->'staff', '[]'::jsonb)) e
    where (t.id is not null and e->>'tt' = t.name) or public._nm_match(e->>'name', s.name) limit 1;
  if sid is not null then
    out := out || jsonb_build_object('duty', jsonb_build_object(
      'keys', (select coalesce(jsonb_agg(a.k), '[]'::jsonb) from jsonb_each_text(coalesce(st.data->'plan'->'assign', '{}'::jsonb)) a(k, v) where a.v = sid),
      'yards', st.data->'yards',
      -- מחליפים שנרשמו במקומי, וההחלפות שאני עושה במקום אחרים (עם תאריכי ההיעדרות)
      'subs', (select coalesce(jsonb_agg(jsonb_build_object('k', b.k, 'mine', b.v->>'id' = sid,
            'who', (select e->>'name' from jsonb_array_elements(st.data->'staff') e where e->>'id' = case when b.v->>'id' = sid then st.data->'plan'->'assign'->>b.k else b.v->>'id' end limit 1),
            'from', coalesce(ma.date_from::text, la->>'from'), 'to', coalesce(ma.date_to::text, la->>'to', case when ma.id is null then null else '9999-12-31' end))), '[]'::jsonb)
          from jsonb_each(coalesce(st.data->'plan'->'subs', '{}'::jsonb)) b(k, v)
          left join public.milui_absences ma on b.v->>'abs' like 'm%' and ma.id::text = substr(b.v->>'abs', 2)
          left join lateral (select e from jsonb_array_elements(coalesce(st.data->'absLocal', '[]'::jsonb)) e where 'l' || (e->>'id') = b.v->>'abs' limit 1) l(la) on true
          where b.v->>'id' = sid or st.data->'plan'->'assign'->>b.k = sid)));
  end if;
  -- תוכניות ההספק של המורה (רק שלו)
  out := out || jsonb_build_object('plans', (select coalesce(jsonb_agg(jsonb_build_object('subject', v->>'subject', 'book', v->>'book', 'grade', v->>'grade', 'cls', v->>'cls',
        'summary', v->'summary', 'start', v->>'startDate', 'end', v->>'endDate', 'updated', v->>'updatedAt') order by v->>'grade', v->>'cls'), '[]'::jsonb)
      from public.plans p, jsonb_each(coalesce(p.data->'plans', '{}'::jsonb)) e(k, v)
      where public._nm_match(coalesce(nullif(v->>'teacher', ''), p.teacher), coalesce(t.name, s.name))));
  return out;
end $function$;

-- ניהול: רמות לכל כלי בתפקיד (בלי גישה / צפייה / עריכה / מנהל)
create or replace function public.hanhala_admin_save_role(p_phone text, p jsonb) returns text
language plpgsql security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_manager(p_phone);
  rid text := nullif(p->>'id',''); lb text := btrim(coalesce(p->>'label',''));
  lv jsonb := coalesce((select jsonb_object_agg(e.key, e.value) from jsonb_each(coalesce(p->'levels','{}'::jsonb)) e where e.value #>> '{}' in ('view','edit','admin')), '{}'::jsonb);
  tl text[];
  ly text[] := array(select l from (select distinct jsonb_array_elements_text(coalesce(p->'layers','[]'::jsonb)) l) z order by strpos('אבגדהו', l));
begin
  if p ? 'tools' and not p ? 'levels' then
    select coalesce(jsonb_object_agg(x, 'view'), '{}'::jsonb) into lv from (select distinct jsonb_array_elements_text(p->'tools') x) z;
  end if;
  tl := array(select k from jsonb_object_keys(lv) k);
  if lb = '' or length(lb) > 40 then raise exception 'bad_label'; end if;
  if not tl <@ array['milui','toranut','sayarot','mapat','hespek'] then raise exception 'bad_tools'; end if;
  if not ly <@ array['א','ב','ג','ד','ה','ו'] then raise exception 'bad_layers'; end if;
  if rid is null then
    rid := 'r' || substr(md5(random()::text || clock_timestamp()::text), 1, 8);
    insert into public.hanhala_roles(id,label,tools,levels,layers,sort)
      values (rid, lb, tl, lv, ly, (select coalesce(max(sort) filter (where sort < 900), 0) + 10 from public.hanhala_roles));
  else
    update public.hanhala_roles set label = lb, tools = tl, levels = lv, layers = ly where id = rid;
    if not found then raise exception 'not_found'; end if;
  end if;
  return rid;
end $function$;

create or replace function public.hanhala_admin_list(p_phone text) returns jsonb
language plpgsql stable security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_manager(p_phone);
begin
  return jsonb_build_object(
    'staff', (select coalesce(jsonb_agg(jsonb_build_object('phone',x.phone,'name',x.name,'can_manage',x.can_manage,'self',x.phone = s.phone,
        'roles', coalesce((select jsonb_agg(sr.role_id order by r.sort) from public.hanhala_staff_roles sr join public.hanhala_roles r on r.id = sr.role_id where sr.phone = x.phone), '[]'::jsonb))
        order by x.name), '[]'::jsonb) from public.hanhala_staff x),
    'roles', (select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'label',r.label,'tools',to_jsonb(r.tools),'levels',r.levels,'layers',to_jsonb(r.layers),
        'holders', coalesce((select jsonb_agg(x.name order by x.name) from public.hanhala_staff_roles sr join public.hanhala_staff x on x.phone = sr.phone where sr.role_id = r.id), '[]'::jsonb))
        order by r.sort), '[]'::jsonb) from public.hanhala_roles r),
    'classes', (select coalesce(jsonb_agg(jsonb_build_object('name', c.name, 'homeroom_id', c.homeroom_id) order by c.sort), '[]'::jsonb) from public.milui_classes c),
    'teachers', (select coalesce(jsonb_agg(jsonb_build_object('id', t.id, 'name', t.name) order by t.name), '[]'::jsonb) from public.milui_teachers t where t.active));
end $function$;

create or replace function public.hanhala_admin_set_homeroom(p_phone text, p_class text, p_teacher integer) returns void
language plpgsql security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_manager(p_phone);
begin
  if p_teacher is not null and not exists (select 1 from public.milui_teachers where id = p_teacher) then raise exception 'not_found'; end if;
  update public.milui_classes set homeroom_id = p_teacher where name = p_class;
  if not found then raise exception 'not_found'; end if;
end $function$;

revoke all on function public._nm_tokens(text), public._nm_match(text,text) from public, anon, authenticated;
grant execute on function public.hanhala_my(text,date,date), public.hanhala_admin_set_homeroom(text,text,integer) to anon, authenticated;

-- מחנכים לפי שמות הלשוניות בקובץ המיפוי (ה'1 לא שובץ: המחנך לא במערכת השעות)
update public.milui_classes c set homeroom_id = m.tid from (values
  ('א'' 1',1),('א'' 2',38),('א'' 3',29),('א'' 4',26),('א'' 5',25),('ב'' 1',42),('ב'' 2',6),('ב'' 3',7),
  ('ג'' 1',3),('ג'' 2',8),('ג'' 3',9),('ג'' 4',11),('ד'' 1',32),('ד'' 2',10),('ד'' 3',5),('ד'' 4',31),('ד'' 5',41),
  ('ה'' 2',17),('ה'' 3',12),('ה'' 4',2),('ו'' 1',30),('ו'' 2',15),('ו'' 3',18),('ו'' 4',39)) m(cn, tid)
where c.name = m.cn and c.homeroom_id is null;

-- (מיגרציה "hanhala_dev_people") מנהל מערכת בלבד: רשימת אנשי הצוות והמורים עם טלפון, למסך "בנעליים של" (צפייה בלבד, נאכף בדפדפן).
