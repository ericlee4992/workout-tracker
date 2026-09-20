import MapKit
import SwiftData
import SwiftUI

extension CardioActivity {
    var symbol: String {
        switch self {
        case .indoorWalk, .outdoorWalk: "figure.walk"
        case .indoorRun, .outdoorRun: "figure.run"
        case .indoorCycle: "figure.indoor.cycle"
        case .outdoorCycle: "figure.outdoor.cycle"
        case .elliptical: "figure.elliptical"
        case .rowing: "figure.rower"
        case .stairStepper: "figure.stair.stepper"
        }
    }
}

struct CardioActivityPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    var endsCurrentSegment = false
    var select: (CardioActivity) -> Void
    var body: some View {
        NavigationStack {
            List {
                if endsCurrentSegment {
                    Text("Starting another activity ends the current cardio segment.")
                        .font(.footnote).foregroundStyle(Theme.secondary)
                }
                activities(outdoor: false, title: "Gym")
                activities(outdoor: true, title: "Outdoors")
            }
            .scrollContentBackground(.hidden).background(Theme.background)
            .navigationTitle("Choose Cardio")
            .searchable(text: $search, prompt: "Search activities")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
    private func activities(outdoor: Bool, title: String) -> some View {
        Section(title) {
            ForEach(CardioActivity.allCases.filter {
                $0.isOutdoor == outdoor && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))
            }) { activity in
                Button {
                    select(activity); dismiss()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: activity.symbol).font(.title2).foregroundStyle(Theme.secondary).frame(minWidth: 32)
                        Text(activity.name).foregroundStyle(Theme.text)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.secondary)
                    }.padding(.vertical, 8).frame(minHeight: 44)
                }
                .listRowBackground(Theme.card)
                .accessibilityIdentifier("cardioActivity.\(activity.rawValue)")
            }
        }
    }
}

