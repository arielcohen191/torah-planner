-- (מיגרציה "shiluv") כלי השילוב: תלמידים ומה שמגיע להם, מטפלים ומורי שילוב, חדרים, שיבוץ מענים ודיווח "התקיים".
-- המידע רגיש, ולכן:
--   * הכניסה בטלפון + קוד אישי (אותו קוד של מפת הכיתה, _mk_auth, כולל נעילה אחרי 5 ניסיונות).
--   * מי נכנס: צוות השילוב (mk_access.shiluv), ובעלי תפקיד שהכלי 'shiluv' פתוח לתפקיד שלהם בלוח ההנהלה
--     (מנהל, מנהל מערכת, סגניות, מנהלות בתים, רכזת שילוב). מנהלת בית רואה ועורכת רק את התלמידים של הבית שלה.
--   * כל הטבלאות סגורות (RLS בלי מדיניות), הגישה רק דרך הפונקציות כאן.
--   * הנתונים עצמם (שמות תלמידים וכו') לא נמצאים בריפו — הם נטענו ישירות למסד.
--   * במצב "בנעליים של" (אסימון kr-as) — צפייה בלבד, כל שמירה נחסמת בשרת.

create table if not exists public.sh_students(
  id bigserial primary key,
  name text not null,
  cls text not null default '',
  freq text not null default '',            -- שכיחות: נמוכה / גבוהה / רפואי
  pulse text not null default 'ראשונה',     -- פעימה
  aide text not null default '',            -- סיוע (מלל חופשי, כמו בגיליון)
  needs jsonb not null default '{}'::jsonb, -- שעות שבועיות שפולחו לפי סוג מענה: {"h":2,"r":1,...}
  tags text[] not null default '{}',        -- אפיונים
  active boolean not null default true,
  updated_at timestamptz not null default now(), updated_by text);

create table if not exists public.sh_rooms(
  id text primary key, name text not null, bld text not null default '', use text not null default '', sort int not null default 0);

create table if not exists public.sh_providers(
  id text primary key,
  name text not null,
  type text not null,                       -- r רגשי · s מיומנויות · b ניתוח התנהגות · k כלבנות · h הוראה מותאמת · t קל"ת · g נגרות וחקלאות · m שעת מחנך
  role_label text not null default '',
  cap numeric not null default 0, ind int not null default 0,
  days int[] not null default '{}',         -- 0=ראשון
  room text references public.sh_rooms(id) on delete set null,
  note text not null default '',
  absence jsonb,                            -- {"from":"2026-11-01","to":"2027-02-28","reason":"חופשת לידה","sub":"שם המחליף/ה"}
  active boolean not null default true, sort int not null default 0,
  updated_at timestamptz not null default now(), updated_by text);

create table if not exists public.sh_fixed(
  id bigserial primary key, room text not null references public.sh_rooms(id) on delete cascade,
  days int[] not null, hours int[] not null, label text not null);

create table if not exists public.sh_sessions(
  id bigserial primary key,
  provider text not null references public.sh_providers(id) on delete cascade,
  day int check (day between 0 and 5), hour int check (hour between 1 and 8),
  mode text not null default 'פרטני', label text not null default '',
  room text references public.sh_rooms(id) on delete set null,
  students bigint[] not null default '{}',
  updated_at timestamptz not null default now(), updated_by text);

create table if not exists public.sh_att(
  session_id bigint not null references public.sh_sessions(id) on delete cascade,
  week date not null, held boolean not null,
  updated_at timestamptz not null default now(), updated_by text,
  primary key (session_id, week));

alter table public.sh_students enable row level security;
alter table public.sh_rooms enable row level security;
alter table public.sh_providers enable row level security;
alter table public.sh_fixed enable row level security;
alter table public.sh_sessions enable row level security;
alter table public.sh_att enable row level security;
revoke all on public.sh_students, public.sh_rooms, public.sh_providers, public.sh_fixed, public.sh_sessions, public.sh_att from anon, authenticated;

-- הכלי בלוח ההנהלה: פתוח לתפקידים האלה, ובמצב פיילוט (נפתח לאנשים אחד אחד)
update public.hanhala_roles set tools = array_append(tools, 'shiluv'),
  levels = levels || jsonb_build_object('shiluv', case when id in ('principal','sysadmin','shiluv') then 'admin' else 'edit' end)
  where id in ('principal','sysadmin','deputy1','deputy2','house_ab','house_gd','house_hv','shiluv') and not ('shiluv' = any(tools));
insert into public.hanhala_tool_launch(tool, mode) values ('shiluv','pilot') on conflict (tool) do nothing;

-- מי אני ומה מותר לי. מחזיר: name, phone, layers (ריק = כל בית הספר), ro (צפייה בלבד)
create or replace function public._sh_auth(p_phone text, p_pin text)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare a public.mk_access := public._mk_auth(p_phone, p_pin); via_role boolean; all_layers boolean; lay text[];
begin
  if a.phone is null then return jsonb_build_object('error', coalesce(a.name,'bad')); end if;
  if 'shiluv' = any(public._hanhala_hidden(a.phone)) then return jsonb_build_object('error','forbidden'); end if;
  select count(*) > 0, bool_or(coalesce(array_length(r.layers,1),0) = 0),
         array(select distinct l from public.hanhala_staff_roles x2 join public.hanhala_roles r2 on r2.id = x2.role_id, unnest(r2.layers) l
               where x2.phone = a.phone and 'shiluv' = any(r2.tools))
    into via_role, all_layers, lay
    from public.hanhala_staff_roles x join public.hanhala_roles r on r.id = x.role_id
    where x.phone = a.phone and 'shiluv' = any(r.tools);
  if not via_role and not coalesce(a.shiluv,false) then return jsonb_build_object('error','forbidden'); end if;
  if coalesce(a.shiluv,false) or all_layers then lay := '{}'; end if;
  return jsonb_build_object('name', a.name, 'phone', a.phone, 'layers', to_jsonb(coalesce(lay,'{}'::text[])),
    'ro', coalesce(current_setting('kr.view_as', true),'') = '1');
end $$;

create or replace function public._sh_layer(p_cls text) returns text language sql immutable set search_path to '' as $$
  select substr(regexp_replace(coalesce(p_cls,''),'[^א-ת]','','g'),1,1) $$;

-- מזהי התלמידים שהמשתמש רואה
create or replace function public._sh_visible(u jsonb) returns bigint[] language sql stable security definer set search_path to 'public' as $$
  select coalesce(array_agg(s.id), '{}') from public.sh_students s
  where jsonb_array_length(u->'layers') = 0 or public._sh_layer(s.cls) in (select jsonb_array_elements_text(u->'layers')) $$;

create or replace function public._sh_w(u jsonb) returns void language plpgsql as $$
begin
  if u ? 'error' then raise exception '%', u->>'error'; end if;
  if (u->>'ro')::boolean then raise exception 'view_only'; end if;
end $$;

create or replace function public.sh_login(p_phone text, p_pin text)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
begin return public._sh_auth(p_phone, p_pin); end $$;

create or replace function public.sh_get(p_phone text, p_pin text)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare u jsonb := public._sh_auth(p_phone, p_pin); vis bigint[];
begin
  if u ? 'error' then return u; end if;
  vis := public._sh_visible(u);
  return jsonb_build_object('me', u,
    'students', (select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'cls',s.cls,'freq',s.freq,'pulse',s.pulse,'aide',s.aide,
        'needs',s.needs,'tags',to_jsonb(s.tags)) order by s.cls, s.name), '[]'::jsonb) from public.sh_students s where s.active and s.id = any(vis)),
    'providers', (select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'type',p.type,'role',p.role_label,'cap',p.cap,'ind',p.ind,
        'days',to_jsonb(p.days),'room',p.room,'note',p.note,'absence',p.absence) order by p.sort, p.name), '[]'::jsonb) from public.sh_providers p where p.active),
    'rooms', (select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'name',r.name,'bld',r.bld,'use',r.use) order by r.sort), '[]'::jsonb) from public.sh_rooms r),
    'fixed', (select coalesce(jsonb_agg(jsonb_build_object('id',f.id,'room',f.room,'days',to_jsonb(f.days),'hours',to_jsonb(f.hours),'label',f.label)), '[]'::jsonb) from public.sh_fixed f),
    -- מענים: תלמידים שהמשתמש לא רואה לא נשלחים (רק כמה כאלה יש), כדי שמשבצת תפוסה עדיין תיראה תפוסה
    'sessions', (select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'t',x.provider,'d',x.day,'h',x.hour,'mode',x.mode,'label',x.label,'room',x.room,
        'stu', to_jsonb(array(select i from unnest(x.students) i where i = any(vis))),
        'hidden', (select count(*) from unnest(x.students) i where not (i = any(vis))),
        'att', (select coalesce(jsonb_object_agg(a.week, a.held), '{}'::jsonb) from public.sh_att a where a.session_id = x.id))), '[]'::jsonb)
      from public.sh_sessions x join public.sh_providers p on p.id = x.provider and p.active));
