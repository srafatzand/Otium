# Otium — Product Requirements Document

**Version:** 1.0  
**Date:** 2026-04-11  
**Status:** Approved

---

## 1. Overview

Otium is a native macOS menu bar application that enforces structured work sessions with mandatory break intervals. When a work session ends, the screen dims with a fullscreen overlay and a short inspirational message. The user can extend their session by 5 minutes once per session, or override the break at the cost of resetting their streak. A running streak counter motivates consistent, healthy work habits.

---

## 2. Goals

- Make it frictionless to start a timed work session from the menu bar
- Enforce breaks without being dismissible by accident — the overlay requires an active choice
- Reward streak-building without punishing rest days or legitimate extensions
- Feel like a native macOS app, not a web wrapper

## 3. Non-Goals

- Cross-platform support (macOS only)
- Cloud sync or multi-device state
- Task/project tracking or tagging
- Notifications when app is not running
- Pomodoro "long break" cycles

---

## 4. User Stories

| # | As a user, I want to… | So that… |
|---|---|---|
| U1 | Start a timed work session from the menu bar | I can focus without setting up an external timer |
| U2 | Choose from preset or custom session durations | The timer fits my natural work rhythm |
| U3 | See how much time is left at a glance from the menu bar | I don't have to click anything to check progress |
| U4 | Have my screen dim when the session ends | I'm forced to acknowledge the break rather than ignore a notification |
| U5 | Get one 5-minute extension per session | I can finish a thought without ruining my streak |
| U6 | Override the break if truly necessary | I'm not locked out of my machine |
| U7 | See my streak and know that overriding costs it | I'm motivated to respect breaks |
| U8 | View today's sessions and weekly focus history | I can reflect on my work patterns |
| U9 | Customize the messages shown on the break overlay | The messages feel personal, not generic |

---

## 5. Feature Requirements

### F1 — Menu Bar Icon

The app runs as a background-only process (`LSUIElement = YES`). No Dock icon. No app switcher entry.

**Icon states:**

| State | Display |
|---|---|
| Idle | Empty progress ring + "Focus" label in muted gray |
| Running | Purple arc ring (fills as session elapses) + remaining time in `MM:SS` format |
| Break active | Pulsing ring + "Break" label |

- Ring is 12×12pt SVG rendered as a `NSImage` template image
- Remaining time updates every second while running
- Color: `#a78bfa` (lavender purple) for the arc; `#374151` for the empty ring

---

### F2 — Popover (Idle State)

Opens when the user clicks the menu bar icon. Closes on click-outside or Escape.

**Sections (top to bottom):**

1. **Header row** — small status dot (gray when idle), "OTIUM" label, streak badge (`🔥 N day streak`)
2. **Time display** — large `25:00` countdown in light lavender, "READY TO START" sub-label
3. **Duration picker** — preset chips: `25m` `45m` `60m` `90m` + custom minute input field
4. **Start Session button** — purple gradient, full width
5. **Divider**
6. **Today section** — "TODAY" label + `Xh Ym focused` total; list of completed sessions (start time + duration + status dot)
7. **Weekly bar chart** — Mon–Sun, bar height = total minutes that day, today highlighted in purple
8. **Footer** — session count ("3 sessions today") + Quit link

**Duration picker behavior:**
- Exactly one option is active at all times (one of the presets, or the custom field)
- Clicking a preset chip clears the custom field and selects that preset
- Typing in the custom field deselects all presets and highlights the custom input in purple
- Custom field accepts integers 1–180; non-integer or out-of-range input reverts to last valid value on blur
- Active preset chip: `rgba(167,139,250,0.2)` background, `rgba(167,139,250,0.4)` border, `#a78bfa` text
- Inactive chip: `rgba(255,255,255,0.03)` background, `rgba(255,255,255,0.08)` border, `#4b5563` text
- Default selected preset on launch: `25m`

**Session history list:**
- Each row: colored dot + start time (e.g. `9:02 AM`) + duration (e.g. `25 min`)
- Dot colors: green (`#34d399`) = completed without override; red (`#ef4444`) = session ended by override; amber (`#fbbf24`) = "5 more mins" was used but break was respected
- Shows today's sessions only; max 10 rows before scroll

---

### F3 — Popover (Running State)

Same layout as idle state with these changes:

- Status dot becomes a pulsing purple circle (`#a78bfa` with glow)
- Time display shows live countdown (updates every second)
- Sub-label becomes "FOCUSING"
- Duration picker chips are **disabled** (locked for session duration)
- Custom input is **disabled**
- "Start Session" button replaced with "Stop Session" (muted styling — `rgba(255,255,255,0.04)` bg, gray text)
- Progress bar appears below the countdown: thin 3px bar, fills left-to-right as percentage of session elapsed, purple gradient

