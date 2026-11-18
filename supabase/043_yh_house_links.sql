-- יום הורים: מנהלות בתים רואות את הכיתות בשכבות שלהן (קישורים ומצב רישום); לכל כיתה גם booked ו־hr_name
create or replace function public._yh_house_grades(s public.hanhala_staff) returns text[]
language sql stable security definer set search_path to '' as $function$
  select coalesce(array_agg(g), '{}') from (
    select unnest(case r.role_id when 'house_ab' then array['א','ב'] when 'house_gd' then array['ג','ד'] when 'house_hv' then array['ה','ו'] end) g
    from public.hanhala_staff_roles r where r.phone = s.phone and r.role_id like 'house\_%') q $function$;

create or replace function public.yh_staff_load(p_phone text) returns jsonb
language plpgsql stable security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); adm boolean := public._yh_is_admin(s);
  tid int := public._yh_tid(s); e public.yh_event := public._yh_ev(); hg text[] := public._yh_house_grades(s); out jsonb;
begin
  out := jsonb_build_object('me', s.name, 'admin', adm, 'tid', tid, 'house', to_jsonb(hg), 'now', public._yh_now());
  if e.id is null then return out || jsonb_build_object('event', null); end if;
  out := out || jsonb_build_object('event', to_jsonb(e));
  out := out || jsonb_build_object('participants', coalesce((select jsonb_agg(jsonb_build_object('tid', p.teacher_id, 'name', t.name,
      'classes', p.classes, 't_start', p.t_start, 't_end', p.t_end, 'room', p.room) order by t.name)
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

alter table public.dev_feedback_msgs add column if not exists seen_at timestamptz;
