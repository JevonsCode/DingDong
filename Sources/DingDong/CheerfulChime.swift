import Foundation

enum CheerfulChime {
    static let sampleRate = 44_100

    static func data(for sound: DingSound) -> Data? {
        switch sound {
        case .joy:
            makeWAV(notes: [
                Note(frequency: 523.25, start: 0.00, duration: 0.16, gain: 0.46),
                Note(frequency: 659.25, start: 0.10, duration: 0.17, gain: 0.42),
                Note(frequency: 783.99, start: 0.22, duration: 0.24, gain: 0.38),
                Note(frequency: 1046.50, start: 0.37, duration: 0.18, gain: 0.26)
            ])
        case .levelUp:
            makeWAV(notes: [
                Note(frequency: 392.00, start: 0.00, duration: 0.12, gain: 0.42),
                Note(frequency: 493.88, start: 0.09, duration: 0.14, gain: 0.40),
                Note(frequency: 587.33, start: 0.18, duration: 0.16, gain: 0.38),
                Note(frequency: 783.99, start: 0.32, duration: 0.24, gain: 0.34),
                Note(frequency: 987.77, start: 0.45, duration: 0.16, gain: 0.24)
            ])
        case .taDa:
            makeWAV(notes: [
                Note(frequency: 523.25, start: 0.00, duration: 0.13, gain: 0.38),
                Note(frequency: 659.25, start: 0.10, duration: 0.14, gain: 0.36),
                Note(frequency: 783.99, start: 0.20, duration: 0.16, gain: 0.34),
                Note(frequency: 1046.50, start: 0.30, duration: 0.28, gain: 0.32),
                Note(frequency: 1318.51, start: 0.40, duration: 0.20, gain: 0.18)
            ])
        case .bubble:
            makeWAV(notes: [
                Note(frequency: 740.00, start: 0.00, duration: 0.10, gain: 0.34),
                Note(frequency: 880.00, start: 0.08, duration: 0.11, gain: 0.32),
                Note(frequency: 1046.50, start: 0.17, duration: 0.12, gain: 0.30),
                Note(frequency: 1174.66, start: 0.27, duration: 0.12, gain: 0.24),
                Note(frequency: 1396.91, start: 0.38, duration: 0.16, gain: 0.18)
            ])
        case .coin:
            makeWAV(notes: [
                Note(frequency: 987.77, start: 0.00, duration: 0.09, gain: 0.34),
                Note(frequency: 1318.51, start: 0.07, duration: 0.12, gain: 0.36),
                Note(frequency: 1760.00, start: 0.16, duration: 0.17, gain: 0.22)
            ])
        case .fanfare:
            makeWAV(notes: [
                Note(frequency: 392.00, start: 0.00, duration: 0.14, gain: 0.38),
                Note(frequency: 523.25, start: 0.10, duration: 0.16, gain: 0.38),
                Note(frequency: 659.25, start: 0.20, duration: 0.18, gain: 0.36),
                Note(frequency: 783.99, start: 0.30, duration: 0.24, gain: 0.32),
                Note(frequency: 1046.50, start: 0.42, duration: 0.26, gain: 0.24)
            ])
        case .arcade:
            makeWAV(notes: [
                Note(frequency: 523.25, start: 0.00, duration: 0.08, gain: 0.34),
                Note(frequency: 659.25, start: 0.08, duration: 0.08, gain: 0.34),
                Note(frequency: 783.99, start: 0.16, duration: 0.08, gain: 0.34),
                Note(frequency: 1046.50, start: 0.24, duration: 0.12, gain: 0.30),
                Note(frequency: 1318.51, start: 0.34, duration: 0.14, gain: 0.22)
            ])
        case .bloom:
            makeWAV(notes: [
                Note(frequency: 349.23, start: 0.00, duration: 0.24, gain: 0.28),
                Note(frequency: 440.00, start: 0.08, duration: 0.26, gain: 0.30),
                Note(frequency: 523.25, start: 0.18, duration: 0.28, gain: 0.30),
                Note(frequency: 659.25, start: 0.30, duration: 0.30, gain: 0.24),
                Note(frequency: 880.00, start: 0.46, duration: 0.22, gain: 0.16)
            ])
        case .sunrise:
            makeWAV(notes: [
                Note(frequency: 329.63, start: 0.00, duration: 0.18, gain: 0.30),
                Note(frequency: 392.00, start: 0.09, duration: 0.20, gain: 0.32),
                Note(frequency: 493.88, start: 0.20, duration: 0.22, gain: 0.34),
                Note(frequency: 659.25, start: 0.34, duration: 0.24, gain: 0.28),
                Note(frequency: 987.77, start: 0.48, duration: 0.18, gain: 0.18)
            ])
        case .popcorn:
            makeWAV(notes: [
                Note(frequency: 783.99, start: 0.00, duration: 0.07, gain: 0.30),
                Note(frequency: 1046.50, start: 0.06, duration: 0.07, gain: 0.34),
                Note(frequency: 659.25, start: 0.13, duration: 0.07, gain: 0.28),
                Note(frequency: 1174.66, start: 0.20, duration: 0.08, gain: 0.34),
                Note(frequency: 880.00, start: 0.29, duration: 0.08, gain: 0.30),
                Note(frequency: 1396.91, start: 0.38, duration: 0.12, gain: 0.22)
            ])
        case .glimmer:
            makeWAV(notes: [
                Note(frequency: 1174.66, start: 0.00, duration: 0.10, gain: 0.22),
                Note(frequency: 1567.98, start: 0.08, duration: 0.12, gain: 0.24),
                Note(frequency: 1318.51, start: 0.18, duration: 0.12, gain: 0.22),
                Note(frequency: 1760.00, start: 0.29, duration: 0.16, gain: 0.20),
                Note(frequency: 2093.00, start: 0.42, duration: 0.14, gain: 0.14)
            ])
        case .rocket:
            makeWAV(notes: [
                Note(frequency: 440.00, start: 0.00, duration: 0.10, gain: 0.32),
                Note(frequency: 554.37, start: 0.08, duration: 0.11, gain: 0.34),
                Note(frequency: 659.25, start: 0.16, duration: 0.12, gain: 0.34),
                Note(frequency: 880.00, start: 0.26, duration: 0.14, gain: 0.32),
                Note(frequency: 1318.51, start: 0.38, duration: 0.18, gain: 0.22),
                Note(frequency: 1760.00, start: 0.50, duration: 0.16, gain: 0.16)
            ])
        case .confetti:
            makeWAV(notes: [
                Note(frequency: 523.25, start: 0.00, duration: 0.08, gain: 0.28),
                Note(frequency: 783.99, start: 0.04, duration: 0.08, gain: 0.28),
                Note(frequency: 659.25, start: 0.11, duration: 0.09, gain: 0.30),
                Note(frequency: 1046.50, start: 0.16, duration: 0.10, gain: 0.32),
                Note(frequency: 880.00, start: 0.25, duration: 0.09, gain: 0.28),
                Note(frequency: 1318.51, start: 0.31, duration: 0.12, gain: 0.26),
                Note(frequency: 1567.98, start: 0.42, duration: 0.16, gain: 0.18)
            ])
        case .marimba:
            makeWAV(notes: [
                Note(frequency: 392.00, start: 0.00, duration: 0.12, gain: 0.34),
                Note(frequency: 493.88, start: 0.08, duration: 0.12, gain: 0.34),
                Note(frequency: 587.33, start: 0.17, duration: 0.12, gain: 0.32),
                Note(frequency: 783.99, start: 0.26, duration: 0.14, gain: 0.30),
                Note(frequency: 987.77, start: 0.38, duration: 0.16, gain: 0.24),
                Note(frequency: 1174.66, start: 0.50, duration: 0.14, gain: 0.16)
            ])
        case .candy:
            makeWAV(notes: [
                Note(frequency: 659.25, start: 0.00, duration: 0.10, gain: 0.28),
                Note(frequency: 880.00, start: 0.07, duration: 0.10, gain: 0.30),
                Note(frequency: 987.77, start: 0.15, duration: 0.12, gain: 0.30),
                Note(frequency: 1318.51, start: 0.25, duration: 0.12, gain: 0.26),
                Note(frequency: 1174.66, start: 0.35, duration: 0.13, gain: 0.22),
                Note(frequency: 1760.00, start: 0.48, duration: 0.16, gain: 0.16)
            ])
        default:
            nil
        }
    }

