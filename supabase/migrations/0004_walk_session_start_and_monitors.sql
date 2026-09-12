-- Walk With Me: start location + which trusted contacts are watching this
-- specific self-monitored journey (informational; a real SOS escalation
-- still fans out to ALL trusted contacts regardless, per scope.md §3).
alter table walk_sessions add column if not exists start_location_text text;
alter table walk_sessions add column if not exists start_lat double precision;
alter table walk_sessions add column if not exists start_lng double precision;
alter table walk_sessions add column if not exists monitor_contact_ids uuid[];
