import SwiftUI

/// Public beta ticket 02: the first-launch walkthrough, in the three structural directions offered to the user
/// (ticket 02, Design). Shows sample content only and touches no data; `onFinish` runs for Skip and for the last
/// page's button alike.
struct OnboardingView: View {
    var style: OnboardingStyle
    var onFinish: () -> Void

    @State private var index = 0
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pages = OnboardingPage.all

    var body: some View {
        VStack(spacing: 0) {
            topBar
            switch style {
            case .showcase, .poster: pager
            case .onePage: onePage
            }
            bottomButton
        }
        .background(look.ground.ignoresSafeArea())
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack {
            if style == .poster { indicator }
            Spacer()
            if !(style == .onePage) && !pages[index].isLast {
                Button(action: onFinish) {
                    Text("Skip")
                        .font(look.font.body.weight(.semibold))
                        .foregroundStyle(look.textSecondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("onboardingSkip")
            }
        }
        .padding(.horizontal, look.space.margin)
        .frame(minHeight: 44)
    }

    private var indicator: some View {
        HStack(spacing: 6) {
            ForEach(pages) { page in
                Capsule()
                    .fill(page.id == index ? look.action : look.textTertiary.opacity(0.5))
                    .frame(width: page.id == index ? 18 : 7, height: 7)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Page \(index + 1) of \(pages.count)")
    }

    private var bottomButton: some View {
        let last = style == .onePage || pages[index].isLast
        return VStack(spacing: 14) {
            if style == .showcase { indicator }
            PrimaryButton(last ? "Get started" : "Continue") {
                if last { onFinish() } else { advance() }
            }
            .accessibilityIdentifier(last ? "onboardingGetStarted" : "onboardingContinue")
        }
        .padding(.horizontal, look.space.margin)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func advance() {
        if reduceMotion { index += 1 } else { withAnimation(.snappy) { index += 1 } }
    }

    // MARK: Paged directions (A, B)

    private var pager: some View {
        TabView(selection: $index) {
            ForEach(pages) { page in
                GeometryReader { viewport in
                    ScrollView {
                        Group {
                            if style == .showcase { showcasePage(page) } else { posterPage(page) }
                        }
                        .padding(.horizontal, look.space.margin)
                        .padding(.bottom, 12)
                        // A centres the page in the viewport (no empty lower third); B stays top-anchored like a
                        // poster. Taller pages (accessibility sizes) scroll.
                        .frame(minHeight: viewport.size.height, alignment: style == .showcase ? .center : .top)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                .tag(page.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    /// A — the illustration leads in a panel; the headline names it below.
    private func showcasePage(_ page: OnboardingPage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            OnboardingIllustration(kind: page.illustration)
                .frame(maxWidth: .infinity, minHeight: 260, alignment: .center)
                .padding(.top, 8)
            Text(page.headline)
                .font(page.id == 0 ? look.font.largeTitle : look.font.title)
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
                .accessibilityAddTraits(.isHeader)
            Text(page.line)
                .font(look.font.body)
                .foregroundStyle(look.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// B — a giant poster headline is the page; the illustration is small beneath it.
    private func posterPage(_ page: OnboardingPage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: -6) {
                ForEach(Array(page.posterLines.enumerated()), id: \.offset) { offset, line in
                    Text(line)
                        .font(.system(size: 56, weight: .black, design: .default).width(.expanded))
                        .foregroundStyle(offset == page.posterLines.count - 1 ? look.action : look.textPrimary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
            }
            .padding(.top, 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(page.headline)
            .accessibilityAddTraits(.isHeader)
            Text(page.line)
                .font(look.font.title3)
                .foregroundStyle(look.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            OnboardingIllustration(kind: page.illustration)
                .padding(.top, 14)
        }
    }

    // MARK: One page (C)

    private var onePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(look.action)
                    .padding(.top, 12)
                    .accessibilityHidden(true)
                Text(pages[0].headline)
                    .font(look.font.largeTitle)
                    .foregroundStyle(look.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(pages[0].line)
                    .font(look.font.title3)
                    .foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 0) {
                    ForEach(pages.dropFirst()) { page in
                        onePageRow(page)
                        if !page.isLast { Rectangle().fill(look.hairline).frame(height: 1).padding(.leading, 62) }
                    }
                }
                .padding(.vertical, 4)
                .lookSurface(.panel)
                .padding(.top, 22)
            }
            .padding(.horizontal, look.space.margin)
            .padding(.bottom, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func onePageRow(_ page: OnboardingPage) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Group {
                if page.symbol == LookIcon.machine {
                    LookIcon(LookIcon.machine, style: .title3)
                } else {
                    Image(systemName: page.symbol).font(.title3.weight(.semibold))
                }
            }
            .foregroundStyle(look.actionText)
            .frame(width: 32)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(page.headline).font(look.font.headline).foregroundStyle(look.textPrimary)
                Text(page.line).font(look.font.subhead).foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}
