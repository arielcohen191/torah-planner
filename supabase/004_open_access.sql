-- Open access (shared-file model): _role() always returns 'admin', app_config dropped.
create or replace function public._role(code text) returns text
language sql stable security definer set search_path = public, extensions as $$ select 'admin'::text $$;
drop table if exists public.app_config;
