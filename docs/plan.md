# Promptly plan

Promptly rings like an alarm before each meeting on your iPhone calendars, with Join right on the alert.
Modeled on "In Your Face: Meeting Reminder"; built in Lovely Mail's style: white space, one decision per screen,
the coral ball, Liquid Glass panes.

Design canvas: https://claude.ai/artifact/6dpuMwrhhPZNf3aAZSfAEh

## Decisions (owner, 2026-11-11)
- Name: Promptly. App Store name "Promptly: Meeting Alarms".
- Icon: option B, the coral ball centered on white.
- Ball: the bubble. It inflates over the last hour before a meeting, strains near the start, and pops and springs
  back small when the meeting is joined or cleared. Kept behind a Bubble / Steady switch (Calendars screen) in
  case the owner drops it after trying it.
- v1 reads the calendar only. Nothing leaves the phone.
- Default lead time 1 minute (1, 2 or 5).

## How it works
- EventKit reads timed events for the next 48 hours from the enabled calendars, skipping all-day, canceled and
  declined events. Google and Exchange calendars added in iOS Settings are included.
- `AlarmPlanner` turns them into alarms (stable IDs from a hash, so re-syncs never duplicate). `AlarmService`
  makes AlarmKit match: cancels stale alarms, schedules missing ones (up to 24).
- Re-sync on launch, on returning to the app, on calendar change notifications and on background refresh.
- The alarm's Join button runs `OpenMeetingIntent`, which opens Promptly; Promptly then opens the meeting link,
  or shows the Now screen when there is none. Opening Promptly near alarm time also shows the Now screen, as a
  fallback in case the button's intent doesn't reach the app on device (a reported AlarmKit issue).

## Sprint 1 (this build): test build plus the main screens
- [x] Calendar read, link detection (Zoom, Teams incl. .us gov/DoD, Meet, Webex, GoTo, Chime, Whereby, Slack)
- [x] AlarmKit scheduling with Join on the alert
- [x] Home with the bubble, Now, Welcome, Calendars (calendar toggles, lead time, ball style)
- [x] Icon B
- [x] Unit tests for links, planning, countdown, pending join; read-only guard in CI
- [ ] On-device check: alarm rings through Silent/Focus; Join opens Teams/Zoom; intent reaches the app

## Sprint 2 (owner said go and ship, 2026-11-11)
- [x] Gum motion: inflates in puffs that ease out (no bounce), stretches up and thins as it grows, swells near the
      start, trembles at the start; pops into falling gum shreds; a new bubble inflates from nothing, no spring
- [x] The bubble is the button: "Pop to join" (or "Pop when ready" with no link); "Not going" is a quiet link
- [x] Buzz that builds in the last ten minutes while Promptly is open (Settings: on by default)
- [x] Lock Screen and Dynamic Island countdown card via AlarmKit countdown (PromptlyWidgets extension): still ball
      with a coral ring that fills, live countdown, tap opens the Now screen. Apple draws and updates it, so the
      bubble can't grow there. Settings: on by default
- [x] Nudges at 5 and 2 minutes, one buzz each (Settings: off by default)
- [ ] On-device check: the card appears ten minutes before the ring and the alarm rings at meeting minus lead. If
      it rings ten minutes early instead, set `AlarmPlanner.countdownStartsAtSchedule = false`.

## Later
- Small and medium Home Screen widgets (designs on the canvas).
- Smart filters: travel-time buffer, a second alert for chosen meetings, quiet hours.
- Apple Watch.

## Before App Store
- Privacy policy and support pages at promptly.tangomike.app.
- Screenshots, description, subtitle.
