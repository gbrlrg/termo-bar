import AppKit
import Observation

/// Coleta as leituras, mantém o histórico recente em memória e o grava no disco.
///
/// A cada segundo lê os sensores; a cada intervalo de registro fecha uma amostra com a média
/// das leituras e a energia por app, e a cada minuto do relógio grava um resumo.
@MainActor @Observable
final class Monitor {
    enum HistoryError: LocalizedError {
        case unavailable

        var errorDescription: String? { "O histórico não está disponível." }
    }

    /// Leituras finas mantidas em memória.
    static let recentWindow: TimeInterval = 3600
    /// Resumos por minuto mantidos em memória.
    static let minuteWindow: TimeInterval = 7 * 86400
    /// Quantos apps ganham cor própria no gráfico de energia.
    static let highlightedApps = 5

    private static let readInterval: TimeInterval = 1
    /// Tolerância para fechar o registro no tique mais próximo do intervalo escolhido.
    private static let intervalTolerance: TimeInterval = 0.25
    /// Um registro nunca representa mais que isso vezes o intervalo (Mac acordando, por exemplo).
    private static let maxDurationFactor = 3.0
    /// Leituras finas ficam no disco por um dia; os resumos, pelo período escolhido.
    private static let rawRetention: TimeInterval = 86400
    private static let diskPruneInterval: TimeInterval = 600

    /// Leituras finas da última hora.
    private(set) var recent: [Sample] = []
    /// Resumos por minuto dos últimos 7 dias.
    private(set) var minutes: [Sample] = []
    private(set) var appNames: [String: String] = [:]
    /// Cor de cada app que mais gastou na última hora; estável enquanto continuar no topo.
    private(set) var palette = PaletteSlots(capacity: Monitor.highlightedApps)
    private(set) var pressure = ThermalPressure.nominal
    /// Última leitura de cada sensor (tela de Ajustes).
    private(set) var sensors: [TemperatureSensors.Sensor] = []
    var showAllSensors = false

    let chipName = SystemInfo.chipName

    private let preferences: Preferences
    private let alerts: AlertNotifier
    private let store: HistoryStore?
    private let temperatureSensors = TemperatureSensors()
    private let energySampler = EnergySampler()
    private let pressureReader = ThermalPressureReader()

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var pendingReadings: [TemperatureSensors.Reading] = []
    @ObservationIgnored private var lastSampleDate: Date?
    @ObservationIgnored private var currentMinute: Date?
    @ObservationIgnored private var lastDiskPrune = Date.distantPast
    @ObservationIgnored private var savedNames: [String: String] = [:]

    init(preferences: Preferences, alerts: AlertNotifier, store: HistoryStore?) {
        self.preferences = preferences
        self.alerts = alerts
        self.store = store
        loadHistory()
        startTimer()
        alerts.requestAuthorizationIfNeeded()
    }

    // MARK: - Consultas

    var current: Sample? { recent.last }

    /// Temperatura conforme a fonte escolhida (média do chip ou ponto mais quente).
    func temperature(of sample: Sample) -> Double {
        sample.temperature(for: preferences.source)
    }

    var currentTemperature: Double? { current.map(temperature(of:)) }

    /// Potência somada dos apps na leitura mais recente que tem medição de energia.
    var currentPower: Double? {
        recent.last { $0.appPower != nil }?.appPower?.values.reduce(0) { $0 + $1.total }
    }

    func name(_ id: String) -> String {
        id == AppID.others ? AppID.othersName : appNames[id] ?? id
    }

    func summary(range: TimeRange) -> RangeSummary {
        RangeSummary(
            range: range,
            history: range.usesMinuteSummaries ? minutes : recent,
            end: current?.date ?? Date(),
            highlighted: palette.apps
        ) { self.name($0) }
    }

    // MARK: - Ações

    func clearHistory() {
        persist("apagar o histórico") { try $0.deleteAll() }
        recent.removeAll()
        minutes.removeAll()
        savedNames = [:]
        saveNewNames()
    }

    func exportCSV(resolution: HistoryStore.Resolution, to url: URL) throws {
        guard let store else { throw HistoryError.unavailable }
        try store.exportCSV(resolution: resolution, to: url)
    }

    // MARK: - Coleta

