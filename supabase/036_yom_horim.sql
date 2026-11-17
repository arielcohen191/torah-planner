-- 036: יום הורים (/horim) — שיבוץ פגישות הורים, יומן מורה ותור חי.
-- צוות: כניסה בטלפון כמו בלוח ההנהלה (_hanhala_me). ניהול האירוע: can_manage או תפקיד מנהל/מנהל מערכת.
-- הורים: קישור כיתתי (אסימון לכל כיתה) בלי סיסמה. אחרי שיבוץ ההורה מקבל אסימון אישי, ורק ממנו אפשר לבטל.
-- ההורה רואה רק "פנוי/תפוס" — אף פעם לא שמות של הורים אחרים.

create table if not exists public.yh_event(
  id serial primary key,
  title text not null default 'יום הורים',
  day date not null,
  t_start time not null default '16:00',
  t_end time not null default '20:00',
  slot_min int not null default 10 check (slot_min between 3 and 60),
  gap_min int not null default 0 check (gap_min between 0 and 30),
  reg_open boolean not null default false,
  reg_close date,
  note text,
  created_at timestamptz not null default now());

create table if not exists public.yh_participants(
  event_id int not null references public.yh_event(id) on delete cascade,
  teacher_id int not null references public.milui_teachers(id) on delete cascade,
  classes text[] not null default '{}',
  t_start time, t_end time,
  room text,
  primary key(event_id, teacher_id));

create table if not exists public.yh_class_links(
  event_id int not null references public.yh_event(id) on delete cascade,
  class_name text not null,
  token text not null unique,
  primary key(event_id, class_name));

create table if not exists public.yh_slots(
  id serial primary key,
  event_id int not null references public.yh_event(id) on delete cascade,
  teacher_id int not null references public.milui_teachers(id) on delete cascade,
  t time not null,
  is_break boolean not null default false,
  unique(event_id, teacher_id, t));

create table if not exists public.yh_bookings(
  id serial primary key,
  slot_id int not null unique references public.yh_slots(id) on delete cascade,
  event_id int not null references public.yh_event(id) on delete cascade,
  class_name text not null,
  student text not null,
  parent_name text not null,
  parent_phone text not null,
  consent boolean not null default false,
  ptoken text not null,
  by_staff text,
  created_at timestamptz not null default now(),
  started_at timestamptz, ended_at timestamptz, no_show boolean not null default false);
create index if not exists yh_bookings_ptoken on public.yh_bookings(ptoken);
create index if not exists yh_bookings_phone on public.yh_bookings(event_id, parent_phone);

alter table public.yh_event enable row level security;
alter table public.yh_participants enable row level security;
alter table public.yh_class_links enable row level security;
alter table public.yh_slots enable row level security;
alter table public.yh_bookings enable row level security;
revoke all on public.yh_event, public.yh_participants, public.yh_class_links, public.yh_slots, public.yh_bookings from anon, authenticated;

-- ---------- עזרים ----------
create or replace function public._yh_tok() returns text language sql volatile set search_path to '' as $$
  select replace(gen_random_uuid()::text, '-', '') $$;

create or replace function public._yh_now() returns timestamp language sql stable set search_path to '' as $$
  select (now() at time zone 'Asia/Jerusalem') $$;

-- האירוע הפעיל: האחרון שעוד לא עבר (ואם אין — האחרון)
create or replace function public._yh_ev() returns public.yh_event language sql stable security definer set search_path to '' as $$
  select * from public.yh_event order by (day >= (now() at time zone 'Asia/Jerusalem')::date) desc, day desc, id desc limit 1 $$;

-- שמות התלמידים בכיתה מתוך מפת הכיתה (שני מבני גיליון)
create or replace function public._yh_students(p_class text) returns text[] language sql stable security definer set search_path to '' as $$
  select coalesce(array_agg(n order by ord), '{}') from (
    select btrim(case when r->>1 ~ '^\s*\d+\s*$' and btrim(coalesce(r->>2,'')) <> '' then r->>2
                      when r->>0 ~ '^\s*\d+\s*$' and btrim(coalesce(r->>1,'')) <> '' then r->>1 end) n, o ord
    from public.mk_class_data d, jsonb_array_elements(d.rows) with ordinality x(r, o)
    where d.class_name = p_class) z where n is not null and n <> '' $$;

