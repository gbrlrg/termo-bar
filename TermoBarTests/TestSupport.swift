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
