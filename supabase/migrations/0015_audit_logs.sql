-- Admin dashboard audit trail: every mutating admin action (zones,
-- responders/admins, broadcasts, resources, incident reports, walking
-- groups, emergency contacts, Safe Ride report review, alert handling)
-- writes one row here, so there is a single browsable interface showing
-- who did what and when. Denormalizes `admin_name` at write time so the
-- log entry still reads sensibly even if the acting admin is later
-- deactivated (their account row isn't deleted, but this avoids a hard
-- dependency on staying joinable).
create table if not exists audit_logs (
  log_id uuid primary key default gen_random_uuid(),
  admin_id uuid references admins(admin_id) on delete set null,
  admin_name text not null,
  action text not null,
  target_type text,
  target_id text,
  details text,
  created_at timestamptz not null default now()
);

create index if not exists audit_logs_created_at_idx on audit_logs (created_at desc);

alter table audit_logs enable row level security;

-- Only admins can browse the audit trail.
drop policy if exists "audit_logs admin read" on audit_logs;
create policy "audit_logs admin read"
on audit_logs for select
to authenticated
using (is_admin());

-- An admin may only ever write an entry attributed to themselves — never
-- impersonate another admin_id, and never as a non-admin.
drop policy if exists "audit_logs admin insert own actions" on audit_logs;
create policy "audit_logs admin insert own actions"
on audit_logs for insert
to authenticated
with check (
  is_admin()
  and admin_id in (select admin_id from admins where user_id = auth.uid())
);

-- No update/delete policy: the log is append-only by design.
