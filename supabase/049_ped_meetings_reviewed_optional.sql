-- 047: משוב #48 — "עברנו על רשימת התלמידים" לא חובה בטופס תיעוד הפגישה, אבל במסד הוגדר check (reviewed), ולכן כל פגישה בלי הסימון נכשלה בשמירה.
alter table public.ped_meetings drop constraint if exists ped_meetings_reviewed_check;
