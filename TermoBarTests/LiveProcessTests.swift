import Foundation
import Testing

struct LiveProcessTests {
    private func details(_ pid: pid_t, _ name: String, project: String?, start: Date? = nil) -> ProcessDetails {
        ProcessDetails(
            pid: pid,
            description: ProcessDescription(
                ProcessFacts(
                    name: name, executablePath: "/usr/bin/\(name)", arguments: [name],
                    workingDirectory: project.map { "/Users/eu/\($0)" }),
                homeDirectory: "/Users/eu"),
            commandLine: name, startDate: start)
    }

    @Test func groupsEqualProcessesAndSortsByPower() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let known: [pid_t: ProcessDetails] = [
            1: details(1, "helper", project: nil),
            2: details(2, "helper", project: nil),
            3: details(3, "node", project: "site", start: start),
        ]
        let processes = LiveProcess.group(
            [(1, Power(cpu: 1, gpu: 0)), (3, Power(cpu: 1.5, gpu: 0)), (2, Power(cpu: 0.5, gpu: 0.5))],
            fallbackName: "Navegador"
        ) { known[$0] }

        #expect(processes.count == 2)
        let helpers = processes[0]
        #expect(helpers.description.title == "helper")
        #expect(helpers.pids == [1, 2])
        #expect(helpers.power == Power(cpu: 1.5, gpu: 0.5))
        // Vários processos juntos não têm um detalhe único.
        #expect(helpers.details == nil)
        #expect(helpers.id == helpers.description)

        let node = processes[1]
        #expect(node.pids == [3])
        #expect(node.details?.startDate == start)
        #expect(node.description.subtitle == "site")
    }

    @Test func unreadableProcessesShowTheAppName() {
        let processes = LiveProcess.group(
            [(10, Power(cpu: 2, gpu: 0)), (11, Power(cpu: 1, gpu: 0))], fallbackName: "Kernel"
        ) { _ in nil }
        #expect(processes.count == 1)
        #expect(processes.first?.description.title == "Kernel")
        #expect(processes.first?.description.subtitle == nil)
        #expect(processes.first?.pids == [10, 11])
    }

    @Test func noActivityMeansNoProcesses() {
        #expect(LiveProcess.group([], fallbackName: "App") { _ in nil }.isEmpty)
    }
}
