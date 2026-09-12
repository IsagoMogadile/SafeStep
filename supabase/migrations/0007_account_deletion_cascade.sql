-- Make deleting a students row correctly remove everything that belongs
-- to that student, and safely detach (not delete) records that just
-- reference them from someone else's data.

-- Belongs-to-the-student: cascade delete.
alter table trusted_contacts drop constraint if exists trusted_contacts_student_id_fkey;
alter table trusted_contacts add constraint trusted_contacts_student_id_fkey
  foreign key (student_id) references students(student_id) on delete cascade;

alter table alerts drop constraint if exists alerts_student_id_fkey;
alter table alerts add constraint alerts_student_id_fkey
  foreign key (student_id) references students(student_id) on delete cascade;

alter table walk_sessions drop constraint if exists walk_sessions_student_id_fkey;
alter table walk_sessions add constraint walk_sessions_student_id_fkey
  foreign key (student_id) references students(student_id) on delete cascade;

alter table incident_reports drop constraint if exists incident_reports_student_id_fkey;
alter table incident_reports add constraint incident_reports_student_id_fkey
  foreign key (student_id) references students(student_id) on delete cascade;

alter table group_members drop constraint if exists group_members_student_id_fkey;
alter table group_members add constraint group_members_student_id_fkey
  foreign key (student_id) references students(student_id) on delete cascade;

alter table group_messages drop constraint if exists group_messages_student_id_fkey;
alter table group_messages add constraint group_messages_student_id_fkey
  foreign key (student_id) references students(student_id) on delete cascade;

alter table walking_groups drop constraint if exists walking_groups_created_by_fkey;
alter table walking_groups add constraint walking_groups_created_by_fkey
  foreign key (created_by) references students(student_id) on delete cascade;

-- Alert fan-out rows belong to the alert / contact, not the student
-- directly — cascade from those instead.
alter table alert_recipients drop constraint if exists alert_recipients_alert_id_fkey;
alter table alert_recipients add constraint alert_recipients_alert_id_fkey
  foreign key (alert_id) references alerts(alert_id) on delete cascade;

alter table alert_recipients drop constraint if exists alert_recipients_contact_id_fkey;
alter table alert_recipients add constraint alert_recipients_contact_id_fkey
  foreign key (contact_id) references trusted_contacts(contact_id) on delete cascade;

-- Someone else's reference TO this student: detach, don't delete their data.
alter table trusted_contacts drop constraint if exists trusted_contacts_linked_student_id_fkey;
alter table trusted_contacts add constraint trusted_contacts_linked_student_id_fkey
  foreign key (linked_student_id) references students(student_id) on delete set null;

alter table resources drop constraint if exists resources_submitted_by_fkey;
alter table resources add constraint resources_submitted_by_fkey
  foreign key (submitted_by) references students(student_id) on delete set null;

-- Students can delete their own account (data). Deleting the auth.users
-- login credential itself needs a service-role server action (e.g. an
-- Edge Function) — out of reach from the client by design.
drop policy if exists "Students can delete their own account" on students;
create policy "Students can delete their own account"
on students for delete
using (student_id = auth.uid());
