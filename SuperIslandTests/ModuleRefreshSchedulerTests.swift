import XCTest
@testable import SuperIsland

@MainActor
final class ModuleRefreshSchedulerTests: XCTestCase {

    // Regression test for the main-thread freeze caused by leaked RunLoop timers.
    //
    // A module's refresh `action` can re-enter the scheduler (for example when a
    // refresh nudges AppState, which pushes a new activity state and triggers a
    // reschedule). The original implementation stored each Timer inside the Job
    // value type; `run(id:)` read a Job copy, invoked the action, then wrote the
    // stale copy back — clobbering any timer the re-entrant call had installed.
    // The clobbered timer stayed armed on RunLoop.main but lost its only owning
    // reference, so it could never be invalidated. Over days these orphans piled
    // up until __CFArmNextTimerInMode turned into an O(n) scan that pegged the
    // main thread and froze the UI.
    //
    // One job must own exactly one live timer no matter how often its action
    // re-enters the scheduler.
    func testReentrantActionDoesNotOrphanTimers() {
        let scheduler = ModuleRefreshScheduler(isolatedForTesting: true)
        var runCount = 0

        scheduler.register(
            id: "test.job",
            name: "Test Job",
            policy: .interval(0.05, tolerance: 0.01),
            enabled: { true }
        ) { [weak scheduler] in
            runCount += 1
            // Re-enter mid-run, the way a real module refresh can.
            scheduler?.refreshScheduling()
        }

        XCTAssertEqual(scheduler.scheduledTimerCountForTesting, 1)

        for _ in 0..<200 {
            scheduler.runNow(id: "test.job")
        }

        XCTAssertGreaterThan(runCount, 0, "action should have executed")
        XCTAssertEqual(
            scheduler.scheduledTimerCountForTesting,
            scheduler.jobCountForTesting,
            "live timers must track the number of jobs, never accumulate"
        )
        XCTAssertEqual(scheduler.scheduledTimerCountForTesting, 1)

        scheduler.unregister(id: "test.job")
        XCTAssertEqual(scheduler.scheduledTimerCountForTesting, 0)
    }

    // Repeated re-registration of the same id must not accumulate timers either.
    func testReRegisterKeepsSingleTimer() {
        let scheduler = ModuleRefreshScheduler(isolatedForTesting: true)

        for _ in 0..<50 {
            scheduler.register(
                id: "test.job",
                name: "Test Job",
                policy: .interval(1, tolerance: 0.1),
                enabled: { true },
                action: {}
            )
        }

        XCTAssertEqual(scheduler.jobCountForTesting, 1)
        XCTAssertEqual(scheduler.scheduledTimerCountForTesting, 1)

        scheduler.unregister(id: "test.job")
        XCTAssertEqual(scheduler.scheduledTimerCountForTesting, 0)
    }
}

final class WeatherSourceSelectionTests: XCTestCase {
    func testAutomaticUsesQWeatherForMainlandChinaWhenConfigured() {
        XCTAssertEqual(
            WeatherManager.resolvedSource(
                preference: .auto,
                isMainlandChina: true,
                qweatherConfigured: true,
                caiyunConfigured: false
            ),
            .qweather
        )
    }

    func testAutomaticFallsBackToOpenMeteoWithoutQWeatherCredentials() {
        XCTAssertEqual(
            WeatherManager.resolvedSource(
                preference: .auto,
                isMainlandChina: true,
                qweatherConfigured: false,
                caiyunConfigured: true
            ),
            .openMeteo
        )
    }

    func testAutomaticUsesOpenMeteoOutsideMainlandChina() {
        XCTAssertEqual(
            WeatherManager.resolvedSource(
                preference: .auto,
                isMainlandChina: false,
                qweatherConfigured: true,
                caiyunConfigured: true
            ),
            .openMeteo
        )
    }

    func testExplicitUnavailableProvidersFallBackToOpenMeteo() {
        XCTAssertEqual(
            WeatherManager.resolvedSource(
                preference: .qweather,
                isMainlandChina: true,
                qweatherConfigured: false,
                caiyunConfigured: false
            ),
            .openMeteo
        )
        XCTAssertEqual(
            WeatherManager.resolvedSource(
                preference: .caiyun,
                isMainlandChina: true,
                qweatherConfigured: true,
                caiyunConfigured: false
            ),
            .openMeteo
        )
    }

