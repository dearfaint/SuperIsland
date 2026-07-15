import Foundation
import Darwin
import IOKit

final class ComputerStatusProvider {
    static let shared = ComputerStatusProvider()

    private var previousCPUTicks: [CPUTicks] = []
    private var cachedSnapshot: [String: Any]?
    private var cachedAt = Date.distantPast
    private let temperatureReader = AppleSiliconTemperatureReader()
    private let fanReader = SMCFanReader()

    private init() {}

    func snapshot() -> [String: Any] {
        let now = Date()
        if let cachedSnapshot, now.timeIntervalSince(cachedAt) < 0.5 {
            return cachedSnapshot
        }

        let payload: [String: Any] = [
            "timestamp": now.timeIntervalSince1970,
            "cpu": cpuSnapshot(),
            "memory": memorySnapshot(),
            "disk": diskSnapshot(),
            "temperature": temperatureReader.snapshot(),
            "fans": fanReader.snapshot(),
            "power": powerSnapshot()
        ]

        cachedSnapshot = payload
        cachedAt = now
        return payload
    }

    private func cpuSnapshot() -> [String: Any] {
        let ticks = currentCPUTicks()
        let usage = cpuUsage(from: ticks)
        return [
            "usagePercent": usage.totalPercent,
            "userPercent": usage.userPercent,
            "systemPercent": usage.systemPercent,
            "idlePercent": usage.idlePercent,
            "coreCount": max(1, ProcessInfo.processInfo.processorCount),
            "activeCoreCount": max(1, ProcessInfo.processInfo.activeProcessorCount),
            "loadAverage": loadAverage()
        ]
    }

    private func currentCPUTicks() -> [CPUTicks] {
        var cpuInfo: processor_info_array_t?
        var processorCount: natural_t = 0
        var processorInfoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &cpuInfo,
            &processorInfoCount
        )

        guard result == KERN_SUCCESS, let cpuInfo else {
            return []
        }

