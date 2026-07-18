import XCTest
@testable import SuperIsland

final class ExtensionLocalizationTests: XCTestCase {
    func testLocalizedExtensionStringFallsBackToEnglish() {
        let value = LocalizedExtensionString(localizations: [
            "en": "Settings",
            "zh-Hans": "设置"
        ])

        XCTAssertEqual(value.resolved(preferredLanguages: ["zh-Hans"]), "设置")
        XCTAssertEqual(value.resolved(preferredLanguages: ["fr-FR"]), "Settings")
    }

    func testExtensionSettingsDecodeLocalizedLabelsAndPlaceholder() throws {
        let data = """
        {
          "sections": [
            {
              "title": { "en": "Team", "zh-Hans": "球队" },
              "fields": [
                {
                  "type": "text",
                  "key": "favoriteTeam",
                  "label": { "en": "Favorite team", "zh-Hans": "主队" },
                  "placeholder": { "en": "USA", "zh-Hans": "美国" },
                  "description": { "en": "FIFA code", "zh-Hans": "FIFA 代码" },
                  "default": ""
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let schema = try JSONDecoder().decode(SettingsSchema.self, from: data)
        let field = try XCTUnwrap(schema.sections.first?.fields.first)

        XCTAssertEqual(schema.sections.first?.title, LocalizedExtensionString(localizations: ["en": "Team", "zh-Hans": "球队"]).value)
        XCTAssertEqual(field.label, LocalizedExtensionString(localizations: ["en": "Favorite team", "zh-Hans": "主队"]).value)
        XCTAssertEqual(field.placeholder, LocalizedExtensionString(localizations: ["en": "USA", "zh-Hans": "美国"]).value)
        XCTAssertEqual(field.description, LocalizedExtensionString(localizations: ["en": "FIFA code", "zh-Hans": "FIFA 代码"]).value)
    }

    func testExtensionInputEditingPreservesInputMethodComposition() {
        XCTAssertFalse(
            ExtensionInputEditingPolicy.shouldApplyExternalText(
                stringsDiffer: true,
                hasMarkedText: true
            )
        )
        XCTAssertTrue(
            ExtensionInputEditingPolicy.shouldApplyExternalText(
                stringsDiffer: true,
                hasMarkedText: false
            )
        )
    }

    func testExtensionInputEditingDoesNotSubmitMarkedText() {
        XCTAssertFalse(
            ExtensionInputEditingPolicy.shouldSubmit(
                isReturn: true,
                hasShift: false,
                hasMarkedText: true
            )
        )
        XCTAssertTrue(
            ExtensionInputEditingPolicy.shouldSubmit(
                isReturn: true,
                hasShift: false,
                hasMarkedText: false
            )
        )
        XCTAssertFalse(
            ExtensionInputEditingPolicy.shouldSubmit(
                isReturn: true,
                hasShift: true,
                hasMarkedText: false
            )
        )
    }

    func testAgentsStatusUsesAgentTerminologyInSimplifiedChinese() throws {
        let extensionDirectory = repositoryRoot
            .appendingPathComponent("Extensions", isDirectory: true)
            .appendingPathComponent("agents-status", isDirectory: true)

        let manifestData = try Data(
            contentsOf: extensionDirectory.appendingPathComponent("manifest.json")
        )
        let manifest = try XCTUnwrap(
            JSONSerialization.jsonObject(with: manifestData) as? [String: Any]
        )
        let names = try XCTUnwrap(manifest["name"] as? [String: String])
        XCTAssertEqual(names["zh-Hans"], "Agents 状态")

        let settingsData = try Data(
            contentsOf: extensionDirectory.appendingPathComponent("settings.json")
        )
        let settings = try XCTUnwrap(
            JSONSerialization.jsonObject(with: settingsData) as? [String: Any]
        )
        let sections = try XCTUnwrap(settings["sections"] as? [[String: Any]])
        let fields = sections.flatMap { $0["fields"] as? [[String: Any]] ?? [] }
        let soundAlert = try XCTUnwrap(
            fields.first { $0["key"] as? String == "soundAlert" }
        )
        let descriptions = try XCTUnwrap(
            soundAlert["description"] as? [String: String]
        )
        XCTAssertEqual(
            descriptions["zh-Hans"],
            "当 Agent 开始工作、需要输入或完成任务时播放提示音；完成时还会短暂展开 Agents 状态岛。"
        )
    }

    func testExtensionNotificationSoundNamesRejectPaths() {
        XCTAssertEqual(
            ExtensionNotificationSoundPolicy.normalizedName("  Ping  "),
            "Ping"
        )
        XCTAssertNil(ExtensionNotificationSoundPolicy.normalizedName(""))
        XCTAssertNil(ExtensionNotificationSoundPolicy.normalizedName("../Ping"))
        XCTAssertNil(ExtensionNotificationSoundPolicy.normalizedName("folder\\Ping"))
        XCTAssertNil(
            ExtensionNotificationSoundPolicy.normalizedName(
                String(repeating: "a", count: 129)
            )
        )
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
