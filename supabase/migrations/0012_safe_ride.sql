-- "Safe Ride": check a lift/taxi's number plate against on-file offense
-- records before getting in, and report a vehicle immediately if
-- something goes wrong (student-facing feature, scope brief §7).
--
-- Risk classification (implemented in lib/features/student/domain/
-- safe_ride_risk.dart) combines both the magnitude and the number of
-- offenses: any single severe offense, or 3+ moderate ones, is "danger";
-- 1-2 moderate or 3+ minor is "moderate"; anything less is "clean".

create table if not exists vehicle_records (
  record_id uuid primary key default gen_random_uuid(),
  plate_number text not null unique,
  driver_name text not null,
  vehicle_make text,
  vehicle_model text,
  vehicle_colour text,
  created_at timestamptz not null default now()
);

create type offense_severity as enum ('minor', 'moderate', 'severe');
create type offense_source as enum ('seed', 'admin', 'student_report');

create table if not exists vehicle_offenses (
  offense_id uuid primary key default gen_random_uuid(),
  record_id uuid not null references vehicle_records(record_id) on delete cascade,
  offense_type text not null,
  severity offense_severity not null,
  notes text,
  source offense_source not null default 'seed',
  reported_by_student_id uuid references students(student_id) on delete set null,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists vehicle_records_plate_idx on vehicle_records (plate_number);
create index if not exists vehicle_offenses_record_idx on vehicle_offenses (record_id);

alter table vehicle_records enable row level security;
alter table vehicle_offenses enable row level security;

-- Anyone signed in can look a plate up.
drop policy if exists "vehicle_records read" on vehicle_records;
create policy "vehicle_records read" on vehicle_records for select to authenticated using (true);

-- A student reporting an unknown plate needs to be able to create its
-- record row (not just add an offense to an existing one).
drop policy if exists "vehicle_records student insert (report)" on vehicle_records;
create policy "vehicle_records student insert (report)" on vehicle_records for insert to authenticated with check (true);

drop policy if exists "vehicle_records admin write" on vehicle_records;
create policy "vehicle_records admin write" on vehicle_records for all using (is_admin()) with check (is_admin());

drop policy if exists "vehicle_offenses read" on vehicle_offenses;
create policy "vehicle_offenses read" on vehicle_offenses for select to authenticated using (true);

-- A student can only ever insert an offense attributed to themself, and
-- only tagged as their own report — never impersonating a 'seed' or
-- 'admin' sourced record. Verified: a student attempting to insert with
-- source='seed' gets a 403.
drop policy if exists "vehicle_offenses student report" on vehicle_offenses;
create policy "vehicle_offenses student report" on vehicle_offenses for insert to authenticated
with check (source = 'student_report' and reported_by_student_id = auth.uid());

drop policy if exists "vehicle_offenses admin write" on vehicle_offenses;
create policy "vehicle_offenses admin write" on vehicle_offenses for all using (is_admin()) with check (is_admin());
