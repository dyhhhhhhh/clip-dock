@testable import ClipDockCore
import XCTest

final class ModelTests: XCTestCase {
    func testUserSettingsDefaultsArePrivacyFirstAndShared() {
        let settings = UserSettings.defaults

        XCTAssertEqual(settings.maxHistoryCount, 1000)
        XCTAssertEqual(settings.retentionDays, 30)
        XCTAssertTrue(settings.saveImages)
        XCTAssertTrue(settings.saveFileURLs)
        XCTAssertEqual(settings.pollingInterval, 0.8, accuracy: 0.001)
        XCTAssertFalse(settings.recordingPaused)
        XCTAssertTrue(settings.ignoreSensitiveContent)
        XCTAssertFalse(settings.restoreLastClipboardOnStartup)
        XCTAssertFalse(settings.autoPasteEnabled)
        XCTAssertEqual(settings.deduplicationStrategy, .byTypeAndContentHash)
    }

    func testUserSettingsDecodeFallsBackWhenStoredGlobalShortcutIsInvalid() throws {
        let json = """
        {
          "globalShortcut": ""
        }
        """

        let decoded = try JSONDecoder.clipDock.decode(UserSettings.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.globalShortcut, UserSettings.defaults.globalShortcut)
    }

    func testUserSettingsMigratesLegacyAutoPasteToggleToDefaultPasteBehavior() throws {
        let json = """
        {
          "autoPasteEnabled": true,
          "defaultPasteBehavior": "restoreOnly"
        }
        """

        let decoded = try JSONDecoder.clipDock.decode(UserSettings.self, from: Data(json.utf8))

        XCTAssertFalse(decoded.autoPasteEnabled)
        XCTAssertEqual(decoded.defaultPasteBehavior, .autoPasteWhenAllowed)
    }

    func testClipItemRoundTripsThroughCodable() throws {
        let item = ClipItem(
            contentHash: "abc",
            primaryType: .text,
            capturedAt: Date(timeIntervalSince1970: 100),
            lastUsedAt: nil,
            useCount: 0,
            isFavorite: true,
            isSensitive: false,
            expiresAt: Date(timeIntervalSince1970: 200),
            tags: ["work"],
            previewText: "hello",
            title: "Greeting",
            payload: .text("hello"),
            payloadRef: nil,
            sourceApp: SourceAppMetadata(name: "Notes", bundleIdentifier: "com.apple.Notes"),
            byteSize: 5,
        )

        let data = try JSONEncoder.clipDock.encode(item)
        let decoded = try JSONDecoder.clipDock.decode(ClipItem.self, from: data)

        XCTAssertEqual(decoded, item)
        XCTAssertEqual(decoded.sourceAppName, "Notes")
        XCTAssertEqual(decoded.sourceBundleID, "com.apple.Notes")
    }

    func testClipItemDecodesLegacyPinnedAsFavorite() throws {
        let json = """
        {
          "byteSize": 5,
          "capturedAt": "1970-01-01T00:01:40Z",
          "contentHash": "legacy",
          "id": "\(UUID().uuidString)",
          "isPinned": true,
          "payload": { "text": { "_0": "hello" } },
          "previewText": "hello",
          "primaryType": "text"
        }
        """

        let decoded = try JSONDecoder.clipDock.decode(ClipItem.self, from: Data(json.utf8))

        XCTAssertTrue(decoded.isFavorite)
    }
}
