-- יום הורים: כמה תאריכים.
--  * לאירוע יכולים להיות כמה תאריכים (days). הפיצול ברמת כיתה: לכל מחנך (=כיתה) ולכל מורה מקצועי נקבע תאריך משלו.
--    ברירת מחדל: התאריך הראשון. אפשר גם תאריך חלופי שאינו מתאריכי האירוע.
--  * מנהלת בית יכולה לערוך שעות, אורך פגישה ותאריכים למורים של הבית שלה.
alter table public.yh_event add column if not exists days date[];
alter table public.yh_participants add column if not exists days date[];
alter table public.yh_slots add column if not exists day date;
update public.yh_slots x set day = e.day from public.yh_event e where e.id = x.event_id and x.day is null;
alter table public.yh_slots alter column day set not null;
alter table public.yh_slots drop constraint if exists yh_slots_event_id_teacher_id_t_key;
alter table public.yh_slots add constraint yh_slots_event_teacher_day_t_key unique (event_id, teacher_id, day, t);

create or replace function public._yh_edays(e public.yh_event) returns date[]
language sql stable security definer set search_path to '' as $f$
  select coalesce((select array_agg(d order by d) from (select distinct unnest(e.days) d) q where d is not null), array[e.day]) $f$;

create or replace function public._yh_pdays(e public.yh_event, p public.yh_participants) returns date[]
language sql stable security definer set search_path to '' as $f$
  select coalesce(nullif(p.days, '{}'), array[(public._yh_edays(e))[1]]) $f$;

-- מי רשאי לערוך מורה: הנהלה, או מנהלת הבית של הכיתות שלו
create or replace function public._yh_can_edit(s public.hanhala_staff, p_tid int) returns boolean
language sql stable security definer set search_path to '' as $f$
  select public._yh_is_admin(s) or exists (
    select 1 from public.milui_classes c, public.yh_participants p
    where p.event_id = (public._yh_ev()).id and p.teacher_id = p_tid
      and left(c.name, 1) = any(public._yh_house_grades(s)) and (c.homeroom_id = p_tid or c.name = any(p.classes))) $f$;

-- בניית המשבצות של מורה אחד לפי התאריכים, השעות ואורך הפגישה שלו (פגישות שנקבעו לא נמחקות)
create or replace function public._yh_rebuild(e public.yh_event, p_tid int) returns jsonb
language plpgsql security definer set search_path to '' as $f$
declare p public.yh_participants; n_add int; n_del int; len int;
begin
  select * into p from public.yh_participants where event_id = e.id and teacher_id = p_tid;
  if p.teacher_id is null then
    delete from public.yh_slots x where x.event_id = e.id and x.teacher_id = p_tid and not exists (select 1 from public.yh_bookings b where b.slot_id = x.id);
    return jsonb_build_object('added', 0, 'removed', 0);
  end if;
  len := coalesce(p.slot_min, e.slot_min);
  with want as (
    select dd::date as wd, g::time as t from unnest(public._yh_pdays(e, p)) dd,
      generate_series(('2000-01-01 '||coalesce(p.t_start, e.t_start))::timestamp,
                      ('2000-01-01 '||coalesce(p.t_end, e.t_end))::timestamp - make_interval(mins => len),
                      make_interval(mins => len + e.gap_min)) g),
  del as (delete from public.yh_slots x where x.event_id = e.id and x.teacher_id = p_tid
      and not exists (select 1 from want w where w.wd = x.day and w.t = x.t)
      and not exists (select 1 from public.yh_bookings b where b.slot_id = x.id) returning 1),
  ins as (insert into public.yh_slots(event_id, teacher_id, day, t) select e.id, p_tid, w.wd, w.t from want w on conflict do nothing returning 1)
  select (select count(*) from ins), (select count(*) from del) into n_add, n_del;
  return jsonb_build_object('added', n_add, 'removed', n_del);
end $f$;

create or replace function public.yh_admin_build(p_phone text) returns jsonb
language plpgsql security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); e public.yh_event := public._yh_ev(); r jsonb; n_add int := 0; n_del int := 0; tid int;
begin
  if not public._yh_is_admin(s) then raise exception 'forbidden'; end if;
  if e.id is null then raise exception 'no_event'; end if;
  for tid in select teacher_id from public.yh_participants where event_id = e.id
    union select distinct teacher_id from public.yh_slots where event_id = e.id loop
    r := public._yh_rebuild(e, tid); n_add := n_add + (r->>'added')::int; n_del := n_del + (r->>'removed')::int;
  end loop;
  perform public._yh_ensure_tlinks(e.id);
  return jsonb_build_object('added', n_add, 'removed', n_del);
