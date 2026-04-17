# Feature 1 — Customizable Break Time

**Date:** 2026-04-17  
**Status:** Approved  
**Scope:** Break duration setting + Settings tab navigation redesign

---

## 1. Overview

Break time is currently hardcoded at 5 minutes everywhere in the app. This spec covers making it user-configurable via a new stepper control in the Settings tab, while also redesigning the Settings tab to use a drill-down navigation pattern (card list → detail page) that scales cleanly as more settings are added.

---

## 2. Settings Tab Redesign

### Home screen
The Settings tab body becomes a list of non-collapsible nav cards. Each card is a tappable row with an icon, label, and `›` chevron. Tapping replaces the tab body with the detail view for that section.

**Cards (in order):**
| Card | Icon | Detail content |
|---|---|---|
| Timer | ⏱ | Break duration stepper |
| Break Messages | 💬 | Existing messages UI (moved here) |
| Repeat Sessions | 🔁 | Greyed out — placeholder for Feature 2 |

### Detail view
When a card is tapped:
- The tab bar remains visible at the top (user always knows they're in Settings)
- The tab body is replaced with the detail view
- A `‹ Back` button appears at the top left of the body, above a section title
- Tapping Back returns to the card list

No animation required for v1 — instant swap is fine.

---

## 3. Break Duration Setting

### UI (Timer detail page)
A stepper control: `−` | `5 min` | `+`

- Increments/decrements by 1 minute per tap
- Minimum: 5 minutes — the `−` button is visually disabled (muted color, non-interactive) at 5
- No maximum cap
- A `"Minimum 5 minutes"` note appears below the stepper in muted text
- Styling matches existing app tokens: background `rgba(255,255,255,0.03)`, border `rgba(255,255,255,0.08)`, value color `#c4b5fd`, active button color `#a78bfa`, disabled button color `#374151`

### Persistence
- Stored in `UserDefaults` under key `timer.breakDuration` as an `Int` (minutes)
- Defaults to `5` if not set
- Read once at app launch; changes take effect immediately (next break that starts)

### Data flow
- `TimerViewModel` gains a `breakDuration: TimeInterval` property, computed from `UserDefaults` (or injected for testability)
- Wherever `5 * 60` is currently hardcoded for break time, it is replaced with `breakDuration`:
  - `breakTimeRemaining` initial assignment in `startSession` / `_forceBreakActive`
  - The break countdown in `breakTick`
- `BreakOverlayView` replaces the hardcoded `"5 MINUTE BREAK"` label with a dynamic string derived from `viewModel.breakDuration` (e.g. `"10 MINUTE BREAK"`)

---

## 4. What Does Not Change

- The "5 More Minutes" extension (from `useExtension()`) stays hardcoded at 5 minutes — it is a separate concept from the break duration and is not configurable in this feature.
- Session duration presets and custom input on the Focus tab are unchanged.
- Streak logic, session history, and break overlay design are unchanged.

---

## 5. Edge Cases

| Scenario | Behavior |
|---|---|
| User changes break duration mid-session | New duration takes effect on the next break (not the current one in progress) |
| UserDefaults value missing on first launch | Default to 5 minutes |
| UserDefaults value is somehow < 5 (e.g. corrupted) | Clamp to 5 on read |

---

## 6. Files Affected

- `Views/PopoverView.swift` — Settings tab body replaced with nav card list + drill-down routing
- `Views/MessagesSettingsView.swift` — moved into Settings detail page, no logic changes
- `ViewModels/TimerViewModel.swift` — replace hardcoded `5 * 60` with `breakDuration`; add `breakDuration` property
- `Views/BreakOverlayView.swift` — dynamic break duration label
- New file: `Views/SettingsHomeView.swift` — nav card list
- New file: `Views/TimerSettingsView.swift` — stepper control + UserDefaults read/write
