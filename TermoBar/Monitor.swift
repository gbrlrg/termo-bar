import AppKit
import Observation

struct Sample: Codable {
    let date: Date
    /// Período que a amostra representa (intervalo de leitura, ou 60 s nos resumos por minuto).
    let duration: TimeInterval
    /// Média dos sensores do die no período.
    let temp: Double
    /// Sensor mais quente no período.
    let maxTemp: Double
    let apps: [String]
    let front: String?
    /// Potência média por app no período; `nil` quando não houve medição de energia.
    let power: [String: Power]?
    let pressure: Int?
    /// Potência total da GPU (W).
    let gpu: Double?

    var throttling: Bool { (pressure ?? 0) >= ThermalPressure.heavy.rawValue }
}

@MainActor @Observable
final class Monitor {
    /// Único: o SwiftUI pode instanciar a struct do app mais de uma vez.
    static let shared = Monitor()

    static let recentWindow: TimeInterval = 3600
    static let minuteWindow: TimeInterval = 7 * 86400
    static let highlighted = 5
    static let othersID = "outros"

    /// Leituras finas da última hora.
    private(set) var recent: [Sample] = []
    /// Resumos por minuto dos últimos 7 dias.
    private(set) var minutes: [Sample] = []
    private(set) var appNames: [String: String] = [:]
    /// Posição na paleta dos apps que mais gastaram na hora; estável enquanto continuarem no topo.
    private(set) var slots: [String: Int] = [:]
    private(set) var pressure = ThermalPressure.current
    /// Última leitura de cada sensor (tela de Ajustes).
    private(set) var sensors: [TemperatureSensors.Sensor] = []
    var showAllSensors = false

    let chipName: String = {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }()

    let store = Store()
    private let prefs = Preferences.shared
    private let reader = TemperatureSensors()
    private let energy = EnergySampler()
    private let alerts = Alerts()
    private var timer: Timer?
    private var pending: [TemperatureSensors.Reading] = []
    private var lastSampleDate: Date?
    private var currentMinute: Date?
    private var lastPrune = Date.distantPast
    private var savedNames: [String: String] = [:]

