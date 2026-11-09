import SwiftUI

/// Nutrition N3 (D80) — Profile → Settings → Personal details: the one place for weight, height, date of birth and
/// sex, read by the nutrition goals, the heart rate zones and the AI. **MOCK for the user's review:** sample values,
/// nothing saved; each row will open its own small editor.
struct PersonalDetailsView: View {
    @Environment(\.look) private var look

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                LookNavTitle("Personal details")
                LookList(separatorInset: 54) {
                    ProfileRow("Weight", symbol: "scalemass", value: "176.4 lb") {}
                    ProfileRow("Height", symbol: "ruler", value: "5 ft 11 in") {}
                    ProfileRow("Date of birth", symbol: "calendar", value: "Mar 14, 1996") {}
                    ProfileRow("Sex", symbol: "person", value: "Male") {}
                }
                Text("Used for your nutrition goals, heart rate zones and AI suggestions.")
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 2)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
    }
}
