import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers

/// Mac-first DNAi analysis UI. Analysis is explicitly dispatched off the audio thread.
struct DNAiAnalysisPanel: View {
    @State private var sourceURL: URL?
    @State private var duration: Double = 0
    @State private var startSeconds: Double = 0
    @State private var endSeconds: Double = 0
    @State private var sampleRate: Double = 44100
    @State private var slices: [DNAiSlice] = []
    @State private var status = "Select a WAV, AIFF or compatible audio file."
    @State private var analyzing = false
    @State private var generation = 0

    private var noteNames: [String] { ["C","C♯","D","D♯","E","F","F♯","G","G♯","A","A♯","B"] }
    private func noteName(_ midi: Int?) -> String {
        guard let midi = midi, (0...127).contains(midi) else { return "Unmapped" }
        return "\(noteNames[midi % 12])\(midi / 12 - 1)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("DNAi • Intelligent Mapping").font(.headline)
                Spacer()
                Button("Open Audio…", action: openAudio)
                Button("Analyze Selection", action: analyze)
                    .disabled(sourceURL == nil || analyzing || endSeconds <= startSeconds)
            }
            Text(sourceURL?.lastPathComponent ?? "No audio selected").font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            if sourceURL != nil {
                HStack {
                    Text("Start \(startSeconds, specifier: "%.2f") s").frame(width: 100, alignment: .leading)
                    Slider(value: $startSeconds, in: 0...max(duration, 0.01))
                        .onChange(of: startSeconds) { value in if value > endSeconds { endSeconds = value } }
                }
                HStack {
                    Text("End \(endSeconds, specifier: "%.2f") s").frame(width: 100, alignment: .leading)
                    Slider(value: $endSeconds, in: 0...max(duration, 0.01))
                        .onChange(of: endSeconds) { value in if value < startSeconds { startSeconds = value } }
                }
            }
            Text(status).font(.caption).foregroundColor(.secondary)
            if analyzing { ProgressView().progressViewStyle(.linear) }
            HStack {
                Text("Detected slices: \(slices.count)")
                Spacer()
                Button("Export Mapping JSON…", action: exportMapping).disabled(slices.isEmpty)
            }.font(.caption)
            List {
                ForEach(slices.indices, id: \.self) { index in
                    HStack(spacing: 10) {
                        Text("#\(index + 1)").frame(width: 38, alignment: .leading)
                        Text(String(format: "%.2f–%.2f s",
                                    Double(slices[index].startFrame)/sampleRate,
                                    Double(slices[index].endFrame)/sampleRate))
                            .monospacedDigit().frame(width: 115, alignment: .leading)
                        Picker("Key", selection: Binding<Int>(
                            get: { slices[index].midiNote ?? -1 },
                            set: { slices[index].midiNote = $0 < 0 ? nil : $0 }
                        )) {
                            Text("Unmapped").tag(-1)
                            ForEach(0..<128, id: \.self) { midi in Text(noteName(midi)).tag(midi) }
                        }.frame(width: 170)
                        Text("confidence \(Int(slices[index].confidence*100))%")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }.frame(minHeight: 150)
            Text("Mapping analysis only: generated-note synthesis and patch injection are not connected yet.")
                .font(.caption2).foregroundColor(.secondary)
        }
        .padding(14)
        .frame(minWidth: 700, minHeight: 370)
    }

    private func openAudio() {
        let picker = NSOpenPanel()
        picker.allowedContentTypes = [.audio]
        picker.allowsMultipleSelection = false
        guard picker.runModal() == .OK, let url = picker.url else { return }
        do {
            let file = try AVAudioFile(forReading: url)
            sourceURL = url
            sampleRate = file.processingFormat.sampleRate
            duration = Double(file.length)/sampleRate
            startSeconds = 0
            endSeconds = duration
            slices = []
            status = "Ready to analyze \(String(format: "%.2f", duration)) seconds."
        } catch {
            status = "Audio import failed: \(error.localizedDescription)"
        }
    }

    private func analyze() {
        guard let url = sourceURL else { return }
        let start = startSeconds, end = endSeconds
        generation += 1
        let run = generation
        analyzing = true
        status = "Analyzing selected region…"
        DispatchQueue.global(qos: .userInitiated).async {
            let result: Result<[DNAiSlice], Error>
            do { result = .success(try DNAiIntelligentSlicer.analyze(url: url, startSeconds: start, endSeconds: end)) }
            catch { result = .failure(error) }
            DispatchQueue.main.async {
                guard run == generation else { return }
                analyzing = false
                switch result {
                case .success(let found):
                    slices = found
                    status = "Mapped \(found.filter { $0.midiNote != nil }.count) of \(found.count) detected slices. Correct keys below."
                case .failure(let error):
                    status = "Analysis failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func exportMapping() {
        guard !slices.isEmpty else { return }
        let save = NSSavePanel()
        save.nameFieldStringValue = "Instrument-DNAi-Mapping.json"
        save.allowedContentTypes = [.json]
        guard save.runModal() == .OK, let url = save.url else { return }
        do {
            let data = try JSONEncoder().encode(slices)
            try data.write(to: url, options: .atomic)
            status = "Exported note mapping."
        } catch { status = "Export failed: \(error.localizedDescription)" }
    }
}
