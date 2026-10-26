import Foundation
import Testing

struct BatteryTests {
    /// Propriedades como o `AppleSmartBattery` as publica num MacBook com Apple Silicon recente.
    private func properties(_ overrides: [String: Any] = [:]) -> [String: Any] {
        var base: [String: Any] = [
            "BatteryInstalled": true,
            "CurrentCapacity": 80,
            "MaxCapacity": 100,
            "CycleCount": 32,
            "ExternalConnected": true,
            "IsCharging": false,
            "Voltage": 12438,
            "Amperage": 0,
            "AvgTimeToFull": 65535,
            "BatteryData": [
                "DesignCapacity": 6249, "NominalChargeCapacity": 6332, "FullChargeCapacity": 6180,
                "RemainingCapacity": 4883,
            ] as [String: Any],
        ]
        base.merge(overrides) { $1 }
        return base
    }

    private func status(_ overrides: [String: Any] = [:]) throws -> BatteryStatus {
        try #require(BatteryStatus(properties: properties(overrides)))
    }

    /// O registro guarda a corrente negativa como inteiro sem sinal de 64 bits.
    private func wrapped(_ milliamps: Int64) -> UInt64 { UInt64(bitPattern: milliamps) }

    @Test func readsTheBasicsFromTheNestedBatteryData() throws {
        let battery = try status()
        #expect(battery.percent == 80)
        #expect(battery.cycleCount == 32)
        #expect(battery.isPluggedIn)
        #expect(!battery.isCharging)
        #expect(battery.designCapacity == 6249)
        #expect(battery.fullChargeCapacity == 6180)
        #expect(battery.dischargeWatts == nil)
    }

    @Test func healthMatchesSystemSettingsAndNeverPassesOneHundredPercent() throws {
        // 6332 / 6249 passa de 100%, e os Ajustes do Sistema mostram 100%.
        #expect(try status().health == 1)
        let worn = try status(["BatteryData": ["DesignCapacity": 6000, "NominalChargeCapacity": 5100]])
        #expect(worn.health == 0.85)
    }

    @Test func fallsBackToTheRootKeysOfOlderMacs() throws {
        let old = try status([
            "BatteryData": [:] as [String: Any], "DesignCapacity": 5000, "AppleRawMaxCapacity": 4500,
            "AppleRawCurrentCapacity": 2250,
        ])
        #expect(old.designCapacity == 5000)
        #expect(old.health == 0.9)
        #expect(old.remainingCapacity == 2250)
    }

    @Test func missingCapacitiesLeaveHealthAndEnergyUnknown() throws {
        let bare = try status(["BatteryData": [:] as [String: Any]])
        #expect(bare.health == nil)
        #expect(bare.remainingEnergy == nil)
        #expect(bare.fullEnergy == nil)
    }

    @Test func energyIsCapacityTimesVoltage() throws {
        let battery = try status()
        #expect(abs(try #require(battery.remainingEnergy) - 4.883 * 12.438) < 0.001)
        #expect(abs(try #require(battery.fullEnergy) - 6.18 * 12.438) < 0.001)
    }

    @Test func dischargePowerComesFromTheUnsignedCurrent() throws {
        let battery = try status(["ExternalConnected": false, "Amperage": wrapped(-1500)])
        #expect(abs(try #require(battery.dischargeWatts) - 1.5 * 12.438) < 0.001)
        #expect(battery.isDischarging)
    }

    @Test func chargingCurrentIsNotDischarge() throws {
        let battery = try status(["IsCharging": true, "Amperage": 2000])
        #expect(battery.dischargeWatts == nil)
        #expect(!battery.isDischarging)
    }

    @Test func pluggedInIsNotDischargingEvenWithCurrentLeaving() throws {
        let battery = try status(["Amperage": wrapped(-300)])
        #expect(battery.dischargeWatts != nil)
        #expect(!battery.isDischarging)
    }

    @Test func timeToFullOnlyWhileChargingAndKnown() throws {
        #expect(try status(["IsCharging": true, "AvgTimeToFull": 45]).minutesToFull == 45)
        #expect(try status(["IsCharging": true]).minutesToFull == nil)
        #expect(try status(["AvgTimeToFull": 45]).minutesToFull == nil)
    }

    @Test func rejectsMissingOrAbsentBatteries() {
        #expect(BatteryStatus(properties: [:]) == nil)
        #expect(BatteryStatus(properties: properties(["BatteryInstalled": false])) == nil)
        #expect(BatteryStatus(properties: properties(["MaxCapacity": 0])) == nil)
    }

    @Test func percentFollowsTheRatioWhenMaxIsNotOneHundred() throws {
        #expect(try status(["CurrentCapacity": 3000, "MaxCapacity": 6000]).percent == 50)
    }

    @Test func drainIsThePowerOverTheFullEnergy() {
        #expect(BatteryDrain.percentPerHour(watts: 5, fullEnergy: 50) == 10)
        #expect(BatteryDrain.percentPerHour(watts: 5, fullEnergy: nil) == nil)
        #expect(BatteryDrain.percentPerHour(watts: 5, fullEnergy: 0) == nil)
        #expect(BatteryDrain.percentPerHour(watts: -1, fullEnergy: 50) == nil)
    }
}
