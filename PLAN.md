# Otium Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar app that enforces structured work/break intervals with a fullscreen overlay, streak tracking, and session history.

**Architecture:** A SwiftUI/AppKit hybrid — SwiftUI for all views (popover + overlay), AppKit for the status bar item, popover presentation, and multi-monitor overlay windows. A central `TimerViewModel` owns the state machine; three stores (`StreakStore`, `SessionStore`, `MessageStore`) own persistence via `UserDefaults`. The app runs as a background-only process with no Dock icon.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, XCTest, UserDefaults (no external dependencies)

---

## File Map

```
Otium/
├── OtiumApp.swift                  # @main, NSApplicationDelegateAdaptor
├── AppDelegate.swift                    # Wires all components, handles sleep/wake
├── Models/
│   ├── Session.swift                    # Session + SessionOutcome Codable types
│   ├── TimerState.swift                 # TimerState enum
│   └── Message.swift                   # Message struct (text + optional attribution)
├── Stores/
│   ├── StreakStore.swift                # Streak count + date logic, UserDefaults
│   ├── SessionStore.swift              # Session history, 90-day pruning, weekly data
│   └── MessageStore.swift             # Default + custom messages, shuffled queue
├── ViewModels/
│   └── TimerViewModel.swift            # State machine, countdown, break lifecycle
├── MenuBar/
│   └── StatusBarController.swift       # NSStatusItem, ring+countdown icon, popover
├── Overlay/
│   └── OverlayWindowController.swift   # NSWindow per screen, fade in/out
└── Views/
    ├── PopoverView.swift               # Root popover container
    ├── TimerControlView.swift          # Duration picker + start/stop button
    ├── SessionHistoryView.swift        # Today's list + weekly bar chart
    ├── MessagesSettingsView.swift      # Add/delete/reset messages
    └── BreakOverlayView.swift          # Fullscreen break overlay content

OtiumTests/
├── StreakStoreTests.swift
├── SessionStoreTests.swift
├── MessageStoreTests.swift
└── TimerViewModelTests.swift
```

---

## Task 1: Xcode Project Setup

**Files:**
- Create: `Otium.xcodeproj` (via Xcode GUI)
- Create: `.gitignore`
- Create: `Otium/Info.plist` (set LSUIElement)

