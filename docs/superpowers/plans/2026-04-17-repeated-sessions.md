# Repeated Sessions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users run N back-to-back sessions with breaks in between, configured via a collapsible "Repeat" disclosure in the Focus tab, with a completion overlay after the final session.

**Architecture:** `TimerViewModel` gains `repeatTotal`/`repeatCurrent` state. `completeBreak()` either starts the next session or signals completion. `AppDelegate.onBreakStart` routes to either the normal break overlay or a new `BlockCompletionView` based on `isLastRepeat`. `TimerControlView` gains a disclosure toggle + dots indicator; the linear progress bar is removed.

**Tech Stack:** SwiftUI, AppKit (NSWindow), Combine, XCTest

---

### Task 1: Update TimerViewModel

**Files:**
- Modify: `Otium/Otium/ViewModels/TimerViewModel.swift`
- Modify: `Otium/OtiumTests/TimerViewModelTests.swift`

- [ ] **Step 1: Add failing tests**

```swift
// In TimerViewModelTests, add:

func testRepeatSession_setsRepeatState() {
    vm.startSession(duration: 2, repeatCount: 3)
    XCTAssertEqual(vm.repeatTotal, 3)
    XCTAssertEqual(vm.repeatCurrent, 1)
}

func testRepeatSession_autoStartsNextAfterBreak() {
    vm.startSession(duration: 2, repeatCount: 2)
    vm._simulateTick(count: 2)       // session 1 expires → breakPending
    vm._forceBreakActive()            // → breakActive
    vm._simulateBreakTick(count: 300) // break ends → session 2 auto-starts
    XCTAssertEqual(vm.state, .running)
    XCTAssertEqual(vm.repeatCurrent, 2)
}

func testRepeatSession_isLastRepeatTrueOnFinalSession() {
    vm.startSession(duration: 2, repeatCount: 2)
    vm._simulateTick(count: 2)
    vm._forceBreakActive()
    vm._simulateBreakTick(count: 300) // session 2 starts
    vm._simulateTick(count: 2)        // session 2 expires
    XCTAssertTrue(vm.isLastRepeat)
    XCTAssertEqual(vm.state, .breakPending)
}

func testRepeatSession_stopResetsRepeatState() {
    vm.startSession(duration: 60, repeatCount: 3)
    vm.stopSession()
    XCTAssertEqual(vm.repeatTotal, 1)
    XCTAssertEqual(vm.repeatCurrent, 1)
}

func testCompleteBlock_logsSessionAndGoesIdle() {
    vm.startSession(duration: 2, repeatCount: 2)
    vm._simulateTick(count: 2)
    vm._forceBreakActive()
    vm._simulateBreakTick(count: 300) // session 2 starts
    vm._simulateTick(count: 2)        // session 2 expires (isLastRepeat = true)
    vm.completeBlock()
    XCTAssertEqual(vm.state, .idle)
    XCTAssertEqual(vm.repeatTotal, 1)
    XCTAssertEqual(sessionStore.sessions.last?.outcome, .completed)
    XCTAssertEqual(streakStore.count, 1)
}
```

- [ ] **Step 2: Run tests — confirm they fail**

```bash
cd Otium && xcodebuild test -scheme Otium -destination 'platform=macOS' 2>&1 | grep -E "failed|error:" | head -10
```

- [ ] **Step 3: Implement changes in TimerViewModel**

Add published properties after `sessionDuration`:
```swift
@Published private(set) var repeatTotal: Int = 1
@Published private(set) var repeatCurrent: Int = 1
var isLastRepeat: Bool { repeatTotal > 1 && repeatCurrent == repeatTotal }
```

Update `startSession`:
```swift
func startSession(duration: TimeInterval, repeatCount: Int = 1) {
    stopTimer()
    state = .running
    sessionDuration = duration
    timeRemaining = duration
    extendUsed = false
    sessionStartTime = Date()
    repeatTotal = repeatCount
    repeatCurrent = 1
    startTimer()
}
```

Update `stopSession` — add reset after `sessionStartTime = nil`:
```swift
repeatTotal = 1
repeatCurrent = 1
```

