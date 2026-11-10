-- תורנויות חצר: toranut_load מחזיר גם 'c' — לכל יום מחרוזת של 8 תווים: אות השכבה של הכיתה שהמורה מלמד בכל שעה ('.' = אין)
-- משמש לשיבוץ בהפסקה ליד הכיתה שהמורה לימד לפניה או ילמד אחריה
create or replace function public.toranut_load(p_phone text)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare me text := public.milui_who(p_phone); tt jsonb; st public.toranut_state; ab jsonb; ph jsonb;
begin
  with g as (
    select t.id, d.day,
      string_agg(coalesce((select case s.kind when 'שיעור' then 'L' when 'שיעור משותף' then 'L'
        when 'פרטני' then 'P' when 'שהייה' then 'S' when 'תפקיד' then 'T' when 'חלון' then 'C' else '?' end
        from public.milui_slots s where s.teacher_id=t.id and s.day=d.day and s.hour=h.h limit 1),'.'),'' order by h.h) prof,
      string_agg(coalesce((select left(s.classes[1],1)
        from public.milui_slots s where s.teacher_id=t.id and s.day=d.day and s.hour=h.h and cardinality(s.classes)>0 limit 1),'.'),'' order by h.h) cls
    from public.milui_teachers t cross join generate_series(0,5) d(day) cross join generate_series(1,8) h(h)
    where not t.is_external and t.active group by t.id, d.day),
  lay as (
    select teacher_id, string_agg(l,'' order by n desc) layers
    from (select teacher_id, left(c,1) l, count(*) n from public.milui_slots, unnest(classes) c group by 1,2) x group by 1)
  select coalesce(jsonb_object_agg(t.name, jsonb_build_object('id',t.id,
           'p',(select jsonb_agg(prof order by day) from g where g.id=t.id),
           'c',(select jsonb_agg(cls order by day) from g where g.id=t.id),
           'l',coalesce(lay.layers,''))),'{}')
    into tt
  from public.milui_teachers t left join lay on lay.teacher_id=t.id where not t.is_external and t.active;

  select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'name',t.name,'from',a.date_from,'to',a.date_to) order by a.date_from),'[]')
    into ab
  from public.milui_absences a join public.milui_teachers t on t.id=a.teacher_id
  where a.hours is null and (a.date_to is null or (a.date_to >= current_date - 1 and a.date_to > a.date_from));

  select coalesce(jsonb_object_agg(name, phone),'{}') into ph from public.milui_teachers where phone is not null and phone<>'';

  select * into st from public.toranut_state where id=1;
  return jsonb_build_object('me',me,'tt',tt,'absences',ab,'phones',ph,'data',coalesce(st.data,'{}'::jsonb),'updated_at',st.updated_at,'updated_by',st.updated_by);
end $$;
