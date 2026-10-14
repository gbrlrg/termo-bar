import SwiftUI

/// Processos de um app consumindo agora, abertos ao clicar no app da lista.
struct ProcessListView: View {
    @Environment(Monitor.self) private var monitor
    let appID: String

    private let visibleCount = 6

    var body: some View {
        let processes = monitor.liveProcesses(of: appID)
        VStack(alignment: .leading, spacing: 2) {
            Text("Processos agora · média de \(Int(ProcessActivity.window)) s")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.bottom, 2)
            if processes.isEmpty {
                Text("Nenhum processo consumindo agora.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
            } else {
                ForEach(processes.prefix(visibleCount)) { process in
                    ProcessRowView(process: process)
                }
                let rest = processes.dropFirst(visibleCount)
                if !rest.isEmpty {
                    let watts = rest.reduce(0) { $0 + $1.power.total }
                    HStack {
                        Text("Mais \(rest.reduce(0) { $0 + $1.pids.count }) processos")
                        Spacer()
                        Text(watts.formatted(.watts)).monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                }
            }
        }
        .padding(.leading, 34)
        .padding(.top, 2)
        .padding(.bottom, 6)
    }
}

private struct ProcessRowView: View {
    let process: LiveProcess

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(process.description.title)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    if process.pids.count > 1 {
                        Text("×\(process.pids.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 6)
            Text(process.power.total.formatted(.watts))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .help(help)
    }

    /// "dev · meu-site · há 2 h 48 min".
    private var detail: String? {
        var parts = [process.description.subtitle].compactMap(\.self)
        if let start = process.details?.startDate {
            parts.append(String(localized: "há \(Self.elapsed(since: start))"))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var help: String {
        let power = "CPU \(process.power.cpu.formatted(.watts)) · GPU \(process.power.gpu.formatted(.watts))"
        guard let details = process.details else {
            return String(localized: "\(process.pids.count) processos · \(power)")
        }
        return ["PID \(details.pid) · \(power)", details.commandLine].compactMap(\.self).joined(separator: "\n")
    }

    private static func elapsed(since start: Date) -> String {
        let seconds = max(Date().timeIntervalSince(start), 0)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.allowedUnits = seconds < 60 ? [.second] : [.day, .hour, .minute]
        return formatter.string(from: seconds) ?? ""
    }
}
