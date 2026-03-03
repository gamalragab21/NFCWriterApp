@preconcurrency import CoreNFC
import Foundation

nonisolated enum NFCAccessError: LocalizedError, Sendable {
    case nfcNotAvailable
    case sessionInvalidated(String)
    case writeFailed(String)
    case tagConnectionFailed(String)
    case tagNotWritable

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
        }
    }
}

nonisolated struct NFCWriteResult: Sendable {
    let roomNumber: String
    let timestamp: Date
}

nonisolated final class NFCService: NSObject, @unchecked Sendable {
    private var session: NFCNDEFReaderSession?
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
        guard NFCNDEFReaderSession.readingAvailable else {
            throw NFCAccessError.nfcNotAvailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.session = NFCNDEFReaderSession(
                delegate: self,
                queue: nil,
                invalidateAfterFirstRead: false
            )
            self.session?.alertMessage = "Hold your iPhone near the door reader"
            self.session?.begin()
        }
        #endif
    }

    private func resumeContinuation(with result: Result<NFCWriteResult, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}

// MARK: - NFCNDEFReaderSessionDelegate

extension NFCService: NFCNDEFReaderSessionDelegate {

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {}

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: any Error) {
        let nfcError = error as NSError
        if nfcError.domain == "NFCError" && nfcError.code == 200 {
            resumeContinuation(with: .failure(NFCAccessError.sessionInvalidated("Cancelled")))
            return
        }
        if continuation != nil {
            resumeContinuation(with: .failure(NFCAccessError.sessionInvalidated(error.localizedDescription)))
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {}

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [any NFCNDEFTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag found")
            return
        }

        // Step 1: Connect to tag
        session.connect(to: tag) { [self] error in
            if let error {
                session.invalidate(errorMessage: "Connection failed")
                resumeContinuation(with: .failure(NFCAccessError.tagConnectionFailed(error.localizedDescription)))
                return
            }

            // Step 2: Verify tag is writable
            tag.queryNDEFStatus { status, capacity, error in
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
                tag.writeNDEF(message) { error in
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
