import Foundation

enum TimeRange: Int, CaseIterable, Identifiable {
    case quarter = 900
    case hour = 3600
    case day = 86400
    case week = 604800

    var id: Self { self }
    var seconds: TimeInterval { TimeInterval(rawValue) }

    var label: String {
        switch self {
        case .quarter: "15 min"
        case .hour: "1 h"
        case .day: "24 h"
        case .week: "7 dias"
        }
    }

    /// Largura de cada barra do gráfico de energia.
    var binSize: TimeInterval {
        switch self {
        case .quarter: 15
        case .hour: 60
        case .day: 15 * 60
        case .week: 3600
        }
    }

    /// Até 1 h usa as leituras finas; acima disso, os resumos por minuto.
    var usesMinutes: Bool { self == .day || self == .week }
}

/// Um app na lista: quanto gastou no período e quando esteve aberto e consumindo.
struct AppRow: Identifiable {
    let id: String
    let name: String
    /// Energia no período (J), separada em CPU e GPU.
    let energy: Power
    let share: Double
    /// Potência média no período em que houve medição de energia.
    let average: Power
    let open: [ClosedRange<Date>]
    /// Potência média por faixa de tempo (início da faixa → W).
    let heat: [Date: Double]
}

/// Uma fatia de barra empilhada do gráfico de energia.
struct PowerSlice: Identifiable {
    var id: String { "\(start.timeIntervalSinceReferenceDate)-\(app)" }
    let start: Date
    let app: String
    let low: Double
    let high: Double
}

/// Tudo que a tela precisa para um período, calculado de uma vez a partir das amostras.
struct RangeSummary {
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

    func bin(for date: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / binSize).rounded(.down) * binSize)
    }
}

extension Monitor {
    func summary(range: TimeRange) -> RangeSummary {
        let end = current?.date ?? Date()
        let start = end.addingTimeInterval(-range.seconds)
        let samples = (range.usesMinutes ? minutes : recent).filter { $0.date >= start }
        let binSize = range.binSize
        func bin(_ date: Date) -> Date {
            Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / binSize).rounded(.down) * binSize)
        }

        var energyByApp: [String: Power] = [:]
        var binEnergy: [String: [Date: Double]] = [:]
        var binMeasured: [Date: Double] = [:]
        var measured = 0.0
        for sample in samples {
            guard let power = sample.power else { continue }
            let b = bin(sample.date)
            binMeasured[b, default: 0] += sample.duration
            measured += sample.duration
            for (id, watts) in power {
                energyByApp[id, default: .zero] = energyByApp[id, default: .zero] + watts * sample.duration
                binEnergy[id, default: [:]][b, default: 0] += watts.total * sample.duration
            }
        }
        let heat = binEnergy.mapValues { energy in
            Dictionary(uniqueKeysWithValues: energy.map { ($0.key, $0.value / max(binMeasured[$0.key] ?? 1, 1)) })
        }
        let total = energyByApp.values.reduce(0) { $0 + $1.total }

        // Apps abertos sempre aparecem; processos soltos só se pesarem na conta.
        let significant = energyByApp.filter { total > 0 && $0.value.total / total >= 0.01 }.keys
        let ids = Set(samples.flatMap(\.apps)).union(significant)
        let rows: [AppRow] = ids.map { id in
            let energy = energyByApp[id] ?? .zero
            return AppRow(id: id, name: name(id), energy: energy,
                          share: total > 0 ? energy.total / total : 0,
                          average: measured > 0 ? energy * (1 / measured) : .zero,
                          open: Self.runs(in: samples) { $0.apps.contains(id) },
                          heat: heat[id] ?? [:])
        }
        .sorted { a, b in
            a.energy.total != b.energy.total ? a.energy.total > b.energy.total
                : a.name.localizedCompare(b.name) == .orderedAscending
        }

        let stacked = rows.filter { (row: AppRow) in slots[row.id] != nil && row.energy.total > 0 }.map { $0.id }
        let highlighted = Set(stacked)
        var slices: [PowerSlice] = []
        var binTotals: [Date: Double] = [:]
        for b in binMeasured.keys {
            var level = 0.0
            for id in stacked + [Self.othersID] {
                let watts = id == Self.othersID
                    ? heat.filter { !highlighted.contains($0.key) }.values.reduce(0) { $0 + ($1[b] ?? 0) }
                    : heat[id]?[b] ?? 0
                guard watts > 0 else { continue }
                slices.append(PowerSlice(start: b, app: id, low: level, high: level + watts))
                level += watts
            }
            binTotals[b] = level
        }

        return RangeSummary(
            range: range, start: start, end: end, samples: samples, rows: rows, stacked: stacked,
            slices: slices, binTotals: binTotals,
            throttled: Self.runs(in: samples) { $0.throttling },
            peakHeat: max(heat.values.flatMap(\.values).max() ?? 0, 0.5), measured: measured)
    }

    /// Intervalos contínuos de amostras que satisfazem `present`. Um buraco maior que
    /// três períodos (Mac dormindo, app fechado) quebra o intervalo.
    static func runs(in samples: [Sample], where present: (Sample) -> Bool) -> [ClosedRange<Date>] {
        var result: [ClosedRange<Date>] = []
        var start: Date?
        var last: Sample?
        func close() {
            if let s = start, let l = last { result.append(s...l.date.addingTimeInterval(l.duration)) }
            start = nil
            last = nil
        }
        for sample in samples {
            guard present(sample) else { close(); continue }
            if let l = last, sample.date.timeIntervalSince(l.date) <= max(l.duration, sample.duration) * 3 {
                last = sample
            } else {
                close()
                start = sample.date
                last = sample
            }
        }
        close()
        return result
    }
}
