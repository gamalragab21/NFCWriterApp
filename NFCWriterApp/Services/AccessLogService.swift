import Foundation

final class AccessLogService: @unchecked Sendable {
    private let key = "access_log_entries"
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func addEntry(_ entry: AccessLogEntry) {
        var entries = loadEntries()
        entries.insert(entry, at: 0)
        // Keep only the last 100 entries
        if entries.count > 100 {
            entries = Array(entries.prefix(100))
        }
        if let data = try? encoder.encode(entries) {
            defaults.set(data, forKey: key)
        }
    }

    func loadEntries() -> [AccessLogEntry] {
        guard let data = defaults.data(forKey: key),
              let entries = try? decoder.decode([AccessLogEntry].self, from: data)
        else { return [] }
        return entries
    }

    func clearEntries() {
        defaults.removeObject(forKey: key)
    }
}
