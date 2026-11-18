-- 039: במצב "בנעליים של" חלק ב' (האישי) של השאלון מוצג רק למנהל המערכת.
-- כשמנהל בית הספר צופה כאיש צוות, mk_my_q מחזיר part_b ריק ו־part_b_hidden. מתקן את הגרסה החיה (לא דורס שינויים אחרים).
do $$ declare d text; a text; b text; begin
  d := pg_get_functiondef('public.mk_my_q(text,text)'::regprocedure);
  if d not like '%part_b_hidden%' then
    a := E'  return jsonb_build_object(''part_a'', q.part_a, ''part_b'', q.part_b, ''updated_at'', q.updated_at);';
    b := E'  if left(coalesce(p_pin,''''), 6) = ''kr-as:'' and not exists (select 1 from public.mk_as_tokens t\n'
      || E'      join public.hanhala_staff_roles r on r.phone = public.milui_norm(t.dev_phone) and r.role_id = ''sysadmin''\n'
      || E'      where t.token = substr(p_pin, 7)) then\n'
      || E'    return jsonb_build_object(''part_a'', q.part_a, ''part_b'', null, ''part_b_hidden'', true, ''updated_at'', q.updated_at);\n'
      || E'  end if;\n' || a;
    if position(a in d) = 0 then raise exception 'patch failed: mk_my_q'; end if;
    execute replace(d, a, b);
  end if;
end $$;
