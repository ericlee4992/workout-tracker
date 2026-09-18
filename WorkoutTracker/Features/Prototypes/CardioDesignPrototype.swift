#if DEBUG
import SwiftUI
import MapKit

/// THROWAWAY DESIGN ONLY. Three mixed-workout compositions inside the existing app shell.
/// Sample values, no HealthKit, GPS recording, persistence, or product behavior.
struct CardioDesignPrototype: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var screen = ProcessInfo.processInfo.environment["CARDIO_SCREEN"] ?? "mixed"
    @State private var variant = ProcessInfo.processInfo.environment["CARDIO_VARIANT"] ?? "A"
    @State private var paused = false
    @State private var selected = "Indoor Run"
    @State private var distance = "2.40"
    private let capture = ProcessInfo.processInfo.environment["CARDIO_CAPTURE"] == "1"
    private var large: Bool { typeSize.isAccessibilitySize }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch screen {
                    case "start": start
                    case "picker": picker
                    case "gym": gym
                    case "outdoor": outdoor
                    case "summary": summary
                    default: mixed
                    }
                }
                .padding(18)
                .padding(.bottom, 12)
            }
            .background(Theme.background)
            .foregroundStyle(Theme.text)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(screen == "start" || screen == "picker" ? .large : .inline)
            .toolbar {
                if screen != "start" {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { screen = "start" } label: { Image(systemName: "chevron.down") }
                            .tint(Theme.secondary)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(screen == "summary" ? "Done" : screen == "picker" ? "Cancel" : "Finish") {
                            screen = screen == "summary" || screen == "picker" ? "start" : "summary"
                        }.tint(Theme.text)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if screen == "start" { tabBar }
                else if screen == "gym" || screen == "outdoor" { cardioControls }
                else if screen == "mixed" {
                    if !capture { variantSwitcher }
                    else { addActivity }
                }
            }
            .accessibilityIdentifier("cardioPrototype.\(screen).\(variant)")
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
    }

    private var title: String {
        switch screen {
        case "start": "Workout"
        case "picker": "Choose Cardio"
        case "gym": selected
        case "outdoor": "Outdoor Run"
        case "summary": "Nice work"
        default: "Evening Workout"
        }
    }

    private var start: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Label("Noyes Fitness Center", systemImage: "mappin.and.ellipse")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 4)
                Image(systemName: "chevron.down").font(.caption)
            }.padding(18).card()
            VStack(spacing: 12) {
                Button { screen = "mixed" } label: {
                    Label("Start Lifting", systemImage: "dumbbell.fill")
                        .frame(maxWidth: .infinity)
                }.buttonStyle(.primary)
                Button { screen = "picker" } label: {
                    Label("Start Cardio", systemImage: "figure.run")
                        .frame(maxWidth: .infinity)
                }.buttonStyle(.secondary)
            }
            HStack {
                Text("Templates").font(.title2.bold())
                Spacer()
                Button { } label: { Image(systemName: "plus") }
            }
            VStack(alignment: .leading, spacing: 14) {
                Text("Upper Body").font(Theme.cardTitle)
                Text("Bench Press, Seated Row, Overhead Press")
                    .font(.subheadline).foregroundStyle(Theme.secondary)
                HStack {
                    Text("5 exercises").font(.caption).foregroundStyle(Theme.secondary)
                    Spacer()
                    Button("Start") { screen = "mixed" }.buttonStyle(.bordered).tint(Theme.accent)
                }
            }.padding(18).card()
            VStack(alignment: .leading, spacing: 10) {
                Text("Lower Body").font(Theme.cardTitle)
                Text("Squat, Romanian Deadlift, Leg Curl")
                    .font(.subheadline).foregroundStyle(Theme.secondary)
                Text("4 exercises").font(.caption).foregroundStyle(Theme.secondary)
            }.padding(18).card()
        }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "magnifyingglass")
                Text("Search activities")
                Spacer()
            }.foregroundStyle(Theme.secondary).padding(13)
                .background(Theme.fill, in: RoundedRectangle(cornerRadius: 12))
            Text("Gym").font(.headline)
            VStack(spacing: 0) {
                activity("Indoor Walk", "figure.walk", "gym")
                activity("Indoor Run", "figure.run", "gym")
                activity("Indoor Cycle", "figure.indoor.cycle", "gym")
                activity("Elliptical", "figure.elliptical", "gym")
                activity("Rowing", "figure.rower", "gym")
                activity("Stair Stepper", "figure.stair.stepper", "gym", last: true)
            }.background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
            Text("Outdoors").font(.headline)
            VStack(spacing: 0) {
                activity("Outdoor Walk", "figure.walk", "outdoor")
                activity("Outdoor Run", "figure.run", "outdoor")
                activity("Outdoor Cycle", "figure.outdoor.cycle", "outdoor", last: true)
            }.background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func activity(_ name: String, _ symbol: String, _ destination: String, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            Button {
                selected = name
                screen = destination
            } label: {
                HStack(spacing: 15) {
                    Image(systemName: symbol).font(.title2).frame(width: 28)
                    Text(name).font(.body.weight(.medium))
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.secondary)
                }.foregroundStyle(Theme.text).padding(16).frame(minHeight: 55)
            }.buttonStyle(.plain)
            if !last { Divider().overlay(Theme.hairline).padding(.leading, 59) }
        }
    }

    private var sessionHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Label("Noyes Fitness Center", systemImage: "mappin.and.ellipse").font(.caption)
                    Spacer(minLength: 8)
                    Text("1:23:15").font(Theme.stat).foregroundStyle(Theme.text)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Label("Noyes Fitness Center", systemImage: "mappin.and.ellipse").font(.caption)
                    Text("1:23:15").font(Theme.stat).foregroundStyle(Theme.text)
                }
            }
        }.foregroundStyle(Theme.secondary)
    }

    private var mixed: some View {
        VStack(alignment: .leading, spacing: 20) {
            sessionHeader
            switch variant {
            case "B": focusedMixed
            case "C": timelineMixed
            default: inlineMixed
            }
        }
    }

    private var inlineMixed: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Lifting").font(Theme.cardTitle)
                Spacer()
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.secondary)
                Text("18/18 sets").font(.caption).foregroundStyle(Theme.secondary)
            }
            liftingSummary
            HStack {
                Text("Cardio").font(Theme.cardTitle)
                Spacer()
                Text("In progress").font(.caption).foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label("Indoor Run", systemImage: "figure.run").font(Theme.cardTitle)
                    Spacer()
                    Button { screen = "gym" } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                }
                timer("14:32")
                metrics([("Heart rate", "142", "bpm"), ("Active calories", "93", "cal")])
                distanceRow
                HStack(spacing: 12) {
                    Button(paused ? "Resume" : "Pause") { paused.toggle() }.buttonStyle(.secondary)
                    Button("End Cardio") { screen = "summary" }.buttonStyle(.secondary)
                }.frame(maxWidth: .infinity)
            }.padding(18).card()
        }
    }

    private var focusedMixed: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 0) {
                Text("Lifting  ✓").foregroundStyle(Theme.secondary).frame(maxWidth: .infinity)
                Text("Cardio").foregroundStyle(Theme.onAccent).frame(maxWidth: .infinity)
                    .padding(.vertical, 10).background(Theme.accent, in: Capsule())
            }.font(.subheadline.weight(.semibold)).padding(4).background(Theme.fill, in: Capsule())
            Label("Indoor Run", systemImage: "figure.run").font(.title2.bold())
            timer("14:32")
            metrics([("Heart rate", "142", "bpm"), ("Active calories", "93", "cal")])
            distanceRow
            HStack(spacing: 12) {
                Button(paused ? "Resume" : "Pause") { paused.toggle() }.buttonStyle(.secondary)
                Button("End Cardio") { screen = "summary" }.buttonStyle(.secondary)
            }
            Divider().overlay(Theme.hairline)
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Lifting completed").font(.headline)
                    Text("6 exercises · 18 sets").font(.subheadline).foregroundStyle(Theme.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.secondary)
            }
        }
    }

    private var timelineMixed: some View {
        VStack(alignment: .leading, spacing: 0) {
            timelineItem("20:00", "Indoor Walk", detail: "8:00 · 0.60 km", symbol: "figure.walk", active: false)
            timelineItem("20:08", "Lifting", detail: "6 exercises · 18/18 sets", symbol: "dumbbell.fill", active: false)
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 8) {
                    Circle().fill(Theme.accent).frame(width: 12, height: 12)
                    Rectangle().fill(Theme.hairline).frame(width: 2)
                }.frame(width: 18)
                VStack(alignment: .leading, spacing: 18) {
                    Text("21:09 · In progress").font(.caption).foregroundStyle(Theme.secondary)
                    Label("Indoor Run", systemImage: "figure.run").font(.title2.bold())
                    timer("14:32")
                    metrics([("Heart rate", "142", "bpm"), ("Active calories", "93", "cal")])
                    distanceRow
                    Button(paused ? "Resume" : "Pause") { paused.toggle() }.buttonStyle(.secondary)
                    Button("End Cardio") { screen = "summary" }.buttonStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func timelineItem(_ time: String, _ name: String, detail: String, symbol: String, active: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.secondary)
                Rectangle().fill(Theme.hairline).frame(width: 2, height: 60)
            }.frame(width: 18)
            VStack(alignment: .leading, spacing: 7) {
                Text(time).font(.caption).foregroundStyle(Theme.secondary)
                Label(name, systemImage: symbol).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(Theme.secondary)
            }
            Spacer(minLength: 0)
        }.padding(.bottom, 12)
    }

    private var liftingSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("6 exercises").font(.headline)
                    Text("Bench Press, Seated Row, Overhead Press…")
                        .font(.subheadline).foregroundStyle(Theme.secondary)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.down").foregroundStyle(Theme.secondary)
            }
            HStack {
                Text("1:08:43").monospacedDigit()
                Spacer()
                Text("8,420 lb volume")
            }.font(.caption).foregroundStyle(Theme.secondary)
        }.padding(18).card()
    }

    private var gym: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Label("Noyes Fitness Center", systemImage: "mappin.and.ellipse")
                Spacer()
            }.font(.subheadline).foregroundStyle(Theme.secondary)
            timer("14:32")
            metrics([("Heart rate", "142", "bpm"), ("Active calories", "93", "cal")])
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Zone 2").font(.headline).foregroundStyle(Theme.unitKg)
                    Spacer()
                    Text("AirPods").font(.caption).foregroundStyle(Theme.secondary)
                }
                HeartRateDesignChart()
                    .frame(height: 88)
            }.padding(18).card()
            distanceRow
            if !large { Spacer(minLength: 10) }
            HStack {
                Image(systemName: "dumbbell.fill")
                Text("Lifting · 18 sets completed")
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
            }.font(.subheadline).foregroundStyle(Theme.secondary)
        }
    }

    private var outdoor: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Label("GPS", systemImage: "location.fill").foregroundStyle(Theme.secondary)
                Spacer()
                Text(paused ? "Paused" : "Recording").foregroundStyle(Theme.accent)
            }.font(.caption.weight(.semibold))
            timer("25:18")
            metrics([("Distance", "4.20", "km"), ("Current pace", "6:01", "/km")])
            CardioRouteDesignMap().frame(height: large ? 180 : 205)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            metrics([("Heart rate", "148", "bpm"), ("Active calories", "281", "cal")])
            HStack {
                Text("Zone 3").foregroundStyle(Theme.warmup)
                Spacer()
                Text("AirPods").foregroundStyle(Theme.secondary)
            }.font(.subheadline)
        }
    }

    private func timer(_ time: String) -> some View {
        VStack(spacing: 7) {
            Text(paused ? "Paused" : "Time").font(.subheadline).foregroundStyle(Theme.secondary)
            Text(time).font(Theme.hero).monospacedDigit().foregroundStyle(Theme.text)
        }.frame(maxWidth: .infinity).padding(.vertical, 8)
    }

    private func metrics(_ values: [(String, String, String)]) -> some View {
        let columns = large ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
            ForEach(values, id: \.0) { value in
                VStack(alignment: .leading, spacing: 7) {
                    Text(value.0).font(.caption).foregroundStyle(Theme.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(value.1).font(Theme.stat).monospacedDigit()
                        Text(value.2).font(.subheadline).foregroundStyle(Theme.secondary)
                    }.foregroundStyle(value.0 == "Heart rate" ? Theme.danger : Theme.text)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var distanceRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Machine distance").font(.caption).foregroundStyle(Theme.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField("Distance", text: $distance).keyboardType(.decimalPad).font(Theme.stat)
                Text("km").font(.subheadline).foregroundStyle(Theme.secondary)
                Image(systemName: "pencil").foregroundStyle(Theme.secondary)
            }
        }.padding(18).background(Theme.fill, in: RoundedRectangle(cornerRadius: 16))
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(Theme.accent, lineWidth: 5)
                    Image(systemName: "checkmark").font(.title2.bold()).foregroundStyle(Theme.accent)
                }.frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Workout saved").font(.title2.bold())
                    Text("Lifting + Indoor Run").font(.subheadline).foregroundStyle(Theme.secondary)
                }
            }.padding(18).card()
            Button("View in History") { }.buttonStyle(.primary)
            Text("Workout details").font(.headline)
            metrics([("Workout time", "1:23:15", ""), ("Total volume", "8,420", "lb"),
                     ("Active calories", "436", "cal"), ("Total calories", "532", "cal"),
                     ("Avg. heart rate", "128", "bpm"), ("Max heart rate", "157", "bpm")])
                .padding(18).card()
            HStack {
                Text("Lifting").font(.headline)
                Spacer()
                Text("18 sets").font(.caption).foregroundStyle(Theme.secondary)
            }
            liftingSummary
            Text("Cardio").font(.headline)
            VStack(alignment: .leading, spacing: 16) {
                Label("Indoor Run", systemImage: "figure.run").font(.headline)
                metrics([("Time", "14:32", ""), ("Distance", "2.40", "km"),
                         ("Avg. heart rate", "142", "bpm"), ("Active calories", "93", "cal")])
            }.padding(18).card()
        }
    }

    private var cardioControls: some View {
        HStack(spacing: 12) {
            Button { paused.toggle() } label: {
                Label(paused ? "Resume" : "Pause", systemImage: paused ? "play.fill" : "pause.fill")
                    .frame(maxWidth: .infinity)
            }.buttonStyle(.primary)
            Button("End Cardio") { screen = "mixed" }
                .buttonStyle(.secondary)
        }.padding(18).background(Theme.background)
    }

    private var addActivity: some View {
        HStack(spacing: 12) {
            Button { } label: { Label("Add Exercise", systemImage: "plus") }.buttonStyle(.secondary)
            Button { screen = "picker" } label: { Label("Add Cardio", systemImage: "plus") }.buttonStyle(.secondary)
        }.padding(16).frame(maxWidth: .infinity).background(Theme.background)
    }

    private var tabBar: some View {
        HStack {
            tab("Workout", "dumbbell.fill", true)
            tab("History", "clock", false)
            tab("Exercises", "figure.strengthtraining.traditional", false)
            tab("Gyms", "building.2", false)
            tab("Settings", "gearshape", false)
        }.padding(.top, 12).padding(.bottom, 5).background(Theme.elevated)
    }

    private func tab(_ label: String, _ symbol: String, _ selected: Bool) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol).font(.title3)
            Text(label).font(.caption2)
        }.foregroundStyle(selected ? Theme.accent : Theme.secondary).frame(maxWidth: .infinity)
    }

    private var variantSwitcher: some View {
        HStack {
            Button { variant = variant == "A" ? "C" : variant == "B" ? "A" : "B" } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text("Prototype \(variant)").font(.caption.bold())
            Spacer()
            Button { variant = variant == "C" ? "A" : variant == "A" ? "B" : "C" } label: {
                Image(systemName: "chevron.right")
            }
        }.padding(16).background(Theme.elevated)
    }
}

