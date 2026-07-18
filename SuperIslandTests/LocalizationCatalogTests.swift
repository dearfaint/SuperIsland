import XCTest

final class LocalizationCatalogTests: XCTestCase {
    func testLocalizableCatalogHasEnglishSourceAndChineseTranslations() throws {
        let catalog = try decodeCatalog(named: "Localizable.xcstrings")

        XCTAssertEqual(catalog.sourceLanguage, "en")
        XCTAssertFalse(catalog.strings.isEmpty)

        let missingChinese = catalog.strings.keys.sorted().filter { key in
            guard let value = catalog.strings[key]?.localizations?["zh-Hans"]?.stringUnit?.value else {
                return true
            }
            return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        XCTAssertTrue(
            missingChinese.isEmpty,
            "Missing zh-Hans translations: \(missingChinese.prefix(12).joined(separator: ", "))"
        )
    }

    func testPermissionDescriptionsHaveInfoPlistLocalizations() throws {
        let catalog = try decodeCatalog(named: "InfoPlist.xcstrings")
        let infoPlist = try decodeInfoPlist()
        let usageDescriptionKeys = infoPlist.keys
            .filter { $0.hasPrefix("NS") && $0.hasSuffix("UsageDescription") }
            .sorted()

        XCTAssertEqual(catalog.sourceLanguage, "en")
        XCTAssertFalse(usageDescriptionKeys.isEmpty)

        for key in usageDescriptionKeys {
            let english = try localizedValue(for: key, locale: "en", in: catalog)
            let chinese = try localizedValue(for: key, locale: "zh-Hans", in: catalog)

            XCTAssertEqual(english, infoPlist[key] as? String)
            XCTAssertFalse(chinese.contains("needs"), "\(key) should have a Chinese permission description")
        }
    }

    func testRepresentativeChineseStringsAndPrintfFormats() throws {
        let catalog = try decodeCatalog(named: "Localizable.xcstrings")

        XCTAssertEqual(try localizedValue(for: "Settings", in: catalog), "设置")
        XCTAssertEqual(try localizedValue(for: "Weather", in: catalog), "天气")
        XCTAssertEqual(try localizedValue(for: "No events", in: catalog), "没有日程")
        XCTAssertEqual(try localizedValue(for: "Use Low Power mode?", in: catalog), "启用低功耗模式？")
        XCTAssertEqual(try localizedValue(for: "Extension Purpose", in: catalog), "扩展用途")
        XCTAssertEqual(
            try localizedValue(for: "The developer did not provide a purpose description.", in: catalog),
            "开发者未提供用途说明。"
        )

        let highTempFormat = try localizedValue(for: "H:%@", in: catalog)
        XCTAssertEqual(String(format: highTempFormat, locale: Locale(identifier: "zh-Hans"), "23°C"), "高：23°C")

        let durationFormat = try localizedValue(for: "%@ ms", in: catalog)
        XCTAssertEqual(String(format: durationFormat, locale: Locale(identifier: "zh-Hans"), "120"), "120 毫秒")
    }
}

private struct StringCatalog: Decodable {
    let sourceLanguage: String
    let strings: [String: CatalogEntry]
}

private struct CatalogEntry: Decodable {
    let localizations: [String: CatalogLocalization]?
}

private struct CatalogLocalization: Decodable {
    let stringUnit: CatalogStringUnit?
}

private struct CatalogStringUnit: Decodable {
    let value: String
}

private func decodeCatalog(named filename: String) throws -> StringCatalog {
    let data = try Data(contentsOf: projectRootURL.appendingPathComponent("SuperIsland/Resources/\(filename)"))
    return try JSONDecoder().decode(StringCatalog.self, from: data)
}

private func decodeInfoPlist() throws -> [String: Any] {
    let data = try Data(contentsOf: projectRootURL.appendingPathComponent("SuperIsland/Info.plist"))
    let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    return try XCTUnwrap(plist as? [String: Any])
}

private func localizedValue(
    for key: String,
    locale: String = "zh-Hans",
    in catalog: StringCatalog,
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> String {
    let entry = try XCTUnwrap(catalog.strings[key], "Missing catalog key: \(key)", file: file, line: line)
    let value = try XCTUnwrap(
        entry.localizations?[locale]?.stringUnit?.value,
        "Missing \(locale) value for key: \(key)",
        file: file,
        line: line
    )
    XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, file: file, line: line)
    return value
}

private var projectRootURL: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