struct CardioWorkoutSection: View {
    var workout: Workout
    var recorder: CardioRecorder
    var monitor: HeartRateMonitor?
    var body: some View {
        Group {
            if let segment = workout.unfinishedCardio {
                CardioLiveView(segment: segment, recorder: recorder, monitor: monitor)
            } else if workout.orderedCardio.isEmpty {
                EmptyState(title: "Add cardio to this workout", symbol: "figure.run")
            }
            ForEach(workout.orderedCardio.filter { $0.endedAt != nil }) { segment in
                CardioSummaryCard(segment: segment, showsRoute: false)
            }
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
        .listRowSeparator(.hidden).listRowBackground(Color.clear)
    }
}

struct CardioLiveView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    var segment: CardioSegment
    var recorder: CardioRecorder
    var monitor: HeartRateMonitor?
    @State private var editingDistance = false
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), alignment: .leading), count: typeSize.isAccessibilitySize ? 1 : 2)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Label(segment.activity.name, systemImage: segment.activity.symbol).font(.title2.bold())
            TimelineView(.periodic(from: .now, by: 1)) { tick in
                VStack(spacing: 7) {
                    Text(segment.isRunning ? "Time" : "Paused").font(.subheadline).foregroundStyle(Theme.secondary)
                    Text(Format.elapsed(seconds: Int(segment.activeDuration(at: tick.date))))
                        .font(Theme.hero).monospacedDigit().accessibilityIdentifier("cardioTimer")
                }.frame(maxWidth: .infinity)
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                CardioMetric(label: "Distance", value: distanceText, unit: segment.unit.rawValue)
                    .accessibilityIdentifier("cardioDistanceMetric")
                if segment.activity.usesSpeed {
                    CardioMetric(label: "Average speed", value: averageSpeedText, unit: "\(segment.unit.rawValue)/h")
                } else {
                    CardioMetric(label: "Average pace", value: CardioMath.paceText(CardioMath.pace(seconds: segment.activeDuration(at: recorder.measurementTime), meters: segment.distanceMeters, unit: segment.unit)), unit: "/\(segment.unit.rawValue)")
                }
                if let sample = recorder.currentHeartRate {
                    CardioMetric(label: "Heart rate", value: "\(sample.bpm)", unit: "bpm", tint: Theme.danger)
                }
                if let calories = segment.activeEnergyKilocalories {
                    CardioMetric(label: "Active calories", value: "\(Int(calories.rounded()))", unit: "cal")
                }
            }
            if segment.manualDistanceValue == nil && recorder.freshSpeed != nil {
                Text(segment.activity.usesSpeed
                     ? "Current speed: \(speedText) \(segment.unit.rawValue)/h"
                     : "Current pace: \(CardioMath.paceText(CardioMath.pace(speed: recorder.freshSpeed, unit: segment.unit))) /\(segment.unit.rawValue)")
                    .font(.footnote).foregroundStyle(Theme.secondary)
                    .accessibilityIdentifier("cardioCurrentPace")
            }
            if segment.isRunning && recorder.currentHeartRate == nil {
                Text("Waiting for heart-rate data").font(.footnote).foregroundStyle(Theme.secondary)
            }
            if let sample = recorder.currentHeartRate, let max = monitor?.maxHeartRate,
               let zone = HeartRateZones.zone(for: sample.bpm, max: max.bpm) {
                HStack {
                    Chip(tint: zone.color) { Text(zone.label) }
                    Spacer()
                    Text(sample.source.label).font(.caption).foregroundStyle(Theme.secondary)
                }
            }
            if let message = recorder.locationMessage {
                Text(message).font(.footnote).foregroundStyle(Theme.secondary)
            }
            // Measured progress already has Distance above. Manual entry stays
            // available when indoor sensors supply no distance, or to revise a manual value.
            if !segment.activity.isOutdoor && (segment.distanceMeters == nil || segment.manualDistanceValue != nil) {
                Button { editingDistance = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            if let caption = segment.distanceSourceCaption {
                                Text(caption).font(.caption).foregroundStyle(Theme.secondary)
                            }
                            Text(segment.distanceMeters == nil ? "Enter distance" : "\(distanceText) \(segment.unit.rawValue)")
                                .font(.headline).foregroundStyle(Theme.text)
                        }
                        Spacer()
                        Image(systemName: "pencil").foregroundStyle(Theme.secondary)
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("cardioEditDistance")
            }

        }
        .foregroundStyle(Theme.text)
        .sheet(isPresented: $editingDistance) { CardioDistanceSheet(segment: segment) }
    }
    private var distanceText: String {
        guard let meters = segment.distanceMeters else { return "—" }
        return String(format: "%.2f", meters / segment.unit.metersPerUnit)
    }
    private var averageSpeedText: String {
        guard let meters = segment.distanceMeters, segment.activeDuration(at: recorder.measurementTime) > 0 else { return "—" }
        return String(format: "%.1f", meters / segment.activeDuration(at: recorder.measurementTime) * 3_600 / segment.unit.metersPerUnit)
    }
    private var speedText: String {
        guard let speed = recorder.freshSpeed else { return "—" }
        return String(format: "%.1f", speed * 3_600 / segment.unit.metersPerUnit)
    }
}

/// Recording controls stay at the thumb even when large text needs scrolling.
struct CardioControls: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    var segment: CardioSegment
    var recorder: CardioRecorder
    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        layout {
            Button {
                if segment.isRunning { recorder.pause() } else { recorder.resume() }
            } label: {
                Label(segment.isRunning ? "Pause" : "Resume", systemImage: segment.isRunning ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }.buttonStyle(.primary).accessibilityIdentifier("cardioPauseResume")
            Button { recorder.endCardio() } label: {
                Text("End Cardio").frame(maxWidth: .infinity)
            }.buttonStyle(.secondary).accessibilityIdentifier("endCardio")
        }
        .padding(16).card(.elevated)
        .padding(.horizontal, 16).padding(.bottom, 8)
    }
}