end $$;

create or replace function public.sh_save_student(p_phone text, p_pin text, p jsonb)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare u jsonb := public._sh_auth(p_phone, p_pin); nid bigint := nullif(p->>'id','')::bigint; v_cls text := left(btrim(coalesce(p->>'cls','')),10);
begin
  perform public._sh_w(u);
  if btrim(coalesce(p->>'name','')) = '' or jsonb_typeof(coalesce(p->'needs','{}')) <> 'object' then raise exception 'bad_input'; end if;
  if jsonb_array_length(u->'layers') > 0 and (public._sh_layer(v_cls) not in (select jsonb_array_elements_text(u->'layers'))
      or (nid is not null and not nid = any(public._sh_visible(u)))) then raise exception 'forbidden'; end if;
  if nid is null then
    insert into public.sh_students(name, cls, freq, pulse, aide, needs, tags, updated_by)
    values (left(btrim(p->>'name'),60), v_cls, left(coalesce(p->>'freq',''),20), left(coalesce(p->>'pulse','ראשונה'),20), left(coalesce(p->>'aide',''),80),
      coalesce(p->'needs','{}'), array(select left(x,40) from jsonb_array_elements_text(coalesce(p->'tags','[]')) x limit 12), u->>'name') returning id into nid;
  else
    update public.sh_students set name = left(btrim(p->>'name'),60), cls = v_cls, freq = left(coalesce(p->>'freq',''),20), pulse = left(coalesce(p->>'pulse','ראשונה'),20),
      aide = left(coalesce(p->>'aide',''),80), needs = coalesce(p->'needs','{}'),
      tags = array(select left(x,40) from jsonb_array_elements_text(coalesce(p->'tags','[]')) x limit 12),
      active = coalesce((p->>'active')::boolean, true), updated_at = now(), updated_by = u->>'name'
    where id = nid;
  end if;
  return jsonb_build_object('ok', true, 'id', nid);
