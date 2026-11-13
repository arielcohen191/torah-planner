-- (מיגרציה "feedback_mine") "הפניות שלי": כל משתמש רואה בכפתור המשוב את הפניות הקודמות ששלח ואת הסטטוס שלהן.
-- זיהוי: מזהה מכשיר אקראי (client_token) שנשמר עם כל משוב, או מספר הטלפון שהשולח מילא.
alter table public.dev_feedback add column if not exists client_token text;
create index if not exists dev_feedback_token_idx on public.dev_feedback(client_token);
create index if not exists dev_feedback_phone_idx on public.dev_feedback(phone);

create or replace function public.feedback_send(p jsonb)
returns bigint language plpgsql security definer set search_path to '' as $$
declare nm text := btrim(coalesce(p->>'name','')); bd text := btrim(coalesce(p->>'body',''));
  ph text := nullif(public.milui_norm(p->>'phone'),''); tl text := left(coalesce(nullif(p->>'tool',''),'אחר'),40);
  kd text := coalesce(p->>'kind','bug'); tk text := nullif(p->>'token',''); nid bigint;
begin
  if nm = '' or length(nm) > 60 then raise exception 'bad_name'; end if;
  if bd = '' or length(bd) > 2000 then raise exception 'bad_body'; end if;
  if kd not in ('bug','idea','question') then raise exception 'bad_kind'; end if;
  if ph is not null and ph !~ '^0\d{8,9}$' then ph := null; end if;
  if tk is not null and tk !~ '^[A-Za-z0-9_-]{16,64}$' then tk := null; end if;
  if (select count(*) from public.dev_feedback where created_at > now() - interval '10 minutes') >= 30 then raise exception 'rate'; end if;
  insert into public.dev_feedback(name,phone,tool,kind,body,page,ua,client_token)
    values (nm, ph, tl, kd, bd, left(p->>'page',300), left(p->>'ua',300), tk) returning id into nid;
  return nid;
end $$;

create or replace function public.feedback_mine(p jsonb)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare ph text := nullif(public.milui_norm(p->>'phone'),''); tk text := nullif(p->>'token','');
begin
  if ph is not null and ph !~ '^0\d{8,9}$' then ph := null; end if;
  if tk is not null and tk !~ '^[A-Za-z0-9_-]{16,64}$' then tk := null; end if;
  if ph is null and tk is null then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id',f.id,'created_at',f.created_at,'tool',f.tool,'kind',f.kind,'body',f.body,'status',f.status) order by f.created_at desc)
    from (select * from public.dev_feedback where (tk is not null and client_token = tk) or (ph is not null and phone = ph) order by created_at desc limit 50) f), '[]'::jsonb);
end $$;

revoke all on function public.feedback_mine(jsonb) from public;
grant execute on function public.feedback_mine(jsonb) to anon, authenticated;
