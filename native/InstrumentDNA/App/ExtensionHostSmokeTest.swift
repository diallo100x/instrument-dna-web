#if DEBUG
import UIKit
import AVFoundation
import AudioToolbox

// Exercises the installed InDN .appex through Apple's host API. Never registers
// DNAudioUnit for this component: the local standalone alias is InDS instead.
enum ExtensionHostSmokeTest {
    private static var node: AVAudioUnit?
    private static var engine: AVAudioEngine?
    private static var container: UIViewController?
    private static var finished = false
    private static let probe = EnergyProbe()
    static func run() {
        precondition(Thread.isMainThread)
        DispatchQueue.main.asyncAfter(deadline:.now()+90) {if !finished {fail("Timed out loading the shipped AUv3 extension")}}
        let description=AudioComponentDescription(componentType:kAudioUnitType_MusicDevice,componentSubType:0x496e444e,componentManufacturer:0x4462414c,componentFlags:0,componentFlagsMask:0)
        print("INSTRUMENT_DNA_EXTENSION_HOST_START");fflush(stdout)
        AVAudioUnit.instantiate(with:description,options:.loadOutOfProcess) { unit,error in
            DispatchQueue.main.async {
                guard let unit=unit else {fail("Instantiation: \(String(describing:error))");return}
                node=unit
                print("INSTRUMENT_DNA_EXTENSION_CREATED \(type(of:unit.auAudioUnit))");fflush(stdout)
                unit.auAudioUnit.requestViewController { editor in
                    DispatchQueue.main.async {
                        guard let editor=editor else {fail("Extension returned no custom editor");return}
                        show(editor,unit:unit)
                    }
                }
            }
        }
    }
    private static func show(_ editor:UIViewController,unit:AVAudioUnit) {
        guard let root=UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).flatMap({$0.windows}).first(where:{$0.isKeyWindow})?.rootViewController else {fail("No host window");return}
        let host=UIViewController();host.modalPresentationStyle = .fullScreen
        host.view.backgroundColor = .darkGray;host.addChild(editor)
        editor.view.translatesAutoresizingMaskIntoConstraints=false;host.view.addSubview(editor.view)
        NSLayoutConstraint.activate([editor.view.leadingAnchor.constraint(equalTo:host.view.leadingAnchor),editor.view.trailingAnchor.constraint(equalTo:host.view.trailingAnchor),editor.view.topAnchor.constraint(equalTo:host.view.topAnchor),editor.view.bottomAnchor.constraint(equalTo:host.view.bottomAnchor)])
        editor.didMove(toParent:host);container=host
        root.present(host,animated:false) {
            do {
                let audio=AVAudioEngine();engine=audio;audio.attach(unit)
                audio.connect(unit,to:audio.mainMixerNode,format:unit.outputFormat(forBus:0))
                audio.mainMixerNode.installTap(onBus:0,bufferSize:512,format:nil){buffer,_ in probe.add(buffer)}
                try audio.start()
                guard let midi=unit.auAudioUnit.scheduleMIDIEventBlock else {fail("No MIDI scheduling block");return}
                let bytes:[UInt8]=[0x90,69,100];bytes.withUnsafeBufferPointer{midi(AUEventSampleTimeImmediate,0,3,$0.baseAddress!)}
                DispatchQueue.main.asyncAfter(deadline:.now()+3){
                    host.view.layoutIfNeeded()
                    guard editor.view.bounds.width>0,editor.view.bounds.height>0,probe.energy>1e-7 else {fail("Remote editor bounds \(editor.view.bounds), audio energy \(probe.energy)");return}
                    finished=true
                    print("INSTRUMENT_DNA_EXTENSION_HOST_PASSED · remote editor \(type(of:editor)) · energy \(probe.energy)");fflush(stdout)
                }
            }catch{fail("Host audio start: \(error.localizedDescription)")}
        }
    }
    private static func fail(_ message:String) {
        print("INSTRUMENT_DNA_EXTENSION_HOST_FAILED: \(message)");fflush(stdout)
        fatalError(message)
    }
    private final class EnergyProbe {
        private let lock=NSLock()
        private var total=0.0
        var energy:Double {lock.lock();defer{lock.unlock()};return total}
        func add(_ buffer:AVAudioPCMBuffer) {
            guard let channels=buffer.floatChannelData else {return}
            var sum=0.0
            for i in 0..<Int(buffer.frameLength){let sample=Double(channels[0][i]);sum+=sample*sample}
            lock.lock();total+=sum;lock.unlock()
        }
    }
}
#endif
