import SwiftUI

struct AccessLogView: View {
    let entries: [AccessLogEntry]
    var onClear: (() -> Void)?

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No Access History",
                    systemImage: "door.left.hand.open",
                    description: Text("Your room access attempts will appear here after you use NFC to unlock a door.")
                )
            } else {
                List {
                    ForEach(entries) { entry in
                        HStack(spacing: 14) {
                            // Status icon
                            ZStack {
                                Circle()
                                    .fill(entry.success ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                Image(systemName: entry.success ? "lock.open.fill" : "lock.slash.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(entry.success ? .green : .red)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.doorID)
                                    .font(.body.weight(.medium))

                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.caption2)
                                    Text(entry.timestamp, format: .dateTime.month(.abbreviated).day().hour().minute())
                                        .font(.caption)
                                }
                                .foregroundStyle(.secondary)

                                if let err = entry.errorMessage {
                                    Text(err)
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                        .lineLimit(2)
                                }
                            }

                            Spacer()

                            Text(entry.success ? "Opened" : "Failed")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(entry.success ? .green : .red)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    (entry.success ? Color.green : Color.red).opacity(0.1),
                                    in: Capsule()
                                )
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Access History")
        .toolbar {
            if !entries.isEmpty, let onClear {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear All", role: .destructive) {
                        onClear()
                    }
                    .font(.subheadline)
                }
            }
        }
    }
}
