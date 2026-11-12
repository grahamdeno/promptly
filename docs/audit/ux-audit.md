# Pop In UX audit

Adapted from Shoebox (`docs/audit/08-ux-audit.md` there). Run by `.github/workflows/ux-audit.yml` on a branch commit
whose message contains `[audit]`, or by hand. The report (pictures, checks, timings, Apple's accessibility audit,
contact sheets) lands on the `ci-audit` branch as `SUMMARY.md` and `sheets/`.

## Layers

| Layer | Question | Who | Evidence |
|---|---|---|---|
| 1. Walk | Does every step work? | XCUITest in the CI simulator (`App/PromptlyUITests/Journeys.swift`) in demo mode | A check and a picture per step |
| 2. Expert review | Is each step clear, findable, calm and friendly? | Opus reading the pictures against the rubric | Findings rated 1 to 4, in `docs/audit/findings.md` |
| 3. People | Can a stranger do it? | Graham's phone checks, then five TestFlight testers | Task success, ease 1 to 7 |

## Journeys

| # | Journey | What it walks |
|---|---|---|
| J1 | First run | Hello, calendars why, alarms why, which calendars, covered, Home |
| J2 | Home, minutes away | Read the card, pop to join, Undo |
| J3 | Not going | Not going, the next meeting moves up, Undo |
| J4 | Home, a day away | The calm state |
| J5 | Takeover and late | Ringing screen; 50 s and 75 s after the ring (buds); pop |
| J6 | Settings (free) | Every row opens and comes back; Ring before 2 min; Sound; Pop sound; a locked color opens Pro; Restore |
| J7 | Many calendars | 22 calendars in 5 accounts: fold, search "soccer", switch one off, turn a whole account off |
| J8 | Nothing coming up | Empty Home, Try a pop |
| J9 | Unicorn | Bubble, pop with confetti, sprinkles and unicorns |

Demo mode: `-screenshots -scene <name>` (`App/Promptly/App/ScreenshotMode.swift`), `-free` for the free version.
No calendar, no alarms, no system prompts, nothing saved.

Not walked: the Lock Screen alarm and its sound, widgets, Live Activity, a real purchase, VoiceOver, Reduce Motion
and Reduce Transparency. These go to the phone checks.

## Configs

pro-light (iPhone 17 Pro), big-text (Accessibility XXXL), small-phone (iPhone SE or 16e), ipad (iPad Pro 13",
landscape). Pop In is light only, so there is no dark run.

## Rubric

Severity: 4 blocks the task, 3 a person will stumble, 2 slows or confuses, 1 cosmetic.

1. Can a first-time person tell what to do next, without help?
2. Does every action say what it did, and can it be undone?
3. Is every gesture also a visible word and a VoiceOver action? (The bubble is a button; Not going is a word.)
4. Do words read over the bubble at every size and color, Unicorn included?
5. Does text grow with the person's text size without clipping or overlap?
6. Is anything shown that the person did not need at that moment?
7. Does the copy say what it means in plain, friendly words? No jargon, no em-dashes.
8. Is the list short enough to scan? Long lists are grouped, folded or searchable.
9. Is every target at least 44 pt, and does nothing jump under a finger?

Pop In's own rules: calm white; the bubble is the main button; a visible Not going; Bubble/Steady switch still works;
Pro choices marked and open the Pro sheet, never a dead end.

## Phone checks (Graham, before testers)

1. Lock the phone and let a test alarm ring (Settings, tap the version line 5 times, Ring in 20 s): full screen,
   through Silent; the sound loops; Open joins and stops it.
2. Force-quit Pop In, then wait for an alarm: it still rings.
3. VoiceOver on Home: the card, the bubble ("Pop the bubble to join …") and Not going are read; Join and Not going
   are actions.
4. Reduce Motion: no wobble or buds; the pop fades.
5. Largest text: Home, the takeover and Settings read without broken words.
6. Pro: Test the purchase works; Unicorn, Popcorn and Chimes unlock.

## Testers (five, no help first; ease 1 to 7 after each)

1. Make Pop In ring 5 minutes before meetings.
2. Your soccer calendar shouldn't ring. Stop it.
3. A meeting is about to start. Join it from Pop In.
4. You don't plan to go to the next meeting. Make Pop In leave it alone. Then change your mind.
5. Change the bubble's color.

## Runs

| Date | Commit | Result |
|---|---|---|
| Nov 11 | 7421ca1 | First walk, 4 configs, 36 journeys. Found UX-1 to UX-11 (findings.md), led by first run blocked at large text. |