        defer {
            let byteCount = vm_size_t(Int(processorInfoCount) * MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: cpuInfo)), byteCount)
        }

        let stride = Int(CPU_STATE_MAX)
        return (0..<Int(processorCount)).map { index in
            let base = index * stride
            return CPUTicks(
                user: UInt64(cpuInfo[base + Int(CPU_STATE_USER)]),
                system: UInt64(cpuInfo[base + Int(CPU_STATE_SYSTEM)]),
                nice: UInt64(cpuInfo[base + Int(CPU_STATE_NICE)]),
                idle: UInt64(cpuInfo[base + Int(CPU_STATE_IDLE)])
            )
        }
    }

    private func cpuUsage(from ticks: [CPUTicks]) -> CPUUsage {
        guard !ticks.isEmpty else { return CPUUsage(totalPercent: 0, userPercent: 0, systemPercent: 0, idlePercent: 100) }

        let sample: CPUTicks
        if previousCPUTicks.count == ticks.count {
            let deltas = zip(previousCPUTicks, ticks).map { previous, current in
                current.delta(from: previous)
            }
            sample = CPUTicks.aggregate(deltas)
        } else {
            sample = CPUTicks.aggregate(ticks)
        }

        previousCPUTicks = ticks
        guard sample.total > 0 else {
            return CPUUsage(totalPercent: 0, userPercent: 0, systemPercent: 0, idlePercent: 100)
        }

        let total = Double(sample.total)
        let user = Double(sample.user + sample.nice) / total * 100
        let system = Double(sample.system) / total * 100
        let idle = Double(sample.idle) / total * 100

        return CPUUsage(
            totalPercent: roundedPercent(user + system),
            userPercent: roundedPercent(user),
            systemPercent: roundedPercent(system),
            idlePercent: roundedPercent(idle)
        )
    }

    private func loadAverage() -> [Double] {
        var values = [Double](repeating: 0, count: 3)
        let count = values.withUnsafeMutableBufferPointer { buffer in
            getloadavg(buffer.baseAddress, Int32(buffer.count))
        }
        guard count > 0 else { return [] }
        return values.prefix(Int(count)).map { round($0 * 100) / 100 }
    }

    private func memorySnapshot() -> [String: Any] {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let status = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }

        let totalBytes = ProcessInfo.processInfo.physicalMemory
        guard status == KERN_SUCCESS else {
            return [
                "totalBytes": int64(totalBytes),
                "usedBytes": 0,
                "freeBytes": int64(totalBytes),
                "usagePercent": 0
            ]
        }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let pageBytes = UInt64(pageSize)
        let appPages = UInt64(max(0, Int64(stats.internal_page_count) - Int64(stats.purgeable_count)))
        let wiredPages = UInt64(stats.wire_count)
        let compressedPages = UInt64(stats.compressor_page_count)
        let cachedPages = UInt64(stats.external_page_count + stats.purgeable_count)
        let freePages = UInt64(stats.free_count + stats.speculative_count)
        let appBytes = appPages * pageBytes
        let wiredBytes = wiredPages * pageBytes
        let compressedBytes = compressedPages * pageBytes
        let cachedBytes = min(totalBytes, cachedPages * pageBytes)
        let freeBytes = min(totalBytes, freePages * UInt64(pageSize))
        let usedBytes = min(totalBytes, appBytes + wiredBytes + compressedBytes)
        let availableBytes = min(totalBytes, freeBytes + cachedBytes)

        return [
            "totalBytes": int64(totalBytes),
            "usedBytes": int64(usedBytes),
            "appBytes": int64(appBytes),
            "wiredBytes": int64(wiredBytes),
            "compressedBytes": int64(compressedBytes),
            "cachedBytes": int64(cachedBytes),
            "freeBytes": int64(freeBytes),
            "availableBytes": int64(availableBytes),
            "usagePercent": roundedPercent(Double(usedBytes) / Double(max(totalBytes, 1)) * 100)
        ]
    }

    private func diskSnapshot() -> [String: Any] {
        let path = NSHomeDirectory()
        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: path),
              let total = attributes[.systemSize] as? NSNumber,
              let free = attributes[.systemFreeSize] as? NSNumber
        else {
            return [
                "path": path,
                "totalBytes": 0,
                "usedBytes": 0,
                "freeBytes": 0,
                "usagePercent": 0
            ]
        }

        let totalBytes = total.uint64Value
        let freeBytes = min(totalBytes, free.uint64Value)
        let usedBytes = totalBytes - freeBytes

        return [
            "path": path,
            "totalBytes": int64(totalBytes),
            "usedBytes": int64(usedBytes),
            "freeBytes": int64(freeBytes),
            "usagePercent": roundedPercent(Double(usedBytes) / Double(max(totalBytes, 1)) * 100)
        ]
    }

    private func powerSnapshot() -> [String: Any] {
        [
            "lowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled,
            "thermalState": thermalStateLabel(ProcessInfo.processInfo.thermalState),
            "uptimeSeconds": Int(ProcessInfo.processInfo.systemUptime)
        ]
    }

    private func thermalStateLabel(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:
            return "nominal"
        case .fair:
            return "fair"
        case .serious:
            return "serious"
        case .critical:
            return "critical"
        @unknown default:
            return "unknown"
        }
    }

    private func roundedPercent(_ value: Double) -> Double {
        max(0, min(100, round(value * 10) / 10))
    }

    private func int64(_ value: UInt64) -> Int64 {
        Int64(min(value, UInt64(Int64.max)))
    }
}

private final class SMCFanReader {
    private static let kernelSelector: UInt32 = 2
    private static let readBytesCommand: UInt8 = 5
    private static let readKeyInfoCommand: UInt8 = 9

    private var connection: io_connect_t = 0

