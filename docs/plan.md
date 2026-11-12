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

## Sprint 7 (owner picked sound 5, 2026-11-11)
- [x] Pop sound: the airy gum pop (#5 of eight synthesized options, made for Pop In, no licensing) plays with the pop
      haptic. Ambient audio session: silent switch mutes it, mixes with other audio. Setting, on by default.

## Sprint 8 (owner said build and ship, 2026-11-11)
- [x] Alarm sound setting: Bubble blow (default; soft low bloops that speed up, ~28 s file since AlarmKit custom sounds
      may not loop) or Apple default. AlarmKit can't play a named system tone such as Mercury; `.default` is Apple's
      standard alarm sound. Changing the sound reschedules all meeting alarms.
- [x] Per-calendar alert style: Alarm (full screen) or Gentle (one time-sensitive notification at ring time).
- [x] iPad: universal app. Regular width shows the meeting and the rest of today on the left, the bubble on the right;
      all orientations, Split View and Stage Manager. "Keep screen on" setting (desk-clock mode). Large widget.
      No buzz on iPad (no haptics); the pop sound still plays.
- [ ] On device: confirm the bubble-blow alarm plays (forum reports say `.named` needs the file extension, used here)
      and whether it loops.

## Sprint 9 (owner's on-device report, 2026-11-11)
- Confirmed on device: the AlarmKit full-screen alert shows on the Lock Screen (Apple's layout: title, time, app
  name, coral Open button, slide to stop). Owner expected an In Your Face style takeover; iOS allows only this.
- [x] Fix: tapping the alarm's Join/Open button didn't stop the alarm (custom buttons don't), so it kept ringing and
      stayed in the Dynamic Island after the app was closed. The intent now stops its alarm; opening Pop In or
      popping/clearing also silences any ringing alarm.
- [x] Alarm title now says when: "Sprint review · in 1 min".
- [x] While Pop In is open (e.g. the iPad on the desk), the Now screen takes over when the alarm time arrives.
- [x] Bubble color setting: Bubblegum (new default) or Coral (owner removed Hot pink). Tints the bubble, scraps, widgets, wordmark dot
      and the alarm's Lock Screen buttons (alarms reschedule on change). App icon stays coral for now.
- [x] Overdue: past the start, new bubbles bud off the first at +1, +2 and +3 min (each grows over ~45 s in small
      puffs), then from +4 min everything swells into one bubble covering the screen over a minute. In-app only.
- [x] Bubble larger at its max: 880 pt on iPhone (was 710), 760 on iPad, 920 on the Now screen.

## Sprint 10 (owner's on-device feedback, 2026-11-11)
- [x] Extra bubbles start sooner: bud at +15, +40, +70 s past the start (grow over 30 s), merge into one screen-filling
      bubble from +110 s over 50 s. (The first test was at about +1 min, before the old +60 s start.)
- [x] Alarm sound is now "Gum pops": the #5 airy pop (same as the in-app pop) repeating in 6 s cycles that speed up,
      soft-limited for loudness. Owner's choice; replaces the bubble-blow bloops. Apple default still available.
- [x] Readable text: the meeting text sits on a glass pane; secondary text darker. Now screen text was centered by
      mistake (VStack not full width); now left-aligned.
- [x] Gloss: solid gum with a crisp curved highlight streak, a small window reflection, a pinpoint glint, a thin rim
      light and shadowed edges, replacing the large faded white blur.

## Sprint 11 (owner: the test showed only the banner, 2026-11-11)
- [x] Test alarms now add a pretend "Test meeting" to Home (starting one lead time after the ring), so with Pop In open
      the bubble grows, the Now screen takes over at ring time, and extra bubbles bud after the start. Unlocked with
      Pop In closed, iOS shows only the banner; locked, Apple's full-screen alarm.

## Sprint 12 (owner: no alarm banner while the app is open; holistic pass, 2026-11-11)
- [x] While Pop In is on screen, Apple's alarms for anything in the next 20 min are held back (re-checked every 30 s);
      Pop In takes over itself at ring time with its own looping gum-pops alarm sound. The moment Pop In leaves the
      screen or the phone locks, all alarms are put back (background task). Test alarms follow the same rules.
- [x] Holistic fixes: no double buzz (Home's buzz pauses under the Now screen); a takeover waits while settings are
      open instead of being lost; the in-app alarm stops on pop, "Not going", or leaving the Now screen.
- [x] Glint is a small stretched highlight along the curve, not a perfect dot.
- [x] Home text split into separate glass cards (meeting with Not going, countdown, Then), spaced out more; Now
      screen has the meeting card with Not going on its own small pill. Meetings not today show the day
      ("Tomorrow 4:35 PM", "Fri 10:30 AM").
- Known limit: the in-app alarm always uses Gum pops (Apple's default tone can't be played by an app).

## Sprint 13: Beta prep, batch 1 (owner said go, 2026-11-11)
Review: https://claude.ai/artifact/Xs4CqLSRPxh6u4VgfZJpko (App Store readiness review, decisions A-F, RICE backlog)
- [x] Reliability: alarms put back on any loss of focus (inactive or background); re-plan on time zone and clock
      changes; while open, a backup alarm 1 min after each soon ring (cancelled when Pop In takes over);
      same-minute meetings merged into one alarm ("A + B").
- [x] Smart alert rule (default): full alarm only for meetings with a video link, gentle notification for the rest;
      per calendar Smart / Alarm / Gentle. Takeover only for full-alarm meetings.
- [x] First run: one screen per permission explaining why first, calendar choice, then "You're covered" with the
      next meeting, or "Try a pop" demo when nothing is coming up. Demo also on the empty Home.
- [x] Settings: Calendars, Ring before (1/2/5/10), Alarm sound, Bubble color up front; Advanced folded; Diagnostics
      (test alarms, alarm count, Bubble/Steady) hidden behind 5 taps on the version line.
- [x] Accessibility: Dynamic Type via @ScaledMetric and text styles; VoiceOver meeting card with Join and Not going
      actions; bubble hint; Reduce Motion already removes wobble, budding and poke.
- [x] Undo: 5-second "Cleared … Undo" after a pop or Not going.
- [x] Icon: Bubblegum primary icon; Coral alternate, switched automatically with the bubble color.
- [x] Alarm sound "Recorded": the owner's recorded pops, cleaned and boosted (~20x), 23 s.
- [x] site/: home, privacy and support pages for popin.tangomike.app, deployed by GitHub Pages (needs Pages enabled
      and a DNS CNAME, via Grok).

## Sprint 14: Pro and Unicorn mode (owner said do it, 2026-11-11)
- [x] Pop In Pro, one-time non-consumable `com.grahamdeno.promptly.pro` ($4.99), StoreKit 2 (`ProStore`): buy,
      restore, Transaction.updates, refund fallback to free choices. Pro sheet from Settings.
- [x] Pro unlocks: Unicorn mode, Recorded and Chimes alarm sounds, per-calendar Alarm/Gentle overrides, 10-min lead,
      Keep screen on. Free: Smart alerts, bubble, widgets, Gum pops and Apple sounds, Bubblegum and Coral.
- [x] Unicorn mode: pastel rainbow bubble with a slowly drifting sheen (still with Reduce Motion), rainbow buds when
      late, confetti pop (stars, hearts, sparkles, dots), sparkle chime pop sound, "Chimes" alarm, Unicorn icon.
- [ ] App Store Connect: create the in-app purchase and confirm the Paid Apps agreement (Grok).
- [ ] Next: listing and screenshots (UI-test screenshot run on iPhone and iPad simulators with demo data).

## Later
- iPad screenshots in App Store Connect before public release (Grok).
- Smart filters: travel-time buffer, a second alert for chosen meetings, quiet hours.
- Apple Watch.

## Before App Store
- Privacy policy and support pages at promptly.tangomike.app.
- Screenshots, description, subtitle.

## Sprint 15: Beta access to Pro, screenshots, listing (owner said go, 2026-11-11)
- Done: TestFlight and Xcode builds unlock every Pro feature (`ProStore.betaAccess`, from `AppTransaction.environment`
  being sandbox/xcode, with a sandbox-receipt first guess). App Store copies are unaffected. The Pro sheet says it is
  unlocked for testing and still offers "Test the purchase" so the sandbox purchase flow can be tried.
- Done: screenshot mode (`-screenshots -scene home|now|late|unicorn|settings|pop`): demo meetings, no calendar, no alarms,
  nothing saved. `PromptlyUITests` + `Screenshots` scheme + `screenshots.yml` (manual) shoot iPhone Pro Max and
  iPad Pro 13" and upload them as artifacts.
- Done: `docs/app-store-listing.md` (name, subtitle, keywords, description, captions).
- Next: check the screenshots; if the pop frame misses the burst, tune the 0.3 s delay in `ScreenshotTests.test6Pop`.
  Grok uploads the listing and pictures; Graham presses Submit for Review.

## Sprint 16: sounds, buds, Unicorn sprinkles, card spacing, settings rebuilt (owner, 2026-11-11)
- Sounds: the recorded alarm is now "Popcorn" (rebuilt from the 12 strongest pops, high-passed, evened out, no room
  tone; the quiet boomy first pops were the "hollow" start). The bubble's pop is one real pop from that recording.
  Unicorn's pop is a new Sparkle (pop plus a shower of tiny bells). Pop sound is its own setting (Pop, Sparkle, Off);
  Sparkle is the default in Unicorn mode until the owner picks.
- Pop In's own ring starts at 25% volume and rises over the last two minutes to full at the start. Apple's Lock Screen
  alarm volume is the phone's ringer volume; AlarmKit gives no control over it.
- Extra bubbles bud from the ring time (first at about 15 s), not from the start time.
- Unicorn confetti adds 36 cake sprinkles and three unicorns.
- Home card: more space between label, title, countdown and time.
- Settings rebuilt like Scales and Shoebox: Pro row; Meetings (Calendars, Ring before); Alarm (Sound, Lock Screen
  countdown, Heads-up buzzes); Bubble (color balls, Pop sound, Buzz, Keep screen on); Help. Each row shows its answer
  and opens one screen. Calendars grouped by account, big accounts folded, search past 8, "Turn all on/off" per
  account, per-calendar Smart / Always rings / Quiet. Gear icon on Home instead of the calendar icon.
- Next: the friction audit (model: Shoebox docs/audit/08-ux-audit.md). Grok's review notes say "calendar button";
  update to "settings button (gear)".

## Sprint 17: clarity for a first-time user (owner said go, 2026-11-11)
- First run adds "When your phone is locked" with a sketch of Apple's alarm (Open and Stop), so the first locked
  alarm isn't a surprise.
- Settings › Alarm starts with "Test the alarm" (rings in 20 s); no more five taps to find it.
- The Home card says how each meeting will alert: "Rings N min before" (bell) or "Quiet notification only".
- Next (from the assessment): "Pop to join" line in the last 10 minutes; a quieter animation for Not going.
  Grok's review notes can now say Settings › Test the alarm instead of the five-tap Diagnostics.

## Sprint 18: polish before submitting (owner said go, 2026-11-11)
- "Pop the bubble to join" line on the card in the last 10 minutes when the meeting has a link.
- Not going: the bubble deflates and grows back (no pop; popping means join). Takeover too.
- Large text: Pro row stacks; the Rings line wraps.
- App Store header image in docs/app-store-header.png (5244 x 2950, no text).
- Owner: leave the EU out of availability for now (no DSA trader declaration). Not submitting yet; phone checks after
  this build. Still version 1.0 (not submitted), so the newer 1.0 build replaces 1024 on the version.

## Next: Fortune theme (Pro), first update after 1.0 (owner chose 2026-11-12)
- Look: mockup B ("Obsidian") without the round window (that's the Magic 8 Ball's mark; Mattel owns name and look).
  Black glass ball, violet edge glow that slowly circles, a soft star drifting inside. Buds: small black spheres
  with their own glow. Violet accent replaces pink; violet wordmark dot. Indigo app icon with the black ball.
- Pop: violet mist rising and fading, tiny white and gold star sparks. No glass shards.
- Pop sound: "Star" (docs/fortune/pop_star.wav; third Pop choice beside Pop and Sparkle; default in Fortune).
- Alarm: "Oracle", the singing bowl (owner's favorite; preview in docs/fortune; final 28 s, swelling).
  Selectable with any color.
- Fortunes on the card in the last 10 minutes, one per meeting (stable), can be turned off. Owner's list (kept):
  Bring coffee. / You'll be on mute. / This could have been an email. / Someone will say "circle back." /
  Fix your hair. Just kidding, you look great. / Good things are on the agenda. / You'll end early. Maybe. /
  Unmute before you talk. / Take the good notes. / Someone will share the wrong screen. / Today's word: "alignment." /
  Stand up and stretch first. / Someone will say "can you see my screen?" / Listen twice, talk once. /
  Your Wi-Fi will hold. Probably. / Someone will say "you're on mute."
- Sound generator: docs/fortune/sound_samples.py.
