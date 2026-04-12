// OtiumTests/MessageStoreTests.swift
import XCTest
@testable import Otium

@MainActor
final class MessageStoreTests: XCTestCase {
    var store: MessageStore!
    private let suiteName = "test.messages.\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults(suiteName: suiteName)!
        store = MessageStore(defaults: defaults)
    }

    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
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
