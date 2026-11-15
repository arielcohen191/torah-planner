-- 029: כלי המשימות · שלב 2 — משימות עם שותפים + דוח "משימות הצוות" להנהלה
-- (אפיון: claude/כלי-משימות-אפיון.md). נבנה על 028.
-- * יוצר המשימה מצרף אנשי צוות. כל שותף מסמן "בוצע" על החלק שלו ויכול להוסיף הערה. היוצר רואה מי עשה מה.
-- * משימה עם שותפים נחשבת בוצעה כשהיוצר סגר אותה, או כשכל השותפים סימנו בוצע.
-- * דוח להנהלה (כלי 'tasks' במסך ההרשאות): רק משימות עם שותפים. משימות אישיות נשארות פרטיות.
-- * אנשי הצוות מזוהים בצד הלקוח במפתח אקראי (לא בטלפון, שהוא אמצעי הכניסה).

create table if not exists public.staff_task_people(
  task_id bigint not null references public.staff_tasks(id) on delete cascade,
  phone text not null,
  name text,
  added_at timestamptz not null default now(),
  done_at timestamptz,
  note text check (length(note) <= 1000),
  note_at timestamptz,
  primary key (task_id, phone));
create index if not exists staff_task_people_phone on public.staff_task_people(phone);

create table if not exists public.staff_task_keys(
  phone text primary key,
  k text not null unique default 'p' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 16));

alter table public.staff_task_people enable row level security;
alter table public.staff_task_keys enable row level security;
revoke all on public.staff_task_people, public.staff_task_keys from anon, authenticated;

-- כל מי שיכול להיכנס ללוח: אנשי ההנהלה + מורים פעילים עם טלפון
create or replace function public._tasks_people() returns table(phone text, name text, k text)
language sql stable security definer set search_path to '' as $$
  select z.phone, z.name, y.k from (
    select h.phone, h.name from public.hanhala_staff h
    union all
    select q.phone, q.name from (
      select distinct on (public.milui_norm(t.phone)) public.milui_norm(t.phone) phone, t.name
      from public.milui_teachers t where t.active and public.milui_norm(t.phone) <> ''
      order by public.milui_norm(t.phone), t.id) q
    where not exists (select 1 from public.hanhala_staff h where h.phone = q.phone)) z
  join public.staff_task_keys y on y.phone = z.phone $$;

-- השכבות של איש צוות: מהתפקידים שלו ומהכיתות שהוא מלמד (לסינון הדוח לפי בית)
create or replace function public._tasks_layers(p text) returns text[]
language sql stable security definer set search_path to '' as $$
  select coalesce(array_agg(distinct l), '{}') from (
    select unnest(r.layers) l from public.hanhala_staff_roles x join public.hanhala_roles r on r.id = x.role_id where x.phone = p
    union all
    select left(btrim(c), 1) from public.milui_teachers t join public.milui_slots s on s.teacher_id = t.id, unnest(s.classes) c
      where t.active and public.milui_norm(t.phone) = p) z
  where l = any(array['א','ב','ג','ד','ה','ו']) $$;

-- הקשר המשתמש: האם רואה את דוח הצוות, ובאילו שכבות ({} = כל בית הספר)
create or replace function public._tasks_ctx(p_phone text) returns jsonb
language plpgsql stable security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); has boolean; allly boolean; ly text[]; pr boolean;
begin
  select count(*) > 0, coalesce(bool_or(cardinality(r.layers) = 0), false) into has, allly
    from public.hanhala_staff_roles x join public.hanhala_roles r on r.id = x.role_id
    where x.phone = s.phone and 'tasks' = any(r.tools);
  ly := array(select distinct l from public.hanhala_staff_roles x join public.hanhala_roles r on r.id = x.role_id, unnest(r.layers) l
    where x.phone = s.phone and 'tasks' = any(r.tools));
  pr := exists (select 1 from public.hanhala_staff_roles where phone = s.phone and role_id = 'principal');
  return jsonb_build_object('phone', s.phone, 'name', s.name, 'rep', pr or has,
    'layers', case when pr or allly then '[]'::jsonb else to_jsonb(coalesce(ly, '{}')) end);
end $function$;

