import Foundation

// Gym feedback, 2026-08-24 — the rest alarm was seen and never heard.
//
// WHY THIS FILE EXISTS AT ALL: the rest timer already fires a local
// notification with `UNNotificationSound.default`, and the user confirmed the
// notification arrives, screen off included. But a notification sound plays on
// the phone's ALERT route — it does not go to connected AirPods. Wearing
// earbuds mid-set, you get a silent banner you cannot see because the phone is
// on the floor.
//
// The only way to put a sound in the user's ears is for the app to play real
// audio through the shared audio session, which means the app needs a waveform.
// Synthesising it here rather than shipping an .aiff keeps the repo's
// no-binary-assets habit and — more usefully — makes the tone testable: a
// silent or malformed buffer is a bug you can catch in CI instead of in a gym.

/// One element of an alarm pattern: a tone, or a gap between tones.
struct AlarmBeep: Equatable, Sendable {
    /// Hertz. Zero means silence for `seconds`.
    let hertz: Double
    let seconds: Double

    static func tone(_ hertz: Double, _ seconds: Double) -> AlarmBeep {
        AlarmBeep(hertz: hertz, seconds: seconds)
    }

    static func gap(_ seconds: Double) -> AlarmBeep {
        AlarmBeep(hertz: 0, seconds: seconds)
    }
}

/// Which alarm this is. The two rest endings sound different on purpose.
///
/// D43 lets a rest end two ways — the heart rate came down, or the four-minute
/// cap ran out — and the difference matters to the lifter: recovered means go,
/// capped means you did not recover and the app stopped waiting. The
/// notification text already distinguishes them. Mid-set with the phone on the
/// floor, the sound is the only channel that reaches you, so it distinguishes
/// them too.
enum RestAlarmPattern: Equatable, Sendable, CaseIterable {
    /// Heart rate recovered: two rising tones. Reads as "ready".
    case recovered
    /// The cap expired: three flat tones. Reads as "time".
    case cap

    var beeps: [AlarmBeep] {
        switch self {
        case .recovered:
            [.tone(880, 0.12), .gap(0.06), .tone(1175, 0.18)]
        case .cap:
            [.tone(880, 0.12), .gap(0.08), .tone(880, 0.12), .gap(0.08), .tone(880, 0.2)]
        }
    }
}

enum RestAlarmTone {

    static let sampleRate: Double = 44_100
    /// Loud enough to hear over gym noise and your own music, short enough not
    /// to be obnoxious. Full scale would clip against ducked music.
    static let amplitude: Double = 0.85
    /// Each tone ramps in and out over this long. Without it every beep starts
    /// and ends on a discontinuity, which is audible as a click — the sound a
    /// user reads as "the app is broken".
    static let fadeSeconds: Double = 0.005

    /// 16-bit mono PCM samples for a pattern.
    static func samples(
        for pattern: RestAlarmPattern, sampleRate: Double = RestAlarmTone.sampleRate
    ) -> [Int16] {
        var out: [Int16] = []
        for beep in pattern.beeps {
            let count = Int((beep.seconds * sampleRate).rounded())
            guard count > 0 else { continue }
            if beep.hertz <= 0 {
                out.append(contentsOf: repeatElement(0, count: count))
                continue
            }
            let fade = max(1, Int(fadeSeconds * sampleRate))
            for index in 0..<count {
                let time = Double(index) / sampleRate
                let wave = sin(2 * .pi * beep.hertz * time)
                // Linear ramp at both ends; `fade` is clamped so a beep shorter
                // than two fades still tapers instead of inverting.
                let ramp: Double
                if count < fade * 2 {
                    ramp = Double(min(index, count - 1 - index)) / Double(max(1, count / 2))
                } else if index < fade {
                    ramp = Double(index) / Double(fade)
                } else if index >= count - fade {
                    ramp = Double(count - 1 - index) / Double(fade)
                } else {
                    ramp = 1
                }
                let value = wave * amplitude * max(0, min(1, ramp))
                out.append(Int16(clamping: Int(value * Double(Int16.max))))
            }
        }
        return out
    }

    /// A complete WAV file for a pattern, ready to hand to `AVAudioPlayer`.
    ///
    /// Built by hand because the alternative is shipping two audio files and
    /// trusting they were encoded right. 44-byte canonical PCM header.
    static func wav(
        for pattern: RestAlarmPattern, sampleRate: Double = RestAlarmTone.sampleRate
    ) -> Data {
        let pcm = samples(for: pattern, sampleRate: sampleRate)
        let bitsPerSample: UInt16 = 16
        let channels: UInt16 = 1
        let rate = UInt32(sampleRate)
        let byteRate = rate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataBytes = UInt32(pcm.count * MemoryLayout<Int16>.size)

        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        data.append(littleEndian: UInt32(36) + dataBytes)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        data.append(littleEndian: UInt32(16))
        data.append(littleEndian: UInt16(1))       // PCM, uncompressed
        data.append(littleEndian: channels)
        data.append(littleEndian: rate)
        data.append(littleEndian: byteRate)
        data.append(littleEndian: blockAlign)
        data.append(littleEndian: bitsPerSample)
        data.append(contentsOf: Array("data".utf8))
        data.append(littleEndian: dataBytes)
        for sample in pcm { data.append(littleEndian: UInt16(bitPattern: sample)) }
        return data
    }
}

private extension Data {
    // `Swift.` qualified deliberately: inside a Data extension, a bare
    // `withUnsafeBytes` resolves to Data's own instance method, not the global
    // one that takes a value.
    mutating func append(littleEndian value: UInt16) {
        append(contentsOf: Swift.withUnsafeBytes(of: value.littleEndian, Array.init))
    }

    mutating func append(littleEndian value: UInt32) {
        append(contentsOf: Swift.withUnsafeBytes(of: value.littleEndian, Array.init))
    }
}
