-- לוח הנהלה: בעלי תפקידים לפי הרשימה של הרב חגי (מיגרציה "hanhala_positions").
-- תפקיד = משרה (למשל "מנהלת בית א׳–ב׳", "יועצת ד׳–ו׳"): יש לו כלים ושכבות. לאדם יכולים להיות כמה תפקידים;
-- הכלים שלו = איחוד הכלים של התפקידים, והשכבות שלו = איחוד השכבות. אין יותר עמודת scope: תפקיד בלי שכבות = כל בית הספר.

alter table public.hanhala_roles add column if not exists layers text[] not null default '{}';
create table if not exists public.hanhala_staff_roles(
  phone text not null references public.hanhala_staff(phone) on update cascade on delete cascade,
  role_id text not null references public.hanhala_roles(id) on update cascade,
  primary key (phone, role_id));
alter table public.hanhala_staff_roles enable row level security;
revoke all on public.hanhala_staff_roles from anon, authenticated;

-- הטבלה של שעה שעברה הייתה זריעה בלבד; מעבירים את האנשים, ובונים את התפקידים מחדש
alter table public.hanhala_staff drop constraint if exists hanhala_staff_role_id_fkey;
alter table public.hanhala_staff drop column if exists role_id;
alter table public.hanhala_staff drop column if exists layers;
delete from public.hanhala_staff_roles;
delete from public.hanhala_roles;
alter table public.hanhala_roles drop column if exists scope;

insert into public.hanhala_roles(id,label,tools,layers,sort) values
  ('principal','מנהל','{milui,toranut,sayarot,mapat,hespek}','{}',10),
  ('deputy1','סגנית 1','{milui,toranut}','{}',20),
  ('deputy2','סגנית 2','{milui,toranut}','{}',30),
  ('house_ab','מנהלת בית א׳–ב׳','{milui,toranut,sayarot,mapat,hespek}','{א,ב}',40),
  ('layer_a','רכזת שכבה א׳','{milui,mapat}','{א}',50),
  ('layer_b','רכזת שכבה ב׳','{milui,mapat}','{ב}',60),
  ('house_gd','מנהלת בית ג׳–ד׳','{milui,toranut,sayarot,mapat,hespek}','{ג,ד}',70),
  ('layer_g','רכזת שכבה ג׳','{milui,mapat}','{ג}',80),
  ('layer_d','רכזת שכבה ד׳','{milui,mapat}','{ד}',90),
  ('house_hv','מנהלת בית ה׳–ו׳','{milui,toranut,sayarot,mapat,hespek}','{ה,ו}',100),
  ('layer_h','רכז שכבה ה׳','{milui,mapat}','{ה}',110),
  ('layer_v','רכזת שכבה ו׳','{milui,mapat}','{ו}',120),
  ('hanam','רכזת חנ״מ','{}','{}',130),
  ('shiluv','רכזת שילוב','{}','{}',140),
  ('counselor_abg','יועצת א׳–ג׳','{mapat}','{א,ב,ג}',150),
  ('counselor_dhv','יועצת ד׳–ו׳','{mapat}','{ד,ה,ו}',160),
  ('hh','רכז/ת ח״ח','{}','{}',170),
  ('rav','רב בית הספר','{sayarot}','{}',180),
  ('kodesh','רכז קודש','{hespek}','{}',190),
  ('tanach','רכז תנ״ך','{hespek}','{}',200),
  ('tushba','רכז תושב״ע','{hespek}','{}',210),
  ('melamdim','מוביל חבורת מלמדים','{hespek}','{}',220),
  ('pedagogic','רכזת פדגוגית','{mapat,hespek}','{}',230),
  ('lashon','רכזת חינוך לשוני','{hespek}','{}',240),
  ('math','רכזת מתמטיקה','{hespek}','{}',250),
  ('english','רכזת אנגלית','{hespek}','{}',260),
  ('amirim','רכזת אמירים','{}','{}',270),
  ('hachala','רכזת הכלה והשתלבות','{}','{}',280),
  ('measure','רכזת מדידה והערכה','{}','{}',290),
  ('abat','עב״ט','{}','{}',300),
  ('maarechet','מערכת ומילוי מקום','{milui,toranut}','{}',310),
  ('tiyulim','טיולים','{}','{}',320),
  ('tikshuv','תקשוב וטכנו־פדגוגיה','{}','{}',330),
  ('zahav','זה״ב ואורח חיים בריא','{}','{}',340),
  ('allergies','אלרגיות','{}','{}',350),
  ('science','מדעים ומעבדה','{hespek}','{}',360),
  ('sysadmin','מנהל מערכת','{milui,toranut,sayarot,mapat,hespek}','{}',900);

