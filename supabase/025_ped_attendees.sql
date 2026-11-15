-- (מיגרציה "ped_attendees") פגישות עם מחנכים (#17): עם מי התקיימה הפגישה: מנהלת, יועצת, מחנכ/ת, אחר
alter table public.ped_meetings add column if not exists attendees text[] not null default '{}';
alter table public.ped_meetings add column if not exists attendees_other text;

CREATE OR REPLACE FUNCTION public.ped_save_meeting(p_phone text, p jsonb)
 RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
declare c jsonb := public._ped_ctx(p_phone); tid int := (p->>'teacher_id')::int; d date := coalesce((p->>'met_on')::date, current_date); nid bigint;
  esc boolean := coalesce((p->>'escalate')::boolean, false);
  att text[] := array(select x from jsonb_array_elements_text(coalesce(p->'attendees','[]'::jsonb)) x where x in ('מנהלת','יועצת','מחנכ/ת','אחר'));
begin
  if not ((c->>'principal')::boolean or (c->>'lvl')::int >= 2) then raise exception 'forbidden'; end if;
  if not exists (select 1 from public.milui_teachers where id = tid and active) then raise exception 'not_found'; end if;
  if d > current_date or d < current_date - 60 then raise exception 'bad_date'; end if;
  if esc and btrim(coalesce(p->>'escalate_text','')) = '' then raise exception 'escalate_text_required'; end if;
  insert into public.ped_meetings(created_by, created_name, met_on, teacher_id, energy, reviewed, summary, escalate, escalate_text, attendees, attendees_other)
    values (c->>'phone', c->>'name', d, tid, (p->>'energy')::smallint, coalesce((p->>'reviewed')::boolean, false), btrim(p->>'summary'),
            esc, case when esc then btrim(p->>'escalate_text') end, att,
            case when 'אחר' = any(att) then nullif(left(btrim(coalesce(p->>'attendees_other','')),120),'') end)
    returning id into nid;
  return nid;
end $function$;

-- ped_data: מוסיפים לכל פגישה את המשתתפים. השינוי נעשה על הגרסה שבמסד, כדי לא לדרוס שינויים משיחות אחרות.
do $$
declare d text := pg_get_functiondef('public.ped_data'::regproc);
begin
  if position('''attendees''' in d) = 0 then
    d := replace(d, '''escalate'', m.escalate, ''escalate_text'', m.escalate_text,',
                    '''escalate'', m.escalate, ''escalate_text'', m.escalate_text, ''attendees'', to_jsonb(m.attendees), ''attendees_other'', m.attendees_other,');
    if position('''attendees''' in d) = 0 then raise exception 'ped_data_pattern_not_found'; end if;
    execute d;
  end if;
end $$;
