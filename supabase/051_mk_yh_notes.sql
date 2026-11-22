-- 051: מסקנות מיום ההורים בכרטיס התלמיד במפת הכיתה
-- מחנך הכיתה וההנהלה רואים את כל ההערות של תלמידי הכיתה; מורה מקצועי רואה רק את ההערות מהפגישות שלו
create or replace function public.mk_yh_notes(p_phone text, p_pin text, p_class text)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $f$
declare a public.mk_access := public._mk_auth(p_phone, p_pin); ck text := public._mk_norm(p_class); lim boolean := false; tid int;
begin
  if a.phone is null then return jsonb_build_object('error', a.name); end if;
  if a.role = 'teacher' and public._mk_norm(a.class_name) <> ck then
    if not exists (select 1 from public._mk_teacher_classes(a.phone) tc where tc.class_key = ck) then return jsonb_build_object('error','forbidden'); end if;
    lim := true;
    select id into tid from public.milui_teachers where active and public.milui_norm(phone) = public.milui_norm(a.phone) order by id limit 1;
  end if;
  return jsonb_build_object('notes', coalesce((
    select jsonb_object_agg(stu, items) from (
      select b.student stu, jsonb_agg(jsonb_build_object('teacher', t.name, 'day', x.day, 't', to_char(x.t,'HH24:MI'), 'note', b.note) order by x.day, x.t) items
      from public.yh_bookings b join public.yh_slots x on x.id = b.slot_id join public.milui_teachers t on t.id = x.teacher_id
      where public._mk_norm(b.class_name) = ck and coalesce(btrim(b.note),'') <> '' and (not lim or x.teacher_id = tid)
      group by b.student) z), '{}'::jsonb));
end $f$;
grant execute on function public.mk_yh_notes(text, text, text) to anon, authenticated;