create or replace function public._yh_is_admin(s public.hanhala_staff) returns boolean language sql stable security definer set search_path to '' as $$
  select coalesce(s.can_manage, false) or exists (select 1 from public.hanhala_staff_roles where phone = s.phone and role_id in ('principal','sysadmin')) $$;

create or replace function public._yh_tid(s public.hanhala_staff) returns int language sql stable security definer set search_path to '' as $$
  select id from public.milui_teachers where active and public.milui_norm(phone) = s.phone order by id limit 1 $$;

-- ---------- צוות ----------
create or replace function public.yh_staff_load(p_phone text) returns jsonb
language plpgsql stable security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); adm boolean := public._yh_is_admin(s);
  tid int := public._yh_tid(s); e public.yh_event := public._yh_ev(); out jsonb;
begin
  out := jsonb_build_object('me', s.name, 'admin', adm, 'tid', tid, 'now', public._yh_now());
  if e.id is null then return out || jsonb_build_object('event', null); end if;
  out := out || jsonb_build_object('event', to_jsonb(e));
  -- המשתתפים (שם, כיתות, טלפון לשליחת תזכורת לא נדרש כאן)
  out := out || jsonb_build_object('participants', coalesce((select jsonb_agg(jsonb_build_object('tid', p.teacher_id, 'name', t.name,
      'classes', p.classes, 't_start', p.t_start, 't_end', p.t_end, 'room', p.room) order by t.name)
    from public.yh_participants p join public.milui_teachers t on t.id = p.teacher_id where p.event_id = e.id), '[]'::jsonb));
  -- הכיתות שאני רואה: מנהל — הכול; מורה — הכיתות שלו באירוע + כיתת החינוך
  out := out || jsonb_build_object('classes', coalesce((select jsonb_agg(jsonb_build_object('name', c.name,
      'token', l.token, 'students', public._yh_students(c.name),
      'teachers', coalesce((select jsonb_agg(p.teacher_id) from public.yh_participants p where p.event_id = e.id and c.name = any(p.classes)), '[]'::jsonb),
      'homeroom', c.homeroom_id) order by c.sort)
    from public.milui_classes c left join public.yh_class_links l on l.event_id = e.id and l.class_name = c.name
    where adm or c.homeroom_id = tid or exists (select 1 from public.yh_participants p where p.event_id = e.id and p.teacher_id = tid and c.name = any(p.classes))), '[]'::jsonb));
  -- משבצות: מנהל — כולן; מורה — שלו
  out := out || jsonb_build_object('slots', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'tid', x.teacher_id, 't', to_char(x.t,'HH24:MI'), 'brk', x.is_break,
      'b', case when b.id is null then null else jsonb_build_object('id', b.id, 'cls', b.class_name, 'stu', b.student, 'parent', b.parent_name, 'phone', b.parent_phone,
        'consent', b.consent, 'ptoken', b.ptoken, 'by_staff', b.by_staff, 'started', b.started_at, 'ended', b.ended_at, 'no_show', b.no_show) end) order by x.teacher_id, x.t)
    from public.yh_slots x left join public.yh_bookings b on b.slot_id = x.id
    where x.event_id = e.id and (adm or x.teacher_id = tid
      or x.teacher_id in (select p.teacher_id from public.yh_participants p join public.milui_classes c on c.name = any(p.classes) where p.event_id = e.id and c.homeroom_id = tid))), '[]'::jsonb));
  -- למנהל: רשימת כל אנשי הצוות להוספה
  if adm then
    out := out || jsonb_build_object('teachers', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'name', name) order by name)
      from public.milui_teachers where active and not is_external), '[]'::jsonb));
  end if;
  return out;
end $function$;

