-- 031: כלי המשימות — דירוג דחיפות וחשיבות למשימה (משוב #4). 1 = גבוהה, 2 = בינונית, 3 = נמוכה; ריק = לא דורג.
-- הפונקציות מתעדכנות על בסיס הגרסה החיה (לא דורס שינויים אחרים).
alter table public.staff_tasks add column if not exists urgency smallint check (urgency between 1 and 3);
alter table public.staff_tasks add column if not exists importance smallint check (importance between 1 and 3);

do $$ declare d text; f text; begin
  foreach f in array array['public.tasks_list(text)', 'public.tasks_report(text)'] loop
    d := pg_get_functiondef(f::regprocedure);
    if d not like '%t.urgency%' then
      if position($x$'due', t.due, 'note', t.note,$x$ in d) = 0 then raise exception 'patch failed: %', f; end if;
      execute replace(d, $x$'due', t.due, 'note', t.note,$x$, $x$'due', t.due, 'note', t.note, 'urgency', t.urgency, 'importance', t.importance,$x$);
    end if;
  end loop;
  d := pg_get_functiondef('public.tasks_save(text,jsonb)'::regprocedure);
  if d not like '%bad_rank%' then
    if position('ks text[]; ph text[];' in d) = 0 or position($x$  if p ? 'partners' then$x$ in d) = 0
       or position('insert into public.staff_tasks(owner, owner_name, title, due, note) values (s.phone, s.name, tl, d, nt)' in d) = 0
       or position('update public.staff_tasks set title = tl, due = d, note = nt,' in d) = 0 then raise exception 'patch failed: tasks_save'; end if;
    d := replace(d, 'ks text[]; ph text[];', $x$ks text[]; ph text[];
  ug smallint := nullif(p->>'urgency', '')::smallint; im smallint := nullif(p->>'importance', '')::smallint;$x$);
    d := replace(d, $x$  if p ? 'partners' then$x$, $x$  if ug not in (1,2,3) or im not in (1,2,3) then raise exception 'bad_rank'; end if;
  if p ? 'partners' then$x$);
    d := replace(d, 'insert into public.staff_tasks(owner, owner_name, title, due, note) values (s.phone, s.name, tl, d, nt)',
                    'insert into public.staff_tasks(owner, owner_name, title, due, note, urgency, importance) values (s.phone, s.name, tl, d, nt, ug, im)');
    d := replace(d, 'update public.staff_tasks set title = tl, due = d, note = nt,', 'update public.staff_tasks set title = tl, due = d, note = nt, urgency = ug, importance = im,');
    execute d;
  end if;
end $$;
