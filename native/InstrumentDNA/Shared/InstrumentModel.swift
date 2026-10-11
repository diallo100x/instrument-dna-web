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
    @Published var physicalFitKind = "modal"
    @Published var fittingPhysical = false
    @Published var automaticExtraction = true
    @Published var analysisProfile = "sustained"
    @Published var captureDensity = 3
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
    static var factoryPresets: [[String:String]] {
        guard let url=Bundle(for:DNAudioUnit.self).url(forResource:"manifest",withExtension:"json"),let data=try? Data(contentsOf:url) else {return []}
        return (try? JSONSerialization.jsonObject(with:data) as? [[String:String]]) ?? []
    }
    func loadFactory(_ id:String) {
        do {
            guard let url=Bundle(for:DNAudioUnit.self).url(forResource:id,withExtension:"json") else {throw ModelError("Factory preset unavailable.")}
            stopPreview();_ = try unit.loadModelData(Data(contentsOf:url));refreshModel();set(28,4)
            status="Loaded \(name). Authored physical model; no reference audio required."
        }catch{status="Factory load failed: \(error.localizedDescription)"}
    }
    func importFile(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            if url.pathExtension.lowercased() == "json" {
                let data = try Data(contentsOf: url); _ = try unit.loadModelData(data); refreshModel()
                status = "Loaded \(name). Reflections without slices use the modeled engine."
            } else { try importAudio(url) }
        } catch { status = "Import failed: \(error.localizedDescription)" }
    }
    private func importAudio(_ url: URL) throws {
        var savedParameters = values
        let file = try AVAudioFile(forReading: url), format = file.processingFormat
        let start = max(0, cropStart), end = min(Double(file.length) / format.sampleRate, cropEnd)
        guard end > start, end-start <= 15 else { throw ModelError("Select a nonempty passage of at most 15 seconds.") }
        let count = AVAudioFrameCount((end-start)*format.sampleRate)
        guard let audio = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count) else { throw ModelError("Cannot allocate audio buffer.") }
        file.framePosition = AVAudioFramePosition(start*format.sampleRate); try file.read(into: audio, frameCount: count)
        guard let channels = audio.floatChannelData, !format.isInterleaved, audio.frameLength > 16 else { throw ModelError("Choose an audio file that decodes to planar Float32 PCM.") }
        var mono = [Float](repeating: 0, count: Int(audio.frameLength))
        for c in 0..<Int(format.channelCount) { for i in mono.indices { mono[i] += channels[c][i]/Float(format.channelCount) } }
        let detections: [NativeAnalyzer.Detection]
        if automaticExtraction {
            detections = NativeAnalyzer.analyze(mono,sampleRate:format.sampleRate,profile:analysisProfile,density:captureDensity)
            guard !detections.isEmpty else { throw ModelError("No stable monophonic notes found in this crop. Adjust the selection or disable extraction to assign a manual anchor.") }
        } else {detections = [NativeAnalyzer.Detection(midi:rootMidi,start:0,end:Double(mono.count)/format.sampleRate,confidence:0,f0:440*pow(2,Double(rootMidi-69)/12),harmonics:[],attack:0.01)]}
        var document = (try? JSONSerialization.jsonObject(with: unit.modelData) as? [String: Any]) ?? [:]
        var dna = document["reflection"] as? [String: Any] ?? document
        if var ext=dna["extensions"] as? [String:Any],ext["physicalModel"] != nil {
            if ext["physicalFits"] != nil {ext.removeValue(forKey:"physicalModel");ext.removeValue(forKey:"physicalFits");ext.removeValue(forKey:"physicalControls");dna["extensions"]=ext}else{document=[:];dna=[:]}
            savedParameters[28]=0
        }
        if dna["format"] == nil {dna = ["format":"instrument-dna-reflection","version":"0.5.7","name":name,"anchors":[],"provenance":[],"sampleSlots":[],"global":[:],"registers":[],"performance":["layers":[:]]]}
        dna["name"] = name;dna["analyzerVersion"] = NativeAnalyzer.version;dna["capture"] = ["density":captureDensity,"analysisProfile":analysisProfile]
        let role = NoteMap.roles[Int(value(20))], sourceID = UUID().uuidString
        var performance = dna["performance"] as? [String:Any] ?? [:], layers = performance["layers"] as? [String:[[String:Any]]] ?? [:]
        var base = dna["anchors"] as? [[String:Any]] ?? []
        var audioLayers = document["audioLayers"] as? [[String:Any]] ?? [], audioBase = document["audio"] as? [[String:Any]] ?? []
        for detection in detections {
            let midi = detection.midi
            let parameters: [String:Any] = ["f0":["analyzed":detection.f0,"model":detection.f0,"offset":0,"confidence":detection.confidence,"unit":"Hz"],"attackSeconds":["analyzed":detection.attack,"model":detection.attack,"offset":0,"confidence":0.4],"harmonicAmplitudes":["analyzed":detection.harmonics,"model":detection.harmonics,"offset":0,"confidence":automaticExtraction ? 0.5 : 0]]
            let anchor: [String:Any] = ["midi":midi,"sourceId":sourceID,"sourceFilename":url.lastPathComponent,"source":automaticExtraction ? "native detected note" : "recorded slice","articulation":role,"analysisProfile":analysisProfile,"start":start+detection.start,"end":start+detection.end,"confidence":["pitch":detection.confidence,"overall":detection.confidence*0.7],"parameters":parameters,"unsupported":["instrument recognition","polyphonic separation","modal resonances","noise spectrum","automatic articulation classification"]]
            layers[role] = (layers[role] ?? []).filter{($0["midi"] as? Int) != midi} + [anchor]
            if role == "sustain" || !base.contains(where:{($0["midi"] as? Int)==midi}) {base=base.filter{($0["midi"] as? Int) != midi}+[anchor]}
            let lo = max(0,Int(detection.start*format.sampleRate)), hi = min(mono.count,Int(detection.end*format.sampleRate))
            let encoded = Array(mono[lo..<hi]).withUnsafeBytes{Data($0).base64EncodedString()}
            let clip:[String:Any] = ["midi":midi,"sampleRate":Int(format.sampleRate),"channels":[encoded]]
            var layered=clip;layered["layer"]=role
            audioLayers=audioLayers.filter{!(($0["layer"] as? String)==role && ($0["midi"] as? Int)==midi)}+[layered]
            if role == "sustain" {audioBase=audioBase.filter{($0["midi"] as? Int) != midi}+[clip]}
        }
        performance["layers"]=layers;dna["performance"]=performance;dna["anchors"]=base
        var provenance=dna["provenance"] as? [[String:Any]] ?? []
        provenance.append(["sourceId":sourceID,"filename":url.lastPathComponent,"rightsStatus":"unverified","redistributionPermitted":false,"analysisDate":ISO8601DateFormatter().string(from:Date()),"analyzerVersion":NativeAnalyzer.version,"articulation":role]);dna["provenance"]=provenance
        document=["format":"instrument-dna-playable-comparison","version":1,"hybridMode":"HybridOriginal","reflection":dna,"audio":audioBase,"audioLayers":audioLayers]
        _ = try unit.loadModelData(JSONSerialization.data(withJSONObject:document));for (id,value) in savedParameters {set(id,value)};refreshModel()
        status = "Added \(detections.count) \(automaticExtraction ? "detected" : "manual") anchors. Review Detected note slices before saving."
    }
    func fitPhysicalModel() {
        guard !fittingPhysical else { return }
        let original = unit.modelData, saved = values, kind = physicalFitKind
        fittingPhysical = true; stopPreview(); status = "Fitting isolated reference notes…"
        DispatchQueue.global(qos:.userInitiated).async { [weak self] in
            do {
                var document = try JSONSerialization.jsonObject(with:original) as! [String:Any]
                var dna = document["reflection"] as? [String:Any] ?? document
                let audio = document["audio"] as? [[String:Any]] ?? []
                let anchors = dna["anchors"] as? [[String:Any]] ?? []
                var fits:[[String:Any]] = [], failures:[String] = []
                for anchor in anchors {
                    guard let midi=anchor["midi"] as? Int, let clip=audio.first(where:{($0["midi"] as? Int)==midi}),let rate=clip["sampleRate"] as? Double,let channels=clip["channels"] as? [String],!channels.isEmpty else {continue}
                    do {
                        let decoded=try channels.map { encoded -> [Float] in
                            guard let data=Data(base64Encoded:encoded),data.count%4==0 else {throw ModelError("Invalid source audio.")}
                            var samples=[Float](repeating:0,count:data.count/4)
                            _ = samples.withUnsafeMutableBytes{data.copyBytes(to:$0)};return samples
                        }
                        guard let first=decoded.first,decoded.allSatisfy({$0.count==first.count}) else {throw ModelError("Mismatched source channels.")}
                        var mono=[Float](repeating:0,count:first.count)
                        for channel in decoded {for i in mono.indices {mono[i]+=channel[i]/Float(decoded.count)}}
                        let pcm=mono.withUnsafeBytes{Data($0)}
                        guard var fit=try DNAudioUnit.fitPhysicalPCM(pcm,sampleRate:rate,midi:midi,kind:kind) as? [String:Any] else {throw ModelError("No fit returned.")}
                        fit["sourceId"]=anchor["sourceId"];fit["articulation"]=anchor["articulation"];fits.append(fit)
                    }catch{failures.append("\(noteName(midi)): \(error.localizedDescription)")}
                }
                guard let first=fits.first else {throw ModelError(failures.isEmpty ? "Import clean struck/plucked notes with source slices before fitting." : failures.joined(separator:" "))}
                var ext=dna["extensions"] as? [String:Any] ?? [:]
                ext["physicalModel"]=first["model"];ext.removeValue(forKey:"physicalControls")
                ext["physicalFits"]=["version":1,"analyzerVersion":"physical-fit-1","kind":kind,"anchors":fits,"failures":failures,"selection":"nearest measured anchor; no physical curve interpolation yet"]
                var native=ext["nativePerformance"] as? [String:Any] ?? [:];native["engineMode"]=4;ext["nativePerformance"]=native;dna["extensions"]=ext
                if document["reflection"] != nil {document["reflection"]=dna;document["hybridMode"]="Physical"}else{document=dna}
                let result=try JSONSerialization.data(withJSONObject:document)
                let count=fits.count, low=fits.filter{($0["confidence"] as? Double ?? 0)<0.55}.count, message=failures.joined(separator:" ")
                DispatchQueue.main.async {
                    guard let self=self else {return};self.fittingPhysical=false
                    guard self.unit.modelData==original else {self.status="Sources or edits changed during fitting. Fit again.";return}
                    do{_ = try self.unit.loadModelData(result);for(id,value) in saved where id<29 && id != 28 {self.set(id,value)};self.set(28,4);self.refreshModel();self.status="Fitted \(count) notes · \(low) low-confidence fits. Source slices and Hybrid retained. \(message)"}catch{self.status="Physical fit: \(error.localizedDescription)"}
                }
            }catch{DispatchQueue.main.async{self?.fittingPhysical=false;self?.status="Physical fit: \(error.localizedDescription)"}}
        }
    }
    var noteEntries: [NoteMap.Entry] {
        let document = (try? JSONSerialization.jsonObject(with: unit.modelData) as? [String: Any]) ?? [:]
        return NoteMap.entries(document)
    }
    private var previewGeneration = 0
    func stopPreview() {
        previewGeneration += 1
        unit.previewNote(60, layer: 0, source: false, down: false)
    }
    func preview(_ entry: NoteMap.Entry, source: Bool) {
        guard !source || entry.hasAudio else { status = "This Reflection contains no source audio. Use Model preview."; return }
        stopPreview()
        unit.previewNote(entry.midi, layer: NoteMap.roles.firstIndex(of: entry.role) ?? 0, source: source, down: true)
        status = "Previewing \(noteName(entry.midi)) · \(entry.role) · \(source ? "source slice" : "reconstructed model"). The host must be rendering audio."
        let generation = previewGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self, self.previewGeneration == generation else { return }
            self.stopPreview()
        }
    }
    func addArticulation(_ entry: NoteMap.Entry, role: String) {
        do {
            let document = try JSONSerialization.jsonObject(with: exportData(includeAudio: ((try? JSONSerialization.jsonObject(with: unit.modelData) as? [String: Any])?["format"] as? String == "instrument-dna-playable-comparison"))) as! [String: Any]
            let edited = try NoteMap.copy(entry, to: role, in: document)
            let saved = values
            stopPreview()
            _ = try unit.loadModelData(JSONSerialization.data(withJSONObject: edited))
            for (id, value) in saved { set(id, value) }
            refreshModel()
            status = "Added \(noteName(entry.midi)) to \(role). Original anchor and measurements retained."
        } catch { status = "Layer assignment: \(error.localizedDescription)" }
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
        var ext = dna["extensions"] as? [String:Any] ?? [:];ext["nativePerformance"] = ["bendRange":value(17),"modulation":value(16),"engineMode":value(28),"volume":value(14)];if ext["physicalModel"] != nil {ext["physicalControls"]=["hardness":value(29),"position":value(30),"damping":value(31),"noise":value(32)]};dna["extensions"] = ext
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
