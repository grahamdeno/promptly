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

## Sprint 3 (owner said build and ship, 2026-11-11)
- [x] Realistic pop: the film tears near the top into eight ragged sheets that part, snap back down toward the
      bottom edge and crumple into a small lump; a few tiny bits come off the tear; the next bubble inflates out of
      the lump. Replaces the flying dots.
- Answered: no third-party app can show its own full-screen alert over the Lock Screen; AlarmKit's alarm is the only
  full-screen option (Critical Alerts and fake incoming calls ruled out).

## Sprint 4 (owner feedback, 2026-11-11)
- [x] Pop scraps fly higher and farther (up to ~400 pt up, ~220 pt out), tumble, then fall and fade; oddly shaped
      lumpy scraps with torn notches plus stretched strands instead of triangles; the pop lasts about 1.2 s.

## Sprint 5 (owner said yes, 2026-11-11)
- [x] Home Screen widget, small and medium: next meeting, live countdown, bubble that grows in minute steps over the
      last hour (easing between redraws), medium shows the next two after it. Tapping the bubble opens Promptly,
      pops it there with the full gum animation, then opens the link. The app writes a meeting snapshot to the App
      Group; the widget never reads the calendar.
- [x] The bubble's tremble fades in from 90 percent and is slightly stronger at the start.

## Sprint 6 (owner said build and ship, 2026-11-11)
- [x] Renamed in the app to Pop In (App Store name "Pop In: Meeting Alarms", claimed in App Store Connect); bundle ID,
      repo and code names stay `promptly` for now.
- [x] Icon B, "Gum on coral": a lighter glossy bubble on a coral gradient.
- [x] No text on the bubble. A fingertip "poke" dents it every 4 s; "Tap the bubble to pop it and join." shows under
      the countdown until the first pop.
- [x] Settings > Check the alarm: shows how many alarms are set and when the next rings; "Ring in 20 s" and "Card,
      then ring" test alarms (test alarms are never cancelled by a sync). Owner reported not yet seeing the
      full-screen alert; this verifies it on device and settles the countdown timing assumption.

## Later
- Smart filters: travel-time buffer, a second alert for chosen meetings, quiet hours.
- Apple Watch.

## Before App Store
- Privacy policy and support pages at promptly.tangomike.app.
- Screenshots, description, subtitle.