end $$;

create or replace function public.sh_save_session(p_phone text, p_pin text, p jsonb)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare u jsonb := public._sh_auth(p_phone, p_pin); vis bigint[]; sid bigint := nullif(p->>'id','')::bigint;
  want bigint[]; keep bigint[] := '{}'; d int := nullif(p->>'d','')::int; h int := nullif(p->>'h','')::int; rm text := nullif(p->>'room','');
begin
  perform public._sh_w(u);
  vis := public._sh_visible(u);
  if not exists (select 1 from public.sh_providers where id = p->>'t') then raise exception 'bad_input'; end if;
  want := array(select x::bigint from jsonb_array_elements_text(coalesce(p->'stu','[]')) x where x::bigint = any(vis) limit 40);
  if d is null then h := null; elsif h is null then h := 1; end if;
  if sid is not null then
    select array(select i from unnest(s.students) i where not (i = any(vis))) into keep from public.sh_sessions s where s.id = sid;  -- תלמידים שהמשתמש לא רואה נשארים
    update public.sh_sessions set provider = p->>'t', day = d, hour = h, mode = left(coalesce(p->>'mode','פרטני'),20), label = left(coalesce(p->>'label',''),60),
      room = rm, students = coalesce(keep,'{}') || want, updated_at = now(), updated_by = u->>'name' where id = sid;
  else
    insert into public.sh_sessions(provider, day, hour, mode, label, room, students, updated_by)
    values (p->>'t', d, h, left(coalesce(p->>'mode','פרטני'),20), left(coalesce(p->>'label',''),60), rm, want, u->>'name') returning id into sid;
  end if;
  return jsonb_build_object('ok', true, 'id', sid);
