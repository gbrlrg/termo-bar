/// Convenções dos identificadores de app usados no histórico.
///
/// Um app aberto é identificado pelo bundle ID. Processos que não pertencem a nenhum app
/// usam `proc:<nome>`, e o grupo agregado do gráfico de energia usa `others`.
enum AppID {
    static let others = "outros"
    static let othersName = String(localized: "Outros")
    static let processPrefix = "proc:"
    static let unknownProcess = processPrefix + "?"

    static func process(named name: String) -> String { processPrefix + name }

    static func isProcess(_ id: String) -> Bool { id.hasPrefix(processPrefix) }
}
