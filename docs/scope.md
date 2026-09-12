# SafeStep — Master Project Plan

**Campus Safety Companion App for Nelson Mandela University, Summerstrand**
Hackathon prototype · Flutter + Supabase

This document is the single source of truth for the project. It consolidates every decision made so far. If restarting the build, everything needed is here.

---

## 1. Vision & Problem Statement

Most student safety incidents happen **off-campus**, not on university grounds — students in Summerstrand live in digs scattered across the suburb, well beyond where campus security has any presence or jurisdiction. A campus-only safety app solves the smaller half of the real problem.

SafeStep is a safety companion app for NMU's four Summerstrand campuses (**South, North, 2nd Avenue, Ocean Sciences**) that treats campus grounds and the surrounding off-campus suburb as **one continuous safety area**, not two separate systems.

This is a hackathon prototype: the backend, auth, and database are **real**, but every person, alert, and report in it is **fictional/simulated** data. No real emergency integration, no real institutional authentication, no real personal data.

---

## 2. Architecture — read this section first

**There is ONE mobile app**, shared by two user types:
- **Students** — full safety feature set (see §5).
- **Responders** — a different post-login experience, same app binary, same login screen. Role is determined by which table the logged-in user's row exists in (`students` vs `responders`), not by a separate app build.

**Admin is web-only.** Never used by students or responders. Can be the same Flutter codebase compiled to web, or a separate small web app — implementation detail, not a product requirement. Conceptually it is a fully separate surface.

**Tech stack:**
| Layer | Tool |
|---|---|
| Mobile app (Student + Responder) | Flutter |
| Admin dashboard | Flutter Web (same codebase, web target) |
| Backend / DB / Auth / Realtime | Supabase |
| Maps & geocoding | Google Maps API |
| Push notifications | Firebase Cloud Messaging or OneSignal |
| Version control | GitHub |
| Editor | VS Code |

**Demo plan:** Live device demo on a physical **Samsung phone connected via USB** (real GPS, real camera, real offline behavior via Airplane Mode). iOS is not locally testable without a Mac — explain Flutter's single-codebase cross-platform nature rather than faking a live iOS demo. A previously-built "virtual phone shell" (fake device chrome for presenting without hardware) has been **abandoned** — not needed now that real hardware is available.

---

## 3. Two responder organizations, one zone-based routing model

This is the core design idea that makes the off-campus expansion work.

- **NMU Campus Security** — covers the four campuses and their immediate perimeters (entrances, gates, adjacent parking, res exits).
- **Security Company** (a private security service, generically named in-app; real-world reference only mentioned verbally in presentation, not shown in the UI) — covers the rest of Summerstrand, 24/7.
- The map is **one continuous view** — campus zones and off-campus Summerstrand zones together, not a toggle between two views.
- Every zone has **2 assigned responders** minimum, from whichever org(s) cover it. Boundary zones (e.g. right at a campus gate) can have **both** orgs assigned.
- **Alert routing is zone-based, not campus-based.** When a panic alert fires in a zone, *every* responder assigned to that zone is notified simultaneously, regardless of org. Whoever acknowledges first is shown to the others as "Acknowledged by [name/org]" — this is real multi-unit dispatch behavior, not a bug to fix.
- Trusted contacts are *always* notified in parallel with responders, regardless of zone/org.

---

## 4. Auth model (confirmed, final)

Real Supabase Auth (`auth.users`) — no custom password hashing.

- **Students**: self-register from scratch — sign up, then complete a details wizard (see §7). Fully active immediately.
- **Responders and Admins**: an existing admin creates their row first (email + name + org + coverage zone for responders; no password, `status: 'invited'`, no auth identity yet). The person **self-activates** later via the same "Create Account" screen a student would use: they enter the email the admin already registered, set a password. After signup succeeds, the app checks for a matching pending `responders`/`admins` row by email — if found, link it, mark `status: 'active'`, skip the student wizard entirely, and route straight to their dashboard.
- Row Level Security (RLS) is **on** across all tables, using `auth.uid()` — verified: a student can see her own row but not another's, can't see other pending invites, can't write to admin-only reference tables.

---

## 5. Functional requirements — Student

