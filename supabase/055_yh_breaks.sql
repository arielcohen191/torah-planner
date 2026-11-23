-- 055: הפסקות באורך חופשי — רשימת הפסקות לכל מורה (breaks: [{at:"16:00",min:10}, ...])
-- המשבצות נבנות ברצף: כשפגישה הייתה חוצה תחילת הפסקה, היא מתחילה אחרי ההפסקה. מחנך עם auto_end: נבנות בדיוק משבצות כמספר התלמידים.
alter table public.yh_participants add column if not exists breaks jsonb not null default '[]'::jsonb;

-- העברת הנתונים: משבצות שסומנו "הפסקה" (באורך פגישה) והפסקה ארוכה (brk_at/brk_min) — לרשימה
update public.yh_participants p set breaks = coalesce((
  select jsonb_agg(jsonb_build_object('at', a, 'min', m) order by a) from (
    select distinct on (to_char(x.t,'HH24:MI')) to_char(x.t,'HH24:MI') a, coalesce(p.slot_min, e.slot_min) m
    from public.yh_slots x join public.yh_event e on e.id = x.event_id
    where x.event_id = p.event_id and x.teacher_id = p.teacher_id and x.is_break
      and not exists (select 1 from public.yh_bookings b where b.slot_id = x.id)
    union all
    select to_char(p.brk_at,'HH24:MI'), p.brk_min where p.brk_at is not null and coalesce(p.brk_min,0) > 0) q), '[]'::jsonb)
where p.event_id = (public._yh_ev()).id;
update public.yh_participants set brk_at = null, brk_min = null where event_id = (public._yh_ev()).id;

create or replace function public._yh_rebuild(e public.yh_event, p_tid integer)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare p public.yh_participants; n_add int; n_del int; len int; g int; st int; en int; t int; bi int;
  bats int[]; bmins int[]; arr int[] := '{}'; auto boolean; target int;
begin
  select * into p from public.yh_participants where event_id = e.id and teacher_id = p_tid;
  if p.teacher_id is null or p.pending then
    delete from public.yh_slots x where x.event_id = e.id and x.teacher_id = p_tid and not exists (select 1 from public.yh_bookings b where b.slot_id = x.id);
    return jsonb_build_object('added', 0, 'removed', 0);
  end if;
  len := coalesce(p.slot_min, e.slot_min); g := coalesce(e.gap_min, 0);
  st := extract(hour from coalesce(p.t_start, e.t_start))::int*60 + extract(minute from coalesce(p.t_start, e.t_start))::int;
  en := extract(hour from coalesce(p.t_end, e.t_end))::int*60 + extract(minute from coalesce(p.t_end, e.t_end))::int;
  select array_agg(a order by a), array_agg(m order by a) into bats, bmins from (
    select extract(hour from (x->>'at')::time)::int*60 + extract(minute from (x->>'at')::time)::int a, (x->>'min')::int m
    from jsonb_array_elements(coalesce(p.breaks, '[]'::jsonb)) x where coalesce((x->>'min')::int, 0) > 0) q
  where a + m > st;
  auto := p.auto_end and public._yh_is_hr(p_tid);
  if auto then
    target := greatest(1, (select coalesce(sum(cardinality(public._yh_students(c.name))),0)::int from public.milui_classes c where c.homeroom_id = p_tid));
  end if;
  t := st; bi := 1;
  loop
    while bats is not null and bi <= cardinality(bats) and t + len > bats[bi] loop
      t := greatest(t, bats[bi]) + bmins[bi]; bi := bi + 1;
    end loop;
    exit when auto and cardinality(arr) >= target;
    exit when not auto and t + len > en;
    exit when t + len > 23*60+59 or cardinality(arr) >= 300;
    arr := arr || t; t := t + len + g;
  end loop;
  if auto then
    en := case when cardinality(arr) > 0 then arr[cardinality(arr)] + len else st + len end;
    update public.yh_participants set t_end = make_time(en/60, en%60, 0) where event_id = e.id and teacher_id = p_tid;
  end if;
  with want0 as (select dd::date as wd, make_time(a/60, a%60, 0) as t from unnest(public._yh_pdays(e, p)) dd, unnest(arr) a),
  want as (select w.* from want0 w where not exists (
      select 1 from public.yh_slots y join public.yh_bookings b on b.slot_id = y.id
      where y.event_id = e.id and y.teacher_id = p_tid and y.day = w.wd and y.t <> w.t
        and y.t < w.t + make_interval(mins => len) and w.t < y.t + make_interval(mins => len))),
  del as (delete from public.yh_slots x where x.event_id = e.id and x.teacher_id = p_tid
      and not exists (select 1 from want w where w.wd = x.day and w.t = x.t)
      and not exists (select 1 from public.yh_bookings b where b.slot_id = x.id) returning 1),
  unb as (update public.yh_slots x set is_break = false from want w
      where x.event_id = e.id and x.teacher_id = p_tid and x.day = w.wd and x.t = w.t and x.is_break returning 1),
  ins as (insert into public.yh_slots(event_id, teacher_id, day, t) select e.id, p_tid, w.wd, w.t from want w on conflict do nothing returning 1)
  select (select count(*) from ins), (select count(*) from del) into n_add, n_del;
  return jsonb_build_object('added', n_add, 'removed', n_del);
end $f$;

-- הוספה / שינוי / ביטול של הפסקה (p_min ריק = ביטול)
create or replace function public.yh_break_set(p_phone text, p_tid integer, p_at text, p_min integer)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare s public.hanhala_staff := public._hanhala_me(p_phone); e public.yh_event := public._yh_ev(); tid int := coalesce(p_tid, public._yh_tid(s)); a text;
begin
  if e.id is null then raise exception 'no_event'; end if;
  if tid is distinct from public._yh_tid(s) and not public._yh_can_edit(s, tid) then raise exception 'forbidden'; end if;
  a := to_char(p_at::time, 'HH24:MI');
  if p_min is not null and (p_min < 1 or p_min > 180) then raise exception 'bad_brk'; end if;
  update public.yh_participants set breaks = coalesce((
      select jsonb_agg(x order by x->>'at') from (
        select x from jsonb_array_elements(coalesce(breaks,'[]'::jsonb)) x where x->>'at' <> a
        union all select jsonb_build_object('at', a, 'min', p_min) where p_min is not null) q), '[]'::jsonb)
    where event_id = e.id and teacher_id = tid;
  return public._yh_rebuild(e, tid);
end $f$;
grant execute on function public.yh_break_set(text, integer, text, integer) to anon, authenticated;

do $m$
declare d text;
begin
  d := pg_get_functiondef('public.yh_staff_load(text)'::regprocedure);
  if position('''breaks''' in d) = 0 then
    d := replace(d, '''no_live'', p.no_live,', '''no_live'', p.no_live, ''breaks'', coalesce(p.breaks, ''[]''::jsonb),');
    if position('''breaks''' in d) = 0 then raise exception 'yh_staff_load'; end if;
    execute d;
  end if;
end $m$;
