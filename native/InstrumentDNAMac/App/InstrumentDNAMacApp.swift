import SwiftUI
import AppKit
import AVFoundation
import AudioToolbox

final class MacStandaloneHost:ObservableObject {
    @Published var model:InstrumentModel?
    @Published var status="Starting native Mac audio…"
    private let engine=AVAudioEngine()
    private var node:AVAudioUnit?
    private var midi:DNAMIDIInput?
    init(){
        fputs("INSTRUMENT_DNA_MAC_STARTING\n",stdout);fflush(stdout)
        let description=AudioComponentDescription(componentType:kAudioUnitType_MusicDevice,componentSubType:0x496e4453,componentManufacturer:0x4462414c,componentFlags:0,componentFlagsMask:0)
        AUAudioUnit.registerSubclass(DNAudioUnit.self,as:description,name:"Diallo Beats Audio Lab: Instrument DNA",version:65545)
        AVAudioUnit.instantiate(with:description,options:[]){[weak self] unit,error in
            DispatchQueue.main.async {
                guard let self=self else{return}
                guard let node=unit,let dna=node.auAudioUnit as? DNAudioUnit else{self.status=error?.localizedDescription ?? "Cannot create Instrument DNA";return}
                self.node=node;self.engine.attach(node)
                let model=InstrumentModel(unit:dna);self.model=model
                model.restartAudio = {[weak self] in try self?.restart()}
                self.midi=DNAMIDIInput(unit:dna)
                // Tests render offline, avoiding dependence on a CI speaker device.
                if ProcessInfo.processInfo.arguments.contains("--mac-smoke-test") {MacSmokeTest.run(local:self,model:model);return}
                do{try self.restart()}catch{model.audioCheck="Audio start failed: \(error.localizedDescription). Open Output → Recover audio."}
            }
        }
    }
    func restart() throws {
        guard let node=node else{return}
        model?.unit.panic();engine.stop();engine.disconnectNodeOutput(node)
        engine.connect(node,to:engine.mainMixerNode,format:node.outputFormat(forBus:0))
        engine.prepare();try engine.start();status="Native Mac audio ready."
    }
}
@main struct InstrumentDNAMacApp:App {
    @StateObject private var host:MacStandaloneHost
    init(){
        let audio=MacStandaloneHost()
        _host=StateObject(wrappedValue:audio)
    }
    @Environment(\.scenePhase) private var scenePhase
    var body:some Scene {
        WindowGroup("Instrument DNA") {
            Group {
                if let model=host.model{InstrumentView(model:model)}
                else{VStack{Text("Instrument DNA").font(.title);Text(host.status)}.padding()}
            }.frame(minWidth:680,minHeight:540)
             .onChange(of:scenePhase){phase in if phase != .active{host.model?.unit.panic()}}
        }
    }
}
