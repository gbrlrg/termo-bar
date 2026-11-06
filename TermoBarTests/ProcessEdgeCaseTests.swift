import Foundation
import Testing

/// Casos de borda do nome legível dos processos e da média recente por processo.
struct ProcessEdgeCaseTests {
    private func describe(_ arguments: [String], path: String? = nil, directory: String? = nil) -> ProcessDescription {
        ProcessDescription(
            ProcessFacts(name: "proc", executablePath: path, arguments: arguments, workingDirectory: directory),
            homeDirectory: "/Users/ana")
    }

    @Test func scriptsOutsideNodeModulesAreNamedAfterTheFile() {
        #expect(describe(["/usr/bin/python3.12", "-u", "/Users/ana/tools/backup.py", "run"]).title == "backup")
        #expect(describe(["ruby", "server"]).title == "server")
        // Arquivo oculto: o nome sem o ponto.
        #expect(describe(["node", ".eslintrc"]).title == "eslintrc")
        #expect(describe(["node", "."]).title == ".")
        // Pasta node_modules sem pacote depois dela.
        #expect(describe(["node", "/x/node_modules"]).title == "node_modules")
        #expect(describe(["node", "/x/node_modules/@scope"]).title == "@scope")
    }

    @Test func interpreterWithoutScriptKeepsItsName() {
        #expect(describe(["/usr/bin/python3", "-i"]).title == "python3")
        #expect(describe(["/usr/bin/pythonista.app"]).title == "pythonista.app")
    }

    @Test func versionOnlyPathsKeepTheLastComponent() {
        #expect(describe(["/bin/2.0"]).title == "2.0")
        #expect(describe(["/opt/1.2/3.4"]).title == "opt")
        #expect(describe(["/opt/claude/versions/2.1.296"]).title == "claude")
    }

    @Test func emptyPathFallsBackToTheKernelName() {
        #expect(describe([], path: "/").title == "proc")
    }

    @Test func onlySimpleWordsCountAsSubcommands() {
        #expect(describe(["/usr/local/bin/tool", "build:prod"]).subtitle == "build:prod")
        #expect(describe(["/usr/local/bin/tool", "Build"]).subtitle == nil)
        #expect(describe(["/usr/local/bin/tool", "dev.local"]).subtitle == nil)
        #expect(describe(["/usr/local/bin/tool", String(repeating: "a", count: 25)]).subtitle == nil)
        #expect(describe(["/usr/local/bin/tool", "--watch"]).subtitle == nil)
    }

    @Test func workingDirectoryWithTrailingSlashNamesTheProject() {
        #expect(describe(["/usr/local/bin/tool"], directory: "/Users/ana/site/").subtitle == "site")
        #expect(describe(["/usr/local/bin/tool"], directory: "/Users/ana/").subtitle == nil)
        #expect(describe(["/usr/local/bin/tool"], directory: "").subtitle == nil)
    }

    @Test func simulatorPathsNeedAFullDeviceID() {
        let short = describe(["/Users/ana/Library/Developer/CoreSimulator/Devices/123/data/app/Demo"])
        #expect(short.title == "Demo")
        #expect(short.subtitle == nil)
        let daemon = describe([
            "/Users/ana/Library/Developer/CoreSimulator/Devices/6F57DBDB-FEF6-4850-AEE7-D112FF1E96B6/data/usr/sbin/launchd_sim"
        ])
        // Sem `.app` no caminho, o nome é o do executável; sem nome do aparelho, só "Simulador".
        #expect(daemon.title == "launchd_sim")
        #expect(daemon.subtitle == String(localized: "Simulador"))
    }

    // MARK: - Atividade recente

    @Test func activityListsTheProcessesInTheWindow() {
        var activity = ProcessActivity()
        #expect(activity.pids.isEmpty)
        #expect(activity.average(of: "a").isEmpty)
        let date = Date(timeIntervalSinceReferenceDate: 0)
        activity.record(
            [
                .init(pid: 1, group: "a", power: Power(cpu: 1, gpu: 0)),
                .init(pid: 2, group: "b", power: Power(cpu: 1, gpu: 0)),
            ], at: date, duration: 5)
        // Medição sem duração não conta.
        activity.record([.init(pid: 3, group: "a", power: Power(cpu: 1, gpu: 0))], at: date, duration: 0)
        #expect(activity.pids == [1, 2])
    }

    @Test func activityBreaksPowerTiesByPID() {
        var activity = ProcessActivity()
        activity.record(
            [
                .init(pid: 9, group: "a", power: Power(cpu: 1, gpu: 0)),
                .init(pid: 4, group: "a", power: Power(cpu: 1, gpu: 0)),
                .init(pid: 7, group: "a", power: Power(cpu: 2, gpu: 0)),
            ], at: Date(timeIntervalSinceReferenceDate: 0), duration: 1)
        #expect(activity.average(of: "a").map(\.pid) == [7, 4, 9])
    }
}