    private init() {
        let now = Date()
        appNames = store.loadNames()
        savedNames = appNames
        recent = store.load(resolution: .raw, since: now.addingTimeInterval(-Self.recentWindow))
        minutes = store.load(resolution: .minute, since: now.addingTimeInterval(-Self.minuteWindow))
        assignSlots()
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.second() }
        }
        timer.tolerance = 0.2
        self.timer = timer
        second()
        alerts.requestAuthorizationIfNeeded()
    }

    var current: Sample? { recent.last }

    /// Temperatura conforme a fonte escolhida (média do chip ou ponto mais quente).
    func temperature(of sample: Sample) -> Double {
        prefs.source == .average ? sample.temp : sample.maxTemp
    }

    /// Potência somada dos apps na leitura mais recente que tem medição de energia.
    var currentPower: Double? {
        recent.last { $0.power != nil }?.power?.values.reduce(0) { $0 + $1.total }
    }

    func name(_ id: String) -> String {
        id == Self.othersID ? "Outros" : appNames[id] ?? id
    }

    func sample(near date: Date, in samples: [Sample]) -> Sample? {
        samples.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    // MARK: - Coleta

    /// A cada segundo lê os sensores; a cada intervalo fecha uma amostra com a média das leituras.
    private func second() {
        if let reading = reader.read(includeOthers: showAllSensors) {
            pending.append(reading)
            sensors = reading.sensors
        }
        pressure = .current
        let now = Date()
        if lastSampleDate.map({ now.timeIntervalSince($0) >= prefs.sampleInterval - 0.25 }) ?? true {
            takeSample(at: now)
        }
    }

    private func takeSample(at now: Date) {
        let measured = energy.sample()
        guard !pending.isEmpty else { return }
        let temp = pending.map(\.average).reduce(0, +) / Double(pending.count)
        let maxTemp = pending.map(\.maximum).max() ?? temp
        pending.removeAll()

        let workspace = NSWorkspace.shared
        var ids: [String] = []
        for app in workspace.runningApplications where app.activationPolicy == .regular {
            let id = Self.identifier(of: app)
            ids.append(id)
            appNames[id] = app.localizedName ?? id
        }
        var power: [String: Power]?
        if let measured {
            var byApp: [String: Power] = [:]
            for (group, watts) in measured.byGroup {
                byApp[group.id, default: .zero] = byApp[group.id, default: .zero] + watts
                appNames[group.id] = group.name
            }
            power = byApp.filter { $0.value.total >= 0.005 }
        }
        let duration = lastSampleDate.map { min(now.timeIntervalSince($0), prefs.sampleInterval * 3) } ?? prefs.sampleInterval
        lastSampleDate = now

        let sample = Sample(date: now, duration: duration, temp: temp, maxTemp: maxTemp, apps: ids,
                            front: workspace.frontmostApplication.map(Self.identifier), power: power,
                            pressure: pressure.rawValue, gpu: measured?.gpuTotal)
        recent.append(sample)
        store.insert(sample, resolution: .raw)
        rollMinute(now)
        prune(now: now)
        assignSlots()
        saveNewNames()
        alerts.evaluate(monitor: self, prefs: prefs)
        #if DEBUG
        if ProcessInfo.processInfo.environment["TERMOBAR_LOG"] != nil {
            let top = (power ?? [:]).sorted { $0.value.total > $1.value.total }.prefix(4)
                .map { "\(name($0.key)) cpu \(formatWatts($0.value.cpu)) gpu \(formatWatts($0.value.gpu))" }
            print(String(format: "%.1f°C max %.1f gpu %.2fW p%d | ", temp, maxTemp, measured?.gpuTotal ?? -1, pressure.rawValue)
                  + top.joined(separator: " | "))
        }
        #endif
    }

    private static func identifier(of app: NSRunningApplication) -> String {
        app.bundleIdentifier ?? app.localizedName ?? "pid-\(app.processIdentifier)"
    }

    /// Quando o minuto do relógio vira, resume as leituras do minuto anterior.
    private func rollMinute(_ now: Date) {
        let minute = Calendar.current.dateInterval(of: .minute, for: now)?.start ?? now
        defer { currentMinute = minute }
        guard let previous = currentMinute, previous != minute else { return }
        let inMinute = recent.filter { $0.date > previous && $0.date <= minute }
        guard let summary = Self.aggregate(inMinute, at: previous) else { return }
        minutes.append(summary)
        store.insert(summary, resolution: .minute)
    }

    static func aggregate(_ samples: [Sample], at date: Date) -> Sample? {
        guard !samples.isEmpty else { return nil }
        let duration = samples.map(\.duration).reduce(0, +)
        func weighted(_ value: (Sample) -> Double) -> Double {
            samples.reduce(0) { $0 + value($1) * $1.duration } / duration
        }
        let measured = samples.filter { $0.power != nil }
        var power: [String: Power]?
        if !measured.isEmpty {
            let measuredDuration = measured.map(\.duration).reduce(0, +)
            var energy: [String: Power] = [:]
            for sample in measured {
                for (id, watts) in sample.power ?? [:] { energy[id, default: .zero] = energy[id, default: .zero] + watts * sample.duration }
            }
            power = energy.mapValues { $0 * (1 / measuredDuration) }.filter { $0.value.total >= 0.005 }
        }
        let fronts = Dictionary(grouping: samples.compactMap(\.front), by: { $0 }).mapValues(\.count)
        let gpus = samples.compactMap(\.gpu)
        return Sample(
            date: date, duration: 60, temp: weighted(\.temp), maxTemp: samples.map(\.maxTemp).max() ?? 0,
            apps: Array(Set(samples.flatMap(\.apps))).sorted(), front: fronts.max { $0.value < $1.value }?.key,
            power: power, pressure: samples.compactMap(\.pressure).max(),
            gpu: gpus.isEmpty ? nil : gpus.reduce(0, +) / Double(gpus.count))
    }

    private func prune(now: Date) {
        let recentCutoff = now.addingTimeInterval(-Self.recentWindow)
        if let first = recent.firstIndex(where: { $0.date >= recentCutoff }), first > 0 { recent.removeFirst(first) }
        let minuteCutoff = now.addingTimeInterval(-Self.minuteWindow)
        if let first = minutes.firstIndex(where: { $0.date >= minuteCutoff }), first > 0 { minutes.removeFirst(first) }
        guard now.timeIntervalSince(lastPrune) >= 600 else { return }
        lastPrune = now
        store.prune(resolution: .raw, before: now.addingTimeInterval(-86400))
        store.prune(resolution: .minute, before: now.addingTimeInterval(-Double(prefs.retentionDays) * 86400))
    }

    private func saveNewNames() {
        let changed = appNames.filter { savedNames[$0.key] != $0.value }
        guard !changed.isEmpty else { return }
        store.saveNames(changed)
        savedNames.merge(changed) { $1 }
    }

    private func assignSlots() {
        var energyByApp: [String: Double] = [:]
        for sample in recent {
            for (id, watts) in sample.power ?? [:] { energyByApp[id, default: 0] += watts.total * sample.duration }
        }
        let top = energyByApp.sorted { $0.value > $1.value }.prefix(Self.highlighted).map(\.key)
        slots = slots.filter { top.contains($0.key) }
        for id in top where slots[id] == nil {
            let used = Set(slots.values)
            slots[id] = (0..<Self.highlighted).first { !used.contains($0) }
        }
    }

    func clearHistory() {
        store.deleteAll()
        recent.removeAll()
        minutes.removeAll()
        savedNames = [:]
        saveNewNames()
    }
}
