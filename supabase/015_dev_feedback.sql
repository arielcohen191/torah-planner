-- משוב למפתח (מיגרציה "dev_feedback"): כפתור "משוב" בכל כלי באתר שולח לכאן,
-- ואריאל (תפקיד "מנהל מערכת") רואה ומטפל בלוח ההנהלה, במסך "משובים".
create table if not exists public.dev_feedback(
  id bigserial primary key,
  created_at timestamptz not null default now(),
  name text not null,
  phone text,
  tool text not null,
  kind text not null check (kind in ('bug','idea','question')),
  body text not null,
  page text,
  ua text,
  status text not null default 'new' check (status in ('new','doing','done')),
  updated_at timestamptz);
alter table public.dev_feedback enable row level security;
revoke all on public.dev_feedback from anon, authenticated;

-- שליחה: פתוח לכל מי שבאתר (גם כלים בלי כניסה), עם הגבלת אורך וקצב
create or replace function public.feedback_send(p jsonb)
returns bigint language plpgsql security definer set search_path to '' as $$
declare nm text := btrim(coalesce(p->>'name','')); bd text := btrim(coalesce(p->>'body',''));
  ph text := nullif(public.milui_norm(p->>'phone'),''); tl text := left(coalesce(nullif(p->>'tool',''),'אחר'),40);
  kd text := coalesce(p->>'kind','bug'); nid bigint;
begin
  if nm = '' or length(nm) > 60 then raise exception 'bad_name'; end if;
  if bd = '' or length(bd) > 2000 then raise exception 'bad_body'; end if;
  if kd not in ('bug','idea','question') then raise exception 'bad_kind'; end if;
  if ph is not null and ph !~ '^0\d{8,9}$' then ph := null; end if;
  if (select count(*) from public.dev_feedback where created_at > now() - interval '10 minutes') >= 30 then raise exception 'rate'; end if;
  insert into public.dev_feedback(name,phone,tool,kind,body,page,ua)
    values (nm, ph, tl, kd, bd, left(p->>'page',300), left(p->>'ua',300)) returning id into nid;
  return nid;
end $$;

create or replace function public._hanhala_dev(p_phone text)
returns public.hanhala_staff language plpgsql stable security definer set search_path to '' as $$
declare s public.hanhala_staff := public._hanhala_me(p_phone);
begin
  if not exists (select 1 from public.hanhala_staff_roles where phone = s.phone and role_id = 'sysadmin') then raise exception 'forbidden'; end if;
  return s;
end $$;

create or replace function public.hanhala_feedback_list(p_phone text)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare s public.hanhala_staff := public._hanhala_dev(p_phone);
begin
  return coalesce((select jsonb_agg(to_jsonb(f) - 'ua' order by f.created_at desc) from (select * from public.dev_feedback order by created_at desc limit 300) f), '[]'::jsonb);
end $$;

create or replace function public.hanhala_feedback_set(p_phone text, p_id bigint, p_status text)
returns void language plpgsql security definer set search_path to '' as $$
declare s public.hanhala_staff := public._hanhala_dev(p_phone);
begin
  if p_status not in ('new','doing','done') then raise exception 'bad_status'; end if;
  update public.dev_feedback set status = p_status, updated_at = now() where id = p_id;
end $$;

-- מספר המשובים הפתוחים, ללוח של מנהל המערכת בלבד
create or replace function public.hanhala_feedback_open(p_phone text)
returns int language plpgsql stable security definer set search_path to '' as $$
declare s public.hanhala_staff := public._hanhala_dev(p_phone);
begin return (select count(*) from public.dev_feedback where status = 'new'); end $$;

revoke all on function public._hanhala_dev(text) from public, anon, authenticated;
revoke all on function public.feedback_send(jsonb), public.hanhala_feedback_list(text), public.hanhala_feedback_set(text,bigint,text), public.hanhala_feedback_open(text) from public;
grant execute on function public.feedback_send(jsonb), public.hanhala_feedback_list(text), public.hanhala_feedback_set(text,bigint,text), public.hanhala_feedback_open(text) to anon, authenticated;
