import Foundation
import Testing

struct ProcessDescriptionTests {
    private let home = "/Users/ana"

    private func describe(
        _ arguments: [String], path: String? = nil, name: String = "proc", directory: String? = nil
    ) -> ProcessDescription {
        ProcessDescription(
            ProcessFacts(
                name: name, executablePath: path ?? arguments.first, arguments: arguments,
                workingDirectory: directory),
            homeDirectory: home,
            simulatorDevice: { $0 == "6F57DBDB-FEF6-4850-AEE7-D112FF1E96B6" ? "iPhone QA" : nil })
    }

    @Test func nodeScriptIsNamedAfterItsPackage() {
        let description = describe(
            [
                "/opt/node/bin/node", "--no-warnings",
                "/Users/ana/app/node_modules/wrangler/wrangler-dist/cli.js", "dev", "--port", "3777",
            ],
            directory: "/Users/ana/Mindminer/server")
        #expect(description.title == "wrangler")
        #expect(description.subtitle == "dev · server")
    }

    @Test func binLinksAndScopedPackagesUseThePackageName() {
        #expect(describe(["node", "/x/node_modules/.bin/hyperframes", "render"]).title == "hyperframes")
        #expect(describe(["node", "/x/node_modules/@scope/tool/index.js"]).title == "tool")
        #expect(describe(["/usr/bin/python3.12", "/srv/manage.py", "runserver"]).title == "manage")
    }

    @Test func plainExecutableShowsProjectFolder() {
        let description = describe(
            ["/opt/homebrew/bin/ffmpeg", "-framerate", "30", "-i", "frame.jpg"], directory: "/Users/ana/Mindminer/")
        #expect(description.title == "ffmpeg")
        #expect(description.subtitle == "Mindminer")
    }

    @Test func homeAndRootDirectoriesAreNotProjects() {
        #expect(describe(["/bin/zsh"], directory: home).subtitle == nil)
        #expect(describe(["/bin/zsh"], directory: "/").subtitle == nil)
    }

    @Test func friendlyNameReplacesCrypticExecutable() {
        let description = describe(
            ["/Applications/Xcode.app/x/swiftpm-testing-helper", "--test-bundle-path", "/x.xctest"],
            directory: "/Users/ana/TermoBar")
        #expect(description.title == "Testes Swift")
        #expect(description.subtitle == "TermoBar")
    }

    @Test func versionedExecutableIsNamedAfterItsFolder() {
        let description = describe(
            ["/Users/ana/.local/share/claude/versions/2.1.296"], directory: "/Users/ana/Tablewit")
        #expect(description.title == "claude")
        #expect(description.subtitle == "Tablewit")
    }

    @Test func retitledProcessIsNamedByItsTitle() {
        let description = describe(["npm exec hyperframes@0.8.41 render"], path: "/opt/node/bin/node", name: "node")
        #expect(description.title == "npm")
        #expect(description.subtitle == "exec")
    }

    @Test func simulatorAppShowsDevice() {
        let description = describe([
            "/Users/ana/Library/Developer/CoreSimulator/Devices/6F57DBDB-FEF6-4850-AEE7-D112FF1E96B6/data/Containers/Bundle/Application/658CD602-5211-46CF-B71F-2302AB3E6254/Tablewit.app/Tablewit"
        ])
        #expect(description.title == "Tablewit")
        #expect(description.subtitle == "Simulador · iPhone QA")
    }

    @Test func unreadableArgumentsFallBackToKernelName() {
        let description = ProcessDescription(
            ProcessFacts(name: "WindowServer", executablePath: nil, arguments: [], workingDirectory: nil),
            homeDirectory: home)
        #expect(description.title == "WindowServer")
        #expect(description.subtitle == nil)
    }
}

struct ProcessActivityTests {
    private func date(_ seconds: TimeInterval) -> Date { Date(timeIntervalSinceReferenceDate: seconds) }

    @Test func averageIsWeightedByDurationAndFilteredByGroup() {
        var activity = ProcessActivity()
        activity.record(
            [
                .init(pid: 1, group: "a", power: Power(cpu: 2, gpu: 0)),
                .init(pid: 2, group: "b", power: Power(cpu: 9, gpu: 0)),
            ], at: date(10), duration: 10)
        activity.record(
            [
                .init(pid: 1, group: "a", power: Power(cpu: 4, gpu: 1)),
                .init(pid: 3, group: "a", power: Power(cpu: 0.0001, gpu: 0)),
            ], at: date(20), duration: 10)

        let average = activity.average(of: "a")
        #expect(average.map(\.pid) == [1])
        #expect(average.first?.power == Power(cpu: 3, gpu: 0.5))
    }

    @Test func oldMeasurementsLeaveTheWindow() {
        var activity = ProcessActivity()
        activity.record([.init(pid: 1, group: "a", power: Power(cpu: 5, gpu: 0))], at: date(0), duration: 1)
        activity.record([.init(pid: 2, group: "a", power: Power(cpu: 1, gpu: 0))], at: date(40), duration: 1)

        #expect(activity.average(of: "a").map(\.pid) == [2])
    }
}
