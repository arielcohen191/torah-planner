-- תורנויות חצר: היסטוריית גרסאות — נשמרת אוטומטית בכל "הרצת שיבוץ" ולפני כל שחזור
create table if not exists public.toranut_versions (
  id bigserial primary key,
  created_at timestamptz not null default now(),
  created_by text,
  label text,
  stats jsonb,
  snap jsonb not null
);
alter table public.toranut_versions enable row level security;
create index if not exists toranut_versions_created_idx on public.toranut_versions (created_at desc);

create or replace function public.toranut_version_add(p_phone text, p_label text, p_stats jsonb, p_snap jsonb)
returns bigint language plpgsql security definer set search_path to '' as $$
declare me text := public.milui_who(p_phone); nid bigint;
begin
  insert into public.toranut_versions(created_by,label,stats,snap) values (me,p_label,p_stats,p_snap) returning id into nid;
  return nid;
end $$;

create or replace function public.toranut_versions_list(p_phone text)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare me text := public.milui_who(p_phone);
begin
  return coalesce((select jsonb_agg(jsonb_build_object('id',id,'at',created_at,'by',created_by,'label',label,'stats',stats) order by created_at desc)
    from (select * from public.toranut_versions order by created_at desc limit 300) v),'[]'::jsonb);
end $$;

create or replace function public.toranut_version_get(p_phone text, p_id bigint)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare me text := public.milui_who(p_phone);
begin
  return (select snap from public.toranut_versions where id=p_id);
end $$;

revoke all on function public.toranut_version_add(text,text,jsonb,jsonb) from public;
revoke all on function public.toranut_versions_list(text) from public;
revoke all on function public.toranut_version_get(text,bigint) from public;
grant execute on function public.toranut_version_add(text,text,jsonb,jsonb) to anon, authenticated;
grant execute on function public.toranut_versions_list(text) to anon, authenticated;
grant execute on function public.toranut_version_get(text,bigint) to anon, authenticated;