| Feature | Notes |
|---|---|
| Registration | Email + password (self-register), primary campus, then: DOB, gender (incl. "prefer not to say"), faculty & year, residence type (NMU residence / off-campus Summerstrand / commuting), full residential address. |
| Restricted-tier fields | Address, vehicle info (optional), mobility needs (optional), medical info (optional) — never admin-browsable; visible to a responder **only** during that student's active alert. |
| Admin-aggregate-only fields | DOB, gender, faculty/year — used for pattern reporting only, never shown as a browsable individual profile. |
| Trusted contacts | 3–10 per student. Added by email (auto-linked if it matches an existing SafeStep account → gets push) or phone (SMS-only fallback with location link). A contact cannot remove themselves — only the student who added them can. |
| Panic button | **Hold for 3 seconds** (deliberate, not one-tap, to avoid accidental activation). Fans out to every responder covering that zone + all trusted contacts. |
| False alarm button | Available after sending an alert. Re-notifies contacts and flips status to "Possible False Alarm – Verify" on the responder side — security still checks in person regardless. |
| Silent alert mode | Separate, deliberate trigger (different gesture/duration from the loud panic button). Sends the same alert without visibly changing the screen. Always flagged to responders as unconfirmed/silent. |
| Offline fallback | Tiered degrade: no data connection → native call to security + SMS to trusted contacts with a location link. No signal at all → cached safety tips, emergency numbers, last-known location shown instead. |
| Walk With Me — invite companion | Student invites a trusted contact (must be app-linked); they must accept before the journey starts; then see the student's live location for its duration. |
| Walk With Me — self-monitored | Student sets destination + timer. Missed check-in → prompt → unresolved for 5 more minutes → escalates into a **real** panic alert. |
| Walk With Me — extend timer | Available mid-journey, doesn't count as a failure. |
| Incident reporting | **One combined details screen** (category, location, description, optional photo, anonymous toggle) → review screen → submit. Not a multi-step wizard. Anonymous reports never expose identity to admin/staff. |
| Campus + Summerstrand map | One continuous map, zones colour-coded by risk (safe/moderate/high), suggested routes avoid red zones. |
| Walking groups | Create or join a scheduled group walk. **Every group requires admin approval.** Optional "request patrol coverage," most relevant for night/off-campus routes. |
| Safety resources | Seeded guidance + admin-verified community-submitted tips. |
| Shuttle & library hours | Simple seeded reference content. |
| QR emergency points | Scanning pre-fills location for a faster alert. |
| Medical info card | Optional, restricted-tier (see above). |

**Home screen:** SOS button + exactly **4 quick-action tiles** — Call Security, Walk With Me, Map, Report a Concern. No scrolling required. Everything else (trusted contacts, groups, resources, safety profile, privacy notice, shuttle/library hours, settings, my reports) lives in the **drawer/menu**, not on the home screen.

**Bottom navigation:** exactly **3 tabs** — Home, Map, Profile. Alerts are reached via a **bell icon in the header**, not a bottom tab (avoids duplicate paths to the same destination).

**Dark/light mode:** supported.

---

## 6. Functional requirements — Responder (same app, different post-login route)

| Feature | Notes |
|---|---|
| Onboarding | Self-activation flow (see §4) using an admin-created invite. |
| Home | Feed of active alerts scoped to their assigned zone(s). Shows student name (or anonymous ID), alert type, location, elapsed time, status. |
| Alert detail | Map with student's live/last-known location + medical info banner (only while alert is active) + status actions: **Acknowledge, Dispatch, Resolve, False Alarm – Verify**. |
| Multi-responder awareness | If another responder covering the same zone already acknowledged, this responder sees "Acknowledged by [name/org]" rather than a duplicate untouched alert. |
| Write report | Short notes field, saved when resolving an alert. |
| History | Past resolved/closed alerts + this responder's own reports. |
| No group visibility needed | Confirmed out of scope — responders don't need to see walking groups. |

---

## 7. Functional requirements — Admin (web only)

| Feature | Notes |
|---|---|
| Manage responders & admins | Creates invite rows for **both** orgs from one dashboard (org + coverage zone are just fields, not separate systems). Deactivate/reactivate accounts. View performance (alerts resolved per responder). |
| Manage zones | Create/edit on-campus + Summerstrand zones, risk status, which org(s) cover each. |
| Broadcast safety alerts | Create, **schedule**, and **retract** alerts (distinct from panic alerts). Target all campuses or specific ones. |
| Manage resources | Create/edit guidance content; moderate (approve/reject) community-submitted tips. |
| Incident reports | View reports — anonymous ones show content only, never identity; named ones show identity. |
| Walking groups | Approve/reject every submitted group. |
| Emergency contacts | Manage the shared numbers list (same across all 4 campuses). |
| Overview dashboard | Active alerts, reports this week, pending approvals, walking-group activity patterns (useful proxy for future shuttle planning). |

---

## 8. Non-functional requirements

