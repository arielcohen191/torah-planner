-- יום הורים: מורים מקצועיים.
-- מחנך (homeroom של כיתה כלשהי): נקבעים אצלו רק מהקישור הכיתתי של הכיתה שלו.
-- מורה מקצועי בלבד: קישור אישי אחד (?t=), ובקישור הכיתתי של כל כיתה שהוא מלמד הוא מופיע כ"בועה" שמובילה אליו.
create table if not exists public.yh_teacher_links(
  event_id int not null references public.yh_event(id) on delete cascade,
  teacher_id int not null,
  token text not null unique,
  primary key(event_id, teacher_id));
alter table public.yh_teacher_links enable row level security;

create or replace function public._yh_is_hr(p_tid int) returns boolean
language sql stable security definer set search_path to '' as $f$
  select exists (select 1 from public.milui_classes where homeroom_id = p_tid) $f$;

-- קישור לכל משתתף שאינו מחנך
create or replace function public._yh_ensure_tlinks(p_event int) returns void
language sql security definer set search_path to '' as $f$
  insert into public.yh_teacher_links(event_id, teacher_id, token)
  select p.event_id, p.teacher_id, public._yh_tok() from public.yh_participants p
  where p.event_id = p_event and not public._yh_is_hr(p.teacher_id)
  on conflict do nothing $f$;

-- הוספת כל המורים המקצועיים (לא מחנכים) מתוך מערכת השעות, עם הכיתות שהם מלמדים
create or replace function public.yh_admin_add_subject(p_phone text) returns jsonb
language plpgsql security definer set search_path to '' as $f$
declare s public.hanhala_staff := public._hanhala_me(p_phone); e public.yh_event := public._yh_ev(); n int;
begin
  if not public._yh_is_admin(s) then raise exception 'forbidden'; end if;
  if e.id is null then raise exception 'no_event'; end if;
  with t as (
    select x.teacher_id, array_agg(distinct c order by c) cls
    from public.milui_slots x, unnest(x.classes) c
    where x.kind in ('שיעור','שיעור משותף') and c in (select name from public.milui_classes)
    group by x.teacher_id),
  ins as (
    insert into public.yh_participants(event_id, teacher_id, classes)
    select e.id, t.teacher_id, t.cls from t join public.milui_teachers m on m.id = t.teacher_id
    where m.active and not m.is_external and not public._yh_is_hr(t.teacher_id)
    on conflict (event_id, teacher_id) do nothing returning 1)
  select count(*) into n from ins;
  perform public._yh_ensure_tlinks(e.id);
  return jsonb_build_object('added', n);
end $f$;
grant execute on function public.yh_admin_add_subject(text) to anon, authenticated;

-- דף מורה מקצועי (להורים): הכיתות שלו, התלמידים בכל כיתה, והמשבצות שלו
create or replace function public.yh_teacher(p_token text) returns jsonb
language plpgsql stable security definer set search_path to '' as $f$
declare l public.yh_teacher_links; e public.yh_event; p public.yh_participants; t public.milui_teachers;
begin
  select * into l from public.yh_teacher_links where token = p_token;
  if l.token is null then raise exception 'bad_link'; end if;
  select * into e from public.yh_event where id = l.event_id;
  select * into p from public.yh_participants where event_id = e.id and teacher_id = l.teacher_id;
  if p.teacher_id is null then raise exception 'bad_link'; end if;
  select * into t from public.milui_teachers where id = l.teacher_id;
  return jsonb_build_object('event', jsonb_build_object('title', e.title, 'day', e.day, 'slot_min', e.slot_min, 'reg_open', e.reg_open
      and (e.reg_close is null or (now() at time zone 'Asia/Jerusalem')::date <= e.reg_close) and e.day >= (now() at time zone 'Asia/Jerusalem')::date, 'reg_close', e.reg_close, 'note', e.note),
    'teacher', jsonb_build_object('tid', t.id, 'name', t.name, 'gender', t.gender, 'room', p.room, 'homeroom', false,
      'slots', (select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 't', to_char(x.t,'HH24:MI'),
            'free', not x.is_break and not exists (select 1 from public.yh_bookings b where b.slot_id = x.id)) order by x.t), '[]'::jsonb)
          from public.yh_slots x where x.event_id = e.id and x.teacher_id = t.id)),
    'classes', (select coalesce(jsonb_agg(jsonb_build_object('name', c.name,
        'students', (select coalesce(jsonb_agg(jsonb_build_object('n', n,
            'done', (select coalesce(jsonb_agg(y.teacher_id), '[]'::jsonb) from public.yh_bookings b join public.yh_slots y on y.id = b.slot_id
                     where b.event_id = e.id and b.class_name = c.name and b.student = n and y.teacher_id = t.id))), '[]'::jsonb)
          from unnest(public._yh_students(c.name)) n)) order by c.sort), '[]'::jsonb)
      from public.milui_classes c where c.name = any(p.classes)));
