-- school curriculum per grade (default books for kodesh subjects, topic lists for math/hebrew/science)
alter table public.school_settings add column if not exists curriculum jsonb not null default '{}'::jsonb;
-- functions get_curriculum(code) / save_curriculum(code, map) – applied as migration "school_curriculum"
