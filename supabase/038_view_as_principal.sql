-- 038: "בנעליים של" פתוח גם למנהל בית הספר (principal), לא רק למנהל המערכת (sysadmin).
-- מתקן את הגרסה החיה של שתי הפונקציות (לא דורס שינויים אחרים). מסכי המשובים נשארים למנהל המערכת בלבד (_hanhala_dev לא משתנה).
do $$ declare d text; a text; b text; begin
  -- רשימת אנשי הצוות למסך "בנעליים של" בלוח ההנהלה
  d := pg_get_functiondef('public.hanhala_dev_people(text)'::regprocedure);
  if d not like '%''principal''%' then
    a := E'declare s public.hanhala_staff := public._hanhala_dev(p_phone);\nbegin\n';
    b := E'declare s public.hanhala_staff := public._hanhala_me(p_phone);\nbegin\n'
      || E'  if not exists (select 1 from public.hanhala_staff_roles where phone = s.phone and role_id in (''sysadmin'', ''principal'')) then raise exception ''forbidden''; end if;\n';
    if position(a in d) = 0 then raise exception 'patch failed: hanhala_dev_people'; end if;
    execute replace(d, a, b);
  end if;
  -- אסימון צפייה במפת כיתה
  d := pg_get_functiondef('public.mk_as_start(text,text,text)'::regprocedure);
  if d not like '%''principal''%' then
    a := 'and role_id = ''sysadmin'')';
    if position(a in d) = 0 then raise exception 'patch failed: mk_as_start'; end if;
    execute replace(d, a, 'and role_id in (''sysadmin'', ''principal''))');
  end if;
end $$;
