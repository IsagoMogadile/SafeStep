-- "Monitor My Journey" (self_monitored walk_sessions) currently has no
-- live position for a monitor to follow — only the walker's own device
-- shows a countdown timer. This adds a live position the walker's app
-- writes periodically while active, and read access for whichever
-- trusted contacts were picked as monitors (matching the "invite a
-- companion" mode's existing pattern of linking a monitor's own student
-- account via trusted_contacts.linked_student_id).
alter table walk_sessions add column if not exists current_lat double precision;
alter table walk_sessions add column if not exists current_lng double precision;
alter table walk_sessions add column if not exists location_updated_at timestamptz;

drop policy if exists "Monitors can view journeys they're watching" on walk_sessions;
create policy "Monitors can view journeys they're watching"
on walk_sessions for select
using (
  mode = 'self_monitored'
  and exists (
    select 1 from trusted_contacts tc
    where tc.linked_student_id = auth.uid()
      and tc.contact_id = any(monitor_contact_ids)
  )
);
