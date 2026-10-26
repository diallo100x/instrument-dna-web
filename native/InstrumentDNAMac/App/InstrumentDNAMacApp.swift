import SwiftUI
import AppKit
import AVFoundation
import AudioToolbox

final class MacStandaloneHost:ObservableObject {
    @Published var model:InstrumentModel?
    @Published var status="Starting native Mac audio…"
    private let engine=AVAudioEngine()
    private var node:AVAudioSourceNode?
    private var midi:DNAMIDIInput?
    init(){
        // Standalone owns a source node; only DAW hosts instantiate the shipped
        // AUv3. Avoid waiting on local Audio Component discovery at app startup.
        DispatchQueue.main.async{[weak self] in self?.initialize()}
    }
    private func initialize(){
        fputs("INSTRUMENT_DNA_MAC_STARTING\n",stdout);fflush(stdout)
        do {
            let description=AudioComponentDescription(componentType:kAudioUnitType_MusicDevice,componentSubType:0x496e4453,componentManufacturer:0x4462414c,componentFlags:0,componentFlagsMask:0)
            let dna=try DNAudioUnit(componentDescription:description,options:[])
            let model=InstrumentModel(unit:dna);self.model=model
            model.restartAudio = {[weak self] in try self?.restart()}
            midi=DNAMIDIInput(unit:dna)
            if ProcessInfo.processInfo.arguments.contains("--mac-smoke-test"){MacSmokeTest.run(model:model);return}
            try restart()
        }catch{status="Audio startup: \(error.localizedDescription)";model?.audioCheck="\(status). Open Output → Recover audio."}
    }
    func restart() throws {
        guard let model=model else{return}
        model.unit.panic();engine.stop()
        if let node=node{engine.detach(node);self.node=nil}
        if model.unit.renderResourcesAllocated{model.unit.deallocateRenderResources()}
        let format=AVAudioFormat(standardFormatWithSampleRate:48000,channels:2)!
        try model.unit.outputBusses[0].setFormat(format)
        model.unit.maximumFramesToRender=65536
        try model.unit.allocateRenderResources()
        let render=model.unit.internalRenderBlock
        let source=AVAudioSourceNode(format:format){_,time,count,output in
            var flags:AudioUnitRenderActionFlags=[]
            return render(&flags,time,count,0,output,nil,nil)
        }
        node=source;engine.attach(source)
        engine.connect(source,to:engine.mainMixerNode,format:format)
        engine.prepare();try engine.start();status="Native Mac audio ready."
    }
}
@main struct InstrumentDNAMacApp:App {
    @StateObject private var host:MacStandaloneHost
    init(){let audio=MacStandaloneHost();_host=StateObject(wrappedValue:audio)}
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
