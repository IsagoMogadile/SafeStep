-- Profile pictures
alter table students add column if not exists avatar_url text;
alter table responders add column if not exists avatar_url text;
alter table admins add column if not exists avatar_url text;

-- Report location: free-text address the student enters, plus optional GPS coords
alter table incident_reports add column if not exists location_text text;
alter table incident_reports add column if not exists lat double precision;
alter table incident_reports add column if not exists lng double precision;

-- Alerts: real GPS coordinates when a student sends SOS (lat/lng columns already exist on alerts)
