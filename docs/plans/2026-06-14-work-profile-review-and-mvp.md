# Work Profile — Review, Optimisation & MVP Roadmap

_Date: 2026-06-14_

This document reviews the current **"work" Hermes profile** — an executive /
personal-assistant agent — and proposes a prioritised set of optimisations and
new features framed as an MVP.

The review is based on the **capabilities the profile is wired to** (the MCP
tool schemas connected to the session), not on any live mailbox/calendar data,
which was intentionally not queried.

---

## 1. What the work profile is today

A read-and-research assistant stitched across four domains:

| Domain | Provider | Tools | Mode |
|--------|----------|-------|------|
| **Microsoft 365** | Graph MCP | `outlook_email_search`, `outlook_calendar_search`, `find_meeting_availability`, `chat_message_search` (Teams), `sharepoint_search`, `sharepoint_folder_search`, `read_resource` | **Read-only** |
| **Travel** | Flights/Hotels MCP | `search_flights`, `search_hotels` | Search → booking link |
| **Lodging** | Accommodations MCP | `accommodations_search` | Search → booking link |
| **Mobility** | Rides MCP | `get_estimates_between_two_locations` | Estimate → booking link |
| **Food/grocery** | Eats MCP | `search` (restaurants + grocery) | Search → order link |

Notable design signals in the schemas:

- The calendar/email tools explicitly support **delegated / shared mailboxes**
  ("an executive's calendar that an assistant has delegate access to"). This
  profile is shaped for an **EA / chief-of-staff** workflow, not just personal
  use.
- Travel/rides/eats tools are **discovery surfaces** — they render rich widgets
  and hand back booking links. They do not transact.

## 2. Strengths

- **Strong read coverage of the work graph.** Email, calendar, Teams, and
  SharePoint search together cover the bulk of "find/summarise what's going on"
  requests, including across delegated mailboxes.
- **`find_meeting_availability` is the standout tool** — real free/busy
  scheduling across participants, the hardest part of assistant work, is
  already present.
- **Travel + mobility + food** make the profile useful beyond the desk
  (trip planning, logistics).
- Pagination, natural-language dates, and timezone discipline are baked into the
  M365 tools — good primitives to build on.

## 3. Gaps & risks (the important part)

### 3.1 The profile can _see_ but cannot _act_ — this is the #1 gap
Every M365 tool is a **search**. There is no:
- send / reply / forward email or save a draft,
- create / update / move / cancel a calendar event,
- accept / decline / propose-new-time on an invite,
- post a Teams message,
- create a task or upload to SharePoint.

So today the assistant can produce *"here's what you should do"* but the human
has to execute every step. For a work profile, **write actions are the product.**

### 3.2 No memory of identity / standing context
The travel, rides, and eats tools all need the same facts every time —
home airport, home/office address, timezone, delivery address, cabin/seat
preferences, `user_id`. Nothing persists them, so each request re-asks. These
belong in the profile's `SOUL.md` + memory.

### 3.3 No proactive / scheduled layer
Hermes has a cron system (`cron/`), but the profile is purely reactive. The
highest-value assistant behaviours — morning brief, inbox triage, "your 9am
moved" — only exist if something runs on a schedule.

### 3.4 No task / follow-up tracking
There is no to-do or commitment store. "Follow up with X on Thursday" has
nowhere to live, so nothing closes the loop.

### 3.5 Redundant lodging providers
`search_hotels` and `accommodations_search` overlap heavily. Two providers for
the same intent means inconsistent results and ambiguous routing. Pick a primary
and demote the other to fallback.

### 3.6 Safety surface is wide and unguarded
The profile has **delegate access to a real human's inbox/calendar.** Once write
actions are added, an over-eager send/cancel is a real-world incident. There is
currently no confirmation policy, no "draft-don't-send" default, no allowlist for
recipients/calendars.

## 4. Optimisations to the current setup (low effort, do first)

1. **Write an identity block into `SOUL.md`.** Name, role, who they assist
   (the delegated exec), timezone, home airport, home/office addresses, default
   cabin class, dietary defaults, working hours. Kills the repeated re-asking and
   makes travel/eats one-shot.
