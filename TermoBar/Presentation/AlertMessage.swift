import Foundation

/// Título e texto da notificação de cada alerta, na unidade escolhida.
enum AlertMessage {
    /// - Parameters:
    ///   - battery: estado da bateria; na bateria, o alerta de app diz quanto dela ele gasta por hora.
    ///   - formatTemperature: temperatura em °C formatada com as preferências ("79 °C").
    ///   - appName: nome de exibição de cada app.
    static func make(
        for event: AlertEvent, battery: BatteryStatus?, formatTemperature: (Double) -> String,
        appName: (String) -> String
    ) -> (title: String, body: String) {
        func describe(_ consumer: PowerConsumer) -> String {
            "\(appName(consumer.app)) (\(consumer.watts.formatted(.watts)))"
        }

        switch event {
        case let .highTemperature(celsius, limit, topConsumer):
            return (
                String(localized: "Mac a \(formatTemperature(celsius))"),
                topConsumer.map { String(localized: "Quem mais consome: \(describe($0)).") }
                    ?? String(localized: "Acima do limite de \(formatTemperature(limit)).")
            )
        case let .throttling(pressure, topConsumer):
            return (
                String(localized: "O macOS está limitando o desempenho"),
                String(localized: "Pressão térmica \(pressure?.label.lowercased() ?? String(localized: "alta")).")
                    + (topConsumer.map { " " + String(localized: "Quem mais consome: \(describe($0)).") } ?? "")
            )
        case let .appPower(consumer, window):
            let average = String(localized: "Média dos últimos \(Int(window / 60)) minutos.")
            // Só CPU e GPU do app: o resto do Mac também gasta, então é o mínimo que ele custa.
            let drain =
                battery?.isDischarging == true
                ? BatteryDrain.notablePercentPerHour(watts: consumer.watts, fullEnergy: battery?.fullEnergy) : nil
            return (
                String(localized: "\(appName(consumer.app)) está gastando \(consumer.watts.formatted(.watts))"),
                drain.map {
                    average + " "
                        + String(
                            localized:
                                "Só a CPU e a GPU dele já tiram cerca de \((Double($0) / 100).formatted(.percent)) da bateria por hora."
                        )
                } ?? average
            )
        }
    }
}
