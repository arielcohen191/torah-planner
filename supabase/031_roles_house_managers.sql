-- 031: תפקידים רשמיים
-- 1. תפקידים חדשים: מלמד, סייע/ת
-- 2. המנהל ומנהלות הבתים יכולים לשנות תפקידים ולהוסיף אנשי צוות (בלי ניהול הרשאות, בלי תפקידי מנהל/מנהל מערכת, בלי מחיקה)
-- 3. מפת כיתה מקבלת official_roles: התפקידים הרשמיים לשאלון האישי

insert into public.hanhala_roles(id,label,sort) values ('melamed','מלמד',225),('aide','סייע/ת',380) on conflict (id) do nothing;

CREATE OR REPLACE FUNCTION public._hanhala_role_editor(p_phone text)
 RETURNS hanhala_staff LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone);
begin
  if not (s.can_manage or exists (select 1 from public.hanhala_staff_roles r where r.phone = s.phone and r.role_id in ('principal','house_ab','house_gd','house_hv'))) then raise exception 'forbidden'; end if;
  return s;
end $function$;

DO $do$
declare src text := pg_get_functiondef('public.hanhala_admin_list(text)'::regprocedure); n text;
begin
  n := replace(src, 'public._hanhala_manager(p_phone)', 'public._hanhala_role_editor(p_phone)');
  if n = src and position('_hanhala_role_editor' in src) = 0 then raise exception 'patch point not found'; end if;
  execute n;
end $do$;

CREATE OR REPLACE FUNCTION public.hanhala_admin_save_staff(p_phone text, p jsonb)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
declare s public.hanhala_staff := public._hanhala_role_editor(p_phone);
  ph text := public.milui_norm(p->>'phone'); old text := nullif(public.milui_norm(p->>'old_phone'),'');
  nm text := btrim(coalesce(p->>'name','')); mg boolean := coalesce((p->>'can_manage')::boolean, false);
  rl text[] := array(select distinct jsonb_array_elements_text(coalesce(p->'roles','[]'::jsonb)));
  cur public.hanhala_staff; prot text[] := array['principal','sysadmin'];
begin
  if not s.can_manage then
    rl := array(select x from unnest(rl) x where x <> all(prot));
    if old is null then
      mg := false;
    else
      select * into cur from public.hanhala_staff where phone = old;
      if cur.phone is null then raise exception 'not_found'; end if;
      ph := cur.phone; nm := cur.name; mg := cur.can_manage;
      rl := rl || array(select role_id from public.hanhala_staff_roles where phone = ph and role_id = any(prot));
    end if;
  end if;
  if ph !~ '^0\d{8,9}$' then raise exception 'bad_phone'; end if;
  if nm = '' or length(nm) > 60 then raise exception 'bad_name'; end if;
  if cardinality(rl) = 0 then raise exception 'no_roles'; end if;
  if exists (select 1 from unnest(rl) x where not exists (select 1 from public.hanhala_roles r where r.id = x)) then raise exception 'bad_role'; end if;
  if ph is distinct from old and exists (select 1 from public.hanhala_staff where phone = ph) then raise exception 'phone_exists'; end if;
  if coalesce(old, ph) = s.phone and s.can_manage then mg := true; end if;
  if old is not null then
    update public.hanhala_staff set phone = ph, name = nm, can_manage = mg, updated_at = now(), updated_by = s.name where phone = old;
    if not found then raise exception 'not_found'; end if;
  else
    insert into public.hanhala_staff(phone,name,can_manage,updated_by) values (ph,nm,mg,s.name);
  end if;
  delete from public.hanhala_staff_roles where phone = ph and role_id <> all(rl);
  insert into public.hanhala_staff_roles(phone, role_id) select ph, x from unnest(rl) x on conflict do nothing;
end $function$;

DO $do$
declare src text := pg_get_functiondef('public._mk_payload(mk_access)'::regprocedure); n text;
begin
  if position('official_roles' in src) > 0 then return; end if;
  n := replace(src, $q$'shiluv', coalesce(a.shiluv, false),$q$, $q$'shiluv', coalesce(a.shiluv, false),
    'official_roles', (select to_jsonb(array_remove(array[
        case when a.class_name is not null then 'מחנך' end,
        case when coalesce(a.shiluv,false) then 'מורה שילוב' end,
        case when not coalesce(a.shiluv,false) and exists (select 1 from public._mk_teacher_classes(a.phone) tc where tc.class_key <> coalesce(public._mk_norm(a.class_name),'')) then 'מורה מקצועי' end], null)
      || coalesce(array(select r.label from public.hanhala_staff_roles sr join public.hanhala_roles r on r.id = sr.role_id
           where sr.phone = public.milui_norm(a.phone) and sr.role_id <> 'sysadmin' order by r.sort), '{}'))),$q$);
  if n = src then raise exception 'patch point not found'; end if;
  execute n;
end $do$;
