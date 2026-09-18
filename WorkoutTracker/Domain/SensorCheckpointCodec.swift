import Foundation

/// Append-only JSON lines avoid re-encoding hours of heartbeats for every new
/// sample. The checkpoint is transient; finished workouts keep their frozen fold.
enum SensorCheckpointCodec {
    static func decode(_ data: Data?) -> [HeartRateSample] {
        guard let data, !data.isEmpty else { return [] }
        // Accept the initial development array format too.
        if data.first == 0x5B { return (try? JSONDecoder().decode([HeartRateSample].self, from: data)) ?? [] }
        return data.split(separator: 0x0A).compactMap { try? JSONDecoder().decode(HeartRateSample.self, from: Data($0)) }
    }
    static func encode(_ samples: [HeartRateSample]) throws -> Data {
        var result = Data()
        try append(samples, to: &result)
        return result
    }
    static func append<S: Sequence>(_ samples: S, to data: inout Data) throws where S.Element == HeartRateSample {
        let encoder = JSONEncoder()
        for sample in samples {
            data.append(try encoder.encode(sample))
            data.append(0x0A)
        }
    }
}
