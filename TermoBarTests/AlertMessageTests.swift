import Foundation
import Testing

struct AlertMessageTests {
    private func message(_ event: AlertEvent, battery: BatteryStatus? = nil) -> (title: String, body: String) {
        AlertMessage.make(
            for: event, battery: battery, formatTemperature: { "\(Int($0)) °C" }, appName: { $0.uppercased() })
    }

    private let consumer = PowerConsumer(app: "xcode", watts: 12)
    private var described: String { "XCODE (\(12.0.formatted(.watts)))" }

    @Test func highTemperatureNamesTheTopConsumer() {
        let (title, body) = message(.highTemperature(celsius: 96, limit: 95, topConsumer: consumer))
        #expect(title == String(localized: "Mac a \("96 °C")"))
        #expect(body == String(localized: "Quem mais consome: \(described)."))
    }

    @Test func highTemperatureWithoutConsumerShowsTheLimit() {
        let (_, body) = message(.highTemperature(celsius: 96, limit: 95, topConsumer: nil))
        #expect(body == String(localized: "Acima do limite de \("95 °C")."))
    }

    @Test func throttlingDescribesThePressure() {
        let (title, body) = message(.throttling(.heavy, topConsumer: consumer))
        #expect(title == String(localized: "O macOS está limitando o desempenho"))
        #expect(
            body
                == String(localized: "Pressão térmica \(ThermalPressure.heavy.label.lowercased()).") + " "
                + String(localized: "Quem mais consome: \(described)."))
    }

    @Test func throttlingWithUnknownPressureSaysHigh() {
        let (_, body) = message(.throttling(nil, topConsumer: nil))
        #expect(body == String(localized: "Pressão térmica \(String(localized: "alta"))."))
    }

    @Test func appPowerShowsTheAverageWindow() {
        let (title, body) = message(.appPower(consumer, window: 600))
        #expect(title == String(localized: "\("XCODE") está gastando \(12.0.formatted(.watts))"))
        #expect(body == String(localized: "Média dos últimos \(10) minutos."))
    }

    @Test func appPowerOnBatterySaysHowMuchItDrainsPerHour() throws {
        let battery = try #require(makeBattery())
        let (_, body) = message(.appPower(consumer, window: 600), battery: battery)
        // 12 W numa bateria de 60 Wh: 20% por hora.
        let drain = String(
            localized: "Só a CPU e a GPU dele já tiram cerca de \(0.2.formatted(.percent)) da bateria por hora.")
        #expect(body == String(localized: "Média dos últimos \(10) minutos.") + " " + drain)
    }

    @Test func appPowerPluggedInOrNegligibleSkipsTheDrain() throws {
        let average = String(localized: "Média dos últimos \(10) minutos.")
        let pluggedIn = try #require(makeBattery(pluggedIn: true))
        #expect(message(.appPower(consumer, window: 600), battery: pluggedIn).body == average)
        let tiny = PowerConsumer(app: "a", watts: 0.1)
        let onBattery = try #require(makeBattery())
        #expect(message(.appPower(tiny, window: 600), battery: onBattery).body == average)
    }
}