private struct HeartRateDesignChart: View {
    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<48) { i in
                    Capsule().fill(Theme.danger.opacity(0.8))
                        .frame(height: CGFloat(14 + (i * 17 % 31)))
                        .offset(y: CGFloat(18 - (i * 7 % 35)))
                }
            }.frame(width: proxy.size.width, height: proxy.size.height)
        }.accessibilityLabel("Sample heart-rate chart")
    }
}

private struct CardioRouteDesignMap: View {
    private let route: [CLLocationCoordinate2D] = [
        .init(latitude: 40.7725, longitude: -73.9744),
        .init(latitude: 40.7738, longitude: -73.9770),
        .init(latitude: 40.7786, longitude: -73.9743),
        .init(latitude: 40.7813, longitude: -73.9714),
        .init(latitude: 40.7826, longitude: -73.9674),
        .init(latitude: 40.7794, longitude: -73.9660),
        .init(latitude: 40.7758, longitude: -73.9682),
        .init(latitude: 40.7733, longitude: -73.9714)
    ]
    var body: some View {
        Map(initialPosition: .region(.init(center: .init(latitude: 40.7775, longitude: -73.9714),
                                          span: .init(latitudeDelta: 0.017, longitudeDelta: 0.020))),
            interactionModes: []) {
            MapPolyline(coordinates: route).stroke(Theme.accent, lineWidth: 4)
            Annotation("Start", coordinate: route[0]) {
                Circle().fill(Theme.accent).frame(width: 10, height: 10).overlay(Circle().stroke(.white, lineWidth: 2))
            }
            Annotation("Now", coordinate: route[7]) {
                Circle().fill(Theme.unitKg).frame(width: 12, height: 12).overlay(Circle().stroke(.white, lineWidth: 2))
            }
        }.mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .accessibilityLabel("Illustrative run route in Central Park")
    }
}

#Preview("Mixed workout — A") { CardioDesignPrototype() }
#endif
