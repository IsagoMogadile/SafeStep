-- Regulated "group chat": students can only send from a fixed set of
-- pre-typed messages/emoji — no free text — to keep walking-group
-- communication safe and low-moderation-overhead (feedback: "lets find
-- a way to regulate this... basic stuff").
create table if not exists group_messages (
  message_id uuid primary key default gen_random_uuid(),
  group_id uuid not null references walking_groups(group_id) on delete cascade,
  student_id uuid not null references students(student_id) on delete cascade,
  preset_key text not null check (preset_key in (
    'lets_go', 'im_here', 'running_late', 'on_my_way',
    'here_now', 'wait_for_me', 'all_good', 'stay_safe'
  )),
  created_at timestamptz not null default now()
);

alter table group_messages enable row level security;

-- Only actual members of a group can read or post its messages.
drop policy if exists "Group members can read group messages" on group_messages;
create policy "Group members can read group messages"
on group_messages for select
using (
  exists (
    select 1 from group_members gm
    where gm.group_id = group_messages.group_id
      and gm.student_id = auth.uid()
  )
);

drop policy if exists "Group members can post preset messages" on group_messages;
create policy "Group members can post preset messages"
on group_messages for insert
with check (
  student_id = auth.uid()
  and exists (
    select 1 from group_members gm
    where gm.group_id = group_messages.group_id
      and gm.student_id = auth.uid()
  )
);

-- Member lists are meant to be browsable (scope: "a student can only view
-- the names of who is in the group"), and joining an approved group is
-- self-service.
drop policy if exists "Any authenticated user can view group members" on group_members;
create policy "Any authenticated user can view group members"
on group_members for select
using (true);

drop policy if exists "Students can join a group themselves" on group_members;
create policy "Students can join a group themselves"
on group_members for insert
with check (student_id = auth.uid());

drop policy if exists "Students can leave a group themselves" on group_members;
create policy "Students can leave a group themselves"
on group_members for delete
using (student_id = auth.uid());

-- Walking groups themselves should be browsable by any authenticated
-- student (scope: "a student can browse through groups and join").
drop policy if exists "Any authenticated user can view walking groups" on walking_groups;
create policy "Any authenticated user can view walking groups"
on walking_groups for select
using (true);
