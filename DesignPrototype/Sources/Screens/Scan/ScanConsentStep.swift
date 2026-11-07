import SwiftUI

// S02 — photo consent: what leaves the phone. The photo just taken (with the exercise catalog
// clipped to it) is drawn travelling to OpenAI. The disclosure is four parallel facts in one
// card, split by their glyph treatment: what is sent (a filled disc with an up-arrow badge:
// the photo, the catalog) and what is not kept or is yours (an open disc: the photo is not
// saved, the call is billed to your key). The policy link is the card's last row, above the
// fold. "Allow photos and continue" is the one filled command.
//
// Also here: the no-key gate (audit B9) — without an OpenAI API key nothing can be identified,
// so the sheet opens on the key instead of the camera.

struct ScanConsentStep: View {
    var photoSpace: Namespace.ID
    var onCancel: () -> Void
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var allowTaps = 0

    private static let policyURL = URL(string: "https://developers.openai.com/api/docs/guides/your-data")!

    var body: some View {
        VStack(spacing: 0) {
            ScanTopBar(title: "Scan Machine", onCancel: onCancel)
            ScanPagedScroll(page: router.scanCapturePage, centered: !typeSize.isAccessibilitySize) {
                VStack(alignment: .leading, spacing: 20) {
                    dataPath
                        .padding(.top, 4)
                    Text("Send equipment photos to OpenAI?")
                        .font(look.font.title2)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    facts
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 20)
            } bar: {
                ScanBottomBar {
                    ScanPrimaryButton("Allow photos and continue", symbol: "checkmark") {
                        allowTaps += 1
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { store.scanAllowPhotos() }
                    }
                }
            }
        }
        .sensoryFeedback(.success, trigger: allowTaps)
    }

    // MARK: The data path: this photo → OpenAI

    private var dataPath: some View {
        HStack(alignment: .center, spacing: 0) {
            ScanPhotoTile(plateText: store.scan.demoKind.scanPlateText, cornerRadius: look.radius.tile)
                .matchedGeometryEffect(id: "scanPhoto", in: photoSpace)
                .frame(width: photoWidth, height: photoWidth * 1.22)
                .overlay(alignment: .bottomTrailing) {
                    // The exercise catalog travels with the photo: a flat badge (not pressable),
                    // cut out of the photo by a ring of the sheet's ground.
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(look.id.isPaperClub ? look.pressedFill : look.surfaceRaised))
                        .overlay { Circle().strokeBorder(look.groundSheet, lineWidth: 3) }
                        .offset(x: 14, y: 12)
                }
            ScanFlowConnector()
                .frame(maxWidth: .infinity, minHeight: 24)
                .padding(.leading, 24)
                .padding(.trailing, 10)
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: discSide * 0.36, weight: .semibold))
                    .foregroundStyle(look.textPrimary)
                    .frame(width: discSide, height: discSide)
                    .background(look.id.isPaperClub ? look.pressedFill : look.surfaceRaised, in: Circle())
                Text("OpenAI")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
            }
            .padding(.top, 26)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("This photo and the exercise catalog are sent to OpenAI")
    }

    private var photoWidth: CGFloat { typeSize.isAccessibilitySize ? 96 : 128 }
    private var discSide: CGFloat { typeSize.isAccessibilitySize ? 76 : 100 }

    // MARK: Four facts and the policy

    private var facts: some View {
        VStack(spacing: 0) {
            ScanFactRow(symbol: "photo", sent: true, text: "The full photo, including any people or screens in frame")
            LookDivider().padding(.leading, 62)
            ScanFactRow(symbol: "list.bullet.rectangle", sent: true, text: "The exercise catalog")
            LookDivider().padding(.leading, 62)
            ScanFactRow(symbol: "square.and.arrow.down.badge.xmark", sent: false, text: "Photo not saved by the app")
            LookDivider().padding(.leading, 62)
            ScanFactRow(symbol: "key", sent: false, text: "Billed to your OpenAI API key")
            LookDivider()
            Link(destination: Self.policyURL) {
                HStack(spacing: 6) {
                    Text("OpenAI data policies")
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right")
                        .font(.system(.footnote, weight: .bold))
                }
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.id.isPaperClub ? look.actionText : look.textSecondary)
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.lookPressable)
        }
        .clipShape(RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
        .lookSurface(.panel)
    }
}