end $f$;
grant execute on function public.yh_teacher(text) to anon, authenticated;

-- הקישור הכיתתי: קביעה רק אצל מחנך הכיתה; המורים המקצועיים (לא מחנכים) כ"בועות" עם הקישור שלהם
create or replace function public.yh_class(p_token text) returns jsonb
language plpgsql stable security definer set search_path to '' as $function$
declare l public.yh_class_links; e public.yh_event;
begin
  select * into l from public.yh_class_links where token = p_token;
  if l.token is null then raise exception 'bad_link'; end if;
  select * into e from public.yh_event where id = l.event_id;
  return jsonb_build_object('event', jsonb_build_object('title', e.title, 'day', e.day, 'slot_min', e.slot_min, 'reg_open', e.reg_open
      and (e.reg_close is null or (now() at time zone 'Asia/Jerusalem')::date <= e.reg_close) and e.day >= (now() at time zone 'Asia/Jerusalem')::date, 'reg_close', e.reg_close, 'note', e.note),
    'cls', l.class_name,
    'students', (select coalesce(jsonb_agg(jsonb_build_object('n', n,
        'done', (select coalesce(jsonb_agg(y.teacher_id), '[]'::jsonb) from public.yh_bookings b join public.yh_slots y on y.id = b.slot_id
                 where b.event_id = e.id and b.class_name = l.class_name and b.student = n))), '[]'::jsonb)
      from unnest(public._yh_students(l.class_name)) n),
    'teachers', (select coalesce(jsonb_agg(jsonb_build_object('tid', p.teacher_id, 'name', t.name, 'gender', t.gender, 'room', p.room, 'homeroom', true,
        'slots', (select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 't', to_char(x.t,'HH24:MI'),
            'free', not x.is_break and not exists (select 1 from public.yh_bookings b where b.slot_id = x.id)) order by x.t), '[]'::jsonb)
          from public.yh_slots x where x.event_id = e.id and x.teacher_id = p.teacher_id))), '[]'::jsonb)
      from public.yh_participants p join public.milui_teachers t on t.id = p.teacher_id
      join public.milui_classes c on c.name = l.class_name and c.homeroom_id = p.teacher_id
      where p.event_id = e.id),
    'subject', (select coalesce(jsonb_agg(jsonb_build_object('tid', p.teacher_id, 'name', t.name, 'gender', t.gender, 'token', k.token,
        'free', (select count(*) from public.yh_slots x where x.event_id = e.id and x.teacher_id = p.teacher_id and not x.is_break
                 and not exists (select 1 from public.yh_bookings b where b.slot_id = x.id))) order by t.name), '[]'::jsonb)
      from public.yh_participants p join public.milui_teachers t on t.id = p.teacher_id
      join public.yh_teacher_links k on k.event_id = e.id and k.teacher_id = p.teacher_id
      where p.event_id = e.id and l.class_name = any(p.classes) and not public._yh_is_hr(p.teacher_id)));
end $function$;

