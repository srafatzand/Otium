# Otium — Product Requirements Document

**Version:** 1.1  
**Date:** 2026-04-13  
**Status:** Approved

---

## 1. Overview

Otium is a native macOS menu bar application that enforces structured work sessions with mandatory break intervals. When a work session ends, the screen dims with a fullscreen overlay and a short inspirational message. The user can extend their session by 5 minutes once per session, or override the break at the cost of resetting their streak. A running streak counter motivates consistent, healthy work habits.

The popover uses a three-tab layout: **Focus** (timer + today's sessions), **Dashboard** (weekly stats and session history), and **Settings** (message customisation).

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
| U10 | Stop a session early and still log my partial focus time | Tasks sometimes finish before the timer |
| U11 | See a dashboard with weekly stats and per-day session history | I can track my focus patterns over the week |

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

### F2 — Popover

Opens when the user clicks the menu bar icon. Closes on click-outside (global `NSEvent` monitor required for `LSUIElement` apps) or by re-clicking the icon.

**Header:** small status dot (purple when running, gray when idle) + "OTIUM" label.

**Tab bar (below header):** three tabs that switch the entire popover content:

| Tab | Content |
|---|---|
| Focus | Timer ring + clock + duration picker + Start/Stop + today's sessions |
| Dashboard | Weekly stats, bar chart, today + yesterday session lists |
| Settings | Break message customisation |

**Focus tab sections:**
1. **Ring + clock** — thin arc ring (fills clockwise as session runs, soft glow at rest); `25:00` countdown at 36pt ultralight monospaced
2. **Duration picker** — preset chips `25m` `45m` `60m` `90m` + custom minute input
3. **Start Session / Stop Session button**
4. **Today section** — session rows with colored dot, start time, and duration

**Dashboard tab sections:**
1. **Stat boxes** — Week Total, Daily Avg, Streak (3-up row)
2. **Bar chart** — Mon–Sun, bar height = focus minutes, today highlighted in purple
3. **TODAY** — section header with total, session rows with outcome labels
4. **YESTERDAY** — same format, only shown when sessions exist

**Footer (all tabs):** session count + Quit button.

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

**Stopping a session early:** Clicking "Stop Session" ends the session without showing the break overlay. If ≥50% of the planned duration has elapsed, the session is logged with `outcome: .stopped` (blue dot) and the actual elapsed time. If <50% elapsed, the session is discarded. No streak effect in either case.

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
  🔥 12 day streak              ← top-right badge (pill)
  
  — thin purple divider —
  
  It's time to take a break.   ← fixed primary headline, 26pt, #e2e8f0
  
  ┌─────────────────────────┐
  │ "Rotating stoic quote   │  ← inset card, rgba(255,255,255,0.03) bg,
  │  in italic serif text." │    13pt, italic, Georgia, #7c6fa0
  │          — Author       │  ← attribution, 11pt, #3d3550
  └─────────────────────────┘
  
  — thin purple divider —
  
  5 MINUTE BREAK               ← small uppercase label, muted
  
  4:58                         ← break countdown, 38pt light, #a78bfa
  
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
    case stopped     // user stopped early; elapsed time logged if ≥50% complete
}
```

**Retention:** Last 90 days of sessions. On launch, prune sessions older than 90 days.

**Weekly chart data:** Derived at render time by grouping `sessions` by calendar day and summing `actualDuration`. No separate aggregation store.

---

### F8 — Break Messages

A rotating set of short, calm, encouraging messages shown on the break overlay.

**Rotation:** Sequentially shuffled — every message is shown once before any repeats.

**Pre-baked defaults (10 messages):**

Each message is displayed with its attribution beneath it in smaller muted text.

1. "The mind must be given relaxation — it will rise improved and sharper after a good break." — *Seneca*
2. "Just as rich fields must not be forced — for they will quickly lose their fertility — constant work on the anvil will fracture the force of the mind." — *Seneca*
3. "Retire into yourself as much as you can." — *Seneca*
4. "Confine yourself to the present." — *Marcus Aurelius*
5. "He who is everywhere is nowhere." — *Seneca*
6. "We suffer more in imagination than in reality." — *Seneca*
7. "No man is free who is not master of himself." — *Epictetus*
8. "Make the best use of what is in your power, and take the rest as it happens." — *Epictetus*
9. "Begin at once to live, and count each separate day as a separate life." — *Seneca*
10. "Rest is not idleness — it is the work of becoming." — *Stoic-inspired*

**User-editable messages:**

A "Messages" section in the popover (accessible via a settings gear icon in the popover header) allows:
- View all current messages (default + custom combined)
- Add a custom message (text field + Add button)
- Delete any message (swipe or delete button) — including defaults
- Reset to defaults (button, with confirmation)

Default messages are stored in-app as `[(text: String, attribution: String)]`. Custom messages are stored in `UserDefaults` as a JSON-encoded array of `CustomMessage: Codable { text: String, attribution: String }` — attribution is optional for user-added messages. Deleted defaults tracked in `messages.deletedDefaultIds: [Int]` (index into the defaults array).

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

### F9 — Dashboard

See F2 (Dashboard tab) for layout. Additional data requirements:

- **Week Total** — sum of `actualDuration` for all sessions in the current calendar week
- **Daily Avg** — Week Total ÷ number of days in the current week that have at least one session
- **Streak** — sourced from `StreakStore.count`
- **Bar chart** — derived at render time from `SessionStore.weeklyMinutes()` (weekday → total minutes)
- **TODAY / YESTERDAY** — filtered from `SessionStore.todaysSessions` / `yesterdaysSessions`

Outcome labels in session rows:

| Outcome | Dot color | Label |
|---|---|---|
| `.completed`, no extension | Green `#34d399` | "completed" |
| `.completed`, extension used | Amber `#fbbf24` | "+5m ext" |
| `.overridden` | Red `#ef4444` | "overridden" |
| `.stopped` | Blue `#60a5fa` | "stopped early" |

---

### F10 — New Day Detection

The app must reflect the new calendar day without requiring a restart.

**Implementation:** On `applicationDidFinishLaunching`, schedule a one-shot `Timer` that fires at the next midnight (`Calendar.current.startOfDay` for tomorrow). On fire:
- Call `objectWillChange.send()` on `SessionStore` and `StreakStore` so SwiftUI recomputes all derived properties using the current `Date()`
- Re-schedule for the next midnight

No data migration or state reset is needed — all computed properties already use live `Calendar.current` calls.

---

## 9. Out of Scope (v1)

- iCloud or network sync
- Multiple timer profiles (work / deep work / etc.)
- Scheduled sessions (auto-start at a time)
- iOS / iPadOS companion app
- Analytics or export
- Widget (macOS Notification Center widget)
- Auto-start break music or ambient sound
