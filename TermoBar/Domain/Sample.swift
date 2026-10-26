import Foundation

/// Um registro do histórico: temperatura, apps abertos e potência por app num período.
struct Sample: Sendable {
    /// Duração de um resumo por minuto.
    static let minuteDuration: TimeInterval = 60
    /// Potência abaixo disso (W) é ruído de medição e não é guardada.
    static let minimumAppPower = 0.005

    let date: Date
    /// Período que a amostra representa (intervalo de leitura, ou 60 s nos resumos por minuto).
    let duration: TimeInterval
    /// Média dos sensores do die no período (°C).
    let averageTemperature: Double
    /// Sensor mais quente no período (°C).
    let maxTemperature: Double
    let openApps: [String]
    let frontmostApp: String?
    /// Potência média por app no período; `nil` quando não houve medição de energia.
    let appPower: [String: Power]?
    /// Nível bruto de `ThermalPressure`, como publicado pelo kernel.
    let pressure: Int?
    /// Potência total da GPU (W).
    let gpuPower: Double?
    /// Rotação média das ventoinhas no período (rpm); `nil` em Macs sem ventoinha.
    let fanSpeed: Double?

    var isThrottling: Bool { (pressure ?? 0) >= ThermalPressure.heavy.rawValue }

    var isFanSpinning: Bool { (fanSpeed ?? 0) >= Fan.spinningThreshold }

    func temperature(for source: TemperatureSource) -> Double {
        source == .average ? averageTemperature : maxTemperature
    }
}

// MARK: - Resumo por minuto

extension Sample {
    /// Resume várias leituras num registro de um minuto: médias ponderadas pela duração,
    /// pico de temperatura e de pressão térmica, e o app que ficou mais tempo em primeiro plano.
    init?(summarizing samples: [Sample], at date: Date) {
        let duration = samples.totalDuration
        guard duration > 0 else { return nil }
        let gpu = samples.compactMap(\.gpuPower)
        let fans = samples.filter { $0.fanSpeed != nil }
        let frontCounts = samples.compactMap(\.frontmostApp).reduce(into: [:]) { $0[$1, default: 0] += 1 }

        self.init(
            date: date,
            duration: Self.minuteDuration,
            averageTemperature: samples.reduce(0) { $0 + $1.averageTemperature * $1.duration } / duration,
            maxTemperature: samples.map(\.maxTemperature).max() ?? 0,
            openApps: Set(samples.flatMap(\.openApps)).sorted(),
            frontmostApp: frontCounts.max { ($0.value, $1.key) < ($1.value, $0.key) }?.key,
            appPower: samples.averagePowerByApp().map(Self.significant),
            pressure: samples.compactMap(\.pressure).max(),
            gpuPower: gpu.isEmpty ? nil : gpu.reduce(0, +) / Double(gpu.count),
            fanSpeed: fans.totalDuration > 0
                ? fans.reduce(0) { $0 + ($1.fanSpeed ?? 0) * $1.duration } / fans.totalDuration : nil)
    }

    static func significant(_ power: [String: Power]) -> [String: Power] {
        power.filter { $0.value.total >= minimumAppPower }
    }
}

// MARK: - Coleções de amostras

extension Collection where Element == Sample {
    var totalDuration: TimeInterval { reduce(0) { $0 + $1.duration } }

    /// Tempo coberto por medição de energia.
    var measuredDuration: TimeInterval { filter { $0.appPower != nil }.totalDuration }

    /// Energia (J) gasta por app no conjunto.
    func energyByApp() -> [String: Power] {
        reduce(into: [:]) { energy, sample in
            for (id, power) in sample.appPower ?? [:] {
                energy[id, default: .zero] += power * sample.duration
            }
        }
    }

    /// Potência média por app no tempo medido; `nil` quando nada foi medido.
    func averagePowerByApp() -> [String: Power]? {
        let measured = measuredDuration
        guard measured > 0 else { return nil }
        return energyByApp().mapValues { $0 / measured }
    }

    /// Fração do tempo com as ventoinhas girando (0–1); `nil` sem leitura de ventoinha.
    var fanSpinningShare: Double? {
        let read = filter { $0.fanSpeed != nil }
        let duration = read.totalDuration
        guard duration > 0 else { return nil }
        return read.filter(\.isFanSpinning).totalDuration / duration
    }

    /// Maior rotação média registrada (rpm); `nil` sem leitura de ventoinha.
    var peakFanSpeed: Double? { compactMap(\.fanSpeed).max() }

    /// Fração do tempo com o macOS limitando o desempenho (0–1); `nil` sem pressão registrada.
    var throttledShare: Double? {
        let read = filter { $0.pressure != nil }
        let duration = read.totalDuration
        guard duration > 0 else { return nil }
        return read.filter(\.isThrottling).totalDuration / duration
    }

    /// Média da temperatura ponderada pela duração de cada amostra.
    func averageTemperature(for source: TemperatureSource) -> Double? {
        let duration = totalDuration
        guard duration > 0 else { return nil }
        return reduce(0) { $0 + $1.temperature(for: source) * $1.duration } / duration
    }

    /// A amostra mais próxima de `date`.
    func nearest(to date: Date) -> Sample? {
        self.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    /// Intervalos contínuos de amostras que satisfazem `predicate`. Um buraco maior que
    /// três períodos (Mac dormindo, app fechado) quebra o intervalo.
    func intervals(where predicate: (Sample) -> Bool) -> [ClosedRange<Date>] {
        var result: [ClosedRange<Date>] = []
        var first: Sample?
        var last: Sample?

        func close() {
            if let first, let last {
                result.append(first.date...last.date.addingTimeInterval(last.duration))
            }
            first = nil
            last = nil
        }

        for sample in self {
            guard predicate(sample) else {
                close()
                continue
            }
            if let previous = last,
                sample.date.timeIntervalSince(previous.date) > Swift.max(previous.duration, sample.duration) * 3
            {
                close()
            }
            if first == nil { first = sample }
            last = sample
        }
        close()
        return result
    }
}
