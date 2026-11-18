-- הורים שנפגשים בנפרד (משוב #44): עד שתי פגישות לאותו תלמיד אצל אותו מורה, ובתנאי שהטלפון שונה.
-- 'same_parent' = כבר יש פגישה מהמספר הזה (או בלי מספר); 'already' = כבר יש שתיים.
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
  if p_phone <> '' and exists (select 1 from public.yh_bookings b join public.yh_slots y on y.id = b.slot_id
      where b.event_id = e.id and b.parent_phone = p_phone and abs(extract(epoch from (y.t - x.t))) < e.slot_min * 60) then return 'overlap'; end if;
  return null;
end $function$;
