import AppKit
import AVFoundation
import AudioToolbox

// Offline host uses the same public hosting, editor and MIDI APIs as a DAW.
// InDN is the shipped extension; InDS is only the standalone local alias.
enum MacSmokeTest {
    private static var remote:AVAudioUnit?
    private static var window:NSWindow?
    private static var finished=false
    static func run(local:MacStandaloneHost,model:InstrumentModel) {
        do {
            let description=AudioComponentDescription(componentType:kAudioUnitType_MusicDevice,componentSubType:0x496e444e,componentManufacturer:0x4462414c,componentFlags:0,componentFlagsMask:0)
            let editor=InstrumentEditorController();_ = editor.view
            let unit=try editor.createAudioUnit(with:description)
            precondition(editor.children.count==1 && unit.providesUserInterface)
            for size in [NSSize(width:680,height:540),NSSize(width:1000,height:800)] {
                editor.view.setFrameSize(size);editor.view.layoutSubtreeIfNeeded()
                precondition(editor.children[0].view.bounds.size==size)
            }
            for preset in InstrumentModel.factoryPresets {
                model.loadFactory(preset["id"]!)
                try render(model.unit)
            }
            print("INSTRUMENT_DNA_MAC_LOCAL_PASSED");fflush(stdout)
            DispatchQueue.main.asyncAfter(deadline:.now()+90){if !finished{fail("Shipped AUv3 timeout")}}
            AVAudioUnit.instantiate(with:description,options:.loadOutOfProcess){node,error in
                DispatchQueue.main.async {
                    guard let node=node else{fail("Shipped AUv3: \(String(describing:error))");return}
                    remote=node
                    node.auAudioUnit.requestViewController{controller in
                        DispatchQueue.main.async {
                            guard let controller=controller else{fail("No remote editor");return}
                            let host=NSWindow(contentRect:NSRect(x:0,y:0,width:900,height:700),styleMask:[.titled,.resizable],backing:.buffered,defer:false)
                            host.contentViewController=controller;host.makeKeyAndOrderFront(nil);window=host
                            DispatchQueue.main.asyncAfter(deadline:.now()+1){
                                do {
                                    host.contentView?.layoutSubtreeIfNeeded()
                                    precondition(controller.view.bounds.width>0 && controller.view.bounds.height>0)
                                    try render(node.auAudioUnit)
                                    finished=true;print("INSTRUMENT_DNA_MAC_EXTENSION_PASSED");fflush(stdout);exit(0)
                                }catch{fail("Remote render: \(error)")}
                            }
                        }
                    }
                }
            }
        }catch{fail("Local render: \(error)")}
    }
    private static func render(_ unit:AUAudioUnit) throws {
        if unit.renderResourcesAllocated{unit.deallocateRenderResources()}
        let format=AVAudioFormat(standardFormatWithSampleRate:48000,channels:2)!
        try unit.outputBusses[0].setFormat(format)
        unit.maximumFramesToRender=512
        try unit.allocateRenderResources()
        defer{unit.deallocateRenderResources()}
        guard let midi=unit.scheduleMIDIEventBlock else{throw TestError("No host MIDI block")}
        let note:[UInt8]=[0x90,66,100];note.withUnsafeBufferPointer{midi(AUEventSampleTimeImmediate,0,3,$0.baseAddress!)}
        var time=AudioTimeStamp();time.mFlags = .sampleTimeValid
        let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:512)!
        buffer.frameLength=512
        var flags:AudioUnitRenderActionFlags=[]
        var energy=0.0
        for block in 0..<64 {
            time.mSampleTime=Double(block*512)
            let result=unit.renderBlock(&flags,&time,512,0,buffer.mutableAudioBufferList,nil)
            guard result==noErr else{throw TestError("Render status \(result)")}
            for frame in 0..<512{let sample=Double(buffer.floatChannelData![0][frame]);guard sample.isFinite else{throw TestError("Nonfinite signal")};energy+=sample*sample}
        }
        guard energy>1e-7 else{throw TestError("Silent output")}
        let off:[UInt8]=[0x80,66,0];off.withUnsafeBufferPointer{midi(AUEventSampleTimeImmediate,0,3,$0.baseAddress!)}
    }
    private static func fail(_ message:String){fputs("INSTRUMENT_DNA_MAC_FAILED: \(message)\n",stderr);fflush(stderr);exit(1)}
    private struct TestError:Error{let message:String;init(_ message:String){self.message=message}}
}
