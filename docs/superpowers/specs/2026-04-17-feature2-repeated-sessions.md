# Feature 2 — Repeated Sessions

**Date:** 2026-04-17  
**Status:** Approved

---

## Overview

Users can optionally run N back-to-back sessions with breaks in between. The feature is opt-in via a disclosure toggle in the Focus tab — invisible to users who don't need it. Stop behavior and session logging are identical to single sessions.

---

## Focus Tab Changes

**Disclosure toggle** — a small muted "Repeat ▼" link sits between the custom duration input and the Start button. Tapping it expands an inline panel:

```
REPEAT          [−]  × 3  [+]
```

- Minimum value when open: ×2 (no point repeating once)
- Start button updates to "Start N × Xm" when panel is open
- Collapsing resets count to ×1 and restores "Start Session" — not persisted
- Panel and dots are hidden entirely during a running session (locked like duration chips)

**Session dots** — row of N dots below the ring, visible only during a repeat block:
- Completed sessions: filled purple dot
- Current session: slightly larger, glowing purple dot  
- Upcoming sessions: faint outline dot
- Hidden for single sessions (zero visual clutter)

---

## State Machine

`TimerViewModel` gains two properties: `repeatTotal: Int` (default 1) and `repeatCurrent: Int` (1-indexed).

`startSession(duration:, repeatCount:)` — sets both, kicks off session 1.

In `completeBreak()`:
- If `repeatCurrent < repeatTotal`: increment `repeatCurrent`, call `startSession` with same duration, skip going to idle
- If `repeatCurrent == repeatTotal`: show completion overlay, then go to idle

Break duration between sessions uses `TimerSettingsStore.breakDuration` (same as single session).

---

## Completion Overlay (Last Break)

When the final session's break would normally show, the break overlay is replaced by a completion screen:

- Headline: "N of N complete."
- Same quote card as normal break overlay  
- No countdown timer
- "Click anywhere to continue" hint in muted text at bottom
- Auto-dismisses after 3 seconds; after that, any tap dismisses it
- On dismiss: go to idle, log session as completed, increment streak

---

## Stop & Logging Behavior

Unchanged from current behavior:
- Stop cancels immediately, abandons remaining sessions in the block
- Session logged if ≥50% of that session's duration elapsed
- No prompts, no "stop block" concept

---

## Files Affected

- `ViewModels/TimerViewModel.swift` — `repeatTotal`, `repeatCurrent`, updated `startSession`, updated `completeBreak`
- `Views/TimerControlView.swift` — disclosure toggle, stepper panel, session dots, updated Start button label
- `Views/BreakOverlayView.swift` — completion screen variant for final session
- `Overlay/OverlayWindowController.swift` — pass `isCompletion: Bool` flag to overlay
- `AppDelegate.swift` — pass repeat params through to overlay show call