Add `completeBlock()` (called by completion overlay on dismiss):
```swift
func completeBlock() {
    let totalDuration = sessionDuration + (extendUsed ? 5 * 60 : 0)
    sessionStore.add(Session(
        startTime: sessionStartTime ?? Date(),
        plannedDuration: sessionDuration,
        actualDuration: totalDuration,
        extendUsed: extendUsed,
        outcome: .completed
    ))
    streakStore.recordCleanSession()
    state = .idle
    sessionStartTime = nil
    repeatTotal = 1
    repeatCurrent = 1
    onBreakEnd?()
}
```

Update `completeBreak()` — replace the `state = .idle` block at the end:
```swift
private func completeBreak() {
    stopTimer()
    let totalDuration = sessionDuration + (extendUsed ? 5 * 60 : 0)
    sessionStore.add(Session(
        startTime: sessionStartTime ?? Date(),
        plannedDuration: sessionDuration,
        actualDuration: totalDuration,
        extendUsed: extendUsed,
        outcome: .completed
    ))
    streakStore.recordCleanSession()

    if repeatCurrent < repeatTotal {
        // Auto-start next session in the block
        repeatCurrent += 1
        extendUsed = false
        sessionStartTime = Date()
        timeRemaining = sessionDuration
        state = .running
        onBreakEnd?()
        startTimer()
    } else {
        state = .idle
        sessionStartTime = nil
        repeatTotal = 1
        repeatCurrent = 1
        onBreakEnd?()
    }
}
```

- [ ] **Step 4: Run tests — confirm they pass**

```bash
cd Otium && xcodebuild test -scheme Otium -destination 'platform=macOS' 2>&1 | grep -E "TimerViewModel.*passed|TimerViewModel.*failed"
```
Expected: all `TimerViewModelTests` pass (except the pre-existing `testExtensionExpiry` failure).

- [ ] **Step 5: Commit**

```bash
cd Otium && git add Otium/ViewModels/TimerViewModel.swift OtiumTests/TimerViewModelTests.swift
git commit -m "feat: add repeat session state to TimerViewModel"
```

---

### Task 2: Update TimerControlView (UI)

**Files:**
- Modify: `Otium/Otium/Views/TimerControlView.swift`

- [ ] **Step 1: Remove the linear progress bar block**

Delete this entire block (lines ~69–81):
```swift
// Progress bar (running only)
if viewModel.state == .running || viewModel.state == .extended {
    GeometryReader { geo in
        ZStack(alignment: .leading) { ... }
    }
    .frame(height: 3)
    .cornerRadius(2)
    .padding(.horizontal, 20)
    .padding(.bottom, 10)
}
```

- [ ] **Step 2: Add session dots where the progress bar was**

Replace with:
```swift
// Session dots — only during repeat blocks
if viewModel.repeatTotal > 1 {
    HStack(spacing: 5) {
        ForEach(0..<viewModel.repeatTotal, id: \.self) { i in
            let done = i < viewModel.repeatCurrent - 1
            let current = i == viewModel.repeatCurrent - 1
            Circle()
                .fill(done || current ? Color(hex: "a78bfa") : Color.white.opacity(0.1))
                .frame(width: current ? 9 : 7, height: current ? 9 : 7)
                .overlay(
                    current ? Circle()
                        .fill(Color(hex: "a78bfa").opacity(0.25))
                        .frame(width: 15, height: 15) : nil
                )
        }
    }
    .padding(.bottom, 8)
}
```

- [ ] **Step 3: Add repeat state variables and toggle logic**

At the top of `TimerControlView`, add after `@State private var customText`:
```swift
@State private var repeatExpanded: Bool = false
@State private var repeatCount: Int = 2
```

Add helper:
```swift
private func toggleRepeat() {
    withAnimation(.easeInOut(duration: 0.15)) {
        if repeatExpanded { repeatCount = 2 }
        repeatExpanded.toggle()
    }
}
```

Update `toggleSession`:
```swift
private func toggleSession() {
    if viewModel.state == .idle {
        viewModel.startSession(duration: activeDuration, repeatCount: repeatExpanded ? repeatCount : 1)
        withAnimation { repeatExpanded = false }
    } else {
        viewModel.stopSession()
    }
}
```

- [ ] **Step 4: Add disclosure trigger and stepper panel before the Start button**

