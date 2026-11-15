-- 023: ישיבות פדגוגיות — מעקב החלטות (מסמך אפיון 1) ופגישות רכזת/יועצת עם מחנך (מסמך אפיון 2)
-- הכלי בלוח: 'ped'. גישה לפי תפקיד ושכבות (רמה: צפייה/עריכה/מנהל), והמחנך רואה את הכיתה שלו.
-- פגישות עם מחנכים (מדד אנרגיה, תמצית, הצפה): רק המנהל (תפקיד principal) ומי שמילא.

create table if not exists public.ped_decisions(
  id bigserial primary key,
  created_at timestamptz not null default now(),
  created_by text not null, created_name text,
  class_name text not null,
  nature text not null check (nature in ('לימודי','רגשי','התנהגותי','חברתי','אחר')),
  scope text not null check (scope in ('class','student')),
  students text[] not null default '{}',
  answer text not null check (length(answer) between 1 and 1000),
  owner text not null check (owner in ('מחנך','רכזת','יועצת','הנהלה','מורה מקצועי')),
  due date not null,
  status text not null default 'open' check (status in ('open','doing','done','cancel')),
  notes text check (length(notes) <= 2000),
  updated_at timestamptz, updated_by text);
create index if not exists ped_decisions_class on public.ped_decisions(class_name, status);

create table if not exists public.ped_meetings(
  id bigserial primary key,
  created_at timestamptz not null default now(),
  created_by text not null, created_name text,
  met_on date not null,
  teacher_id integer not null references public.milui_teachers(id),
  energy smallint not null check (energy between 1 and 4),
  reviewed boolean not null check (reviewed),
  summary text not null check (length(summary) between 1 and 400),
  escalate boolean not null default false,
  escalate_text text check (length(escalate_text) <= 1500),
  seen_at timestamptz);
create index if not exists ped_meetings_teacher on public.ped_meetings(teacher_id, met_on desc);

alter table public.ped_decisions enable row level security;
alter table public.ped_meetings enable row level security;
revoke all on public.ped_decisions, public.ped_meetings from anon, authenticated;

-- הקשר המשתמש: רמה בכלי (0 בלי, 1 צפייה, 2 עריכה, 3 מנהל), שכבות ({} = כל ביה"ס), מנהל, וכיתות חינוך
create or replace function public._ped_ctx(p_phone text) returns jsonb
language plpgsql stable security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); lvl int; ly text[]; allly boolean; pr boolean; tid int; hr text[];
begin
  select coalesce(max(case r.levels->>'ped' when 'admin' then 3 when 'edit' then 2 else 1 end), 0), bool_or(cardinality(r.layers) = 0)
    into lvl, allly
    from public.hanhala_staff_roles x join public.hanhala_roles r on r.id = x.role_id
    where x.phone = s.phone and 'ped' = any(r.tools);
  ly := array(select distinct l from public.hanhala_staff_roles x join public.hanhala_roles r on r.id = x.role_id, unnest(r.layers) l
    where x.phone = s.phone and 'ped' = any(r.tools));
  pr := exists (select 1 from public.hanhala_staff_roles where phone = s.phone and role_id = 'principal');
  select t.id into tid from public.milui_teachers t where t.active and public.milui_norm(t.phone) = s.phone limit 1;
  hr := array(select c.name from public.milui_classes c where tid is not null and c.homeroom_id = tid order by c.sort);
  return jsonb_build_object('phone', s.phone, 'name', s.name, 'lvl', case when pr then 3 else lvl end,
    'layers', case when pr or coalesce(allly, false) then '[]'::jsonb else to_jsonb(coalesce(ly, '{}')) end,
    'principal', pr, 'tid', tid, 'homeroom', to_jsonb(hr));
end $function$;

-- 0 = אין גישה לכיתה, 1 = צפייה והזנה, 2 = גם עדכון סטטוס
create or replace function public._ped_class(c jsonb, cls text) returns int
language sql immutable set search_path to '' as $$
  select case
    when (c->>'principal')::boolean then 2
    when c->'homeroom' ? cls then 2
    when (c->>'lvl')::int >= 1 and (jsonb_array_length(c->'layers') = 0 or c->'layers' ? left(cls, 1))
      then case when (c->>'lvl')::int >= 2 then 2 else 1 end
    else 0 end $$;