    init() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }

        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == kIOReturnSuccess else {
            connection = 0
            return
        }
    }

    deinit {
        if connection != 0 {
            IOServiceClose(connection)
        }
    }

    func snapshot() -> [String: Any] {
        guard let fanCount = readFanCount() else {
            return ["available": false, "count": 0, "items": []]
        }

        let items = (0..<fanCount).map { index -> [String: Any] in
            var item: [String: Any] = ["index": index]
            if let actualRPM = readRPM(key: "F\(index)Ac") {
                item["actualRPM"] = Int(actualRPM.rounded())
            }
            if let maximumRPM = readRPM(key: "F\(index)Mx") {
                item["maximumRPM"] = Int(maximumRPM.rounded())
            }
            return item
        }

        return [
            "available": true,
            "count": fanCount,
            "items": items,
            "source": "AppleSMC"
        ]
    }

    private func readFanCount() -> Int? {
        guard let value = readKey("FNum"), let firstByte = value.bytes.first else { return nil }
        let count = Int(firstByte)
        return (0...8).contains(count) ? count : nil
    }

    private func readRPM(key: String) -> Double? {
        guard let value = readKey(key) else { return nil }

        let rpm: Double?
        switch value.dataType {
        case "flt ":
            guard value.bytes.count >= 4 else { return nil }
            let bits = UInt32(value.bytes[0])
                | UInt32(value.bytes[1]) << 8
                | UInt32(value.bytes[2]) << 16
                | UInt32(value.bytes[3]) << 24
            rpm = Double(Float(bitPattern: bits))
        case "fpe2":
            guard value.bytes.count >= 2 else { return nil }
            let raw = UInt16(value.bytes[0]) << 8 | UInt16(value.bytes[1])
            rpm = Double(raw) / 4
        case "ui16":
            guard value.bytes.count >= 2 else { return nil }
            rpm = Double(UInt16(value.bytes[0]) << 8 | UInt16(value.bytes[1]))
        default:
            rpm = nil
        }

        guard let rpm, rpm.isFinite, rpm >= 0, rpm <= 20_000 else { return nil }
        return rpm
    }

    private func readKey(_ key: String) -> (bytes: [UInt8], dataType: String)? {
        guard connection != 0, let keyCode = fourCharacterCode(key) else { return nil }

        var infoInput = SMCParameter()
        infoInput.key = keyCode
        infoInput.data8 = Self.readKeyInfoCommand
        guard let infoOutput = call(input: infoInput), infoOutput.result == 0 else { return nil }

        let dataSize = Int(infoOutput.keyInfo.dataSize)
        guard dataSize > 0, dataSize <= 32 else { return nil }

        var readInput = SMCParameter()
        readInput.key = keyCode
        readInput.keyInfo.dataSize = infoOutput.keyInfo.dataSize
        readInput.data8 = Self.readBytesCommand
        guard let readOutput = call(input: readInput), readOutput.result == 0 else { return nil }

        let bytes = withUnsafeBytes(of: readOutput.bytes) { buffer in
            Array(buffer.prefix(dataSize))
        }
        return (bytes, fourCharacterString(infoOutput.keyInfo.dataType))
    }

    private func call(input: SMCParameter) -> SMCParameter? {
        var input = input
        var output = SMCParameter()
        var outputSize = MemoryLayout<SMCParameter>.stride
        let result = IOConnectCallStructMethod(
            connection,
            Self.kernelSelector,
            &input,
            MemoryLayout<SMCParameter>.stride,
            &output,
            &outputSize
        )
        return result == kIOReturnSuccess ? output : nil
    }

    private func fourCharacterCode(_ value: String) -> UInt32? {
        guard value.utf8.count == 4 else { return nil }
        return value.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
    }

    private func fourCharacterString(_ value: UInt32) -> String {
        let bytes = [
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }
}

private struct SMCParameter {
    typealias Bytes = (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    )

    struct Version {
        var major: UInt8 = 0
        var minor: UInt8 = 0
        var build: UInt8 = 0
        var reserved: UInt8 = 0
        var release: UInt16 = 0
    }

    struct PowerLimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPowerLimit: UInt32 = 0
        var gpuPowerLimit: UInt32 = 0
        var memoryPowerLimit: UInt32 = 0
    }

    struct KeyInfo {
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    var key: UInt32 = 0
    var version = Version()
    var powerLimitData = PowerLimitData()
    var keyInfo = KeyInfo()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: Bytes = (
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    )
}

@objc private protocol HIDEventSystemClient: NSObjectProtocol {}
@objc private protocol HIDServiceClient: NSObjectProtocol {}
@objc private protocol HIDEvent: NSObjectProtocol {}

private final class AppleSiliconTemperatureReader {
    private typealias CreateClient = @convention(c) (CFAllocator?) -> HIDEventSystemClient?
    private typealias SetMatching = @convention(c) (HIDEventSystemClient?, CFDictionary?) -> Void
    private typealias CopyServices = @convention(c) (HIDEventSystemClient?) -> CFArray?
    private typealias CopyProperty = @convention(c) (HIDServiceClient?, CFString?) -> CFTypeRef?
    private typealias CopyEvent = @convention(c) (HIDServiceClient?, Int64, Int32, Int64) -> HIDEvent?
    private typealias GetFloatValue = @convention(c) (HIDEvent?, UInt32) -> Double

