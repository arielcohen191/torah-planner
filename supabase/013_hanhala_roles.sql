-- לוח הנהלה: תפקידים, הרשאות והתאמה אישית (מיגרציה "hanhala_roles").
-- הכניסה נשארת לפי טלפון (זיהוי: שם + טלפון). רשימת הנכנסים ללוח נפרדת מ-milui_admins:
-- מי שנכנס ללוח לא מקבל בזכות זה הרשאת עריכה במילוי מקום / תורנויות.
-- הנתונים של כל כלי מוחזרים מהשרת רק למי שהכלי פתוח לתפקיד שלו (hanhala_data).
-- סינון לפי שכבות הוא בתצוגה בלבד בשלב זה.

create table if not exists public.hanhala_roles(
  id text primary key,
  label text not null,
  tools text[] not null default '{}',
  scope text not null default 'all' check (scope in ('all','layers')),
  sort int not null default 0);
create table if not exists public.hanhala_staff(
  phone text primary key,
  name text not null,
  role_id text not null references public.hanhala_roles(id),
  layers text[] not null default '{}',
  can_manage boolean not null default false,
  prefs jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by text);
alter table public.hanhala_roles enable row level security;
alter table public.hanhala_staff enable row level security;
revoke all on public.hanhala_roles, public.hanhala_staff from anon, authenticated;

insert into public.hanhala_roles(id,label,tools,scope,sort) values
  ('principal','מנהל','{milui,toranut,sayarot,mapat,hespek}','all',10),
  ('sysadmin','מנהל מערכת','{milui,toranut,sayarot,mapat,hespek}','all',15),
  ('deputy','סגנית','{milui,toranut}','all',20),
  ('house_head','מנהל/ת בית','{milui,toranut,sayarot,mapat,hespek}','layers',30),
  ('house_deputy','סגן/ית מנהל בית','{milui,toranut,sayarot,mapat,hespek}','layers',40),
  ('pedagogic','רכזת פדגוגית','{mapat,hespek}','all',50),
  ('counselor','יועצת','{mapat}','layers',60),
  ('shiluv','רכזת שילוב','{}','all',70)
on conflict (id) do nothing;

-- זריעה ראשונית מצוות הניהול הקיים של מילוי מקום
insert into public.hanhala_staff(phone,name,role_id,layers,can_manage,updated_by)
select a.phone, a.name,
  case a.name when 'חגי כהן' then 'principal' when 'אריאל כהן' then 'sysadmin' when 'אתי ארג''י' then 'deputy' else 'house_head' end,
  case a.name when 'גילה פרטוש' then '{א,ב}'::text[] when 'אוריה עובד' then '{ה,ו}'::text[] else '{}'::text[] end,
  a.name in ('חגי כהן','אריאל כהן'), 'זריעה ראשונית'
from public.milui_admins a
on conflict (phone) do nothing;

create or replace function public._hanhala_me(p_phone text)
returns public.hanhala_staff language plpgsql stable security definer set search_path to '' as $$
declare s public.hanhala_staff;
begin
  select * into s from public.hanhala_staff where phone = public.milui_norm(p_phone);
  if s.phone is null then raise exception 'no_access'; end if;
  return s;
end $$;

create or replace function public._hanhala_payload(s public.hanhala_staff)
returns jsonb language sql stable security definer set search_path to '' as $$
  select jsonb_build_object('name', s.name, 'role', r.id, 'role_label', r.label, 'tools', to_jsonb(r.tools),
    'scope', r.scope, 'layers', to_jsonb(case when r.scope = 'layers' then s.layers else '{}'::text[] end),
    'can_manage', s.can_manage, 'prefs', s.prefs)
  from public.hanhala_roles r where r.id = s.role_id $$;

create or replace function public.hanhala_me(p_phone text)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
begin return public._hanhala_payload(public._hanhala_me(p_phone)); end $$;

