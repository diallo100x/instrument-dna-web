import Foundation
import SwiftUI
import AudioToolbox
import AVFoundation
import UniformTypeIdentifiers

struct PresetDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
final class InstrumentModel: ObservableObject {
    let unit: DNAudioUnit
    @Published var values: [Int: Float] = [:]
    @Published var name = "Instrument DNA"
    @Published var status = "Ready. Play the touch surface or import a model."
    @Published var reflection: [String: Any] = [:]
    @Published var rootMidi = 60
    @Published var cropStart = 0.0
    @Published var cropEnd = 2.0
    private var observer: AUParameterObserverToken?
    private var modelObserver: NSObjectProtocol?
    init(unit: DNAudioUnit) {
        self.unit = unit
        for p in unit.parameterTree?.allParameters ?? [] { values[Int(p.address)] = p.value }
        observer = unit.parameterTree?.token(byAddingParameterObserver: { [weak self] address, value in
            DispatchQueue.main.async { self?.values[Int(address)] = value }
        })
        modelObserver = NotificationCenter.default.addObserver(forName:Notification.Name("InstrumentDNAModelChanged"),object:unit,queue:.main){[weak self] _ in self?.refreshModel()}
        refreshModel()
    }
    deinit { if let token = observer { unit.parameterTree?.removeParameterObserver(token) };if let token=modelObserver {NotificationCenter.default.removeObserver(token)} }
    func value(_ id: Int) -> Float { values[id] ?? 0 }
    func set(_ id: Int, _ value: Float) {
        guard let p = unit.parameterTree?.parameter(withAddress: AUParameterAddress(id)) else { return }
        let clamped = min(p.maxValue, max(p.minValue, value)); p.value = clamped; values[id] = clamped
    }
    func binding(_ id: Int) -> Binding<Float> { Binding(get: { self.value(id) }, set: { self.set(id, $0) }) }
    func refreshModel() {
        guard let document = try? JSONSerialization.jsonObject(with: unit.modelData) as? [String: Any] else { return }
        reflection = document["reflection"] as? [String: Any] ?? document
        name = reflection["name"] as? String ?? "Instrument DNA"
    }
    func importFile(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            if url.pathExtension.lowercased() == "json" {
                let data = try Data(contentsOf: url); _ = try unit.loadModelData(data); refreshModel()
                status = "Loaded \(name). Reflections without slices use the modeled engine."
            } else { try importAudio(url); status = "Added \(url.lastPathComponent) at \(noteName(rootMidi)). Root pitch is assigned manually." }
        } catch { status = "Import failed: \(error.localizedDescription)" }
    }
    private func importAudio(_ url: URL) throws {
        let savedParameters = values
        let file = try AVAudioFile(forReading: url), format = file.processingFormat
        let start = max(0, cropStart), end = min(Double(file.length) / format.sampleRate, cropEnd)
        guard end > start, end-start <= 15 else { throw ModelError("Select a nonempty passage of at most 15 seconds.") }
        let count = AVAudioFrameCount((end-start)*format.sampleRate)
        guard let audio = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count) else { throw ModelError("Cannot allocate audio buffer.") }
        file.framePosition = AVAudioFramePosition(start*format.sampleRate); try file.read(into: audio, frameCount: count)
        guard let channels = audio.floatChannelData, !format.isInterleaved, audio.frameLength > 16 else { throw ModelError("Choose an audio file that decodes to planar Float32 PCM.") }
        var mono = [Float](repeating: 0, count: Int(audio.frameLength))
        for c in 0..<Int(format.channelCount) { for i in mono.indices { mono[i] += channels[c][i]/Float(format.channelCount) } }
        let encoded = mono.withUnsafeBytes { Data($0).base64EncodedString() }
        var document = (try? JSONSerialization.jsonObject(with: unit.modelData) as? [String: Any]) ?? [:]
        var dna = document["reflection"] as? [String: Any] ?? document
        if dna["format"] == nil { dna = ["format":"instrument-dna-reflection", "version":"0.5.7", "analyzerVersion":"native-manual-0.1.0", "name":name, "anchors":[], "provenance":[], "sampleSlots":[], "global":[:], "registers":[], "capture":["density":3], "performance":["layers":[:]]] }
        dna["name"] = name
        let roles = ["sustain","trill","staccato","accent","breathy","alternate"], role = roles[Int(value(20))]
        let sourceID = UUID().uuidString
        let anchor: [String: Any] = ["midi":rootMidi,"sourceId":sourceID,"sourceFilename":url.lastPathComponent,"source":"recorded slice","articulation":role,"start":start,"end":end,"confidence":["pitch":0,"overall":0],"parameters":["f0":["analyzed":440*pow(2,Double(rootMidi-69)/12),"model":440*pow(2,Double(rootMidi-69)/12),"offset":0,"confidence":0,"unit":"Hz"]],"unsupported":["automatic pitch analysis","harmonic model","source separation"]]
        var performance = dna["performance"] as? [String:Any] ?? [:], layers = performance["layers"] as? [String:[[String:Any]]] ?? [:]
        layers[role] = (layers[role] ?? []).filter { ($0["midi"] as? Int) != rootMidi } + [anchor]; performance["layers"] = layers; dna["performance"] = performance
        var base = dna["anchors"] as? [[String:Any]] ?? []
        if role == "sustain" || !base.contains(where: { ($0["midi"] as? Int)==rootMidi }) { base = base.filter { ($0["midi"] as? Int) != rootMidi } + [anchor] }
        dna["anchors"] = base
        var provenance = dna["provenance"] as? [[String:Any]] ?? []
        provenance.append(["sourceId":sourceID,"filename":url.lastPathComponent,"rightsStatus":"unverified","redistributionPermitted":false,"analysisDate":ISO8601DateFormatter().string(from:Date()),"analyzerVersion":"native-manual-0.1.0","articulation":role]); dna["provenance"] = provenance
        var audioLayers = document["audioLayers"] as? [[String:Any]] ?? [], audioBase = document["audio"] as? [[String:Any]] ?? []
        let clip: [String:Any] = ["midi":rootMidi,"sampleRate":Int(format.sampleRate),"channels":[encoded]]
        var layered = clip; layered["layer"] = role
        audioLayers = audioLayers.filter { !(($0["layer"] as? String)==role && ($0["midi"] as? Int)==rootMidi) } + [layered]
        if role == "sustain" { audioBase = audioBase.filter { ($0["midi"] as? Int) != rootMidi } + [clip] }
        document = ["format":"instrument-dna-playable-comparison","version":1,"hybridMode":"HybridOriginal","reflection":dna,"audio":audioBase,"audioLayers":audioLayers]
        _ = try unit.loadModelData(JSONSerialization.data(withJSONObject:document));for (id,value) in savedParameters {set(id,value)};refreshModel()
    }
    func exportData(includeAudio: Bool) throws -> Data {
        var document = (try? JSONSerialization.jsonObject(with: unit.modelData) as? [String:Any]) ?? [:]
        var dna = document["reflection"] as? [String:Any] ?? reflection
        guard dna["format"] != nil else { throw ModelError("Import or create an anchor before saving a DNA model.") }
        dna["name"] = name
        let macros = ["Attack","Body","Brightness","Harmonics","Noise","Resonance","Dynamics","Articulation","Movement","Drive"]
        dna["macros"] = Dictionary(uniqueKeysWithValues: macros.enumerated().map { ($0.element, value($0.offset)) })
        dna["xy"] = ["tone":[value(10),value(11)],"behavior":[value(12),value(13)]]
        var performance = dna["performance"] as? [String:Any] ?? [:]
        performance["voiceMode"] = ["poly","mono","legato"][Int(value(18))];performance["glideMs"] = value(19)
        performance["selectedArticulation"] = ["sustain","trill","staccato","accent","breathy","alternate"][Int(value(20))]
        performance["velocityTrill"] = value(25) > 0.5;performance["trillThreshold"] = value(26);performance["trillRateHz"] = value(23);performance["trillInterval"] = value(24);performance["noteLengthSeconds"] = value(27)
        dna["performance"] = performance;dna["era"] = ["recording":["none","vintage","tape"][Int(value(21))],"amount":value(22)]
        var ext = dna["extensions"] as? [String:Any] ?? [:];ext["nativePerformance"] = ["bendRange":value(17),"modulation":value(16),"engineMode":value(28),"volume":value(14)];dna["extensions"] = ext
        if includeAudio && document["format"] as? String != "instrument-dna-playable-comparison" { throw ModelError("This Reflection contains no source slices. Save it as a Reflection.") }
        if includeAudio && document["format"] as? String == "instrument-dna-playable-comparison" { document["reflection"] = dna; return try JSONSerialization.data(withJSONObject:document,options:.sortedKeys) }
        return try JSONSerialization.data(withJSONObject:dna,options:.sortedKeys)
    }
    func editOffset(key: String, offset: Double) {
        do {
            var document = try JSONSerialization.jsonObject(with:unit.modelData) as! [String:Any]
            var dna = document["reflection"] as? [String:Any] ?? document
            var global = dna["global"] as? [String:[String:Any]] ?? [:]
            guard var parameter = global[key] else { return };parameter["offset"] = offset;global[key] = parameter;dna["global"] = global
            if document["reflection"] != nil { document["reflection"] = dna } else { document=dna }
            let saved=values;_ = try unit.loadModelData(JSONSerialization.data(withJSONObject:document));for (id,value) in saved {set(id,value)};refreshModel();status="Updated \(key). Analyzed measurements are retained."
        } catch { status="Edit failed: \(error.localizedDescription)" }
    }
}
struct ModelError: LocalizedError { let message:String;init(_ message:String){self.message=message};var errorDescription:String?{message} }
func noteName(_ midi:Int)->String { let names=["C","C♯","D","D♯","E","F","F♯","G","G♯","A","A♯","B"];return "\(names[(midi%12+12)%12])\(midi/12-1)" }
