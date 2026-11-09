-- תורנויות חצר: היעדרויות ארוכות (משותף עם מילוי מקום), טלפונים, והחלת מערכת שעות מקובץ עם גיבוי

-- גיבוי שורות מערכת לפני כל החלה מקובץ (לשחזור)
create table if not exists public.milui_slots_backup (
  batch bigint not null,
  created_at timestamptz not null default now(),
  created_by text,
  teacher_name text not null,
  teacher jsonb,
  slots jsonb not null
);
alter table public.milui_slots_backup enable row level security;
create sequence if not exists public.milui_slots_backup_batch;

-- toranut_load: + היעדרויות של יותר מיום אחד שעדיין רלוונטיות, + טלפונים
create or replace function public.toranut_load(p_phone text)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare me text := public.milui_who(p_phone); tt jsonb; st public.toranut_state; ab jsonb; ph jsonb;
begin
  with g as (
    select t.id, d.day, string_agg(coalesce((select case s.kind when 'שיעור' then 'L' when 'שיעור משותף' then 'L'
        when 'פרטני' then 'P' when 'שהייה' then 'S' when 'תפקיד' then 'T' when 'חלון' then 'C' else '?' end
        from public.milui_slots s where s.teacher_id=t.id and s.day=d.day and s.hour=h.h limit 1),'.'),'' order by h.h) prof
    from public.milui_teachers t cross join generate_series(0,5) d(day) cross join generate_series(1,8) h(h)
    where not t.is_external and t.active group by t.id, d.day),
  lay as (
    select teacher_id, string_agg(l,'' order by n desc) layers
    from (select teacher_id, left(c,1) l, count(*) n from public.milui_slots, unnest(classes) c group by 1,2) x group by 1)
  select coalesce(jsonb_object_agg(t.name, jsonb_build_object('id',t.id,
           'p',(select jsonb_agg(prof order by day) from g where g.id=t.id),'l',coalesce(lay.layers,''))),'{}')
    into tt
  from public.milui_teachers t left join lay on lay.teacher_id=t.id where not t.is_external and t.active;

  select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'name',t.name,'from',a.date_from,'to',a.date_to) order by a.date_from),'[]')
    into ab
  from public.milui_absences a join public.milui_teachers t on t.id=a.teacher_id
  where a.hours is null and (a.date_to is null or (a.date_to >= current_date - 1 and a.date_to > a.date_from));

  select coalesce(jsonb_object_agg(name, phone),'{}') into ph from public.milui_teachers where phone is not null and phone<>'';

  select * into st from public.toranut_state where id=1;
  return jsonb_build_object('me',me,'tt',tt,'absences',ab,'phones',ph,'data',coalesce(st.data,'{}'::jsonb),'updated_at',st.updated_at,'updated_by',st.updated_by);
end $$;

-- היעדרות ארוכה למורה שקיים במילוי מקום (יום מלא). p_to ריק = עד הודעה חדשה
create or replace function public.toranut_absence_save(p_phone text, p_name text, p_from date, p_to date)
returns integer language plpgsql security definer set search_path to '' as $$
declare me text := public.milui_who(p_phone); tid int; nid int;
begin
  select id into tid from public.milui_teachers where name=p_name limit 1;
  if tid is null then raise exception 'no_teacher'; end if;
  insert into public.milui_absences(teacher_id,date_from,date_to,hours,permanent,created_by)
  values (tid,p_from,p_to,null,false,me) returning id into nid;
  return nid;
end $$;

-- הארכה / קיצור / "עד הודעה חדשה" (p_to ריק)
create or replace function public.toranut_absence_set_end(p_phone text, p_id int, p_to date)
returns void language plpgsql security definer set search_path to '' as $$
declare me text := public.milui_who(p_phone);
begin
  update public.milui_absences set date_to=p_to where id=p_id;
end $$;