2. **Author a sharp persona + operating rules** in `SOUL.md`: concise tone,
   always cite the source email/event, surface times in the user's local TZ,
   and a hard rule to **confirm before any external/irreversible action.**
3. **Pick one lodging provider as primary**; only fall back to the second when
   the first returns nothing. Removes duplicate widgets.
4. **Standardise a "context preamble"** the agent fills before travel/eats/rides
   calls (location, TZ, addresses) so widgets render correctly first try.
5. **Package the profile as a distribution** (`distribution.yaml` + `SOUL.md` +
   `config.yaml` + `cron/`). Makes the setup versioned, reviewable, and
   reproducible on another machine — and gives us a place to land everything
   below.

## 5. MVP feature roadmap

Phased so each phase ships something usable on its own. Phase 1 is the MVP.

### Phase 1 — MVP: "Draft & brief" (highest value, lowest risk)
The two things that turn this from a search box into an assistant, **without**
giving it the ability to do irreversible harm.

1. **Email & calendar _drafting_ (read-safe writes).**
   - Compose email **drafts** (never auto-send) in Outlook.
   - Create **tentative** calendar holds / draft invites.
   - The human hits send/confirm. 80% of the value of "act", ~0% of the
     blast radius. (Implementation: extend the M365 MCP with `create_draft`,
     `create_event` scoped to drafts/tentative.)

2. **Daily morning brief (cron).**
   A scheduled job that assembles: today's agenda (with conflicts flagged),
   unread/important email summary, Teams mentions, and any travel happening
   today — delivered to the user's gateway (Telegram/Slack/etc.) each morning.
   Pure read tools + cron; no new permissions needed. **Build this first — it
   showcases the whole stack and needs nothing but what's already connected.**

3. **Standing context / memory (identity block).** As in §4 — prerequisite for
   the above to feel personal.

### Phase 2 — "Act with a guardrail"
Promote drafts to real actions, gated by an explicit confirmation policy.

4. **Confirmed send / schedule / reply.** Send the draft, send the invite,
   accept/decline, propose new time — each behind a one-tap confirm and an
   allowlist of recipients/calendars.
5. **Meeting scheduler loop.** Combine `find_meeting_availability` + draft
   invite into "find a 30-min slot with A and B next week and send a hold."
6. **Inbox triage.** Categorise/label, surface "needs reply in 24h", draft
   suggested replies for the user to approve.

### Phase 3 — "Close the loop"
7. **Task / follow-up tracker.** A lightweight store (could be a Hermes skill
   backed by a Linear/Notion/Airtable connector that already exists in
   `skills/productivity/`) so commitments don't evaporate.
8. **Trip orchestration.** Chain the existing silos: flight → hotel near the
   meeting location → ride to/from the airport → add everything to the
   calendar as a draft itinerary. The data is all there; this is glue.
9. **Meeting prep packets.** Before a meeting, auto-pull the relevant
   SharePoint docs, last email thread, and attendee context into one brief.

### Cross-cutting (build alongside, not after)
- **Confirmation & safety policy** in `SOUL.md` + config: draft-by-default,
  confirm-before-send, never touch the delegated exec's calendar without
  explicit per-action approval, recipient allowlist.
- **Audit trail.** Log every external action (what was sent, to whom, when) so
  the human can review what the assistant did on their behalf.

## 6. Recommended next step

Two concrete options, in order of leverage:

- **A. Ship the MVP morning brief now.** It needs only the already-connected
  read tools + a cron job + an identity block, and immediately demonstrates the
  whole profile. Lowest risk, fastest visible win.
- **B. Package the profile as a distribution** (`SOUL.md` + `config.yaml` +
  `distribution.yaml` + the brief cron) so the setup is versioned and the rest
  of the roadmap has a home.

Doing **A inside B** is the cleanest path: stand up the distribution skeleton and
land the morning brief + identity block as its first content.

> The one external dependency for Phases 2–3 is **write scopes on the M365 MCP
> server** (draft/send/create-event). That is owned by whoever operates that MCP
> server, not by this repo — worth confirming availability before committing to
> the "act" phases.
