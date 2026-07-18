import XCTest
@testable import SuperIsland

@MainActor
final class ExtensionInstallationTests: XCTestCase {
    func testInspectAcceptsSafeThirdPartyExtension() throws {
        let directory = try makeExtensionDirectory(
            id: "example.status-monitor.\(UUID().uuidString)",
            permissions: ["network", "storage", "notifications"]
        )
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }

        let manifest = try ExtensionManager.shared.inspectInstallSource(
            directory,
            currentAppVersion: "99.0"
        )

        XCTAssertEqual(manifest.permissions, ["network", "storage", "notifications"])
    }

    func testInspectRejectsReservedIdentifier() throws {
        let directory = try makeExtensionDirectory(
            id: "superisland.third-party",
            permissions: []
        )
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }

        XCTAssertThrowsError(
            try ExtensionManager.shared.inspectInstallSource(directory, currentAppVersion: "99.0")
        ) { error in
            guard case ExtensionInstallationError.reservedIdentifier = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testInspectRejectsIncompatibleAppVersion() throws {
        let directory = try makeExtensionDirectory(
            id: "example.future-version.\(UUID().uuidString)",
            permissions: [],
            minAppVersion: "2.0.0"
        )
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }

        XCTAssertThrowsError(
            try ExtensionManager.shared.inspectInstallSource(directory, currentAppVersion: "1.9.9")
        ) { error in
            guard case ExtensionInstallationError.incompatibleAppVersion(
                let required,
                let current
            ) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(required, "2.0.0")
            XCTAssertEqual(current, "1.9.9")
        }
    }

    func testInspectRejectsUnknownPermission() throws {
        let directory = try makeExtensionDirectory(
            id: "example.unknown-permission.\(UUID().uuidString)",
            permissions: ["process"]
        )
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }

        XCTAssertThrowsError(
            try ExtensionManager.shared.inspectInstallSource(directory, currentAppVersion: "99.0")
        ) { error in
            guard case ExtensionInstallationError.unsupportedPermissions(let permissions) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(permissions, ["process"])
        }
    }

    func testInspectRejectsEntryOutsideExtensionFolder() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperIslandExtensionTests-\(UUID().uuidString)", isDirectory: true)
        let directory = root.appendingPathComponent("extension", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("// outside".utf8).write(to: root.appendingPathComponent("outside.js"))
        try writeManifest(
            to: directory,
            id: "example.unsafe.\(UUID().uuidString)",
            permissions: [],
            main: "../outside.js"
        )
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertThrowsError(
            try ExtensionManager.shared.inspectInstallSource(directory, currentAppVersion: "99.0")
        ) { error in
            guard case ExtensionInstallationError.unsafeResourcePath = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testInspectRejectsSymlinkedEntryOutsideExtensionFolder() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperIslandExtensionTests-\(UUID().uuidString)", isDirectory: true)
        let directory = root.appendingPathComponent("extension", isDirectory: true)
        let outsideURL = root.appendingPathComponent("outside.js")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("// outside".utf8).write(to: outsideURL)
        try FileManager.default.createSymbolicLink(
            at: directory.appendingPathComponent("index.js"),
            withDestinationURL: outsideURL
        )
        try writeManifest(
            to: directory,
            id: "example.symlink.unsafe.\(UUID().uuidString)",
            permissions: [],
            main: "index.js"
        )
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertThrowsError(
            try ExtensionManager.shared.inspectInstallSource(directory, currentAppVersion: "99.0")
        ) { error in
            guard case ExtensionInstallationError.unsafeResourcePath = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testInspectRejectsSymlinkedExtensionRoot() throws {
        let directory = try makeExtensionDirectory(
            id: "example.symlink.root.\(UUID().uuidString)",
            permissions: []
        )
        let root = directory.deletingLastPathComponent()
        let symlinkURL = root.appendingPathComponent("extension-link", isDirectory: true)
        try FileManager.default.createSymbolicLink(
            at: symlinkURL,
            withDestinationURL: directory
        )
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertThrowsError(
            try ExtensionManager.shared.inspectInstallSource(symlinkURL, currentAppVersion: "99.0")
        ) { error in
            guard case ExtensionInstallationError.unsafeResourcePath = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPreparedInstallUsesReviewedSnapshot() throws {
        let directory = try makeExtensionDirectory(
            id: "example.snapshot.\(UUID().uuidString)",
            permissions: []
        )
        let root = directory.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: root) }

        let preparedInstall = try ExtensionManager.shared.prepareInstall(
            from: directory,
            currentAppVersion: "99.0"
        )
        defer {
            ExtensionManager.shared.discardPreparedInstall(preparedInstall)
        }

        try Data("// changed after review".utf8).write(
            to: directory.appendingPathComponent("index.js")
        )

        let reviewedEntry = try String(contentsOf: preparedInstall.manifest.entryURL, encoding: .utf8)
        XCTAssertEqual(reviewedEntry, "// extension entry")
    }

    func testRemovingPersistedDataKeepsOtherExtensionKeys() throws {
        let suiteName = "ExtensionInstallationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("token", forKey: "extensions.example.one.store.token")
        defaults.set(true, forKey: "extensions.example.one.settings.enabled")
        defaults.set("keep", forKey: "extensions.example.one-more.store.token")
        defaults.set("keep", forKey: "extensions.example.two.store.token")

        ExtensionManager.removePersistedData(extensionID: "example.one", defaults: defaults)

        XCTAssertNil(defaults.object(forKey: "extensions.example.one.store.token"))
        XCTAssertNil(defaults.object(forKey: "extensions.example.one.settings.enabled"))
        XCTAssertEqual(defaults.string(forKey: "extensions.example.one-more.store.token"), "keep")
        XCTAssertEqual(defaults.string(forKey: "extensions.example.two.store.token"), "keep")
    }

    func testNudgePackagePassesThirdPartyInspection() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceDirectory = repositoryRoot
            .appendingPathComponent("InstallableExtensions", isDirectory: true)
            .appendingPathComponent("Nudge", isDirectory: true)
        let sourceManifest = try ExtensionManifest.load(from: sourceDirectory)

        XCTAssertEqual(sourceManifest.id, "com.guoyxu.nudge")
        XCTAssertFalse(sourceManifest.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertFalse(sourceManifest.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertEqual(sourceManifest.author?.name, "Guoyxu")

        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperIslandNudgeTests-\(UUID().uuidString)", isDirectory: true)
        let directory = temporaryRoot.appendingPathComponent("Nudge", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryRoot,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }
        try FileManager.default.copyItem(at: sourceDirectory, to: directory)

        let manifestURL = directory.appendingPathComponent("manifest.json")
        let manifestData = try Data(contentsOf: manifestURL)
        var manifestObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: manifestData) as? [String: Any]
        )
        manifestObject["id"] = "com.guoyxu.nudge.tests.\(UUID().uuidString)"
        try JSONSerialization.data(
            withJSONObject: manifestObject,
            options: [.prettyPrinted, .sortedKeys]
        ).write(to: manifestURL)

        let manifest = try ExtensionManager.shared.inspectInstallSource(
            directory,
            currentAppVersion: "1.0.10"
        )

        XCTAssertEqual(manifest.permissions, ["storage", "notifications"])
        XCTAssertEqual(manifest.version, "1.1.1")
        let settingsURL = try XCTUnwrap(manifest.settingsURL)
        let settingsSchema = try SettingsSchema.load(from: settingsURL)
        XCTAssertEqual(
            Set(settingsSchema.sections.flatMap(\.fields).map(\.key)),
            ["alertSound", "customSoundName", "previewSound"]
        )
        XCTAssertFalse(manifest.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertFalse(manifest.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertEqual(manifest.author?.name, "Guoyxu")

        ExtensionManager.removePersistedData(extensionID: manifest.id)
        defer { ExtensionManager.removePersistedData(extensionID: manifest.id) }

        let runtime = try ExtensionJSRuntime(
            manifest: manifest,
            manager: ExtensionManager.shared
        )
        runtime.activate()
        defer { runtime.cleanup() }

        runtime.handleAction(actionID: "select-delay:10", value: nil)
        runtime.handleAction(actionID: "create-reminder", value: "Test reminder")

        XCTAssertNotNil(runtime.fetchState())
    }

    private func makeExtensionDirectory(
        id: String,
        permissions: [String],
        minAppVersion: String = "1.0.0"
    ) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperIslandExtensionTests-\(UUID().uuidString)", isDirectory: true)
        let directory = root.appendingPathComponent("extension", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("// extension entry".utf8).write(to: directory.appendingPathComponent("index.js"))
        try writeManifest(
            to: directory,
            id: id,
            permissions: permissions,
            main: "index.js",
            minAppVersion: minAppVersion
        )
        return directory
    }

    private func writeManifest(
        to directory: URL,
        id: String,
        permissions: [String],
        main: String,
        minAppVersion: String = "1.0.0"
    ) throws {
        let manifest: [String: Any] = [
            "id": id,
            "name": "Test Extension",
            "version": "1.0.0",
            "minAppVersion": minAppVersion,
            "main": main,
            "description": "Test extension",
            "permissions": permissions
        ]
        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted])
        try data.write(to: directory.appendingPathComponent("manifest.json"))
    }
}
