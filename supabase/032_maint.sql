-- 032: לוח תחזוקה / אב הבית (כלי המשימות · שלב 3, משוב #11)
-- כל איש צוות מדווח על תקלה מהלוח ורואה את הסטטוס של הדיווחים שלו; יכול לסמן שטופל ולשלוח "תודה לאבים".
-- בעלי הרשאה לכלי 'maint' (מסך ההרשאות): צפייה = רואים את כל התקלות; עריכה/מנהל = מטפלים (סטטוס, הערה, דחיפות).
create table if not exists public.maint_tickets(
  id bigserial primary key,
  created_at timestamptz not null default now(),
  reporter text,
  reporter_name text not null,
  place text not null check (length(place) between 1 and 120),
  descr text not null check (length(descr) between 1 and 1500),
  urgency smallint not null default 2 check (urgency between 1 and 3),
  status text not null default 'open' check (status in ('open','doing','done')),
  status_at timestamptz,
  status_by text,
  note text check (length(note) <= 1500),
  thanked_at timestamptz,
  source text not null default 'app',
  ext_key text unique);
create index if not exists maint_tickets_status on public.maint_tickets(status, created_at);
create index if not exists maint_tickets_reporter on public.maint_tickets(reporter);
alter table public.maint_tickets enable row level security;
revoke all on public.maint_tickets from anon, authenticated;

-- רמה בכלי: 0 בלי (רואה רק את הדיווחים שלו), 1 צפייה בכל התקלות, 2 מטפל, 3 מנהל
create or replace function public._maint_lvl(p text) returns int
language sql stable security definer set search_path to '' as $$
  select greatest(
    coalesce((select max(case r.levels->>'maint' when 'admin' then 3 when 'edit' then 2 else 1 end)
      from public.hanhala_staff_roles x join public.hanhala_roles r on r.id = x.role_id where x.phone = p and 'maint' = any(r.tools)), 0),
    case when exists (select 1 from public.hanhala_staff_roles where phone = p and role_id = 'principal') then 3 else 0 end) $$;

create or replace function public.maint_list(p_phone text) returns jsonb
language plpgsql stable security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); lvl int := public._maint_lvl(s.phone);
begin
  return jsonb_build_object('me', jsonb_build_object('name', s.name, 'lvl', lvl),
    'tickets', (select coalesce(jsonb_agg(jsonb_build_object('id', t.id, 'created_at', t.created_at, 'by', t.reporter_name, 'place', t.place, 'descr', t.descr,
        'urgency', t.urgency, 'status', t.status, 'status_at', t.status_at, 'status_by', t.status_by, 'note', t.note,
        'thanked_at', t.thanked_at, 'mine', t.reporter = s.phone, 'source', t.source) order by t.created_at desc, t.id desc), '[]'::jsonb)
      from public.maint_tickets t
      where (lvl >= 1 or t.reporter = s.phone) and (t.status <> 'done' or t.status_at > now() - interval '60 days')));
end $function$;

create or replace function public.maint_report(p_phone text, p jsonb) returns bigint
language plpgsql security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); pl text := btrim(coalesce(p->>'place', '')); ds text := btrim(coalesce(p->>'descr', ''));
  ug smallint := coalesce(nullif(p->>'urgency', '')::smallint, 2); nid bigint;
begin
  if pl = '' or length(pl) > 120 then raise exception 'bad_place'; end if;
  if ds = '' or length(ds) > 1500 then raise exception 'bad_descr'; end if;
  if ug not in (1,2,3) then raise exception 'bad_urgency'; end if;
  if (select count(*) from public.maint_tickets where reporter = s.phone and status <> 'done') >= 40 then raise exception 'too_many'; end if;
  insert into public.maint_tickets(reporter, reporter_name, place, descr, urgency) values (s.phone, s.name, pl, ds, ug) returning id into nid;
  return nid;
end $function$;

-- מטפל (רמה 2+): סטטוס, הערה, דחיפות. המדווח עצמו: סטטוס בלבד, ומחיקה של דיווח שעוד לא התחילו לטפל בו.
create or replace function public.maint_update(p_phone text, p_id bigint, p jsonb) returns void
language plpgsql security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); lvl int := public._maint_lvl(s.phone); t public.maint_tickets; st text := p->>'status';
begin
  select * into t from public.maint_tickets where id = p_id;
  if t.id is null then raise exception 'not_found'; end if;
  if lvl < 2 and t.reporter is distinct from s.phone then raise exception 'forbidden'; end if;
  if st is not null and st not in ('open','doing','done') then raise exception 'bad_status'; end if;
  if p ? 'delete' then
    if not (lvl >= 3 or (t.reporter = s.phone and t.status = 'open')) then raise exception 'forbidden'; end if;
    delete from public.maint_tickets where id = p_id; return;
  end if;
  if lvl >= 2 then
    if p ? 'urgency' and (p->>'urgency')::smallint not in (1,2,3) then raise exception 'bad_urgency'; end if;
    if length(p->>'note') > 1500 then raise exception 'bad_note'; end if;
    update public.maint_tickets set
      status = coalesce(st, status),
      status_at = case when st is not null and st <> status then now() else status_at end,
      status_by = case when st is not null and st <> status then s.name else status_by end,
      thanked_at = case when st is not null and st <> 'done' then null else thanked_at end,
      note = case when p ? 'note' then nullif(btrim(p->>'note'), '') else note end,
      urgency = coalesce((p->>'urgency')::smallint, urgency)
    where id = p_id;
  elsif st is not null and st <> t.status then
    update public.maint_tickets set status = st, status_at = now(), status_by = s.name,
      thanked_at = case when st <> 'done' then null else thanked_at end where id = p_id;
  end if;
end $function$;

-- "תודה לאבים": המדווח, אחרי שהתקלה טופלה
create or replace function public.maint_thanks(p_phone text, p_id bigint) returns void
language plpgsql security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone);
begin
  update public.maint_tickets set thanked_at = coalesce(thanked_at, now()) where id = p_id and reporter = s.phone and status = 'done';
  if not found then raise exception 'not_found'; end if;
end $function$;

revoke all on function public._maint_lvl(text) from public, anon, authenticated;
revoke all on function public.maint_list(text), public.maint_report(text,jsonb), public.maint_update(text,bigint,jsonb), public.maint_thanks(text,bigint) from public;
grant execute on function public.maint_list(text), public.maint_report(text,jsonb), public.maint_update(text,bigint,jsonb), public.maint_thanks(text,bigint) to anon, authenticated;

-- 'maint' מותר בהגדרת תפקידים (על בסיס הגרסה החיה)
do $$ declare d text; begin
  d := pg_get_functiondef('public.hanhala_admin_save_role(text,jsonb)'::regprocedure);
  if d not like '%''maint''%' then
    d := regexp_replace(d, $x$(not tl <@ array\[[^\]]*)\]$x$, $x$\1,'maint']$x$);
    if d not like '%''maint''%' then raise exception 'patch failed'; end if;
    execute d;
  end if;
end $$;

-- תפקיד "אב בית" (מטפל), והמנהל כמנהל הכלי
insert into public.hanhala_roles(id, label, tools, levels, layers, sort)
  select 'av_bayit', 'אב בית', array['maint'], '{"maint":"edit"}'::jsonb, '{}', (select coalesce(max(sort) filter (where sort < 900), 0) + 10 from public.hanhala_roles)
  where not exists (select 1 from public.hanhala_roles where id = 'av_bayit');
update public.hanhala_roles set tools = array_append(tools, 'maint'), levels = levels || jsonb_build_object('maint', 'admin')
  where id = 'principal' and not 'maint' = any(tools);
