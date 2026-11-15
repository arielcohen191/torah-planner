-- 034: תקלות ותחזוקה — צירוף תמונה לדיווח (כמו בטופס הגוגל של אב הבית). התמונה מוקטנת בדפדפן ונשמרת בטבלה סגורה,
-- ונטענת רק כשפותחים אותה (המדווח, אב הבית ובעלי הרשאת צפייה). הפונקציות מתעדכנות על בסיס הגרסה החיה.
create table if not exists public.maint_shot(
  ticket_id bigint primary key references public.maint_tickets(id) on delete cascade,
  data text not null check (data like 'data:image/jpeg;base64,%' and length(data) <= 400000),
  created_at timestamptz not null default now());
alter table public.maint_shot enable row level security;
revoke all on public.maint_shot from anon, authenticated;

create or replace function public.maint_photo(p_phone text, p_id bigint) returns text
language plpgsql stable security definer set search_path to '' as $function$
declare s public.hanhala_staff := public._hanhala_me(p_phone);
begin
  if not exists (select 1 from public.maint_tickets t where t.id = p_id and (t.reporter = s.phone or public._maint_lvl(s.phone) >= 1)) then raise exception 'forbidden'; end if;
  return (select h.data from public.maint_shot h where h.ticket_id = p_id);
end $function$;
revoke all on function public.maint_photo(text,bigint) from public;
grant execute on function public.maint_photo(text,bigint) to anon, authenticated;

do $$ declare d text; a1 text := E'nid bigint;\nbegin'; a2 text := 'returning id into nid;'; a3 text := $x$'mine', t.reporter = s.phone, 'source', t.source)$x$; begin
  d := pg_get_functiondef('public.maint_report(text,jsonb)'::regprocedure);
  if d not like '%bad_photo%' then
    if position(a1 in d) = 0 or position(a2 in d) = 0 then raise exception 'patch failed: maint_report'; end if;
    d := replace(d, a1, E'nid bigint; ph text := nullif(p->>\'photo\', \'\');\nbegin\n  if ph is not null and (ph not like \'data:image/jpeg;base64,%\' or length(ph) > 400000) then raise exception \'bad_photo\'; end if;');
    d := replace(d, a2, E'returning id into nid;\n  if ph is not null then insert into public.maint_shot(ticket_id, data) values (nid, ph); end if;');
    execute d;
  end if;
  d := pg_get_functiondef('public.maint_list(text)'::regprocedure);
  if d not like '%has_photo%' then
    if position(a3 in d) = 0 then raise exception 'patch failed: maint_list'; end if;
    execute replace(d, a3, $x$'mine', t.reporter = s.phone, 'source', t.source, 'has_photo', exists (select 1 from public.maint_shot h where h.ticket_id = t.id))$x$);
  end if;
end $$;
