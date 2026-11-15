-- (מיגרציה "mk_shiluv") מורה שילוב במפת הכיתה.
-- בכניסה הראשונה לכיתה מורה השילוב בוחר את התלמידים שהוא מלמד, ורואה רק אותם:
-- תצוגת מורה מקצועי, ועוד כל ההישגים, מיפוי הקריאה (של התלמידים שלו), המענים והצרכים משנים קודמות.
-- מצב משפחתי, רווחה ומלל חופשי של המחנך נשארים סגורים.
alter table public.mk_access add column if not exists shiluv boolean not null default false;
update public.mk_access set shiluv = true where name in ('חנה מייכור','ושדי רביד','אביה בן שימול','יצחק קשאני');

create table if not exists public.mk_shiluv_pick(
  phone text not null, class_key text not null, students text[] not null default '{}', updated_at timestamptz not null default now(),
  primary key (phone, class_key));
alter table public.mk_shiluv_pick enable row level security;

create or replace function public._mk_shiluv_rows(p_rows jsonb, p_pick text[])
returns jsonb language plpgsql immutable set search_path to '' as $$
declare c jsonb := public._mk_canon_rows(p_rows); r jsonb; res jsonb := '[]'::jsonb;
  allowed int[] := array[0,1,2,4,5,6,7,8,9,10,11,15,16,17,18,20,22,23,24,25,26,31,32,33,34,36,37,40,41,44,45,48,49,52,53,56,57];
  pk text[] := array(select regexp_replace(x,'[^א-תa-zA-Z]','','g') from unnest(coalesce(p_pick,'{}')) x);
begin
  for r in select e from jsonb_array_elements(c) with ordinality t(e, ord) order by ord loop
    if regexp_replace(coalesce(r->>2,''),'[^א-תa-zA-Z]','','g') = any(pk) then
      res := res || jsonb_build_array((select jsonb_agg(case when g = any(allowed) then coalesce(r->>g,'') else '' end order by g) from generate_series(0, 63) g));
    end if;
  end loop;
  return res;
end $$;

create or replace function public.mk_shiluv_pick(p_phone text, p_pin text, p_class text, p_students jsonb)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare a public.mk_access := public._mk_auth(p_phone, p_pin); ck text := public._mk_norm(p_class); st text[];
begin
  if a.phone is null then return jsonb_build_object('error', a.name); end if;
  if not a.shiluv or not exists (select 1 from public._mk_teacher_classes(a.phone) tc where tc.class_key = ck) then return jsonb_build_object('error','forbidden'); end if;
  st := array(select left(btrim(x),60) from jsonb_array_elements_text(coalesce(p_students,'[]')) x where btrim(x) <> '' limit 60);
  insert into public.mk_shiluv_pick(phone, class_key, students, updated_at) values (a.phone, ck, st, now())
  on conflict (phone, class_key) do update set students = excluded.students, updated_at = now();
  return jsonb_build_object('ok', true, 'n', coalesce(array_length(st,1),0));
end $$;
revoke all on function public.mk_shiluv_pick(text,text,text,jsonb) from public;
grant execute on function public.mk_shiluv_pick(text,text,text,jsonb) to anon, authenticated;