create or replace function public.ped_data(p_phone text) returns jsonb
language plpgsql stable security definer set search_path to '' as $function$
declare c jsonb := public._ped_ctx(p_phone); cls text[];
begin
  cls := array(select x.name from public.milui_classes x where public._ped_class(c, x.name) > 0 order by x.sort);
  return jsonb_build_object(
    'me', c - 'phone' || jsonb_build_object('can_meet', (c->>'principal')::boolean or (c->>'lvl')::int >= 2),
    'classes', to_jsonb(cls),
    -- שמות התלמידים מקובץ המיפוי (שורה שמתחילה במספר ואחריו שם), לבחירה במקום הקלדה
    'students', (select coalesce(jsonb_object_agg(d.class_name, (
        select coalesce(jsonb_agg(nm order by o), '[]'::jsonb) from (
          select min(r.o) o, x.nm from jsonb_array_elements(d.rows) with ordinality r(row, o),
            lateral (select case when r.row->>1 ~ '^\s*\d+\s*$' and btrim(coalesce(r.row->>2, '')) <> '' then btrim(r.row->>2)
                                 when r.row->>0 ~ '^\s*\d+\s*$' and btrim(coalesce(r.row->>1, '')) <> '' then btrim(r.row->>1) end nm) x
          where x.nm is not null group by x.nm) z)), '{}'::jsonb)
      from public.mk_class_data d where d.class_name = any(cls)),
    'decisions', (select coalesce(jsonb_agg(jsonb_build_object('id', d.id, 'created_at', d.created_at, 'by', d.created_name, 'class', d.class_name,
        'nature', d.nature, 'scope', d.scope, 'students', to_jsonb(d.students), 'answer', d.answer, 'owner', d.owner, 'due', d.due,
        'status', d.status, 'notes', d.notes, 'updated_at', d.updated_at, 'edit', public._ped_class(c, d.class_name) = 2) order by d.due, d.id), '[]'::jsonb)
      from public.ped_decisions d where d.class_name = any(cls) and (d.status in ('open','doing') or d.updated_at > now() - interval '120 days' or d.created_at > now() - interval '120 days')),
    'meetings', (select coalesce(jsonb_agg(jsonb_build_object('id', m.id, 'created_at', m.created_at, 'by', m.created_name, 'mine', m.created_by = c->>'phone',
        'met_on', m.met_on, 'teacher_id', m.teacher_id, 'teacher', t.name, 'energy', m.energy, 'summary', m.summary,
        'escalate', m.escalate, 'escalate_text', m.escalate_text, 'seen_at', m.seen_at) order by m.met_on desc, m.id desc), '[]'::jsonb)
      from public.ped_meetings m join public.milui_teachers t on t.id = m.teacher_id
      where (c->>'principal')::boolean or m.created_by = c->>'phone'),
    -- המחנכים (לבחירה בטופס הפגישה, ולתמונת המצב של המנהל)
    'homerooms', (select coalesce(jsonb_agg(jsonb_build_object('class', x.name, 'teacher_id', t.id, 'teacher', t.name) order by x.sort), '[]'::jsonb)
      from public.milui_classes x join public.milui_teachers t on t.id = x.homeroom_id
      where (c->>'principal')::boolean or ((c->>'lvl')::int >= 2 and public._ped_class(c, x.name) > 0)));
end $function$;

create or replace function public.ped_save_decision(p_phone text, p jsonb) returns bigint
language plpgsql security definer set search_path to '' as $function$
declare c jsonb := public._ped_ctx(p_phone); cl text := btrim(coalesce(p->>'class',''));
  st text[] := array(select btrim(x) from jsonb_array_elements_text(coalesce(p->'students','[]'::jsonb)) x where btrim(x) <> '');
  nid bigint;
begin
  if not exists (select 1 from public.milui_classes where name = cl) or public._ped_class(c, cl) = 0 then raise exception 'forbidden'; end if;
  if p->>'scope' = 'student' and cardinality(st) = 0 then raise exception 'students_required'; end if;
  if cardinality(st) > 40 or exists (select 1 from unnest(st) x where length(x) > 60) then raise exception 'bad_students'; end if;
  if (p->>'due')::date < current_date - 1 or (p->>'due')::date > current_date + 400 then raise exception 'bad_due'; end if;
  insert into public.ped_decisions(created_by, created_name, class_name, nature, scope, students, answer, owner, due)
    values (c->>'phone', c->>'name', cl, p->>'nature', p->>'scope', case when p->>'scope' = 'student' then st else '{}' end,
            btrim(p->>'answer'), p->>'owner', (p->>'due')::date)
    returning id into nid;
  return nid;
