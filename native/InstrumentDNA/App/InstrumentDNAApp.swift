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
        AUAudioUnit.registerSubclass(DNAudioUnit.self,as:component,name:"Diallo Beats Audio Lab: Instrument DNA",version:0x00010000)
        AVAudioUnit.instantiate(with:component,options:[]){[weak self] unit,error in
            DispatchQueue.main.async {guard let self=self else{return};guard let unit=unit,let dna=unit.auAudioUnit as? DNAudioUnit else{self.status=error?.localizedDescription ?? "Cannot create Instrument DNA";return};do{
                let session=AVAudioSession.sharedInstance();try session.setCategory(.playback,mode:.default,options:.mixWithOthers);try session.setPreferredIOBufferDuration(0.0058);try session.setActive(true)
                self.node=unit;self.engine.attach(unit);self.engine.connect(unit,to:self.engine.mainMixerNode,format:unit.outputFormat(forBus:0));try self.engine.start();self.model=InstrumentModel(unit:dna);self.midi=DNAMIDIInput(unit:dna);fputs("INSTRUMENT_DNA_READY\n",stdout);fflush(stdout)
            }catch{self.status="Audio startup failed: \(error.localizedDescription)"}}
        }
        NotificationCenter.default.addObserver(forName:AVAudioSession.interruptionNotification,object:nil,queue:.main){[weak self] notification in self?.model?.unit.panic();if let raw=notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,raw==AVAudioSession.InterruptionType.ended.rawValue {do{try AVAudioSession.sharedInstance().setActive(true);try self?.engine.start()}catch{self?.status=error.localizedDescription}}}
    }
    func resume(){guard model != nil else{return};if !engine.isRunning {do{try AVAudioSession.sharedInstance().setActive(true);try engine.start()}catch{status=error.localizedDescription}}}
}
@main struct InstrumentDNAApp:App {
    @StateObject private var host=StandaloneHost()
    @Environment(\.scenePhase) private var scenePhase
    var body:some Scene{WindowGroup{Group{if let model=host.model{InstrumentView(model:model)}else{VStack{Text("Instrument DNA").font(.title);Text(host.status)}}}.onChange(of:scenePhase){phase in if phase == .active {host.resume()}else{host.model?.unit.panic()}}}}
}
