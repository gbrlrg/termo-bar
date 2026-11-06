import Foundation
import IOKit

/// Potência de GPU por processo: a energia total da GPU (IOReport) dividida pela
/// fatia de tempo de GPU que cada processo usou no intervalo (IORegistry, por cliente Metal).
final class GPUSampler {
    struct Measurement: Sendable {
        /// Potência atribuída a cada processo (W).
        let perProcess: [pid_t: Double]
        /// Potência total da GPU (W).
        let total: Double
    }

    private var subscription: IOReportSubscriptionRef?
    private var channels: CFMutableDictionary?
    private var lastReport: CFDictionary?
    private var lastGPUTime: [pid_t: UInt64] = [:]
    private var lastDate: Date?
    /// Rateio pelo tempo de GPU, com a correção do WindowServer (`GPUAttribution`).
    private var attribution = GPUAttribution()

    /// Nome de cada cliente da GPU, como o registro informa ("WindowServer", "gpuload"…).
    private(set) var clientNames: [pid_t: String] = [:]

    init() {
        guard let group = IOReportCopyChannelsInGroup("Energy Model" as CFString, nil, 0, 0, 0),
            let channels = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, group)
        else { return }
        var subscribed: Unmanaged<CFMutableDictionary>?
        subscription = IOReportCreateSubscription(nil, channels, &subscribed, 0, nil)
        self.channels = subscribed?.takeRetainedValue() ?? channels
    }

    /// Potência da GPU desde a chamada anterior; `nil` na primeira ou sem acesso ao IOReport.
    func sample() -> Measurement? {
        let now = Date()
        let usage = Self.gpuUsage()
        clientNames = usage.names
        let joules = gpuEnergy()
        defer {
            lastGPUTime = usage.times
            lastDate = now
        }
        guard let lastDate, let joules else { return nil }
        let elapsed = now.timeIntervalSince(lastDate)
        guard elapsed > 0 else { return nil }

        let occupancy = GPUAttribution.occupancy(times: usage.times, previous: lastGPUTime, elapsed: elapsed)
        let watts = joules / elapsed
        return Measurement(
            perProcess: attribution.attribute(watts, occupancy: occupancy, names: usage.names), total: watts)
    }

    /// Energia da GPU (J) desde a leitura anterior do IOReport.
    private func gpuEnergy() -> Double? {
        guard let subscription, let channels,
            let current = IOReportCreateSamples(subscription, channels, nil)
        else { return nil }
        defer { lastReport = current }
        guard let previous = lastReport,
            let delta = IOReportCreateSamplesDelta(previous, current, nil) as? [String: Any],
            let items = delta["IOReportChannels"] as? [NSDictionary]
        else { return nil }

        for item in items {
            let channel = item as CFDictionary
            guard IOReportChannelGetChannelName(channel)?.takeUnretainedValue() as String? == "GPU Energy" else {
                continue
            }
            let value = Double(IOReportSimpleGetIntegerValue(channel, 0))
            return switch IOReportChannelGetUnitLabel(channel)?.takeUnretainedValue() as String? {
            case "mJ": value / 1e3
            case "uJ": value / 1e6
            default: value / 1e9
            }
        }
        return nil
    }

    /// Tempo de GPU acumulado (ns) e nome de cada processo, somando os clientes Metal de cada um.
    private static func gpuUsage() -> (times: [pid_t: UInt64], names: [pid_t: String]) {
        var times: [pid_t: UInt64] = [:]
        var names: [pid_t: String] = [:]
        var accelerators: io_iterator_t = 0
        guard
            IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &accelerators)
                == KERN_SUCCESS
        else { return (times, names) }
        defer { IOObjectRelease(accelerators) }

        forEachEntry(in: accelerators) { accelerator in
            var clients: io_iterator_t = 0
            guard IORegistryEntryGetChildIterator(accelerator, kIOServicePlane, &clients) == KERN_SUCCESS else {
                return
            }
            defer { IOObjectRelease(clients) }
            forEachEntry(in: clients) { client in
                guard let creator: String = property("IOUserClientCreator", of: client),
                    let (pid, name) = GPUAttribution.parse(creator: creator),
                    let usage: [[String: Any]] = property("AppUsage", of: client)
                else { return }
                times[pid, default: 0] += usage.reduce(UInt64(0)) {
                    $0 + (($1["accumulatedGPUTime"] as? NSNumber)?.uint64Value ?? 0)
                }
                names[pid] = name
            }
        }
        return (times, names)
    }

    /// Percorre um iterador do IORegistry, liberando cada entrada depois do uso.
    private static func forEachEntry(in iterator: io_iterator_t, _ body: (io_registry_entry_t) -> Void) {
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            body(entry)
        }
    }

    private static func property<T>(_ key: String, of entry: io_registry_entry_t) -> T? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? T
    }
}
