# Otium

A native macOS menu bar app that enforces structured work/break intervals with a fullscreen dimmed overlay, stoic quotes, and a streak counter.

*Otium* — Latin for "philosophical leisure", as Seneca described the rest that sharpens the mind.

## What it does

- Set a work session (25, 45, 60, 90 min, or custom)
- When time is up, your screen dims with a fullscreen overlay and a rotating stoic quote
- Take the 5-minute break, or use **5 More Minutes** once per session (streak-safe)
- **Override** is always available — but it resets your streak to 0
- Track your streak (days without overriding) and session history from the menu bar popover

## Requirements

- macOS 14.0+
- Xcode 15+

## Setup

```bash
git clone <repo-url>
cd timer
open Otium.xcodeproj
```

Press `⌘R` to build and run. The app lives in your menu bar — no Dock icon.

## Running tests

```bash
xcodebuild test -scheme Otium -destination 'platform=macOS'
```

Or press `⌘U` in Xcode.

## Project structure

| Path | Purpose |
|---|---|
| `Otium/Models/` | `Session`, `TimerState`, `Message` value types |
| `Otium/Stores/` | Persistence: streak, sessions, messages (UserDefaults) |
| `Otium/ViewModels/` | `TimerViewModel` — state machine and countdown |
| `Otium/MenuBar/` | `StatusBarController` — ring+countdown icon and popover |
| `Otium/Overlay/` | `OverlayWindowController` — multi-monitor break screen |
| `Otium/Views/` | SwiftUI views for popover and overlay |
| `OtiumTests/` | XCTest unit tests for stores and view model |

## Docs

- [PRD.md](PRD.md) — Full product requirements
- [PLAN.md](PLAN.md) — Technical implementation plan