end $function$;

create or replace function public.yh_my_settings(p_phone text, p_start text, p_end text, p_slot int) returns jsonb
language plpgsql security definer set search_path to '' as $f$
declare s public.hanhala_staff := public._hanhala_me(p_phone); e public.yh_event := public._yh_ev(); tid int := public._yh_tid(s);
  ts time := nullif(p_start,'')::time; te time := nullif(p_end,'')::time; sm int := nullif(p_slot, 0);
begin
  if e.id is null then raise exception 'no_event'; end if;
  if tid is null or not exists (select 1 from public.yh_participants where event_id = e.id and teacher_id = tid) then raise exception 'forbidden'; end if;
  if e.reg_open and not public._yh_is_admin(s) then raise exception 'reg_open'; end if;
  if sm is not null and (sm < 5 or sm > 60) then raise exception 'bad_len'; end if;
  if coalesce(ts, e.t_start) >= coalesce(te, e.t_end) then raise exception 'bad_hours'; end if;
  update public.yh_participants set t_start = case when ts = e.t_start then null else ts end, t_end = case when te = e.t_end then null else te end,
    slot_min = case when sm = e.slot_min then null else sm end where event_id = e.id and teacher_id = tid;
  return public._yh_rebuild(e, tid);
end $f$;

-- מנהלת בית / הנהלה: שעות, אורך ותאריכים לרשימת מורים. p_list: [{tid, t_start, t_end, slot_min, days:[...]}]
create or replace function public.yh_house_set(p_phone text, p_list jsonb) returns jsonb
language plpgsql security definer set search_path to '' as $f$
declare s public.hanhala_staff := public._hanhala_me(p_phone); e public.yh_event := public._yh_ev(); j jsonb; tid int; n int := 0;
  ts time; te time; sm int; ds date[];
