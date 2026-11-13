-- (מיגרציה "feedback_sender_urgency") השולח מסמן בטופס המשוב כמה הפנייה דחופה בעיניו (1 דחוף · 2 חשוב · 3 יכול לחכות).
-- מוצג למפתח כ"דחיפות לפי השולח", לצד הדירוג שלו (urgency).
alter table public.dev_feedback add column if not exists sender_urgency smallint check (sender_urgency between 1 and 3);

create or replace function public.feedback_send(p jsonb)
returns bigint language plpgsql security definer set search_path to '' as $$
declare nm text := btrim(coalesce(p->>'name','')); bd text := btrim(coalesce(p->>'body',''));
  ph text := nullif(public.milui_norm(p->>'phone'),''); tl text := left(coalesce(nullif(p->>'tool',''),'אחר'),40);
  kd text := coalesce(p->>'kind','bug'); tk text := nullif(p->>'token','');
  su smallint := case when p->>'urgency' in ('1','2','3') then (p->>'urgency')::smallint end; nid bigint;
begin
  if nm = '' or length(nm) > 60 then raise exception 'bad_name'; end if;
  if bd = '' or length(bd) > 2000 then raise exception 'bad_body'; end if;
  if kd not in ('bug','idea','question') then raise exception 'bad_kind'; end if;
  if ph is not null and ph !~ '^0\d{8,9}$' then ph := null; end if;
  if tk is not null and tk !~ '^[A-Za-z0-9_-]{16,64}$' then tk := null; end if;
  if (select count(*) from public.dev_feedback where created_at > now() - interval '10 minutes') >= 30 then raise exception 'rate'; end if;
  insert into public.dev_feedback(name,phone,tool,kind,body,page,ua,client_token,sender_urgency)
    values (nm, ph, tl, kd, bd, left(p->>'page',300), left(p->>'ua',300), tk, su) returning id into nid;
  return nid;
end $$;