end $$;

create or replace function public.sh_delete_session(p_phone text, p_pin text, p_id bigint)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare u jsonb := public._sh_auth(p_phone, p_pin);
begin
  perform public._sh_w(u);
  if exists (select 1 from public.sh_sessions s, unnest(s.students) i where s.id = p_id and not (i = any(public._sh_visible(u)))) then raise exception 'forbidden'; end if;
  delete from public.sh_sessions where id = p_id;
  return jsonb_build_object('ok', true);
end $$;

-- דיווח "התקיים": p_held = true / false / null (מחיקת הדיווח)
create or replace function public.sh_set_att(p_phone text, p_pin text, p_id bigint, p_week date, p_held boolean)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare u jsonb := public._sh_auth(p_phone, p_pin);
begin
  perform public._sh_w(u);
  if extract(dow from p_week) <> 0 or p_week > current_date + 7 then raise exception 'bad_input'; end if;
  if p_held is null then delete from public.sh_att where session_id = p_id and week = p_week;
  else insert into public.sh_att(session_id, week, held, updated_by) values (p_id, p_week, p_held, u->>'name')
    on conflict (session_id, week) do update set held = excluded.held, updated_at = now(), updated_by = excluded.updated_by; end if;
  return jsonb_build_object('ok', true);
end $$;

-- מטפל/ת: עריכת פרטים והיעדרות ממושכת
create or replace function public.sh_save_provider(p_phone text, p_pin text, p jsonb)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare u jsonb := public._sh_auth(p_phone, p_pin); pid text := nullif(p->>'id','');
begin
  perform public._sh_w(u);
  if btrim(coalesce(p->>'name','')) = '' or coalesce(p->>'type','') !~ '^[rsbkhtgm]$' then raise exception 'bad_input'; end if;
  if p->'absence' is not null and jsonb_typeof(p->'absence') not in ('object','null') then raise exception 'bad_input'; end if;
  if pid is null then pid := 'p' || substr(md5(random()::text),1,8); end if;
  insert into public.sh_providers(id, name, type, role_label, cap, ind, days, room, note, absence, updated_by)
  values (pid, left(btrim(p->>'name'),60), p->>'type', left(coalesce(p->>'role',''),40), coalesce((p->>'cap')::numeric,0), coalesce((p->>'ind')::int,0),
    array(select x::int from jsonb_array_elements_text(coalesce(p->'days','[]')) x where x::int between 0 and 5),
    nullif(p->>'room',''), left(coalesce(p->>'note',''),200), case when jsonb_typeof(p->'absence') = 'object' then p->'absence' end, u->>'name')
  on conflict (id) do update set name = excluded.name, type = excluded.type, role_label = excluded.role_label, cap = excluded.cap, ind = excluded.ind,
    days = excluded.days, room = excluded.room, note = excluded.note, absence = excluded.absence, updated_at = now(), updated_by = excluded.updated_by;
  return jsonb_build_object('ok', true, 'id', pid);
end $$;

revoke all on function public._sh_auth(text,text), public._sh_visible(jsonb), public._sh_w(jsonb) from public, anon, authenticated;
revoke all on function public.sh_login(text,text), public.sh_get(text,text), public.sh_save_student(text,text,jsonb), public.sh_save_session(text,text,jsonb),
  public.sh_delete_session(text,text,bigint), public.sh_set_att(text,text,bigint,date,boolean), public.sh_save_provider(text,text,jsonb) from public;
grant execute on function public.sh_login(text,text), public.sh_get(text,text), public.sh_save_student(text,text,jsonb), public.sh_save_session(text,text,jsonb),
  public.sh_delete_session(text,text,bigint), public.sh_set_att(text,text,bigint,date,boolean), public.sh_save_provider(text,text,jsonb) to anon, authenticated;