Replace the `// Start / Stop button` block with:
```swift
// Repeat disclosure (idle only)
if viewModel.state == .idle {
    Button(action: toggleRepeat) {
        HStack(spacing: 4) {
            Text("Repeat")
                .font(.system(size: 9, weight: .medium))
                .tracking(1)
                .foregroundColor(repeatExpanded ? Color(hex: "6366f1") : Color(hex: "374151"))
            Image(systemName: repeatExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(repeatExpanded ? Color(hex: "6366f1") : Color(hex: "374151"))
        }
    }
    .buttonStyle(.plain)
    .padding(.bottom, 4)
}

if repeatExpanded && viewModel.state == .idle {
    HStack {
        Text("REPEAT")
            .font(.system(size: 9, weight: .semibold))
            .tracking(1.5)
            .foregroundColor(Color(hex: "4b5563"))
        Spacer()
        HStack(spacing: 0) {
            Button(action: { if repeatCount > 2 { repeatCount -= 1 } }) {
                Text("−")
                    .font(.system(size: 16, weight: .light))
                    .frame(width: 34, height: 28)
                    .foregroundColor(repeatCount <= 2 ? Color(hex: "374151") : Color(hex: "a78bfa"))
            }
            .buttonStyle(.plain)
            .disabled(repeatCount <= 2)
            Divider().frame(height: 14)
            Text("× \(repeatCount)")
                .font(.system(size: 12, weight: .light, design: .monospaced))
                .foregroundColor(Color(hex: "c4b5fd"))
                .frame(width: 36)
            Divider().frame(height: 14)
            Button(action: { repeatCount += 1 }) {
                Text("+")
                    .font(.system(size: 16, weight: .light))
                    .frame(width: 34, height: 28)
                    .foregroundColor(Color(hex: "a78bfa"))
            }
            .buttonStyle(.plain)
        }
        .background(Color.white.opacity(0.03))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .cornerRadius(7)
    }
    .padding(.bottom, 8)
    .transition(.opacity.combined(with: .move(edge: .top)))
}

// Start / Stop button
Button(action: toggleSession) {
    Group {
        if viewModel.state != .idle {
            Text("Stop Session")
        } else if repeatExpanded {
            Text("Start \(repeatCount) × \(Int(activeDuration / 60))m")
        } else {
            Text("Start Session")
        }
    }
    .font(.system(size: 13, weight: .medium))
    .frame(maxWidth: .infinity)
    .padding(.vertical, 10)
    .background(
        viewModel.state == .idle
            ? LinearGradient(colors: [Color(hex: "7c3aed"), Color(hex: "6366f1")], startPoint: .leading, endPoint: .trailing)
            : LinearGradient(colors: [Color.white.opacity(0.04), Color.white.opacity(0.04)], startPoint: .leading, endPoint: .trailing)
    )
    .foregroundColor(viewModel.state == .idle ? .white : Color(hex: "64748b"))
    .cornerRadius(8)
}
.buttonStyle(.plain)
.padding(.bottom, 8)
```

- [ ] **Step 5: Build and verify**

```bash
cd Otium && xcodebuild -scheme Otium -destination 'platform=macOS' build 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 6: Commit**

```bash
cd Otium && git add Otium/Views/TimerControlView.swift
git commit -m "feat: add repeat disclosure UI and session dots to Focus tab"
```

---

### Task 3: Block Completion Overlay

**Files:**
- Create: `Otium/Otium/Views/BlockCompletionView.swift`
- Modify: `Otium/Otium/Overlay/OverlayWindowController.swift`
- Modify: `Otium/Otium/AppDelegate.swift`

- [ ] **Step 1: Create BlockCompletionView**

```swift
// Otium/Views/BlockCompletionView.swift
import SwiftUI

struct BlockCompletionView: View {
    let repeatTotal: Int
    let currentMessage: Message
    @ObservedObject var streakStore: StreakStore
    let onDismiss: () -> Void

