import Foundation

/// Um app na lista: quanto gastou no período e quando esteve aberto e consumindo.
struct AppRow: Identifiable, Sendable {
    let id: String
    let name: String
    /// Energia no período (J), separada em CPU e GPU.
    let energy: Power
    /// Fatia da energia total do período (0–1).
    let share: Double
    /// Potência média no tempo em que houve medição de energia.
    let average: Power
    let openIntervals: [ClosedRange<Date>]
    /// Potência média por faixa de tempo (início da faixa → W).
    let heat: [Date: Double]
}

/// Uma fatia de barra empilhada do gráfico de energia.
struct PowerSlice: Identifiable, Sendable {
    let start: Date
    let app: String
    let low: Double
    let high: Double

    var id: String { "\(start.timeIntervalSinceReferenceDate)-\(app)" }
    var watts: Double { high - low }
}

/// Tudo que a tela precisa para um período, calculado de uma vez a partir das amostras.
struct RangeSummary: Sendable {
    /// Processos soltos só entram na lista acima desta fatia da energia total.
    static let minimumProcessShare = 0.01
    /// Piso da escala de calor, para que consumos baixos não pareçam intensos.
    static let minimumPeakHeat = 0.5

    let range: TimeRange
    let start: Date
    let end: Date
    let samples: [Sample]
    let rows: [AppRow]
    /// Apps com cor própria, na ordem do empilhamento (de baixo para cima).
    let stacked: [String]
    let slices: [PowerSlice]
    let binTotals: [Date: Double]
    let throttled: [ClosedRange<Date>]
    let peakHeat: Double
    /// Tempo coberto por medição de energia (s).
    let measured: TimeInterval

    var binSize: TimeInterval { range.binSize }

    var hasEnoughData: Bool { samples.count >= 3 }

    func bin(for date: Date) -> Date { range.bin(containing: date) }

    /// Potência média de todos os apps no período.
    var averagePower: Double? {
        guard measured > 0 else { return nil }
        return rows.reduce(0) { $0 + $1.energy.total } / measured
    }

    /// - Parameters:
    ///   - history: amostras na resolução do período (finas ou por minuto), em ordem cronológica.
    ///   - highlighted: apps com cor própria no gráfico; os demais somam em "Outros".
    ///   - appName: nome de exibição de cada app.
    init(
        range: TimeRange, history: [Sample], end: Date, highlighted: Set<String>,
        appName: (String) -> String
    ) {
        let start = end.addingTimeInterval(-range.seconds)
        let samples = history.filter { $0.date >= start }
        let usage = BinnedUsage(samples: samples, range: range)
        let rows = Self.rows(samples: samples, usage: usage, appName: appName)
        let stacked = rows.filter { highlighted.contains($0.id) && $0.energy.total > 0 }.map(\.id)
        let (slices, binTotals) = Self.stack(usage: usage, stacked: stacked)

        self.range = range
        self.start = start
        self.end = end
        self.samples = samples
        self.rows = rows
        self.stacked = stacked
        self.slices = slices
        self.binTotals = binTotals
        self.throttled = samples.intervals { $0.isThrottling }
        self.peakHeat = max(usage.heat.values.flatMap(\.values).max() ?? 0, Self.minimumPeakHeat)
        self.measured = usage.measured
    }

    /// Apps abertos sempre aparecem; processos soltos só se pesarem na conta.
    private static func rows(samples: [Sample], usage: BinnedUsage, appName: (String) -> String) -> [AppRow] {
        let total = usage.energyByApp.values.reduce(0) { $0 + $1.total }
        let significant = usage.energyByApp.filter { total > 0 && $0.value.total / total >= minimumProcessShare }
        let ids = Set(samples.flatMap(\.openApps)).union(significant.keys)

        return ids.map { id in
            let energy = usage.energyByApp[id] ?? .zero
            return AppRow(
                id: id,
                name: appName(id),
                energy: energy,
                share: total > 0 ? energy.total / total : 0,
                average: usage.measured > 0 ? energy / usage.measured : .zero,
                openIntervals: samples.intervals { $0.openApps.contains(id) },
                heat: usage.heat[id] ?? [:])
        }
        .sorted { lhs, rhs in
            lhs.energy.total != rhs.energy.total
                ? lhs.energy.total > rhs.energy.total
                : lhs.name.localizedCompare(rhs.name) == .orderedAscending
        }
    }

    /// Empilha, em cada faixa de tempo, os apps destacados e por cima o grupo "Outros".
    private static func stack(usage: BinnedUsage, stacked: [String]) -> ([PowerSlice], [Date: Double]) {
        let highlighted = Set(stacked)
        let others = usage.heat
            .filter { !highlighted.contains($0.key) }
            .values
            .reduce(into: [Date: Double]()) { sum, heat in sum.merge(heat, uniquingKeysWith: +) }

        var slices: [PowerSlice] = []
        var totals: [Date: Double] = [:]
        for bin in usage.measuredByBin.keys.sorted() {
            var level = 0.0
            for id in stacked + [AppID.others] {
                let watts = id == AppID.others ? others[bin] ?? 0 : usage.heat[id]?[bin] ?? 0
                guard watts > 0 else { continue }
                slices.append(PowerSlice(start: bin, app: id, low: level, high: level + watts))
                level += watts
            }
            totals[bin] = level
        }
        return (slices, totals)
    }
}

/// Energia das amostras distribuída nas faixas de tempo do período.
private struct BinnedUsage {
    /// Energia (J) por app no período.
    var energyByApp: [String: Power] = [:]
    /// Tempo medido (s) em cada faixa.
    var measuredByBin: [Date: TimeInterval] = [:]
    /// Potência média (W) por app em cada faixa.
    var heat: [String: [Date: Double]] = [:]
    var measured: TimeInterval = 0

    init(samples: [Sample], range: TimeRange) {
        var binEnergy: [String: [Date: Double]] = [:]
        for sample in samples {
            guard let power = sample.appPower else { continue }
            let bin = range.bin(containing: sample.date)
            measuredByBin[bin, default: 0] += sample.duration
            measured += sample.duration
            for (id, watts) in power {
                energyByApp[id, default: .zero] += watts * sample.duration
                binEnergy[id, default: [:]][bin, default: 0] += watts.total * sample.duration
            }
        }
        heat = binEnergy.mapValues { energy in
            energy.reduce(into: [:]) { heat, entry in
                heat[entry.key] = entry.value / max(measuredByBin[entry.key] ?? 1, 1)
            }
        }
    }
}