/// One fact. Sent: a filled disc with a small up-arrow badge. Not sent / yours: an open disc.
private struct ScanFactRow: View {
    var symbol: String
    var sent: Bool
    var text: String
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var disc: CGFloat = 32

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            glyph
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 6 }
            Text(text)
                .font(look.font.body)
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sent ? "Sent: \(text)" : text)
    }

    private var glyph: some View {
        Image(systemName: symbol)
            .font(.system(.subheadline, weight: .semibold))
            .foregroundStyle(sent ? sentInk : look.textSecondary)
            .frame(width: disc, height: disc)
            .background {
                if sent {
                    Circle().fill(sentFill)
                } else {
                    Circle().strokeBorder(look.hairline, lineWidth: look.id.isPaperClub ? 1.5 : 1.2)
                }
            }
            .overlay(alignment: .topTrailing) {
                if sent {
                    Image(systemName: "arrow.up")
                        .font(.system(size: disc * 0.28, weight: .heavy))
                        .foregroundStyle(sentFill)
                        .frame(width: disc * 0.46, height: disc * 0.46)
                        .background(sentInk, in: Circle())
                        .overlay { Circle().strokeBorder(look.surfaceSheet, lineWidth: 2) }
                        .offset(x: disc * 0.14, y: -disc * 0.12)
                }
            }
            .padding(.trailing, 2)
            .accessibilityHidden(true)
    }

    /// The sent disc takes the look's "text" fill (A flood, B pearl, C ink), inverted glyph.
    private var sentFill: Color { look.textPrimary }
    private var sentInk: Color { look.surfaceSheet }
}

/// A dashed arrow from the photo to OpenAI. When the step appears (the photo was just taken),
/// a dot runs along it twice to show where the photo would go, then rests. Reduce Motion: no dot.
private struct ScanFlowConnector: View {
    @Environment(\.look) private var look
    @ScanReduceMotion private var reduceMotion
    @State private var travel: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let y = geo.size.height / 2
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: geo.size.width - 8, y: y))
                }
                .stroke(look.textTertiary, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 6]))
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .heavy))
                    .foregroundStyle(look.textSecondary)
                    .position(x: geo.size.width - 5, y: y)
                if !reduceMotion {
                    Circle()
                        .fill(look.live)
                        .frame(width: 9, height: 9)
                        .position(x: travel * (geo.size.width - 14), y: y)
                        .opacity(1 - Double(travel))
                }
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatCount(2, autoreverses: false).delay(0.4)) { travel = 1 }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - No API key

/// Without a key the scan cannot run: the key is the step's subject (a key disc over the real
/// line), "Open AI Settings" the one filled command, the catalog the way out.
struct ScanNoKeyStep: View {
    var onCancel: () -> Void
    var onSettings: () -> Void
    var onManual: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 0) {
            ScanTopBar(title: "Scan Machine", onCancel: onCancel) { ScanDemoMenu() }
            ScanPagedScroll(page: nil, centered: true) {
                VStack(spacing: 22) {
                    ScanGlyphDisc(symbol: "key.fill", size: typeSize.isAccessibilitySize ? 88 : 108,
                                  glyphFont: .system(size: typeSize.isAccessibilitySize ? 34 : 42, weight: .semibold))
                    Text("Add your OpenAI API key to identify equipment with Terra.")
                        .font(look.font.title2)
                        .foregroundStyle(look.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                .padding(.horizontal, look.space.margin + 8)
            } bar: {
                ScanBottomBar {
                    ScanPrimaryButton("Open AI Settings", symbol: "key", action: onSettings)
                    Button("Choose a catalog model", action: onManual)
                        .buttonStyle(.lookSecondary)
                }
            }
        }
    }
}
