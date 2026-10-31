#if DEBUG
import Foundation
import AudioToolbox

enum PhysicalFitSmokeTest {
    static func run() {
        let component=AudioComponentDescription(componentType:kAudioUnitType_MusicDevice,componentSubType:0x496e444e,componentManufacturer:0x4462414c,componentFlags:0,componentFlagsMask:0)
        let unit=try! DNAudioUnit(componentDescription:component)
        let rate=16000,pcm=(0..<32000).map { i -> Float in
            var value=0.0
            for h in 1...4 {let tone=0.72,base = -log(1000.0)/2,loss=440*log(tone/sqrt(1+pow(1-tone,2)-2*(1-tone)*cos(2*Double.pi*440*Double(h)/Double(rate))));value += 0.35/Double(h)*sin(2*Double.pi*440*Double(h*i)/Double(rate))*exp((base+loss)*Double(i)/Double(rate))}
            return Float(value)
        }
        let encoded=pcm.withUnsafeBytes{Data($0).base64EncodedString()}
        let dna:[String:Any]=["format":"instrument-dna-reflection","name":"Fitting smoke test","anchors":[["midi":69,"parameters":[:]]],"provenance":[],"sampleSlots":[],"performance":["layers":[:]],"global":[:],"registers":[]]
        let document:[String:Any]=["format":"instrument-dna-playable-comparison","version":1,"reflection":dna,"audio":[["midi":69,"sampleRate":rate,"channels":[encoded]]]]
        _ = try! unit.loadModelData(JSONSerialization.data(withJSONObject:document))
        let model=InstrumentModel(unit:unit)
        exercise(model,kind:"modal") {exercise(model,kind:"waveguide") {fputs("INSTRUMENT_DNA_FITTING_TESTS_PASSED\n",stdout);fflush(stdout)}}
    }
    private static func exercise(_ model:InstrumentModel,kind:String,done:@escaping()->Void) {
        model.physicalFitKind=kind;model.set(2,0.3);model.fitPhysicalModel();model.set(2,0.79)
        let deadline=Date().addingTimeInterval(15)
        func check() {
            if model.fittingPhysical {precondition(Date()<deadline,"Fitting timed out");DispatchQueue.main.asyncAfter(deadline:.now()+0.1){check()};return}
            precondition(model.unit.parameterTree?.parameter(withAddress:28)?.value==4,model.status)
            precondition(model.value(28)==4,"Displayed engine mode must match the current unit after queued observer callbacks: \(model.status)")
            precondition(abs(model.value(2)-0.79)<0.001,"Live macro edit was overwritten by fitting")
            let reflection=try! JSONSerialization.jsonObject(with:model.exportData(includeAudio:false)) as! [String:Any]
            let ext=reflection["extensions"] as! [String:Any],physical=ext["physicalModel"] as! [String:Any]
            precondition(physical["kind"] as? String==kind && physical["origin"] as? String=="analyzed")
            precondition(reflection["audio"]==nil)
            model.set(28,0)
            let comparison=try! JSONSerialization.jsonObject(with:model.exportData(includeAudio:true)) as! [String:Any]
            precondition(comparison["hybridMode"] as? String=="HybridOriginal")
            precondition((comparison["audio"] as? [[String:Any]])?.count==1)
            done()
        }
        check()
    }
}
#endif