-- המשימות שלי: שפתחתי + שצורפתי אליהן. פתוחות, ומבוצעות מ־60 הימים האחרונים.
drop function if exists public.tasks_list(text);
create function public.tasks_list(p_phone text) returns jsonb
language plpgsql security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone);
begin
  insert into public.staff_task_keys(phone)
    select h.phone from public.hanhala_staff h
    union select public.milui_norm(t.phone) from public.milui_teachers t where t.active and public.milui_norm(t.phone) <> ''
    on conflict do nothing;
  return jsonb_build_object('name', s.name,
    'report', (public._tasks_ctx(p_phone)->>'rep')::boolean,
    'people', (select coalesce(jsonb_agg(jsonb_build_object('k', p.k, 'name', p.name) order by p.name), '[]'::jsonb)
      from public._tasks_people() p where p.phone <> s.phone),
    'tasks', (select coalesce(jsonb_agg(z.j order by z.due nulls last, z.id), '[]'::jsonb) from (
      select t.id, t.due, jsonb_build_object('id', t.id, 'title', t.title, 'due', t.due, 'note', t.note, 'created_at', t.created_at,
          'mine', t.owner = s.phone, 'by', t.owner_name, 'closed', t.done_at is not null,
          'done_at', e.eff, 'my_note', me.note,
          'partners', (select coalesce(jsonb_agg(jsonb_build_object('k', k.k, 'name', coalesce(k.name, x.name), 'done_at', x.done_at)
                || case when t.owner = s.phone then jsonb_build_object('note', x.note) else '{}'::jsonb end order by x.added_at, x.name), '[]'::jsonb)
              from public.staff_task_people x left join public._tasks_people() k on k.phone = x.phone where x.task_id = t.id)) j
      from public.staff_tasks t
      left join public.staff_task_people me on me.task_id = t.id and me.phone = s.phone
      cross join lateral (select count(*) n, count(x.done_at) nd, max(x.done_at) last from public.staff_task_people x where x.task_id = t.id) a
      cross join lateral (select case when t.owner = s.phone then coalesce(t.done_at, case when a.n > 0 and a.n = a.nd then a.last end)
                                      else coalesce(me.done_at, t.done_at) end eff) e
      where (t.owner = s.phone or me.phone is not null) and (e.eff is null or e.eff > now() - interval '60 days')) z));
end $function$;

-- חדשה או עדכון (רק היוצר). partners = מפתחות של אנשי הצוות המצורפים; אם לא נשלח, השותפים לא משתנים.
create or replace function public.tasks_save(p_phone text, p jsonb) returns bigint
language plpgsql security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone);
  tl text := btrim(coalesce(p->>'title', '')); nt text := nullif(btrim(coalesce(p->>'note', '')), '');
  d date := nullif(p->>'due', '')::date; tid bigint := nullif(p->>'id', '')::bigint; ks text[]; ph text[];
begin
  if tl = '' or length(tl) > 200 then raise exception 'bad_title'; end if;
  if length(nt) > 2000 then raise exception 'bad_note'; end if;
  if d is not null and (d < current_date - 366 or d > current_date + 800) then raise exception 'bad_due'; end if;
  if p ? 'partners' then
    ks := array(select distinct x from jsonb_array_elements_text(coalesce(p->'partners', '[]'::jsonb)) x);
    if cardinality(ks) > 80 then raise exception 'too_many_partners'; end if;
    ph := array(select q.phone from public._tasks_people() q where q.k = any(ks) and q.phone <> s.phone);
    if cardinality(ph) <> (select count(*) from unnest(ks) x where x <> coalesce((select k from public.staff_task_keys where phone = s.phone), '')) then
      raise exception 'bad_partner'; end if;
  end if;
  if tid is null then
    if (select count(*) from public.staff_tasks where owner = s.phone and done_at is null) >= 300 then raise exception 'too_many'; end if;
    insert into public.staff_tasks(owner, owner_name, title, due, note) values (s.phone, s.name, tl, d, nt) returning id into tid;
  else
    update public.staff_tasks set title = tl, due = d, note = nt, updated_at = now() where id = tid and owner = s.phone;
    if not found then raise exception 'not_found'; end if;
  end if;
  if ph is not null then
    delete from public.staff_task_people where task_id = tid and not phone = any(ph);
    insert into public.staff_task_people(task_id, phone, name)
      select tid, q.phone, q.name from public._tasks_people() q where q.phone = any(ph)
      on conflict do nothing;
  end if;
  return tid;
end $function$;

