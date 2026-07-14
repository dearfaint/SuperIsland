import Foundation

struct LocalizedExtensionString: Codable, Hashable {
    private let source: String
    private let localizations: [String: String]

    init(_ source: String) {
        self.source = source
        self.localizations = ["en": source]
    }

    init(localizations: [String: String]) {
        let normalized = Self.normalized(localizations)
        self.source = normalized["en"] ?? normalized["default"] ?? normalized.values.first ?? ""
        self.localizations = normalized
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self.init(value)
            return
        }

        let values = try container.decode([String: String].self)
        self.init(localizations: values)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(localizations)
    }

    var value: String {
        resolved(preferredLanguages: Locale.preferredLanguages + [Locale.current.identifier])
    }

    func resolved(preferredLanguages: [String]) -> String {
        for identifier in preferredLanguages.flatMap(Self.candidates(for:)) {
            if let value = localizations[identifier], !value.isEmpty {
                return value
            }
        }

        return localizations["en"] ?? localizations["default"] ?? source
    }

    static func resolve(_ value: Any?, preferredLanguages: [String] = Locale.preferredLanguages + [Locale.current.identifier]) -> String? {
        guard let value else { return nil }
        if let string = value as? String { return string }
        if let dictionary = value as? [String: String] {
            return LocalizedExtensionString(localizations: dictionary).resolved(preferredLanguages: preferredLanguages)
        }
        if let dictionary = value as? [AnyHashable: Any] {
            var strings: [String: String] = [:]
            for (key, value) in dictionary {
                guard let key = key as? String, let value = value as? String else { continue }
                strings[key] = value
            }
            return strings.isEmpty ? nil : LocalizedExtensionString(localizations: strings).resolved(preferredLanguages: preferredLanguages)
        }
        return String(describing: value)
    }

    private static func normalized(_ values: [String: String]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: values.map { key, value in
            (key.replacingOccurrences(of: "_", with: "-"), value)
        })
    }

    private static func candidates(for identifier: String) -> [String] {
        let normalized = identifier.replacingOccurrences(of: "_", with: "-")
        var candidates = [normalized]

        if normalized.hasPrefix("zh-Hans") {
            candidates.append("zh-Hans")
        }
        if normalized.hasPrefix("zh-Hant") {
            candidates.append("zh-Hant")
        }
        if let language = normalized.split(separator: "-").first.map(String.init) {
            candidates.append(language)
        }

        return candidates
    }
}
