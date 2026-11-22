-- 050: משובי 22.11 — תור בלי לחיצות (no_live), הפסקה באורך משלה, פתיחת הרשמה בלחיצה, מורים מקצועיים לכיתה במועד נפרד
alter table public.yh_participants add column if not exists no_live boolean not null default false;
alter table public.yh_participants add column if not exists brk_at time;
alter table public.yh_participants add column if not exists brk_min int;

do $m$
declare d text;
begin
  -- הפסקה: המשבצות נעצרות בתחילת ההפסקה וממשיכות אחריה
  d := pg_get_functiondef('public._yh_rebuild(public.yh_event,integer)'::regprocedure);
  if position('brk_at' in d) = 0 then
    d := replace(d, $a$      generate_series(('2000-01-01 '||coalesce(p.t_start, e.t_start))::timestamp,
                      ('2000-01-01 '||coalesce(p.t_end, e.t_end))::timestamp - make_interval(mins => len),
                      make_interval(mins => len + e.gap_min)) g),$a$,
$b$      (select g1 from generate_series(('2000-01-01 '||coalesce(p.t_start, e.t_start))::timestamp,
                      ('2000-01-01 '||(case when coalesce(p.brk_min,0) > 0 and p.brk_at is not null then least(p.brk_at, coalesce(p.t_end, e.t_end)) else coalesce(p.t_end, e.t_end) end))::timestamp - make_interval(mins => len),
                      make_interval(mins => len + e.gap_min)) g1
       union all
       select g2 from generate_series(('2000-01-01 '||p.brk_at)::timestamp + make_interval(mins => coalesce(p.brk_min,0)),
                      ('2000-01-01 '||coalesce(p.t_end, e.t_end))::timestamp - make_interval(mins => len),
                      make_interval(mins => len + e.gap_min)) g2
       where coalesce(p.brk_min,0) > 0 and p.brk_at is not null) gg(g)),$b$);
    if position('brk_at' in d) = 0 then raise exception '_yh_rebuild'; end if;
    execute d;
  end if;

  d := pg_get_functiondef('public.yh_mine(text)'::regprocedure);
  if position('no_live' in d) = 0 then
    d := replace(d, '''queue'', public._yh_queue2', '''no_live'', coalesce(p.no_live, false), ''queue'', public._yh_queue2');
    if position('no_live' in d) = 0 then raise exception 'yh_mine'; end if;
    execute d;
  end if;

  d := pg_get_functiondef('public.yh_staff_load(text)'::regprocedure);
  if position('no_live' in d) = 0 then
    d := replace(d, '''pending'', p.pending,', '''pending'', p.pending, ''no_live'', p.no_live, ''brk_at'', to_char(p.brk_at,''HH24:MI''), ''brk_min'', p.brk_min,');
    if position('no_live' in d) = 0 then raise exception 'yh_staff_load'; end if;
    execute d;
  end if;
end $m$;

-- השעות שלי + הפסקה
drop function if exists public.yh_my_settings(text, text, text, integer);
create or replace function public.yh_my_settings(p_phone text, p_start text, p_end text, p_slot integer, p_brk_at text default null, p_brk_min integer default null)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare s public.hanhala_staff := public._hanhala_me(p_phone); e public.yh_event := public._yh_ev(); tid int := public._yh_tid(s);
  ts time := nullif(p_start,'')::time; te time := nullif(p_end,'')::time; sm int := nullif(p_slot, 0);
  ba time := nullif(p_brk_at,'')::time; bm int := nullif(p_brk_min, 0);
begin
  if e.id is null then raise exception 'no_event'; end if;
  if tid is null or not exists (select 1 from public.yh_participants where event_id = e.id and teacher_id = tid) then raise exception 'forbidden'; end if;
  if e.reg_open and not public._yh_is_admin(s) then raise exception 'reg_open'; end if;
  if sm is not null and (sm < 5 or sm > 60) then raise exception 'bad_len'; end if;
  if coalesce(ts, e.t_start) >= coalesce(te, e.t_end) then raise exception 'bad_hours'; end if;
  if bm is not null and (bm < 5 or bm > 120 or ba is null or ba <= coalesce(ts, e.t_start) or ba >= coalesce(te, e.t_end)) then raise exception 'bad_brk'; end if;
  update public.yh_participants set t_start = case when ts = e.t_start then null else ts end, t_end = case when te = e.t_end then null else te end,
    slot_min = case when sm = e.slot_min then null else sm end,
    brk_at = case when bm is null then null else ba end, brk_min = bm
    where event_id = e.id and teacher_id = tid;
  return public._yh_rebuild(e, tid);
end $f$;
grant execute on function public.yh_my_settings(text, text, text, integer, text, integer) to anon, authenticated;

-- תור בלי לחיצות: המורה (או ההנהלה) מסמנים שהמורה לא מעדכן כניסה ויציאה
create or replace function public.yh_set_live(p_phone text, p_tid integer, p_no_live boolean)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare s public.hanhala_staff := public._hanhala_me(p_phone); e public.yh_event := public._yh_ev(); tid int := coalesce(p_tid, public._yh_tid(s));
begin
  if e.id is null then raise exception 'no_event'; end if;
  if tid is distinct from public._yh_tid(s) and not public._yh_can_edit(s, tid) then raise exception 'forbidden'; end if;
  update public.yh_participants set no_live = coalesce(p_no_live, false) where event_id = e.id and teacher_id = tid;
  return jsonb_build_object('ok', true);
end $f$;
grant execute on function public.yh_set_live(text, integer, boolean) to anon, authenticated;

-- פתיחה/סגירה של ההרשמה לכל הכיתות בלחיצה
create or replace function public.yh_admin_reg(p_phone text, p_open boolean)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare s public.hanhala_staff := public._hanhala_me(p_phone); e public.yh_event := public._yh_ev();
begin
  if not public._yh_is_admin(s) then raise exception 'forbidden'; end if;
  if e.id is null then raise exception 'no_event'; end if;
  update public.yh_event set reg_open = coalesce(p_open, false) where id = e.id;
  return jsonb_build_object('reg_open', coalesce(p_open, false));
end $f$;
grant execute on function public.yh_admin_reg(text, boolean) to anon, authenticated;

-- כיתה שלא מקיימת את יום ההורים עם כולם: פתיחת המורים המקצועיים שלה להרשמה (לפי המערכת השעתית)
create or replace function public.yh_class_subjects(p_phone text, p_class text, p_on boolean)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare s public.hanhala_staff := public._hanhala_me(p_phone); e public.yh_event := public._yh_ev(); n int;
begin
  if e.id is null then raise exception 'no_event'; end if;
  if not (public._yh_is_admin(s) or left(p_class, 1) = any(public._yh_house_grades(s))) then raise exception 'forbidden'; end if;
  with t as (select distinct x.teacher_id from public.milui_slots x
             where x.kind in ('שיעור','שיעור משותף') and p_class = any(x.classes)),
  u as (update public.yh_participants p set classes = case when p_on
            then (select array_agg(distinct c order by c) from unnest(p.classes || array[p_class]) c)
            else array_remove(p.classes, p_class) end
        where p.event_id = e.id and not public._yh_is_hr(p.teacher_id)
          and (p_on and p.teacher_id in (select teacher_id from t) and not p_class = any(p.classes)
               or not p_on and p_class = any(p.classes))
        returning 1)
  select count(*) into n from u;
  perform public._yh_ensure_tlinks(e.id);
  return jsonb_build_object('n', n);
end $f$;
grant execute on function public.yh_class_subjects(text, text, boolean) to anon, authenticated;