-- היוצר סוגר/פותח את המשימה כולה; שותף מסמן את החלק שלו
create or replace function public.tasks_done(p_phone text, p_id bigint, p_done boolean) returns void
language plpgsql security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone);
begin
  update public.staff_tasks set done_at = case when p_done then coalesce(done_at, now()) end,
      done_by = case when p_done then s.name end, updated_at = now()
    where id = p_id and owner = s.phone;
  if found then
    -- פתיחה מחדש של משימה שכל השותפים כבר ביצעו: אין מה לפתוח בלי לשנות את הסימון שלהם
    return;
  end if;
  update public.staff_task_people set done_at = case when p_done then coalesce(done_at, now()) end
    where task_id = p_id and phone = s.phone;
  if not found then raise exception 'not_found'; end if;
end $function$;

-- הערה של שותף על החלק שלו
create or replace function public.tasks_note(p_phone text, p_id bigint, p_note text) returns void
language plpgsql security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone); nt text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if length(nt) > 1000 then raise exception 'bad_note'; end if;
  update public.staff_task_people set note = nt, note_at = case when nt is null then null else now() end
    where task_id = p_id and phone = s.phone;
  if not found then raise exception 'not_found'; end if;
end $function$;

-- דוח "משימות הצוות": רק משימות עם שותפים. פתוחות, ומבוצעות מ־30 הימים האחרונים.
create or replace function public.tasks_report(p_phone text) returns jsonb
language plpgsql stable security definer set search_path to '' as $function$
declare c jsonb := public._tasks_ctx(p_phone); vly text[];
begin
  if not (c->>'rep')::boolean then raise exception 'forbidden'; end if;
  vly := array(select jsonb_array_elements_text(c->'layers'));
  return jsonb_build_object('layers', c->'layers', 'tasks', (
    with pl as (select q.phone, public._tasks_layers(q.phone) ly from (
        select owner phone from public.staff_tasks union select phone from public.staff_task_people) q)
    select coalesce(jsonb_agg(z.j order by z.due nulls last, z.id), '[]'::jsonb) from (
      select t.id, t.due, jsonb_build_object('id', t.id, 'title', t.title, 'due', t.due, 'note', t.note, 'by', t.owner_name,
          'created_at', t.created_at, 'done_at', e.eff, 'ly', to_jsonb(g.ly),
          'partners', (select jsonb_agg(jsonb_build_object('name', x.name, 'done_at', x.done_at, 'note', x.note,
                'ly', to_jsonb(coalesce((select pl.ly from pl where pl.phone = x.phone), '{}'))) order by x.added_at, x.name)
              from public.staff_task_people x where x.task_id = t.id)) j
      from public.staff_tasks t
      cross join lateral (select count(*) n, count(x.done_at) nd, max(x.done_at) last from public.staff_task_people x where x.task_id = t.id) a
      cross join lateral (select coalesce(t.done_at, case when a.n = a.nd then a.last end) eff) e
      cross join lateral (select coalesce(array_agg(distinct l), '{}') ly from pl, unnest(pl.ly) l
          where pl.phone = t.owner or pl.phone in (select x.phone from public.staff_task_people x where x.task_id = t.id)) g
      where a.n > 0 and (e.eff is null or e.eff > now() - interval '30 days')
        and (cardinality(vly) = 0 or g.ly && vly)) z));
end $function$;

revoke all on function public._tasks_people(), public._tasks_layers(text), public._tasks_ctx(text) from public, anon, authenticated;
revoke all on function public.tasks_list(text), public.tasks_note(text,bigint,text), public.tasks_report(text) from public;
grant execute on function public.tasks_list(text), public.tasks_save(text,jsonb), public.tasks_done(text,bigint,boolean),
  public.tasks_delete(text,bigint), public.tasks_note(text,bigint,text), public.tasks_report(text) to anon, authenticated;

-- 'tasks' מותר בהגדרת תפקידים: נקרא מהגרסה החיה ומוסיף רק את הכלי למערך (לא דורס שינויים של שיחות אחרות)
do $$ declare d text; begin
  d := pg_get_functiondef('public.hanhala_admin_save_role(text,jsonb)'::regprocedure);
  if d not like '%''tasks''%' then
    d := regexp_replace(d, $x$(not tl <@ array\[[^\]]*)\]$x$, $x$\1,'tasks']$x$);
    if d not like '%''tasks''%' then raise exception 'patch failed'; end if;
    execute d;
  end if;
end $$;

-- ברירת מחדל: רק המנהל רואה את דוח הצוות. לשאר התפקידים פותחים במסך ההרשאות.
update public.hanhala_roles set tools = array_append(tools, 'tasks'), levels = levels || jsonb_build_object('tasks', 'admin')
  where id = 'principal' and not 'tasks' = any(tools);
