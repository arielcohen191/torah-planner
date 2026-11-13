-- (מיגרציה "feedback_size") גודל העבודה לכל משוב: 1 קטן · 2 בינוני · 3 פרויקט. בדוח: בתוך כל דחיפות, הקטנים קודם.
alter table public.dev_feedback add column if not exists size smallint check (size between 1 and 3);

drop function if exists public.hanhala_feedback_rank(text,bigint,int,text);
create or replace function public.hanhala_feedback_rank(p_phone text, p_id bigint, p_urgency int, p_note text, p_size int default null)
returns void language plpgsql security definer set search_path to '' as $$
declare s public.hanhala_staff := public._hanhala_dev(p_phone);
begin
  if p_urgency is not null and p_urgency not between 1 and 3 then raise exception 'bad_urgency'; end if;
  if p_size is not null and p_size not between 1 and 3 then raise exception 'bad_size'; end if;
  update public.dev_feedback set urgency = p_urgency, size = p_size, dev_note = nullif(left(btrim(coalesce(p_note,'')),1000),''), updated_at = now() where id = p_id;
end $$;

revoke all on function public.hanhala_feedback_rank(text,bigint,int,text,int) from public;
grant execute on function public.hanhala_feedback_rank(text,bigint,int,text,int) to anon, authenticated;
