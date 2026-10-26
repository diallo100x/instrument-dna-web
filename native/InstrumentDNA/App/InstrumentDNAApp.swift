import SwiftUI
import AVFoundation
import AudioToolbox
import Darwin

private let component=AudioComponentDescription(componentType:kAudioUnitType_MusicDevice,componentSubType:0x496e4453,componentManufacturer:0x4462414c,componentFlags:0,componentFlagsMask:0)
final class StandaloneHost:ObservableObject {
    @Published var model:InstrumentModel?
    @Published var status="Starting native audio…"
    let engine=AVAudioEngine()
    private var node:AVAudioUnit?
    private var midi:DNAMIDIInput?
    init(){
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--editor-smoke-test") {DispatchQueue.main.async {EditorSmokeTest.run()}}
        if ProcessInfo.processInfo.arguments.contains("--extension-host-smoke-test") {DispatchQueue.main.asyncAfter(deadline:.now()+1){ExtensionHostSmokeTest.run()}}
        #endif
        AUAudioUnit.registerSubclass(DNAudioUnit.self,as:component,name:"Diallo Beats Audio Lab: Instrument DNA",version:0x00010000)
        AVAudioUnit.instantiate(with:component,options:[]){[weak self] unit,error in
            DispatchQueue.main.async {guard let self=self else{return};guard let unit=unit,let dna=unit.auAudioUnit as? DNAudioUnit else{self.status=error?.localizedDescription ?? "Cannot create Instrument DNA";return};
                self.node=unit;self.engine.attach(unit);self.model=InstrumentModel(unit:dna);self.model?.restartAudio = {[weak self] in try self?.recoverAudio()};self.midi=DNAMIDIInput(unit:dna)
                do{
                let session=AVAudioSession.sharedInstance();try session.setCategory(.playback,mode:.default,options:.mixWithOthers);try session.setPreferredIOBufferDuration(0.0058);try session.setActive(true)
                self.engine.connect(unit,to:self.engine.mainMixerNode,format:unit.outputFormat(forBus:0));try self.engine.start();fputs("INSTRUMENT_DNA_READY\n",stdout);fflush(stdout)
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--editor-smoke-test") {DispatchQueue.main.asyncAfter(deadline:.now()+2){self.recoverySmokeTest()}}
                #endif
            }catch{self.status="Audio startup failed: \(error.localizedDescription)";self.model?.audioCheck="\(self.status). Open Output → Recover audio."}}
        }
        NotificationCenter.default.addObserver(forName:AVAudioSession.interruptionNotification,object:nil,queue:.main){[weak self] notification in self?.model?.unit.panic();if let raw=notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,raw==AVAudioSession.InterruptionType.ended.rawValue {do{try AVAudioSession.sharedInstance().setActive(true);try self?.engine.start()}catch{self?.status=error.localizedDescription}}}
    }
    #if DEBUG
    private func recoverySmokeTest() {
        guard let model=model else {preconditionFailure("Missing native model")}
        let data=model.unit.modelData, values=model.values
        do {try recoverAudio()} catch {preconditionFailure("Audio recovery failed: \(error)")}
        precondition(model.unit.modelData==data && model.values==values)
        let frames=model.unit.renderedFrames, audible=model.unit.audibleFrames
        model.unit.touchNote(0,midi:69,velocity:0.8,down:true)
        DispatchQueue.main.asyncAfter(deadline:.now()+0.5) {
            precondition(model.unit.renderedFrames>frames && model.unit.audibleFrames>audible)
            model.unit.touchNote(0,midi:69,velocity:0,down:false)
            fputs("INSTRUMENT_DNA_AUDIO_RECOVERY_PASSED\n",stdout);fflush(stdout)
        }
    }
    #endif
    func recoverAudio() throws {
        guard let node = node else { return }
        model?.unit.panic()
        engine.stop()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode:.default, options:.mixWithOthers)
        try session.setActive(true)
        engine.disconnectNodeOutput(node)
        engine.connect(node, to:engine.mainMixerNode, format:node.outputFormat(forBus:0))
        engine.prepare()
        try engine.start()
        status = "Native audio restarted."
    }
    func resume(){guard model != nil else{return};if !engine.isRunning {do{try AVAudioSession.sharedInstance().setActive(true);try engine.start()}catch{status=error.localizedDescription}}}
}
@main struct InstrumentDNAApp:App {
    @StateObject private var host=StandaloneHost()
    @Environment(\.scenePhase) private var scenePhase
    var body:some Scene{WindowGroup{Group{if let model=host.model{InstrumentView(model:model)}else{VStack{Text("Instrument DNA").font(.title);Text(host.status)}}}.onChange(of:scenePhase){phase in if phase == .active {host.resume()}else{host.model?.unit.panic()}}}}
}
