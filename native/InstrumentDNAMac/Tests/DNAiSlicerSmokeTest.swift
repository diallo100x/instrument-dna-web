import Foundation

@main
struct DNAiSlicerSmokeTest {
    static func main() {
        let sampleRate = 44_100.0
        func tone(_ hz: Double, seconds: Double) -> [Float] {
            let n = Int(sampleRate * seconds)
            return (0..<n).map { i in
                let t = Double(i)/sampleRate
                let envelope = min(1.0, t/0.012) * min(1.0, (seconds-t)/0.035)
                return Float(0.5 * envelope * sin(2 * .pi * hz * t))
            }
        }
        let silence = [Float](repeating: 0, count: 4_410)
        let audio = silence + tone(220, seconds: 0.35) + silence + tone(261.625565, seconds: 0.35) + silence
        let slices = DNAiIntelligentSlicer.analyze(samples: audio, sampleRate: sampleRate)
        print("DNAi slices: \(slices.map { "\($0.midiNote.map(String.init) ?? "unknown") @ \($0.startFrame)" })")
        let notes = slices.compactMap(\.midiNote)
        guard notes.contains(57), notes.contains(60) else {
            fputs("FAIL: expected A3 (57) and C4 (60), found \(notes)\n", stderr)
            exit(1)
        }
        print("PASS: detected A3 and C4")
    }
}
