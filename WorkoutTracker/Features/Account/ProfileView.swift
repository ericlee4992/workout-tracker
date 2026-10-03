import SwiftUI

/// Public beta ticket 05: the profile page, pushed from Settings → Account. The name is the page title (who is signed
/// in); **today's AI use** is the bold element — three figures against their limits, the one thing that changes day to
/// day; then the training profile (the runner-up: it fills in Ask AI for Templates) with Edit; then the account's facts,
/// Sign Out, and Delete Account at the end.
///
/// UI-first stage: runs on an `AccountProfile` value; the server calls arrive with the wiring (after 03's app half).
struct ProfileView: View {
    var profile: AccountProfile
    var onEditTraining: () -> Void = {}
    var onEditName: () -> Void = {}
    var onSignOut: () -> Void = {}
    var onDelete: () -> Void = {}

    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var titleVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                LookNavTitle(profile.displayName, subtitle: profile.email)
                aiUse
                training
                account
                VStack(spacing: look.space.group) {
                    LookList {
                        LookRow("Sign Out", symbol: "rectangle.portrait.and.arrow.right", showsChevron: false,
                                action: onSignOut)
                            .accessibilityIdentifier("profileSignOut")
                    }
                    DestructiveRowButton("Delete Account…", action: onDelete)
                        .accessibilityIdentifier("profileDeleteAccount")
                }
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
        .exercisesInlineTitle(profile.displayName, visible: titleVisible)
    }

    // MARK: Today's AI (the bold element)

    private var aiUse: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
        return VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Today's AI", trailing: profile.aiPaused ? "Paused" : "Resets at midnight")
            layout {
                ForEach(profile.aiUsage) { use in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(use.used)")
                                .font(look.font.statNumber)
                                .foregroundStyle(look.textPrimary)
                            Text("/ \(use.limit)")
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(look.textSecondary)
                        }
                        Text(use.title)
                            .font(look.font.footnote)
                            .foregroundStyle(look.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: typeSize.isAccessibilitySize ? nil : 92, alignment: .topLeading)
                    .lookSurface(.stat)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(use.title), \(use.used) of \(use.limit) used today")
                    .accessibilityIdentifier("profileAIUse.\(use.flow)")
                }
            }
        }
    }

    // MARK: Training profile

    private var training: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Training profile", trailing: profile.training == nil ? nil : "Edit",
                          trailingAction: profile.training == nil ? nil : onEditTraining)
                .accessibilityIdentifier("profileEditTraining")
            if let training = profile.training {
                VStack(alignment: .leading, spacing: 0) {
                    Text(training.goals)
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(16)
                        .accessibilityLabel("Goals, \(training.goals)")
                    LookDivider().padding(.leading, 16)
                    fact("Experience", training.experience)
                    LookDivider().padding(.leading, 16)
                    fact("Schedule", "\(training.days) \(training.days == 1 ? "day" : "days") · \(training.minutes) min")
                    LookDivider().padding(.leading, 16)
                    fact("Height", training.height?.display ?? "Not set")
                    LookDivider().padding(.leading, 16)
                    fact("Weight", training.weight?.display ?? "Not set")
                }
                .lookSurface(.panel)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("profileTraining")
                SettingsNotice(symbol: "sparkles", text: "Fills in Ask AI for Templates.")
                    .padding(.top, 2)
            } else {
                Button(action: onEditTraining) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(.title3, weight: .semibold))
                            .foregroundStyle(look.textSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Set Up Training Profile")
                                .font(.system(.body, weight: .semibold))
                                .foregroundStyle(look.textPrimary)
                            Text("Goals, schedule, height and weight for Ask AI.")
                                .font(look.font.footnote)
                                .foregroundStyle(look.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lookSurface(.tile)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.lookPressable)
                .accessibilityIdentifier("profileSetUpTraining")
            }
        }
    }

    // MARK: Account

    private var account: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Account")
            LookList {
                Button(action: onEditName) {
                    fact("Name", profile.displayName, chevron: true)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profileName")
                LookDivider().padding(.leading, 16)
                fact("Signed in with", profile.provider)
                LookDivider().padding(.leading, 16)
                fact("Email", profile.email)
                LookDivider().padding(.leading, 16)
                fact("Member since", profile.memberSince.formatted(.dateTime.month(.wide).year()))
            }
        }
    }

    /// A label/value row; at accessibility sizes the value goes under the label.
    private func fact(_ label: String, _ value: String, chevron: Bool = false) -> some View {
        let ax = typeSize.isAccessibilitySize
        let layout = ax ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2)) : AnyLayout(HStackLayout(spacing: 12))
        return HStack(spacing: 8) {
            layout {
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
            if chevron {
                if ax { Spacer(minLength: 0) }
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Settings → Account row

/// The row at the top of Settings (spec → Profile page): the name and email signed in; "Sign In" signed out.
struct SettingsAccountRow: View {
    var profile: AccountProfile?
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var disc: CGFloat = 48

    var body: some View {
        SettingsCardButton(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(look.surfaceRaised)
                    if let profile {
                        Text(Self.initials(profile.displayName))
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(look.textPrimary)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(.title3, weight: .semibold))
                            .foregroundStyle(look.textSecondary)
                    }
                }
                .frame(width: disc, height: disc)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile?.displayName ?? "Sign In")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                    Text(profile?.email ?? "For AI and a training profile.")
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("settingsAccount")
    }

    static func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}
