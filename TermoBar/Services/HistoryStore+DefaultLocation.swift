import Foundation

extension HistoryStore {
    /// `~/Library/Application Support/TermoBar/history.sqlite`
    static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "TermoBar/history.sqlite", directoryHint: .notDirectory)
    }
}