    private static func makeWAV(notes: [Note]) -> Data {
        let totalDuration = (notes.map { $0.start + $0.duration }.max() ?? 0) + 0.08
        let frameCount = max(1, Int(totalDuration * Double(sampleRate)))
        var samples = Array(repeating: 0.0, count: frameCount)

        for note in notes {
            mix(note, into: &samples)
        }

        let peak = samples.map(abs).max() ?? 1
        let normalization = peak > 0 ? min(0.92 / peak, 1.0) : 1.0
        let pcm = samples.map { sample -> Int16 in
            let clamped = max(-1.0, min(1.0, sample * normalization))
            return Int16(clamped * Double(Int16.max))
        }

        return wavData(pcm: pcm)
    }

    private static func mix(_ note: Note, into samples: inout [Double]) {
        let startFrame = max(0, Int(note.start * Double(sampleRate)))
        let noteFrames = max(1, Int(note.duration * Double(sampleRate)))
        let endFrame = min(samples.count, startFrame + noteFrames)
        guard startFrame < endFrame else {
            return
        }

        for frame in startFrame..<endFrame {
            let localFrame = frame - startFrame
            let progress = Double(localFrame) / Double(noteFrames)
            let time = Double(localFrame) / Double(sampleRate)
            let envelope = envelope(progress)
            let tone = sin(2 * .pi * note.frequency * time)
            let shimmer = 0.32 * sin(2 * .pi * note.frequency * 2.01 * time)
            samples[frame] += (tone + shimmer) * note.gain * envelope
        }
    }

    private static func envelope(_ progress: Double) -> Double {
        let attack = min(progress / 0.12, 1)
        let release = min((1 - progress) / 0.34, 1)
        return max(0, min(attack, release))
    }

    private static func wavData(pcm: [Int16]) -> Data {
        let channelCount = UInt16(1)
        let bitsPerSample = UInt16(16)
        let byteRate = UInt32(sampleRate) * UInt32(channelCount) * UInt32(bitsPerSample / 8)
        let blockAlign = channelCount * (bitsPerSample / 8)
        let dataSize = UInt32(pcm.count * MemoryLayout<Int16>.size)
        let riffSize = UInt32(36) + dataSize

        var data = Data()
        data.appendASCII("RIFF")
        data.appendLittleEndian(riffSize)
        data.appendASCII("WAVE")
        data.appendASCII("fmt ")
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(channelCount)
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(byteRate)
        data.appendLittleEndian(blockAlign)
        data.appendLittleEndian(bitsPerSample)
        data.appendASCII("data")
        data.appendLittleEndian(dataSize)

        for sample in pcm {
            data.appendLittleEndian(UInt16(bitPattern: sample))
        }

        return data
    }
}

private struct Note {
    var frequency: Double
    var start: Double
    var duration: Double
    var gain: Double
}

private extension Data {
    mutating func appendASCII(_ string: String) {
        append(contentsOf: string.utf8)
    }

    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
            append(contentsOf: bytes)
        }
    }
}
