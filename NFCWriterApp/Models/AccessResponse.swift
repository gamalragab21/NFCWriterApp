import CoreNFC
import Foundation

struct GuestAccessData: Codable, Sendable {
    let masterKey: String       // 16 chars, unique key assigned at check-in
    let roomNumber: String      // Room number guest has access to
    let checkIn: String         // Check-in time: yyyy-MM-dd HH:mm
    let checkOut: String        // Check-out time: yyyy-MM-dd HH:mm
    let timestamp: Int64        // Request timestamp in milliseconds (replay prevention)

    init(masterKey: String, roomNumber: String, checkIn: String, checkOut: String) {
        self.masterKey = masterKey
        self.roomNumber = roomNumber
        self.checkIn = checkIn
        self.checkOut = checkOut
        self.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
    }
}

extension GuestAccessData {

    func toNDEFMessage() -> NFCNDEFMessage {
        let json: [String: Any] = [
            "masterKey": masterKey,
            "roomNumber": roomNumber,
            "checkIn": checkIn,
            "checkOut": checkOut,
            "timestamp": timestamp
        ]
        let jsonData = try! JSONSerialization.data(withJSONObject: json)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        let payload = NFCNDEFPayload.wellKnownTypeTextPayload(
            string: jsonString,
            locale: Locale(identifier: "en")
        )!

        return NFCNDEFMessage(records: [payload])
    }
}
