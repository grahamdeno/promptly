# UX audit findings

Severity: 4 blocks the task, 3 a person will stumble, 2 slows or confuses, 1 cosmetic.

## Run 1: 7421ca1 (Nov 11), four configs, 36 journeys

| # | Sev | Where | Finding | Fix |
|---|---|---|---|---|
| UX-1 | 4 | First run, large text | The words push the button off screen; you can't get past the first screen. Title runs into the status bar. | Words scroll; the button is pinned at the bottom (`WelcomeView`). |
| UX-2 | 3 | Settings, large text | Rows break mid-word ("Calen-dars", "Ring be-fore"). | At accessibility sizes the answer sits under the title (`SettingsLink`). |
| UX-3 | 3 | Home, large text and small phone | The time ("1:56 AM to 2:…") and the Then line are cut off. | Both wrap. |
| UX-4 | 3 | Home, takeover, Calendars | Not going and Turn all off have tap areas under 44 pt. | Padded tap areas; takeover pill 48 pt. |
| UX-5 | 3 | Pop | A pause before the bubble tore, the audio session reset on every pop, and the card changed only after the burst (Graham, on device). | Tears on touch; sounds preloaded; no session reset; card clears with the pop. |
| UX-6 | 2 | Practice pop | "Try a pop" read like a real meeting: a 3-minute countdown and Not going. | Labeled Practice, no countdown, "Skip". |
| UX-7 | 2 | iPad Home | "Tomorr…" cut off in the Later list. | Time column grows to fit. |
| UX-8 | 2 | Calendars | The pink words (Smart, Turn all off, Pro) are light for small text; the Smart menu is a small target. | Darker pink for small words; bigger targets. |
| UX-9 | 2 | Buttons, large text | Fixed-height buttons clip big words. | Buttons grow with the text. |
| UX-10 | 1 | iPad takeover | The meeting card stretches the full width. | Capped at 680 pt. |
| UX-11 | 2 | Everywhere | Ten fixed font sizes didn't grow with text size. | Text styles throughout. |

Test-side, not the app: J6 ran before demo mode could show the free version (Unicorn locked, Restore purchase);
J3 and the iPad Undo outlasted the 5 s Undo because the walk took its picture first. Fixed in the journeys.

Kept: Apple's contrast check samples through Liquid Glass and flags words that read well (as in Shoebox); checked
by eye. The wordmark stays a fixed size on purpose.