- **Usability under stress** — panic button and emergency actions reachable in 1–2 taps, always.
- **Accessibility** — large text, high contrast, clear icons, screen-reader support.
- **Mobile-first** for student/responder; **web** for admin.
- **Performance** — emergency screens and alert delivery load with minimal delay (Supabase realtime).
- **Privacy & POPIA** — tiered data visibility (see §5), explained plainly in the in-app Privacy Notice.
- **Security** — real Supabase Auth + RLS (see §4). Production would add encrypted comms, audit logs, formal data-sharing agreements between NMU and the security company.
- **Reliability** — tiered offline degrade (see §5).
- **Maintainability** — zones, resources, emergency numbers, broadcasts all editable by admin without code changes.
- **Ethical design** — clearly labeled as a prototype; real emergencies must go through official channels; no false confidence created.
- **Dark/light mode.**

---

## 9. Data model (ERD summary)

Core tables: `campuses`, `zones`, `students`, `trusted_contacts`, `responders`, `admins`, `alerts`, `alert_recipients`, `walk_sessions`, `incident_reports`, `walking_groups`, `group_members`, `safety_broadcasts` (admin alerts — distinct from `alerts`), `resources`, `emergency_contacts`.

**Key relationships:**
- `students.student_id` → `auth.users(id)` (self-registered, always active).
- `responders.user_id` / `admins.user_id` → nullable `auth.users(id)` + `status: invited/active` (activation flow).
- `zones.covered_by` (`nmu` / `security_company` / `both`) determines alert routing.
- `alerts.zone_id` → `zones`; `alert_recipients` is the fan-out junction table (one row per notified responder or trusted contact, with its own `acknowledged_at` — this is what makes multi-responder "first to claim it" work).
- `walk_sessions.escalated_alert_id` → `alerts` (nullable; set if a missed check-in escalates to a real alert).
- `walk_sessions.companion_accepted_at` (nullable timestamp) — null = invite pending, set = companion accepted.
- `trusted_contacts.linked_student_id` (nullable) → `students`, set if the contact's email matches an existing account.

**Enums used throughout:** `AlertType`, `AlertStatus`, `AreaType`, `RiskStatus`, `CoverageType`, `WalkMode`, `WalkStatus`, `ReportStatus`, `GroupStatus`, `BroadcastLevel`, `ResourceType`, `ResourceStatus`, `ContactStatus`, `OrgType`.

---

## 10. Seed data conventions

- Format: real South African names, `firstname@student.ac.za` / `firstname@staff.ac.za` (or `@admin.co.za`/`@responder.co.za`/`@student.co.za` — pick one convention and use it consistently) emails, `firstname@123` passwords.
- Roster: 1 admin, 2 responders per zone (minimum 6 zones = 12 responders, split across NMU + Security Company), 10 students varied by campus, gender, residence type, with at least one off-campus/Summerstrand pair.
- Students seed fully activated (real signUp via Admin API). Responders/admins seed as **pending invites only** (`status: 'invited'`, `user_id: null`) — they must self-activate once each via the real Create Account flow before they can log in. This isn't a script limitation, it's the actual intended flow.

---

## 11. Key UX decisions (don't relitigate these)

- Report flow is **2 screens** (combined details → review), not a 3-step wizard.
- Home screen is **SOS + exactly 4 tiles**, no scrolling.
- Bottom nav is **exactly 3 tabs** (Home/Map/Profile); Alerts is a header bell icon, not a tab.
- Everything else lives in the drawer.
- Map is **one continuous view**, not a campus/off-campus toggle.
- Multi-language support is **parked for later** — not in scope now.
- A "what am I wearing today" self-description field was considered and **rejected** as not useful.
- Shake-gesture panic trigger was considered and **rejected** for MVP (too accident-prone) — silent alert instead uses a separate deliberate gesture.

---

## 12. Known open items / not yet built

- Live Walk With Me tracking (companion accept flow, missed check-in escalation) — designed, not confirmed fully working end-to-end.
- Photo evidence upload — UI picker exists in some builds but not wired to real storage.
- A visible helpline/support button.
- Accessibility audit.
- Native (non-web) builds and app store-style packaging — not attempted.
- Git hygiene: commit work in logical chunks — don't let large rewrites stack on an uncommitted foundation.

---

## 13. Explicit assumptions (per original hackathon brief)

- All data is simulated; no real students, no real emergencies.
- Real Supabase + real Auth + real Google Maps API are fine to use — the "avoid real data" rule is about data content, not tooling.
- No real integration with actual police/ambulance/university security systems.
- No real-time GPS tracking of real people; location features use real GPS APIs against fictional demo accounts.
- A real production version would require university approval, security testing, legal review, formal data-sharing agreements (especially given two organizations sharing student data), and integration with official emergency response procedures — none of that is being solved here, just named honestly in the ethics/privacy statement.s