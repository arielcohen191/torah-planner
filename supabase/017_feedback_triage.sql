-- (מיגרציה "feedback_triage") דירוג דחיפות והערת מפתח לכל משוב, לדוח המשובים שאריאל מוריד ממסך "משובים".
-- urgency: 1 דחוף · 2 חשוב · 3 יכול לחכות · null עוד לא דורג
alter table public.dev_feedback add column if not exists urgency smallint check (urgency between 1 and 3);
alter table public.dev_feedback add column if not exists dev_note text;

create or replace function public.hanhala_feedback_rank(p_phone text, p_id bigint, p_urgency int, p_note text)
returns void language plpgsql security definer set search_path to '' as $$
declare s public.hanhala_staff := public._hanhala_dev(p_phone);
begin
  if p_urgency is not null and p_urgency not between 1 and 3 then raise exception 'bad_urgency'; end if;
  update public.dev_feedback set urgency = p_urgency, dev_note = nullif(left(btrim(coalesce(p_note,'')),1000),''), updated_at = now() where id = p_id;
end $$;

revoke all on function public.hanhala_feedback_rank(text,bigint,int,text) from public;
grant execute on function public.hanhala_feedback_rank(text,bigint,int,text) to anon, authenticated;