    private var frameworkHandle: UnsafeMutableRawPointer?
    private var client: HIDEventSystemClient?
    private var services: [HIDServiceClient] = []
    private var copyEvent: CopyEvent?
    private var getFloatValue: GetFloatValue?

    init() {
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY),
              let createSymbol = dlsym(handle, "IOHIDEventSystemClientCreate"),
              let matchingSymbol = dlsym(handle, "IOHIDEventSystemClientSetMatching"),
              let servicesSymbol = dlsym(handle, "IOHIDEventSystemClientCopyServices"),
              let propertySymbol = dlsym(handle, "IOHIDServiceClientCopyProperty"),
              let eventSymbol = dlsym(handle, "IOHIDServiceClientCopyEvent"),
              let valueSymbol = dlsym(handle, "IOHIDEventGetFloatValue")
        else {
            return
        }

        frameworkHandle = handle
        let createClient = unsafeBitCast(createSymbol, to: CreateClient.self)
        let setMatching = unsafeBitCast(matchingSymbol, to: SetMatching.self)
        let copyServices = unsafeBitCast(servicesSymbol, to: CopyServices.self)
        let copyProperty = unsafeBitCast(propertySymbol, to: CopyProperty.self)
        copyEvent = unsafeBitCast(eventSymbol, to: CopyEvent.self)
        getFloatValue = unsafeBitCast(valueSymbol, to: GetFloatValue.self)

        guard let client = createClient(kCFAllocatorDefault) else { return }
        self.client = client
        setMatching(client, [
            "PrimaryUsage": 5,
            "PrimaryUsagePage": 65_280
        ] as CFDictionary)

        guard let serviceArray = copyServices(client) else { return }
        var namedServices: [(name: String, service: HIDServiceClient)] = []
        var seenNames = Set<String>()

        for index in 0..<CFArrayGetCount(serviceArray) {
            guard let rawService = CFArrayGetValueAtIndex(serviceArray, index) else { continue }
            let service = unsafeBitCast(rawService, to: HIDServiceClient.self)
            guard let name = copyProperty(service, "Product" as CFString) as? String,
                  name.hasPrefix("PMU "),
                  name != "PMU tcal",
                  seenNames.insert(name).inserted else {
                continue
            }
            namedServices.append((name, service))
        }

        let dieServices = namedServices.filter { $0.name.hasPrefix("PMU tdie") }
        services = (dieServices.isEmpty ? namedServices : dieServices).map(\.service)
    }

    deinit {
        if let frameworkHandle {
            dlclose(frameworkHandle)
        }
    }

    func snapshot() -> [String: Any] {
        guard let copyEvent, let getFloatValue, !services.isEmpty else {
            return ["available": false]
        }

        let values = services.compactMap { service -> Double? in
            guard let event = copyEvent(service, 15, 0, 0) else { return nil }
            let value = getFloatValue(event, UInt32(15 << 16))
            guard value >= 0, value <= 125 else { return nil }
            return value
        }

        guard let hotspot = values.max() else {
            return ["available": false]
        }

        return [
            "available": true,
            "socCelsius": round(hotspot * 10) / 10,
            "sensorCount": values.count,
            "source": "Apple Silicon HID"
        ]
    }
}

private struct CPUTicks {
    let user: UInt64
    let system: UInt64
    let nice: UInt64
    let idle: UInt64

    var total: UInt64 {
        user + system + nice + idle
    }

    func delta(from previous: CPUTicks) -> CPUTicks {
        CPUTicks(
            user: user.saturatingSubtract(previous.user),
            system: system.saturatingSubtract(previous.system),
            nice: nice.saturatingSubtract(previous.nice),
            idle: idle.saturatingSubtract(previous.idle)
        )
    }

    static func aggregate(_ ticks: [CPUTicks]) -> CPUTicks {
        ticks.reduce(CPUTicks(user: 0, system: 0, nice: 0, idle: 0)) { result, tick in
            CPUTicks(
                user: result.user + tick.user,
                system: result.system + tick.system,
                nice: result.nice + tick.nice,
                idle: result.idle + tick.idle
            )
        }
    }
}

private struct CPUUsage {
    let totalPercent: Double
    let userPercent: Double
    let systemPercent: Double
    let idlePercent: Double
}

private extension UInt64 {
    func saturatingSubtract(_ other: UInt64) -> UInt64 {
        self >= other ? self - other : 0
    }
}
