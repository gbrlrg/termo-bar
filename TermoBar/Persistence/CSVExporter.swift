import Foundation

/// Gera o CSV de exportação: uma linha por (instante, app); temperatura em °C, potência em W,
/// ventoinhas em rpm. A coluna das ventoinhas fica no fim, para não deslocar as que já existiam.
enum CSVExporter {
    static let header = [
        "timestamp", "duracao_s", "temp_media_c", "temp_max_c", "pressao_termica", "gpu_total_w",
        "app_id", "app", "cpu_w", "gpu_w", "primeiro_plano", "ventoinha_rpm",
    ]

    static func csv(samples: [Sample], names: [String: String], timeZone: TimeZone = .current) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = timeZone

        var lines = [header.joined(separator: ",")]
        for sample in samples {
            let head = [
                dateFormatter.string(from: sample.date), number(sample.duration),
                number(sample.averageTemperature), number(sample.maxTemperature),
                sample.pressure.map(String.init) ?? "", number(sample.gpuPower),
            ]
            let fan = sample.fanSpeed.map { String(format: "%.0f", $0) } ?? ""
            let power = (sample.appPower ?? [:]).sorted { $0.value.total > $1.value.total }
            guard !power.isEmpty else {
                lines.append((head + Array(repeating: "", count: 5) + [fan]).joined(separator: ","))
                continue
            }
            for (id, watts) in power {
                let app = [
                    text(id), text(names[id] ?? id), number(watts.cpu), number(watts.gpu),
                    sample.frontmostApp == id ? "1" : "0", fan,
                ]
                lines.append((head + app).joined(separator: ","))
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func number(_ value: Double?) -> String {
        value.map { String(format: "%.3f", $0) } ?? ""
    }

    /// Escapa um campo de texto (RFC 4180) e neutraliza fórmulas.
    ///
    /// Nomes de processo são escolhidos por quem os executa; um nome começando com `=`, `+`,
    /// `-` ou `@` seria interpretado como fórmula ao abrir o CSV numa planilha.
    static func text(_ value: String) -> String {
        var value = value
        if let first = value.unicodeScalars.first, "=+-@\t\r".unicodeScalars.contains(first) {
            value = "'" + value
        }
        guard value.contains(where: { ",\"\n\r".contains($0) }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
