-- תורנויות חצר: מצב אחד משותף (אנשי צוות, הגדרות, שיבוץ) + מערכת השעות מטבלאות מילוי מקום
create table if not exists public.toranut_state (
  id int primary key default 1 check (id = 1),
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by text
);
alter table public.toranut_state enable row level security;
-- אין policies: גישה רק דרך הפונקציות (אותה כניסה בטלפון כמו מילוי מקום)

create or replace function public.toranut_load(p_phone text)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare me text := public.milui_who(p_phone); tt jsonb; st public.toranut_state;
begin
  with g as (
    select t.id, d.day, string_agg(coalesce((select case s.kind when 'שיעור' then 'L' when 'שיעור משותף' then 'L'
        when 'פרטני' then 'P' when 'שהייה' then 'S' when 'תפקיד' then 'T' when 'חלון' then 'C' else '?' end
        from public.milui_slots s where s.teacher_id=t.id and s.day=d.day and s.hour=h.h limit 1),'.'),'' order by h.h) prof
    from public.milui_teachers t cross join generate_series(0,5) d(day) cross join generate_series(1,8) h(h)
    where not t.is_external group by t.id, d.day),
  lay as (
    select teacher_id, string_agg(l,'' order by n desc) layers
    from (select teacher_id, left(c,1) l, count(*) n from public.milui_slots, unnest(classes) c group by 1,2) x group by 1)
  select coalesce(jsonb_object_agg(t.name, jsonb_build_object('id',t.id,
           'p',(select jsonb_agg(prof order by day) from g where g.id=t.id),'l',coalesce(lay.layers,''))),'{}')
    into tt
  from public.milui_teachers t left join lay on lay.teacher_id=t.id where not t.is_external;
  select * into st from public.toranut_state where id=1;
  return jsonb_build_object('me',me,'tt',tt,'data',coalesce(st.data,'{}'::jsonb),'updated_at',st.updated_at,'updated_by',st.updated_by);
end $$;

create or replace function public.toranut_save(p_phone text, p_data jsonb, p_expect timestamptz)
returns timestamptz language plpgsql security definer set search_path to '' as $$
declare me text := public.milui_who(p_phone); cur timestamptz; nt timestamptz := now();
begin
  select updated_at into cur from public.toranut_state where id=1 for update;
  if cur is not null and p_expect is not null and cur > p_expect + interval '1 second' then
    raise exception 'conflict';
  end if;
  insert into public.toranut_state(id,data,updated_at,updated_by) values (1,p_data,nt,me)
  on conflict (id) do update set data=excluded.data, updated_at=nt, updated_by=me;
  return nt;
end $$;

revoke all on function public.toranut_load(text) from public;
revoke all on function public.toranut_save(text, jsonb, timestamptz) from public;
grant execute on function public.toranut_load(text) to anon, authenticated;
grant execute on function public.toranut_save(text, jsonb, timestamptz) to anon, authenticated;
