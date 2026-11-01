-- staff see full data only for plans saved from their own device; others are reduced to teacher/grade/subject/book
drop function if exists public.list_plans(text);
create or replace function public.list_plans(code text, owner_id text default null, owner_key text default null) returns jsonb
language plpgsql stable security definer set search_path = public, extensions as $$
declare r text := public._role(code);
begin
  if r is null then raise exception 'bad_code'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'updated_at', p.updated_at, 'data',
      case when r = 'admin' or (p.id = owner_id and owner_key is not null and extensions.crypt(owner_key, p.owner_key_hash) = p.owner_key_hash)
        then p.data
        else jsonb_build_object('teacher', p.data->'teacher', 'plans',
          coalesce((select jsonb_object_agg(k, jsonb_build_object('teacher', v->'teacher', 'grade', v->'grade', 'cls', v->'cls', 'subject', v->'subject', 'book', v->'book'))
                    from jsonb_each(coalesce(p.data->'plans','{}'::jsonb)) as e(k, v)), '{}'::jsonb))
      end) order by p.updated_at desc) from public.plans p), '[]'::jsonb);
end $$;
revoke all on function public.list_plans(text,text,text) from public;
grant execute on function public.list_plans(text,text,text) to anon, authenticated;
