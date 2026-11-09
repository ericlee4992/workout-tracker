import SwiftUI

// Nutrition N1: the safety copy's three moments on screen — a copy that failed before an update changed the data
// (launch), the restore row and its confirmation (Settings), and the wait for the next launch after choosing restore.

/// Every string the user reads about the safety copy (the user approves the wording; ticket N1).
enum SafetyCopyCopy {
    static let failedTitle = "Couldn't save a safety copy"
    static let failedLines = [
        "This update changes how Stacked stores your data. It saves a copy on this iPhone first — that didn't work.",
        "Your data hasn't been changed.",
    ]
    static let tryAgain = "Try Again"
    static let blockedTitle = "Couldn't finish the restore"
    static let blockedLines = [
        "Stacked couldn't finish restoring your data.",
        "It won't open your data until this is sorted out, so nothing gets mixed up.",
    ]
    static func cancelFailed(_ reason: String) -> String { "Couldn't cancel the restore: \(reason)" }
    static let continueWithout = "Continue Without a Copy"

    static let sectionTitle = "Safety copy"
    static let restoreRow = "Restore data from before the update"
    static func restoreRowSubtitle(_ date: Date) -> String { "Copy from \(date.formatted(date: .abbreviated, time: .shortened))" }
    static func confirmTitle(_ date: Date) -> String { "Restore data from \(date.formatted(date: .abbreviated, time: .omitted))?" }
    static let confirmMessage = "Your data goes back to how it was before the update. Anything logged since then is removed."
    static let confirmButton = "Restore"
    static func restoreFailed(_ reason: String) -> String { "The restore didn't work: \(reason) Your data is unchanged." }

    static let pendingTitle = "Close Stacked to finish"
    static func pendingMessage(_ date: Date) -> String {
        "Your data from \(date.formatted(date: .abbreviated, time: .omitted)) comes back the next time you open Stacked."
    }
    static let cancelRestore = "Cancel Restore"

    static let restoredTitle = "Data restored"
    static func restoredMessage(_ date: Date) -> String {
        "Your data is back to how it was on \(date.formatted(date: .abbreviated, time: .omitted))."
    }
}

/// Launch, the copy failed: the user's data is still closed and unchanged. The eye lands on the title; the thumb on
/// Try Again (the one filled command); Continue Without a Copy is the quiet second.
struct SafetyCopyFailedView: View {
    var title = SafetyCopyCopy.failedTitle
    var lines = SafetyCopyCopy.failedLines
    let reason: String
    let onTryAgain: () -> Void
    /// nil: Try Again only (an unfinished restore must not open the store).
    let onContinue: (() -> Void)?
    @Environment(\.look) private var look

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    Text(title)
                        .font(look.font.largeTitle)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 40)
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(lines, id: \.self) { line in
                            Text(line)
                                .font(look.font.body)
                                .foregroundStyle(look.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !reason.isEmpty {
                            Text(reason)
                                .font(look.font.footnote)
                                .foregroundStyle(look.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("safetyCopyFailureReason")
                        }
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(spacing: 10) {
                Button(SafetyCopyCopy.tryAgain, action: onTryAgain)
                    .buttonStyle(.lookPrimary)
                    .accessibilityIdentifier("safetyCopyTryAgain")
                if let onContinue {
                    Button(SafetyCopyCopy.continueWithout, action: onContinue)
                        .buttonStyle(.lookSecondary)
                        .accessibilityIdentifier("safetyCopyContinue")
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.bottom, 16)
        }
        .lookScreenBackground()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("safetyCopyFailed")
    }
}

/// After Restore is confirmed: the files change at the next launch, so the app waits here — nothing logged meanwhile
/// would survive. The eye lands on the title; Cancel Restore is the only command.
struct SafetyRestorePendingView: View {
    let copy: SafetyCopyInfo
    var cancelFailure: String?
    let onCancel: () -> Void
    @Environment(\.look) private var look

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    Text(SafetyCopyCopy.pendingTitle)
                        .font(look.font.largeTitle)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 40)
                    Text(SafetyCopyCopy.pendingMessage(copy.date))
                        .font(look.font.body)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let cancelFailure {
                        Text(SafetyCopyCopy.cancelFailed(cancelFailure))
                            .font(look.font.footnote)
                            .foregroundStyle(look.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("safetyRestoreCancelFailed")
                    }
                }
                .padding(.horizontal, look.space.margin)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            Button(SafetyCopyCopy.cancelRestore, action: onCancel)
                .buttonStyle(.lookSecondary)
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 16)
                .accessibilityIdentifier("safetyRestoreCancel")
        }
        .lookScreenBackground()
        .accessibilityElement(children: .contain)
        // The app is still underneath: VoiceOver stays on this screen (codex-review-n1 #3).
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("safetyRestorePending")
    }
}

/// Settings: shown only when a copy exists (or a restore just failed). One row, the newest copy, with its date; the
/// confirmation names the date again.
struct SafetyCopySection: View {
    @Environment(StoreGate.self) private var store
    @Environment(\.look) private var look
    @State private var confirming: SafetyCopyInfo?
    @State private var scheduleFailure: String?
    @AppStorage(StoreGate.restoreFailureKey) private var restoreFailure: String?

    private var latest: SafetyCopyInfo? { store.latestCopy }

    var body: some View {
        Group {
            if latest != nil || restoreFailure != nil || scheduleFailure != nil {
                VStack(alignment: .leading, spacing: look.space.header) {
                    SectionHeader(SafetyCopyCopy.sectionTitle)
                    if let latest {
                        SettingsCardButton { confirming = latest } label: {
                            SettingsRow(SafetyCopyCopy.restoreRow,
                                        subtitle: SafetyCopyCopy.restoreRowSubtitle(latest.date),
                                        symbol: "clock.arrow.circlepath", showsChevron: false)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("safetyCopyRestore")
                    }
                    if let message = scheduleFailure ?? restoreFailure {
                        SettingsNotice(symbol: "exclamationmark.triangle", text: SafetyCopyCopy.restoreFailed(message))
                            .padding(.top, 2)
                            .accessibilityIdentifier("safetyCopyRestoreFailed")
                    }
                }
            }
        }
        .confirmationDialog(confirming.map { SafetyCopyCopy.confirmTitle($0.date) } ?? "",
                            isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
                            titleVisibility: .visible, presenting: confirming) { copy in
            Button(SafetyCopyCopy.confirmButton, role: .destructive) {
                do {
                    try store.scheduleRestore(copy)
                    scheduleFailure = nil
                } catch {
                    scheduleFailure = error.localizedDescription
                }
            }
            .accessibilityIdentifier("safetyCopyConfirmRestore")
        } message: { _ in
            Text(SafetyCopyCopy.confirmMessage)
        }
    }
}
