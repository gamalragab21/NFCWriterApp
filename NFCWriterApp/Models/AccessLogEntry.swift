import Foundation

struct AccessLogEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let doorID: String
    let timestamp: Date
    let success: Bool
    let errorMessage: String?

    init(doorID: String, success: Bool, errorMessage: String? = nil) {
        self.id = UUID()
        self.doorID = doorID
        self.timestamp = Date()
        self.success = success
        self.errorMessage = errorMessage
    }
}