-- החלת מערכת שעות מקובץ. p = {upsert:[{name, slots:[{day,hour,kind,subject,classes,detail}]}], deactivate:[name]}
-- לפני כל שינוי נשמר גיבוי של המורים המושפעים; מחזיר מספר אצווה לשחזור
create or replace function public.toranut_tt_apply(p_phone text, p jsonb)
returns bigint language plpgsql security definer set search_path to '' as $$
declare me text := public.milui_who(p_phone); b bigint := nextval('public.milui_slots_backup_batch'); u jsonb; tid int; n text;
begin
  for n in select jsonb_array_elements_text(coalesce(p->'deactivate','[]')) union
           select x->>'name' from jsonb_array_elements(coalesce(p->'upsert','[]')) x loop
    insert into public.milui_slots_backup(batch,created_by,teacher_name,teacher,slots)
    select b, me, n, (select to_jsonb(t) from public.milui_teachers t where t.name=n limit 1),
      coalesce((select jsonb_agg(to_jsonb(s)) from public.milui_slots s join public.milui_teachers t on t.id=s.teacher_id where t.name=n),'[]');
  end loop;
  update public.milui_teachers set active=false where name in (select jsonb_array_elements_text(coalesce(p->'deactivate','[]')));
  for u in select * from jsonb_array_elements(coalesce(p->'upsert','[]')) loop
    select id into tid from public.milui_teachers where name=u->>'name' limit 1;
    if tid is null then
      insert into public.milui_teachers(name,is_external,active) values (u->>'name',false,true) returning id into tid;
    else
      update public.milui_teachers set active=true where id=tid;
    end if;
    delete from public.milui_slots where teacher_id=tid;
    insert into public.milui_slots(teacher_id,day,hour,kind,subject,classes,detail)
    select tid,(s->>'day')::smallint,(s->>'hour')::smallint,coalesce(s->>'kind','שיעור'),s->>'subject',
      coalesce(array(select jsonb_array_elements_text(s->'classes')),'{}'),s->>'detail'
    from jsonb_array_elements(coalesce(u->'slots','[]')) s;
  end loop;
  return b;
end $$;

-- שחזור אצווה: מחזיר את המורים והשיעורים למצב שלפני ההחלה
create or replace function public.toranut_tt_undo(p_phone text, p_batch bigint)
returns int language plpgsql security definer set search_path to '' as $$
declare me text := public.milui_who(p_phone); r record; tid int; k int := 0;
begin
  for r in select * from public.milui_slots_backup where batch=p_batch loop
    select id into tid from public.milui_teachers where name=r.teacher_name limit 1;
    if r.teacher is null then
      if tid is not null then delete from public.milui_slots where teacher_id=tid; update public.milui_teachers set active=false where id=tid; end if;
    else
      if tid is null then insert into public.milui_teachers(name,active) values (r.teacher_name,true) returning id into tid; end if;
      update public.milui_teachers set active=coalesce((r.teacher->>'active')::boolean,true) where id=tid;
      delete from public.milui_slots where teacher_id=tid;
      insert into public.milui_slots(teacher_id,day,hour,kind,subject,classes,detail,room)
      select tid,(s->>'day')::smallint,(s->>'hour')::smallint,s->>'kind',s->>'subject',
        coalesce(array(select jsonb_array_elements_text(s->'classes')),'{}'),s->>'detail',s->>'room'
      from jsonb_array_elements(r.slots) s;
    end if;
    k := k + 1;
  end loop;
  return k;
end $$;

revoke all on function public.toranut_absence_save(text,text,date,date) from public;
revoke all on function public.toranut_absence_set_end(text,int,date) from public;
revoke all on function public.toranut_tt_apply(text,jsonb) from public;
revoke all on function public.toranut_tt_undo(text,bigint) from public;
grant execute on function public.toranut_absence_save(text,text,date,date) to anon, authenticated;
grant execute on function public.toranut_absence_set_end(text,int,date) to anon, authenticated;
grant execute on function public.toranut_tt_apply(text,jsonb) to anon, authenticated;
grant execute on function public.toranut_tt_undo(text,bigint) to anon, authenticated;