-- קביעה: מהקישור הכיתתי (כמו קודם) או מקישור של מורה מקצועי (p_token = הקישור שלו, p_class = הכיתה)
drop function if exists public.yh_book(text, text, text, text, boolean, jsonb, text);
create or replace function public.yh_book(p_token text, p_student text, p_parent text, p_pphone text, p_consent boolean, p_picks jsonb, p_ptoken text default null, p_class text default null)
 returns jsonb language plpgsql security definer set search_path to '' as $function$
declare l public.yh_class_links; tl public.yh_teacher_links; e public.yh_event; x public.yh_slots; err text; tok text; ph text := public.milui_norm(p_pphone);
  sid int; tids int[] := '{}'; cls text;
begin
  select * into l from public.yh_class_links where token = p_token;
  if l.token is not null then
    cls := l.class_name; select * into e from public.yh_event where id = l.event_id;
  else
    select * into tl from public.yh_teacher_links where token = p_token;
    if tl.token is null then raise exception 'bad_link'; end if;
    select * into e from public.yh_event where id = tl.event_id;
    if not exists (select 1 from public.yh_participants p where p.event_id = e.id and p.teacher_id = tl.teacher_id and p_class = any(p.classes)) then raise exception 'wrong_teacher'; end if;
    cls := p_class;
  end if;
  if not e.reg_open or (e.reg_close is not null and (now() at time zone 'Asia/Jerusalem')::date > e.reg_close) then raise exception 'closed'; end if;
  if length(ph) < 9 or ph !~ '^0\d{8,9}$' then raise exception 'bad_phone'; end if;
  if btrim(coalesce(p_parent,'')) = '' then raise exception 'no_parent'; end if;
  if jsonb_array_length(coalesce(p_picks,'[]')) = 0 then raise exception 'no_picks'; end if;
  if p_ptoken is not null and exists (select 1 from public.yh_bookings where ptoken = p_ptoken and parent_phone = ph) then tok := p_ptoken; end if;
  if tok is null then select ptoken into tok from public.yh_bookings where event_id = e.id and parent_phone = ph limit 1; end if;
  tok := coalesce(tok, public._yh_tok());
  for sid in select (v #>> '{}')::int from jsonb_array_elements(p_picks) v loop
    select * into x from public.yh_slots where id = sid for update;
    if tl.token is not null and x.teacher_id is distinct from tl.teacher_id then raise exception 'wrong_teacher'; end if;
    if x.teacher_id = any(tids) then raise exception 'two_same_teacher'; end if;
    tids := tids || x.teacher_id;
    err := public._yh_check(e, x, cls, p_student, ph);
    if err is not null then raise exception '%', err; end if;
    insert into public.yh_bookings(slot_id, event_id, class_name, student, parent_name, parent_phone, consent, ptoken)
      values (x.id, e.id, cls, p_student, btrim(p_parent), ph, coalesce(p_consent,false), tok);
  end loop;
  return jsonb_build_object('ptoken', tok);
end $function$;
grant execute on function public.yh_book(text, text, text, text, boolean, jsonb, text, text) to anon, authenticated;

-- בניית הלוח יוצרת גם קישורים למורים המקצועיים
create or replace function public.yh_admin_build(p_phone text) returns jsonb
language plpgsql security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); e public.yh_event := public._yh_ev(); n_add int; n_del int;
begin
  if not public._yh_is_admin(s) then raise exception 'forbidden'; end if;
  if e.id is null then raise exception 'no_event'; end if;
  with want as (
    select p.teacher_id, g::time t from public.yh_participants p,
      generate_series(('2000-01-01 '||coalesce(p.t_start, e.t_start))::timestamp,
                      ('2000-01-01 '||coalesce(p.t_end, e.t_end))::timestamp - make_interval(mins => e.slot_min),
                      make_interval(mins => e.slot_min + e.gap_min)) g
    where p.event_id = e.id),
  del as (delete from public.yh_slots x where x.event_id = e.id
      and not exists (select 1 from want w where w.teacher_id = x.teacher_id and w.t = x.t)
      and not exists (select 1 from public.yh_bookings b where b.slot_id = x.id) returning 1),
  ins as (insert into public.yh_slots(event_id, teacher_id, t) select e.id, w.teacher_id, w.t from want w on conflict do nothing returning 1)
  select (select count(*) from ins), (select count(*) from del) into n_add, n_del;
  perform public._yh_ensure_tlinks(e.id);
  return jsonb_build_object('added', n_add, 'removed', n_del);
