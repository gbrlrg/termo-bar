import Foundation
import Observation
import UserNotifications

/// Envia as notificações decididas pela `AlertPolicy`, com o texto na unidade escolhida.
@MainActor @Observable
final class AlertNotifier {
    private let preferences: Preferences
    @ObservationIgnored private var policy = AlertPolicy()
    /// O delegate do `UNUserNotificationCenter` é uma referência fraca: o notificador o mantém vivo.
    @ObservationIgnored private let presenter = ForegroundPresenter()

    init(preferences: Preferences) {
        self.preferences = preferences
        UNUserNotificationCenter.current().delegate = presenter
    }

    /// Pede permissão só se algum alerta estiver ligado, para não incomodar quem não usa.
    func requestAuthorizationIfNeeded() {
        guard preferences.alertConfiguration.isAnyEnabled else { return }
        requestAuthorization()
    }

    func requestAuthorization() {
        Task { await Self.authorize() }
    }

    /// Avalia a amostra mais recente do histórico e notifica o que for preciso.
    func evaluate(_ history: [Sample], appName: (String) -> String) {
        let events = policy.evaluate(history, configuration: preferences.alertConfiguration, source: preferences.source)
        for event in events {
            let (title, body) = message(for: event, appName: appName)
            post(id: event.key, title: title, body: body)
        }
    }

    func sendTestNotification() {
        Task {
            await Self.authorize()
            await Self.deliver(id: "test", title: "TermoBar", body: "As notificações estão funcionando.")
        }
    }

    private func message(for event: AlertEvent, appName: (String) -> String) -> (title: String, body: String) {
        func describe(_ consumer: PowerConsumer) -> String {
            "\(appName(consumer.app)) (\(consumer.watts.formatted(.watts)))"
        }

        switch event {
        case let .highTemperature(celsius, limit, topConsumer):
            return (
                "Mac a \(preferences.format(celsius))",
                topConsumer.map { "Quem mais consome: \(describe($0))." }
                    ?? "Acima do limite de \(preferences.format(limit))."
            )
        case let .throttling(pressure, topConsumer):
            return (
                "O macOS está limitando o desempenho",
                "Pressão térmica \(pressure?.label.lowercased() ?? "alta")."
                    + (topConsumer.map { " Quem mais consome: \(describe($0))." } ?? "")
            )
        case let .appPower(consumer, window):
            return (
                "\(appName(consumer.app)) está gastando \(consumer.watts.formatted(.watts))",
                "Média dos últimos \(Int(window / 60)) minutos."
            )
        }
    }

    private func post(id: String, title: String, body: String) {
        Task { await Self.deliver(id: id, title: title, body: body) }
    }

    // As APIs assíncronas evitam que os callbacks do UserNotifications, chamados fora da
    // thread principal, rodem em closures isoladas no MainActor.

    private nonisolated static func authorize() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            Log.notifications.error("Permissão de notificação negada: \(error.localizedDescription)")
        }
    }

    private nonisolated static func deliver(id: String, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: "\(id)-\(UUID().uuidString)", content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Log.notifications.error("Falha ao enviar notificação: \(error.localizedDescription)")
        }
    }
}

/// Sem delegate, o macOS não mostra o banner enquanto o app está em primeiro plano (com os Ajustes
/// abertos, por exemplo) e manda a notificação direto para a Central de Notificações.
private final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate, Sendable {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
