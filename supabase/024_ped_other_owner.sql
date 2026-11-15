-- 024: ישיבות פדגוגיות — "אחר" במהות הצורך פותח מלל חופשי, ו"מורה מקצועי" דורש שם מורה.
-- הוחל כמיגרציה "ped_other_and_teacher_owner" (תיקון על בסיס הגרסה החיה של הפונקציות, דרך pg_get_functiondef).
alter table public.ped_decisions add column if not exists nature_other text check (length(nature_other) <= 200);
alter table public.ped_decisions add column if not exists owner_name text check (length(owner_name) <= 80);
-- ped_save_decision: nature_other_required / owner_name_required, ושמירת שני השדות
-- ped_update_decision: owner_name מתעדכן יחד עם owner
-- ped_data: ההחלטות כוללות nature_other ו-owner_name; 'teachers' = מורים פעילים והכיתות שהם מלמדים
