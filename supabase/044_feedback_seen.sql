-- משוב: תשובת מפתח שלא נקראה קופצת לשולח פעם אחת. feedback_mine מחזיר id ו־seen לכל הודעה.
create or replace function public.feedback_mine(p jsonb) returns jsonb
language plpgsql stable security definer set search_path to '' as $function$
declare ph text := nullif(public.milui_norm(p->>'phone'),''); tk text := nullif(p->>'token','');
begin
  if ph is not null and ph !~ '^0\d{8,9}$' then ph := null; end if;
  if tk is not null and tk !~ '^[A-Za-z0-9_-]{16,64}$' then tk := null; end if;
  if ph is null and tk is null then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id',f.id,'created_at',f.created_at,'tool',f.tool,'kind',f.kind,'body',f.body,'status',f.status,
      'msgs',(select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'dev',m.by_dev,'name',m.name,'body',m.body,'at',m.created_at,'seen',m.seen_at is not null) order by m.created_at),'[]'::jsonb) from public.dev_feedback_msgs m where m.feedback_id = f.id)) order by f.created_at desc)
    from (select * from public.dev_feedback where (tk is not null and client_token = tk) or (ph is not null and phone = ph) order by created_at desc limit 50) f), '[]'::jsonb);
end $function$;

create or replace function public.feedback_seen(p jsonb) returns jsonb
language plpgsql security definer set search_path to '' as $function$
declare ph text := nullif(public.milui_norm(p->>'phone'),''); tk text := nullif(p->>'token',''); n int;
begin
  if ph is not null and ph !~ '^0\d{8,9}$' then ph := null; end if;
  if tk is not null and tk !~ '^[A-Za-z0-9_-]{16,64}$' then tk := null; end if;
  if ph is null and tk is null then return jsonb_build_object('n',0); end if;
  update public.dev_feedback_msgs m set seen_at = now()
    from public.dev_feedback f
    where f.id = m.feedback_id and m.by_dev and m.seen_at is null
      and ((tk is not null and f.client_token = tk) or (ph is not null and f.phone = ph))
      and m.id in (select (v #>> '{}')::bigint from jsonb_array_elements(coalesce(p->'ids','[]'::jsonb)) v);
  get diagnostics n = row_count;
  return jsonb_build_object('n', n);
end $function$;
grant execute on function public.feedback_seen(jsonb) to anon, authenticated;
update public.dev_feedback_msgs set seen_at = now() where by_dev and seen_at is null and created_at < now() - interval '14 days';