-- יצירה/עדכון של האירוע
create or replace function public.yh_admin_save_event(p_phone text, p_ev jsonb) returns jsonb
language plpgsql security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); e public.yh_event := public._yh_ev(); nid int;
begin
  if not public._yh_is_admin(s) then raise exception 'forbidden'; end if;
  if e.id is null or coalesce((p_ev->>'new')::boolean, false) then
    insert into public.yh_event(title, day, t_start, t_end, slot_min, gap_min, reg_open, reg_close, note)
      values (coalesce(nullif(p_ev->>'title',''),'יום הורים'), (p_ev->>'day')::date, coalesce((p_ev->>'t_start')::time,'16:00'), coalesce((p_ev->>'t_end')::time,'20:00'),
        coalesce((p_ev->>'slot_min')::int,10), coalesce((p_ev->>'gap_min')::int,0), coalesce((p_ev->>'reg_open')::boolean,false), nullif(p_ev->>'reg_close','')::date, p_ev->>'note')
      returning id into nid;
    -- ברירת מחדל: מחנכי הכיתות, כל אחד עם הכיתה שלו
    insert into public.yh_participants(event_id, teacher_id, classes)
      select nid, c.homeroom_id, array_agg(c.name order by c.sort) from public.milui_classes c join public.milui_teachers t on t.id = c.homeroom_id and t.active
      where c.homeroom_id is not null group by c.homeroom_id on conflict do nothing;
  else
    update public.yh_event set title = coalesce(nullif(p_ev->>'title',''), title), day = coalesce((p_ev->>'day')::date, day),
      t_start = coalesce((p_ev->>'t_start')::time, t_start), t_end = coalesce((p_ev->>'t_end')::time, t_end),
      slot_min = coalesce((p_ev->>'slot_min')::int, slot_min), gap_min = coalesce((p_ev->>'gap_min')::int, gap_min),
      reg_open = coalesce((p_ev->>'reg_open')::boolean, reg_open),
      reg_close = case when p_ev ? 'reg_close' then nullif(p_ev->>'reg_close','')::date else reg_close end,
      note = case when p_ev ? 'note' then p_ev->>'note' else note end
    where id = e.id;
    nid := e.id;
  end if;
  -- קישור כיתתי לכל כיתה
  insert into public.yh_class_links(event_id, class_name, token)
    select nid, c.name, public._yh_tok() from public.milui_classes c on conflict do nothing;
  return jsonb_build_object('id', nid);
end $function$;

-- רשימת המשתתפים: [{tid, classes:[..], t_start, t_end, room}] — מחליפה את הקיימת. משבצות תפוסות לא נמחקות.
create or replace function public.yh_admin_set_participants(p_phone text, p_list jsonb) returns void
language plpgsql security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); e public.yh_event := public._yh_ev();
begin
  if not public._yh_is_admin(s) then raise exception 'forbidden'; end if;
  if e.id is null then raise exception 'no_event'; end if;
  delete from public.yh_participants p where p.event_id = e.id
    and not exists (select 1 from jsonb_array_elements(p_list) j where (j->>'tid')::int = p.teacher_id)
    and not exists (select 1 from public.yh_slots x join public.yh_bookings b on b.slot_id = x.id where x.event_id = e.id and x.teacher_id = p.teacher_id);
  insert into public.yh_participants(event_id, teacher_id, classes, t_start, t_end, room)
    select e.id, (j->>'tid')::int, coalesce((select array_agg(v) from jsonb_array_elements_text(j->'classes') v), '{}'),
      nullif(j->>'t_start','')::time, nullif(j->>'t_end','')::time, nullif(j->>'room','')
    from jsonb_array_elements(p_list) j
    on conflict (event_id, teacher_id) do update set classes = excluded.classes, t_start = excluded.t_start, t_end = excluded.t_end, room = excluded.room;
  delete from public.yh_slots x where x.event_id = e.id and not exists (select 1 from public.yh_participants p where p.event_id = e.id and p.teacher_id = x.teacher_id)
    and not exists (select 1 from public.yh_bookings b where b.slot_id = x.id);
end $function$;

-- בניית הלוח: יוצרת משבצות לכל משתתף לפי השעות, ומוחקת משבצות פנויות שמחוץ לטווח. משבצת תפוסה אף פעם לא נמחקת.
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
  return jsonb_build_object('added', n_add, 'removed', n_del);
end $function$;

-- מורה (או מנהל): הפסקה / פנוי
create or replace function public.yh_slot_break(p_phone text, p_slot int, p_break boolean) returns void
language plpgsql security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); x public.yh_slots;
begin
  select * into x from public.yh_slots where id = p_slot;
  if x.id is null then raise exception 'no_slot'; end if;
  if x.teacher_id is distinct from public._yh_tid(s) and not public._yh_is_admin(s) then raise exception 'forbidden'; end if;
  if p_break and exists (select 1 from public.yh_bookings where slot_id = p_slot) then raise exception 'taken'; end if;
  update public.yh_slots set is_break = p_break where id = p_slot;
