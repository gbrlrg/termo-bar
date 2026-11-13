import Foundation

extension WidgetSnapshot {
    /// Resumo para o widget: a temperatura já formatada e os apps que mais gastaram no período,
    /// com a mesma cor do gráfico de energia.
    init(
        date: Date, celsius: Double, temperature: String, pressure: ThermalPressure,
        summary: RangeSummary, palette: PaletteSlots, limit: Int
    ) {
        let apps = summary.heatingApps.prefix(limit).map {
            App(
                id: $0.id, name: $0.name, watts: $0.average.total.formatted(.watts), share: $0.share,
                colorSlot: palette[$0.id])
        }
        self.init(date: date, celsius: celsius, temperature: temperature, pressure: pressure, apps: Array(apps))
    }
}
