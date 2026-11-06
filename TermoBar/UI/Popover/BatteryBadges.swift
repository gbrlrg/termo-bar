import SwiftUI

/// Carga da bateria e, quando o sensor existe, a temperatura dela; carregando é quando ela mais esquenta.
struct BatteryBadge: View {
    let battery: BatteryStatus
    let temperature: String?

    var body: some View {
        Label(
            BatteryBadgeContent.text(battery, temperature: temperature),
            systemImage: BatteryBadgeContent.symbol(battery)
        )
        .help(BatteryBadgeContent.help(battery, temperature: temperature))
    }
}

/// Quanto falta para a bateria acabar (no ritmo atual) ou para carregar.
struct BatteryTimeBadge: View {
    let battery: BatteryStatus
    let runtime: RuntimeEstimate?

    /// Há o que mostrar: autonomia (ou "calculando") na bateria, ou o tempo para carregar.
    static func hasContent(_ battery: BatteryStatus) -> Bool {
        BatteryBadgeContent.hasTime(battery)
    }

    var body: some View {
        if let content = BatteryBadgeContent.time(battery, runtime: runtime) {
            Label(content.text, systemImage: "clock")
                .help(content.help)
        }
    }
}
