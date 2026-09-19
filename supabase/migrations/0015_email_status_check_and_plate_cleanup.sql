-- Fixes the "create account -> something went wrong -> user already
-- exists" bug: the old flow called auth signUp() the moment email+
-- password were entered, then wrote the rest of the student profile one
-- wizard step at a time. Abandoning (or hitting any error) partway
-- through left a real, permanent auth.users row with no completed
-- profile — a retry with the same email then failed signUp() with
-- "already registered", with no way to tell the difference between that
-- and a genuine existing account.
--
-- This function lets the Create Account screen check an email BEFORE
-- creating anything, while unauthenticated (SECURITY DEFINER, callable
-- by anon) — it only ever returns one of three words, never any account
-- data, so it's safe to expose pre-login:
--   'active'  - a real, already-usable account exists (students row, or
--               an activated responder/admin) -> block, tell them to log in.
--   'invited' - a responder/admin invite is waiting on this email -> the
--               existing single-screen self-activation flow is fine as-is
--               (no multi-step wizard risk there).
--   'none'    - brand new email -> safe to defer real account creation
--               until the wizard's final review/confirm step.
create or replace function check_email_status(p_email text)
returns text
language sql
security definer
set search_path = public
as $$
  select case
    when exists (select 1 from students where email = p_email) then 'active'
    when exists (select 1 from responders where email = p_email and user_id is not null) then 'active'
    when exists (select 1 from admins where email = p_email and user_id is not null) then 'active'
    when exists (select 1 from responders where email = p_email and activation_status = 'invited') then 'invited'
    when exists (select 1 from admins where email = p_email and activation_status = 'invited') then 'invited'
    else 'none'
  end;
$$;

grant execute on function check_email_status(text) to anon, authenticated;

-- Admin review now categorizes the offense (severity) and flags whether
-- it needs responder/police follow-up, rather than the reporting
-- student's own guess being taken as final (feedback: "admin ... should
-- review the report and add to category of offense, and if responders
-- or police need to intervene").
alter table vehicle_offenses add column if not exists needs_intervention boolean not null default false;

-- Number plates should never contain spaces in storage (feedback: "all
-- number plate should not have any spaces in database") — the app's own
-- normalizePlate() used to collapse repeated spaces into one rather than
-- removing them. Backfill existing rows to match the corrected
-- normalization the client now applies.
update vehicle_records set plate_number = replace(plate_number, ' ', '');
