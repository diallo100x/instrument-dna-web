import SwiftUI
import AppKit

enum PlayingSurface:String,CaseIterable {case piano="Piano",mallet="Mallet",fretboard="Fretboard",pads="Drum Pads"}
struct TouchInstrument:NSViewRepresentable {
    @ObservedObject var model:InstrumentModel
    var style:PlayingSurface;var firstNote:Int;var noteCount:Int;var independent:Bool
    func makeNSView(context:Context)->MacInstrumentSurface{MacInstrumentSurface(model:model)}
    func updateNSView(_ view:MacInstrumentSurface,context:Context){view.configure(style:style,firstNote:firstNote,noteCount:noteCount,independent:independent)}
    static func dismantleNSView(_ view:MacInstrumentSurface,coordinator:()){view.releaseNotes()}
}
final class MacInstrumentSurface:NSView {
    private let model:InstrumentModel
    private var style:PlayingSurface = .piano,firstNote=48,noteCount=24,independent=true
    private var held:[Int:Int]=[:]
    private var origin=CGPoint.zero
    private let computerKeys:[UInt16:Int]=[0:0,13:1,1:2,14:3,2:4,3:5,17:6,5:7,16:8,4:9,32:10,38:11,40:12]
    override var isFlipped:Bool{true}
    override var acceptsFirstResponder:Bool{true}
    init(model:InstrumentModel){self.model=model;super.init(frame:.zero);setAccessibilityLabel("Instrument keys. Click and drag for pitch bend. A W S E D F T G Y H U J K play notes when focused.")}
    required init?(coder:NSCoder){fatalError("Use init(model:)")}
    func configure(style:PlayingSurface,firstNote:Int,noteCount:Int,independent:Bool){
        if self.style != style || self.firstNote != firstNote || self.noteCount != noteCount || self.independent != independent {
            releaseNotes();self.style=style;self.firstNote=firstNote;self.noteCount=noteCount;self.independent=independent;needsDisplay=true
        }
    }
    func releaseNotes(){for(slot,midi) in held{model.unit.touchNote(slot,midi:midi,velocity:0,down:false);model.unit.touchBend(slot,semitones:0)};held.removeAll();if !independent{model.set(15,0)};needsDisplay=true}
    override func resignFirstResponder()->Bool{releaseNotes();return super.resignFirstResponder()}
    override func viewWillMove(toWindow newWindow:NSWindow?){if newWindow==nil{releaseNotes()};super.viewWillMove(toWindow:newWindow)}
    private func black(_ midi:Int)->Bool{[1,3,6,8,10].contains(midi%12)}
    private func keys()->[(Int,CGRect,Bool)] {
        switch style {
        case .piano,.mallet:
            let notes=Array(firstNote..<min(128,firstNote+noteCount)),white=notes.filter{!black($0)}
            let width=bounds.width/CGFloat(max(1,white.count))
            var result=white.enumerated().map{(i,n) in (n,CGRect(x:CGFloat(i)*width,y:0,width:width,height:bounds.height),false)}
            for n in notes where black(n){let before=white.filter{$0<n}.count;result.append((n,CGRect(x:CGFloat(before)*width-width*0.3,y:0,width:width*0.6,height:bounds.height*0.63),true))};return result
        case .pads:
            return (0..<16).map{i in (min(127,firstNote+(3-i/4)*4+i%4),CGRect(x:CGFloat(i%4)*bounds.width/4,y:CGFloat(i/4)*bounds.height/4,width:bounds.width/4,height:bounds.height/4),false)}
        case .fretboard:
            return (0..<54).map{i in (min(127,firstNote+[0,5,10,15,19,24][i/9]+i%9),CGRect(x:CGFloat(i%9)*bounds.width/9,y:CGFloat(i/9)*bounds.height/6,width:bounds.width/9,height:bounds.height/6),false)}
        }
    }
    override func mouseDown(with event:NSEvent){window?.makeFirstResponder(self);let point=convert(event.locationInWindow,from:nil);guard let key=keys().reversed().first(where:{$0.1.contains(point)})else{return};origin=point;held[0]=key.0;model.unit.touchBend(0,semitones:0);model.unit.touchNote(0,midi:key.0,velocity:Float(0.35+0.6*min(1,max(0,point.y/max(1,bounds.height)))) ,down:true);needsDisplay=true}
    override func mouseDragged(with event:NSEvent){guard held[0] != nil else{return};let point=convert(event.locationInWindow,from:nil);let pixels=bounds.width/CGFloat(style == .fretboard ? 9:style == .pads ? 4:noteCount);let bend=Float((point.x-origin.x)/max(1,pixels));let range=max(0.1,model.value(17));if independent{model.unit.touchBend(0,semitones:min(range,max(-range,bend)))}else{model.set(15,min(1,max(-1,bend/range)))}}
    override func mouseUp(with event:NSEvent){if let midi=held.removeValue(forKey:0){model.unit.touchNote(0,midi:midi,velocity:0,down:false);model.unit.touchBend(0,semitones:0)};if !independent{model.set(15,0)};needsDisplay=true}
    override func keyDown(with event:NSEvent){guard !event.isARepeat,let offset=computerKeys[event.keyCode]else{super.keyDown(with:event);return};let slot=offset+1,midi=min(127,firstNote+offset);held[slot]=midi;model.unit.touchNote(slot,midi:midi,velocity:0.8,down:true);needsDisplay=true}
    override func keyUp(with event:NSEvent){guard let offset=computerKeys[event.keyCode],let midi=held.removeValue(forKey:offset+1)else{super.keyUp(with:event);return};model.unit.touchNote(offset+1,midi:midi,velocity:0,down:false);needsDisplay=true}
    override func draw(_ dirtyRect:NSRect){
        NSColor(calibratedRed:0.06,green:0.1,blue:0.12,alpha:1).setFill();bounds.fill()
        for (midi,rect,isBlack) in keys(){let shape=rect.insetBy(dx:style == .pads ? 3:1,dy:style == .mallet ? 7:1)
            let color:NSColor=held.values.contains(midi) ? .systemOrange:isBlack ? .darkGray:style == .mallet || style == .fretboard ? NSColor(calibratedRed:0.65,green:0.45,blue:0.23,alpha:1):.white
            color.setFill();NSBezierPath(roundedRect:shape,xRadius:4,yRadius:4).fill()
            let text=noteName(midi) as NSString,attrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:11),.foregroundColor:isBlack ? NSColor.white:NSColor.black]
            let size=text.size(withAttributes:attrs);text.draw(at:CGPoint(x:shape.midX-size.width/2,y:shape.maxY-size.height-5),withAttributes:attrs)
        }
    }
}