-- אנשי צוות חדשים: הטלפון מרשימת המורים של מילוי המקום
insert into public.hanhala_staff(phone,name,can_manage,updated_by)
select public.milui_norm(t.phone), v.name, false, 'רשימת בעלי התפקידים'
from (values (1,'מיטל אבוחצירא'),(3,'מוריה איבגי'),(10,'ברכי דהאן'),(35,'ברקת מאור'),(33,'שרית לוי'),(43,'קרן קניגסברג'),
             (21,'הרב נתנאל רדלר'),(15,'הרב שמעון חי בן שחר'),(8,'רעות בוסקילה'),(24,'רעות זהבי'),(14,'הרב אדיר בוסי'),(27,'אורטל חן')) v(tid,name)
join public.milui_teachers t on t.id = v.tid
where coalesce(t.phone,'') <> ''
on conflict (phone) do nothing;

insert into public.hanhala_staff_roles(phone, role_id)
select s.phone, r.role_id
from (values
  ('חגי כהן','principal'),('חגי כהן','deputy1'),
  ('אריאל כהן','sysadmin'),
  ('גילה פרטוש','deputy2'),('גילה פרטוש','house_ab'),('גילה פרטוש','layer_b'),('גילה פרטוש','pedagogic'),
  ('מיטל אבוחצירא','layer_a'),('מיטל אבוחצירא','allergies'),
  ('אתי ארג''י','house_gd'),('אתי ארג''י','maarechet'),
  ('מוריה איבגי','layer_g'),('מוריה איבגי','measure'),
  ('ברכי דהאן','layer_d'),
  ('אוריה עובד','house_hv'),('אוריה עובד','layer_v'),('אוריה עובד','lashon'),('אוריה עובד','hachala'),
  ('ברקת מאור','hanam'),('ברקת מאור','hh'),
  ('שרית לוי','counselor_abg'),('קרן קניגסברג','counselor_dhv'),
  ('הרב נתנאל רדלר','kodesh'),('הרב נתנאל רדלר','tanach'),
  ('הרב שמעון חי בן שחר','tushba'),('הרב שמעון חי בן שחר','melamdim'),
  ('רעות בוסקילה','math'),('רעות זהבי','english'),('רעות זהבי','amirim'),
  ('הרב אדיר בוסי','tiyulim'),('הרב אדיר בוסי','tikshuv'),
  ('אורטל חן','zahav'),('אורטל חן','allergies'),('אורטל חן','science')) r(name, role_id)
join public.hanhala_staff s on s.name = r.name
on conflict do nothing;

-- ---------- פונקציות ----------
drop function if exists public._hanhala_payload(public.hanhala_staff);
create or replace function public._hanhala_payload(s public.hanhala_staff)
returns jsonb language sql stable security definer set search_path to '' as $$
  select jsonb_build_object('name', s.name,
    'roles', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'label', r.label) order by r.sort)
        from public.hanhala_staff_roles x join public.hanhala_roles r on r.id = x.role_id where x.phone = s.phone), '[]'::jsonb),
    'role_label', coalesce((select string_agg(r.label, ' · ' order by r.sort)
        from public.hanhala_staff_roles x join public.hanhala_roles r on r.id = x.role_id where x.phone = s.phone), ''),
    'tools', coalesce((select jsonb_agg(distinct t) from public.hanhala_staff_roles x join public.hanhala_roles r on r.id = x.role_id,
        unnest(r.tools) t where x.phone = s.phone), '[]'::jsonb),
    'layers', coalesce((select jsonb_agg(l order by strpos('אבגדהו', l)) from (select distinct l from public.hanhala_staff_roles x
        join public.hanhala_roles r on r.id = x.role_id, unnest(r.layers) l where x.phone = s.phone) z), '[]'::jsonb),
    'can_manage', s.can_manage, 'prefs', s.prefs) $$;

create or replace function public.hanhala_me(p_phone text)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
begin return public._hanhala_payload(public._hanhala_me(p_phone)); end $$;

create or replace function public.hanhala_data(p_phone text, p_from date, p_to date)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
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

create or replace function public.hanhala_admin_list(p_phone text)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare s public.hanhala_staff := public._hanhala_manager(p_phone);
begin
  return jsonb_build_object(
    'staff', (select coalesce(jsonb_agg(jsonb_build_object('phone',x.phone,'name',x.name,'can_manage',x.can_manage,'self',x.phone = s.phone,
        'roles', coalesce((select jsonb_agg(sr.role_id order by r.sort) from public.hanhala_staff_roles sr join public.hanhala_roles r on r.id = sr.role_id where sr.phone = x.phone), '[]'::jsonb))
        order by x.name), '[]'::jsonb) from public.hanhala_staff x),
    'roles', (select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'label',r.label,'tools',to_jsonb(r.tools),'layers',to_jsonb(r.layers),
        'holders', coalesce((select jsonb_agg(x.name order by x.name) from public.hanhala_staff_roles sr join public.hanhala_staff x on x.phone = sr.phone where sr.role_id = r.id), '[]'::jsonb))
        order by r.sort), '[]'::jsonb) from public.hanhala_roles r));
