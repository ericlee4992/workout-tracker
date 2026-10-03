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
    @State private var attachment: FeedbackAttachment
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
        _attachment = State(initialValue: FeedbackAttachment(screenshot: initial?.screenshot))
        if let initial {
            _category = State(initialValue: initial.category)
            _message = State(initialValue: initial.message)
        }
    }

    private var trimmed: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// Not while a chosen photo is still loading: Send would go without it (codex-review-07 #1).
    private var canSend: Bool { !trimmed.isEmpty && phase == .editing && !attachment.isLoading }
    private var shownFailure: String? { failure ?? attachment.problem?.message }

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
        .interactiveDismissDisabled(phase != .sent && FeedbackDraft.blocksSwipeAway(message: message, attachment: attachment))
        .sensoryFeedback(.success, trigger: phase == .sent)
        .onChange(of: pick) { _, item in
            guard let item else { return }
            failure = nil
            attachment.select { try? await item.loadTransferable(type: Data.self) }
        }
        // A refused image clears the picker's selection, so choosing it again (or another) is a change.
        .onChange(of: attachment.problem) { _, problem in if problem != nil { pick = nil } }
    }

    // MARK: Form

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section - 4) {
                if let failure = shownFailure {
                    // Not a SettingsNotice: that sets its own (neutral) colour, and this line is a failure.
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(.footnote, weight: .bold))
                        Text(failure)
                            .font(.system(.footnote, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(look.destructive)
                    .padding(.horizontal, 4)
                    .accessibilityElement(children: .combine)
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
        if let screenshot = attachment.screenshot {
            attached(screenshot)
        } else if attachment.isLoading {
            loading
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
            Button(action: removeScreenshot) {
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

    /// While the picked photo loads (an iCloud original can take a while): Send waits; Remove cancels it.
    private var loading: some View {
        LookList(separatorInset: 54) {
            LookRow("Loading Screenshot…", symbol: "photo", showsChevron: false) {
                HStack(spacing: 12) {
                    ProgressView()
                    Button(action: removeScreenshot) {
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
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("feedbackScreenshotLoading")
    }

    private func removeScreenshot() {
        if reduceMotion { attachment.remove() } else { withAnimation(.snappy(duration: 0.25)) { attachment.remove() } }
        pick = nil
    }

    // MARK: What is sent, and to whom

    private var sentWithIt: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Sent with it")
            LookList {
                detailRow("App", details.app)
                detailRow("iOS", details.system)
                detailRow("iPhone", DeviceModelName.name(for: details.model))
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
        let draft = FeedbackDraft(category: category, message: trimmed, screenshot: attachment.screenshot)
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

    /// A swipe would lose something the tester made: text, a screenshot, or one still loading (codex-review-07 #2).
    /// Cancel still discards on purpose.
    @MainActor static func blocksSwipeAway(message: String, attachment: FeedbackAttachment) -> Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachment.screenshot != nil || attachment.isLoading
    }
}

/// The form's screenshot slot (codex-review-07 #1). A pick starts a load the form waits for; a newer pick or Remove
/// supersedes it, and a superseded load's result is dropped, so what is attached is always the latest choice.
@MainActor @Observable
final class FeedbackAttachment {
    private(set) var screenshot: FeedbackScreenshot?
    private(set) var isLoading = false
    private(set) var problem: FeedbackScreenshot.Problem?
    private var generation = 0
    private var task: Task<Void, Never>?

    init(screenshot: FeedbackScreenshot? = nil) {
        self.screenshot = screenshot
    }

    func select(_ load: @escaping @Sendable () async -> Data?) {
        task?.cancel()
        generation += 1
        let mine = generation
        screenshot = nil
        problem = nil
        isLoading = true
        task = Task {
            let data = await load()
            guard !Task.isCancelled, mine == generation else { return }
            isLoading = false
            switch data.map(FeedbackScreenshot.make) ?? .failure(.unreadable) {
            case .success(let shot): screenshot = shot
            case .failure(let reason): problem = reason
            }
        }
    }

    func remove() {
        task?.cancel()
        task = nil
        generation += 1
        screenshot = nil
        problem = nil
        isLoading = false
    }

    /// Tests: waits for the current load to finish or be dropped.
    func settle() async { await task?.value }
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
    /// The hardware identifier (for example `iPhone16,2`): sent as is, shown by its name (`DeviceModelName`).
    var model: String
    /// The signed-in account's name and email; nil signed out.
    var account: String?

    var app: String { "Stacked \(appVersion) (\(build))" }
    var system: String { systemVersion }

    /// What the form shows and sends on this phone (the account arrives with ticket 03's app half); the capture
    /// fixture's fixed values under `-uiTestReset`.
    static var forThisPhone: FeedbackDetails {
        WorkoutTrackerStore.isUITestReset ? FeedbackSample.fixed(.current()) : .current()
    }

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

// MARK: - Sending

enum FeedbackSender {
    /// Whether this build can send feedback: a server is configured, or a UI test stands in for it.
    static var isAvailable: Bool { WorkoutTrackerStore.isUITestReset || ServerConfig.baseURL != nil }

    /// The sheet's sender: the UI-test stub under `-uiTestReset` (the app cannot reach a server in tests), otherwise
    /// the server. Signed out until ticket 03's app half supplies the session.
    static func make(details: FeedbackDetails) -> (FeedbackDraft) async -> FeedbackSendResult {
        // `-uiTestRealServer`: the Simulator smoke test sends to the build's server (a local `wrangler dev`).
        if WorkoutTrackerStore.isUITestReset && !ProcessInfo.processInfo.arguments.contains("-uiTestRealServer") {
            return FeedbackSample.stubSend
        }
        guard let baseURL = ServerConfig.baseURL else {
            return { _ in .failed(FeedbackClientError.unreachable.message(signedIn: false)) }
        }
        let client = FeedbackClient(baseURL: baseURL, sessionToken: nil)
        return { draft in
            let submission = FeedbackSubmission(
                category: draft.category.rawValue, message: draft.message, appVersion: details.appVersion,
                build: details.build, systemVersion: details.systemVersion, model: details.model,
                jpeg: draft.screenshot?.data)
            do {
                try await client.send(submission)
                return .sent
            } catch {
                return .failed((error as? FeedbackClientError ?? .unreachable).message(signedIn: client.sessionToken != nil))
            }
        }
    }
}

// MARK: - UI-test and capture seams

enum FeedbackSample {
    /// `-uiTestFeedbackSample`: the form opens filled (Bug, a message, a screenshot) and signed in.
    static let filledArgument = "-uiTestFeedbackSample"

    static var isFilled: Bool { WorkoutTrackerStore.isUITestReset && ProcessInfo.processInfo.arguments.contains(filledArgument) }

    /// The capture fixture's details: fixed, so captures do not change with the build machine; signed in when filled.
    static func fixed(_ details: FeedbackDetails) -> FeedbackDetails {
        var details = details
        details.account = isFilled ? "Alex Kim · alex@example.com" : nil
        details.appVersion = "0.1.0"
        details.build = "1"
        details.systemVersion = "27.0"
        details.model = "iPhone16,2"
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
    FeedbackSheet(details: FeedbackSample.fixed(.current()), send: FeedbackSample.stubSend)
}
