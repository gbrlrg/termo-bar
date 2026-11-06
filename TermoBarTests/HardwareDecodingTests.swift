import Foundation
import Testing

struct HardwareDecodingTests {
    // MARK: - Sensores do die

    @Test func averagesTheReadingsNearTheMedian() throws {
        let result = try #require(DieTemperatureFilter.filter([50, 52, 54, nil, 95]))
        #expect(result.isIncluded == [true, true, true, false, false])
        #expect(result.average == 52)
        #expect(result.maximum == 54)
    }

    @Test func keepsReadingsAtTheDeviationLimit() throws {
        let result = try #require(DieTemperatureFilter.filter([50, 75, 25]))
        #expect(result.isIncluded == [true, true, true])
        #expect(result.maximum == 75)
    }

    @Test func noValidReadingMeansNoTemperature() {
        #expect(DieTemperatureFilter.filter([]) == nil)
        #expect(DieTemperatureFilter.filter([nil, nil]) == nil)
    }

    @Test func discardsImplausibleValues() {
        #expect(DieTemperatureFilter.plausible(55) == 55)
        #expect(DieTemperatureFilter.plausible(10) == 10)
        #expect(DieTemperatureFilter.plausible(130) == 130)
        #expect(DieTemperatureFilter.plausible(9.9) == nil)
        #expect(DieTemperatureFilter.plausible(-127) == nil)
        #expect(DieTemperatureFilter.plausible(200) == nil)
    }

    @Test(arguments: [
        ("PMU tdie3", String(localized: "Chip · sensor \("3")")),
        ("PMU tdev1", String(localized: "Placa · sensor \("1")")),
        ("als", String(localized: "Sensor de luz ambiente")),
        ("PMU tcal", String(localized: "Calibração \("1")")),
        ("PMU2 tcal", String(localized: "Calibração \("2")")),
        ("NAND CH0 temp", "SSD"),
        ("gas gauge battery", String(localized: "Bateria")),
        ("Desconhecido", "Desconhecido"),
    ])
    func labelsSensors(name: String, label: String) {
        #expect(SensorLabel.label(for: name) == label)
    }

    // MARK: - SMC

    @Test func buildsFourCharacterCodes() {
        #expect(SMCValue.fourCC("F0Ac") == 0x4630_4163)
        #expect(SMCValue.fourCC("flt ") == 0x666c_7420)
    }

    @Test func decodesLittleEndianFloats() {
        let bytes = withUnsafeBytes(of: Float(2503.5).bitPattern.littleEndian) { Array($0) }
        #expect(SMCValue.decode(bytes, type: SMCValue.fourCC("flt ")) == 2503.5)
    }

    @Test func decodesBigEndianIntegersAndFixedPoint() {
        #expect(SMCValue.decode([2], type: SMCValue.fourCC("ui8 ")) == 2)
        #expect(SMCValue.decode([0x01, 0x02], type: SMCValue.fourCC("ui16")) == 258)
        #expect(SMCValue.decode([0, 0, 0x01, 0x00], type: SMCValue.fourCC("ui32")) == 256)
        #expect(SMCValue.decode([0x27, 0x10], type: SMCValue.fourCC("fpe2")) == 2500)
    }

    @Test func rejectsUnknownTypesAndWrongSizes() {
        #expect(SMCValue.decode([1, 2], type: SMCValue.fourCC("ui8 ")) == nil)
        #expect(SMCValue.decode([1, 2, 3], type: SMCValue.fourCC("flt ")) == nil)
        #expect(SMCValue.decode([1], type: SMCValue.fourCC("ch8*")) == nil)
    }

    // MARK: - Grupos de energia

    @Test func looseProcessesAreGroupedByName() {
        let group = EnergyGroup.process(named: "wrangler")
        #expect(group.id == AppID.process(named: "wrangler"))
        #expect(group.name == "wrangler")
        #expect(EnergyGroup.process(named: "kernel_task").name == "Kernel")
    }

    @Test func helpersJoinTheAppTheyBelongTo() {
        #expect(EnergyGroup.process(named: "com.docker.backend").id == "com.docker.docker")
        #expect(EnergyGroup.process(named: "SimulatorTrampoline").id == "com.apple.iphonesimulator")
        // Por prefixo, como os serviços do CoreSimulator.
        #expect(
            EnergyGroup.process(named: "com.apple.CoreSimulator.CoreSimulatorService").id == "com.apple.iphonesimulator"
        )
    }

    @Test func unnamedProcessesGoToOthers() {
        let group = EnergyGroup.process(named: nil)
        #expect(group.id == AppID.unknownProcess)
        #expect(group.name == String(localized: "Outros processos"))
        #expect(AppID.isProcess(group.id))
    }
}
