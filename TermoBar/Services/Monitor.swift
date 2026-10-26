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

        var errorDescription: String? { String(localized: "O histórico não está disponível.") }
    }

    /// Leituras finas mantidas em memória.
    static let recentWindow: TimeInterval = 3600
    /// Resumos por minuto mantidos em memória.
    static let minuteWindow: TimeInterval = 7 * 86400
    /// Quantos apps ganham cor própria no gráfico de energia.
    static let highlightedApps = 5
    /// Apps listados no widget médio.
    private static let widgetApps = 3

    private static let readInterval: TimeInterval = 1
    /// A bateria muda devagar; ler a cada tique só gastaria CPU.
    private static let batteryInterval: TimeInterval = 5
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
    /// Temperatura da bateria, arredondada a 0,1 °C para não redesenhar o popover à toa; `nil` sem bateria.
    private(set) var batteryTemperature: Double?
    private(set) var isCharging = false
    /// Estado da bateria interna, lido a cada poucos segundos; `nil` em Macs de mesa.
    private(set) var battery: BatteryStatus?
    /// Autonomia no ritmo recente; só enquanto descarrega e depois de medir por alguns minutos.
    private(set) var runtime: RuntimeEstimate?
    /// Modo Pouca Energia ligado: o macOS segura o chip e o calor cai.
    private(set) var isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    /// Última leitura de cada sensor e de cada ventoinha, atualizadas só com a aba Sensores aberta.
    private(set) var sensors: [TemperatureSensors.Sensor] = []
    private(set) var fans: [Fan] = []
    /// A aba Sensores está na tela: só então vale ler os sensores fora do chip e publicar as leituras.
    @ObservationIgnored var isShowingSensors = false {
        didSet { refreshLiveReadings() }
    }
    /// Potência recente de cada processo, para detalhar um app na lista.
    private(set) var processActivity = ProcessActivity()

    let chipName = SystemInfo.chipName

    private let preferences: Preferences
    private let alerts: AlertNotifier
    private let store: HistoryStore?
    private let temperatureSensors = TemperatureSensors()
    private let energySampler = EnergySampler()
    private let pressureReader = ThermalPressureReader()
    private let fanReader = FanReader()
    private let widget = WidgetPublisher()

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var pendingReadings: [TemperatureSensors.Reading] = []
    /// Rotação média das ventoinhas em cada leitura do intervalo (rpm).
    @ObservationIgnored private var pendingFanSpeeds: [Double] = []
    @ObservationIgnored private var lastSampleDate: Date?
    @ObservationIgnored private var discharge = DischargeHistory()
    @ObservationIgnored private var lastBatteryRead = Date.distantPast
    @ObservationIgnored private var currentMinute: Date?
    @ObservationIgnored private var lastDiskPrune = Date.distantPast
    @ObservationIgnored private var savedNames: [String: String] = [:]
    /// Detalhes já lidos de cada processo, com o início dele para notar PID reaproveitado.
    @ObservationIgnored private var processDetails: [pid_t: (start: UInt64, details: ProcessDetails)] = [:]

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

    /// O Mac tem ventoinha (o MacBook Air não tem).
    var hasFans: Bool { fanReader.hasFans }

    /// Potência somada dos apps na leitura mais recente que tem medição de energia.
    var currentPower: Double? {
        recent.last { $0.appPower != nil }?.appPower?.values.reduce(0) { $0 + $1.total }
    }

    func name(_ id: String) -> String {
        id == AppID.others ? AppID.othersName : appNames[id] ?? id
    }

    /// Processos do app consumindo agora, com processos iguais (mesmo nome e projeto) juntos.
    func liveProcesses(of id: String) -> [LiveProcess] {
        var groups: [ProcessDescription: LiveProcess] = [:]
        var order: [ProcessDescription] = []
        for (pid, power) in processActivity.average(of: id) {
            // Processos do sistema não revelam detalhes; aparecem pelo nome do grupo.
            let details =
                details(of: pid)
                ?? ProcessDetails(
                    pid: pid,
                    description: ProcessDescription(
                        ProcessFacts(name: name(id), executablePath: nil, arguments: [], workingDirectory: nil),
                        homeDirectory: ""),
                    commandLine: nil, startDate: nil)
            let key = details.description
            if groups[key] == nil {
                order.append(key)
                groups[key] = LiveProcess(description: key)
            }
            groups[key]?.add(details, power: power)
        }
        return order.compactMap { groups[$0] }.sorted { $0.power.total > $1.power.total }
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
        if let reading = temperatureSensors.read(includeOthers: isShowingSensors) {
            pendingReadings.append(reading)
            if isShowingSensors { sensors = reading.sensors }
        }
        let fans = fanReader.read()
        if !fans.isEmpty {
            pendingFanSpeeds.append(fans.reduce(0) { $0 + $1.rpm } / Double(fans.count))
        }
        if isShowingSensors, fans != self.fans { self.fans = fans }
        // O Observation avisa as telas a cada atribuição, mesmo de um valor igual.
        let pressure = pressureReader.read()
        if pressure != self.pressure { self.pressure = pressure }
        let battery = temperatureSensors.readBattery().map { ($0 * 10).rounded() / 10 }
        if battery != batteryTemperature { batteryTemperature = battery }
        updateBattery(now: Date())
        let isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        if isLowPowerMode != self.isLowPowerMode { self.isLowPowerMode = isLowPowerMode }

        let now = Date()
        let isDue =
            lastSampleDate.map {
                now.timeIntervalSince($0) >= preferences.sampleInterval - Self.intervalTolerance
            } ?? true
        if isDue { recordSample(at: now) }
    }

    private func updateBattery(now: Date) {
        guard now.timeIntervalSince(lastBatteryRead) >= Self.batteryInterval - Self.intervalTolerance else { return }
        lastBatteryRead = now
        let status = BatteryReader.read()
        discharge.record(status, at: now)
        let runtime = discharge.estimate(for: status)
        if status != battery { battery = status }
        if runtime != self.runtime { self.runtime = runtime }
        let isCharging = status?.isCharging ?? false
        if isCharging != self.isCharging { self.isCharging = isCharging }
    }

    private func recordSample(at now: Date) {
        // A energia é medida mesmo sem temperatura, para manter a base de comparação do próximo registro.
        let measurement = energySampler.sample()
        if let measurement {
            processActivity.record(measurement.byProcess, at: now, duration: measurement.duration)
        }
        guard !pendingReadings.isEmpty else { return }
        let averageTemperature = pendingReadings.map(\.average).reduce(0, +) / Double(pendingReadings.count)
        let maxTemperature = pendingReadings.map(\.maximum).max() ?? averageTemperature
        pendingReadings.removeAll()
        let fanSpeed = pendingFanSpeeds.isEmpty ? nil : pendingFanSpeeds.reduce(0, +) / Double(pendingFanSpeeds.count)
        pendingFanSpeeds.removeAll()

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
            gpuPower: measurement?.gpuTotal,
            fanSpeed: fanSpeed)
        recent.append(sample)
        persist("gravar a leitura") { try $0.insert(sample, resolution: .raw) }

        summarizeMinute(at: now)
        prune(now: now)
        updatePalette()
        publishWidget(at: now)
        saveNewNames()
        alerts.evaluate(recent) { self.name($0) }
        #if DEBUG
            logIfRequested(sample)
        #endif
    }

    /// Temperatura e os apps que mais gastaram nos últimos 15 minutos, para o widget.
    private func publishWidget(at now: Date) {
        guard let celsius = currentTemperature else { return }
        let apps = summary(range: .quarter).rows
            .filter { $0.id != AppID.others && $0.energy.total > 0 }
            .prefix(Self.widgetApps)
            .map {
                WidgetSnapshot.App(
                    id: $0.id, name: $0.name, watts: $0.average.total.formatted(.watts), share: $0.share,
                    colorSlot: palette[$0.id])
            }
        widget.publish(
            WidgetSnapshot(
                date: now, celsius: celsius, temperature: preferences.format(celsius),
                pressure: pressure, apps: Array(apps)))
    }

    /// Atualiza na hora as leituras da aba Sensores, sem esperar o próximo tique.
    private func refreshLiveReadings() {
        guard isShowingSensors else { return }
        sensors = temperatureSensors.read(includeOthers: true)?.sensors ?? []
        fans = fanReader.read()
    }

    private func details(of pid: pid_t) -> ProcessDetails? {
        guard let start = ProcessInspector.startTime(of: pid) else {
            processDetails[pid] = nil
            return nil
        }
        if let cached = processDetails[pid], cached.start == start { return cached.details }
        guard let details = ProcessInspector.details(of: pid) else { return nil }
        processDetails[pid] = (start, details)
        return details
    }

    /// Apps comuns (com ícone no Dock) abertos agora.
    private func openApps() -> [String] {
        var ids: [String] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            let id = Self.identifier(of: app)
            ids.append(id)
            setName(app.localizedName ?? id, for: id)
        }
        return ids
    }

    private func appPower(from measurement: EnergySampler.Measurement) -> [String: Power] {
        var power: [String: Power] = [:]
        for (group, watts) in measurement.byGroup {
            power[group.id, default: .zero] += watts
            setName(group.name, for: group.id)
        }
        return Sample.significant(power)
    }

    /// Só grava nomes novos: cada atribuição faria as telas que mostram nomes se redesenharem.
    private func setName(_ name: String, for id: String) {
        if appNames[id] != name { appNames[id] = name }
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
        let active = processActivity.pids
        processDetails = processDetails.filter { active.contains($0.key) }
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
        var palette = palette
        palette.update(ranking: recent.energyByApp().sorted { $0.value.total > $1.value.total }.map(\.key))
        if palette != self.palette { self.palette = palette }
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

/// Um processo (ou vários iguais, como as abas do Chrome) de um app, com a potência recente.
struct LiveProcess: Identifiable {
    let description: ProcessDescription
    private(set) var pids: [pid_t] = []
    private(set) var power = Power.zero
    /// Só quando é um processo único.
    private(set) var details: ProcessDetails?

    var id: ProcessDescription { description }

    fileprivate init(description: ProcessDescription) {
        self.description = description
    }

    fileprivate mutating func add(_ details: ProcessDetails, power: Power) {
        pids.append(details.pid)
        self.power += power
        self.details = pids.count == 1 ? details : nil
    }
}
