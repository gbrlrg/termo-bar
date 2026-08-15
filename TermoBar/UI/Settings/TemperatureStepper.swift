import SwiftUI

/// Stepper que edita um limite guardado em °C, avançando de grau em grau na unidade escolhida.
struct TemperatureStepper: View {
    @Environment(Preferences.self) private var preferences
    let title: String
    @Binding var celsius: Double

    var body: some View {
        let unit = preferences.unit
        let range = Preferences.temperatureLimitRange
        Stepper {
            LabeledContent(title, value: preferences.format(celsius, decimals: 0))
        } onIncrement: {
            celsius = unit.toCelsius(unit.convert(celsius).rounded() + 1).clamped(to: range)
        } onDecrement: {
            celsius = unit.toCelsius(unit.convert(celsius).rounded() - 1).clamped(to: range)
        }
    }
}