**Stopping a session early:** Clicking "Stop Session" cancels the session. No break overlay is shown. The session is not logged in history. No streak effect.

---

### F4 — Timer Engine

**State machine:**

```
idle → running → break_pending → break_active → idle
                    ↓ (5 more mins, once)
                  extended → break_pending → break_active → idle
```

| State | Description |
|---|---|
| `idle` | No session running |
| `running` | Countdown active, ticking every second |
| `break_pending` | Session expired; overlay animating in |
| `break_active` | Overlay fully visible, break countdown running (5:00) |
| `extended` | "5 more mins" was used; 5-min work extension countdown |

**Transitions:**
- `idle → running`: User taps "Start Session"
- `running → break_pending`: Countdown reaches 0:00
- `break_pending → break_active`: Overlay fully appeared (~0.4s fade)
- `break_active → extended`: User taps "5 More Minutes" (only if not already used this session)
- `extended → break_pending`: 5-min extension countdown reaches 0:00
- `break_active → idle`: Break countdown reaches 0:00 (auto-dismiss) OR user taps Override
- `running → idle`: User taps "Stop Session" (no overlay)

**"5 More Minutes" flag:** A boolean `extendUsed` stored on the current session object. Resets to `false` when a new session starts.

---

### F5 — Break Overlay

A fullscreen `NSWindow` at `.screenSaver` window level, covering **all connected monitors**. Created fresh each time; not reused across sessions.

**Visual design:**
- Background: `linear-gradient(145deg, #1a1025, #0f1a2e)` — deep purple-navy
- Alpha: 0.97 (nearly opaque, not fully black)
- Appears with a 0.4s ease-in fade
- Dismisses with a 0.3s ease-out fade

**Content (centered vertically and horizontally):**

```
────────────────────────────
  🔥 12 day streak            ← top-right badge
  
  — thin purple divider —
  
  "Your message here, in      ← rotating quote, serif font,
   italics and centered."       ~18–20pt, #c4b5fd
  
  5 minute break              ← small uppercase label, muted
  
  4:58                        ← break countdown, 36pt light weight, #a78bfa
  
  [5 More Minutes]  [Override] ← pill buttons
────────────────────────────
```

**Buttons:**

| Button | Style | Behavior | Streak effect |
|---|---|---|---|
| 5 More Minutes | Purple pill, `rgba(167,139,250,0.12)` bg | Dismisses overlay, starts 5-min work extension. Hidden/disabled if already used this session. | None |
| Override | Ghost pill, very muted | Dismisses overlay, cancels break entirely | Resets streak to 0 |

**Break auto-dismiss:** When the break countdown reaches 0:00, the overlay fades out automatically. Session logged as completed (green dot). Streak is unaffected.

**Multi-monitor:** One `NSWindow` per connected screen, all at `.screenSaver` level. Coordinated fade in/out.

---

### F6 — Streak System

A streak counts the number of **days the user completed at least one session without using Override**, since their last override. Days where the app is not used are neutral — they neither increment nor break the streak.

**Rules:**
- Override used → streak resets to 0, records today's date as `lastOverrideDate`
- Session completed without override → streak increments by 1 (once per calendar day)
- "5 More Minutes" used → no streak effect
- App not used today → streak holds unchanged
- Multiple sessions in one day → streak increments only once per day

**Stored in `UserDefaults`:**
- `streak.count: Int` — current streak value
- `streak.lastCompletedDate: Date?` — last date a session completed cleanly
- `streak.lastOverrideDate: Date?` — last date an override was used

**Streak increment logic (on clean session complete):**
```
if lastCompletedDate is nil or lastCompletedDate < today:
    if lastOverrideDate is nil or lastOverrideDate < today:
        streak.count += 1   // gaps in usage are neutral — always increment
    streak.lastCompletedDate = today
```

---

### F7 — Session History

Sessions are stored in `UserDefaults` as a JSON-encoded array of `Session` objects.

```swift
struct Session: Codable {
    let id: UUID
    let startTime: Date
    let plannedDuration: TimeInterval   // seconds
    let actualDuration: TimeInterval    // seconds (may differ if stopped early — but early stops are not logged)
    let extendUsed: Bool
    let outcome: SessionOutcome         // .completed, .overridden
}

enum SessionOutcome: String, Codable {
    case completed   // break was respected (with or without extension)
    case overridden  // override button was used
}
```

