-- Per-student SOS misuse-prevention ban (see AlertRepository.checkSosGate).
-- Previously tracked client-side in SharedPreferences, which is scoped
-- to the device, not the account — every student login tested on the
-- same physical phone shared one ban state, so one student's misuse
-- blocked every other account on that device too. Moving it server-side,
-- per student_id, fixes that.
alter table students add column if not exists sos_banned_until timestamptz;
