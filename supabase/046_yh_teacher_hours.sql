-- יום הורים: אורך פגישה ושעות לכל מורה.
-- כללי: האירוע (16:00–20:00, 10 דקות). כל משתתף יכול לשנות לעצמו שעות ואורך פגישה — רק לפני פתיחת ההרשמה (ההנהלה תמיד).
alter table public.yh_participants add column if not exists slot_min int check (slot_min is null or slot_min between 5 and 60);

create or replace function public._yh_len(p_event int, p_tid int) returns int
language sql stable security definer set search_path to '' as $f$
  select coalesce((select p.slot_min from public.yh_participants p where p.event_id = p_event and p.teacher_id = p_tid),
                  (select slot_min from public.yh_event where id = p_event)) $f$;

-- המורה משנה לעצמו: שעת התחלה, סיום ואורך פגישה (null = כמו הכללי). בונה מחדש רק את המשבצות שלו.
create or replace function public.yh_my_settings(p_phone text, p_start text, p_end text, p_slot int) returns jsonb
language plpgsql security definer set search_path to '' as $f$
declare s public.hanhala_staff := public._hanhala_me(p_phone); e public.yh_event := public._yh_ev(); tid int := public._yh_tid(s);
  ts time := nullif(p_start,'')::time; te time := nullif(p_end,'')::time; sm int := nullif(p_slot, 0); n_add int; n_del int;
begin
  if e.id is null then raise exception 'no_event'; end if;
  if tid is null or not exists (select 1 from public.yh_participants where event_id = e.id and teacher_id = tid) then raise exception 'forbidden'; end if;
  if e.reg_open and not public._yh_is_admin(s) then raise exception 'reg_open'; end if;
  if sm is not null and (sm < 5 or sm > 60) then raise exception 'bad_len'; end if;
  if coalesce(ts, e.t_start) >= coalesce(te, e.t_end) then raise exception 'bad_hours'; end if;
  update public.yh_participants set t_start = case when ts = e.t_start then null else ts end, t_end = case when te = e.t_end then null else te end,
    slot_min = case when sm = e.slot_min then null else sm end where event_id = e.id and teacher_id = tid;
  with p as (select * from public.yh_participants where event_id = e.id and teacher_id = tid),
  want as (select g::time t from p, generate_series(('2000-01-01 '||coalesce(p.t_start, e.t_start))::timestamp,
              ('2000-01-01 '||coalesce(p.t_end, e.t_end))::timestamp - make_interval(mins => coalesce(p.slot_min, e.slot_min)),
              make_interval(mins => coalesce(p.slot_min, e.slot_min) + e.gap_min)) g),
  del as (delete from public.yh_slots x where x.event_id = e.id and x.teacher_id = tid and not exists (select 1 from want w where w.t = x.t)
      and not exists (select 1 from public.yh_bookings b where b.slot_id = x.id) returning 1),
  ins as (insert into public.yh_slots(event_id, teacher_id, t) select e.id, tid, w.t from want w on conflict do nothing returning 1)
  select (select count(*) from ins), (select count(*) from del) into n_add, n_del;
  return jsonb_build_object('added', n_add, 'removed', n_del);
end $f$;
grant execute on function public.yh_my_settings(text, text, text, int) to anon, authenticated;

create or replace function public._yh_check(e yh_event, x yh_slots, p_class text, p_student text, p_phone text)
 returns text language plpgsql stable security definer set search_path to '' as $function$
declare n int; same boolean;
begin
  if x.id is null or x.event_id <> e.id then return 'no_slot'; end if;
  if x.is_break then return 'taken'; end if;
  if exists (select 1 from public.yh_bookings where slot_id = x.id) then return 'taken'; end if;
  if not exists (select 1 from public.yh_participants p where p.event_id = e.id and p.teacher_id = x.teacher_id and p_class = any(p.classes)) then return 'wrong_teacher'; end if;
  if not (p_student = any(public._yh_students(p_class))) then return 'no_student'; end if;
  select count(*), coalesce(bool_or(p_phone = '' or b.parent_phone = p_phone or coalesce(b.parent_phone,'') = ''), false) into n, same
    from public.yh_bookings b join public.yh_slots y on y.id = b.slot_id
    where b.event_id = e.id and y.teacher_id = x.teacher_id and b.class_name = p_class and b.student = p_student;
  if n >= 2 then return 'already'; end if;
  if n = 1 and same then return 'same_parent'; end if;
  -- חפיפה לפי אורך הפגישה של כל מורה (אצל מורים שונים יכולים להיות אורכים שונים)
  if p_phone <> '' and exists (select 1 from public.yh_bookings b join public.yh_slots y on y.id = b.slot_id
      where b.event_id = e.id and b.parent_phone = p_phone
        and y.t < x.t + make_interval(mins => public._yh_len(e.id, x.teacher_id))
        and x.t < y.t + make_interval(mins => public._yh_len(e.id, y.teacher_id))) then return 'overlap'; end if;
  return null;
end $function$;