end $function$;


-- yh_staff_load: למשתתפים גם hr (מחנך?) ו־token (הקישור של מורה מקצועי)
create or replace function public.yh_staff_load(p_phone text) returns jsonb
language plpgsql stable security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); adm boolean := public._yh_is_admin(s);
  tid int := public._yh_tid(s); e public.yh_event := public._yh_ev(); hg text[] := public._yh_house_grades(s); out jsonb;
begin
  out := jsonb_build_object('me', s.name, 'admin', adm, 'tid', tid, 'house', to_jsonb(hg), 'now', public._yh_now());
  if e.id is null then return out || jsonb_build_object('event', null); end if;
  out := out || jsonb_build_object('event', to_jsonb(e));
  out := out || jsonb_build_object('participants', coalesce((select jsonb_agg(jsonb_build_object('tid', p.teacher_id, 'name', t.name,
      'classes', p.classes, 't_start', p.t_start, 't_end', p.t_end, 'room', p.room,
      'hr', public._yh_is_hr(p.teacher_id), 'token', (select k.token from public.yh_teacher_links k where k.event_id = e.id and k.teacher_id = p.teacher_id)) order by t.name)
    from public.yh_participants p join public.milui_teachers t on t.id = p.teacher_id where p.event_id = e.id), '[]'::jsonb));
  out := out || jsonb_build_object('classes', coalesce((select jsonb_agg(jsonb_build_object('name', c.name,
      'token', l.token, 'students', public._yh_students(c.name),
      'teachers', coalesce((select jsonb_agg(p.teacher_id) from public.yh_participants p where p.event_id = e.id and c.name = any(p.classes)), '[]'::jsonb),
      'homeroom', c.homeroom_id, 'hr_name', (select t.name from public.milui_teachers t where t.id = c.homeroom_id),
      'booked', (select count(distinct b.student) from public.yh_bookings b where b.event_id = e.id and b.class_name = c.name)) order by c.sort)
    from public.milui_classes c left join public.yh_class_links l on l.event_id = e.id and l.class_name = c.name
    where adm or c.homeroom_id = tid or left(c.name, 1) = any(hg)
      or exists (select 1 from public.yh_participants p where p.event_id = e.id and p.teacher_id = tid and c.name = any(p.classes))), '[]'::jsonb));
  out := out || jsonb_build_object('slots', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'tid', x.teacher_id, 't', to_char(x.t,'HH24:MI'), 'brk', x.is_break,
      'b', case when b.id is null then null else jsonb_build_object('id', b.id, 'cls', b.class_name, 'stu', b.student, 'parent', b.parent_name, 'phone', b.parent_phone,
        'consent', b.consent, 'ptoken', b.ptoken, 'by_staff', b.by_staff, 'started', b.started_at, 'ended', b.ended_at, 'no_show', b.no_show,
        'note', case when adm or x.teacher_id = tid
          or exists (select 1 from public.milui_classes c where c.name = b.class_name and c.homeroom_id = tid) then b.note end) end) order by x.teacher_id, x.t)
    from public.yh_slots x left join public.yh_bookings b on b.slot_id = x.id
    where x.event_id = e.id and (adm or x.teacher_id = tid
      or x.teacher_id in (select p.teacher_id from public.yh_participants p join public.milui_classes c on c.name = any(p.classes) where p.event_id = e.id and (c.homeroom_id = tid or left(c.name, 1) = any(hg))))), '[]'::jsonb));
  if adm then
    out := out || jsonb_build_object('teachers', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'name', name) order by name)
      from public.milui_teachers where active and not is_external), '[]'::jsonb));
  end if;
  return out;
end $function$;
