import Foundation

/// Potência recente de cada processo, para detalhar o consumo de um app "agora".
///
/// Guarda as medições dos últimos segundos e devolve a média ponderada pela duração,
/// mais estável que a última leitura isolada.
struct ProcessActivity: Sendable {
    /// Período coberto pela média.
    static let window: TimeInterval = 30
    /// Potência abaixo disso (W) não é guardada.
    static let minimumPower = 0.001

    struct Entry: Hashable, Sendable {
        let pid: pid_t
        let group: String
        let power: Power
    }

    private struct Measurement {
        let date: Date
        let duration: TimeInterval
        let entries: [Entry]
    }

    private var measurements: [Measurement] = []

    mutating func record(_ entries: [Entry], at date: Date, duration: TimeInterval) {
        guard duration > 0 else { return }
        measurements.append(
            Measurement(
                date: date, duration: duration, entries: entries.filter { $0.power.total >= Self.minimumPower }))
        measurements.removeAll { $0.date <= date.addingTimeInterval(-Self.window) }
    }

    /// Processos com alguma medição na janela.
    var pids: Set<pid_t> { Set(measurements.flatMap { $0.entries.map(\.pid) }) }

    /// Potência média de cada processo do grupo na janela, do maior para o menor.
    func average(of group: String) -> [(pid: pid_t, power: Power)] {
        let duration = measurements.reduce(0) { $0 + $1.duration }
        guard duration > 0 else { return [] }
        var energy: [pid_t: Power] = [:]
        for measurement in measurements {
            for entry in measurement.entries where entry.group == group {
                energy[entry.pid, default: .zero] += entry.power * measurement.duration
            }
        }
        return energy.map { (pid: $0.key, power: $0.value / duration) }
            .sorted { ($0.power.total, $1.pid) > ($1.power.total, $0.pid) }
    }
}
