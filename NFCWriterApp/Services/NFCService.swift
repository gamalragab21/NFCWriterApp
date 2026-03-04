@preconcurrency import CoreNFC
import Foundation

nonisolated enum NFCAccessError: LocalizedError, Sendable {
    case nfcNotAvailable
    case sessionInvalidated(String)
    case writeFailed(String)
    case tagConnectionFailed(String)
    case tagNotWritable
    case systemBusy
    case unsupportedTag

    var errorDescription: String? {
        switch self {
        case .nfcNotAvailable:
            return "NFC is not available on this device"
        case .sessionInvalidated(let msg):
            return "NFC session ended: \(msg)"
        case .writeFailed(let msg):
            return "Failed to write data: \(msg)"
        case .tagConnectionFailed(let msg):
            return "Connection failed: \(msg)"
        case .tagNotWritable:
            return "Tag is not writable"
        case .systemBusy:
            return "NFC hardware is busy. Go to Settings → Wallet → Express Mode and turn it OFF, then try again."
        case .unsupportedTag:
            return "Unsupported tag type. Reader must be ISO 14443-4 compatible."
        }
    }
}

nonisolated struct NFCWriteResult: Sendable {
    let roomNumber: String
    let timestamp: Date
}

nonisolated final class NFCService: NSObject, @unchecked Sendable {
    private var session: NFCTagReaderSession?
    private var continuation: CheckedContinuation<NFCWriteResult, Error>?
    private let guestData: GuestAccessData

    init(guestData: GuestAccessData) {
        self.guestData = guestData
    }

    @MainActor
    func writeGuestData() async throws -> NFCWriteResult {
        #if targetEnvironment(simulator)
        try await Task.sleep(for: .seconds(1.5))
        return NFCWriteResult(roomNumber: guestData.roomNumber, timestamp: Date())
        #else
        guard NFCReaderSession.readingAvailable else {
            throw NFCAccessError.nfcNotAvailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.session = NFCTagReaderSession(
                pollingOption: .iso14443,
                delegate: self,
                queue: nil
            )
            self.session?.alertMessage = "Preparing NFC..."
            self.session?.begin()
        }
        #endif
    }

    private func resumeContinuation(with result: Result<NFCWriteResult, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}

// MARK: - NFCTagReaderSessionDelegate

extension NFCService: NFCTagReaderSessionDelegate {

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        // NFC hardware is now exclusively locked by our app — Wallet/Express Mode is suspended
        session.alertMessage = "Ready! Hold your iPhone near the door reader"
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: any Error) {
        let nfcError = error as NSError

        // User cancelled (code 200)
        if nfcError.code == 200 {
            resumeContinuation(with: .failure(NFCAccessError.sessionInvalidated("Cancelled")))
            return
        }

        // System resources unavailable (Express Mode / Wallet interference)
        let desc = error.localizedDescription.lowercased()
        if desc.contains("system resource") || desc.contains("unavailable") || nfcError.code == 1 {
            resumeContinuation(with: .failure(NFCAccessError.systemBusy))
            return
        }

        // Session timeout (code 5)
        if nfcError.code == 5 {
            resumeContinuation(with: .failure(NFCAccessError.sessionInvalidated("Session timed out. Please try again.")))
            return
        }

        if continuation != nil {
            resumeContinuation(with: .failure(NFCAccessError.sessionInvalidated(error.localizedDescription)))
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag found")
            return
        }

        // Must be ISO 14443-4 (Type 4 Tag) — this is what PN532 in card-emulation mode presents
        guard case .iso7816(let iso7816Tag) = tag else {
            session.invalidate(errorMessage: "Not a compatible tag")
            resumeContinuation(with: .failure(NFCAccessError.unsupportedTag))
            return
        }

        // Step 1: Connect to tag
        session.connect(to: tag) { [self] error in
            if let error {
                session.invalidate(errorMessage: "Connection failed")
                resumeContinuation(with: .failure(NFCAccessError.tagConnectionFailed(error.localizedDescription)))
                return
            }

            // Step 2: Verify tag is writable (NFCISO7816Tag conforms to NFCNDEFTag)
            iso7816Tag.queryNDEFStatus { status, capacity, error in
                guard error == nil else {
                    session.invalidate(errorMessage: "Cannot query tag")
                    self.resumeContinuation(with: .failure(NFCAccessError.tagConnectionFailed("Query failed")))
                    return
                }

                guard status == .readWrite else {
                    session.invalidate(errorMessage: "Tag is not writable")
                    self.resumeContinuation(with: .failure(NFCAccessError.tagNotWritable))
                    return
                }

                // Step 3: Write guest access data
                let message = self.guestData.toNDEFMessage()
                iso7816Tag.writeNDEF(message) { error in
                    if let error {
                        session.invalidate(errorMessage: "Write failed")
                        self.resumeContinuation(with: .failure(NFCAccessError.writeFailed(error.localizedDescription)))
                        return
                    }

                    let result = NFCWriteResult(
                        roomNumber: self.guestData.roomNumber,
                        timestamp: Date()
                    )
                    session.alertMessage = "Access Granted"
                    session.invalidate()
                    self.resumeContinuation(with: .success(result))
                }
            }
        }
    }
}
