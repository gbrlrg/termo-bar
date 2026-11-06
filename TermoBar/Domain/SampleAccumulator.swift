import Foundation

/// Junta as leituras de cada segundo até fechar um registro do histórico.
///
/// Guarda as temperaturas e a rotação das ventoinhas lidas no intervalo e decide quando o
/// registro vence e quanto tempo ele representa. Fica fora do `Monitor` para poder ser testado.
struct ReadingAccumulator: Sendable {
    /// Tolerância para fechar o registro no tique mais próximo do intervalo escolhido.
    static let intervalTolerance: TimeInterval = 0.25
    /// Um registro nunca representa mais que isso vezes o intervalo (Mac acordando, por exemplo).
    static let maxDurationFactor = 3.0

    /// O que vai para a `Sample` ao fechar o registro.
    struct Record: Equatable, Sendable {
        let date: Date
        let duration: TimeInterval
        let averageTemperature: Double
        let maxTemperature: Double
        /// Média das ventoinhas no intervalo (rpm); `nil` sem leitura de ventoinha.
        let fanSpeed: Double?
    }

    private var temperatures: [(average: Double, maximum: Double)] = []
    /// Rotação média das ventoinhas em cada leitura do intervalo (rpm).
    private var fanSpeeds: [Double] = []
    private(set) var lastRecordDate: Date?

    var hasPendingTemperature: Bool { !temperatures.isEmpty }

    mutating func addTemperature(average: Double, maximum: Double) {
        temperatures.append((average, maximum))
    }

    /// Guarda a média das ventoinhas lidas agora; sem ventoinha, não guarda nada.
    mutating func addFans(_ rpms: [Double]) {
        guard !rpms.isEmpty else { return }
        fanSpeeds.append(rpms.reduce(0, +) / Double(rpms.count))
    }

    /// O intervalo escolhido já passou desde o último registro (ou ainda não houve nenhum).
    func isDue(at now: Date, interval: TimeInterval) -> Bool {
        lastRecordDate.map { now.timeIntervalSince($0) >= interval - Self.intervalTolerance } ?? true
    }

    /// Fecha o registro com as leituras pendentes; `nil` (e nada muda) sem nenhuma temperatura.
    mutating func close(at now: Date, interval: TimeInterval) -> Record? {
        guard !temperatures.isEmpty else { return nil }
        let average = temperatures.map(\.average).reduce(0, +) / Double(temperatures.count)
        let maximum = temperatures.map(\.maximum).max() ?? average
        let fanSpeed = fanSpeeds.isEmpty ? nil : fanSpeeds.reduce(0, +) / Double(fanSpeeds.count)
        temperatures.removeAll()
        fanSpeeds.removeAll()

        let duration =
            lastRecordDate.map { min(now.timeIntervalSince($0), interval * Self.maxDurationFactor) } ?? interval
        lastRecordDate = now
        return Record(
            date: now, duration: duration, averageTemperature: average, maxTemperature: maximum, fanSpeed: fanSpeed)
    }
}

/// Percebe a virada do minuto do relógio, quando as leituras do minuto anterior viram um resumo.
struct MinuteClock: Sendable {
    private(set) var current: Date?

    /// Avança para o minuto de `now`; devolve o minuto que acabou de fechar, se o relógio virou.
    ///
    /// O minuto fechado vai do início dele (`start`) ao início do minuto atual (`end`); as amostras
    /// com data em `start < data <= end` entram no resumo.
    mutating func advance(to now: Date, calendar: Calendar = .current) -> DateInterval? {
        let minute = calendar.dateInterval(of: .minute, for: now)?.start ?? now
        defer { current = minute }
        guard let previous = current, previous < minute else { return nil }
        return DateInterval(start: previous, end: minute)
    }
}

extension Collection where Element == Sample {
    /// Resumo das amostras do minuto fechado (veja `MinuteClock`); `nil` sem amostras nele.
    func minuteSummary(of minute: DateInterval) -> Sample? {
        Sample(summarizing: filter { $0.date > minute.start && $0.date <= minute.end }, at: minute.start)
    }
}
