/// Posição de cada app na paleta categórica do gráfico.
///
/// Os apps que mais gastaram ganham uma cor e a mantêm enquanto continuarem no topo,
/// para que a cor de um app não mude a cada nova leitura.
struct PaletteSlots: Equatable, Sendable {
    let capacity: Int
    private(set) var assignments: [String: Int] = [:]

    init(capacity: Int) {
        self.capacity = capacity
    }

    subscript(id: String) -> Int? { assignments[id] }

    var apps: Set<String> { Set(assignments.keys) }

    /// Reatribui as cores aos `capacity` primeiros de `ranking` (do maior para o menor consumo).
    mutating func update(ranking: [String]) {
        let top = Array(ranking.prefix(capacity))
        assignments = assignments.filter { top.contains($0.key) }
        for id in top where assignments[id] == nil {
            let used = Set(assignments.values)
            assignments[id] = (0..<capacity).first { !used.contains($0) }
        }
    }
}