end $function$;

create or replace function public.ped_update_decision(p_phone text, p_id bigint, p jsonb) returns void
language plpgsql security definer set search_path to '' as $function$
declare c jsonb := public._ped_ctx(p_phone); d public.ped_decisions;
begin
  select * into d from public.ped_decisions where id = p_id;
  if d.id is null then raise exception 'not_found'; end if;
  if public._ped_class(c, d.class_name) < 2 then raise exception 'forbidden'; end if;
  if p ? 'delete' then
    if not ((c->>'principal')::boolean or (d.created_by = c->>'phone' and d.created_at > now() - interval '1 day')) then raise exception 'forbidden'; end if;
    delete from public.ped_decisions where id = p_id; return;
  end if;
  update public.ped_decisions set
    status = coalesce(p->>'status', status),
    notes = case when p ? 'notes' then nullif(btrim(p->>'notes'), '') else notes end,
    due = coalesce((p->>'due')::date, due),
    owner = coalesce(p->>'owner', owner),
    updated_at = now(), updated_by = c->>'name'
  where id = p_id;
end $function$;

create or replace function public.ped_save_meeting(p_phone text, p jsonb) returns bigint
language plpgsql security definer set search_path to '' as $function$
declare c jsonb := public._ped_ctx(p_phone); tid int := (p->>'teacher_id')::int; d date := coalesce((p->>'met_on')::date, current_date); nid bigint;
  esc boolean := coalesce((p->>'escalate')::boolean, false);
begin
  if not ((c->>'principal')::boolean or (c->>'lvl')::int >= 2) then raise exception 'forbidden'; end if;
  if not exists (select 1 from public.milui_teachers where id = tid and active) then raise exception 'not_found'; end if;
  if d > current_date or d < current_date - 60 then raise exception 'bad_date'; end if;
  if esc and btrim(coalesce(p->>'escalate_text','')) = '' then raise exception 'escalate_text_required'; end if;
  insert into public.ped_meetings(created_by, created_name, met_on, teacher_id, energy, reviewed, summary, escalate, escalate_text)
    values (c->>'phone', c->>'name', d, tid, (p->>'energy')::smallint, coalesce((p->>'reviewed')::boolean, false), btrim(p->>'summary'),
            esc, case when esc then btrim(p->>'escalate_text') end)
    returning id into nid;
  return nid;
end $function$;

create or replace function public.ped_meeting_seen(p_phone text, p_id bigint) returns void
language plpgsql security definer set search_path to '' as $function$
declare c jsonb := public._ped_ctx(p_phone);
begin
  if not (c->>'principal')::boolean then raise exception 'forbidden'; end if;
  update public.ped_meetings set seen_at = coalesce(seen_at, now()) where id = p_id;
end $function$;

revoke all on function public._ped_ctx(text), public._ped_class(jsonb,text) from public, anon, authenticated;
grant execute on function public.ped_data(text), public.ped_save_decision(text,jsonb), public.ped_update_decision(text,bigint,jsonb),
  public.ped_save_meeting(text,jsonb), public.ped_meeting_seen(text,bigint) to anon, authenticated;

-- 'ped' מותר בהגדרת תפקידים (נקרא מהגרסה החיה ומוחלף רק מערך הכלים)
do $$ declare d text; begin
  d := pg_get_functiondef('public.hanhala_admin_save_role(text,jsonb)'::regprocedure);
  d := replace(d, $x$array['milui','toranut','sayarot','mapat','hespek']$x$, $x$array['milui','toranut','sayarot','mapat','hespek','ped']$x$);
  if d not like '%''ped''%' then raise exception 'patch failed'; end if;
  execute d;
end $$;

-- ברירת מחדל: מנהל = מנהל; מנהלות בתים, רכזות שכבה, יועצות ורכזת פדגוגית = עריכה; סגניות = צפייה
update public.hanhala_roles set tools = array_append(tools, 'ped'),
  levels = levels || jsonb_build_object('ped', case when id = 'principal' then 'admin' when id in ('deputy1','deputy2') then 'view' else 'edit' end)
where id in ('principal','deputy1','deputy2','house_ab','house_gd','house_hv','layer_a','layer_b','layer_g','layer_d','layer_h','layer_v','counselor_abg','counselor_dhv','pedagogic')
  and not 'ped' = any(tools);
