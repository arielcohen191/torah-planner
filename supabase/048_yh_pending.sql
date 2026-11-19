-- 048: מורה ש"המועד שלו עוד לא נקבע" (pending): משתתף, בלי משבצות, עד שההנהלה קובעת תאריך
alter table public.yh_participants add column if not exists pending boolean not null default false;

do $m$
declare d text;
begin
  d := pg_get_functiondef('public._yh_rebuild(public.yh_event,integer)'::regprocedure);
  if position('p.pending' in d) = 0 then
    d := replace(d, '  len := coalesce(p.slot_min, e.slot_min);',
      '  if p.pending then
    delete from public.yh_slots x where x.event_id = e.id and x.teacher_id = p_tid and not exists (select 1 from public.yh_bookings b where b.slot_id = x.id);
    return jsonb_build_object(''added'', 0, ''removed'', 0);
  end if;
  len := coalesce(p.slot_min, e.slot_min);');
    if position('p.pending' in d) = 0 then raise exception '_yh_rebuild'; end if;
    execute d;
  end if;

  d := pg_get_functiondef('public.yh_class(text)'::regprocedure);
  d := replace(d, '''homeroom'', true, ''slot_min''', '''homeroom'', true, ''pending'', p.pending, ''slot_min''');
  if position('p.pending' in d) = 0 then raise exception 'yh_class'; end if;
  execute d;

  d := pg_get_functiondef('public.yh_staff_load(text)'::regprocedure);
  d := replace(d, '''own_days'', p.days,', '''own_days'', p.days, ''pending'', p.pending,');
  if position('p.pending' in d) = 0 then raise exception 'yh_staff_load'; end if;
  execute d;

  d := pg_get_functiondef('public.yh_house_set(text,jsonb)'::regprocedure);
  d := replace(d, 'days = case when j ? ''days'' then ds else days end',
    'days = case when j ? ''days'' then ds else days end, pending = case when j ? ''pending'' then coalesce((j->>''pending'')::boolean, false) else pending end');
  if position('pending =' in d) = 0 then raise exception 'yh_house_set'; end if;
  execute d;
end $m$;

-- אתי (ד' 3) ורעות בוסקילה (ג' 2): נפגשות במועד אחר, שעוד לא נקבע
insert into public.yh_participants(event_id, teacher_id, classes, pending)
select e.id, c.homeroom_id, array[c.name], true
from public.yh_event e, public.milui_classes c
where e.id = (public._yh_ev()).id and c.homeroom_id in (5, 8)
on conflict (event_id, teacher_id) do update set pending = true;
