import SwiftData
import SwiftUI

/// Soft redesign S6: the Profile tab's root, laid out like the approved prototype (`SoftProfileScreen`, tag
/// `design/soft-approved-2026-11-07`) and grouped as the user chose (D80): the account card, **Goals & tracking** (what
/// you track — Heart rate zones now; N3 adds Nutrition goals, N9 Body weight and Apple Health), **Settings** (what you
/// set once — Preferences, Ask AI, Export & backup; N3 adds Personal details), then Help and the app's version. Every
/// setting that sat inline on the old page (`SettingsView` before S6) is one tap further.
struct ProfileTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query private var allPreferences: [AppPreferences]
    @Query private var nutritionGoals: [NutritionGoal]
    /// Public beta ticket 02: Show Tour starts the guided tour (absent in previews and the tour's own world).
    @Environment(OnboardingCoordinator.self) private var onboarding: OnboardingCoordinator?
    @Environment(AccountStore.self) private var account
    @AppStorage(ExportRecord.dateKey) private var lastExportSeconds: Double?
    /// N1: a failed restore is said here too, not only one level down on Export & backup.
    @AppStorage(StoreGate.restoreFailureKey) private var restoreFailure: String?

    @State private var showSettings = false
    @State private var showNutritionGoals = false
    @State private var showPersonalDetails = false
    @State private var showExportBackup = false
    @State private var showMaxHeartRateSheet = false
    @State private var showAskAISheet = false
    @State private var showFeedback = false
    @State private var showWhatsNew = false
    @State private var showProfile = false
    @State private var showSignIn = false
    @State private var showAppleStep = false
    @State private var deletionSignedOut = false
    @State private var titleVisible = false

    private let title = "Profile"

    private var preferences: AppPreferences? { AppPreferences.canonical(of: allPreferences) }

    private var unitSystem: AppUnitSystem {
        AppUnitSystem.resolve(preference: preferences?.unitPreference)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                LookNavTitle(title)
                    .tourAnchor("tour.settings")
                // Public beta tickets 05/03: the account — shown when this build has a server (or a sample flag).
                if account.isAvailable {
                    SettingsAccountRow(profile: account.profile, signedIn: account.isSignedIn) {
                        if account.isSignedIn {
                            // The page works without a loaded profile too: Try Again and Sign Out (offline at launch).
                            showProfile = true
                        } else {
                            showSignIn = true
                        }
                    }
                }
                goalsAndTracking
                settings
                help
                Text("Version \(WorkoutTrackerStore.appVersion)")
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityIdentifier("profileVersion")
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 2)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top > (typeSize.isAccessibilitySize ? 90 : 52)
        } action: { _, past in
            withAnimation(.easeInOut(duration: 0.18)) { titleVisible = past }
        }
        .lookScreenBackground()
        .exercisesInlineTitle(title, visible: titleVisible)
        .navigationDestination(isPresented: $showSettings) { SettingsView(title: SettingsView.pageTitle) }
        .navigationDestination(isPresented: $showNutritionGoals) { NutritionGoalsView() }
        .navigationDestination(isPresented: $showPersonalDetails) { PersonalDetailsView() }
        .navigationDestination(isPresented: $showExportBackup) { ExportBackupView() }
        .sheet(isPresented: $showMaxHeartRateSheet) { MaxHeartRateSheet() }
        .sheet(isPresented: $showAskAISheet) { AskAISettingsSheet() }
        .navigationDestination(isPresented: $showProfile) {
            ProfileScreen(usCustomary: unitSystem == .usCustomary) { outcome in
                switch outcome {
                case .deletedNeedsAppleStep: showAppleStep = true
                case .signedOut: deletionSignedOut = true
                default: break
                }
            }
        }
        .sheet(isPresented: $showSignIn) { AccountSignInSheet() }
        .alert(AccountDeletionCopy.doneTitle, isPresented: $showAppleStep) {
            Button("OK") {}
        } message: {
            Text(AccountDeletionCopy.stopUsingApple)
        }
        // Shown here, not on the page: the page closes when the session ends (codex-review-03-app #5).
        .alert(AccountDeletionCopy.signedOut, isPresented: $deletionSignedOut) {
            Button("OK") {}
        }
        .sheet(isPresented: $showFeedback) {
            // Rebuilt on every change of the account: the footer and the session sent always agree (codex-review-03-app
            // #1); a refused session signs out and the form, its draft kept, then says "Not signed in" (#2).
            let details = FeedbackDetails.forThisPhone(account: account.feedbackAccountLine)
            FeedbackSheet(details: details, initial: FeedbackSample.draft,
                          send: FeedbackSender.make(details: details, sessionToken: account.token,
                                                    onUnauthorized: { account.invalidate(token: $0) }))
        }
    }

    // MARK: Settings

    /// The maximum the zones are computed against right now (measured, else 220−age); D52.
    private var maxHeartRate: Int? {
        MaxHeartRateResolver.resolve(
            measured: preferences?.measuredMaxHeartRate, birthDate: preferences?.birthDate, at: .now)?.bpm
    }

    private var nutritionGoalValue: String {
        guard let goal = nutritionGoals.max(by: {
            ($0.effectiveFrom, $0.createdAt, $0.id.uuidString) < ($1.effectiveFrom, $1.createdAt, $1.id.uuidString)
        }) else { return "Not set" }
        return "\(goal.calories.formatted(.number.precision(.fractionLength(0)))) cal"
    }

    /// One status — On, Sign In or Paused (ticket 06: AI runs on the server, signed in, D60).
    private var askAIStatus: String {
        guard TerraAccess.ready(account) else { return "Sign In" }
        return account.profile?.aiPaused == true ? "Paused" : "On"
    }

    private var showsOnlyCopyNotice: Bool {
        BackupStatus.showsOnlyCopyNotice(
            lastExport: lastExportSeconds.map(Date.init(timeIntervalSinceReferenceDate:)), now: .now)
    }

    /// What the user tracks (D80). N3 adds Nutrition goals above Heart rate zones; N9 Body weight and Apple Health.
    private var goalsAndTracking: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Goals & tracking")
            LookList(separatorInset: 54) {
                // N3: the goal in force, or Not set until Personal details make one.
                ProfileRow("Nutrition goals", symbol: "scope", value: nutritionGoalValue) { showNutritionGoals = true }
                    .accessibilityIdentifier("profileNutritionGoals")
                let max = maxHeartRate
                ProfileRow("Heart rate zones", symbol: "heart", value: max.map { "\($0) bpm" } ?? "Not set") {
                    showMaxHeartRateSheet = true
                }
                .accessibilityIdentifier("heartRateZonesSettings")
            }
        }
    }

    /// What the user sets once (D80). N3 adds Personal details at the top.
    private var settings: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Settings")
            LookList(separatorInset: 54) {
                // N3 (D80): the one place for weight, height, date of birth and sex.
                ProfileRow("Personal details", symbol: "person.text.rectangle") { showPersonalDetails = true }
                    .accessibilityIdentifier("profilePersonalDetails")
                ProfileRow(SettingsView.pageTitle, symbol: "slider.horizontal.3") { showSettings = true }
                    .accessibilityIdentifier("profileSettings")
                ProfileRow("Ask AI", symbol: "sparkles", value: askAIStatus) { showAskAISheet = true }
                    .accessibilityIdentifier("askAISettings")
                // The one line the old Export section had to keep saying (codex-review 06) rides on the row.
                ProfileRow("Export & backup", symbol: "square.and.arrow.up",
                           subtitle: showsOnlyCopyNotice ? "This phone holds the only copy until you export." : nil) {
                    showExportBackup = true
                }
                .accessibilityIdentifier("profileExportBackup")
            }
            if let restoreFailure {
                SettingsNotice(symbol: "exclamationmark.triangle", text: SafetyCopyCopy.restoreFailed(restoreFailure))
                    .padding(.top, 2)
                    .accessibilityIdentifier("profileRestoreFailed")
            }
        }
    }

    // MARK: Help

    /// Public beta ticket 02: the guided tour again, any time (not while a workout runs — it explains why).
    /// Ticket 07: Send Feedback (works signed out). Neither row may exist (a preview without a server): no group then.
    @ViewBuilder private var help: some View {
        if onboarding != nil || FeedbackSender.isAvailable || WhatsNew.latest != nil {
            VStack(alignment: .leading, spacing: look.space.header) {
                SectionHeader("Help")
                LookList(separatorInset: 54) {
                    if let onboarding {
                        ProfileRow("Show Tour", symbol: "map") { onboarding.startTour(realContext: modelContext) }
                            .accessibilityIdentifier("showTour")
                    }
                    // Public beta ticket 14: the latest What's New again (the user's choice: readable from Settings).
                    if WhatsNew.latest != nil {
                        ProfileRow("What's New", symbol: "newspaper") { showWhatsNew = true }
                            .accessibilityIdentifier("settingsWhatsNew")
                    }
                    // Hidden in a build without a server (WT_SERVER_URL blank) rather than failing on Send.
                    if FeedbackSender.isAvailable {
                        ProfileRow("Send Feedback", symbol: "bubble.left.and.text.bubble.right") { showFeedback = true }
                            .accessibilityIdentifier("sendFeedback")
                    }
                }
            }
            .sheet(isPresented: $showWhatsNew) {
                if let latest = WhatsNew.latest { WhatsNewSheet(entry: latest) }
            }
            .alert(onboarding?.tourFailure ?? "", isPresented: Binding(
                get: { onboarding?.tourFailure != nil }, set: { if !$0 { onboarding?.tourFailure = nil } })) {
                Button("OK", role: .cancel) {}
            }
        }
    }
}

/// A Profile row: glyph, title, an optional value, chevron. At accessibility sizes the value moves under the title so
/// neither truncates (ios-design: rows stack trailing accessories under the text).
struct ProfileRow: View {
    var title: String
    var symbol: String
    var value: String?
    var subtitle: String?
    /// nil when the row is another control's label (a `Menu`), which is then the button.
    var action: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var typeSize

    init(_ title: String, symbol: String, value: String? = nil, subtitle: String? = nil,
         action: (() -> Void)?) {
        self.title = title
        self.symbol = symbol
        self.value = value
        self.subtitle = subtitle
        self.action = action
    }

    var body: some View {
        let stacked = typeSize.isAccessibilitySize
        let lines = [stacked ? value : nil, subtitle].compactMap { $0 }
        LookRow(title, subtitle: lines.isEmpty ? nil : lines.joined(separator: "\n"), symbol: symbol,
                value: stacked ? nil : value, action: action)
            // One element read as "Ask AI, Sign In" (the old cards' labels), never the glyph's name.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel([title, value, subtitle].compactMap { $0 }.joined(separator: ", "))
            .accessibilityAddTraits(.isButton)
    }
}
