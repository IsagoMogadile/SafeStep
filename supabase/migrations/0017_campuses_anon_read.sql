-- Fixes a real bug: the student registration wizard now runs BEFORE the
-- auth account is created (deferred signup, migration 0015), so it has
-- no authenticated session when it loads the campus dropdown. campuses'
-- RLS only allowed authenticated reads, so the dropdown silently came
-- back empty — a student could never pick a campus when registering.
--
-- Campus names (South/North/2nd Avenue/Ocean Sciences) are static public
-- reference data, not sensitive in any way, so an anon-readable policy
-- is safe here — same reasoning as check_email_status in migration 0015.
create policy "Anyone can read campuses" on campuses
for select
using (true);
