import SwiftUI
import UIKit

// Nutrition N7 — the camera's modes, and the drawn stand-ins for the camera in UI tests and on the Simulator (which has
// no camera): a meal, a nutrition label, a barcode. Drawn in code, so no personal photo is in the repo.

/// The camera's three modes (the approved prototype's `SoftScanFoodScreen`): Barcode is wired in N8.
enum FoodScanMode: String, CaseIterable, Identifiable {
    case meal, barcode, label
    var id: String { rawValue }
    var title: String {
        switch self {
        case .meal: "Scan food"
        case .barcode: "Barcode"
        case .label: "Food label"
        }
    }
    var symbol: String {
        switch self {
        case .meal: "camera.viewfinder"
        case .barcode: "barcode.viewfinder"
        case .label: "list.bullet.rectangle.portrait"
        }
    }
}

// MARK: - Sample art (drawn, not photographed)

@MainActor
enum FoodScanArt {
    static let meal: UIImage = render(MockMealPhoto(), size: CGSize(width: 360, height: 360))
    static let label: UIImage = render(MockNutritionLabel(), size: CGSize(width: 300, height: 440))
    static let barcode: UIImage = render(MockBarcode(), size: CGSize(width: 320, height: 160))

    private static func render(_ view: some View, size: CGSize) -> UIImage {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 2
        return renderer.uiImage ?? UIImage()
    }
}

/// A bowl on a table, from above: rice, tuna cubes, mango, avocado, edamame.
private struct MockMealPhoto: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x6E5A48), Color(hex: 0x3B2F26)], startPoint: .topLeading,
                           endPoint: .bottomTrailing)
            Circle().fill(Color(hex: 0xF4F1EA)).frame(width: 300, height: 300)
                .shadow(color: .black.opacity(0.45), radius: 18, y: 10)
            Circle().fill(Color(hex: 0xE9E4DA)).frame(width: 262, height: 262)
            // Rice.
            Circle().fill(Color(hex: 0xFBF8F0)).frame(width: 236, height: 236)
            ForEach(0..<46, id: \.self) { i in
                Capsule().fill(Color(hex: 0xEDE6D6)).frame(width: 9, height: 4)
                    .rotationEffect(.degrees(Double(i * 37)))
                    .offset(x: CGFloat((i * 53) % 190) - 95, y: CGFloat((i * 89) % 190) - 95)
            }
            // Tuna.
            ForEach(0..<9, id: \.self) { i in
                RoundedRectangle(cornerRadius: 6).fill(Color(hex: i % 2 == 0 ? 0xC8384B : 0xB22C40))
                    .frame(width: 30, height: 28)
                    .rotationEffect(.degrees(Double(i * 23)))
                    .offset(x: -52 + CGFloat(i % 3) * 30, y: -58 + CGFloat(i / 3) * 30)
            }
            // Mango.
            ForEach(0..<6, id: \.self) { i in
                RoundedRectangle(cornerRadius: 5).fill(Color(hex: 0xF4A72C)).frame(width: 24, height: 24)
                    .rotationEffect(.degrees(Double(i * 31)))
                    .offset(x: 46 + CGFloat(i % 2) * 26, y: -44 + CGFloat(i / 2) * 26)
            }
            // Avocado.
            ForEach(0..<4, id: \.self) { i in
                Ellipse().fill(LinearGradient(colors: [Color(hex: 0xC9DB7A), Color(hex: 0x6E9A3A)],
                                              startPoint: .leading, endPoint: .trailing))
                    .frame(width: 70, height: 22)
                    .rotationEffect(.degrees(-28))
                    .offset(x: -38 + CGFloat(i) * 12, y: 52 + CGFloat(i) * 16)
            }
            // Edamame.
            ForEach(0..<10, id: \.self) { i in
                Circle().fill(Color(hex: 0x8DBF4E)).frame(width: 16, height: 16)
                    .offset(x: 50 + CGFloat(i % 3) * 16, y: 44 + CGFloat(i / 3) * 15)
            }
            // Sesame.
            ForEach(0..<24, id: \.self) { i in
                Capsule().fill(i % 3 == 0 ? Color.black.opacity(0.8) : Color(hex: 0xF5EBD3)).frame(width: 4, height: 2.5)
                    .offset(x: CGFloat((i * 71) % 170) - 85, y: CGFloat((i * 43) % 150) - 75)
            }
        }
    }
}

/// A UPC sticker, the barcode mode's subject.
private struct MockBarcode: View {
    private let widths: [CGFloat] = [2, 1, 3, 1, 1, 2, 4, 1, 2, 1, 3, 2, 1, 1, 4, 2, 1, 3, 1, 2, 2, 1, 3, 1, 1, 2, 4, 1,
                                     2, 1, 1, 3, 2, 1, 2, 4, 1, 1, 3, 1, 2, 1]
    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 2) {
                ForEach(widths.indices, id: \.self) { i in
                    Rectangle().fill(i % 2 == 0 ? Color.black : Color.clear).frame(width: widths[i] * 2.4)
                }
            }
            .frame(height: 100)
            Text("0  12345  67890  5").font(.system(size: 18, weight: .medium, design: .monospaced)).foregroundStyle(.black)
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
    }
}

/// A nutrition facts panel (US layout), the label mode's subject.
private struct MockNutritionLabel: View {
    var body: some View {
        ZStack {
            Color(hex: 0xD9CBB0)
            VStack(alignment: .leading, spacing: 3) {
                Text("Nutrition Facts").font(.system(size: 30, weight: .black)).kerning(-0.5)
                Rectangle().frame(height: 1)
                Text("8 servings per container").font(.system(size: 13))
                HStack {
                    Text("Serving size").font(.system(size: 15, weight: .bold))
                    Spacer()
                    Text("2/3 cup (55g)").font(.system(size: 15, weight: .bold))
                }
                Rectangle().frame(height: 8)
                Text("Amount per serving").font(.system(size: 11, weight: .bold))
                HStack(alignment: .lastTextBaseline) {
                    Text("Calories").font(.system(size: 26, weight: .black))
                    Spacer()
                    Text("230").font(.system(size: 34, weight: .black))
                }
                Rectangle().frame(height: 4)
                row("Total Fat 8g", "10%", bold: true)
                row("   Saturated Fat 1g", "5%")
                row("Sodium 160mg", "7%", bold: true)
                row("Total Carbohydrate 37g", "13%", bold: true)
                row("   Dietary Fiber 4g", "14%")
                row("   Total Sugars 12g", "")
                row("Protein 3g", "", bold: true)
                Rectangle().frame(height: 8)
            }
            .foregroundStyle(.black)
            .padding(12)
            .background(Color.white)
            .border(Color.black, width: 2)
            .padding(18)
            .rotationEffect(.degrees(-1.5))
        }
    }

    private func row(_ title: String, _ percent: String, bold: Bool = false) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(title).font(.system(size: 13, weight: bold ? .bold : .regular))
                Spacer()
                Text(percent).font(.system(size: 13, weight: .bold))
            }
            Rectangle().frame(height: 0.8)
        }
    }
}
