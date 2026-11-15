-- 030: "בנעליים של" בכל הכלים (מנהל המערכת בלבד), עד יציאה יזומה.
-- בכלים שנכנסים אליהם עם טלפון בלבד (הלוח, מילוי מקום, תורנויות) המצב מנוהל בדפדפן (as/as.js).
-- במפת כיתה הכניסה מוגנת בקוד אישי, ולכן כאן: מנהל המערכת מזדהה בקוד שלו ומקבל אסימון זמני לצפייה כאיש צוות אחר.
-- צפייה בלבד נאכפת בשרת: כל כתיבה לטבלאות מפת הכיתה נחסמת כשהכניסה היא באסימון.

create table if not exists public.mk_as_tokens(
  token text primary key,
  dev_phone text not null,
  target_phone text not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null);
alter table public.mk_as_tokens enable row level security;
revoke all on public.mk_as_tokens from anon, authenticated;

create or replace function public.mk_as_start(p_phone text, p_pin text, p_target text) returns jsonb
language plpgsql security definer set search_path to 'public' as $function$
declare a public.mk_access := public._mk_auth(p_phone, p_pin); tg text := public._mk_phone(p_target); t public.mk_access; tok text;
begin
  if a.phone is null then return jsonb_build_object('error', a.name); end if;
  if not exists (select 1 from public.hanhala_staff_roles where phone = public.milui_norm(a.phone) and role_id = 'sysadmin') then
    return jsonb_build_object('error', 'forbidden'); end if;
  select * into t from public.mk_access where phone = tg;
  if t.phone is null then return jsonb_build_object('error', 'no_target'); end if;
  delete from public.mk_as_tokens where dev_phone = a.phone or expires_at < now();
  tok := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  insert into public.mk_as_tokens(token, dev_phone, target_phone, expires_at) values (tok, a.phone, tg, now() + interval '30 days');
  return jsonb_build_object('token', tok, 'name', t.name);
end $function$;

create or replace function public.mk_as_stop(p_token text) returns void
language sql security definer set search_path to 'public' as $$
  delete from public.mk_as_tokens where token = p_token $$;

revoke all on function public.mk_as_start(text,text,text), public.mk_as_stop(text) from public;
grant execute on function public.mk_as_start(text,text,text), public.mk_as_stop(text) to anon, authenticated;

-- כניסה באסימון: נקרא מהגרסה החיה של _mk_auth ומוסיף רק את הענף הזה בתחילתה (לא דורס שינויים אחרים)
do $$ declare d text; a text := E'begin\n  select * into a from public.mk_access where phone = ph;'; begin
  d := pg_get_functiondef('public._mk_auth(text,text)'::regprocedure);
  if d not like '%kr-as:%' then
    if position(a in d) = 0 then raise exception 'patch failed'; end if;
    d := replace(d, a, E'begin\n  if left(coalesce(p_pin,\'\'), 6) = \'kr-as:\' then\n'
      || E'    select m.* into a from public.mk_as_tokens t join public.mk_access m on m.phone = t.target_phone\n'
      || E'      where t.token = substr(p_pin, 7) and t.target_phone = ph and t.expires_at > now();\n'
      || E'    if a.phone is null then e.name := \'bad\'; return e; end if;\n'
      || E'    perform set_config(\'kr.view_as\', \'1\', true);\n'
      || E'    return a;\n'
      || E'  end if;\n'
      || E'  select * into a from public.mk_access where phone = ph;');
    execute d;
  end if;
end $$;

-- צפייה בלבד: בכניסה באסימון אין כתיבה לטבלאות מפת הכיתה
create or replace function public._mk_view_only() returns trigger language plpgsql set search_path to '' as $$
begin
  if current_setting('kr.view_as', true) = '1' then raise exception 'view_only'; end if;
  return coalesce(new, old);
end $$;
do $$ declare t text; begin
  foreach t in array array['mk_access','mk_staff_q','mk_shiluv_pick','mk_reading','mk_settings','mk_class_data'] loop
    execute format('drop trigger if exists mk_view_only on public.%I', t);
    execute format('create trigger mk_view_only before insert or update or delete on public.%I for each row execute function public._mk_view_only()', t);
  end loop;
end $$;
