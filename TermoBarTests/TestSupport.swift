import Foundation

/// Amostra com valores padrão, para os testes declararem só o que importa.
func makeSample(
    at seconds: TimeInterval,
    duration: TimeInterval = 5,
    temperature: Double = 50,
    maxTemperature: Double? = nil,
    openApps: [String] = [],
    frontmostApp: String? = nil,
    appPower: [String: Power]? = nil,
    pressure: Int? = 0,
    gpuPower: Double? = nil,
    fanSpeed: Double? = nil
) -> Sample {
    Sample(
        date: Date(timeIntervalSinceReferenceDate: seconds),
        duration: duration,
        averageTemperature: temperature,
        maxTemperature: maxTemperature ?? temperature,
        openApps: openApps,
        frontmostApp: frontmostApp,
        appPower: appPower,
        pressure: pressure,
        gpuPower: gpuPower,
        fanSpeed: fanSpeed)
}

/// Bateria de 12 V e 5.000 mAh (60 Wh), descarregando a 12 W por padrão.
func makeBattery(
    percent: Int = 80,
    pluggedIn: Bool = false,
    charging: Bool = false,
    milliamps: Int64 = -1000,
    minutesToFull: Int = 65535,
    cycles: Int? = 32,
    designCycles: Int? = 1000,
    capacities: Bool = true
) -> BatteryStatus? {
    var properties: [String: Any] = [
        "CurrentCapacity": percent,
        "MaxCapacity": 100,
        "ExternalConnected": pluggedIn,
        "IsCharging": charging,
        "Voltage": 12000,
        "Amperage": UInt64(bitPattern: milliamps),
        "AvgTimeToFull": minutesToFull,
    ]
    if let cycles { properties["CycleCount"] = cycles }
    if let designCycles { properties["DesignCycleCount9C"] = designCycles }
    if capacities {
        properties["BatteryData"] = [
            "DesignCapacity": 5000, "NominalChargeCapacity": 4500, "FullChargeCapacity": 5000,
            "RemainingCapacity": 4000,
        ]
    }
    return BatteryStatus(properties: properties)
}
