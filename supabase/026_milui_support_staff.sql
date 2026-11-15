-- (מיגרציה "milui_support_staff") מילוי מקום (#15): הוספת איש צוות שאין לו מערכת שעות בכלי, כמו מורות שילוב,
-- כדי לשבץ אותו כמסייע/ת במילוי מקום. kind = 'support'.
alter table public.milui_teachers add column if not exists kind text;

CREATE OR REPLACE FUNCTION public.milui_save_teacher(p_phone text, p jsonb)
 RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
declare me text := public.milui_who(p_phone); nid int; sup boolean := coalesce(p->>'kind','') = 'support'; begin
  if p ? 'id' and p->>'id' is not null then
    update public.milui_teachers set phone=p->>'phone', email=p->>'email', channel=coalesce(p->>'channel',channel),
      gender=case when p ? 'gender' then nullif(p->>'gender','') else gender end,
      nick=case when p ? 'nick' then nullif(trim(p->>'nick'),'') else nick end
    where id=(p->>'id')::int returning id into nid;
  else
    if btrim(coalesce(p->>'name','')) = '' then raise exception 'name_required'; end if;
    insert into public.milui_teachers(name,phone,email,channel,is_external,gender,nick,kind)
      values (btrim(p->>'name'),nullif(btrim(coalesce(p->>'phone','')),''),p->>'email',coalesce(p->>'channel','whatsapp'),not sup,nullif(p->>'gender',''),nullif(trim(p->>'nick'),''),case when sup then 'support' end)
      returning id into nid;
  end if;
  return nid; end $function$;
