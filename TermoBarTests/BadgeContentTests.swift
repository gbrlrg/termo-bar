import Foundation
import Testing

struct BadgeContentTests {
    // MARK: - Badge da bateria

    @Test func batteryTextAddsTheTemperatureWhenKnown() throws {
        let battery = try #require(makeBattery(percent: 64))
        #expect(BatteryBadgeContent.text(battery, temperature: nil) == "64%")
        #expect(BatteryBadgeContent.text(battery, temperature: "31 °C") == "64% · 31 °C")
    }

    @Test(arguments: [
        (5, "battery.0percent"), (20, "battery.25percent"), (50, "battery.50percent"), (80, "battery.75percent"),
        (95, "battery.100percent"),
    ])
    func batterySymbolFollowsTheCharge(percent: Int, symbol: String) throws {
        #expect(BatteryBadgeContent.symbol(try #require(makeBattery(percent: percent))) == symbol)
    }

    @Test func chargingShowsTheBolt() throws {
        let battery = try #require(makeBattery(percent: 20, pluggedIn: true, charging: true, milliamps: 1500))
        #expect(BatteryBadgeContent.symbol(battery) == "battery.100percent.bolt")
        #expect(BatteryBadgeContent.state(battery) == String(localized: "carregando"))
    }

    @Test func helpDescribesTheState() throws {
        let onBattery = try #require(makeBattery())
        let pluggedIn = try #require(makeBattery(pluggedIn: true, milliamps: 0))
        let unplugged = String(localized: "na bateria")
        #expect(BatteryBadgeContent.state(pluggedIn) == String(localized: "na tomada"))
        #expect(
            BatteryBadgeContent.help(onBattery, temperature: nil) == String(localized: "Carga da bateria, \(unplugged)")
        )
        #expect(
            BatteryBadgeContent.help(onBattery, temperature: "30 °C")
                == String(localized: "Carga e temperatura da bateria, \(unplugged)"))
    }

    @Test func timeBadgeWhileDischargingWaitsForTheEstimate() throws {
        let battery = try #require(makeBattery())
        #expect(BatteryBadgeContent.hasTime(battery))
        let calculating = try #require(BatteryBadgeContent.time(battery, runtime: nil))
        #expect(calculating.text == String(localized: "Calculando…"))
    }

    @Test func timeBadgeShowsTheRoundedRuntime() throws {
        let battery = try #require(makeBattery())
        let runtime = RuntimeEstimate(hours: 1.3, watts: 9, basis: 300)
        let content = try #require(BatteryBadgeContent.time(battery, runtime: runtime))
        #expect(content.text == "~" + BatteryBadgeContent.format(minutes: 80))
        #expect(
            content.help
                == String(
                    localized:
                        "Autonomia no ritmo dos últimos \(5) min (\(9.0.formatted(.watts))). Muda conforme o que você faz."
                ))
    }

    @Test func timeBadgeCapsLongEstimates() throws {
        let runtime = RuntimeEstimate(hours: 30, watts: 1, basis: 600)
        let battery = try #require(makeBattery())
        let content = try #require(BatteryBadgeContent.time(battery, runtime: runtime))
        #expect(content.text == String(localized: "mais de 24 h"))
    }

    @Test func timeBadgeWhileChargingShowsTimeToFull() throws {
        let charging = try #require(makeBattery(pluggedIn: true, charging: true, milliamps: 1500, minutesToFull: 95))
        #expect(BatteryBadgeContent.hasTime(charging))
        let content = try #require(BatteryBadgeContent.time(charging, runtime: nil))
        #expect(content.text == String(localized: "Cheia em \(BatteryBadgeContent.format(minutes: 95))"))
        #expect(BatteryBadgeContent.format(minutes: 95) != BatteryBadgeContent.format(minutes: 90))
    }

    @Test func timeBadgeIsHiddenWhenThereIsNothingToShow() throws {
        let full = try #require(makeBattery(percent: 100, pluggedIn: true, milliamps: 0))
        #expect(!BatteryBadgeContent.hasTime(full))
        #expect(BatteryBadgeContent.time(full, runtime: nil) == nil)
    }

    // MARK: - Detalhes dos badges

    @Test func pressureDetailsShowTheThrottledShare() {
        let samples = [makeSample(at: 0, pressure: 0), makeSample(at: 5, pressure: 2)]
        let content = BadgeDetails.pressure(.heavy, samples: samples)
        #expect(content.rows.map(\.title) == [String(localized: "Estado"), String(localized: "Limitado no período")])
        #expect(content.rows.first?.value == ThermalPressure.heavy.label)
        #expect(content.rows.last?.value == 0.5.formatted(.percent.precision(.fractionLength(0))))
        #expect(content.note == ThermalPressure.heavy.explanation)
        #expect(BadgeDetails.pressure(.nominal, samples: [makeSample(at: 0, pressure: nil)]).rows.count == 1)
    }

    @Test func everyPressureLevelIsExplained() {
        let explanations = Set(ThermalPressure.allCases.map(\.explanation))
        #expect(explanations.count == ThermalPressure.allCases.count)
    }

    @Test func fanDetailsShowPeakAndSpinningShare() {
        let samples = [makeSample(at: 0, fanSpeed: 0), makeSample(at: 5, fanSpeed: 3200)]
        let content = BadgeDetails.fan(rpm: 2400, samples: samples)
        #expect(
            content.rows == [
                BadgeDetailRow(title: String(localized: "Rotação agora"), value: 2400.0.formatted(.rpm)),
                BadgeDetailRow(title: String(localized: "Pico no período"), value: 3200.0.formatted(.rpm)),
                BadgeDetailRow(
                    title: String(localized: "Girando no período"),
                    value: 0.5.formatted(.percent.precision(.fractionLength(0)))),
            ])
        #expect(content.note == nil)
    }

    @Test func stoppedFanHasNoPeak() {
        let content = BadgeDetails.fan(rpm: 20, samples: [makeSample(at: 0, fanSpeed: 50)])
        #expect(content.rows.first?.value == String(localized: "Parado"))
        #expect(content.rows.map(\.title).contains(String(localized: "Pico no período")) == false)
        #expect(BadgeDetails.fan(rpm: 0, samples: []).rows.count == 1)
    }

    @Test func batteryDetailsListHealthCyclesAndPower() throws {
        let battery = try #require(makeBattery(percent: 72))
        let content = BadgeDetails.battery(battery, temperature: "33 °C")
        #expect(
            content.rows.map(\.title) == [
                String(localized: "Carga"), String(localized: "Capacidade máxima"), String(localized: "Ciclos"),
                String(localized: "Consumo do Mac"), String(localized: "Temperatura"),
            ])
        #expect(content.rows[0].value == "72% · \(String(localized: "na bateria"))")
        #expect(content.rows[1].value == 0.9.formatted(.percent.precision(.fractionLength(0))))
        #expect(content.rows[2].value == String(localized: "\(32) de \(1000)"))
        #expect(content.rows[3].value == 12.0.formatted(.watts))
        #expect(content.rows[4].value == "33 °C")
        #expect(content.note == String(localized: "A capacidade máxima é a mesma dos Ajustes do Sistema."))
        #expect(content.rows[0].id == content.rows[0].title)
    }

    @Test func batteryDetailsSkipWhatTheMacDoesNotReport() throws {
        let battery = try #require(
            makeBattery(pluggedIn: true, milliamps: 0, cycles: 12, designCycles: nil, capacities: false))
        let content = BadgeDetails.battery(battery, temperature: nil)
        #expect(content.rows.map(\.title) == [String(localized: "Carga"), String(localized: "Ciclos")])
        #expect(content.rows[1].value == 12.formatted())
        #expect(content.note == nil)
        let noCycles = try #require(makeBattery(pluggedIn: true, milliamps: 0, cycles: nil, capacities: false))
        #expect(BadgeDetails.battery(noCycles, temperature: nil).rows.count == 1)
    }
}
