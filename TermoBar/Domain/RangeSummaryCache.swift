import Foundation

/// Guarda o último resumo de cada período enquanto as amostras não mudam.
///
/// O popover redesenha a cada movimento do cursor sobre os gráficos e a lista; sem o cache, cada
/// redesenho refazia o resumo inteiro, o que nos 7 dias (10 mil resumos por minuto) leva dezenas
/// de milissegundos.
struct RangeSummaryCache {
    /// O que identifica as entradas de um resumo: se nada disso mudou, o resumo é o mesmo.
    struct Key: Equatable {
        let end: Date
        let count: Int
        let first: Date?
        let last: Date?
        let highlighted: Set<String>
        let names: [String: String]
    }

    private var entries: [TimeRange: (key: Key, summary: RangeSummary)] = [:]

    /// O resumo do período, reaproveitado se as amostras, o fim, as cores e os nomes forem os mesmos.
    mutating func summary(
        range: TimeRange, history: [Sample], end: Date, highlighted: Set<String>, names: [String: String]
    ) -> RangeSummary {
        let key = Key(
            end: end, count: history.count, first: history.first?.date, last: history.last?.date,
            highlighted: highlighted, names: names)
        if let entry = entries[range], entry.key == key { return entry.summary }
        let summary = RangeSummary(range: range, history: history, end: end, highlighted: highlighted) {
            AppID.displayName(of: $0, names: names)
        }
        entries[range] = (key, summary)
        return summary
    }
}