-- mk_get: כמו הגרסה הקיימת, ועוד ענף למורה שילוב
CREATE OR REPLACE FUNCTION public.mk_get(p_phone text, p_pin text, p_class text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare a public.mk_access := public._mk_auth(p_phone, p_pin); ck text := public._mk_norm(p_class); d public.mk_class_data;
  lim boolean := false; subs text[]; heb boolean := false; cname text; hteacher text; pick text[]; pk text[]; myv jsonb;
begin
  if a.phone is null then return jsonb_build_object('error', a.name); end if;
  if a.role = 'teacher' and public._mk_norm(a.class_name) <> ck then
    select tc.subjects into subs from public._mk_teacher_classes(a.phone) tc where tc.class_key = ck;
    if not found then return jsonb_build_object('error','forbidden'); end if;
    lim := true;
    heb := exists (select 1 from unnest(coalesce(subs, array[]::text[])) s where regexp_replace(s,'[^א-ת]','','g') in ('עברית','לשון'));
  end if;
  select * into d from public.mk_class_data where class_key = ck;
  cname := coalesce((select name from public.milui_classes where public._mk_norm(name) = ck limit 1), d.class_name, p_class);
  hteacher := (select string_agg(x.name, ', ') from public.mk_access x where public._mk_norm(x.class_name) = ck);
  if lim then
    myv := (select coalesce(jsonb_agg(jsonb_build_object('name', a.name, 'role', a.role, 'is_homeroom', false, 'updated_at', q.updated_at,
          'worries', (select coalesce(jsonb_agg(e), '[]') from jsonb_array_elements(coalesce(q.part_a->'worries','[]')) e where public._mk_norm(e->>'cls') = ck),
          'discuss', (select coalesce(jsonb_agg(e), '[]') from jsonb_array_elements(coalesce(q.part_a->'discuss','[]')) e where public._mk_norm(e->>'cls') = ck))), '[]'::jsonb)
        from public.mk_staff_q q where q.phone = a.phone);
    if a.shiluv then
      -- מורה שילוב: רק התלמידים שבחר; עד שבחר, רשימת שמות בלבד לבחירה
      select s.students into pick from public.mk_shiluv_pick s where s.phone = a.phone and s.class_key = ck;
      pk := array(select regexp_replace(x,'[^א-תa-zA-Z]','','g') from unnest(coalesce(pick,'{}')) x);
      return jsonb_build_object('class_name', cname, 'teacher', hteacher, 'sheet_title', d.sheet_title, 'synced_at', d.synced_at, 'limited', true, 'shiluv', true,
        'picked', to_jsonb(coalesce(pick, array[]::text[])),
        'roster', (select coalesce(jsonb_agg(jsonb_build_array(r->>1, r->>2) order by ord), '[]'::jsonb) from jsonb_array_elements(case when d.rows is null then '[]'::jsonb else public._mk_canon_rows(d.rows) end) with ordinality t(r, ord)),
        'rows', case when d.rows is null or pick is null then null else public._mk_shiluv_rows(d.rows, pick) end,
        'voices', myv,
        'reading', case when pick is null then null else (select r.data - 'students' || jsonb_build_object('uploaded_at', r.uploaded_at,
            'students', (select coalesce(jsonb_agg(e), '[]'::jsonb) from jsonb_array_elements(coalesce(r.data->'students','[]')) e
                         where exists (select 1 from unnest(pk) p where p <> '' and (p = regexp_replace(coalesce(e->>'n',''),'[^א-תa-zA-Z]','','g')
                           or position(regexp_replace(coalesce(e->>'n',''),'[^א-תa-zA-Z]','','g') in p) > 0 and length(regexp_replace(coalesce(e->>'n',''),'[^א-תa-zA-Z]','','g')) >= 4))))
          from public.mk_reading r where r.class_key = ck) end);
    end if;
    -- מורה מקצועי: רק העמודות המותרות, רק מה שהוא עצמו כתב בשאלון, ומיפוי קריאה רק למורה לעברית
    return jsonb_build_object('class_name', cname, 'teacher', hteacher, 'sheet_title', d.sheet_title, 'synced_at', d.synced_at, 'limited', true,
      'subjects', to_jsonb(coalesce(subs, array[]::text[])),
      'rows', case when d.rows is null then null else public._mk_limited_rows(d.rows, subs) end,
      'voices', myv,
      'reading', case when heb then (select r.data || jsonb_build_object('uploaded_at', r.uploaded_at) from public.mk_reading r where r.class_key = ck) end);
  end if;
  return jsonb_build_object(
    'class_name', cname, 'teacher', hteacher,
    'sheet_title', d.sheet_title, 'rows', d.rows, 'synced_at', d.synced_at,
    'voices', public._mk_voices(ck),
    'reading', (select r.data || jsonb_build_object('uploaded_at', r.uploaded_at) from public.mk_reading r where r.class_key = ck),
    'sync_url', case when a.role in ('admin','principal') then (select st.v from public.mk_settings st where st.k = 'sync_url') end);
end $function$;
