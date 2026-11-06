import Foundation
import Testing

struct GPUAttributionTests {
    private let names: [pid_t: String] = [1: "WindowServer", 2: "gpuload", 3: "Safari"]

    @Test func occupancyIsTheGPUTimeOverTheInterval() {
        let occupancy = GPUAttribution.occupancy(
            times: [1: 1_500_000_000, 2: 4_000_000_000, 3: 700],
            previous: [1: 1_000_000_000, 2: 1_000_000_000, 3: 700],
            elapsed: 2)
        #expect(occupancy[1] == 0.25)
        // Nunca passa de 100% do intervalo.
        #expect(occupancy[2] == 1)
        // Sem tempo novo de GPU, o processo não aparece.
        #expect(occupancy[3] == nil)
    }

    @Test func newOrReusedProcessesCountAllTheirTime() {
        let occupancy = GPUAttribution.occupancy(
            times: [1: 500_000_000, 2: 250_000_000], previous: [2: 900_000_000], elapsed: 1)
        #expect(occupancy == [1: 0.5, 2: 0.25])
    }

    @Test func noElapsedTimeMeansNoOccupancy() {
        #expect(GPUAttribution.occupancy(times: [1: 10], previous: [:], elapsed: 0).isEmpty)
    }

    @Test func splitsProportionallyWithoutTheCompositor() {
        var attribution = GPUAttribution()
        let watts = attribution.attribute(6, occupancy: [2: 0.2, 3: 0.4], names: names)
        #expect(watts[2] == 2)
        #expect(watts[3] == 4)
        #expect(attribution.compositorBaseline == 0.3)
    }

    @Test func idleGPUAttributesNothing() {
        var attribution = GPUAttribution()
        #expect(attribution.attribute(5, occupancy: [:], names: names).isEmpty)
        #expect(attribution.attribute(5, occupancy: [2: 0], names: names).isEmpty)
    }

    @Test func compositorAloneTeachesTheBaseline() {
        var attribution = GPUAttribution()
        let watts = attribution.attribute(1.3, occupancy: [1: 0.3, 2: 0.01], names: names)
        // Sem disputa, o rateio é proporcional e a referência anda 10% na direção da medição.
        #expect(abs((watts[1] ?? 0) - 1.3 * 0.3 / 0.31) < 1e-9)
        #expect(abs(attribution.compositorBaseline - 0.4) < 1e-9)
    }

    @Test func contentionCapsTheCompositorAndGivesTheRestToOthers() {
        var attribution = GPUAttribution()
        // WindowServer com o tempo inflado pela fila: proporcionalmente ficaria com metade.
        let watts = attribution.attribute(10, occupancy: [1: 0.5, 2: 0.3, 3: 0.2], names: names)
        let cap = 0.3 * GPUAttribution.compositorCapFactor
        #expect(abs((watts[1] ?? 0) - cap) < 1e-9)
        #expect(abs((watts[2] ?? 0) - (10 - cap) * 0.6) < 1e-9)
        #expect(abs((watts[3] ?? 0) - (10 - cap) * 0.4) < 1e-9)
        #expect(abs(watts.values.reduce(0, +) - 10) < 1e-9)
        // A referência só é aprendida sem disputa.
        #expect(attribution.compositorBaseline == 0.3)
    }

    @Test func compositorBelowTheCapKeepsItsProportionalShare() {
        var attribution = GPUAttribution()
        let watts = attribution.attribute(0.4, occupancy: [1: 0.25, 2: 0.75], names: names)
        #expect(abs((watts[1] ?? 0) - 0.1) < 1e-9)
        #expect(abs((watts[2] ?? 0) - 0.3) < 1e-9)
    }

    @Test func capHasAFloorWhenTheBaselineIsTiny() {
        var attribution = GPUAttribution()
        // Muitas leituras ociosas puxam a referência para perto de zero.
        for _ in 0..<200 { _ = attribution.attribute(0, occupancy: [1: 0.5], names: names) }
        let watts = attribution.attribute(10, occupancy: [1: 0.5, 2: 0.5], names: names)
        #expect(abs((watts[1] ?? 0) - GPUAttribution.minimumCompositorCap) < 1e-9)
    }

    @Test func compositorWithoutGPUTimeIsIgnored() {
        var attribution = GPUAttribution()
        let watts = attribution.attribute(3, occupancy: [2: 0.5, 3: 0.5], names: names)
        #expect(watts == [2: 1.5, 3: 1.5])
    }

    @Test func parsesTheUserClientCreator() {
        let parsed = GPUAttribution.parse(creator: "pid 415, WindowServer")
        #expect(parsed?.pid == 415)
        #expect(parsed?.name == "WindowServer")
        #expect(GPUAttribution.parse(creator: "pid 7,  Mail ")?.name == "Mail")
        #expect(GPUAttribution.parse(creator: "WindowServer") == nil)
        #expect(GPUAttribution.parse(creator: "pid 415 WindowServer") == nil)
        #expect(GPUAttribution.parse(creator: "pid x, WindowServer") == nil)
    }

    @Test func counterDeltaHandlesNewAndReusedProcesses() {
        #expect(CounterDelta.since(100, current: 250) == 150)
        #expect(CounterDelta.since(nil, current: 80) == 80)
        // Leitura anterior maior: outro processo com o mesmo PID, tudo é deste intervalo.
        #expect(CounterDelta.since(900, current: 80) == 80)
        #expect(CounterDelta.since(80, current: 80) == nil)
        #expect(CounterDelta.since(nil, current: 0) == nil)
    }
}
