-- Bug: a student could join a walking group via group_members insert
-- before an admin approved it — the "Students can join a group
-- themselves" policy only checked student_id = auth.uid(), never the
-- group's status. This was reachable from My Groups, which (unlike
-- Browse Groups) intentionally shows the creator's own pending groups,
-- landing them on a group detail screen with a working Join button.
drop policy if exists "Students can join a group themselves" on group_members;
create policy "Students can join a group themselves"
on group_members for insert
with check (
  student_id = auth.uid()
  and exists (
    select 1 from walking_groups wg
    where wg.group_id = group_members.group_id
      and wg.status = 'approved'
  )
);

-- The live database also had an unrelated, untracked duplicate INSERT
-- policy ("group_members insert self", with_check: student_id =
-- auth.uid() only) predating this migration file. Postgres RLS policies
-- for the same command are OR'd together, so that duplicate alone was
-- enough to bypass the approval check above entirely — drop it.
drop policy if exists "group_members insert self" on group_members;

-- Once a group is approved, its creator shouldn't have to separately
-- click Join — auto-add them as a member. security definer so this
-- works regardless of which admin (not the creator) performs the
-- approval update.
create or replace function handle_group_approved()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'approved' and old.status is distinct from 'approved' then
    insert into group_members (group_id, student_id)
    select new.group_id, new.created_by
    where not exists (
      select 1 from group_members gm
      where gm.group_id = new.group_id and gm.student_id = new.created_by
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_group_approved_auto_join on walking_groups;
create trigger trg_group_approved_auto_join
after update on walking_groups
for each row
execute function handle_group_approved();
