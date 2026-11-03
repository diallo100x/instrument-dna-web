import Foundation
import AVFoundation

/// DNAi's first offline, deterministic note slicer. Never invoke from the audio render callback.
struct DNAiSlice: Codable, Equatable {
    var startFrame: Int
    var endFrame: Int
    var midiNote: Int?
    var cents: Double?
    var confidence: Double
    var source: String = "recorded"
}

enum DNAiSliceError: Error {
    case emptyAudio
    case unsupportedFormat
}

enum DNAiIntelligentSlicer {
    /// Load and analyze a local PCM-compatible audio file. Call on a background queue.
    static func analyze(url: URL, startSeconds: Double = 0, endSeconds: Double? = nil) throws -> [DNAiSlice] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        guard format.commonFormat == .pcmFormatFloat32, format.isInterleaved == false,
              format.sampleRate > 0 else { throw DNAiSliceError.unsupportedFormat }
        let count = Int(file.length)
        guard count > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else {
            throw DNAiSliceError.emptyAudio
        }
        try file.read(into: buffer)
        guard let channels = buffer.floatChannelData else { throw DNAiSliceError.unsupportedFormat }
        let length = Int(buffer.frameLength)
        let lo = max(0, min(length, Int(startSeconds * format.sampleRate)))
        let hi = max(lo, min(length, Int((endSeconds ?? Double(length) / format.sampleRate) * format.sampleRate)))
        let channelCount = Int(format.channelCount)
        var mono = [Float](repeating: 0, count: hi - lo)
        for ch in 0..<channelCount {
            for i in 0..<mono.count { mono[i] += channels[ch][lo+i] / Float(channelCount) }
        }
        return analyze(samples: mono, sampleRate: format.sampleRate).map {
            var result = $0
            result.startFrame += lo
            result.endFrame += lo
            return result
        }
    }

    /// Pure sample-array entry point for unit tests and eventual iPad parity.
    static func analyze(samples: [Float], sampleRate: Double) -> [DNAiSlice] {
        guard sampleRate > 0, samples.count >= 1024 else { return [] }
        let hop = max(128, Int(sampleRate * 0.010))
        let window = max(1024, Int(sampleRate * 0.040))
        guard samples.count >= window else { return [] }
        var rms = [Double]()
        var starts = [Int]()
        for pos in stride(from: 0, through: samples.count-window, by: hop) {
            var power = 0.0
            for i in pos..<(pos+window) {
                let v = Double(samples[i]); power += v*v
            }
            rms.append(sqrt(power/Double(window)))
            starts.append(pos)
        }
        guard let peak = rms.max(), peak > 0.0001 else { return [] }
        let threshold = max(0.0005, peak * 0.075)
        var boundaries = [Int]()
        var active = false
        var lastOnset = -window
        for i in rms.indices {
            let loud = rms[i] >= threshold
            let previous = i > 0 ? rms[i-1] : 0
            let onset = loud && (!active || (rms[i] > previous * 1.9 && rms[i] > peak * 0.13))
            if onset && starts[i] - lastOnset >= Int(sampleRate * 0.085) {
                boundaries.append(starts[i])
                lastOnset = starts[i]
            }
            active = loud
        }
        guard !boundaries.isEmpty else { return [] }
        var slices = [DNAiSlice]()
        for (index, start) in boundaries.enumerated() {
            let end = index+1 < boundaries.count ? boundaries[index+1] : samples.count
            guard end-start >= Int(sampleRate * 0.06) else { continue }
            let offset = min(end, start + Int(sampleRate * 0.035))
            let limit = min(end, offset + Int(sampleRate * 0.20))
            let result = estimatePitch(samples: samples, from: offset, to: limit, sampleRate: sampleRate)
            slices.append(DNAiSlice(startFrame: start, endFrame: end, midiNote: result?.0,
                                    cents: result?.1, confidence: result?.2 ?? 0))
        }
        return slices
    }

    /// Normalized autocorrelation with a confidence floor. Designed as a baseline,
    /// not a trained polyphonic pitch detector.
    static func estimatePitch(samples: [Float], from: Int, to: Int, sampleRate: Double) -> (Int, Double, Double)? {
        let low = max(0, from), high = min(samples.count, to)
        let count = high-low
        let minLag = max(2, Int(sampleRate / 1400))
        let maxLag = min(count/2, Int(sampleRate / 35))
        guard maxLag > minLag, count > 2*maxLag else { return nil }
        var bestLag = 0
        var best = 0.0
        for lag in minLag...maxLag {
            var dot = 0.0, a = 0.0, b = 0.0
            let length = min(count-lag, 4096)
            for j in 0..<length {
                let x = Double(samples[low+j]), y = Double(samples[low+j+lag])
                dot += x*y; a += x*x; b += y*y
            }
            let score = dot / sqrt(max(1e-16, a*b))
            if score > best { best = score; bestLag = lag }
        }
        guard bestLag > 0, best >= 0.72 else { return nil }
        // Select the shortest lag that has nearly the same correlation to reduce octave errors.
        var chosen = bestLag
        for lag in minLag..<bestLag {
            var dot = 0.0, a = 0.0, b = 0.0
            let length = min(count-lag, 4096)
            for j in 0..<length {
                let x = Double(samples[low+j]), y = Double(samples[low+j+lag])
                dot += x*y; a += x*x; b += y*y
            }
            if dot / sqrt(max(1e-16, a*b)) >= best * 0.985 { chosen = lag; break }
        }
        let frequency = sampleRate / Double(chosen)
        let midiFloat = 69 + 12 * log2(frequency/440)
        let midi = Int(midiFloat.rounded())
        guard (0...127).contains(midi) else { return nil }
        return (midi, (midiFloat-Double(midi))*100, min(1, best))
    }
}