    private func startTimer() {
        let timer = Timer.scheduledTimer(withTimeInterval: Self.readInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.2
        self.timer = timer
        tick()
    }

    private func tick() {
        if let reading = temperatureSensors.read(includeOthers: showAllSensors) {
            pendingReadings.append(reading)
            sensors = reading.sensors
        }
        pressure = pressureReader.read()

        let now = Date()
        let isDue =
            lastSampleDate.map {
                now.timeIntervalSince($0) >= preferences.sampleInterval - Self.intervalTolerance
            } ?? true
        if isDue { recordSample(at: now) }
    }

    private func recordSample(at now: Date) {
        // A energia é medida mesmo sem temperatura, para manter a base de comparação do próximo registro.
        let measurement = energySampler.sample()
        guard !pendingReadings.isEmpty else { return }
        let averageTemperature = pendingReadings.map(\.average).reduce(0, +) / Double(pendingReadings.count)
        let maxTemperature = pendingReadings.map(\.maximum).max() ?? averageTemperature
        pendingReadings.removeAll()

        let interval = preferences.sampleInterval
        let duration =
            lastSampleDate.map { min(now.timeIntervalSince($0), interval * Self.maxDurationFactor) } ?? interval
        lastSampleDate = now

        let sample = Sample(
            date: now,
            duration: duration,
            averageTemperature: averageTemperature,
            maxTemperature: maxTemperature,
            openApps: openApps(),
            frontmostApp: NSWorkspace.shared.frontmostApplication.map(Self.identifier),
            appPower: measurement.map { appPower(from: $0) },
            pressure: pressure.rawValue,
            gpuPower: measurement?.gpuTotal)
        recent.append(sample)
        persist("gravar a leitura") { try $0.insert(sample, resolution: .raw) }

        summarizeMinute(at: now)
        prune(now: now)
        updatePalette()
        saveNewNames()
        alerts.evaluate(recent) { self.name($0) }
        #if DEBUG
            logIfRequested(sample)
        #endif
    }

    /// Apps comuns (com ícone no Dock) abertos agora.
    private func openApps() -> [String] {
        var ids: [String] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            let id = Self.identifier(of: app)
            ids.append(id)
            appNames[id] = app.localizedName ?? id
        }
        return ids
    }

    private func appPower(from measurement: EnergySampler.Measurement) -> [String: Power] {
        var power: [String: Power] = [:]
        for (group, watts) in measurement.byGroup {
            power[group.id, default: .zero] += watts
            appNames[group.id] = group.name
        }
        return Sample.significant(power)
    }

    private static func identifier(of app: NSRunningApplication) -> String {
        app.bundleIdentifier ?? app.localizedName ?? "pid-\(app.processIdentifier)"
    }

    /// Quando o minuto do relógio vira, resume as leituras do minuto anterior.
    private func summarizeMinute(at now: Date) {
        let minute = Calendar.current.dateInterval(of: .minute, for: now)?.start ?? now
        defer { currentMinute = minute }
        guard let previous = currentMinute, previous != minute else { return }
        let samples = recent.filter { $0.date > previous && $0.date <= minute }
        guard let summary = Sample(summarizing: samples, at: previous) else { return }
        minutes.append(summary)
        persist("gravar o resumo do minuto") { try $0.insert(summary, resolution: .minute) }
    }

    private func prune(now: Date) {
        recent.removeAll { $0.date < now.addingTimeInterval(-Self.recentWindow) }
        minutes.removeAll { $0.date < now.addingTimeInterval(-Self.minuteWindow) }

        guard now.timeIntervalSince(lastDiskPrune) >= Self.diskPruneInterval else { return }
        lastDiskPrune = now
        let retention = TimeInterval(preferences.retentionDays) * 86400
        persist("limpar o histórico antigo") { store in
            try store.prune(resolution: .raw, before: now.addingTimeInterval(-Self.rawRetention))
            try store.prune(resolution: .minute, before: now.addingTimeInterval(-retention))
        }
    }

    // MARK: - Histórico

    private func loadHistory() {
        let now = Date()
        persist("carregar o histórico") { store in
            appNames = try store.names()
            recent = try store.samples(resolution: .raw, since: now.addingTimeInterval(-Self.recentWindow))
            minutes = try store.samples(resolution: .minute, since: now.addingTimeInterval(-Self.minuteWindow))
        }
        savedNames = appNames
        updatePalette()
    }

    /// Dá as cores aos apps que mais gastaram na última hora.
    private func updatePalette() {
        palette.update(ranking: recent.energyByApp().sorted { $0.value.total > $1.value.total }.map(\.key))
    }

    private func saveNewNames() {
        let changed = appNames.filter { savedNames[$0.key] != $0.value }
        guard !changed.isEmpty else { return }
        persist("gravar os nomes dos apps") { try $0.saveNames(changed) }
        savedNames.merge(changed) { $1 }
    }

    /// Executa uma operação no histórico; falhas vão para o log sem interromper a coleta.
    private func persist(_ action: String, _ operation: (HistoryStore) throws -> Void) {
        guard let store else { return }
        do {
            try operation(store)
        } catch {
            Log.history.error("Falha ao \(action, privacy: .public): \(String(describing: error), privacy: .public)")
        }
    }

    #if DEBUG
        /// TERMOBAR_LOG=1 imprime cada registro no terminal.
        private func logIfRequested(_ sample: Sample) {
            guard ProcessInfo.processInfo.environment["TERMOBAR_LOG"] != nil else { return }
            let top = (sample.appPower ?? [:]).sorted { $0.value.total > $1.value.total }.prefix(4)
                .map { "\(name($0.key)) cpu \($0.value.cpu.formatted(.watts)) gpu \($0.value.gpu.formatted(.watts))" }
            let head = String(
                format: "%.1f°C max %.1f gpu %.2fW p%ld | ", sample.averageTemperature, sample.maxTemperature,
                sample.gpuPower ?? -1, sample.pressure ?? -1)
            print(head + top.joined(separator: " | "))
        }
    #endif
}
