-- Walk With Me — Invite a Companion: instead of the companion just
-- watching the walker go straight to the destination, accepting now also
-- asks the companion for their own location so the app can compute a
-- meeting point roughly midway between them. Both sides walk there first;
-- once each has arrived, the existing destination tracking (walker ->
-- destination) resumes as before.
alter table walk_sessions add column if not exists companion_lat double precision;
alter table walk_sessions add column if not exists companion_lng double precision;
alter table walk_sessions add column if not exists companion_location_updated_at timestamptz;
alter table walk_sessions add column if not exists meeting_lat double precision;
alter table walk_sessions add column if not exists meeting_lng double precision;
alter table walk_sessions add column if not exists walker_reached_meeting_at timestamptz;
alter table walk_sessions add column if not exists companion_reached_meeting_at timestamptz;

-- The companion's own device needs to write their location and arrival
-- timestamp onto the session while walking to the meeting point, same
-- pattern as the existing "companion can accept" update.
drop policy if exists "Companion can update meeting point progress on their invite" on walk_sessions;
create policy "Companion can update meeting point progress on their invite"
on walk_sessions for update
using (
  mode = 'invite_companion'
  and exists (
    select 1 from trusted_contacts tc
    where tc.linked_student_id = auth.uid()
      and tc.contact_id = companion_contact_id
  )
)
with check (
  mode = 'invite_companion'
  and exists (
    select 1 from trusted_contacts tc
    where tc.linked_student_id = auth.uid()
      and tc.contact_id = companion_contact_id
  )
);
