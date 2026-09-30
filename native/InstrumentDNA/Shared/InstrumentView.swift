import SwiftUI
import UniformTypeIdentifiers

struct InstrumentView: View {
    @ObservedObject var model: InstrumentModel
    @State private var tab="Instrument"
    @State private var surface:PlayingSurface = .piano
    @State private var firstNote=48
    @State private var noteCount=24
    @State private var independent=true
    @State private var importing=false
    @State private var exporting=false
    @State private var document=PresetDocument(data:Data())
    @State private var exportName="Instrument DNA"
    private let macros=["Attack","Body","Brightness","Harmonics","Noise","Resonance","Dynamics","Articulation","Movement","Drive"]
    private var tabs:[String]{["Instrument"]+macros+["Tone XY","Behavior XY","Performance","Sources","DNA Edit","Anchors","Era","Output","About"]}
    var body:some View {
        GeometryReader { geometry in
            if geometry.size.height<380 { ScrollView { layout(controlHeight:220,surfaceHeight:180) } }
            else { layout(controlHeight:nil,surfaceHeight:min(240,max(140,geometry.size.height*0.32))) }
        }
        .background(Color(red:0.06,green:0.1,blue:0.12)).foregroundColor(.white)
        .preferredColorScheme(.dark)
        .fileImporter(isPresented:$importing,allowedContentTypes:[.json,.audio],allowsMultipleSelection:false) { result in
            switch result {case .success(let urls):if let url=urls.first {model.importFile(url)};case .failure(let error):model.status=error.localizedDescription}
        }
        .fileExporter(isPresented:$exporting,document:document,contentType:.json,defaultFilename:exportName) { result in
            switch result {case .success:model.status="Saved \(exportName).";case .failure(let error):model.status="Save failed: \(error.localizedDescription)"}
        }
    }
    private func layout(controlHeight:CGFloat?,surfaceHeight:CGFloat)->some View {
        VStack(spacing:8){
            HStack { Text("INSTRUMENT DNA · AUv3").font(.caption.bold());Spacer();Button("Panic"){model.unit.panic()}.accessibilityHint("Release every sounding voice") }.padding(.horizontal)
            HStack { Picker("All parameter tabs",selection:$tab){ForEach(tabs,id:\.self){Text($0).tag($0)}}.pickerStyle(.menu).accessibilityLabel("All parameter tabs")
                ScrollView(.horizontal,showsIndicators:true){HStack{ForEach(tabs,id:\.self){name in Button(name){tab=name}.padding(.horizontal,9).padding(.vertical,6).background(tab==name ? Color.orange.opacity(0.35):Color.white.opacity(0.08)).cornerRadius(6)}}}.accessibilityLabel("Parameter tabs")
            }.padding(.horizontal)
            ScrollView { VStack(alignment:.leading,spacing:12){Text(tab).font(.title3.bold());page;Text(model.status).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true)}.padding().frame(maxWidth:.infinity,alignment:.leading) }.frame(height:controlHeight)
            VStack(spacing:6){
                HStack { Picker("Playing surface",selection:$surface){ForEach(PlayingSurface.allCases,id:\.self){Text($0.rawValue).tag($0)}}.pickerStyle(.menu)
                    Button("− Oct"){firstNote=max(24,firstNote-12)};Text(noteName(firstNote)).font(.caption.monospaced());Button("+ Oct"){firstNote=min(surface == .fretboard ? 84:96,firstNote+12)}
                    Picker("Slide mode",selection:$independent){Text("Per note slide").tag(true);Text("Global slide").tag(false)}.pickerStyle(.menu)
                }.padding(.horizontal)
                TouchInstrument(model:model,style:surface,firstNote:firstNote,noteCount:noteCount,independent:independent).frame(height:surfaceHeight).clipShape(RoundedRectangle(cornerRadius:8)).padding(.horizontal,8)
                HStack{Text("Slide each finger horizontally · bend range \(Int(model.value(17))) semitones").font(.caption2);Spacer();Text("a product of Diallo Beats Audio Lab").font(.system(size:9)).foregroundColor(.secondary)}.padding(.horizontal,10)
            }
        }.padding(.vertical,8)
    }
    @ViewBuilder private var page:some View {
        if let index=macros.firstIndex(of:tab) { ParameterSlider(model:model,id:index,title:macros[index]);Text(macroDescription(index)).font(.callout);Button("Reset macro to center"){model.set(index,0.5)} }
        else {switch tab {
        case "Instrument":
            TextField("Model name",text:$model.name).textFieldStyle(.roundedBorder)
            enumPicker("Engine",id:28,labels:["Hybrid · Original","Reconstructed","Sample follow","Mallet"])
            Text("Original uses exact recorded anchors and harmonic modeling between them. Sample follow transposes a nearby anchor; pitch and duration remain linked in this native first version.").font(.caption).foregroundColor(.secondary)
            HStack{Button("Import model / audio"){importing=true};Button("Save Reflection"){save(false)};Button("Save playable comparison"){save(true)}}.buttonStyle(.bordered)
            Picker("Visible keyboard keys",selection:$noteCount){Text("12").tag(12);Text("24").tag(24);Text("36").tag(36)}.pickerStyle(.segmented)
        case "Tone XY": XYControl(model:model,x:10,y:11,left:"Dark",right:"Bright",bottom:"Pure",top:"Rich");Text("Brightness/filter range horizontally; harmonic energy vertically.").font(.caption)
        case "Behavior XY": XYControl(model:model,x:12,y:13,left:"Soft",right:"Aggressive",bottom:"Clean",top:"Organic");Text("Excitation and drive horizontally; noise contribution vertically.").font(.caption)
        case "Performance":
            enumPicker("Voice behavior",id:18,labels:["Poly","Mono","Legato"])
            ParameterSlider(model:model,id:19,title:"Legato glide · ms",range:10...250)
            enumPicker("Articulation layer",id:20,labels:["Sustain","Trill","Staccato","Accent","Breathy","Alternate"])
            Toggle("High velocity selects Trill",isOn:Binding(get:{model.value(25)>0.5},set:{model.set(25,$0 ? 1:0)}))
            ParameterSlider(model:model,id:26,title:"Trill velocity threshold",range:1...127)
            ParameterSlider(model:model,id:23,title:"Generated trill rate · Hz",range:3...15)
            ParameterSlider(model:model,id:24,title:"Generated trill interval · semitones",range:1...12)
            ParameterSlider(model:model,id:27,title:"Maximum note duration · 0 = natural",range:0...15)
            Text("Recorded articulation layers preserve their source performance. Missing layers use the nearest model; generated trills apply to harmonic voices. Mono/Legato use last held note priority.").font(.caption)
        case "Sources":
            Button("Import model or add an audio anchor"){importing=true}.buttonStyle(.borderedProminent)
            Stepper("Audio root: \(noteName(model.rootMidi)) · MIDI \(model.rootMidi)",value:$model.rootMidi,in:24...108)
            HStack{TextField("Start seconds",value:$model.cropStart,format:.number).textFieldStyle(.roundedBorder);TextField("End seconds",value:$model.cropEnd,format:.number).textFieldStyle(.roundedBorder)}
            Text("For audio imports, choose the root key, source start/end and Performance articulation first. Audio is added as one anchor, up to 15 seconds. Automatic note extraction currently remains in the web analyzer; import its saved JSON to use analyzed maps here.").font(.caption)
            ForEach(Array((model.reflection["provenance"] as? [[String:Any]] ?? []).enumerated()),id:\.offset){_,p in VStack(alignment:.leading){Text(p["filename"] as? String ?? p["archive"] as? String ?? "Reference source").font(.headline);Text("\(p["articulation"] as? String ?? "reference") · rights: \(p["rightsStatus"] as? String ?? "unverified")").font(.caption)}}
        case "DNA Edit":
            Text("Reset returns the user offset to zero while retaining analyzed/model values. Native playback currently applies attack, decay and release offsets; other measured fields remain available as model metadata.").font(.caption)
            let parameters=model.reflection["global"] as? [String:[String:Any]] ?? [:]
            ForEach(parameters.keys.sorted(),id:\.self){key in OffsetEditor(model:model,key:key,parameter:parameters[key] ?? [:])}
            if parameters.isEmpty {Text("Import an analyzed Reflection to edit its measured baseline.").foregroundColor(.secondary)}
        case "Anchors":
            let anchors=model.reflection["anchors"] as? [[String:Any]] ?? []
            ForEach(Array(anchors.enumerated()),id:\.offset){_,a in DisclosureGroup("\(noteName(a["midi"] as? Int ?? 60)) · \(a["sourceFilename"] as? String ?? "model")") {
                let parameters=a["parameters"] as? [String:[String:Any]] ?? [:]
                ForEach(parameters.keys.sorted(),id:\.self){key in Text("\(key): \(String(describing:parameters[key]?["model"] ?? "unsupported"))").font(.caption).textSelection(.enabled)}
                Text("Unsupported: \((a["unsupported"] as? [String] ?? []).joined(separator:", "))").font(.caption).foregroundColor(.secondary)
            }}
        case "Era":enumPicker("Recording Era",id:21,labels:["None","Vintage bandwidth","Warm bandwidth"]);ParameterSlider(model:model,id:22,title:"Era amount");Text("A separate adjustable bandwidth layer. These are illustrative presets, not measured historical recording chains.").font(.caption)
        case "Output":
            ParameterSlider(model:model,id:14,title:"Master volume")
            ParameterSlider(model:model,id:15,title:"Global pitch wheel",range:-1...1);Button("Center pitch wheel"){model.set(15,0)}
            ParameterSlider(model:model,id:16,title:"Mod wheel · vibrato")
            ParameterSlider(model:model,id:17,title:"Pitch bend range · semitones",range:1...48)
        default:Text("Native instrument v0.1.0 · iOS/iPadOS 15.4+").font(.headline);Text("Import audio-free DNA Reflections or playable comparisons made by the web app. The native engine provides touch performance, host MIDI/MPE, parameter automation and host state recall. Native automatic analysis and independent time stretching remain future work. No source recordings are bundled.").font(.callout)
        }}
    }
    private func enumPicker(_ title:String,id:Int,labels:[String])->some View {Picker(title,selection:Binding(get:{Int(model.value(id))},set:{model.set(id,Float($0))})){ForEach(labels.indices,id:\.self){i in Text(labels[i]).tag(i)}}.pickerStyle(.menu)}
    private func save(_ audio:Bool){do{document=PresetDocument(data:try model.exportData(includeAudio:audio));exportName=model.name+(audio ? "-playable-comparison":"-reflection");exporting=true}catch{model.status=error.localizedDescription}}
    private func macroDescription(_ index:Int)->String {[
        "Attack time relative to the analyzed onset.","Body level and the modeled strike's ringing strength.","Spectral brightness through the native tone filter.","Upper harmonic energy in reconstructed voices.","Additional excitation noise.","A small fundamental resonance emphasis; measured modal resonance is not yet implemented.","Velocity response across volume and harmonic energy.","Release response around the model baseline.","Slow pitch movement around the fundamental.","Velocity-sensitive nonlinear saturation inside the voice."
    ][index]}
}
struct ParameterSlider:View {
    @ObservedObject var model:InstrumentModel
    let id:Int
    let title:String
    var range:ClosedRange<Float> = 0...1
    var body:some View{VStack(alignment:.leading){HStack{Text(title);Spacer();Text(String(format:range.upperBound>2 ? "%0.0f":"%0.2f",model.value(id))).monospacedDigit()};Slider(value:model.binding(id),in:range).accessibilityLabel(title)}}
}
struct XYControl:View {
    @ObservedObject var model:InstrumentModel
    let x:Int,y:Int
    let left:String,right:String,bottom:String,top:String
    var body:some View{VStack{HStack{Text(left);Spacer();Text(right)};GeometryReader{g in ZStack{RoundedRectangle(cornerRadius:12).fill(Color.teal.opacity(0.25));Circle().fill(Color.orange).frame(width:22,height:22).position(x:CGFloat(model.value(x))*g.size.width,y:(1-CGFloat(model.value(y)))*g.size.height)}.contentShape(Rectangle()).gesture(DragGesture(minimumDistance:0).onChanged{v in model.set(x,Float(v.location.x/g.size.width));model.set(y,1-Float(v.location.y/g.size.height))})}.frame(height:130);HStack{Text(bottom);Spacer();Text(top)};HStack{ParameterSlider(model:model,id:x,title:"X");ParameterSlider(model:model,id:y,title:"Y")}}}
}
struct OffsetEditor:View {
    @ObservedObject var model:InstrumentModel
    let key:String
    let parameter:[String:Any]
    @State private var offset=0.0
    var body:some View{VStack(alignment:.leading){Text(key).font(.headline);Text("Analyzed \(String(describing:parameter["analyzed"] ?? "unknown")) · Model \(String(describing:parameter["model"] ?? "unknown")) · Confidence \(String(describing:parameter["confidence"] ?? 0))").font(.caption);HStack{TextField("User offset",value:$offset,format:.number).textFieldStyle(.roundedBorder);Button("Apply"){model.editOffset(key:key,offset:offset)};Button("Reset"){offset=0;model.editOffset(key:key,offset:0)}}}.onAppear{offset=(parameter["offset"] as? NSNumber)?.doubleValue ?? 0}}
}