    func testMainlandChinaDetectionPrefersGeocodedCountryCode() {
        XCTAssertTrue(WeatherManager.isMainlandChina(isoCountryCode: "CN", latitude: 39.9, longitude: 116.4))
        XCTAssertFalse(WeatherManager.isMainlandChina(isoCountryCode: "HK", latitude: 22.3, longitude: 114.2))
        XCTAssertFalse(WeatherManager.isMainlandChina(isoCountryCode: "TW", latitude: 25.0, longitude: 121.5))
    }

    func testCaiyunSignatureMatchesDocumentedExample() {
        let query = WeatherManager.encodedQueryString([
            "hourlysteps": "24",
            "dailysteps": "1",
            "alert": "true"
        ])
        let stringToSign = [
            "GET",
            "/v2.6/your_app_key/116.3176,39.9760/weather",
            query,
            "your_app_key",
            "0195c68a-42e7-7243-bff2-ac97a78b837d",
            "1742791910"
        ].joined(separator: ":")

        XCTAssertEqual(query, "alert=true&dailysteps=1&hourlysteps=24")
        XCTAssertEqual(
            WeatherManager.caiyunSignature(for: stringToSign, appSecret: "your_app_secret"),
            "KfHsk3z2XfX6Yxox4Uf_VgyM0wHk6bWEyRqZ9QOJUYw="
        )
    }

    func testQWeatherJWTUsesCredentialIDAndProjectID() {
        let seed = Data((0..<32).map { UInt8($0) })
        let token = WeatherManager.qweatherJWT(
            credentialID: "TESTCREDID",
            projectID: "project-id",
            privateKeyInput: seed.base64EncodedString(),
            issuedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let parts = token?.split(separator: ".")

        XCTAssertEqual(parts?.count, 3)
        let header = decodedJWTPart(parts?[0])
        let payload = decodedJWTPart(parts?[1])
        let signature = decodedJWTData(parts?[2])

        XCTAssertEqual(header?["alg"] as? String, "EdDSA")
        XCTAssertEqual(header?["kid"] as? String, "TESTCREDID")
        XCTAssertEqual(payload?["sub"] as? String, "project-id")
        XCTAssertEqual(payload?["iat"] as? Int, 1_699_999_970)
        XCTAssertEqual(payload?["exp"] as? Int, 1_700_003_570)
        XCTAssertEqual(signature?.count, 64)
    }

    func testQWeatherPrivateKeyParsesPKCS8PEM() {
        let seed = Data((0..<32).map { UInt8($0) })
        var der = Data([0x30, 0x2E, 0x02, 0x01, 0x00, 0x30, 0x05, 0x06, 0x03, 0x2B, 0x65, 0x70, 0x04, 0x22, 0x04, 0x20])
        der.append(seed)
        let pem = """
        -----BEGIN PRIVATE KEY-----
        \(der.base64EncodedString())
        -----END PRIVATE KEY-----
        """
        let singleLinePEM = pem.replacingOccurrences(of: "\n", with: " ")

        XCTAssertEqual(WeatherManager.qweatherPrivateKeyRawRepresentation(from: pem), seed)
        XCTAssertEqual(WeatherManager.qweatherPrivateKeyRawRepresentation(from: singleLinePEM), seed)
    }

    func testQWeatherAQIPrefersChinaIndexBeforeQAQI() {
        let indexes: [[String: Any]] = [
            ["code": "qaqi", "aqi": 1, "category": "Excellent"],
            ["code": "us-epa", "aqi": 88, "category": "Moderate"],
            ["code": "cn-mee", "aqi": 46, "category": "优"]
        ]

        let selected = WeatherManager.preferredQWeatherAQIIndex(from: indexes)
        XCTAssertEqual(selected?["code"] as? String, "cn-mee")
        XCTAssertEqual(selected?["category"] as? String, "优")
    }

    private func decodedJWTPart(_ part: Substring?) -> [String: Any]? {
        guard let data = decodedJWTData(part) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private func decodedJWTData(_ part: Substring?) -> Data? {
        guard let part else { return nil }
        var value = String(part)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = value.count % 4
        if remainder != 0 {
            value += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: value)
    }
}