end $$;

drop function if exists public.hanhala_admin_save_staff(text, jsonb);
create function public.hanhala_admin_save_staff(p_phone text, p jsonb)
returns void language plpgsql security definer set search_path to '' as $$
declare s public.hanhala_staff := public._hanhala_manager(p_phone);
  ph text := public.milui_norm(p->>'phone'); old text := nullif(public.milui_norm(p->>'old_phone'),'');
  nm text := btrim(coalesce(p->>'name','')); mg boolean := coalesce((p->>'can_manage')::boolean, false);
  rl text[] := array(select distinct jsonb_array_elements_text(coalesce(p->'roles','[]'::jsonb)));
begin
  if ph !~ '^0\d{8,9}$' then raise exception 'bad_phone'; end if;
  if nm = '' or length(nm) > 60 then raise exception 'bad_name'; end if;
  if cardinality(rl) = 0 then raise exception 'no_roles'; end if;
  if exists (select 1 from unnest(rl) x where not exists (select 1 from public.hanhala_roles r where r.id = x)) then raise exception 'bad_role'; end if;
  if ph is distinct from old and exists (select 1 from public.hanhala_staff where phone = ph) then raise exception 'phone_exists'; end if;
  if coalesce(old, ph) = s.phone then mg := true; end if;  -- מנהל הרשאות לא מבטל לעצמו את הניהול
  if old is not null then
    update public.hanhala_staff set phone = ph, name = nm, can_manage = mg, updated_at = now(), updated_by = s.name where phone = old;
    if not found then raise exception 'not_found'; end if;
  else
    insert into public.hanhala_staff(phone,name,can_manage,updated_by) values (ph,nm,mg,s.name);
  end if;
  delete from public.hanhala_staff_roles where phone = ph and role_id <> all(rl);
  insert into public.hanhala_staff_roles(phone, role_id) select ph, x from unnest(rl) x on conflict do nothing;
end $$;

drop function if exists public.hanhala_admin_save_role(text, jsonb);
create function public.hanhala_admin_save_role(p_phone text, p jsonb)
returns text language plpgsql security definer set search_path to '' as $$
declare s public.hanhala_staff := public._hanhala_manager(p_phone);
  rid text := nullif(p->>'id',''); lb text := btrim(coalesce(p->>'label',''));
  tl text[] := array(select distinct jsonb_array_elements_text(coalesce(p->'tools','[]'::jsonb)));
  ly text[] := array(select l from (select distinct jsonb_array_elements_text(coalesce(p->'layers','[]'::jsonb)) l) z order by strpos('אבגדהו', l));
begin
  if lb = '' or length(lb) > 40 then raise exception 'bad_label'; end if;
  if not tl <@ array['milui','toranut','sayarot','mapat','hespek'] then raise exception 'bad_tools'; end if;
  if not ly <@ array['א','ב','ג','ד','ה','ו'] then raise exception 'bad_layers'; end if;
  if rid is null then
    rid := 'r' || substr(md5(random()::text || clock_timestamp()::text), 1, 8);
    insert into public.hanhala_roles(id,label,tools,layers,sort)
      values (rid, lb, tl, ly, (select coalesce(max(sort) filter (where sort < 900), 0) + 10 from public.hanhala_roles));
  else
    update public.hanhala_roles set label = lb, tools = tl, layers = ly where id = rid;
    if not found then raise exception 'not_found'; end if;
  end if;
  return rid;
end $$;

create or replace function public.hanhala_admin_delete_role(p_phone text, p_id text)
returns void language plpgsql security definer set search_path to '' as $$
declare s public.hanhala_staff := public._hanhala_manager(p_phone);
begin
  if exists (select 1 from public.hanhala_staff_roles where role_id = p_id) then raise exception 'role_in_use'; end if;
  delete from public.hanhala_roles where id = p_id;
end $$;

revoke all on function public._hanhala_payload(public.hanhala_staff) from public, anon, authenticated;
revoke all on function public.hanhala_admin_save_staff(text,jsonb), public.hanhala_admin_save_role(text,jsonb) from public;
grant execute on function public.hanhala_admin_save_staff(text,jsonb), public.hanhala_admin_save_role(text,jsonb) to anon, authenticated;
