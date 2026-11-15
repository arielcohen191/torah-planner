-- 028: כלי המשימות · שלב 1 — משימות אישיות (אפיון: claude/כלי-משימות-אפיון.md, משובים #4, #11)
-- כל איש צוות שנכנס ללוח (הנהלה או מורה פעיל) פותח משימות לעצמו: כותרת, תאריך יעד, הערה, וסימון "בוצע".
-- המשימה שייכת לטלפון של בעליה, ורק הוא רואה ומעדכן אותה. שלב 2 (שותפים) ושלב 3 (לוח אביים) ייבנו על אותה טבלה.
-- לא משנה שום פונקציה קיימת: רק קורא ל־_hanhala_me לזיהוי.

create table if not exists public.staff_tasks(
  id bigserial primary key,
  created_at timestamptz not null default now(),
  owner text not null,
  owner_name text,
  title text not null check (length(title) between 1 and 200),
  due date,
  note text check (length(note) <= 2000),
  done_at timestamptz,
  done_by text,
  updated_at timestamptz);
create index if not exists staff_tasks_owner on public.staff_tasks(owner, done_at);

alter table public.staff_tasks enable row level security;
revoke all on public.staff_tasks from anon, authenticated;

-- המשימות שלי: כל הפתוחות, והמבוצעות מ־60 הימים האחרונים
create or replace function public.tasks_list(p_phone text) returns jsonb
language plpgsql stable security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone);
begin
  return jsonb_build_object('name', s.name,
    'tasks', (select coalesce(jsonb_agg(jsonb_build_object('id', t.id, 'title', t.title, 'due', t.due, 'note', t.note,
        'done_at', t.done_at, 'created_at', t.created_at) order by t.due nulls last, t.id), '[]'::jsonb)
      from public.staff_tasks t where t.owner = s.phone and (t.done_at is null or t.done_at > now() - interval '60 days')));
end $function$;

-- חדשה (בלי id) או עדכון של משימה שלי
create or replace function public.tasks_save(p_phone text, p jsonb) returns bigint
language plpgsql security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone);
  tl text := btrim(coalesce(p->>'title', '')); nt text := nullif(btrim(coalesce(p->>'note', '')), '');
  d date := nullif(p->>'due', '')::date; tid bigint := nullif(p->>'id', '')::bigint;
begin
  if tl = '' or length(tl) > 200 then raise exception 'bad_title'; end if;
  if length(nt) > 2000 then raise exception 'bad_note'; end if;
  if d is not null and (d < current_date - 366 or d > current_date + 800) then raise exception 'bad_due'; end if;
  if tid is null then
    if (select count(*) from public.staff_tasks where owner = s.phone and done_at is null) >= 300 then raise exception 'too_many'; end if;
    insert into public.staff_tasks(owner, owner_name, title, due, note) values (s.phone, s.name, tl, d, nt) returning id into tid;
  else
    update public.staff_tasks set title = tl, due = d, note = nt, updated_at = now() where id = tid and owner = s.phone;
    if not found then raise exception 'not_found'; end if;
  end if;
  return tid;
end $function$;

create or replace function public.tasks_done(p_phone text, p_id bigint, p_done boolean) returns void
language plpgsql security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone);
begin
  update public.staff_tasks set done_at = case when p_done then coalesce(done_at, now()) end,
      done_by = case when p_done then s.name end, updated_at = now()
    where id = p_id and owner = s.phone;
  if not found then raise exception 'not_found'; end if;
end $function$;

create or replace function public.tasks_delete(p_phone text, p_id bigint) returns void
language plpgsql security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone);
begin
  delete from public.staff_tasks where id = p_id and owner = s.phone;
  if not found then raise exception 'not_found'; end if;
end $function$;

revoke all on function public.tasks_list(text), public.tasks_save(text,jsonb), public.tasks_done(text,bigint,boolean), public.tasks_delete(text,bigint) from public;
grant execute on function public.tasks_list(text), public.tasks_save(text,jsonb), public.tasks_done(text,bigint,boolean), public.tasks_delete(text,bigint) to anon, authenticated;