**Retention:** Last 90 days of sessions. On launch, prune sessions older than 90 days.

**Weekly chart data:** Derived at render time by grouping `sessions` by calendar day and summing `actualDuration`. No separate aggregation store.

---

### F8 — Break Messages

A rotating set of short, calm, encouraging messages shown on the break overlay.

**Rotation:** Sequentially shuffled — every message is shown once before any repeats.

**Pre-baked defaults (20 messages):**

1. "Step away. Your best ideas come when you stop chasing them."
2. "Rest is not a reward. It's part of the work."
3. "A rested mind sees further."
4. "The pause is productive."
5. "You've earned this moment."
6. "Let your thoughts settle."
7. "Breathe. The work will wait."
8. "Stillness is a skill worth practicing."
9. "Distance is clarity."
10. "Your next session will be better for this."
11. "Good work. Now let go for five minutes."
12. "The best athletes rest. So should you."
13. "Movement helps. Stand up if you can."
14. "Close your eyes. Just for a moment."
15. "Your focus is a muscle. Recover it."
16. "Away from the screen, toward yourself."
17. "The break is the session."
18. "Slower now. Faster later."
19. "You showed up. That's already something."
20. "Five minutes for every hour. That's the deal."

**User-editable messages:**

A "Messages" section in the popover (accessible via a settings gear icon in the popover header) allows:
- View all current messages (default + custom combined)
- Add a custom message (text field + Add button)
- Delete any message (swipe or delete button) — including defaults
- Reset to defaults (button, with confirmation)

Custom messages stored separately in `UserDefaults` as `messages.custom: [String]`. Deleted defaults tracked in `messages.deletedDefaultIds: [Int]` (index into the defaults array).

---

## 6. Visual Design Tokens

| Token | Value | Usage |
|---|---|---|
| `colorBackground` | `linear-gradient(145deg, #1a1025, #0f1a2e)` | Overlay + popover background |
| `colorPrimary` | `#a78bfa` | Ring arc, countdown, active chips |
| `colorPrimaryDeep` | `#7c3aed` | Button gradient start, accents |
| `colorPrimaryMid` | `#6366f1` | Button gradient end |
| `colorText` | `#c4b5fd` | Large time display, quotes |
| `colorTextMuted` | `#94a3b8` | Session times, sub-labels |
| `colorTextDim` | `#4b5563` | Inactive chips, footer |
| `colorDivider` | `rgba(255,255,255,0.06)` | Section dividers |
| `colorSuccess` | `#34d399` | Completed session dot |
| `colorDanger` | `#ef4444` | Overridden session dot |
| `colorWarning` | `#fbbf24` | Extended session dot |
| `fontSerif` | Georgia, serif | Break overlay quote |
| `fontSans` | System font (SF Pro) | All other text |

---

## 7. Data Persistence

All data stored in `UserDefaults` under the app's bundle identifier. No external database.

| Key | Type | Description |
|---|---|---|
| `streak.count` | `Int` | Current streak value |
| `streak.lastCompletedDate` | `Date` | Last clean session date |
| `streak.lastOverrideDate` | `Date` | Last override date |
| `sessions` | `[Session]` (JSON) | Session history (90-day rolling) |
| `messages.custom` | `[String]` | User-added messages |
| `messages.deletedDefaultIds` | `[Int]` | Indices of deleted default messages |
| `timer.lastDuration` | `Int` | Last used duration in minutes (restores on next launch) |

---

## 8. Edge Cases

| Scenario | Behavior |
|---|---|
| Mac goes to sleep mid-session | On wake, if elapsed ≥ session duration, show overlay immediately. If elapsed < duration, resume countdown from remaining time. |
| App quits mid-session | Session is discarded (not logged). Timer state is not persisted across app restarts. |
| Override used, then app relaunched same day | Streak is already 0 from the override. |
| User adds duplicate custom message | Allow it — no deduplication. |
| Custom field left empty on popover close | Reverts to last active preset. |
| All messages deleted by user | Show a fallback: "Time to take a break." |
| Monitor disconnected during break overlay | Remaining overlay windows handle their own lifecycle; disconnected screen's window is released. |
| System time changed while session running | Timer uses monotonic clock (`ProcessInfo.processInfo.systemUptime` delta), not wall clock, to track elapsed time. |

---

## 9. Out of Scope (v1)

- iCloud or network sync
- Multiple timer profiles (work / deep work / etc.)
- Scheduled sessions (auto-start at a time)
- iOS / iPadOS companion app
- Analytics or export
- Widget (macOS Notification Center widget)
- Auto-start break music or ambient sound
