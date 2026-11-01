-- מתכנן הספק · כנפי רוח · Supabase schema
-- Access model: the site holds only the public anon key. Tables are locked (RLS on, no policies);
-- everything goes through SECURITY DEFINER functions that check the school code.
--   staff code  -> view all plans, create plans, edit/delete only plans saved from the same device (owner secret)
--   admin code  -> everything staff can do + edit any plan + manage school days off / events

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.app_config (
  id int primary key default 1 check (id = 1),
  staff_code_hash text not null,
  admin_code_hash text not null
);

create table if not exists public.plans (
  id text primary key,                    -- one row per teacher device ("owner")
  owner_key_hash text not null,
  data jsonb not null,                    -- {teacher, updatedAt, plans:{planId:{...}}}
  teacher text,
  updated_at timestamptz not null default now()
);

create table if not exists public.school_settings (
  id int primary key default 1 check (id = 1),
  holidays jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);
insert into public.school_settings (id) values (1) on conflict do nothing;

alter table public.app_config enable row level security;
alter table public.plans enable row level security;
alter table public.school_settings enable row level security;
revoke all on public.app_config, public.plans, public.school_settings from anon, authenticated;

-- role for a code: 'admin' | 'staff' | null
create or replace function public._role(code text) returns text
language sql stable security definer set search_path = public, extensions as $$
  select case
    when code is null or length(code) < 4 then null
    when extensions.crypt(code, admin_code_hash) = admin_code_hash then 'admin'
    when extensions.crypt(code, staff_code_hash) = staff_code_hash then 'staff'
  end from public.app_config where id = 1
$$;
revoke all on function public._role(text) from public, anon, authenticated;

create or replace function public.check_code(code text) returns text
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform pg_sleep(0.3);  -- slows down guessing
  return public._role(code);
end $$;

create or replace function public.list_plans(code text) returns jsonb
language plpgsql stable security definer set search_path = public, extensions as $$
begin
  if public._role(code) is null then raise exception 'bad_code'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', id, 'data', data, 'updated_at', updated_at) order by updated_at desc) from public.plans), '[]'::jsonb);
end $$;

create or replace function public.save_plans(code text, owner_id text, owner_key text, payload jsonb) returns timestamptz
language plpgsql security definer set search_path = public, extensions as $$
declare r text := public._role(code); h text; t timestamptz := now();
begin
  if r is null then raise exception 'bad_code'; end if;
  if owner_id !~ '^[A-Za-z0-9_-]{8,64}$' or length(coalesce(owner_key,'')) < 16 then raise exception 'bad_owner'; end if;
  if length(payload::text) > 400000 then raise exception 'too_large'; end if;
  select owner_key_hash into h from public.plans where id = owner_id;
  if h is null then
    insert into public.plans (id, owner_key_hash, data, teacher, updated_at)
    values (owner_id, extensions.crypt(owner_key, extensions.gen_salt('bf')), payload, payload->>'teacher', t);
  else
    if r <> 'admin' and extensions.crypt(owner_key, h) <> h then raise exception 'not_owner'; end if;
    update public.plans set data = payload, teacher = payload->>'teacher', updated_at = t where id = owner_id;
  end if;
  return t;
end $$;

create or replace function public.get_settings(code text) returns jsonb
language plpgsql stable security definer set search_path = public, extensions as $$
begin
  if public._role(code) is null then raise exception 'bad_code'; end if;
  return (select jsonb_build_object('holidays', holidays, 'updated_at', updated_at) from public.school_settings where id = 1);
end $$;

create or replace function public.save_settings(code text, holidays jsonb) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  if public._role(code) is distinct from 'admin' then raise exception 'not_admin'; end if;
  if jsonb_typeof(holidays) <> 'array' or length(holidays::text) > 50000 then raise exception 'bad_payload'; end if;
  update public.school_settings set holidays = save_settings.holidays, updated_at = now() where id = 1;
end $$;

grant execute on function public.check_code(text), public.list_plans(text), public.save_plans(text,text,text,jsonb),
  public.get_settings(text), public.save_settings(text,jsonb) to anon, authenticated;

-- set / change the codes (run once, replace the two values):
-- insert into public.app_config (id, staff_code_hash, admin_code_hash)
-- values (1, extensions.crypt('STAFF-CODE', extensions.gen_salt('bf')), extensions.crypt('ADMIN-CODE', extensions.gen_salt('bf')))
-- on conflict (id) do update set staff_code_hash = excluded.staff_code_hash, admin_code_hash = excluded.admin_code_hash;