- [ ] **Step 1: Create the Xcode project**

  In Xcode: File → New → Project → macOS → App
  - Product Name: `Otium`
  - Bundle Identifier: `com.yourname.otium`
  - Interface: SwiftUI
  - Language: Swift
  - Uncheck "Include Tests" (we'll add the test target manually)
  - Save to `/Users/samyarrafatzand/Projects/timer/`

- [ ] **Step 2: Add test target**

  In Xcode: File → New → Target → macOS → Unit Testing Bundle
  - Product Name: `OtiumTests`
  - Target to be tested: `Otium`

- [ ] **Step 3: Set LSUIElement (no Dock icon)**

  In `Otium/Info.plist`, add the key `Application is agent (UIElement)` = `YES`
  (raw key: `LSUIElement`, type: Boolean, value: YES)

- [ ] **Step 4: Set minimum deployment target**

  In the project settings → Otium target → General → Minimum Deployments: macOS 14.0

- [ ] **Step 5: Create .gitignore**

  Create `/Users/samyarrafatzand/Projects/timer/.gitignore`:
  ```
  .DS_Store
  *.xcuserstate
  xcuserdata/
  DerivedData/
  .build/
  .superpowers/
  ```

- [ ] **Step 6: Initialise git and push**

  ```bash
  cd /Users/samyarrafatzand/Projects/timer
  git init
  git add .gitignore PRD.md PLAN.md README.md docs/
  git commit -m "chore: project setup with PRD, PLAN, and gitignore"
  git remote add origin <your-github-repo-url>
  git push -u origin main
  ```

---

## Task 2: Models

**Files:**
- Create: `Otium/Models/Session.swift`
- Create: `Otium/Models/TimerState.swift`
- Create: `Otium/Models/Message.swift`

- [ ] **Step 1: Create `TimerState.swift`**

  ```swift
  // Otium/Models/TimerState.swift
  enum TimerState: Equatable {
      case idle
      case running
      case breakPending   // animating overlay in
      case breakActive    // overlay visible, break countdown running
      case extended       // 5-min extension countdown
  }
  ```

- [ ] **Step 2: Create `Session.swift`**

  ```swift
  // Otium/Models/Session.swift
  import Foundation

  enum SessionOutcome: String, Codable {
      case completed   // break respected (with or without extension)
      case overridden  // user hit Override
  }

  struct Session: Codable, Identifiable {
      let id: UUID
      let startTime: Date
      let plannedDuration: TimeInterval
      let actualDuration: TimeInterval
      let extendUsed: Bool
      let outcome: SessionOutcome

      init(
          startTime: Date,
          plannedDuration: TimeInterval,
          actualDuration: TimeInterval,
          extendUsed: Bool,
          outcome: SessionOutcome
      ) {
          self.id = UUID()
          self.startTime = startTime
          self.plannedDuration = plannedDuration
          self.actualDuration = actualDuration
          self.extendUsed = extendUsed
          self.outcome = outcome
      }
  }
  ```

- [ ] **Step 3: Create `Message.swift`**

  ```swift
  // Otium/Models/Message.swift
  import Foundation

  struct Message: Equatable, Identifiable {
      let id: UUID
      let text: String
      let attribution: String?
      let isDefault: Bool

      init(text: String, attribution: String? = nil, isDefault: Bool = false) {
          self.id = UUID()
          self.text = text
          self.attribution = attribution
          self.isDefault = isDefault
      }
  }

  // For persisting custom messages to UserDefaults
  struct CustomMessageRecord: Codable {
      let text: String
      let attribution: String?
  }
  ```

- [ ] **Step 4: Commit**

  ```bash
  git add Otium/Models/
  git commit -m "feat: add Session, TimerState, and Message models"
  git push
  ```

---

## Task 3: StreakStore

**Files:**
- Create: `Otium/Stores/StreakStore.swift`
- Create: `OtiumTests/StreakStoreTests.swift`

- [ ] **Step 1: Write failing tests**

  ```swift
  // OtiumTests/StreakStoreTests.swift
  import XCTest
  @testable import Otium

  final class StreakStoreTests: XCTestCase {
      var store: StreakStore!
      let suiteName = "test.streak.\(UUID().uuidString)"

      override func setUp() {
          super.setUp()
          let defaults = UserDefaults(suiteName: suiteName)!
          store = StreakStore(defaults: defaults)
      }

      override func tearDown() {
          UserDefaults().removePersistentDomain(forName: suiteName)
          super.tearDown()
      }

      func testInitialStreakIsZero() {
          XCTAssertEqual(store.count, 0)
      }

      func testRecordCleanSession_incrementsStreak() {
          store.recordCleanSession()
          XCTAssertEqual(store.count, 1)
      }

      func testRecordCleanSession_onlyIncrementsOncePerDay() {
          store.recordCleanSession()
          store.recordCleanSession()
          XCTAssertEqual(store.count, 1)
      }

      func testRecordOverride_resetsStreakToZero() {
          store.recordCleanSession()
          XCTAssertEqual(store.count, 1)
          store.recordOverride()
          XCTAssertEqual(store.count, 0)
      }

      func testGapInUsage_doesNotBreakStreak() {
          // Simulate 5-day streak from 3 days ago
          let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
          store._setCount(5, lastCompletedDate: threeDaysAgo)
          // Record session today — should increment to 6, not reset
          store.recordCleanSession()
          XCTAssertEqual(store.count, 6)
      }

      func testOverrideToday_preventsStreakIncrementToday() {
          store.recordOverride()
          store.recordCleanSession()
          XCTAssertEqual(store.count, 0)
      }

      func testStreakPersistsAcrossInstances() {
          let defaults = UserDefaults(suiteName: suiteName)!
          store.recordCleanSession()
          let store2 = StreakStore(defaults: defaults)
          XCTAssertEqual(store2.count, 1)
      }
  }
  ```

- [ ] **Step 2: Run tests — verify they fail**

  In Xcode: Product → Test (⌘U)
  Expected: All `StreakStoreTests` fail with "cannot find type 'StreakStore' in scope"

- [ ] **Step 3: Implement `StreakStore`**

  ```swift
  // Otium/Stores/StreakStore.swift
  import Foundation

  final class StreakStore: ObservableObject {
      @Published private(set) var count: Int
      private(set) var lastCompletedDate: Date?
      private(set) var lastOverrideDate: Date?

      private let defaults: UserDefaults
      private let calendar = Calendar.current

      private enum Keys {
          static let count = "streak.count"
          static let lastCompleted = "streak.lastCompletedDate"
          static let lastOverride = "streak.lastOverrideDate"
      }

      init(defaults: UserDefaults = .standard) {
          self.defaults = defaults
          self.count = defaults.integer(forKey: Keys.count)
          self.lastCompletedDate = defaults.object(forKey: Keys.lastCompleted) as? Date
          self.lastOverrideDate = defaults.object(forKey: Keys.lastOverride) as? Date
      }

      func recordCleanSession() {
          let today = calendar.startOfDay(for: Date())
          // Already recorded today
          if let last = lastCompletedDate, calendar.isDate(last, inSameDayAs: today) { return }
          // Override happened today — no increment
          if let override = lastOverrideDate, calendar.isDate(override, inSameDayAs: today) { return }
          count += 1
          lastCompletedDate = today
          persist()
      }

      func recordOverride() {
          count = 0
          lastOverrideDate = calendar.startOfDay(for: Date())
          persist()
      }

      // Internal setter for testing — allows injecting past dates
      func _setCount(_ value: Int, lastCompletedDate: Date?) {
          count = value
          self.lastCompletedDate = lastCompletedDate
          persist()
      }

      private func persist() {
          defaults.set(count, forKey: Keys.count)
          defaults.set(lastCompletedDate, forKey: Keys.lastCompleted)
          defaults.set(lastOverrideDate, forKey: Keys.lastOverride)
      }
  }
  ```

- [ ] **Step 4: Run tests — verify they pass**

  Product → Test (⌘U). All `StreakStoreTests` should be green.

- [ ] **Step 5: Commit**

  ```bash
  git add Otium/Stores/StreakStore.swift OtiumTests/StreakStoreTests.swift
  git commit -m "feat: add StreakStore with persistence and gap-neutral logic"
  git push
  ```

---

## Task 4: SessionStore

**Files:**
- Create: `Otium/Stores/SessionStore.swift`
- Create: `OtiumTests/SessionStoreTests.swift`

- [ ] **Step 1: Write failing tests**

  ```swift
  // OtiumTests/SessionStoreTests.swift
  import XCTest
  @testable import Otium

  final class SessionStoreTests: XCTestCase {
      var store: SessionStore!
      let suiteName = "test.sessions.\(UUID().uuidString)"

      override func setUp() {
          super.setUp()
          let defaults = UserDefaults(suiteName: suiteName)!
          store = SessionStore(defaults: defaults)
      }

      override func tearDown() {
          UserDefaults().removePersistentDomain(forName: suiteName)
          super.tearDown()
      }

      func makeSession(
          startTime: Date = Date(),
          duration: TimeInterval = 25 * 60,
          outcome: SessionOutcome = .completed
      ) -> Session {
          Session(startTime: startTime, plannedDuration: duration, actualDuration: duration, extendUsed: false, outcome: outcome)
      }

      func testAddSession_appearsInHistory() {
          let s = makeSession()
          store.add(s)
          XCTAssertEqual(store.sessions.count, 1)
          XCTAssertEqual(store.sessions.first?.id, s.id)
      }

      func testTodaysSessions_excludesYesterday() {
          let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
          store.add(makeSession(startTime: yesterday))
          store.add(makeSession(startTime: Date()))
          XCTAssertEqual(store.todaysSessions.count, 1)
      }

      func testTodaysFocusTime_sumsActualDurations() {
          store.add(makeSession(duration: 25 * 60))
          store.add(makeSession(duration: 45 * 60))
          XCTAssertEqual(store.todaysFocusTime, 70 * 60, accuracy: 1)
      }

      func testPruneOldSessions_removesSessionsOlderThan90Days() {
          let old = Calendar.current.date(byAdding: .day, value: -91, to: Date())!
          store.add(makeSession(startTime: old))
          store.add(makeSession(startTime: Date()))
          // Re-init triggers pruning
          let defaults = UserDefaults(suiteName: suiteName)!
          let store2 = SessionStore(defaults: defaults)
          XCTAssertEqual(store2.sessions.count, 1)
      }

      func testWeeklyMinutes_sumsCorrectlyForToday() {
          store.add(makeSession(duration: 25 * 60))  // 25 min today
          let weekday = Calendar.current.component(.weekday, from: Date())
          let result = store.weeklyMinutes()
          XCTAssertEqual(result[weekday] ?? 0, 25, accuracy: 0.1)
      }

      func testSessionsPersistAcrossInstances() {
          store.add(makeSession())
          let defaults = UserDefaults(suiteName: suiteName)!
          let store2 = SessionStore(defaults: defaults)
          XCTAssertEqual(store2.sessions.count, 1)
      }
  }
  ```

- [ ] **Step 2: Run tests — verify they fail**

  Product → Test (⌘U). Expected: all `SessionStoreTests` fail.

- [ ] **Step 3: Implement `SessionStore`**

  ```swift
  // Otium/Stores/SessionStore.swift
  import Foundation

  final class SessionStore: ObservableObject {
      @Published private(set) var sessions: [Session] = []

      private let defaults: UserDefaults
      private let retentionDays = 90
      private let key = "sessions"

      init(defaults: UserDefaults = .standard) {
          self.defaults = defaults
          load()
          pruneOldSessions()
      }

      func add(_ session: Session) {
          sessions.append(session)
          save()
      }

      var todaysSessions: [Session] {
          let cal = Calendar.current
          return sessions.filter { cal.isDateInToday($0.startTime) }
      }

      var todaysFocusTime: TimeInterval {
          todaysSessions.reduce(0) { $0 + $1.actualDuration }
      }

      /// Returns weekday (1=Sun … 7=Sat) → total focus minutes for the current week.
      func weeklyMinutes() -> [Int: Double] {
          let cal = Calendar.current
          let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
          var result = [Int: Double]()
          for session in sessions where session.startTime >= weekStart {
              let weekday = cal.component(.weekday, from: session.startTime)
              result[weekday, default: 0] += session.actualDuration / 60
          }
          return result
      }

      private func pruneOldSessions() {
          guard let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) else { return }
          let before = sessions.count
          sessions = sessions.filter { $0.startTime > cutoff }
          if sessions.count != before { save() }
      }

      private func load() {
          guard let data = defaults.data(forKey: key),
                let decoded = try? JSONDecoder().decode([Session].self, from: data)
          else { return }
          sessions = decoded
      }

      private func save() {
          guard let data = try? JSONEncoder().encode(sessions) else { return }
          defaults.set(data, forKey: key)
      }
  }
  ```

- [ ] **Step 4: Run tests — verify they pass**

- [ ] **Step 5: Commit**

  ```bash
  git add Otium/Stores/SessionStore.swift OtiumTests/SessionStoreTests.swift
  git commit -m "feat: add SessionStore with history, pruning, and weekly aggregation"
  git push
  ```

---

## Task 5: MessageStore

**Files:**
- Create: `Otium/Stores/MessageStore.swift`
- Create: `OtiumTests/MessageStoreTests.swift`

- [ ] **Step 1: Write failing tests**

  ```swift
  // OtiumTests/MessageStoreTests.swift
  import XCTest
  @testable import Otium

  final class MessageStoreTests: XCTestCase {
      var store: MessageStore!
      let suiteName = "test.messages.\(UUID().uuidString)"

      override func setUp() {
          super.setUp()
          let defaults = UserDefaults(suiteName: suiteName)!
          store = MessageStore(defaults: defaults)
      }

      override func tearDown() {
          UserDefaults().removePersistentDomain(forName: suiteName)
          super.tearDown()
      }

      func testDefaultMessagesLoaded() {
          XCTAssertFalse(store.allMessages.isEmpty)
      }

      func testNextMessage_cyclesThroughAllBeforeRepeating() {
          let total = store.allMessages.count
          var seen = Set<String>()
          for _ in 0..<total {
              seen.insert(store.nextMessage().text)
          }
          XCTAssertEqual(seen.count, total, "Should see every message exactly once before repeating")
      }

      func testAddCustomMessage_appearsInRotation() {
          store.addCustom(text: "My custom quote", attribution: nil)
          let texts = store.allMessages.map { $0.text }
          XCTAssertTrue(texts.contains("My custom quote"))
      }

      func testDeleteDefaultMessage_removesFromRotation() {
          let first = store.allMessages.first!
          store.delete(first)
          let texts = store.allMessages.map { $0.text }
          XCTAssertFalse(texts.contains(first.text))
      }

      func testResetToDefaults_restoresDeletedDefaults() {
          let first = store.allMessages.first!
          store.delete(first)
          store.resetToDefaults()
          let texts = store.allMessages.map { $0.text }
          XCTAssertTrue(texts.contains(first.text))
      }

      func testResetToDefaults_removesCustomMessages() {
          store.addCustom(text: "Custom", attribution: nil)
          store.resetToDefaults()
          XCTAssertFalse(store.allMessages.map { $0.text }.contains("Custom"))
      }

      func testFallbackMessageWhenAllDeleted() {
          for msg in store.allMessages { store.delete(msg) }
          let next = store.nextMessage()
          XCTAssertFalse(next.text.isEmpty)
      }

      func testCustomMessagesPersistAcrossInstances() {
          store.addCustom(text: "Persistent", attribution: "Me")
          let defaults = UserDefaults(suiteName: suiteName)!
          let store2 = MessageStore(defaults: defaults)
          XCTAssertTrue(store2.allMessages.map { $0.text }.contains("Persistent"))
      }
  }
  ```

- [ ] **Step 2: Run tests — verify they fail**

- [ ] **Step 3: Implement `MessageStore`**

  ```swift
  // Otium/Stores/MessageStore.swift
  import Foundation

  final class MessageStore: ObservableObject {
      @Published private(set) var allMessages: [Message] = []

      private let defaults: UserDefaults
      private var shuffleQueue: [Message] = []

      private enum Keys {
          static let custom = "messages.custom"
          static let deletedIds = "messages.deletedDefaultIds"
      }

      private static let defaults_: [(text: String, attribution: String)] = [
          ("The mind must be given relaxation — it will rise improved and sharper after a good break.", "Seneca"),
          ("Just as rich fields must not be forced — for they will quickly lose their fertility — constant work on the anvil will fracture the force of the mind.", "Seneca"),
          ("Retire into yourself as much as you can.", "Seneca"),
          ("Confine yourself to the present.", "Marcus Aurelius"),
          ("He who is everywhere is nowhere.", "Seneca"),
          ("We suffer more in imagination than in reality.", "Seneca"),
          ("No man is free who is not master of himself.", "Epictetus"),
      ]

      private static let fallback = Message(text: "Time to take a break.", attribution: nil, isDefault: true)

      init(defaults: UserDefaults = .standard) {
          self.defaults = defaults
          rebuild()
      }

      func nextMessage() -> Message {
          if allMessages.isEmpty { return Self.fallback }
          if shuffleQueue.isEmpty { shuffleQueue = allMessages.shuffled() }
          return shuffleQueue.removeFirst()
      }

      func addCustom(text: String, attribution: String?) {
          let record = CustomMessageRecord(text: text, attribution: attribution)
          var existing = loadCustomRecords()
          existing.append(record)
          saveCustomRecords(existing)
          rebuild()
      }

      func delete(_ message: Message) {
          if message.isDefault {
              // Find index in defaults_ and record it as deleted
              if let idx = Self.defaults_.firstIndex(where: { $0.text == message.text }) {
                  var deleted = loadDeletedIds()
                  deleted.insert(idx)
                  defaults.set(Array(deleted), forKey: Keys.deletedIds)
              }
          } else {
              var records = loadCustomRecords()
              records.removeAll { $0.text == message.text }
              saveCustomRecords(records)
          }
          shuffleQueue.removeAll { $0.text == message.text }
          rebuild()
      }

      func resetToDefaults() {
          defaults.removeObject(forKey: Keys.deletedIds)
          defaults.removeObject(forKey: Keys.custom)
          shuffleQueue = []
          rebuild()
      }

      private func rebuild() {
          let deleted = loadDeletedIds()
          let defaultMessages: [Message] = Self.defaults_.enumerated().compactMap { idx, pair in
              guard !deleted.contains(idx) else { return nil }
              return Message(text: pair.text, attribution: pair.attribution, isDefault: true)
          }
          let customMessages: [Message] = loadCustomRecords().map {
              Message(text: $0.text, attribution: $0.attribution, isDefault: false)
          }
          allMessages = defaultMessages + customMessages
          // Purge queue entries that no longer exist
          let texts = Set(allMessages.map { $0.text })
          shuffleQueue = shuffleQueue.filter { texts.contains($0.text) }
      }

      private func loadDeletedIds() -> Set<Int> {
          Set(defaults.array(forKey: Keys.deletedIds) as? [Int] ?? [])
      }

      private func loadCustomRecords() -> [CustomMessageRecord] {
          guard let data = defaults.data(forKey: Keys.custom),
                let records = try? JSONDecoder().decode([CustomMessageRecord].self, from: data)
          else { return [] }
          return records
      }

      private func saveCustomRecords(_ records: [CustomMessageRecord]) {
          guard let data = try? JSONEncoder().encode(records) else { return }
          defaults.set(data, forKey: Keys.custom)
      }
  }
  ```

- [ ] **Step 4: Run tests — verify they pass**

- [ ] **Step 5: Commit**

  ```bash
  git add Otium/Stores/MessageStore.swift OtiumTests/MessageStoreTests.swift
  git commit -m "feat: add MessageStore with shuffled rotation, custom messages, and reset"
  git push
  ```

---

## Task 6: TimerViewModel

**Files:**
- Create: `Otium/ViewModels/TimerViewModel.swift`
- Create: `OtiumTests/TimerViewModelTests.swift`

- [ ] **Step 1: Write failing tests**

  ```swift
  // OtiumTests/TimerViewModelTests.swift
  import XCTest
  @testable import Otium

  final class TimerViewModelTests: XCTestCase {
      var vm: TimerViewModel!
      var streakStore: StreakStore!
      var sessionStore: SessionStore!
      var messageStore: MessageStore!
      let suiteName = "test.vm.\(UUID().uuidString)"

      override func setUp() {
          super.setUp()
          let defaults = UserDefaults(suiteName: suiteName)!
          streakStore = StreakStore(defaults: defaults)
          sessionStore = SessionStore(defaults: defaults)
          messageStore = MessageStore(defaults: defaults)
          vm = TimerViewModel(streakStore: streakStore, sessionStore: sessionStore)
      }

      override func tearDown() {
          UserDefaults().removePersistentDomain(forName: suiteName)
          super.tearDown()
      }

      func testInitialStateIsIdle() {
          XCTAssertEqual(vm.state, .idle)
      }

      func testStartSession_setsStateToRunning() {
          vm.startSession(duration: 25 * 60)
          XCTAssertEqual(vm.state, .running)
      }

      func testStartSession_resetsExtendUsed() {
          vm.startSession(duration: 10)
          vm._simulateTick(count: 10)  // exhaust
          vm.useExtension()
          vm.stopSession()
          vm.startSession(duration: 25 * 60)
          XCTAssertFalse(vm.extendUsed)
      }

      func testStopSession_returnsToIdle() {
          vm.startSession(duration: 25 * 60)
          vm.stopSession()
          XCTAssertEqual(vm.state, .idle)
      }

      func testStopSession_doesNotLogSession() {
          vm.startSession(duration: 25 * 60)
          vm.stopSession()
          XCTAssertEqual(sessionStore.sessions.count, 0)
      }

      func testCountdownTick_decrementsTimeRemaining() {
          vm.startSession(duration: 60)
          vm._simulateTick(count: 1)
          XCTAssertEqual(vm.timeRemaining, 59, accuracy: 1)
      }

      func testSessionExpiry_transitionsToBreakPending() {
          vm.startSession(duration: 2)
          vm._simulateTick(count: 2)
          XCTAssertEqual(vm.state, .breakPending)
      }

      func testUseExtension_marksExtendUsedAndStartsExtension() {
          vm.startSession(duration: 2)
          vm._simulateTick(count: 2)
          vm._forceBreakActive()
          vm.useExtension()
          XCTAssertTrue(vm.extendUsed)
          XCTAssertEqual(vm.state, .extended)
      }

      func testUseExtension_canOnlyBeUsedOnce() {
          vm.startSession(duration: 2)
          vm._simulateTick(count: 2)
          vm._forceBreakActive()
          vm.useExtension()
          let stateAfterFirst = vm.state
          vm.useExtension()
          XCTAssertEqual(vm.state, stateAfterFirst)
      }

      func testOverride_resetsStreakAndLogsSession() {
          streakStore.recordCleanSession()
          XCTAssertEqual(streakStore.count, 1)
          vm.startSession(duration: 2)
          vm._simulateTick(count: 2)
          vm._forceBreakActive()
          vm.triggerOverride()
          XCTAssertEqual(streakStore.count, 0)
          XCTAssertEqual(sessionStore.sessions.first?.outcome, .overridden)
      }

      func testBreakCompletion_logsCompletedSessionAndIncrementsStreak() {
          vm.startSession(duration: 2)
          vm._simulateTick(count: 2)
          vm._forceBreakActive()
          vm._simulateBreakTick(count: 5 * 60)
          XCTAssertEqual(sessionStore.sessions.first?.outcome, .completed)
          XCTAssertEqual(streakStore.count, 1)
      }

      func testElapsedFraction_calculatesCorrectly() {
          vm.startSession(duration: 100)
          vm._simulateTick(count: 25)
          XCTAssertEqual(vm.elapsedFraction, 0.25, accuracy: 0.01)
      }
  }
  ```

- [ ] **Step 2: Run tests — verify they fail**

- [ ] **Step 3: Implement `TimerViewModel`**

  ```swift
  // Otium/ViewModels/TimerViewModel.swift
  import Foundation
  import Combine

  @MainActor
  final class TimerViewModel: ObservableObject {
      @Published private(set) var state: TimerState = .idle
      @Published private(set) var timeRemaining: TimeInterval = 0
      @Published private(set) var breakTimeRemaining: TimeInterval = 5 * 60
      @Published private(set) var extendUsed: Bool = false
      @Published private(set) var sessionDuration: TimeInterval = 25 * 60

      // Called by OverlayWindowController
      var onBreakStart: (() -> Void)?
      var onBreakEnd: (() -> Void)?

      private var timer: Timer?
      private var sessionStartTime: Date?
      private var sleepStartTime: Date?

      private let streakStore: StreakStore
      private let sessionStore: SessionStore

      init(streakStore: StreakStore, sessionStore: SessionStore) {
          self.streakStore = streakStore
          self.sessionStore = sessionStore
      }

      // MARK: - Public API

      func startSession(duration: TimeInterval) {
          stopTimer()
          state = .running
          sessionDuration = duration
          timeRemaining = duration
          extendUsed = false
          sessionStartTime = Date()
          startTimer()
      }

      func stopSession() {
          stopTimer()
          state = .idle
          sessionStartTime = nil
      }

      func useExtension() {
          guard state == .breakActive, !extendUsed else { return }
          extendUsed = true
          state = .extended
          timeRemaining = 5 * 60
          onBreakEnd?()
          startTimer()
      }

      func triggerOverride() {
          stopTimer()
          let elapsed = sessionStartTime.map { Date().timeIntervalSince($0) } ?? sessionDuration
          sessionStore.add(Session(
              startTime: sessionStartTime ?? Date(),
              plannedDuration: sessionDuration,
              actualDuration: elapsed,
              extendUsed: extendUsed,
              outcome: .overridden
          ))
          streakStore.recordOverride()
          state = .idle
          sessionStartTime = nil
          onBreakEnd?()
      }

      var elapsedFraction: Double {
          guard sessionDuration > 0 else { return 0 }
          let elapsed = sessionDuration - timeRemaining
          return min(max(elapsed / sessionDuration, 0), 1)
      }

      // MARK: - Sleep / Wake

      func handleSystemWillSleep() {
          sleepStartTime = Date()
      }

      func handleSystemDidWake() {
          guard let slept = sleepStartTime else { return }
          let sleptFor = Date().timeIntervalSince(slept)
          sleepStartTime = nil
          guard state == .running || state == .extended else { return }
          timeRemaining = max(timeRemaining - sleptFor, 0)
          if timeRemaining == 0 { sessionExpired() }
      }

      // MARK: - Timer

      private func startTimer() {
          timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
              Task { @MainActor [weak self] in self?.tick() }
          }
      }

      private func stopTimer() {
          timer?.invalidate()
          timer = nil
      }

      // Internal for testing
      func _simulateTick(count: Int) {
          for _ in 0..<count { tick() }
      }

      func _simulateBreakTick(count: Int) {
          for _ in 0..<count { breakTick() }
      }

      func _forceBreakActive() {
          state = .breakActive
          breakTimeRemaining = 5 * 60
      }

      private func tick() {
          switch state {
          case .running, .extended:
              if timeRemaining > 0 {
                  timeRemaining -= 1
              } else {
                  sessionExpired()
              }
          case .breakActive:
              breakTick()
          default:
              break
          }
      }

      private func breakTick() {
          if breakTimeRemaining > 0 {
              breakTimeRemaining -= 1
          } else {
              completeBreak()
          }
      }

      private func sessionExpired() {
          stopTimer()
          state = .breakPending
          onBreakStart?()
          // Overlay controller listens to state; after animation it calls _forceBreakActive()
      }

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
          state = .idle
          sessionStartTime = nil
          onBreakEnd?()
      }
  }
  ```

- [ ] **Step 4: Run tests — verify they pass**

- [ ] **Step 5: Commit**

  ```bash
  git add Otium/ViewModels/TimerViewModel.swift OtiumTests/TimerViewModelTests.swift
  git commit -m "feat: add TimerViewModel state machine with sleep/wake and override handling"
  git push
  ```

---

## Task 7: Break Overlay View

**Files:**
- Create: `Otium/Views/BreakOverlayView.swift`

- [ ] **Step 1: Create `BreakOverlayView.swift`**

  ```swift
  // Otium/Views/BreakOverlayView.swift
  import SwiftUI

  struct BreakOverlayView: View {
      @ObservedObject var viewModel: TimerViewModel
      @ObservedObject var streakStore: StreakStore
      let currentMessage: Message

      private var breakMinutes: Int { Int(viewModel.breakTimeRemaining) / 60 }
      private var breakSeconds: Int { Int(viewModel.breakTimeRemaining) % 60 }

      var body: some View {
          ZStack(alignment: .topTrailing) {
              // Background
              LinearGradient(
                  colors: [Color(hex: "1a1025"), Color(hex: "0f1a2e")],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
              )
              .ignoresSafeArea()

              // Streak badge
              streakBadge
                  .padding(20)

              // Centered content
              VStack(spacing: 16) {
                  divider

                  // Fixed headline
                  Text("It's time to take a break.")
                      .font(.system(size: 26, weight: .regular, design: .default))
                      .foregroundColor(Color(hex: "e2e8f0"))

                  // Rotating stoic quote card
                  quoteCard

                  divider

                  // Break countdown
                  Text("5 MINUTE BREAK")
                      .font(.system(size: 11, weight: .regular))
                      .tracking(3)
                      .foregroundColor(Color(hex: "6d5a8a"))

                  Text(String(format: "%d:%02d", breakMinutes, breakSeconds))
                      .font(.system(size: 38, weight: .ultraLight, design: .monospaced))
                      .foregroundColor(Color(hex: "a78bfa"))

                  // Buttons
                  HStack(spacing: 10) {
                      if !viewModel.extendUsed {
                          pillButton(label: "5 More Minutes", primary: true) {
                              viewModel.useExtension()
                          }
                      }
                      pillButton(label: "Override", primary: false) {
                          viewModel.triggerOverride()
                      }
                  }
                  .padding(.top, 4)
              }
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
      }

      private var streakBadge: some View {
          HStack(spacing: 4) {
              Text("🔥")
                  .font(.system(size: 12))
              Text("\(streakStore.count) day streak")
                  .font(.system(size: 11, weight: .medium))
                  .foregroundColor(Color(hex: "a78bfa"))
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 4)
          .background(Color(hex: "a78bfa").opacity(0.1))
          .overlay(
              Capsule().stroke(Color(hex: "a78bfa").opacity(0.2), lineWidth: 1)
          )
          .clipShape(Capsule())
      }

      private var quoteCard: some View {
          VStack(spacing: 8) {
              Text(""\(currentMessage.text)"")
                  .font(.system(size: 13))
                  .italic()
                  .foregroundColor(Color(hex: "7c6fa0"))
                  .multilineTextAlignment(.center)
                  .lineSpacing(4)
                  .frame(maxWidth: 340)

              if let attribution = currentMessage.attribution {
                  Text("— \(attribution)")
                      .font(.system(size: 11))
                      .foregroundColor(Color(hex: "3d3550"))
              }
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 14)
          .background(Color.white.opacity(0.03))
          .overlay(
              RoundedRectangle(cornerRadius: 10)
                  .stroke(Color.white.opacity(0.07), lineWidth: 1)
          )
          .cornerRadius(10)
      }

      private var divider: some View {
          LinearGradient(
              colors: [.clear, Color(hex: "a78bfa"), .clear],
              startPoint: .leading,
              endPoint: .trailing
          )
          .frame(width: 40, height: 1)
      }

      private func pillButton(label: String, primary: Bool, action: @escaping () -> Void) -> some View {
          Button(action: action) {
              Text(label)
                  .font(.system(size: 12))
                  .foregroundColor(primary ? Color(hex: "a78bfa") : Color(hex: "374151"))
                  .padding(.horizontal, 20)
                  .padding(.vertical, 9)
                  .background(primary ? Color(hex: "a78bfa").opacity(0.12) : Color.white.opacity(0.03))
                  .overlay(
                      Capsule().stroke(
                          primary ? Color(hex: "a78bfa").opacity(0.25) : Color.white.opacity(0.06),
                          lineWidth: 1
                      )
                  )
                  .clipShape(Capsule())
          }
          .buttonStyle(.plain)
      }
  }

  // MARK: - Color hex helper
  extension Color {
      init(hex: String) {
          let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
          var int: UInt64 = 0
          Scanner(string: hex).scanHexInt64(&int)
          let r = Double((int >> 16) & 0xFF) / 255
          let g = Double((int >> 8) & 0xFF) / 255
          let b = Double(int & 0xFF) / 255
          self.init(red: r, green: g, blue: b)
      }
  }
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add Otium/Views/BreakOverlayView.swift
  git commit -m "feat: add BreakOverlayView with fixed headline, rotating quote card, and pill buttons"
  git push
  ```

---

## Task 8: Overlay Window Controller

**Files:**
- Create: `Otium/Overlay/OverlayWindowController.swift`

- [ ] **Step 1: Create `OverlayWindowController.swift`**

  ```swift
  // Otium/Overlay/OverlayWindowController.swift
  import AppKit
  import SwiftUI

  final class OverlayWindowController {
      private var windows: [NSWindow] = []

      func show(
          viewModel: TimerViewModel,
          streakStore: StreakStore,
          message: Message
      ) {
          guard windows.isEmpty else { return }

          for screen in NSScreen.screens {
              let window = makeWindow(for: screen, viewModel: viewModel, streakStore: streakStore, message: message)
              windows.append(window)
              window.orderFront(nil)
          }

          // Fade in
          windows.forEach { $0.alphaValue = 0 }
          NSAnimationContext.runAnimationGroup { ctx in
              ctx.duration = 0.4
              ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
              windows.forEach { $0.animator().alphaValue = 1 }
          }

          // Listen for screen configuration changes while overlay is up
          NotificationCenter.default.addObserver(
              self,
              selector: #selector(screensChanged),
              name: NSApplication.didChangeScreenParametersNotification,
              object: nil
          )
      }

      func hide(completion: (() -> Void)? = nil) {
          NotificationCenter.default.removeObserver(self, name: NSApplication.didChangeScreenParametersNotification, object: nil)

          NSAnimationContext.runAnimationGroup { ctx in
              ctx.duration = 0.3
              ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
              windows.forEach { $0.animator().alphaValue = 0 }
          } completionHandler: { [weak self] in
              self?.windows.forEach { $0.orderOut(nil) }
              self?.windows.removeAll()
              completion?()
          }
      }

      @objc private func screensChanged() {
          // Remove windows for disconnected screens; windows for connected screens stay.
          windows = windows.filter { $0.screen != nil }
      }

      private func makeWindow(
          for screen: NSScreen,
          viewModel: TimerViewModel,
          streakStore: StreakStore,
          message: Message
      ) -> NSWindow {
          let window = NSWindow(
              contentRect: screen.frame,
              styleMask: [.borderless],
              backing: .buffered,
              defer: false
          )
          window.level = .screenSaver
          window.isOpaque = false
          window.backgroundColor = .clear
          window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
          window.isReleasedWhenClosed = false

          let overlay = BreakOverlayView(
              viewModel: viewModel,
              streakStore: streakStore,
              currentMessage: message
          )
          window.contentView = NSHostingView(rootView: overlay)
          return window
      }
  }
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add Otium/Overlay/OverlayWindowController.swift
  git commit -m "feat: add OverlayWindowController with multi-monitor support and fade animations"
  git push
  ```

---

## Task 9: Menu Bar Icon

**Files:**
- Create: `Otium/MenuBar/StatusBarController.swift`

- [ ] **Step 1: Create `StatusBarController.swift`**

  ```swift
  // Otium/MenuBar/StatusBarController.swift
  import AppKit
  import SwiftUI
  import Combine

  @MainActor
  final class StatusBarController {
      private let statusItem: NSStatusItem
      private let popover: NSPopover
      private var cancellables = Set<AnyCancellable>()

      init(
          viewModel: TimerViewModel,
          streakStore: StreakStore,
          sessionStore: SessionStore,
          messageStore: MessageStore
      ) {
          statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
          popover = NSPopover()
          popover.behavior = .transient

          let root = PopoverView(
              viewModel: viewModel,
              streakStore: streakStore,
              sessionStore: sessionStore,
              messageStore: messageStore
          )
          popover.contentViewController = NSHostingController(rootView: root)
          popover.contentSize = NSSize(width: 250, height: 480)

          statusItem.button?.action = #selector(togglePopover(_:))
          statusItem.button?.target = self
          statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

          // Observe state for icon updates
          viewModel.$state
              .combineLatest(viewModel.$timeRemaining, viewModel.$sessionDuration)
              .receive(on: RunLoop.main)
              .sink { [weak self, weak viewModel] _ in
                  guard let vm = viewModel else { return }
                  self?.updateButton(viewModel: vm)
              }
              .store(in: &cancellables)

          updateButton(viewModel: viewModel)
      }

      @objc private func togglePopover(_ sender: NSStatusBarButton) {
          if popover.isShown {
              popover.performClose(nil)
          } else if let button = statusItem.button {
              popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
          }
      }

      private func updateButton(viewModel: TimerViewModel) {
          guard let button = statusItem.button else { return }
          button.image = makeRingIcon(fraction: viewModel.elapsedFraction, state: viewModel.state)
          button.imagePosition = .imageLeft

          switch viewModel.state {
          case .running, .extended:
              let m = Int(viewModel.timeRemaining) / 60
              let s = Int(viewModel.timeRemaining) % 60
              button.title = String(format: " %d:%02d", m, s)
          case .breakActive, .breakPending:
              button.title = " Break"
          default:
              button.title = " Focus"
          }
      }

      private func makeRingIcon(fraction: Double, state: TimerState) -> NSImage {
          let size = NSSize(width: 14, height: 14)
          let image = NSImage(size: size, flipped: false) { rect in
              let center = NSPoint(x: rect.midX, y: rect.midY)
              let radius: CGFloat = 5.5
              let lineWidth: CGFloat = 1.8

              // Background ring
              let bg = NSBezierPath()
              bg.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
              bg.lineWidth = lineWidth
              NSColor(red: 0x37/255, green: 0x41/255, blue: 0x51/255, alpha: 1).setStroke()
              bg.stroke()

              // Progress arc
              if state == .running || state == .extended, fraction > 0 {
                  let arc = NSBezierPath()
                  let endAngle = CGFloat(90 - (360 * fraction))
                  arc.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: endAngle, clockwise: true)
                  arc.lineWidth = lineWidth
                  arc.lineCapStyle = .round
                  NSColor(red: 0xa7/255, green: 0x8b/255, blue: 0xfa/255, alpha: 1).setStroke()
                  arc.stroke()
              }
              return true
          }
          image.isTemplate = false
          return image
      }
  }
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add Otium/MenuBar/StatusBarController.swift
  git commit -m "feat: add StatusBarController with animated ring+countdown menu bar icon"
  git push
  ```

---

## Task 10: Popover Views

**Files:**
- Create: `Otium/Views/PopoverView.swift`
- Create: `Otium/Views/TimerControlView.swift`
- Create: `Otium/Views/SessionHistoryView.swift`
- Create: `Otium/Views/MessagesSettingsView.swift`

- [ ] **Step 1: Create `TimerControlView.swift`**

  ```swift
  // Otium/Views/TimerControlView.swift
  import SwiftUI

  struct TimerControlView: View {
      @ObservedObject var viewModel: TimerViewModel
      @State private var selectedPreset: Int? = 25
      @State private var customText: String = ""

      private let presets = [25, 45, 60, 90]

      private var activeDuration: TimeInterval {
          if let custom = Int(customText), (1...180).contains(custom) {
              return TimeInterval(custom * 60)
          }
          return TimeInterval((selectedPreset ?? 25) * 60)
      }

      var body: some View {
          VStack(spacing: 0) {
              // Large time display
              VStack(spacing: 4) {
                  Text(formattedTime)
                      .font(.system(size: 44, weight: .ultraLight, design: .monospaced))
                      .foregroundColor(Color(hex: "c4b5fd"))
                  Text(viewModel.state == .running ? "FOCUSING" : "READY TO START")
                      .font(.system(size: 11))
                      .tracking(2)
                      .foregroundColor(viewModel.state == .running ? Color(hex: "7c3aed").opacity(0.6) : Color(hex: "4b5563"))
              }
              .padding(.vertical, 12)

              // Progress bar (running only)
              if viewModel.state == .running || viewModel.state == .extended {
                  GeometryReader { geo in
                      ZStack(alignment: .leading) {
                          Rectangle().fill(Color.white.opacity(0.06)).frame(height: 3)
                          LinearGradient(colors: [Color(hex: "7c3aed"), Color(hex: "a78bfa")], startPoint: .leading, endPoint: .trailing)
                              .frame(width: geo.size.width * viewModel.elapsedFraction, height: 3)
                      }
                  }
                  .frame(height: 3)
                  .cornerRadius(2)
                  .padding(.bottom, 16)
              }

              // Preset chips
              HStack(spacing: 5) {
                  ForEach(presets, id: \.self) { preset in
                      presetChip(preset)
                  }
              }
              .disabled(viewModel.state != .idle)
              .padding(.bottom, 6)

              // Custom input
              HStack(spacing: 4) {
                  TextField("custom", text: $customText)
                      .textFieldStyle(.plain)
                      .multilineTextAlignment(.center)
                      .font(.system(size: 11))
                      .foregroundColor(!customText.isEmpty ? Color(hex: "a78bfa") : Color(hex: "4b5563"))
                      .frame(width: 54)
                      .onChange(of: customText) { newValue in
                          // Only digits; strip non-numeric chars
                          let filtered = newValue.filter { $0.isNumber }
                          if filtered != newValue { customText = filtered }
                          if !filtered.isEmpty { selectedPreset = nil }
                      }
                      .onSubmit { validateCustom() }
                  Text("min")
                      .font(.system(size: 11))
                      .foregroundColor(Color(hex: "374151"))
              }
              .padding(.horizontal, 8)
              .frame(height: 26)
              .background(
                  !customText.isEmpty
                      ? Color(hex: "6366f1").opacity(0.1)
                      : Color.white.opacity(0.03)
              )
              .overlay(
                  RoundedRectangle(cornerRadius: 6)
                      .stroke(
                          !customText.isEmpty ? Color(hex: "6366f1").opacity(0.4) : Color.white.opacity(0.08),
                          lineWidth: 1
                      )
              )
              .cornerRadius(6)
              .disabled(viewModel.state != .idle)
              .padding(.bottom, 14)

              // Start / Stop button
              Button(action: toggleSession) {
                  Text(viewModel.state == .idle ? "Start Session" : "Stop Session")
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
          }
      }

      private var formattedTime: String {
          let t = viewModel.state == .idle ? activeDuration : viewModel.timeRemaining
          let m = Int(t) / 60
          let s = Int(t) % 60
          return String(format: "%d:%02d", m, s)
      }

      private func presetChip(_ minutes: Int) -> some View {
          let selected = selectedPreset == minutes && customText.isEmpty
          return Button(action: {
              selectedPreset = minutes
              customText = ""
          }) {
              Text("\(minutes)m")
                  .font(.system(size: 11))
                  .foregroundColor(selected ? Color(hex: "a78bfa") : Color(hex: "4b5563"))
                  .padding(.horizontal, 9)
                  .padding(.vertical, 5)
                  .background(selected ? Color(hex: "a78bfa").opacity(0.2) : Color.white.opacity(0.03))
                  .overlay(
                      RoundedRectangle(cornerRadius: 6)
                          .stroke(selected ? Color(hex: "a78bfa").opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                  )
                  .cornerRadius(6)
          }
          .buttonStyle(.plain)
      }

      private func toggleSession() {
          if viewModel.state == .idle {
              viewModel.startSession(duration: activeDuration)
          } else {
              viewModel.stopSession()
          }
      }

      private func validateCustom() {
          guard let val = Int(customText) else { customText = ""; return }
          if !(1...180).contains(val) { customText = String(min(max(val, 1), 180)) }
      }
  }
  ```

- [ ] **Step 2: Create `SessionHistoryView.swift`**

  ```swift
  // Otium/Views/SessionHistoryView.swift
  import SwiftUI

  struct SessionHistoryView: View {
      @ObservedObject var sessionStore: SessionStore

      var body: some View {
          VStack(alignment: .leading, spacing: 10) {
              // Today header
              HStack {
                  Text("TODAY")
                      .font(.system(size: 11))
                      .tracking(2)
                      .foregroundColor(Color(hex: "4b5563"))
                  Spacer()
                  Text(formattedFocusTime)
                      .font(.system(size: 11))
                      .foregroundColor(Color(hex: "6366f1"))
              }

              // Session list
              VStack(spacing: 5) {
                  ForEach(sessionStore.todaysSessions.suffix(10)) { session in
                      sessionRow(session)
                  }
              }

              // Weekly chart
              Divider().background(Color.white.opacity(0.06)).padding(.vertical, 4)

              Text("THIS WEEK")
                  .font(.system(size: 11))
                  .tracking(2)
                  .foregroundColor(Color(hex: "4b5563"))

              weeklyChart
          }
      }

      private func sessionRow(_ session: Session) -> some View {
          HStack {
              Circle()
                  .fill(dotColor(for: session))
                  .frame(width: 6, height: 6)
              Text(formattedTime(session.startTime))
                  .font(.system(size: 12))
                  .foregroundColor(Color(hex: "94a3b8"))
              Spacer()
              Text(formattedDuration(session.actualDuration))
                  .font(.system(size: 12))
                  .foregroundColor(Color(hex: "64748b"))
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 7)
          .background(Color.white.opacity(0.03))
          .cornerRadius(6)
      }

      private var weeklyChart: some View {
          let data = sessionStore.weeklyMinutes()
          let todayWeekday = Calendar.current.component(.weekday, from: Date())
          // Mon(2)..Sun(1) ordered as M T W T F S S
          let weekdays = [2, 3, 4, 5, 6, 7, 1]
          let labels = ["M", "T", "W", "T", "F", "S", "S"]
          let maxVal = weekdays.map { data[$0] ?? 0 }.max() ?? 1

          return HStack(alignment: .bottom, spacing: 6) {
              ForEach(Array(zip(weekdays, labels)), id: \.0) { weekday, label in
                  let minutes = data[weekday] ?? 0
                  let fraction = maxVal > 0 ? minutes / maxVal : 0
                  let isToday = weekday == todayWeekday

                  VStack(spacing: 3) {
                      RoundedRectangle(cornerRadius: 3)
                          .fill(
                              isToday
                                  ? Color(hex: "6366f1").opacity(0.6)
                                  : Color(hex: "a78bfa").opacity(0.3)
                          )
                          .frame(height: max(CGFloat(fraction) * 32, 3))
                          .overlay(
                              isToday ? RoundedRectangle(cornerRadius: 3).stroke(Color(hex: "a78bfa").opacity(0.4), lineWidth: 1) : nil
                          )
                      Text(label)
                          .font(.system(size: 9))
                          .foregroundColor(isToday ? Color(hex: "a78bfa") : Color(hex: "374151"))
                  }
                  .frame(maxWidth: .infinity)
              }
          }
          .frame(height: 48)
      }

      private var formattedFocusTime: String {
          let totalMinutes = Int(sessionStore.todaysFocusTime / 60)
          if totalMinutes < 60 { return "\(totalMinutes)m focused" }
          return "\(totalMinutes / 60)h \(totalMinutes % 60)m focused"
      }

      private func formattedTime(_ date: Date) -> String {
          let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: date)
      }

      private func formattedDuration(_ interval: TimeInterval) -> String {
          "\(Int(interval / 60)) min"
      }

      private func dotColor(for session: Session) -> Color {
          switch session.outcome {
          case .completed: return session.extendUsed ? Color(hex: "fbbf24") : Color(hex: "34d399")
          case .overridden: return Color(hex: "ef4444")
          }
      }
  }
  ```

- [ ] **Step 3: Create `MessagesSettingsView.swift`**

  ```swift
  // Otium/Views/MessagesSettingsView.swift
  import SwiftUI

  struct MessagesSettingsView: View {
      @ObservedObject var messageStore: MessageStore
      @State private var newText: String = ""
      @State private var newAttribution: String = ""
      @State private var showResetConfirm = false

      var body: some View {
          VStack(alignment: .leading, spacing: 12) {
              Text("BREAK MESSAGES")
                  .font(.system(size: 11))
                  .tracking(2)
                  .foregroundColor(Color(hex: "4b5563"))

              // Message list
              ScrollView {
                  VStack(spacing: 4) {
                      ForEach(messageStore.allMessages) { message in
                          HStack(alignment: .top, spacing: 8) {
                              VStack(alignment: .leading, spacing: 2) {
                                  Text(message.text)
                                      .font(.system(size: 11))
                                      .foregroundColor(Color(hex: "94a3b8"))
                                      .lineLimit(2)
                                  if let attr = message.attribution {
                                      Text("— \(attr)")
                                          .font(.system(size: 10))
                                          .foregroundColor(Color(hex: "4b5563"))
                                  }
                              }
                              Spacer()
                              Button(action: { messageStore.delete(message) }) {
                                  Image(systemName: "minus.circle")
                                      .foregroundColor(Color(hex: "374151"))
                                      .font(.system(size: 12))
                              }
                              .buttonStyle(.plain)
                          }
                          .padding(8)
                          .background(Color.white.opacity(0.03))
                          .cornerRadius(6)
                      }
                  }
              }
              .frame(maxHeight: 160)

              Divider().background(Color.white.opacity(0.06))

              // Add custom message
              VStack(spacing: 6) {
                  TextField("New message…", text: $newText)
                      .textFieldStyle(.plain)
                      .font(.system(size: 11))
                      .foregroundColor(Color(hex: "94a3b8"))
                      .padding(8)
                      .background(Color.white.opacity(0.03))
                      .cornerRadius(6)

                  HStack {
                      TextField("Attribution (optional)", text: $newAttribution)
                          .textFieldStyle(.plain)
                          .font(.system(size: 11))
                          .foregroundColor(Color(hex: "64748b"))
                          .padding(8)
                          .background(Color.white.opacity(0.03))
                          .cornerRadius(6)

                      Button("Add") {
                          guard !newText.isEmpty else { return }
                          messageStore.addCustom(text: newText, attribution: newAttribution.isEmpty ? nil : newAttribution)
                          newText = ""
                          newAttribution = ""
                      }
                      .buttonStyle(.plain)
                      .font(.system(size: 11, weight: .medium))
                      .foregroundColor(Color(hex: "a78bfa"))
                      .disabled(newText.isEmpty)
                  }
              }

              // Reset to defaults
              Button("Reset to defaults") { showResetConfirm = true }
                  .buttonStyle(.plain)
                  .font(.system(size: 11))
                  .foregroundColor(Color(hex: "374151"))
                  .confirmationDialog("Reset all messages to defaults?", isPresented: $showResetConfirm) {
                      Button("Reset", role: .destructive) { messageStore.resetToDefaults() }
                  }
          }
          .padding()
      }
  }
  ```

- [ ] **Step 4: Create `PopoverView.swift`**

  ```swift
  // Otium/Views/PopoverView.swift
  import SwiftUI

  struct PopoverView: View {
      @ObservedObject var viewModel: TimerViewModel
      @ObservedObject var streakStore: StreakStore
      @ObservedObject var sessionStore: SessionStore
      @ObservedObject var messageStore: MessageStore
      @State private var showMessages = false

      var body: some View {
          VStack(spacing: 0) {
              // Header
              HStack {
                  HStack(spacing: 6) {
                      Circle()
                          .fill(viewModel.state == .running ? Color(hex: "a78bfa") : Color(hex: "374151"))
                          .frame(width: 8, height: 8)
                          .overlay(
                              viewModel.state == .running
                                  ? Circle().fill(Color(hex: "a78bfa").opacity(0.3)).frame(width: 14, height: 14) : nil
                          )
                      Text("OTIUM")
                          .font(.system(size: 12))
                          .tracking(1)
                          .foregroundColor(Color(hex: "94a3b8"))
                  }
                  Spacer()
                  // Streak badge
                  HStack(spacing: 4) {
                      Text("🔥")
                          .font(.system(size: 12))
                      Text("\(streakStore.count) day streak")
                          .font(.system(size: 11, weight: .medium))
                          .foregroundColor(Color(hex: "a78bfa"))
                  }
                  .padding(.horizontal, 8)
                  .padding(.vertical, 3)
                  .background(Color(hex: "a78bfa").opacity(0.1))
                  .overlay(Capsule().stroke(Color(hex: "a78bfa").opacity(0.2), lineWidth: 1))
                  .clipShape(Capsule())

                  // Settings gear
                  Button(action: { showMessages.toggle() }) {
                      Image(systemName: showMessages ? "xmark.circle" : "gearshape")
                          .foregroundColor(Color(hex: "374151"))
                          .font(.system(size: 12))
                  }
                  .buttonStyle(.plain)
                  .padding(.leading, 6)
              }
              .padding(.horizontal, 20)
              .padding(.top, 16)
              .padding(.bottom, 12)

              Divider().background(Color.white.opacity(0.06))

              if showMessages {
                  MessagesSettingsView(messageStore: messageStore)
              } else {
                  ScrollView {
                      VStack(spacing: 0) {
                          TimerControlView(viewModel: viewModel)
                              .padding(.horizontal, 20)
                              .padding(.top, 16)

                          Divider()
                              .background(Color.white.opacity(0.06))
                              .padding(.vertical, 12)

                          SessionHistoryView(sessionStore: sessionStore)
                              .padding(.horizontal, 20)
                      }
                  }
              }

              // Footer
              Divider().background(Color.white.opacity(0.05))
              HStack {
                  Text("\(sessionStore.todaysSessions.count) sessions today")
                      .font(.system(size: 11))
                      .foregroundColor(Color(hex: "374151"))
                  Spacer()
                  Button("Quit") { NSApplication.shared.terminate(nil) }
                      .buttonStyle(.plain)
                      .font(.system(size: 11))
                      .foregroundColor(Color(hex: "374151"))
              }
              .padding(.horizontal, 20)
              .padding(.vertical, 10)
          }
          .background(
              LinearGradient(
                  colors: [Color(hex: "1a1025"), Color(hex: "0f1a2e")],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
              )
          )
          .preferredColorScheme(.dark)
      }
  }
  ```

- [ ] **Step 5: Commit**

  ```bash
  git add Otium/Views/
  git commit -m "feat: add popover views — timer controls, session history, messages settings"
  git push
  ```

---

## Task 11: App Entry Point and Wiring

**Files:**
- Modify: `Otium/OtiumApp.swift`
- Create: `Otium/AppDelegate.swift`

- [ ] **Step 1: Replace `OtiumApp.swift`**

  ```swift
  // Otium/OtiumApp.swift
  import SwiftUI

  @main
  struct OtiumApp: App {
      @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

      var body: some Scene {
          // No windows — pure menu bar app
          Settings { EmptyView() }
      }
  }
  ```

- [ ] **Step 2: Create `AppDelegate.swift`**

  ```swift
  // Otium/AppDelegate.swift
  import AppKit
  import Combine

  final class AppDelegate: NSObject, NSApplicationDelegate {
      private var streakStore: StreakStore!
      private var sessionStore: SessionStore!
      private var messageStore: MessageStore!
      private var viewModel: TimerViewModel!
      private var statusBarController: StatusBarController!
      private var overlayController: OverlayWindowController!

      func applicationDidFinishLaunching(_ notification: Notification) {
          // Stores
          streakStore = StreakStore()
          sessionStore = SessionStore()
          messageStore = MessageStore()

          // ViewModel
          viewModel = TimerViewModel(
              streakStore: streakStore,
              sessionStore: sessionStore
          )

          // Overlay controller
          overlayController = OverlayWindowController()

          // Wire break lifecycle
          viewModel.onBreakStart = { [weak self] in
              guard let self else { return }
              let message = self.messageStore.nextMessage()
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                  self.overlayController.show(
                      viewModel: self.viewModel,
                      streakStore: self.streakStore,
                      message: message
                  )
                  // Transition VM to breakActive after overlay animation
                  DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                      self.viewModel._forceBreakActive()
                  }
              }
          }

          viewModel.onBreakEnd = { [weak self] in
              self?.overlayController.hide()
          }

          // Status bar
          statusBarController = StatusBarController(
              viewModel: viewModel,
              streakStore: streakStore,
              sessionStore: sessionStore,
              messageStore: messageStore
          )

          // Sleep / wake
          NSWorkspace.shared.notificationCenter.addObserver(
              self,
              selector: #selector(systemWillSleep),
              name: NSWorkspace.willSleepNotification,
              object: nil
          )
          NSWorkspace.shared.notificationCenter.addObserver(
              self,
              selector: #selector(systemDidWake),
              name: NSWorkspace.didWakeNotification,
              object: nil
          )
      }

      @objc private func systemWillSleep(_ note: Notification) {
          viewModel.handleSystemWillSleep()
      }

      @objc private func systemDidWake(_ note: Notification) {
          viewModel.handleSystemDidWake()
      }
  }
  ```

- [ ] **Step 3: Build and run in Xcode**

  Product → Run (⌘R). You should see:
  - No Dock icon
  - "○ Focus" appears in the menu bar
  - Clicking it opens the popover with the timer controls
  - Starting a session shows the ring filling and countdown updating

- [ ] **Step 4: Commit**

  ```bash
  git add Otium/OtiumApp.swift Otium/AppDelegate.swift
  git commit -m "feat: wire AppDelegate — connects stores, ViewModel, overlay, and status bar"
  git push
  ```

---

## Task 12: README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Create `README.md`**

  ```markdown
  # Otium

  A native macOS menu bar app that enforces structured work/break intervals.

  ## What it does

  - Set a work session (25, 45, 60, 90 min, or custom)
  - When time is up, your screen dims with a fullscreen overlay and a stoic quote
  - Take the 5-minute break, or use **5 More Minutes** once per session (streak safe)
  - **Override** is always available — but it resets your streak
  - Track your streak (days without overriding) and session history from the menu bar

  ## Requirements

  - macOS 14.0+
  - Xcode 15+

  ## Setup

  ```bash
  git clone <repo-url>
  cd timer
  open Otium.xcodeproj
  ```

  Press ⌘R to build and run. The app lives in your menu bar — no Dock icon.

  ## Project structure

  | Path | Purpose |
  |---|---|
  | `Otium/Models/` | `Session`, `TimerState`, `Message` value types |
  | `Otium/Stores/` | Persistence: streak, sessions, messages |
  | `Otium/ViewModels/` | `TimerViewModel` — state machine and countdown |
  | `Otium/MenuBar/` | `StatusBarController` — icon and popover |
  | `Otium/Overlay/` | `OverlayWindowController` — multi-monitor break screen |
  | `Otium/Views/` | SwiftUI views for popover and overlay |
  | `OtiumTests/` | XCTest unit tests for stores and view model |

  ## Running tests

  ⌘U in Xcode, or:
  ```bash
  xcodebuild test -scheme Otium -destination 'platform=macOS'
  ```

  ## Design

  See [PRD.md](PRD.md) for full product requirements.
  ```

- [ ] **Step 2: Commit and push**

  ```bash
  git add README.md
  git commit -m "docs: add README with setup instructions and project structure"
  git push
  ```

---

## Verification Checklist

After completing all tasks, verify the following end-to-end:

- [ ] App launches with no Dock icon; menu bar shows "○ Focus"
- [ ] Clicking menu bar icon opens popover with timer controls and streak
- [ ] Selecting a preset and clicking Start Session begins countdown; icon updates every second
- [ ] Stopping session early returns to idle; no session logged
- [ ] When countdown reaches 0:00, overlay fades in on all connected monitors
- [ ] Overlay shows "It's time to take a break.", a stoic quote in the inset card, and the 5-min break countdown
- [ ] "5 More Minutes" button dismisses overlay, starts 5-min work extension, then overlay returns without the button
- [ ] Break auto-dismisses after 5 min; session logged as green dot in history
- [ ] "Override" resets streak to 0; session logged as red dot; streak badge in popover updates immediately
- [ ] Streak increments by 1 once per day on clean session; multiple sessions don't double-count
- [ ] Skipping a day doesn't break the streak
- [ ] Disconnecting a monitor while overlay is shown doesn't crash
- [ ] Sleeping Mac mid-session and waking resumes correctly; if expired, overlay shows immediately on wake
- [ ] Adding a custom message in settings makes it appear in the rotation
- [ ] Deleting all messages doesn't crash; fallback text is shown
- [ ] Resetting to defaults removes custom messages and restores deleted defaults
- [ ] Weekly bar chart reflects actual session data
- [ ] All XCTest tests pass (⌘U)
