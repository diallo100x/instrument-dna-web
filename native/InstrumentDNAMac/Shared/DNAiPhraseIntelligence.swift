import Foundation

/// Offline, explainable phrase analysis for DNAi. Does not run on the audio thread.
/// A tonic cannot be proven from a short phrase: the pitch-class suggestion is
/// deliberately low-confidence and must remain user-editable.
struct DNAiPhraseContext: Codable {
    var firstSoundingMidi: Int?
    var lowestSoundingMidi: Int?
    var tonicPitchClassSuggestion: Int?
    var tonicConfidence: Double
    var phraseAnchorMidi: Int?
    var articulationHints: [DNAiArticulationHint]
}
struct DNAiArticulationHint: Codable {
    var sliceIndex: Int
    var label: String
    var confidence: Double
    var reason: String
}
enum DNAiPhraseIntelligence {
    static func summarize(_ slices: [DNAiSlice], sampleRate: Double) -> DNAiPhraseContext {
        let notes = slices.compactMap { $0.midiNote }
        let first = notes.first
        let lowest = notes.min()
        var pitchClasses = [Double](repeating: 0, count: 12)
        for slice in slices {
            guard let note = slice.midiNote, (0...127).contains(note) else { continue }
            let duration = max(0, slice.endFrame - slice.startFrame)
            pitchClasses[note % 12] += Double(duration) * max(0, min(1, slice.confidence))
        }
        let ranked = pitchClasses.enumerated().sorted { $0.element > $1.element }
        let winner = ranked.first
        let runnerUp = ranked.dropFirst().first?.element ?? 0
        let total = pitchClasses.reduce(0,+)
        let tonic = (winner?.element ?? 0) > 0 ? winner?.offset : nil
        // Pitch-class prominence is not the same as a proven tonal center.
        let confidence = total > 0 ? min(0.49, max(0, ((winner?.element ?? 0)-runnerUp)/total)) : 0
        let hints = slices.enumerated().map { index, slice -> DNAiArticulationHint in
            let seconds = sampleRate > 0 ? Double(max(0,slice.endFrame-slice.startFrame))/sampleRate : 0
            if seconds < 0.18 {
                return DNAiArticulationHint(sliceIndex:index,label:"short-note candidate",
                    confidence:0.35,reason:"Short detected segment; not proof of staccato or damping.")
            }
            return DNAiArticulationHint(sliceIndex:index,label:"unclassified",
                confidence:0,reason:"Requires envelope and spectral evidence before technique labeling.")
        }
        return DNAiPhraseContext(firstSoundingMidi:first,lowestSoundingMidi:lowest,
            tonicPitchClassSuggestion:tonic,tonicConfidence:confidence,
            phraseAnchorMidi:first,articulationHints:hints)
    }
}