begin
  if e.id is null then raise exception 'no_event'; end if;
  for j in select * from jsonb_array_elements(coalesce(p_list,'[]')) loop
    tid := (j->>'tid')::int;
    if not public._yh_can_edit(s, tid) then raise exception 'forbidden'; end if;
    ts := nullif(j->>'t_start','')::time; te := nullif(j->>'t_end','')::time; sm := nullif(j->>'slot_min','')::int;
    if sm is not null and (sm < 5 or sm > 60) then raise exception 'bad_len'; end if;
    if coalesce(ts, e.t_start) >= coalesce(te, e.t_end) then raise exception 'bad_hours'; end if;
    ds := case when j ? 'days' and jsonb_typeof(j->'days') = 'array' and jsonb_array_length(j->'days') > 0
               then (select array_agg(distinct (v #>> '{}')::date) from jsonb_array_elements(j->'days') v) end;
    update public.yh_participants set t_start = case when ts = e.t_start then null else ts end, t_end = case when te = e.t_end then null else te end,
      slot_min = case when sm = e.slot_min then null else sm end, days = case when j ? 'days' then ds else days end
      where event_id = e.id and teacher_id = tid;
    perform public._yh_rebuild(e, tid); n := n + 1;
  end loop;
  return jsonb_build_object('n', n);
end $f$;
grant execute on function public.yh_house_set(text, jsonb) to anon, authenticated;

create or replace function public.yh_admin_set_participants(p_phone text, p_list jsonb) returns void
language plpgsql security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); e public.yh_event := public._yh_ev();
begin
  if not public._yh_is_admin(s) then raise exception 'forbidden'; end if;
  if e.id is null then raise exception 'no_event'; end if;
  delete from public.yh_participants p where p.event_id = e.id
    and not exists (select 1 from jsonb_array_elements(p_list) j where (j->>'tid')::int = p.teacher_id)
    and not exists (select 1 from public.yh_slots x join public.yh_bookings b on b.slot_id = x.id where x.event_id = e.id and x.teacher_id = p.teacher_id);
  insert into public.yh_participants(event_id, teacher_id, classes, t_start, t_end, room, slot_min, days)
    select e.id, (j->>'tid')::int, coalesce((select array_agg(v) from jsonb_array_elements_text(j->'classes') v), '{}'),
      nullif(j->>'t_start','')::time, nullif(j->>'t_end','')::time, nullif(j->>'room',''), nullif(j->>'slot_min','')::int,
      case when jsonb_typeof(j->'days') = 'array' and jsonb_array_length(j->'days') > 0 then (select array_agg(distinct (v #>> '{}')::date) from jsonb_array_elements(j->'days') v) end
    from jsonb_array_elements(p_list) j
    on conflict (event_id, teacher_id) do update set classes = excluded.classes, t_start = excluded.t_start, t_end = excluded.t_end, room = excluded.room,
      slot_min = excluded.slot_min, days = excluded.days;
  delete from public.yh_slots x where x.event_id = e.id and not exists (select 1 from public.yh_participants p where p.event_id = e.id and p.teacher_id = x.teacher_id)
    and not exists (select 1 from public.yh_bookings b where b.slot_id = x.id);
end $function$;

create or replace function public._yh_queue2(p_event integer, p_tid integer, p_day date) returns jsonb
language sql stable security definer set search_path to '' as $f$
  select coalesce(jsonb_agg(jsonb_build_object('t', to_char(x.t,'HH24:MI'), 's', b.started_at, 'e', b.ended_at, 'n', b.no_show) order by x.t), '[]'::jsonb)
  from public.yh_slots x join public.yh_bookings b on b.slot_id = x.id where x.event_id = p_event and x.teacher_id = p_tid and x.day = p_day $f$;

-- שמירת האירוע: גם תאריכים (days). day = התאריך הראשון.
create or replace function public.yh_admin_save_event(p_phone text, p_ev jsonb) returns jsonb
language plpgsql security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); e public.yh_event := public._yh_ev(); nid int; ds date[];
begin
  if not public._yh_is_admin(s) then raise exception 'forbidden'; end if;
  ds := case when jsonb_typeof(p_ev->'days') = 'array' and jsonb_array_length(p_ev->'days') > 0
             then (select array_agg(distinct d order by d) from (select nullif(v #>> '{}','')::date d from jsonb_array_elements(p_ev->'days') v) q where d is not null) end;
  if e.id is null or coalesce((p_ev->>'new')::boolean, false) then
    insert into public.yh_event(title, day, days, t_start, t_end, slot_min, gap_min, reg_open, reg_close, note)
      values (coalesce(nullif(p_ev->>'title',''),'יום הורים'), coalesce(ds[1], (p_ev->>'day')::date), ds, coalesce((p_ev->>'t_start')::time,'16:00'), coalesce((p_ev->>'t_end')::time,'20:00'),
        coalesce((p_ev->>'slot_min')::int,10), coalesce((p_ev->>'gap_min')::int,0), coalesce((p_ev->>'reg_open')::boolean,false), nullif(p_ev->>'reg_close','')::date, p_ev->>'note')
      returning id into nid;
    insert into public.yh_participants(event_id, teacher_id, classes)
      select nid, c.homeroom_id, array_agg(c.name order by c.sort) from public.milui_classes c join public.milui_teachers t on t.id = c.homeroom_id and t.active
      where c.homeroom_id is not null group by c.homeroom_id on conflict do nothing;
  else
    update public.yh_event set title = coalesce(nullif(p_ev->>'title',''), title),
      day = coalesce(ds[1], (p_ev->>'day')::date, day), days = case when p_ev ? 'days' then ds else days end,
      t_start = coalesce((p_ev->>'t_start')::time, t_start), t_end = coalesce((p_ev->>'t_end')::time, t_end),
      slot_min = coalesce((p_ev->>'slot_min')::int, slot_min), gap_min = coalesce((p_ev->>'gap_min')::int, gap_min),
      reg_open = coalesce((p_ev->>'reg_open')::boolean, reg_open),
      reg_close = case when p_ev ? 'reg_close' then nullif(p_ev->>'reg_close','')::date else reg_close end,
      note = case when p_ev ? 'note' then p_ev->>'note' else note end
    where id = e.id;
    nid := e.id;
  end if;
  insert into public.yh_class_links(event_id, class_name, token)
    select nid, c.name, public._yh_tok() from public.milui_classes c on conflict do nothing;
  return jsonb_build_object('id', nid);
end $function$;

-- שאר הפונקציות: תוספת היום (d / day) לכל משבצת ופגישה, וחפיפה/תור רק באותו יום
do $$
declare d text;
  procedure_rep text;
begin
  d := pg_get_functiondef('public.yh_class(text)'::regprocedure);
  d := replace(d, '''id'', x.id, ''t'', to_char(x.t,''HH24:MI''),', '''id'', x.id, ''d'', x.day, ''t'', to_char(x.t,''HH24:MI''),');
  d := replace(d, 'order by x.t)', 'order by x.day, x.t)');
  d := replace(d, '''reg_close'', e.reg_close, ''note'', e.note)', '''reg_close'', e.reg_close, ''note'', e.note, ''days'', to_jsonb(public._yh_edays(e)))');
  d := replace(d, 'and e.day >= (now() at time zone ''Asia/Jerusalem'')::date', 'and (select max(q) from unnest(public._yh_edays(e)) q) >= (now() at time zone ''Asia/Jerusalem'')::date');
  if position('''d'', x.day' in d) = 0 or position('''days''' in d) = 0 then raise exception 'yh_class'; end if;
  execute d;

  d := pg_get_functiondef('public.yh_teacher(text)'::regprocedure);
  d := replace(d, '''id'', x.id, ''t'', to_char(x.t,''HH24:MI''),', '''id'', x.id, ''d'', x.day, ''t'', to_char(x.t,''HH24:MI''),');
  d := replace(d, 'order by x.t)', 'order by x.day, x.t)');
  d := replace(d, '''reg_close'', e.reg_close, ''note'', e.note)', '''reg_close'', e.reg_close, ''note'', e.note, ''days'', to_jsonb(public._yh_edays(e)))');
  d := replace(d, 'and e.day >= (now() at time zone ''Asia/Jerusalem'')::date', 'and (select max(q) from unnest(public._yh_edays(e)) q) >= (now() at time zone ''Asia/Jerusalem'')::date');
  d := replace(d, '''homeroom'', false,', '''homeroom'', false, ''days'', to_jsonb(public._yh_pdays(e, p)),');
  if position('''d'', x.day' in d) = 0 or position('_yh_pdays' in d) = 0 then raise exception 'yh_teacher'; end if;
  execute d;

  d := pg_get_functiondef('public.yh_staff_load(text)'::regprocedure);
  d := replace(d, 'jsonb_build_object(''event'', to_jsonb(e))', 'jsonb_build_object(''event'', to_jsonb(e) || jsonb_build_object(''days'', to_jsonb(public._yh_edays(e))))');
  d := replace(d, '''slot_min'', p.slot_min,', '''slot_min'', p.slot_min, ''days'', to_jsonb(public._yh_pdays(e, p)), ''own_days'', p.days,');
  d := replace(d, 'jsonb_build_object(''id'', x.id, ''tid'', x.teacher_id, ''t'', to_char(x.t,''HH24:MI''),', 'jsonb_build_object(''id'', x.id, ''tid'', x.teacher_id, ''d'', x.day, ''t'', to_char(x.t,''HH24:MI''),');
  d := replace(d, 'order by x.teacher_id, x.t)', 'order by x.teacher_id, x.day, x.t)');
  if position('''d'', x.day' in d) = 0 or position('own_days' in d) = 0 or position('_yh_edays' in d) = 0 then raise exception 'yh_staff_load'; end if;
  execute d;

  d := pg_get_functiondef('public._yh_check(yh_event,yh_slots,text,text,text)'::regprocedure);
  d := replace(d, 'where b.event_id = e.id and b.parent_phone = p_phone', 'where b.event_id = e.id and b.parent_phone = p_phone and y.day = x.day');
  if position('y.day = x.day' in d) = 0 then raise exception '_yh_check'; end if;
  execute d;

  d := pg_get_functiondef('public.yh_live(text,integer,text)'::regprocedure);
  d := replace(d, 'where y.id = z.slot_id and y.teacher_id = x.teacher_id', 'where y.id = z.slot_id and y.teacher_id = x.teacher_id and y.day = x.day');
  if position('y.day = x.day' in d) = 0 then raise exception 'yh_live'; end if;
  execute d;

  d := pg_get_functiondef('public.yh_mine(text)'::regprocedure);
  d := replace(d, '''t'', to_char(x.t,''HH24:MI''), ''tid''', '''t'', to_char(x.t,''HH24:MI''), ''day'', x.day, ''tid''');
  d := replace(d, 'public._yh_queue(e.id, x.teacher_id)', 'public._yh_queue2(e.id, x.teacher_id, x.day)');
  d := replace(d, 'order by x.t)', 'order by x.day, x.t)');
  d := replace(d, '''can_cancel'', e.day >=', '''can_cancel'', (select max(q) from unnest(public._yh_edays(e)) q) >=');
  d := replace(d, '''note'', e.note,', '''note'', e.note, ''days'', to_jsonb(public._yh_edays(e)),');
  if position('_yh_queue2' in d) = 0 or position('''day'', x.day' in d) = 0 then raise exception 'yh_mine'; end if;
  execute d;
end $$;
