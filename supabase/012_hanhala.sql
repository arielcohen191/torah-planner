-- לוח הנהלה (/hanhala): דף קריאה בלבד שמרכז את כל הכלים. הוחל ב-Supabase כמיגרציה "hanhala_summary".
-- כניסה: אותו טלפון כמו מילוי מקום (milui_admins, localStorage milui_phone).
-- הדף קורא RPC קיימים: milui_state, toranut_load, get_sayarot, list_plans, get_settings — ועוד אחד חדש:
--   hanhala_summary(p_phone) -> {me, mk:{classes_total, classes_synced[], staff_access, staff_entered, q_filled, q_last}}
--   מספרים בלבד ממפת הכיתה (בלי תוכן שאלונים ובלי נתוני תלמידים).
create or replace function public.hanhala_summary(p_phone text)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare me text := public.milui_who(p_phone);
begin
  return jsonb_build_object('me', me,
    'mk', jsonb_build_object(
      'classes_total', (select count(*) from public.milui_classes),
      'classes_synced', (select coalesce(jsonb_agg(jsonb_build_object('name', coalesce(c.class_name, c.class_key),
            'students', coalesce(jsonb_array_length(c.rows), 0), 'synced_at', c.synced_at) order by c.class_key), '[]'::jsonb)
          from public.mk_class_data c),
      'staff_access', (select count(*) from public.mk_access),
      'staff_entered', (select count(*) from public.mk_access where pin_hash is not null),
      'q_filled', (select count(*) from public.mk_staff_q),
      'q_last', (select max(updated_at) from public.mk_staff_q)));
end $$;
revoke all on function public.hanhala_summary(text) from public;
grant execute on function public.hanhala_summary(text) to anon, authenticated;
