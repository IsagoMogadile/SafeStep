-- Fixes a real bug found during QA: the admin "Delete guidance" and
-- "Reject" (community tip) buttons on the Resources tab silently did
-- nothing. Verified directly against the live database as a real
-- authenticated admin (not the service-role key, which bypasses RLS and
-- would have hidden this): DELETE returned HTTP 200 with zero rows
-- affected — the row was never actually removed. SELECT/INSERT/UPDATE
-- all have working admin policies on `resources`; DELETE never got one.
create policy "Admins can delete resources" on resources
for delete
using (is_admin());
