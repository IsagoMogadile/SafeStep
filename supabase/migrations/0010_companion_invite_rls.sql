-- Walk With Me companion accept flow: a companion's pending-invites query
-- embeds `students(full_name)` to show who invited them, but the
-- `students` SELECT policy only allows a student to read their own row
-- (or admin/responder) — so the embed silently came back null for anyone
-- else. This narrowly allows a linked companion to read the inviter's
-- row only while there's a matching active walk_sessions invite.
drop policy if exists "Companion can see inviter's name for a pending walk session" on students;
create policy "Companion can see inviter's name for a pending walk session"
on students for select
using (
  exists (
    select 1 from walk_sessions ws
    join trusted_contacts tc on tc.contact_id = ws.companion_contact_id
    where ws.student_id = students.student_id
      and tc.linked_student_id = auth.uid()
      and ws.status = 'active'
  )
);
