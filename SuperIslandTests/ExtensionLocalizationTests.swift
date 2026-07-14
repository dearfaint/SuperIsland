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
}
