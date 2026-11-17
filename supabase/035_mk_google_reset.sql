-- 035: מפת כיתה — איפוס סיסמה עצמי בהזדהות עם חשבון גוגל (החלטת אריאל, 17.11).
-- איש הצוות נכנס עם גוגל (Supabase Auth), והשרת מתאים את המייל המאומת של חשבון הגוגל למייל הרשום שלו:
-- קודם המייל הארגוני; מייל אישי רק למי שאין לו מייל ארגוני רשום. התאמה חייבת להיות לאיש צוות אחד בדיוק.
-- המייל נלקח מזהות הגוגל עצמה (auth.identities), שהמשתמש לא יכול לערוך, ולא מהטוקן.

create or replace function public._mk_email_phone(p_email text) returns text
language sql stable security definer set search_path to 'public' as $$
  with e as (select lower(btrim(coalesce(p_email, ''))) v),
  ppl as (
    select public._mk_phone(t.phone) phone, lower(nullif(btrim(t.org_email), '')) org, lower(nullif(btrim(t.email), '')) personal
      from public.milui_teachers t where t.active and coalesce(t.phone, '') <> ''
    union all
    select h.phone, lower(nullif(btrim(h.org_email), '')), null from public.hanhala_staff h),
  per as (select phone, max(org) org, max(personal) personal, bool_or(org = (select v from e)) org_hit,
                 bool_or(personal = (select v from e)) personal_hit, bool_or(org is not null) has_org
          from ppl group by phone),
  hit as (select phone from per where (select v from e) <> '' and (org_hit or (personal_hit and not has_org)))
  select case when (select count(*) from hit) = 1 then (select phone from hit) end $$;

-- p_new_pin ריק = בדיקה בלבד (מי זוהה). עם סיסמה = קביעת סיסמה חדשה.
create or replace function public.mk_google_reset(p_new_pin text) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare em text; ph text; a public.mk_access;
begin
  select lower(i.identity_data->>'email') into em from auth.identities i
    where i.user_id = auth.uid() and i.provider = 'google' and coalesce((i.identity_data->>'email_verified')::boolean, false)
    limit 1;
  if em is null then return jsonb_build_object('error', 'no_google'); end if;
  ph := public._mk_email_phone(em);
  if ph is not null then select * into a from public.mk_access where phone = ph; end if;
  if a.phone is null then return jsonb_build_object('error', 'no_match', 'email', em); end if;
  if coalesce(p_new_pin, '') = '' then return jsonb_build_object('check', true, 'name', a.name, 'email', em); end if;
  if length(p_new_pin) not between 4 and 30 then return jsonb_build_object('error', 'pin_format'); end if;
  update public.mk_access set pin_hash = extensions.crypt(p_new_pin, extensions.gen_salt('bf')), fails = 0, locked_until = null, updated_at = now()
    where phone = a.phone;
  return jsonb_build_object('ok', true, 'phone', a.phone, 'name', a.name);
end $function$;

revoke all on function public._mk_email_phone(text) from public, anon, authenticated;
revoke all on function public.mk_google_reset(text) from public, anon;
grant execute on function public.mk_google_reset(text) to authenticated;
