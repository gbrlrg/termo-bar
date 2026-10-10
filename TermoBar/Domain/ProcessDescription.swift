import Foundation

/// O que se sabe de um processo pelo kernel: executável, argumentos e pasta de trabalho.
struct ProcessFacts: Hashable, Sendable {
    /// Nome curto do kernel (`proc_name`), usado quando o caminho não é legível.
    let name: String
    let executablePath: String?
    /// `argv`, incluindo o próprio executável.
    let arguments: [String]
    let workingDirectory: String?
}

/// Nome legível de um processo e o que ele está fazendo: "wrangler" · "dev · Mindminer".
struct ProcessDescription: Hashable, Sendable {
    let title: String
    let subtitle: String?

    /// Interpretadores: o que importa é o script que eles rodam.
    private static let interpreters: Set<String> = [
        "node", "bun", "deno", "python", "python3", "ruby", "perl", "php", "java",
    ]
    /// Executáveis com nome pouco claro.
    private static let friendlyNames = [
        "swiftpm-testing-helper": "Testes Swift",
        "swift-test": "swift test",
        "swift-frontend": "Compilador Swift",
        "com.apple.Virtualization.VirtualMachine": "Máquina virtual",
        "com.docker.virtualization": "Máquina virtual do Docker",
    ]
    private static let simulatorDevicesMarker = "/CoreSimulator/Devices/"

    /// - Parameters:
    ///   - homeDirectory: pasta de trabalho que não diz nada sobre o projeto.
    ///   - simulatorDevice: nome do aparelho do Simulador a partir do UDID.
    init(_ facts: ProcessFacts, homeDirectory: String, simulatorDevice: (String) -> String? = { _ in nil }) {
        let arguments = Self.normalized(facts.arguments)
        // Quem mudou o próprio título se apresenta pelo novo nome, não pelo do interpretador.
        let isRetitled = arguments != facts.arguments
        let path = (isRetitled ? arguments.first : facts.executablePath ?? arguments.first) ?? facts.name
        let executable = Self.executableName(path) ?? facts.name

        if let udid = Self.simulatorUDID(in: path) {
            let app = path.split(separator: "/").last { $0.hasSuffix(".app") }.map { String($0.dropLast(4)) }
            title = app ?? executable
            subtitle = ["Simulador", simulatorDevice(udid)].compactMap(\.self).joined(separator: " · ")
            return
        }

        var commandIndex = 1
        var name = Self.friendlyNames[executable] ?? executable
        if Self.interpreters.contains(Self.interpreterName(executable)),
            let scriptIndex = arguments.indices.dropFirst().first(where: { !arguments[$0].hasPrefix("-") })
        {
            name = Self.toolName(fromScript: arguments[scriptIndex])
            commandIndex = scriptIndex + 1
        }
        title = name

        let command = arguments.indices.contains(commandIndex) ? arguments[commandIndex] : nil
        let project = facts.workingDirectory.flatMap { directory -> String? in
            let trimmed = directory.hasSuffix("/") ? String(directory.dropLast()) : directory
            guard !trimmed.isEmpty, trimmed != homeDirectory, trimmed != "/" else { return nil }
            return Self.basename(trimmed)
        }
        let parts = [command.flatMap(Self.subcommand), project].compactMap(\.self)
        subtitle = parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Processos que mudam o próprio título (`npm exec …`) deixam tudo num único argumento.
    private static func normalized(_ arguments: [String]) -> [String] {
        guard arguments.count == 1, let only = arguments.first, only.contains(" "), !only.hasPrefix("/") else {
            return arguments
        }
        return only.split(separator: " ").map(String.init)
    }

    /// Nome do arquivo, ou da pasta do programa quando o arquivo é só a versão
    /// ("~/.local/share/claude/versions/2.1.296" → "claude").
    private static func executableName(_ path: String) -> String? {
        let components = path.split(separator: "/").map(String.init)
        let isVersion = { (name: String) in name.first?.isNumber == true && name.allSatisfy { $0.isNumber || $0 == "." } }
        guard let last = components.last else { return nil }
        guard isVersion(last) else { return last }
        return components.dropLast().reversed().first { !isVersion($0) && !["versions", "bin"].contains($0) } ?? last
    }

    private static func basename(_ path: String) -> String {
        path.split(separator: "/").last.map(String.init) ?? path
    }

    /// "python3.12" → "python3".
    private static func interpreterName(_ executable: String) -> String {
        guard let dot = executable.firstIndex(of: "."), executable.hasPrefix("python") else { return executable }
        return String(executable[..<dot])
    }

    /// O pacote dono do script: ".../node_modules/wrangler/wrangler-dist/cli.js" → "wrangler".
    private static func toolName(fromScript script: String) -> String {
        let components = script.split(separator: "/").map(String.init)
        if let index = components.lastIndex(of: "node_modules") {
            var rest = components[(index + 1)...].drop { $0 == ".bin" }
            if let scope = rest.first, scope.hasPrefix("@"), rest.count > 1 { rest = rest.dropFirst() }
            if let package = rest.first { return package }
        }
        let file = components.last ?? script
        let stem = file.split(separator: ".").first.map(String.init) ?? file
        return stem.isEmpty ? file : stem
    }

    /// Só palavras simples contam como subcomando ("dev", "render"), não valores nem caminhos.
    private static func subcommand(_ argument: String) -> String? {
        guard let first = argument.first, first.isLetter, first.isLowercase, argument.count <= 24,
            argument.allSatisfy({ $0.isLetter || $0.isNumber || "-_:".contains($0) })
        else { return nil }
        return argument
    }

    private static func simulatorUDID(in path: String) -> String? {
        guard let range = path.range(of: simulatorDevicesMarker) else { return nil }
        let udid = path[range.upperBound...].prefix { $0 != "/" }
        return udid.count == 36 ? String(udid) : nil
    }
}
