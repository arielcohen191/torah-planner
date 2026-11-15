-- (מיגרציה "mk_staff_status") לוח ההנהלה, מסך מפת כיתה (#18):
-- 1. כניסה אחרונה לכל איש צוות (mk_access.last_login, מתעדכן בכניסה, לכל היותר פעם ב־10 דקות)
-- 2. רשימת הצוות: מי נכנס ומתי, מי מילא שאלון ומתי
-- 3. תיקון: מספר התלמידים בכיתה נספר לפי שורות התלמידים, לא לפי כל שורות הגיליון
alter table public.mk_access add column if not exists last_login timestamptz;

CREATE OR REPLACE FUNCTION public._mk_auth(p_phone text, p_pin text)
 RETURNS mk_access LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'extensions'
AS $function$
declare a public.mk_access; ph text := public._mk_phone(p_phone); e public.mk_access;
begin
  select * into a from public.mk_access where phone = ph;
  if a.phone is null or a.pin_hash is null then e.name := 'bad'; return e; end if;
  if a.locked_until is not null and a.locked_until > now() then e.name := 'locked'; return e; end if;
  if a.pin_hash <> extensions.crypt(coalesce(p_pin,''), a.pin_hash) then
    update public.mk_access set fails = fails + 1,
      locked_until = case when fails + 1 >= 5 then now() + interval '15 minutes' else null end where phone = ph;
    e.name := 'bad'; return e;
  end if;
  if a.fails > 0 then update public.mk_access set fails = 0, locked_until = null where phone = ph; end if;
  if a.last_login is null or a.last_login < now() - interval '10 minutes' then update public.mk_access set last_login = now() where phone = ph; end if;
  return a;
end $function$;

create or replace function public._hanhala_mk(p_full boolean) returns jsonb language sql stable security definer set search_path to '' as $$
  select jsonb_build_object(
    'classes_total', (select count(*) from public.milui_classes),
    'classes_synced', (select coalesce(jsonb_agg(jsonb_build_object('name', coalesce(c.class_name, c.class_key),
          'students', coalesce(jsonb_array_length(public._mk_canon_rows(c.rows)), 0), 'synced_at', c.synced_at) order by c.class_key), '[]'::jsonb)
        from public.mk_class_data c),
    'staff_access', (select count(*) from public.mk_access),
    'staff_entered', (select count(*) from public.mk_access where pin_hash is not null),
    'q_filled', (select count(*) from public.mk_staff_q),
    'q_last', (select max(updated_at) from public.mk_staff_q))
  || case when p_full then jsonb_build_object('staff', (select coalesce(jsonb_agg(jsonb_build_object(
          'name', p.name, 'role', m.role, 'cls', m.class_name, 'access', m.phone is not null, 'entered', m.pin_hash is not null,
          'last_login', m.last_login, 'q_at', q.updated_at) order by p.name), '[]'::jsonb)
        from (select public._mk_phone(phone) phone, min(name) as name from (
                select phone, name from public.milui_teachers where active and not coalesce(is_external,false) and coalesce(phone,'') <> ''
                union all select phone, name from public.mk_access) u group by 1) p
        left join public.mk_access m on m.phone = p.phone
        left join public.mk_staff_q q on q.phone = p.phone)) else '{}'::jsonb end
$$;
revoke all on function public._hanhala_mk(boolean) from public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.hanhala_summary(p_phone text)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
declare me text := public.milui_who(p_phone);
begin
  return jsonb_build_object('me', me, 'mk', public._hanhala_mk(false));
end $function$;

CREATE OR REPLACE FUNCTION public.hanhala_data(p_phone text, p_from date, p_to date)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); tools text[]; out jsonb; st public.toranut_state;
begin
  if p_to < p_from or p_to - p_from > 62 then raise exception 'bad_range'; end if;
  select coalesce(array_agg(distinct t), '{}') into tools
    from public.hanhala_staff_roles x join public.hanhala_roles r on r.id = x.role_id, unnest(r.tools) t where x.phone = s.phone;
  out := jsonb_build_object('me', public._hanhala_payload(s),
    'classes', (select coalesce(jsonb_agg(c.name order by c.sort), '[]'::jsonb) from public.milui_classes c),
    'staff_n', (select count(*) from public.milui_teachers t where t.active and not t.is_external));
  if 'milui' = any(tools) then
    out := out || jsonb_build_object('milui', jsonb_build_object(
      'teachers', (select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'name',t.name)), '[]'::jsonb) from public.milui_teachers t),
      'slots', (select coalesce(jsonb_agg(jsonb_build_array(x.id,x.teacher_id,x.day,x.hour,x.kind,x.subject,x.classes)), '[]'::jsonb) from public.milui_slots x),
      'absences', (select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'teacher_id',a.teacher_id,'date_from',a.date_from,'date_to',a.date_to,'hours',a.hours) order by a.date_from), '[]'::jsonb)
          from public.milui_absences a where a.date_from <= p_to and (a.date_to is null or a.date_to >= p_from)),
      'assignments', (select coalesce(jsonb_agg(jsonb_build_object('date',x.date,'slot_id',x.slot_id,'status',x.status,'substitute_id',x.substitute_id,'comp_done',x.comp_done,'other_note',x.other_note)), '[]'::jsonb)
          from public.milui_assignments x where x.date between p_from and p_to)));
  end if;
  if 'toranut' = any(tools) then
    select * into st from public.toranut_state where id = 1;
    out := out || jsonb_build_object('tor', jsonb_build_object(
      'updated_at', st.updated_at, 'updated_by', st.updated_by,
      'staff', (select coalesce(jsonb_agg(jsonb_build_object('id',e->'id','name',e->'name','tt',e->'tt')), '[]'::jsonb) from jsonb_array_elements(coalesce(st.data->'staff','[]'::jsonb)) e),
      'plan', jsonb_build_object('at', st.data->'plan'->'at', 'stale', st.data->'plan'->'stale', 'stats', st.data->'plan'->'stats',
              'assign', coalesce(st.data->'plan'->'assign','{}'::jsonb), 'subs', coalesce(st.data->'plan'->'subs','{}'::jsonb)),
      'yards', st.data->'yards', 'absLocal', coalesce(st.data->'absLocal','[]'::jsonb),
      'abs', (select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'name',t.name,'from',a.date_from,'to',a.date_to,'hours',a.hours)), '[]'::jsonb)
          from public.milui_absences a join public.milui_teachers t on t.id = a.teacher_id
          where a.date_from <= p_to and (a.date_to is null or a.date_to >= p_from))));
  end if;
  if 'mapat' = any(tools) then
    out := out || jsonb_build_object('mk', public._hanhala_mk(true));
  end if;
  return out;
end $function$;
