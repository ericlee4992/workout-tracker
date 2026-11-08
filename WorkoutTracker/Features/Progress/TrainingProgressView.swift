import SwiftUI

// Soft redesign S4: a training-wide weekly chart, opened from its Progress panel — the chart large and the weeks
// listed, newest first.
struct TrainingProgressView: View {
    let metric: TrainingMetric
    let reading: ProgressReading
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(metric.title).font(look.font.title).foregroundStyle(look.textPrimary)
                    Text(metric.measures).font(look.font.subhead).foregroundStyle(look.textSecondary)
                }
                if reading.state == .empty {
                    Text("Nothing to chart here").font(look.font.subhead).foregroundStyle(look.textSecondary)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        ProgressReadingHeader(reading: reading, numberFont: look.font.heroNumber)
                        ProgressPanelChart(reading: reading, height: 220)
                    }
                    .padding(16)
                    .lookSurface(.panel)
                    LookList(header: "Weeks") {
                        ForEach(reading.points.reversed()) { point in
                            HStack {
                                Text("Week of \(point.date.formatted(.dateTime.month(.abbreviated).day()))")
                                    .font(look.font.body).foregroundStyle(look.textPrimary)
                                Spacer()
                                Text(reading.axisLabel(point.value) + (reading.unit.isEmpty ? "" : " \(reading.unit)"))
                                    .font(look.font.fieldNumber).foregroundStyle(look.textPrimary)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.vertical, 12)
        }
        .lookSheetGround()
        .navigationTitle(metric.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
    }
}
