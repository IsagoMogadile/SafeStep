-- Adds a phone column to admins (scope.md: every user type collects a
-- cellphone number at registration/invite time — students and
-- responders already have one, admins didn't).
alter table admins add column if not exists phone text;

-- Safe Ride student-submitted offense reports now go through admin
-- review before they affect a vehicle's public risk rating, instead of
-- taking effect immediately. Existing rows (seed data + anything already
-- reported) are backfilled as already-approved so nothing already live
-- disappears.
alter table vehicle_offenses add column if not exists status text not null default 'pending_review';
alter table vehicle_offenses add column if not exists reviewed_at timestamptz;

update vehicle_offenses set status = 'approved' where status = 'pending_review';

alter table vehicle_offenses
  add constraint vehicle_offenses_status_check
  check (status in ('pending_review', 'approved', 'rejected'));
