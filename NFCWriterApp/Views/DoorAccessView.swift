import SwiftUI

struct DoorAccessView: View {
    @Bindable var viewModel: DoorAccessViewModel
    @State private var showingForm = false
    @State private var pulseAnimation = false

    var body: some View {
        ZStack {
            // Background
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Room card at top
                roomCard
                    .padding(.horizontal)
                    .padding(.top, 8)

                Spacer()

                // Big NFC button in center
                nfcButton

                Spacer()

                // Steps guide + recent log
                bottomSection
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
        .navigationTitle("Room Access")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                nfcStatusBadge
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        showingForm = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                    }

                    NavigationLink {
                        AccessLogView(
                            entries: viewModel.accessLog,
                            onClear: { viewModel.clearHistory() }
                        )
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            GuestDataFormSheet(viewModel: viewModel)
        }
    }

    // MARK: - NFC Status Badge

    private var nfcStatusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(viewModel.isNFCAvailable ? .green : .red)
                .frame(width: 8, height: 8)
            Text(viewModel.isNFCAvailable ? "NFC Ready" : "No NFC")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Room Card

    private var roomCard: some View {
        VStack(spacing: 0) {
            if viewModel.hasGuestData {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ROOM")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .tracking(2)
                        Text(viewModel.roomNumber)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        Label(viewModel.checkIn, systemImage: "arrow.right.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                        Label(viewModel.checkOut, systemImage: "arrow.left.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(.top, 4)
                }
                .padding(20)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.1, green: 0.2, blue: 0.45), Color(red: 0.15, green: 0.3, blue: 0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
            } else {
                Button {
                    showingForm = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Set Up Room Access")
                                .font(.headline)
                            Text("Enter your guest details to get started")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - NFC Button

    private var nfcButton: some View {
        VStack(spacing: 20) {
            Button {
                Task { await viewModel.startDoorAccess() }
            } label: {
                ZStack {
                    // Outer pulse rings
                    if isScanning {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .stroke(Color.cyan.opacity(0.3 - Double(i) * 0.1), lineWidth: 2)
                                .frame(width: CGFloat(200 + i * 40), height: CGFloat(200 + i * 40))
                                .scaleEffect(pulseAnimation ? 1.1 : 0.9)
                                .opacity(pulseAnimation ? 0 : 0.8)
                                .animation(
                                    .easeInOut(duration: 1.5)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(i) * 0.3),
                                    value: pulseAnimation
                                )
                        }
                    }

                    // Main button circle
                    Circle()
                        .fill(buttonGradient)
                        .frame(width: 180, height: 180)
                        .shadow(color: buttonShadow, radius: isScanning ? 25 : 12, y: 4)

                    // Icon + text inside circle
                    VStack(spacing: 8) {
                        Image(systemName: buttonIcon)
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(.white)
                            .symbolEffect(.variableColor.iterative, isActive: isScanning)

                        Text(buttonLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .tracking(1)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.isNFCAvailable || isScanning || !viewModel.hasGuestData)
            .onChange(of: viewModel.accessState) {
                if isScanning {
                    pulseAnimation = true
                } else {
                    pulseAnimation = false
                }
            }

            // Status text below button
            Text(statusMessage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(statusColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .animation(.easeInOut(duration: 0.3), value: viewModel.accessState)
        }
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 12) {
            // How-to steps (only when idle and has data)
            if case .idle = viewModel.accessState, viewModel.hasGuestData {
                VStack(alignment: .leading, spacing: 10) {
                    StepRow(number: "1", text: "Tap the unlock button above")
                    StepRow(number: "2", text: "Hold iPhone near the door reader")
                    StepRow(number: "3", text: "Wait for \"Access Granted\" confirmation")
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            // Recent log preview
            if !viewModel.accessLog.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(1)

                    ForEach(viewModel.accessLog.prefix(2)) { entry in
                        HStack(spacing: 10) {
                            Image(systemName: entry.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(entry.success ? .green : .red)
                            Text(entry.doorID)
                                .font(.subheadline)
                            Spacer()
                            Text(entry.timestamp, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Computed

    private var isScanning: Bool { viewModel.accessState == .scanning }

    private var buttonIcon: String {
        switch viewModel.accessState {
        case .idle: return "wave.3.right"
        case .scanning: return "wave.3.right"
        case .success: return "lock.open.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private var buttonLabel: String {
        switch viewModel.accessState {
        case .idle: return viewModel.hasGuestData ? "UNLOCK" : "SET UP"
        case .scanning: return "SCANNING"
        case .success: return "UNLOCKED"
        case .error: return "RETRY"
        }
    }

    private var statusMessage: String {
        switch viewModel.accessState {
        case .idle:
            return viewModel.hasGuestData ? "Tap to unlock your room" : "Set up your guest details first"
        case .scanning:
            return "Hold your iPhone near the door reader..."
        case .success(let room):
            return "Room \(room) unlocked successfully"
        case .error(let msg):
            return msg
        }
    }

    private var statusColor: Color {
        switch viewModel.accessState {
        case .idle: return .secondary
        case .scanning: return .blue
        case .success: return .green
        case .error: return .red
        }
    }

    private var buttonGradient: LinearGradient {
        switch viewModel.accessState {
        case .idle:
            let c: Color = viewModel.hasGuestData ? .blue : .gray
            return LinearGradient(colors: [c, c.opacity(0.75)], startPoint: .top, endPoint: .bottom)
        case .scanning:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom)
        case .success:
            return LinearGradient(colors: [.green, Color(red: 0.2, green: 0.7, blue: 0.3)], startPoint: .top, endPoint: .bottom)
        case .error:
            return LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)
        }
    }

    private var buttonShadow: Color {
        switch viewModel.accessState {
        case .idle: return .blue.opacity(0.25)
        case .scanning: return .cyan.opacity(0.4)
        case .success: return .green.opacity(0.4)
        case .error: return .red.opacity(0.25)
        }
    }
}

// MARK: - Step Row

private struct StepRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.blue, in: Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Guest Data Form Sheet

private struct GuestDataFormSheet: View {
    @Bindable var viewModel: DoorAccessViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var saved = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "key.horizontal.fill")
                            .foregroundStyle(.orange)
                            .frame(width: 28)
                        TextField("e.g. A1B2C3D4E5F6G7H8", text: $viewModel.masterKey)
                    }
                } header: {
                    Text("Master Key")
                } footer: {
                    Text("16-character key assigned at check-in")
                }

                Section("Room") {
                    HStack {
                        Image(systemName: "door.left.hand.closed")
                            .foregroundStyle(.blue)
                            .frame(width: 28)
                        TextField("e.g. 101", text: $viewModel.roomNumber)
                            .keyboardType(.numberPad)
                    }
                }

                Section {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundStyle(.green)
                            .frame(width: 28)
                        TextField("yyyy-MM-dd HH:mm", text: $viewModel.checkIn)
                    }
                    HStack {
                        Image(systemName: "calendar.badge.minus")
                            .foregroundStyle(.red)
                            .frame(width: 28)
                        TextField("yyyy-MM-dd HH:mm", text: $viewModel.checkOut)
                    }
                } header: {
                    Text("Stay Period")
                }

                Section {
                    Button {
                        viewModel.saveGuestData()
                        saved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if saved {
                                Label("Saved", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Text("Save Guest Data")
                            }
                            Spacer()
                        }
                        .font(.headline)
                    }
                    .disabled(!viewModel.hasGuestData)
                }
            }
            .navigationTitle("Guest Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
