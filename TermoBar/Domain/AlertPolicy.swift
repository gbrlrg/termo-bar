import Foundation

/// Quais alertas estão ligados e com que limites.
struct AlertConfiguration: Equatable, Sendable {
    struct AppPowerLimit: Equatable, Sendable {
        /// Potência média (W) a partir da qual o app gera alerta.
        var watts: Double
        /// Janela em que a média é calculada.
        var window: TimeInterval
    }

    /// Limite em °C; `nil` desliga o alerta.
    var temperatureLimit: Double?
    var throttling: Bool
    /// `nil` desliga o alerta.
    var appPower: AppPowerLimit?

    var isAnyEnabled: Bool { temperatureLimit != nil || throttling || appPower != nil }
}

/// App que mais consumiu num intervalo.
struct PowerConsumer: Equatable, Sendable {
    let app: String
    let watts: Double
}

/// Um alerta a notificar; o texto fica a cargo da camada de apresentação.
enum AlertEvent: Equatable, Sendable {
    case highTemperature(celsius: Double, limit: Double, topConsumer: PowerConsumer?)
    case throttling(ThermalPressure?, topConsumer: PowerConsumer?)
    case appPower(PowerConsumer, window: TimeInterval)

    /// Identifica o alerta para o intervalo mínimo entre repetições.
    var key: String {
        switch self {
        case .highTemperature: "temp"
        case .throttling: "throttle"
        case .appPower(let consumer, _): "app:\(consumer.app)"
        }
    }

    var cooldown: TimeInterval {
        switch self {
        case .highTemperature, .throttling: AlertPolicy.cooldown
        case .appPower: AlertPolicy.appCooldown
        }
    }
}

/// Decide quando avisar sobre temperatura alta, limitação térmica e app gastando demais.
///
/// Guarda o estado entre leituras: há quanto tempo a temperatura está acima do limite,
/// se já havia limitação e quando cada alerta foi enviado pela última vez.
struct AlertPolicy: Sendable {
    /// Tempo seguido acima do limite antes de avisar.
    static let sustainedDuration: TimeInterval = 30
    static let cooldown: TimeInterval = 15 * 60
    static let appCooldown: TimeInterval = 30 * 60
    /// Janela usada para apontar quem mais consome no momento do alerta.
    static let consumerWindow: TimeInterval = 60
    /// Fração mínima da janela que precisa ter sido medida, para não alertar com pouco dado.
    static let minimumCoverage = 0.8

    private var hotSince: Date?
    private var wasThrottling = false
    private var lastSent: [String: Date] = [:]

    /// Avalia a amostra mais recente de `history` (em ordem cronológica) e devolve os alertas a enviar.
    mutating func evaluate(
        _ history: [Sample], configuration: AlertConfiguration, source: TemperatureSource
    ) -> [AlertEvent] {
        guard let sample = history.last else { return [] }
        let now = sample.date
        var events: [AlertEvent] = []

        let temperature = sample.temperature(for: source)
        if let limit = configuration.temperatureLimit, temperature >= limit {
            let since = hotSince ?? now
            hotSince = since
            if now.timeIntervalSince(since) >= Self.sustainedDuration {
                events.append(
                    .highTemperature(
                        celsius: temperature, limit: limit, topConsumer: Self.topConsumer(in: history, before: now)))
            }
        } else {
            hotSince = nil
        }

        if configuration.throttling, sample.isThrottling, !wasThrottling {
            let pressure = sample.pressure.flatMap(ThermalPressure.init(rawValue:))
            events.append(.throttling(pressure, topConsumer: Self.topConsumer(in: history, before: now)))
        }
        wasThrottling = sample.isThrottling

        if let limit = configuration.appPower {
            events += Self.heavyConsumers(in: history, before: now, limit: limit)
                .map { .appPower($0, window: limit.window) }
        }

        return events.filter { registerIfDue($0, at: now) }
    }

    /// Respeita o intervalo mínimo entre repetições do mesmo alerta.
    private mutating func registerIfDue(_ event: AlertEvent, at now: Date) -> Bool {
        if let last = lastSent[event.key], now.timeIntervalSince(last) < event.cooldown { return false }
        lastSent[event.key] = now
        return true
    }

    private static func topConsumer(in history: [Sample], before now: Date) -> PowerConsumer? {
        let window = history.filter { $0.date > now.addingTimeInterval(-consumerWindow) }
        let measured = window.measuredDuration
        guard measured > 0,
            let top = window.energyByApp().max(by: { $0.value.total < $1.value.total })
        else { return nil }
        return PowerConsumer(app: top.key, watts: top.value.total / measured)
    }

    private static func heavyConsumers(
        in history: [Sample], before now: Date, limit: AlertConfiguration.AppPowerLimit
    ) -> [PowerConsumer] {
        let window = history.filter { $0.date > now.addingTimeInterval(-limit.window) && $0.appPower != nil }
        let measured = window.totalDuration
        guard measured > 0, measured >= limit.window * minimumCoverage else { return [] }
        return window.energyByApp()
            .map { PowerConsumer(app: $0.key, watts: $0.value.total / measured) }
            .filter { $0.watts >= limit.watts }
            .sorted { $0.watts > $1.watts }
    }
}
