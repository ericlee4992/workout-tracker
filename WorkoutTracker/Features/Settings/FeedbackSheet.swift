import PhotosUI
import SwiftUI

/// Public beta ticket 07: Settings → Help → Send Feedback. A compose sheet: the category, the message (the bold
/// element — the largest block, first under the category), an optional screenshot, and everything else that is sent,
/// shown before sending, with the one line saying where it goes. Send is the one filled command (in the header, as in
/// every staged-edit sheet) and needs a message. Sent replaces the form with a confirmation and Done.
///
/// UI-first stage: the form runs on `FeedbackDetails` and a sender; the server client arrives with the wiring.
struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var details: FeedbackDetails
    var send: (FeedbackDraft) async -> FeedbackSendResult

    @State private var category = FeedbackCategory.bug
    @State private var message = ""
    @State private var screenshot: FeedbackScreenshot?
    @State private var pick: PhotosPickerItem?
    @State private var phase = Phase.editing
    @State private var failure: String?
    @FocusState private var messageFocused: Bool
    @ScaledMetric(relativeTo: .body) private var messageHeight: CGFloat = 168
    @ScaledMetric(relativeTo: .body) private var thumbnailHeight: CGFloat = 96

    private enum Phase { case editing, sending, sent }

    init(details: FeedbackDetails, initial: FeedbackDraft? = nil,
         send: @escaping (FeedbackDraft) async -> FeedbackSendResult) {
        self.details = details
        self.send = send
        if let initial {
            _category = State(initialValue: initial.category)
            _message = State(initialValue: initial.message)
            _screenshot = State(initialValue: initial.screenshot)
        }
    }

    private var trimmed: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSend: Bool { !trimmed.isEmpty && phase == .editing }

    var body: some View {
        VStack(spacing: 0) {
            if phase == .sent {
                sentHeader
                sentBody
            } else {
                SheetHeader(cancel: { dismiss() }, title: "Feedback", commit: submit,
                            commitTitle: phase == .sending ? "Sending…" : "Send", commitEnabled: canSend,
                            commitIdentifier: "feedbackSend", reflowsTitle: true)
                form
            }
        }
        .lookSheetGround()
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(!trimmed.isEmpty && phase != .sent)
        .sensoryFeedback(.success, trigger: phase == .sent)
        .onChange(of: pick) { _, item in load(item) }
    }

    // MARK: Form

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section - 4) {
                if let failure {
                    SettingsNotice(symbol: "exclamationmark.triangle.fill", text: failure, emphasized: true)
                        .foregroundStyle(look.destructive)
                        .accessibilityIdentifier("feedbackFailure")
                }
                SegmentedPills(FeedbackCategory.allCases.map(\.label), selection: Binding(
                    get: { FeedbackCategory.allCases.firstIndex(of: category) ?? 0 },
                    set: { category = FeedbackCategory.allCases[$0] }))
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Category")
                    .accessibilityIdentifier("feedbackCategory")
                messageField
                screenshotBlock
                sentWithIt
            }
            .disabled(phase == .sending)
            .padding(.horizontal, look.space.margin)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Message (the bold element)

    private var messageField: some View {
        VStack(alignment: .trailing, spacing: 6) {
            TextEditor(text: $message)
                .font(look.font.body)
                .foregroundStyle(look.textPrimary)
                .tint(look.actionText)
                .scrollContentBackground(.hidden)
                .focused($messageFocused)
                .frame(minHeight: messageHeight)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .overlay(alignment: .topLeading) {
                    if message.isEmpty {
                        Text("What happened, or what would you change?")
                            .font(look.font.body)
                            .foregroundStyle(look.textSecondary)
                            .padding(.horizontal, 17)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .lookSurface(.tile)
                .accessibilityLabel("Message")
                .accessibilityHint("Required")
                .accessibilityIdentifier("feedbackMessage")
                .onChange(of: message) { _, text in
                    if text.count > FeedbackDraft.maxMessageLength {
                        message = String(text.prefix(FeedbackDraft.maxMessageLength))
                    }
                }
            // Only near the limit: a counter from the first keystroke is noise for a two-line note.
            if message.count >= FeedbackDraft.counterThreshold {
                Text("\(message.count.formatted()) of \(FeedbackDraft.maxMessageLength.formatted())")
                    .font(look.font.footnote)
                    .monospacedDigit()
                    .foregroundStyle(message.count >= FeedbackDraft.maxMessageLength ? look.destructive : look.textSecondary)
                    .padding(.trailing, 4)
                    .accessibilityIdentifier("feedbackCount")
            }
        }
    }

    // MARK: Screenshot

    @ViewBuilder private var screenshotBlock: some View {
        if let screenshot {
            attached(screenshot)
        } else {
            LookList(separatorInset: 54) {
                PhotosPicker(selection: $pick, matching: .images, photoLibrary: .shared()) {
                    LookRow("Add Screenshot", symbol: "photo.badge.plus", showsChevron: false) { EmptyView() }
                }
                .buttonStyle(.lookPressable)
                .accessibilityIdentifier("feedbackAddScreenshot")
            }
        }
    }

    private func attached(_ shot: FeedbackScreenshot) -> some View {
        let ax = typeSize.isAccessibilitySize
        let layout = ax ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
        return layout {
            Image(uiImage: shot.preview)
                .resizable()
                .scaledToFit()
                .frame(height: thumbnailHeight)
                .clipShape(RoundedRectangle(cornerRadius: look.radius.field, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: look.radius.field, style: .continuous)
                        .strokeBorder(look.hairline, lineWidth: 1)
                }
                .accessibilityLabel("Attached screenshot")
            VStack(alignment: .leading, spacing: 3) {
                Text("Screenshot")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(look.textPrimary)
                Text(shot.summary)
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !ax { Spacer(minLength: 0) }
            Button {
                if reduceMotion { screenshot = nil } else { withAnimation(.snappy(duration: 0.25)) { screenshot = nil } }
                pick = nil
            } label: {
                Text("Remove")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(look.destructive)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove screenshot")
            .accessibilityIdentifier("feedbackRemoveScreenshot")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.tile)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("feedbackScreenshot")
    }

    // MARK: What is sent, and to whom

    private var sentWithIt: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Sent with it")
            LookList {
                detailRow("App", details.app)
                detailRow("iOS", details.system)
                detailRow("iPhone", details.model)
                detailRow("Account", details.account ?? "Not signed in")
            }
            .accessibilityIdentifier("feedbackDetails")
            SettingsNotice(symbol: "lock.fill", text: "Goes only to Stacked's developer.")
                .padding(.top, 2)
                .accessibilityIdentifier("feedbackRecipient")
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        let ax = typeSize.isAccessibilitySize
        let layout = ax ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Text(label)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(look.textSecondary)
            if !ax { Spacer(minLength: 8) }
            Text(value)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(look.textPrimary)
                .multilineTextAlignment(ax ? .leading : .trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Sent

    private var sentHeader: some View {
        HStack {
            Spacer()
            GlassCapsuleButton("Done") { dismiss() }
                .accessibilityIdentifier("feedbackDone")
        }
        .padding(.horizontal, look.space.margin)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    /// Centred: the confirmation is the whole sheet's content, and Done is the only way on.
    private var sentBody: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            Image(systemName: "checkmark")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(look.textPrimary)
                .frame(width: 72, height: 72)
                .background(look.surface, in: Circle())
                .overlay { Circle().strokeBorder(look.hairline, lineWidth: 1) }
                .accessibilityHidden(true)
            Text("Sent")
                .font(look.font.largeTitle)
                .foregroundStyle(look.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Thanks — every message is read.")
                .font(look.font.body)
                .foregroundStyle(look.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, look.space.margin)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("feedbackSent")
        .transition(.opacity)
    }

    // MARK: Actions

    private func submit() {
        guard canSend else { return }
        messageFocused = false
        failure = nil
        phase = .sending
        let draft = FeedbackDraft(category: category, message: trimmed, screenshot: screenshot)
        Task {
            let result = await send(draft)
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                switch result {
                case .sent: phase = .sent
                case .failed(let reason):
                    failure = reason
                    phase = .editing
                }
            }
        }
    }

    private func load(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                failure = "Couldn't read that image. Try another."
                return
            }
            switch FeedbackScreenshot.make(from: data) {
            case .success(let shot):
                failure = nil
                if reduceMotion { screenshot = shot } else { withAnimation(.snappy(duration: 0.25)) { screenshot = shot } }
            case .failure(let problem):
                failure = problem.message
                pick = nil
            }
        }
    }
}

// MARK: - Model

enum FeedbackCategory: String, CaseIterable {
    case bug, idea, other

    var label: String {
        switch self {
        case .bug: "Bug"
        case .idea: "Idea"
        case .other: "Other"
        }
    }
}

struct FeedbackDraft {
    static let maxMessageLength = 4_000
    static let counterThreshold = 3_500
    var category: FeedbackCategory
    var message: String
    var screenshot: FeedbackScreenshot?
}

enum FeedbackSendResult: Equatable {
    case sent
    case failed(String)
}

/// Everything sent besides the message and the screenshot, exactly as shown on the form.
struct FeedbackDetails: Equatable {
    var appVersion: String
    var build: String
    var systemVersion: String
    /// The hardware identifier (for example `iPhone16,2`), shown as sent rather than translated.
    var model: String
    /// The signed-in account's name and email; nil signed out.
    var account: String?

    var app: String { "Stacked \(appVersion) (\(build))" }
    var system: String { systemVersion }

    static func current(account: String? = nil) -> FeedbackDetails {
        let info = Bundle.main.infoDictionary ?? [:]
        return FeedbackDetails(
            appVersion: info["CFBundleShortVersionString"] as? String ?? "?",
            build: info["CFBundleVersion"] as? String ?? "?",
            systemVersion: UIDevice.current.systemVersion,
            model: hardwareModel(),
            account: account)
    }

    static func hardwareModel() -> String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return simulated }
        var system = utsname()
        uname(&system)
        return withUnsafeBytes(of: &system.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}

/// The screenshot as it will be sent: re-encoded, so the photo's location and camera details are not (D56's rule for
/// photos sent to OpenAI applies here too).
struct FeedbackScreenshot {
    static let maxBytes = 5 * 1024 * 1024
    var data: Data
    var preview: UIImage

    var summary: String {
        "JPEG · \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)) · photo details removed"
    }

    enum Problem: Error {
        case unreadable, tooLarge
        var message: String {
            switch self {
            case .unreadable: "Couldn't read that image. Try another."
            case .tooLarge: "That image is too large to send. Try a screenshot."
            }
        }
    }

    /// Decodes and re-encodes as JPEG (no metadata), stepping the quality down to stay under the server's 5 MB cap.
    static func make(from original: Data) -> Result<FeedbackScreenshot, Problem> {
        guard let image = UIImage(data: original) else { return .failure(.unreadable) }
        for quality in [0.85, 0.7, 0.5] {
            if let jpeg = image.jpegData(compressionQuality: quality), jpeg.count <= maxBytes {
                return .success(FeedbackScreenshot(data: jpeg, preview: image))
            }
        }
        return .failure(.tooLarge)
    }
}

// MARK: - UI-test and capture seams

enum FeedbackSample {
    /// `-uiTestFeedbackSample`: the form opens filled (Bug, a message, a screenshot) and signed in.
    static let filledArgument = "-uiTestFeedbackSample"

    static var isFilled: Bool { WorkoutTrackerStore.isUITestReset && ProcessInfo.processInfo.arguments.contains(filledArgument) }

    static var details: FeedbackDetails {
        var details = FeedbackDetails.current(account: isFilled ? "Alex Kim · alex@example.com" : nil)
        if WorkoutTrackerStore.isUITestReset {
            // Fixed values, so captures do not change with the build machine.
            details.appVersion = "0.1.0"
            details.build = "1"
            details.systemVersion = "27.0"
            details.model = "iPhone16,2"
        }
        return details
    }

    static var draft: FeedbackDraft? {
        guard isFilled else { return nil }
        let shot = FeedbackScreenshot.make(from: sampleImage().pngData() ?? Data())
        return FeedbackDraft(
            category: .bug,
            message: "The rest timer kept counting after I finished the workout. It showed 3:10 on the Lock Screen "
                + "until I opened the app again.",
            screenshot: try? shot.get())
    }

    /// A stand-in screenshot drawn from the palette (no asset, no user data).
    private static func sampleImage() -> UIImage {
        let size = CGSize(width: 390, height: 844)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.024, green: 0.027, blue: 0.031, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.094, green: 0.102, blue: 0.118, alpha: 1).setFill()
            for row in 0..<5 {
                UIBezierPath(roundedRect: CGRect(x: 20, y: 140 + CGFloat(row) * 96, width: 350, height: 80),
                             cornerRadius: 16).fill()
            }
            UIColor(red: 0.698, green: 0.361, blue: 1, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 20, y: 740, width: 350, height: 56), cornerRadius: 28).fill()
            UIColor(white: 0.96, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 20, y: 70, width: 180, height: 34), cornerRadius: 8).fill()
        }
    }

    /// Under `-uiTestReset` the app cannot reach a server: a short pause, then sent (or `-uiTestFeedbackFail`).
    static func stubSend(_ draft: FeedbackDraft) async -> FeedbackSendResult {
        try? await Task.sleep(for: .milliseconds(400))
        if ProcessInfo.processInfo.arguments.contains("-uiTestFeedbackFail") {
            return .failed("Couldn't send. Check your connection and try again.")
        }
        return .sent
    }
}

#Preview("Empty") {
    FeedbackSheet(details: FeedbackSample.details, send: FeedbackSample.stubSend)
}