    @State private var canDismiss = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [Color(hex: "1a1025"), Color(hex: "0f1a2e")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Streak badge
            HStack(spacing: 4) {
                Text("🔥").font(.system(size: 12))
                Text("\(streakStore.count) day streak")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "a78bfa"))
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Color(hex: "a78bfa").opacity(0.1))
            .overlay(Capsule().stroke(Color(hex: "a78bfa").opacity(0.2), lineWidth: 1))
            .clipShape(Capsule())
            .padding(20)

            VStack(spacing: 16) {
                LinearGradient(colors: [.clear, Color(hex: "a78bfa"), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 40, height: 1)

                Text("\(repeatTotal) of \(repeatTotal) complete.")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundColor(Color(hex: "e2e8f0"))

                VStack(spacing: 8) {
                    Text("\u{201C}\(currentMessage.text)\u{201D}")
                        .font(.system(size: 13)).italic()
                        .foregroundColor(Color(hex: "7c6fa0"))
                        .multilineTextAlignment(.center).lineSpacing(4)
                        .frame(maxWidth: 340)
                    if let attr = currentMessage.attribution {
                        Text("— \(attr)").font(.system(size: 11)).foregroundColor(Color(hex: "3d3550"))
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 14)
                .background(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.07), lineWidth: 1))
                .cornerRadius(10)

                LinearGradient(colors: [.clear, Color(hex: "a78bfa"), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 40, height: 1)

                if canDismiss {
                    Text("click anywhere to continue")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "374151"))
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .contentShape(Rectangle())
        .onTapGesture { if canDismiss { onDismiss() } }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { canDismiss = true }
            }
        }
    }
}
```

- [ ] **Step 2: Add `showCompletion` to OverlayWindowController**

Add this method after `hide()`:
```swift
func showCompletion(
    repeatTotal: Int,
    streakStore: StreakStore,
    message: Message,
    onDismiss: @escaping () -> Void
) {
    guard windows.isEmpty else { return }
    for screen in NSScreen.screens {
        let window = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: BlockCompletionView(
            repeatTotal: repeatTotal,
            currentMessage: message,
            streakStore: streakStore,
            onDismiss: onDismiss
        ))
        windows.append(window)
        window.orderFront(nil)
    }
    windows.forEach { $0.alphaValue = 0 }
    NSAnimationContext.runAnimationGroup { ctx in
        ctx.duration = 0.4
        ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
        windows.forEach { $0.animator().alphaValue = 1 }
    }
    NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
}
```

- [ ] **Step 3: Update AppDelegate.onBreakStart to route last-session to completion overlay**

Replace the `viewModel.onBreakStart` closure:
```swift
viewModel.onBreakStart = { [weak self] in
    guard let self else { return }
    let message = self.messageStore.nextMessage()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        if self.viewModel.isLastRepeat {
            let total = self.viewModel.repeatTotal
            self.overlayController.showCompletion(
                repeatTotal: total,
                streakStore: self.streakStore,
                message: message,
                onDismiss: {
                    self.viewModel.completeBlock()
                    self.overlayController.hide()
                }
            )
        } else {
            self.overlayController.show(
                viewModel: self.viewModel,
                streakStore: self.streakStore,
                message: message
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.viewModel._forceBreakActive()
            }
        }
    }
}
```

- [ ] **Step 4: Build and run full test suite**

```bash
cd Otium && xcodebuild test -scheme Otium -destination 'platform=macOS' 2>&1 | grep -E "passed|failed|BUILD"
```
Expected: `BUILD SUCCEEDED`, all tests pass except pre-existing `testExtensionExpiry`.

- [ ] **Step 5: Commit and push**

```bash
cd Otium && git add Otium/Views/BlockCompletionView.swift Otium/Overlay/OverlayWindowController.swift Otium/AppDelegate.swift docs/superpowers/specs/2026-04-17-feature2-repeated-sessions.md
git commit -m "feat: repeated sessions with completion overlay"
git push
```

---

## Verification

1. Open the app → Focus tab shows a small muted "Repeat ▼" below duration picker
2. Tap "Repeat" → stepper panel expands (× 2 min), Start button becomes "Start 2 × 25m"
3. Tap "Repeat ▲" → panel collapses, Start button back to "Start Session"
4. Set repeat × 2, start → two session dots appear below ring (first glowing)
5. Let first session expire → break overlay shows, break counts down, then second session auto-starts (second dot glows)
6. Let second session expire → completion overlay: "2 of 2 complete.", no countdown
7. After 3s → "click anywhere to continue" appears; tap → goes to idle
8. Session history shows two logged sessions
