import SwiftUI

// Public beta ticket 14 (D62): the one-time sheet that introduces a big change — the title, a few lines with a glyph
// each, and Continue. Shown after an update (WhatsNew.decide) and from Settings → What's New.

struct WhatsNewSheet: View {
    let entry: WhatsNewEntry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .title3) private var disc: CGFloat = 44

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    Text(entry.title)
                        .font(look.font.largeTitle)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 40)
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(entry.items, id: \.text) { item in
                            HStack(alignment: .top, spacing: 16) {
                                Image(systemName: item.symbol)
                                    .font(.system(.title3, weight: .semibold))
                                    .foregroundStyle(look.textPrimary)
                                    .frame(width: disc, height: disc)
                                    .background(look.surfaceRaised, in: Circle())
                                    .accessibilityHidden(true)
                                Text(item.text)
                                    .font(look.font.body)
                                    .foregroundStyle(look.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, 10)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("whatsNewItem")
                        }
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            Button("Continue") { dismiss() }
                .buttonStyle(.lookPrimary)
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 16)
                .accessibilityIdentifier("whatsNewContinue")
        }
        .lookSheetGround()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("whatsNewSheet")
    }
}
