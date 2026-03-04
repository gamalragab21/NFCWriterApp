import CoreNFC
import Foundation
import SwiftUI

enum AccessState: Equatable, Sendable {
    case idle
    case scanning
    case success(roomNumber: String)
    case error(message: String)
}

@Observable
@MainActor
final class DoorAccessViewModel {
    var accessState: AccessState = .idle
    var accessLog: [AccessLogEntry] = []

    // Guest data fields
    var masterKey: String = ""
    var roomNumber: String = ""
    var checkIn: String = ""
    var checkOut: String = ""

    var isNFCAvailable: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return NFCNDEFReaderSession.readingAvailable
        #endif
    }

    var hasGuestData: Bool {
        !masterKey.isEmpty && !roomNumber.isEmpty && !checkIn.isEmpty && !checkOut.isEmpty
    }

    private let accessLogService: AccessLogService
    private let keychainService: KeychainService

    init() {
        self.keychainService = KeychainService()
        self.accessLogService = AccessLogService()

        // Load saved guest data
        loadGuestData()

        // Load access log
        self.accessLog = accessLogService.loadEntries()
    }

    private let maxRetries = 2

    func startDoorAccess() async {
        guard accessState != .scanning else { return }
        guard hasGuestData else {
            accessState = .error(message: "Please fill in all guest data")
            return
        }

        accessState = .scanning

        let guestData = GuestAccessData(
            masterKey: masterKey,
            roomNumber: roomNumber,
            checkIn: checkIn,
            checkOut: checkOut
        )

        // Retry loop for system busy errors (e.g. Apple Wallet grabbed NFC)
        for attempt in 0...maxRetries {
            let nfcService = NFCService(guestData: guestData)

            do {
                let result = try await nfcService.writeGuestData()
                accessState = .success(roomNumber: result.roomNumber)

                let entry = AccessLogEntry(doorID: "Room \(result.roomNumber)", success: true)
                accessLogService.addEntry(entry)
                accessLog = accessLogService.loadEntries()

                try? await Task.sleep(for: .seconds(3))
                if case .success = accessState {
                    accessState = .idle
                }
                return
            } catch NFCAccessError.systemBusy where attempt < maxRetries {
                // NFC busy (Wallet interference) — wait and retry
                accessState = .error(message: "NFC busy, retrying... (\(attempt + 1)/\(maxRetries))")
                try? await Task.sleep(for: .seconds(1.5))
                accessState = .scanning
                continue
            } catch {
                let message: String
                if let nfcError = error as? NFCAccessError {
                    message = nfcError.errorDescription ?? error.localizedDescription
                } else {
                    message = error.localizedDescription
                }

                if message.contains("Cancelled") {
                    accessState = .idle
                    return
                }

                accessState = .error(message: message)

                let entry = AccessLogEntry(doorID: "Room \(roomNumber)", success: false, errorMessage: message)
                accessLogService.addEntry(entry)
                accessLog = accessLogService.loadEntries()
                return
            }
        }
    }

    func saveGuestData() {
        try? keychainService.saveString(masterKey, forKey: "guest_masterKey")
        try? keychainService.saveString(roomNumber, forKey: "guest_roomNumber")
        try? keychainService.saveString(checkIn, forKey: "guest_checkIn")
        try? keychainService.saveString(checkOut, forKey: "guest_checkOut")
    }

    func resetState() {
        accessState = .idle
    }

    func clearHistory() {
        accessLogService.clearEntries()
        accessLog = []
    }

    // MARK: - Private

    private func loadGuestData() {
        masterKey = keychainService.loadString(forKey: "guest_masterKey") ?? ""
        roomNumber = keychainService.loadString(forKey: "guest_roomNumber") ?? ""
        checkIn = keychainService.loadString(forKey: "guest_checkIn") ?? ""
        checkOut = keychainService.loadString(forKey: "guest_checkOut") ?? ""
    }
}
