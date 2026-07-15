import XCTest
@testable import SuperIsland

final class ComputerStatusProviderTests: XCTestCase {
    func testSnapshotIsStableWithinOneRenderPass() {
        let first = ComputerStatusProvider.shared.snapshot()
        let second = ComputerStatusProvider.shared.snapshot()

        XCTAssertEqual(first["timestamp"] as? Double, second["timestamp"] as? Double)
        XCTAssertEqual(
            (first["cpu"] as? [String: Any])?["usagePercent"] as? Double,
            (second["cpu"] as? [String: Any])?["usagePercent"] as? Double
        )
    }

    func testSnapshotContainsBoundedCoreMetrics() {
        let snapshot = ComputerStatusProvider.shared.snapshot()

        let cpu = snapshot["cpu"] as? [String: Any]
        let memory = snapshot["memory"] as? [String: Any]
        let disk = snapshot["disk"] as? [String: Any]
        let temperature = snapshot["temperature"] as? [String: Any]
        let fans = snapshot["fans"] as? [String: Any]
        let power = snapshot["power"] as? [String: Any]

        XCTAssertNotNil(cpu)
        XCTAssertNotNil(memory)
        XCTAssertNotNil(disk)
        XCTAssertNotNil(temperature)
        XCTAssertNotNil(fans)
        XCTAssertNotNil(power)
        XCTAssertNil(snapshot["battery"])

        if let cpu {
            XCTAssertGreaterThanOrEqual(cpu["usagePercent"] as? Double ?? -1, 0)
            XCTAssertLessThanOrEqual(cpu["usagePercent"] as? Double ?? 101, 100)
            XCTAssertGreaterThan(cpu["coreCount"] as? Int ?? 0, 0)
        }

        if let memory {
            XCTAssertGreaterThan(memory["totalBytes"] as? Int64 ?? 0, 0)
            XCTAssertGreaterThanOrEqual(memory["usedBytes"] as? Int64 ?? -1, 0)
            XCTAssertGreaterThanOrEqual(memory["appBytes"] as? Int64 ?? -1, 0)
            XCTAssertGreaterThanOrEqual(memory["wiredBytes"] as? Int64 ?? -1, 0)
            XCTAssertGreaterThanOrEqual(memory["compressedBytes"] as? Int64 ?? -1, 0)
            XCTAssertGreaterThanOrEqual(memory["cachedBytes"] as? Int64 ?? -1, 0)
            XCTAssertGreaterThanOrEqual(memory["usagePercent"] as? Double ?? -1, 0)
            XCTAssertLessThanOrEqual(memory["usagePercent"] as? Double ?? 101, 100)
        }

        if let disk {
            XCTAssertGreaterThan(disk["totalBytes"] as? Int64 ?? 0, 0)
            XCTAssertGreaterThanOrEqual(disk["usagePercent"] as? Double ?? -1, 0)
            XCTAssertLessThanOrEqual(disk["usagePercent"] as? Double ?? 101, 100)
        }

        if let temperature {
            XCTAssertNotNil(temperature["available"] as? Bool)
            if temperature["available"] as? Bool == true {
                XCTAssertGreaterThanOrEqual(temperature["socCelsius"] as? Double ?? -1, 0)
                XCTAssertLessThanOrEqual(temperature["socCelsius"] as? Double ?? 126, 125)
                XCTAssertGreaterThan(temperature["sensorCount"] as? Int ?? 0, 0)
            }
        }

        if let fans {
            XCTAssertNotNil(fans["available"] as? Bool)
            XCTAssertGreaterThanOrEqual(fans["count"] as? Int ?? -1, 0)
            XCTAssertLessThanOrEqual(fans["count"] as? Int ?? 9, 8)
            XCTAssertNotNil(fans["items"] as? [[String: Any]])

            if fans["available"] as? Bool == true,
               let items = fans["items"] as? [[String: Any]] {
                XCTAssertEqual(items.count, fans["count"] as? Int)
                for item in items {
                    XCTAssertGreaterThanOrEqual(item["index"] as? Int ?? -1, 0)
                    if let actualRPM = item["actualRPM"] as? Int {
                        XCTAssertGreaterThanOrEqual(actualRPM, 0)
                        XCTAssertLessThanOrEqual(actualRPM, 20_000)
                    }
                    if let maximumRPM = item["maximumRPM"] as? Int {
                        XCTAssertGreaterThan(maximumRPM, 0)
                        XCTAssertLessThanOrEqual(maximumRPM, 20_000)
                    }
                }
            }
        }

        if let power {
            XCTAssertNotNil(power["thermalState"] as? String)
        }
    }
}