end $function$;

-- בדיקות שיבוץ משותפות להורה ולצוות
create or replace function public._yh_check(e public.yh_event, x public.yh_slots, p_class text, p_student text, p_phone text) returns text
language plpgsql stable security definer set search_path to '' as $function$
begin
  if x.id is null or x.event_id <> e.id then return 'no_slot'; end if;
  if x.is_break then return 'taken'; end if;
  if exists (select 1 from public.yh_bookings where slot_id = x.id) then return 'taken'; end if;
  if not exists (select 1 from public.yh_participants p where p.event_id = e.id and p.teacher_id = x.teacher_id and p_class = any(p.classes)) then return 'wrong_teacher'; end if;
  if not (p_student = any(public._yh_students(p_class))) then return 'no_student'; end if;
  if exists (select 1 from public.yh_bookings b join public.yh_slots y on y.id = b.slot_id
      where b.event_id = e.id and y.teacher_id = x.teacher_id and b.class_name = p_class and b.student = p_student) then return 'already'; end if;
  -- אותו הורה (טלפון) לא יכול להיות בשני מקומות באותו זמן (אחים)
  if p_phone <> '' and exists (select 1 from public.yh_bookings b join public.yh_slots y on y.id = b.slot_id
      where b.event_id = e.id and b.parent_phone = p_phone and abs(extract(epoch from (y.t - x.t))) < e.slot_min * 60) then return 'overlap'; end if;
  return null;
end $function$;

-- מורה/מחנך/מנהל משבץ ידנית הורה שלא נרשם
create or replace function public.yh_staff_book(p_phone text, p_slot int, p_class text, p_student text, p_parent text, p_pphone text) returns jsonb
language plpgsql security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); e public.yh_event := public._yh_ev(); x public.yh_slots; tid int := public._yh_tid(s);
  err text; tok text; ph text := public.milui_norm(p_pphone);
begin
  select * into x from public.yh_slots where id = p_slot;
  if not public._yh_is_admin(s) and x.teacher_id is distinct from tid
     and not exists (select 1 from public.milui_classes c where c.name = p_class and c.homeroom_id = tid) then raise exception 'forbidden'; end if;
  err := public._yh_check(e, x, p_class, p_student, ph);
  if err is not null then raise exception '%', err; end if;
  -- אותו הורה כבר קיבל אסימון? נשתמש בו כדי שכל הפגישות שלו יופיעו בקישור אחד
  select ptoken into tok from public.yh_bookings where event_id = e.id and ph <> '' and parent_phone = ph limit 1;
  tok := coalesce(tok, public._yh_tok());
  insert into public.yh_bookings(slot_id, event_id, class_name, student, parent_name, parent_phone, consent, ptoken, by_staff)
    values (x.id, e.id, p_class, p_student, coalesce(nullif(btrim(p_parent),''), 'הורה'), ph, false, tok, s.name);
  return jsonb_build_object('ptoken', tok);
end $function$;

create or replace function public.yh_staff_cancel(p_phone text, p_booking int) returns void
language plpgsql security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); b public.yh_bookings; x public.yh_slots; tid int := public._yh_tid(s);
begin
  select * into b from public.yh_bookings where id = p_booking; if b.id is null then return; end if;
  select * into x from public.yh_slots where id = b.slot_id;
  if not public._yh_is_admin(s) and x.teacher_id is distinct from tid
     and not exists (select 1 from public.milui_classes c where c.name = b.class_name and c.homeroom_id = tid) then raise exception 'forbidden'; end if;
  delete from public.yh_bookings where id = p_booking;
end $function$;

-- הזזה למשבצת אחרת של אותו מורה
create or replace function public.yh_staff_move(p_phone text, p_booking int, p_slot int) returns void
language plpgsql security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); b public.yh_bookings; x public.yh_slots; y public.yh_slots; tid int := public._yh_tid(s);
begin
  select * into b from public.yh_bookings where id = p_booking; if b.id is null then raise exception 'no_booking'; end if;
  select * into x from public.yh_slots where id = b.slot_id;
  select * into y from public.yh_slots where id = p_slot;
  if y.id is null or y.teacher_id <> x.teacher_id then raise exception 'no_slot'; end if;
  if y.is_break or exists (select 1 from public.yh_bookings where slot_id = y.id) then raise exception 'taken'; end if;
  if not public._yh_is_admin(s) and x.teacher_id is distinct from tid
     and not exists (select 1 from public.milui_classes c where c.name = b.class_name and c.homeroom_id = tid) then raise exception 'forbidden'; end if;
  update public.yh_bookings set slot_id = y.id where id = b.id;
