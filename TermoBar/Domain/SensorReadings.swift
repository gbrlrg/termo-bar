import Foundation

/// Filtro das leituras dos sensores do die: descarta as que destoam da mediana.
///
/// Fica fora do `TemperatureSensors`, que lê o IOHID, para a regra poder ser testada.
enum DieTemperatureFilter {
    /// Faixa de leitura plausível (°C); fora dela o sensor está com defeito ou desligado.
    static let plausibleRange = 10.0...130.0
    /// Um sensor do die que destoa da mediana por mais que isso (°C) está com defeito ou é outro componente.
    static let maxDeviation = 25.0

    struct Result: Equatable, Sendable {
        /// Para cada leitura, na mesma ordem: entrou na média?
        let isIncluded: [Bool]
        let average: Double
        let maximum: Double
    }

    /// A leitura bruta, ou `nil` fora da faixa plausível.
    static func plausible(_ value: Double) -> Double? {
        plausibleRange.contains(value) ? value : nil
    }

    /// Média e máximo das leituras próximas da mediana; `nil` sem nenhuma leitura válida.
    static func filter(_ values: [Double?]) -> Result? {
        let valid = values.compactMap { $0 }.sorted()
        guard !valid.isEmpty else { return nil }
        let median = valid[valid.count / 2]
        let isIncluded = values.map { value in value.map { abs($0 - median) <= maxDeviation } ?? false }
        let accepted = zip(values, isIncluded).compactMap { $1 ? $0 : nil }
        guard let maximum = accepted.max() else { return nil }
        return Result(
            isIncluded: isIncluded, average: accepted.reduce(0, +) / Double(accepted.count), maximum: maximum)
    }
}

enum SensorLabel {
    /// Nome legível de um sensor do IOHID.
    static func label(for name: String) -> String {
        let number = String(name.drop { !$0.isNumber })
        return switch true {
        case name.hasPrefix("PMU tdie"): String(localized: "Chip · sensor \(number)")
        case name.hasPrefix("PMU2 tdie"): String(localized: "Chip, controlador 2 · sensor \(number)")
        case name.hasPrefix("PMU tdev"): String(localized: "Placa · sensor \(number)")
        case name.hasPrefix("PMU2 tdev"): String(localized: "Placa, controlador 2 · sensor \(number)")
        case name.hasPrefix("als"): String(localized: "Sensor de luz ambiente")
        case name.contains("tcal"): String(localized: "Calibração \(name.hasPrefix("PMU2") ? "2" : "1")")
        case name.hasPrefix("NAND"): "SSD"
        case name.contains("battery"): String(localized: "Bateria")
        default: name
        }
    }
}