-- כל הנתונים שהלוח צריך, בקריאה אחת. כל כלי מוחזר רק אם הוא פתוח לתפקיד.
create or replace function public.hanhala_data(p_phone text, p_from date, p_to date)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare s public.hanhala_staff := public._hanhala_me(p_phone); tools text[]; out jsonb; st public.toranut_state;
begin
  if p_to < p_from or p_to - p_from > 62 then raise exception 'bad_range'; end if;
  select r.tools into tools from public.hanhala_roles r where r.id = s.role_id;
  out := jsonb_build_object('me', public._hanhala_payload(s),
    'classes', (select coalesce(jsonb_agg(c.name order by c.sort), '[]'::jsonb) from public.milui_classes c),
    'staff_n', (select count(*) from public.milui_teachers t where t.active and not t.is_external));
  if 'milui' = any(tools) then
    out := out || jsonb_build_object('milui', jsonb_build_object(
      'teachers', (select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'name',t.name)), '[]'::jsonb) from public.milui_teachers t),
      'slots', (select coalesce(jsonb_agg(jsonb_build_array(x.id,x.teacher_id,x.day,x.hour,x.kind,x.subject,x.classes)), '[]'::jsonb) from public.milui_slots x),
      'absences', (select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'teacher_id',a.teacher_id,'date_from',a.date_from,'date_to',a.date_to,'hours',a.hours) order by a.date_from), '[]'::jsonb)
          from public.milui_absences a where a.date_from <= p_to and (a.date_to is null or a.date_to >= p_from)),
      'assignments', (select coalesce(jsonb_agg(jsonb_build_object('date',x.date,'slot_id',x.slot_id,'status',x.status,'substitute_id',x.substitute_id,'comp_done',x.comp_done)), '[]'::jsonb)
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
    out := out || jsonb_build_object('mk', jsonb_build_object(
      'classes_synced', (select coalesce(jsonb_agg(jsonb_build_object('name', coalesce(c.class_name, c.class_key),
            'students', coalesce(jsonb_array_length(c.rows), 0), 'synced_at', c.synced_at) order by c.class_key), '[]'::jsonb) from public.mk_class_data c),
      'staff_access', (select count(*) from public.mk_access),
      'staff_entered', (select count(*) from public.mk_access where pin_hash is not null),
      'q_filled', (select count(*) from public.mk_staff_q),
      'q_last', (select max(updated_at) from public.mk_staff_q)));
  end if;
  return out;
end $$;

create or replace function public.hanhala_save_prefs(p_phone text, p_prefs jsonb)
returns void language plpgsql security definer set search_path to '' as $$
declare s public.hanhala_staff := public._hanhala_me(p_phone);
begin
  if jsonb_typeof(p_prefs) <> 'object' or length(p_prefs::text) > 2000 then raise exception 'bad_payload'; end if;
  update public.hanhala_staff set prefs = p_prefs where phone = s.phone;
end $$;

create or replace function public._hanhala_manager(p_phone text)
returns public.hanhala_staff language plpgsql stable security definer set search_path to '' as $$
declare s public.hanhala_staff := public._hanhala_me(p_phone);
begin if not s.can_manage then raise exception 'forbidden'; end if; return s; end $$;

create or replace function public.hanhala_admin_list(p_phone text)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare s public.hanhala_staff := public._hanhala_manager(p_phone);
begin
  return jsonb_build_object(
    'staff', (select coalesce(jsonb_agg(jsonb_build_object('phone',x.phone,'name',x.name,'role_id',x.role_id,'layers',to_jsonb(x.layers),
        'can_manage',x.can_manage,'self',x.phone = s.phone) order by r.sort, x.name), '[]'::jsonb)
        from public.hanhala_staff x join public.hanhala_roles r on r.id = x.role_id),
    'roles', (select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'label',r.label,'tools',to_jsonb(r.tools),'scope',r.scope,
        'n',(select count(*) from public.hanhala_staff x where x.role_id = r.id)) order by r.sort), '[]'::jsonb) from public.hanhala_roles r));
end $$;

create or replace function public.hanhala_admin_save_staff(p_phone text, p jsonb)
returns void language plpgsql security definer set search_path to '' as $$
declare s public.hanhala_staff := public._hanhala_manager(p_phone);
  ph text := public.milui_norm(p->>'phone'); old text := nullif(public.milui_norm(p->>'old_phone'),'');
  nm text := btrim(coalesce(p->>'name','')); mg boolean := coalesce((p->>'can_manage')::boolean, false);
  ly text[] := array(select jsonb_array_elements_text(coalesce(p->'layers','[]'::jsonb)));
