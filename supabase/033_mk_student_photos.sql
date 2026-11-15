-- 033: מפת כיתה — תמונת תלמיד בכרטיס האישי (משוב #19). פתוח בכל הכיתות, למי שרוצה (החלטת הרב חגי).
-- מעלים: מחנך הכיתה וההנהלה. רואים: כל מי שיכול לפתוח את הכיתה (מורה שילוב: רק התלמידים שבחר).
-- התמונה מוקטנת בדפדפן ונשמרת בטבלה סגורה, כמו צילום המסך של המשוב.
create table if not exists public.mk_student_photo(
  class_key text not null,
  stu_key text not null,
  stu_name text not null,
  data text not null check (data like 'data:image/jpeg;base64,%' and length(data) <= 120000),
  updated_at timestamptz not null default now(),
  updated_by text,
  primary key (class_key, stu_key));
alter table public.mk_student_photo enable row level security;
revoke all on public.mk_student_photo from anon, authenticated;

create or replace function public._mk_stu_key(t text) returns text language sql immutable set search_path to '' as $$
  select regexp_replace(coalesce(t, ''), '[^א-תa-zA-Z0-9]', '', 'g') $$;

create or replace function public.mk_photos(p_phone text, p_pin text, p_class text) returns jsonb
language plpgsql security definer set search_path to 'public' as $function$
declare a public.mk_access := public._mk_auth(p_phone, p_pin); ck text := public._mk_norm(p_class); own boolean; pk text[];
begin
  if a.phone is null then return jsonb_build_object('error', a.name); end if;
  own := a.role in ('admin','principal') or public._mk_norm(a.class_name) = ck;
  if not own and not exists (select 1 from public._mk_teacher_classes(a.phone) tc where tc.class_key = ck) then
    return jsonb_build_object('error', 'forbidden'); end if;
  if not own and a.shiluv then
    pk := array(select public._mk_stu_key(u.st) from public.mk_shiluv_pick s, unnest(s.students) u(st) where s.phone = a.phone and s.class_key = ck);
  end if;
  return jsonb_build_object('can_edit', own,
    'photos', (select coalesce(jsonb_object_agg(f.stu_key, f.data), '{}'::jsonb) from public.mk_student_photo f
               where f.class_key = ck and (pk is null or f.stu_key = any(pk))));
end $function$;

create or replace function public.mk_photo_set(p_phone text, p_pin text, p_class text, p_student text, p_data text) returns jsonb
language plpgsql security definer set search_path to 'public' as $function$
declare a public.mk_access := public._mk_auth(p_phone, p_pin); ck text := public._mk_norm(p_class); sk text := public._mk_stu_key(p_student);
begin
  if a.phone is null then return jsonb_build_object('error', a.name); end if;
  if not (a.role in ('admin','principal') or public._mk_norm(a.class_name) = ck) then return jsonb_build_object('error', 'forbidden'); end if;
  if sk = '' or not exists (select 1 from public.milui_classes where public._mk_norm(name) = ck) then return jsonb_build_object('error', 'not_found'); end if;
  if coalesce(p_data, '') = '' then
    delete from public.mk_student_photo where class_key = ck and stu_key = sk;
    return jsonb_build_object('ok', true);
  end if;
  if p_data not like 'data:image/jpeg;base64,%' or length(p_data) > 120000 then return jsonb_build_object('error', 'bad_photo'); end if;
  if (select count(*) from public.mk_student_photo where class_key = ck and stu_key <> sk) >= 60 then return jsonb_build_object('error', 'too_many'); end if;
  insert into public.mk_student_photo(class_key, stu_key, stu_name, data, updated_by) values (ck, sk, left(btrim(p_student), 80), p_data, a.name)
    on conflict (class_key, stu_key) do update set data = excluded.data, stu_name = excluded.stu_name, updated_at = now(), updated_by = excluded.updated_by;
  return jsonb_build_object('ok', true);
end $function$;

revoke all on function public._mk_stu_key(text) from public, anon, authenticated;
revoke all on function public.mk_photos(text,text,text), public.mk_photo_set(text,text,text,text,text) from public;
grant execute on function public.mk_photos(text,text,text), public.mk_photo_set(text,text,text,text,text) to anon, authenticated;

-- צפייה בלבד במצב "בנעליים של" (030) חלה גם על התמונות
drop trigger if exists mk_view_only on public.mk_student_photo;
create trigger mk_view_only before insert or update or delete on public.mk_student_photo for each row execute function public._mk_view_only();