struct CardioMetric: View {
    var label: String
    var value: String
    var unit: String = ""
    var tint: Color = Theme.text
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundStyle(Theme.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(Theme.stat).monospacedDigit().foregroundStyle(tint)
                Text(unit).font(.subheadline).foregroundStyle(Theme.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CardioSummaryCard: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    var segment: CardioSegment
    // Completed segments also appear inside an unfinished workout, where maps stay hidden.
    var showsRoute = true
    @State private var editingDistance = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(segment.activity.name, systemImage: segment.activity.symbol).font(.headline).foregroundStyle(Theme.text)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("cardioSummary.\(segment.activityRawValue)")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 16) {
                CardioMetric(label: "Time", value: Format.elapsed(seconds: Int(segment.activeDuration(at: segment.endedAt ?? .now))))
                if let meters = segment.distanceMeters {
                    CardioMetric(label: "Distance", value: String(format: "%.2f", meters / segment.unit.metersPerUnit), unit: segment.unit.rawValue)
                    if !segment.activity.usesSpeed {
                        CardioMetric(label: "Average pace", value: CardioMath.paceText(CardioMath.pace(seconds: segment.activeDuration(at: segment.endedAt ?? .now), meters: meters, unit: segment.unit)), unit: "/\(segment.unit.rawValue)")
                    } else if segment.activeDuration(at: segment.endedAt ?? .now) > 0 {
                        CardioMetric(label: "Average speed", value: String(format: "%.1f", meters / segment.activeDuration(at: segment.endedAt ?? .now) * 3_600 / segment.unit.metersPerUnit), unit: "\(segment.unit.rawValue)/h")
                    }
                }
                if let bpm = segment.averageHeartRate { CardioMetric(label: "Avg. heart rate", value: "\(bpm)", unit: "bpm") }
                if let calories = segment.activeEnergyKilocalories { CardioMetric(label: "Active calories", value: "\(Int(calories.rounded()))", unit: "cal") }
            }
            if showsRoute && !segment.route.isEmpty { CardioRouteMap(points: segment.route).frame(height: 180) }
            Button { editingDistance = true } label: {
                HStack {
                    Text(segment.distanceMeters == nil ? "Enter distance" : (segment.distanceSourceCaption ?? "Distance"))
                    Spacer()
                    Image(systemName: "pencil")
                }.font(.caption).frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).foregroundStyle(Theme.secondary).accessibilityIdentifier("cardioSummaryEditDistance")
        }
        .padding(16).card()
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $editingDistance) { CardioDistanceSheet(segment: segment) }
    }
}

struct CardioDistanceSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var segment: CardioSegment
    @State private var text = ""
    @State private var unit: CardioDistanceUnit = .km
    @State private var error: String?
    @State private var initialText = ""
    @State private var initialUnit: CardioDistanceUnit = .km
    var body: some View {
        NavigationStack {
            Form {
                TextField("Distance", text: $text).keyboardType(.decimalPad).accessibilityIdentifier("cardioDistanceField")
                Picker("Unit", selection: $unit) {
                    ForEach(CardioDistanceUnit.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).accessibilityIdentifier("cardioDistanceUnit")
                if let meters = segment.automaticDistanceMeters {
                    Text("Measured: \(String(format: "%.2f", meters / unit.metersPerUnit)) \(unit.rawValue)")
                        .font(.subheadline).foregroundStyle(Theme.secondary)
                }
                Text("Enter the machine’s distance. Clear it to use the measured distance.")
                    .font(.footnote).foregroundStyle(Theme.secondary)
                if let error { Text(error).foregroundStyle(Theme.danger) }
            }
            .navigationTitle("Distance")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try CardioSession(context: context).enterDistance(text, unit: unit, for: segment)
                            dismiss()
                        } catch { self.error = error.localizedDescription }
                    }.disabled(text == initialText && unit == initialUnit)
                        .accessibilityIdentifier("saveCardioDistance")
                }
            }
            .onAppear {
                unit = segment.manualDistanceUnitRawValue.flatMap(CardioDistanceUnit.init(rawValue:)) ?? segment.unit
                text = segment.manualDistanceValue.map(String.init(describing:)) ?? ""
                initialText = text
                initialUnit = unit
            }
        }
    }
}

struct CardioRouteMap: View {
    var points: [CardioRoutePoint]
    private struct Portion: Identifiable {
        let id: UUID
        let coordinates: [CLLocationCoordinate2D]
    }
    private var portions: [Portion] {
        Dictionary(grouping: points, by: \.portion).map { id, points in
            Portion(id: id, coordinates: points.sorted { $0.date < $1.date }.map { .init(latitude: $0.latitude, longitude: $0.longitude) })
        }
    }
    var body: some View {
        Map(initialPosition: .automatic, interactionModes: []) {
            ForEach(portions) { portion in
                MapPolyline(coordinates: portion.coordinates).stroke(Color("AccentColor"), lineWidth: 4)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.inner))
        .accessibilityLabel("Recorded cardio route")
        .accessibilityIdentifier("cardioRoute")
    }
}

private extension CardioSegment {
    /// Presentation only: keep automatic source provenance in the model and exports.
    var distanceSourceCaption: String? {
        if manualDistanceValue != nil { return distanceLabel }
        return source == .gps ? source?.label : nil
    }
}
