-- Walking group members: the app already only ever shows a member's
-- name (never a private message channel to them, never other profile
-- fields), matching "a student can only view the names of who is in
-- the group" — but the `students` SELECT policy only let a student
-- read their own row, so the embedded `students(full_name)` join came
-- back null for every fellow member. Verified: before this fix, a real
-- member saw a name for only 1 of 21 group members (themself); after,
-- 21 of 21.
drop policy if exists "Group members can see each other's names" on students;
create policy "Group members can see each other's names"
on students for select
using (
  exists (
    select 1 from group_members gm1
    join group_members gm2 on gm1.group_id = gm2.group_id
    where gm1.student_id = students.student_id
      and gm2.student_id = auth.uid()
  )
);