begin
  if ph !~ '^0\d{8,9}$' then raise exception 'bad_phone'; end if;
  if nm = '' or length(nm) > 60 then raise exception 'bad_name'; end if;
  if not exists (select 1 from public.hanhala_roles r where r.id = p->>'role_id') then raise exception 'bad_role'; end if;
  if not ly <@ array['א','ב','ג','ד','ה','ו'] then raise exception 'bad_layers'; end if;
  if old is not null and old <> ph and exists (select 1 from public.hanhala_staff where phone = ph) then raise exception 'phone_exists'; end if;
  if old is null and exists (select 1 from public.hanhala_staff where phone = ph) then raise exception 'phone_exists'; end if;
  if coalesce(old, ph) = s.phone then mg := true; end if;  -- מנהל הרשאות לא יכול לבטל לעצמו את הניהול
  if old is not null then
    update public.hanhala_staff set phone = ph, name = nm, role_id = p->>'role_id', layers = ly, can_manage = mg,
      updated_at = now(), updated_by = s.name where phone = old;
    if not found then raise exception 'not_found'; end if;
  else
    insert into public.hanhala_staff(phone,name,role_id,layers,can_manage,updated_by) values (ph,nm,p->>'role_id',ly,mg,s.name);
  end if;
end $$;

create or replace function public.hanhala_admin_delete_staff(p_phone text, p_target text)
returns void language plpgsql security definer set search_path to '' as $$
declare s public.hanhala_staff := public._hanhala_manager(p_phone); t text := public.milui_norm(p_target);
begin
  if t = s.phone then raise exception 'cannot_delete_self'; end if;
  delete from public.hanhala_staff where phone = t;
end $$;

create or replace function public.hanhala_admin_save_role(p_phone text, p jsonb)
returns text language plpgsql security definer set search_path to '' as $$
declare s public.hanhala_staff := public._hanhala_manager(p_phone);
  rid text := nullif(p->>'id',''); lb text := btrim(coalesce(p->>'label',''));
  tl text[] := array(select jsonb_array_elements_text(coalesce(p->'tools','[]'::jsonb)));
  sc text := coalesce(p->>'scope','all');
begin
  if lb = '' or length(lb) > 40 then raise exception 'bad_label'; end if;
  if not tl <@ array['milui','toranut','sayarot','mapat','hespek'] then raise exception 'bad_tools'; end if;
  if sc not in ('all','layers') then raise exception 'bad_scope'; end if;
  if rid is null then
    rid := 'r' || substr(md5(random()::text || clock_timestamp()::text), 1, 8);
    insert into public.hanhala_roles(id,label,tools,scope,sort)
      values (rid, lb, tl, sc, (select coalesce(max(sort),0) + 10 from public.hanhala_roles));
  else
    update public.hanhala_roles set label = lb, tools = tl, scope = sc where id = rid;
    if not found then raise exception 'not_found'; end if;
  end if;
  return rid;
end $$;

create or replace function public.hanhala_admin_delete_role(p_phone text, p_id text)
returns void language plpgsql security definer set search_path to '' as $$
declare s public.hanhala_staff := public._hanhala_manager(p_phone);
begin
  if exists (select 1 from public.hanhala_staff where role_id = p_id) then raise exception 'role_in_use'; end if;
  delete from public.hanhala_roles where id = p_id;
end $$;

revoke all on function public._hanhala_me(text), public._hanhala_payload(public.hanhala_staff), public._hanhala_manager(text) from public, anon, authenticated;
revoke all on function public.hanhala_me(text), public.hanhala_data(text,date,date), public.hanhala_save_prefs(text,jsonb),
  public.hanhala_admin_list(text), public.hanhala_admin_save_staff(text,jsonb), public.hanhala_admin_delete_staff(text,text),
  public.hanhala_admin_save_role(text,jsonb), public.hanhala_admin_delete_role(text,text) from public;
grant execute on function public.hanhala_me(text), public.hanhala_data(text,date,date), public.hanhala_save_prefs(text,jsonb),
  public.hanhala_admin_list(text), public.hanhala_admin_save_staff(text,jsonb), public.hanhala_admin_delete_staff(text,text),
  public.hanhala_admin_save_role(text,jsonb), public.hanhala_admin_delete_role(text,text) to anon, authenticated;
