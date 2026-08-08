import Foundation
import UserNotifications

/// Notificações de temperatura alta, limitação térmica e app gastando demais.
@MainActor
final class Alerts {
    private static let sustained: TimeInterval = 30
    private static let cooldown: TimeInterval = 15 * 60
    private static let appCooldown: TimeInterval = 30 * 60

    private var hotSince: Date?
    private var wasThrottling = false
    private var lastSent: [String: Date] = [:]

    func requestAuthorizationIfNeeded() {
        let prefs = Preferences.shared
        guard prefs.alertTemperature || prefs.alertThrottling || prefs.alertAppPower else { return }
        requestAuthorization()
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func evaluate(monitor: Monitor, prefs: Preferences) {
        guard let sample = monitor.current else { return }
        let now = sample.date
        let culprit = topConsumer(monitor: monitor, since: now.addingTimeInterval(-60))

        let temp = monitor.temperature(of: sample)
        if prefs.alertTemperature, temp >= prefs.alertTemperatureLimit {
            let since = hotSince ?? now
            hotSince = since
            if now.timeIntervalSince(since) >= Self.sustained {
                send(key: "temp", cooldown: Self.cooldown, now: now,
                     title: "Mac a \(prefs.format(temp))",
                     body: culprit.map { "Quem mais consome: \($0)." } ?? "Acima do limite de \(prefs.format(prefs.alertTemperatureLimit)).")
            }
        } else {
            hotSince = nil
        }

        let throttling = sample.throttling
        if prefs.alertThrottling, throttling, !wasThrottling {
            send(key: "throttle", cooldown: Self.cooldown, now: now,
                 title: "O macOS está limitando o desempenho",
                 body: "Pressão térmica \(ThermalPressure(rawValue: sample.pressure ?? 0)?.label.lowercased() ?? "alta")."
                     + (culprit.map { " Quem mais consome: \($0)." } ?? ""))
        }
        wasThrottling = throttling

        if prefs.alertAppPower {
            let window = prefs.alertAppMinutes * 60
            let samples = monitor.recent.filter { $0.date > now.addingTimeInterval(-window) && $0.power != nil }
            let covered = samples.map(\.duration).reduce(0, +)
            // Só avalia com pelo menos 80% da janela medida, para não alertar com pouco dado.
            guard covered >= window * 0.8 else { return }
            var energy: [String: Double] = [:]
            for s in samples { for (id, w) in s.power ?? [:] { energy[id, default: 0] += w.total * s.duration } }
            for (id, joules) in energy where joules / covered >= prefs.alertAppWatts {
                send(key: "app:\(id)", cooldown: Self.appCooldown, now: now,
                     title: "\(monitor.name(id)) está gastando \(formatWatts(joules / covered))",
                     body: "Média dos últimos \(Int(prefs.alertAppMinutes)) minutos.")
            }
        }
    }

    private func topConsumer(monitor: Monitor, since: Date) -> String? {
        var energy: [String: Double] = [:]
        for s in monitor.recent where s.date > since {
            for (id, w) in s.power ?? [:] { energy[id, default: 0] += w.total * s.duration }
        }
        let covered = monitor.recent.filter { $0.date > since && $0.power != nil }.map(\.duration).reduce(0, +)
        guard let top = energy.max(by: { $0.value < $1.value }), covered > 0 else { return nil }
        return "\(monitor.name(top.key)) (\(formatWatts(top.value / covered)))"
    }

    private func send(key: String, cooldown: TimeInterval, now: Date, title: String, body: String) {
        if let last = lastSent[key], now.timeIntervalSince(last) < cooldown { return }
        lastSent[key] = now
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: key + "-\(now.timeIntervalSince1970)", content: content, trigger: nil))
    }
}

extension ThermalPressure {
    var label: String {
        switch self {
        case .nominal: "Normal"
        case .moderate: "Moderada"
        case .heavy: "Limitando desempenho"
        case .critical: "Crítica"
        case .sleeping: "Suspensão térmica"
        }
    }

    var symbol: String {
        switch self {
        case .nominal: "checkmark.circle.fill"
        case .moderate: "thermometer.medium"
        case .heavy: "flame.fill"
        default: "exclamationmark.triangle.fill"
        }
    }
}