end $function$;

-- היום עצמו: התחלתי / סיימתי / לא הגיע / איפוס
create or replace function public.yh_live(p_phone text, p_booking int, p_action text) returns void
language plpgsql security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); b public.yh_bookings; x public.yh_slots;
begin
  select * into b from public.yh_bookings where id = p_booking; if b.id is null then raise exception 'no_booking'; end if;
  select * into x from public.yh_slots where id = b.slot_id;
  if x.teacher_id is distinct from public._yh_tid(s) and not public._yh_is_admin(s) then raise exception 'forbidden'; end if;
  if p_action = 'start' then
    -- פגישה קודמת שעדיין פתוחה נסגרת אוטומטית
    update public.yh_bookings z set ended_at = now() from public.yh_slots y
      where y.id = z.slot_id and y.teacher_id = x.teacher_id and z.event_id = b.event_id and z.started_at is not null and z.ended_at is null and z.id <> b.id;
    update public.yh_bookings set started_at = now(), ended_at = null, no_show = false where id = b.id;
  elsif p_action = 'end' then update public.yh_bookings set ended_at = now(), started_at = coalesce(started_at, now()) where id = b.id;
  elsif p_action = 'noshow' then update public.yh_bookings set no_show = true, started_at = null, ended_at = null where id = b.id;
  elsif p_action = 'reset' then update public.yh_bookings set no_show = false, started_at = null, ended_at = null where id = b.id;
  else raise exception 'bad_action'; end if;
end $function$;

-- ---------- הורים ----------
-- התור של מורה (בלי שמות): לכל משבצת תפוסה — שעה, התחיל, הסתיים, לא הגיע
create or replace function public._yh_queue(p_event int, p_tid int) returns jsonb language sql stable security definer set search_path to '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('t', to_char(x.t,'HH24:MI'), 's', b.started_at, 'e', b.ended_at, 'n', b.no_show) order by x.t), '[]'::jsonb)
  from public.yh_slots x join public.yh_bookings b on b.slot_id = x.id where x.event_id = p_event and x.teacher_id = p_tid $$;

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
    'teachers', (select coalesce(jsonb_agg(jsonb_build_object('tid', p.teacher_id, 'name', t.name, 'gender', t.gender, 'room', p.room,
        'homeroom', exists (select 1 from public.milui_classes c where c.name = l.class_name and c.homeroom_id = p.teacher_id),
        'slots', (select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 't', to_char(x.t,'HH24:MI'),
            'free', not x.is_break and not exists (select 1 from public.yh_bookings b where b.slot_id = x.id)) order by x.t), '[]'::jsonb)
          from public.yh_slots x where x.event_id = e.id and x.teacher_id = p.teacher_id))
        order by (exists (select 1 from public.milui_classes c where c.name = l.class_name and c.homeroom_id = p.teacher_id)) desc, t.name), '[]'::jsonb)
      from public.yh_participants p join public.milui_teachers t on t.id = p.teacher_id where p.event_id = e.id and l.class_name = any(p.classes)));
end $function$;

