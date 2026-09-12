-- SafeStep migration: student phone numbers + safe cross-user contact lookup.
-- Run this once in the Supabase Dashboard -> SQL Editor for project
-- "Jackathon SafeStep" (ref ujmatbssukemvrxlnrmp).

-- 1. Student cellphone number, collected during registration.
alter table students add column if not exists phone text;

-- 2. Trusted-contact auto-linking (scope.md §5: "Added by email ... auto-
--    linked if it matches an existing SafeStep account").
--
-- A signed-in student's RLS policies correctly only let them read their
-- OWN row in `students` — but checking whether a contact's email/phone
-- belongs to some OTHER existing student needs a narrow exception to
-- that. This function is SECURITY DEFINER (runs with elevated
-- privileges, bypassing RLS) but is intentionally minimal: it only ever
-- returns a single student_id (never a full row), and only for an exact
-- email or phone match — it cannot be used to enumerate or dump the
-- students table.
create or replace function find_student_by_contact(
  p_email text default null,
  p_phone text default null
)
returns uuid
language sql
security definer
set search_path = public
as $$
  select student_id from students
  where (p_email is not null and email = p_email)
     or (p_phone is not null and phone = p_phone)
  limit 1;
$$;

grant execute on function find_student_by_contact(text, text) to authenticated;
