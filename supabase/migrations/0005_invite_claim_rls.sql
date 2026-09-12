-- Fix for the actual root cause of "signed up as responder/admin but got
-- routed to the student wizard": claimPendingInvite's UPDATE against
-- responders/admins was being silently blocked by RLS (0 rows affected,
-- no error — PostgREST just returns an empty result), so it always fell
-- through to "no invite found, treat as new student."
--
-- This policy allows an authenticated user to update ONLY a row that:
--   (a) is still a pending invite (activation_status = 'invited'), and
--   (b) has an email matching their own authenticated JWT email,
-- and only to set exactly their own user_id + activation_status='active'
-- (the `with check` clause) — never anyone else's invite, never any
-- other field.

drop policy if exists "Authenticated users can claim their own pending responder invite" on responders;
create policy "Authenticated users can claim their own pending responder invite"
on responders for update
using (activation_status = 'invited' and email = auth.jwt()->>'email')
with check (user_id = auth.uid() and activation_status = 'active');

drop policy if exists "Authenticated users can claim their own pending admin invite" on admins;
create policy "Authenticated users can claim their own pending admin invite"
on admins for update
using (activation_status = 'invited' and email = auth.jwt()->>'email')
with check (user_id = auth.uid() and activation_status = 'active');

-- The update-then-select-returning pattern (claimPendingInvite selects
-- full_name back) also needs a SELECT policy covering both the
-- pre-claim (matching email) and post-claim (own user_id) states.
drop policy if exists "Users can read their own responder invite or row" on responders;
create policy "Users can read their own responder invite or row"
on responders for select
using (email = auth.jwt()->>'email' or user_id = auth.uid());

drop policy if exists "Users can read their own admin invite or row" on admins;
create policy "Users can read their own admin invite or row"
on admins for select
using (email = auth.jwt()->>'email' or user_id = auth.uid());
