import Foundation
import IOKit

/// Potência de GPU por processo: a energia total da GPU (IOReport) dividida pela
/// fatia de tempo de GPU que cada processo usou no intervalo (IORegistry, por cliente Metal).
final class GPUSampler {
    private var subscription: IOReportSubscriptionRef?
    private var channels: CFMutableDictionary?
    private var lastReport: CFDictionary?
    private var lastTime: [pid_t: UInt64] = [:]
    private var lastDate: Date?
    /// Nome de cada cliente da GPU, como o registro informa ("WindowServer", "gpuload"…).
    private(set) var names: [pid_t: String] = [:]
    /// Potência típica da GPU quando só o WindowServer a usa (W).
    private var compositorBaseline = 0.3

    init() {
        guard let group = IOReportCopyChannelsInGroup("Energy Model" as CFString, nil, 0, 0, 0) else { return }
        let channels = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, group)!
        var subscribed: Unmanaged<CFMutableDictionary>?
        subscription = IOReportCreateSubscription(nil, channels, &subscribed, 0, nil)
        self.channels = subscribed?.takeRetainedValue() ?? channels
    }

    /// Watts de GPU por PID desde a chamada anterior (`nil` na primeira) e o total da GPU.
    func sample() -> (perProcess: [pid_t: Double], total: Double)? {
        let now = Date()
        let (times, names) = Self.gpuTimes()
        self.names = names
        let joules = gpuEnergy()
        defer {
            lastTime = times
            lastDate = now
        }
        guard let lastDate, let joules else { return nil }
        let dt = now.timeIntervalSince(lastDate)
        guard dt > 0 else { return nil }
        var deltas: [pid_t: Double] = [:]
        for (pid, time) in times {
            // Processo que começou a usar a GPU neste intervalo: todo o tempo dele é daqui.
            let previous = lastTime[pid].flatMap { $0 <= time ? $0 : nil } ?? 0
            if time > previous { deltas[pid] = min(Double(time - previous) / 1e9 / dt, 1) }
        }
        let watts = joules / dt
        return (attribute(watts, rates: deltas, names: names), watts)
    }

    /// Divide a potência da GPU pelos processos na proporção do tempo de GPU de cada um.
    ///
    /// O WindowServer é exceção: o tempo de GPU dele inclui a espera dos quadros na fila e
    /// infla quando outro processo ocupa a GPU, sem que ele gaste mais. Com disputa, ele fica
    /// com no máximo 1,5× a potência que a GPU tem quando só ele a usa, e o resto vai para
    /// quem disputa. Sem disputa, essa potência é aprendida como referência.
    private func attribute(_ watts: Double, rates: [pid_t: Double], names: [pid_t: String]) -> [pid_t: Double] {
        let busy = rates.values.reduce(0, +)
        guard busy > 0 else { return [:] }
        guard let compositor = names.first(where: { $0.value == "WindowServer" })?.key,
              let compositorRate = rates[compositor] else {
            return rates.mapValues { watts * $0 / busy }
        }
        let others = busy - compositorRate
        if others < 0.05 {
            compositorBaseline = compositorBaseline * 0.9 + watts * 0.1
            return rates.mapValues { watts * $0 / busy }
        }
        let compositorWatts = min(watts * compositorRate / busy, max(compositorBaseline * 1.5, 0.1))
        var result = rates.filter { $0.key != compositor }.mapValues { (watts - compositorWatts) * $0 / others }
        result[compositor] = compositorWatts
        return result
    }

    private func gpuEnergy() -> Double? {
        guard let subscription, let channels,
              let current = IOReportCreateSamples(subscription, channels, nil) else { return nil }
        defer { lastReport = current }
        guard let previous = lastReport,
              let delta = IOReportCreateSamplesDelta(previous, current, nil) as? [String: Any],
              let items = delta["IOReportChannels"] as? [NSDictionary] else { return nil }
        for item in items {
            let channel = item as CFDictionary
            guard IOReportChannelGetChannelName(channel)?.takeUnretainedValue() as String? == "GPU Energy" else { continue }
            let value = Double(IOReportSimpleGetIntegerValue(channel, 0))
            switch IOReportChannelGetUnitLabel(channel)?.takeUnretainedValue() as String? {
            case "mJ": return value / 1e3
            case "uJ": return value / 1e6
            default: return value / 1e9
            }
        }
        return nil
    }

    /// Tempo de GPU acumulado (ns) por processo, somando os clientes Metal de cada um.
    private static func gpuTimes() -> ([pid_t: UInt64], [pid_t: String]) {
        var result: [pid_t: UInt64] = [:]
        var names: [pid_t: String] = [:]
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else { return (result, names) }
        defer { IOObjectRelease(iterator) }
        while case let accelerator = IOIteratorNext(iterator), accelerator != 0 {
            defer { IOObjectRelease(accelerator) }
            var children: io_iterator_t = 0
            guard IORegistryEntryGetChildIterator(accelerator, kIOServicePlane, &children) == KERN_SUCCESS else { continue }
            defer { IOObjectRelease(children) }
            while case let client = IOIteratorNext(children), client != 0 {
                defer { IOObjectRelease(client) }
                guard let creator = IORegistryEntryCreateCFProperty(client, "IOUserClientCreator" as CFString, kCFAllocatorDefault, 0)?
                        .takeRetainedValue() as? String,
                      let (pid, name) = Self.parse(creator: creator),
                      let usage = IORegistryEntryCreateCFProperty(client, "AppUsage" as CFString, kCFAllocatorDefault, 0)?
                        .takeRetainedValue() as? [[String: Any]] else { continue }
                let time = usage.reduce(UInt64(0)) { $0 + (($1["accumulatedGPUTime"] as? NSNumber)?.uint64Value ?? 0) }
                result[pid, default: 0] += time
                names[pid] = name
            }
        }
        return (result, names)
    }

    /// "pid 415, WindowServer" → (415, "WindowServer")
    private static func parse(creator: String) -> (pid_t, String)? {
        guard creator.hasPrefix("pid "), let comma = creator.firstIndex(of: ","),
              let pid = pid_t(creator.dropFirst(4).prefix { $0.isNumber }) else { return nil }
        return (pid, creator[creator.index(after: comma)...].trimmingCharacters(in: .whitespaces))
    }
}

/// Nível de pressão térmica publicado pelo kernel; mais fino que `ProcessInfo.thermalState`.
enum ThermalPressure: Int, Codable, CaseIterable {
    case nominal, moderate, heavy, critical, sleeping

    private nonisolated(unsafe) static var token: Int32 = {
        var token: Int32 = 0
        notify_register_check("com.apple.system.thermalpressurelevel", &token)
        return token
    }()

    static var current: ThermalPressure {
        var state: UInt64 = 0
        notify_get_state(token, &state)
        return ThermalPressure(rawValue: Int(state)) ?? .nominal
    }

    /// A partir de "pesada" o macOS reduz a frequência do chip.
    var throttling: Bool { self >= .heavy }

    static func >= (a: Self, b: Self) -> Bool { a.rawValue >= b.rawValue }
}