create or replace function public.yh_mine(p_ptoken text) returns jsonb
language plpgsql stable security definer set search_path to '' as $function$
declare e public.yh_event;
begin
  select v.* into e from public.yh_event v join public.yh_bookings b on b.event_id = v.id where b.ptoken = p_ptoken limit 1;
  if e.id is null then return jsonb_build_object('items', '[]'::jsonb); end if;
  return jsonb_build_object('event', jsonb_build_object('title', e.title, 'day', e.day, 'slot_min', e.slot_min, 'note', e.note,
      'can_cancel', e.day >= (now() at time zone 'Asia/Jerusalem')::date),
    'now', now(),
    'items', (select coalesce(jsonb_agg(jsonb_build_object('id', b.id, 'cls', b.class_name, 'stu', b.student, 'parent', b.parent_name,
        't', to_char(x.t,'HH24:MI'), 'tid', x.teacher_id, 'teacher', t.name, 'gender', t.gender, 'room', p.room, 'slot_min', coalesce(p.slot_min, e.slot_min),
        'started', b.started_at, 'ended', b.ended_at, 'no_show', b.no_show,
        'queue', public._yh_queue(e.id, x.teacher_id)) order by x.t), '[]'::jsonb)
      from public.yh_bookings b join public.yh_slots x on x.id = b.slot_id join public.milui_teachers t on t.id = x.teacher_id
      left join public.yh_participants p on p.event_id = e.id and p.teacher_id = x.teacher_id
      where b.ptoken = p_ptoken));
end $function$;

create or replace function public.yh_admin_set_participants(p_phone text, p_list jsonb) returns void
language plpgsql security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); e public.yh_event := public._yh_ev();
begin
  if not public._yh_is_admin(s) then raise exception 'forbidden'; end if;
  if e.id is null then raise exception 'no_event'; end if;
  delete from public.yh_participants p where p.event_id = e.id
    and not exists (select 1 from jsonb_array_elements(p_list) j where (j->>'tid')::int = p.teacher_id)
    and not exists (select 1 from public.yh_slots x join public.yh_bookings b on b.slot_id = x.id where x.event_id = e.id and x.teacher_id = p.teacher_id);
  insert into public.yh_participants(event_id, teacher_id, classes, t_start, t_end, room, slot_min)
    select e.id, (j->>'tid')::int, coalesce((select array_agg(v) from jsonb_array_elements_text(j->'classes') v), '{}'),
      nullif(j->>'t_start','')::time, nullif(j->>'t_end','')::time, nullif(j->>'room',''), nullif(j->>'slot_min','')::int
    from jsonb_array_elements(p_list) j
    on conflict (event_id, teacher_id) do update set classes = excluded.classes, t_start = excluded.t_start, t_end = excluded.t_end, room = excluded.room, slot_min = excluded.slot_min;
  delete from public.yh_slots x where x.event_id = e.id and not exists (select 1 from public.yh_participants p where p.event_id = e.id and p.teacher_id = x.teacher_id)
    and not exists (select 1 from public.yh_bookings b where b.slot_id = x.id);
end $function$;

create or replace function public.yh_admin_build(p_phone text) returns jsonb
language plpgsql security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); e public.yh_event := public._yh_ev(); n_add int; n_del int;
begin
  if not public._yh_is_admin(s) then raise exception 'forbidden'; end if;
  if e.id is null then raise exception 'no_event'; end if;
  with want as (
    select p.teacher_id, g::time t from public.yh_participants p,
      generate_series(('2000-01-01 '||coalesce(p.t_start, e.t_start))::timestamp,
                      ('2000-01-01 '||coalesce(p.t_end, e.t_end))::timestamp - make_interval(mins => coalesce(p.slot_min, e.slot_min)),
                      make_interval(mins => coalesce(p.slot_min, e.slot_min) + e.gap_min)) g
    where p.event_id = e.id),
  del as (delete from public.yh_slots x where x.event_id = e.id
      and not exists (select 1 from want w where w.teacher_id = x.teacher_id and w.t = x.t)
      and not exists (select 1 from public.yh_bookings b where b.slot_id = x.id) returning 1),
  ins as (insert into public.yh_slots(event_id, teacher_id, t) select e.id, w.teacher_id, w.t from want w on conflict do nothing returning 1)
  select (select count(*) from ins), (select count(*) from del) into n_add, n_del;
  perform public._yh_ensure_tlinks(e.id);
  return jsonb_build_object('added', n_add, 'removed', n_del);
end $function$;

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
    'teachers', (select coalesce(jsonb_agg(jsonb_build_object('tid', p.teacher_id, 'name', t.name, 'gender', t.gender, 'room', p.room, 'homeroom', true, 'slot_min', coalesce(p.slot_min, e.slot_min),
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
    'teacher', jsonb_build_object('tid', t.id, 'name', t.name, 'gender', t.gender, 'room', p.room, 'homeroom', false, 'slot_min', coalesce(p.slot_min, e.slot_min),
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

create or replace function public.yh_staff_load(p_phone text) returns jsonb
language plpgsql stable security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); adm boolean := public._yh_is_admin(s);
  tid int := public._yh_tid(s); e public.yh_event := public._yh_ev(); hg text[] := public._yh_house_grades(s); out jsonb;
begin
  out := jsonb_build_object('me', s.name, 'admin', adm, 'tid', tid, 'house', to_jsonb(hg), 'now', public._yh_now());
  if e.id is null then return out || jsonb_build_object('event', null); end if;
  out := out || jsonb_build_object('event', to_jsonb(e));
  out := out || jsonb_build_object('participants', coalesce((select jsonb_agg(jsonb_build_object('tid', p.teacher_id, 'name', t.name,
      'classes', p.classes, 't_start', p.t_start, 't_end', p.t_end, 'room', p.room, 'slot_min', p.slot_min,
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