-- שיבוץ מההורה: p_picks = [slot_id, ...] (משבצת אחת לכל מורה). הכול או כלום.
create or replace function public.yh_book(p_token text, p_student text, p_parent text, p_pphone text, p_consent boolean, p_picks jsonb, p_ptoken text default null) returns jsonb
language plpgsql security definer set search_path to '' as $function$
declare l public.yh_class_links; e public.yh_event; x public.yh_slots; err text; tok text; ph text := public.milui_norm(p_pphone); sid int; tids int[] := '{}';
begin
  select * into l from public.yh_class_links where token = p_token;
  if l.token is null then raise exception 'bad_link'; end if;
  select * into e from public.yh_event where id = l.event_id;
  if not e.reg_open or (e.reg_close is not null and (now() at time zone 'Asia/Jerusalem')::date > e.reg_close) then raise exception 'closed'; end if;
  if length(ph) < 9 or ph !~ '^0\d{8,9}$' then raise exception 'bad_phone'; end if;
  if btrim(coalesce(p_parent,'')) = '' then raise exception 'no_parent'; end if;
  if jsonb_array_length(coalesce(p_picks,'[]')) = 0 then raise exception 'no_picks'; end if;
  -- אסימון קיים של אותו הורה (אחים) — רק אם הוא באמת שייך לאותו טלפון
  if p_ptoken is not null and exists (select 1 from public.yh_bookings where ptoken = p_ptoken and parent_phone = ph) then tok := p_ptoken; end if;
  if tok is null then select ptoken into tok from public.yh_bookings where event_id = e.id and parent_phone = ph limit 1; end if;
  tok := coalesce(tok, public._yh_tok());
  for sid in select (v #>> '{}')::int from jsonb_array_elements(p_picks) v loop
    select * into x from public.yh_slots where id = sid for update;
    if x.teacher_id = any(tids) then raise exception 'two_same_teacher'; end if;
    tids := tids || x.teacher_id;
    err := public._yh_check(e, x, l.class_name, p_student, ph);
    if err is not null then raise exception '%', err; end if;
    insert into public.yh_bookings(slot_id, event_id, class_name, student, parent_name, parent_phone, consent, ptoken)
      values (x.id, e.id, l.class_name, p_student, btrim(p_parent), ph, coalesce(p_consent,false), tok);
  end loop;
  return jsonb_build_object('ptoken', tok);
end $function$;

-- הדף האישי של ההורה: הפגישות שלו + התור החי של כל מורה (בלי שמות)
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
        't', to_char(x.t,'HH24:MI'), 'tid', x.teacher_id, 'teacher', t.name, 'gender', t.gender, 'room', p.room,
        'started', b.started_at, 'ended', b.ended_at, 'no_show', b.no_show,
        'queue', public._yh_queue(e.id, x.teacher_id)) order by x.t), '[]'::jsonb)
      from public.yh_bookings b join public.yh_slots x on x.id = b.slot_id join public.milui_teachers t on t.id = x.teacher_id
      left join public.yh_participants p on p.event_id = e.id and p.teacher_id = x.teacher_id
      where b.ptoken = p_ptoken));
end $function$;

create or replace function public.yh_cancel(p_ptoken text, p_booking int) returns void
language plpgsql security definer set search_path to '' as $function$
begin
  delete from public.yh_bookings b using public.yh_event e
    where b.id = p_booking and b.ptoken = p_ptoken and e.id = b.event_id and b.started_at is null
      and e.day >= (now() at time zone 'Asia/Jerusalem')::date;
end $function$;

-- סיכום ללוח ההנהלה: אחוז שיבוץ לפי כיתה (מספרים בלבד)
create or replace function public.yh_summary(p_phone text) returns jsonb
language plpgsql stable security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); e public.yh_event := public._yh_ev();
begin
  if e.id is null then return jsonb_build_object('event', null); end if;
  return jsonb_build_object('event', jsonb_build_object('day', e.day, 'reg_open', e.reg_open),
    'classes', (select coalesce(jsonb_agg(jsonb_build_object('name', c.name, 'students', cardinality(public._yh_students(c.name)),
        'booked', (select count(distinct b.student) from public.yh_bookings b where b.event_id = e.id and b.class_name = c.name)) order by c.sort), '[]'::jsonb)
      from public.milui_classes c));
end $function$;

do $$ declare f text; begin
  foreach f in array array['yh_staff_load(text)','yh_admin_save_event(text,jsonb)','yh_admin_set_participants(text,jsonb)','yh_admin_build(text)',
    'yh_slot_break(text,int,boolean)','yh_staff_book(text,int,text,text,text,text)','yh_staff_cancel(text,int)','yh_staff_move(text,int,int)',
    'yh_live(text,int,text)','yh_class(text)','yh_book(text,text,text,text,boolean,jsonb,text)','yh_mine(text)','yh_cancel(text,int)','yh_summary(text)'] loop
    execute format('revoke all on function public.%s from public', f);
    execute format('grant execute on function public.%s to anon, authenticated', f);
  end loop;
  foreach f in array array['_yh_tok()','_yh_now()','_yh_ev()','_yh_students(text)','_yh_is_admin(public.hanhala_staff)','_yh_tid(public.hanhala_staff)',
    '_yh_check(public.yh_event,public.yh_slots,text,text,text)','_yh_queue(int,int)'] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;
