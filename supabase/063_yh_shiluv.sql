-- 063: מורה שילוב ביום ההורים — פתוח רק להורים של התלמידים שלו
-- מקור התלמידים: הבחירה של מורה השילוב במפת הכיתה (mk_shiluv_pick),
-- ובנוסף תלמידים שמשובצים לו בכלי השילוב (sh_sessions, ספק מסוג h, התאמה לפי שם).
alter table public.yh_participants add column if not exists shiluv boolean not null default false;

-- מילים ממוינות: "יצחק קשאני" = "קשאני יצחק"
create or replace function public._yh_sw(p text) returns text language sql immutable set search_path to '' as $$
  select coalesce(string_agg(w, ' ' order by w), '') from unnest(regexp_split_to_array(btrim(coalesce(p,'')), '\s+')) w where w <> '' $$;

create or replace function public._yh_shiluv_stu(p_tid int, p_cls text) returns text[]
language sql stable security definer set search_path to '' as $$
  with t as (select phone, public._yh_sw(name) k from public.milui_teachers where id = p_tid),
  ck as (select regexp_replace(p_cls, '[^א-ת0-9]', '', 'g') k),
  r as (select unnest(public._yh_students(p_cls)) n)
  select coalesce(array_agg(r.n order by r.n), '{}') from r
  where r.n in (select unnest(k.students) from public.mk_shiluv_pick k, t, ck where k.phone = t.phone and k.class_key = ck.k)
     or exists (select 1 from public.sh_sessions s join public.sh_providers pr on pr.id = s.provider and pr.type = 'h'
                join public.sh_students st on st.id = any(s.students) and st.active, t, ck
                where public._yh_sw(pr.name) = t.k and regexp_replace(st.cls, '[^א-ת0-9]', '', 'g') = ck.k
                  and public._yh_sw(st.name) = public._yh_sw(r.n)) $$;

do $mig$
declare d text; n text;
begin
  -- yh_class: בועה של מורה שילוב רק עם רשימת התלמידים שלו
  d := pg_get_functiondef('public.yh_class(text)'::regprocedure);
  if position('''only''' in d) = 0 then
    n := replace(d, $a$'token', k.token,$a$, $a$'token', k.token, 'only', case when p.shiluv then to_jsonb(public._yh_shiluv_stu(p.teacher_id, l.class_name)) end,$a$);
    n := replace(n, $a$and not p.pending and not public._yh_is_hr(p.teacher_id)));$a$,
      $a$and not p.pending and not public._yh_is_hr(p.teacher_id) and (not p.shiluv or cardinality(public._yh_shiluv_stu(p.teacher_id, l.class_name)) > 0)));$a$);
    if n = d or position('''only''' in n) = 0 or position('not p.shiluv' in n) = 0 then raise exception 'yh_class anchor'; end if;
    execute n;
  end if;

  -- yh_teacher: בקישור האישי רק התלמידים שלו
  d := pg_get_functiondef('public.yh_teacher(text)'::regprocedure);
  if position('_yh_shiluv_stu' in d) = 0 then
    n := replace(d, $a$from unnest(public._yh_students(c.name)) n)) order by c.sort)$a$,
      $a$from unnest(case when p.shiluv then public._yh_shiluv_stu(t.id, c.name) else public._yh_students(c.name) end) n)) order by c.sort)$a$);
    n := replace(n, $a$from public.milui_classes c where c.name = any(p.classes) and$a$,
      $a$from public.milui_classes c where c.name = any(p.classes) and (not p.shiluv or cardinality(public._yh_shiluv_stu(t.id, c.name)) > 0) and$a$);
    if (length(n) - length(replace(n, '_yh_shiluv_stu', ''))) / length('_yh_shiluv_stu') <> 2 then raise exception 'yh_teacher anchor'; end if;
    execute n;
  end if;

  -- yh_book: חסימה בשרת
  d := pg_get_functiondef('public.yh_book(text,text,text,text,boolean,jsonb,text,text)'::regprocedure);
  if position('_yh_shiluv_stu' in d) = 0 then
    n := replace(d, $a$    err := public._yh_check(e, x, cls, p_student, ph);$a$,
      $a$    if exists (select 1 from public.yh_participants p where p.event_id = e.id and p.teacher_id = x.teacher_id and p.shiluv)
       and not (p_student = any(public._yh_shiluv_stu(x.teacher_id, cls))) then raise exception 'wrong_teacher'; end if;
    err := public._yh_check(e, x, cls, p_student, ph);$a$);
    if n = d then raise exception 'yh_book anchor'; end if;
    execute n;
  end if;

  -- yh_staff_load: לצוות — מי עוד לא קבע, רק מתוך התלמידים של מורה השילוב
  d := pg_get_functiondef('public.yh_staff_load(text)'::regprocedure);
  if position('''shiluv''' in d) = 0 then
    n := replace(d, $a$'hr', public._yh_is_hr(p.teacher_id),$a$,
      $a$'shiluv', p.shiluv, 'only', case when p.shiluv then (select jsonb_object_agg(c, to_jsonb(public._yh_shiluv_stu(p.teacher_id, c))) from unnest(p.classes) c) end, 'hr', public._yh_is_hr(p.teacher_id),$a$);
    if n = d then raise exception 'yh_staff_load anchor'; end if;
    execute n;
  end if;
end $mig$;

-- יצחק קשאני — מורה שילוב
update public.yh_participants p set shiluv = true from public.milui_teachers t
  where t.id = p.teacher_id and t.phone = '0586208148';
