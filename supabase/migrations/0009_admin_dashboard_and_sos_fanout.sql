-- Admin web dashboard (scope.md §7): admin write access on every table it
-- needs (zones, safety_broadcasts, resources, incident_reports,
-- walking_groups, emergency_contacts, responders, admins) already existed
-- via is_admin(); the one gap was a status column for deactivating an
-- admin account, mirroring what responders.status already did.
alter table admins add column if not exists is_active boolean not null default true;

-- SOS fan-out bug: createAlert() reads the `responders` table (filtered
-- to active + activated) to fan out alert_recipients rows, but a plain
-- student matched none of the existing SELECT policies (not admin, not
-- responder, not a pending invite by email) — so the read silently
-- returned zero rows under RLS (no error), no responder ever got
-- notified, and only trusted_contacts fan-out succeeded. This lets any
-- authenticated user read the minimal fields needed for that fan-out.
drop policy if exists "Authenticated users can read active responders for alert fan-out" on responders;
create policy "Authenticated users can read active responders for alert fan-out"
on responders for select
to authenticated
using (status = 'active' and activation_status = 'active');
