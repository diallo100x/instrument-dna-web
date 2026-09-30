import SwiftUI
import UIKit

enum PlayingSurface: String, CaseIterable { case piano="Piano", mallet="Mallet", fretboard="Fretboard", pads="Drum Pads" }
struct TouchInstrument: UIViewRepresentable {
    @ObservedObject var model: InstrumentModel
    var style: PlayingSurface
    var firstNote: Int
    var noteCount: Int
    var independent: Bool
    func makeUIView(context:Context)->TouchInstrumentView { TouchInstrumentView(model:model) }
    func updateUIView(_ view:TouchInstrumentView,context:Context) { view.configure(style:style,firstNote:firstNote,noteCount:noteCount,independent:independent) }
    static func dismantleUIView(_ uiView:TouchInstrumentView,coordinator:()){uiView.cancelTouches()}
}
final class TouchInstrumentView: UIView {
    struct Contact { let slot:Int;let midi:Int;let origin:CGPoint;var location:CGPoint }
    let model: InstrumentModel
    var style:PlayingSurface = .piano,firstNote=48,noteCount=24,independent=true
    private var contacts:[UITouch:Contact]=[:]
    init(model:InstrumentModel){self.model=model;super.init(frame:.zero);isMultipleTouchEnabled=true;isExclusiveTouch=false;accessibilityLabel="Playable multitouch instrument. Slide horizontally for pitch.";backgroundColor=UIColor(red:0.06,green:0.1,blue:0.12,alpha:1)}
    required init?(coder:NSCoder){fatalError("Use init(model:)")}
    func configure(style:PlayingSurface,firstNote:Int,noteCount:Int,independent:Bool){if self.style != style || self.firstNote != firstNote || self.noteCount != noteCount || self.independent != independent {cancelTouches();self.style=style;self.firstNote=firstNote;self.noteCount=noteCount;self.independent=independent;setNeedsDisplay()}}
    func cancelTouches(){for contact in contacts.values {model.unit.touchNote(contact.slot,midi:contact.midi,velocity:0,down:false);model.unit.touchBend(contact.slot,semitones:0)};contacts.removeAll();model.set(15,0);setNeedsDisplay()}
    private func isBlack(_ n:Int)->Bool {[1,3,6,8,10].contains(n%12)}
    private func keyRects()->[(Int,CGRect,Bool)] { let notes=Array(firstNote..<min(128,firstNote+noteCount));let whites=notes.filter{!isBlack($0)},width=bounds.width/CGFloat(max(1,whites.count));var result:[(Int,CGRect,Bool)]=[];for (i,n) in whites.enumerated(){result.append((n,CGRect(x:CGFloat(i)*width,y:0,width:width,height:bounds.height),false))};for n in notes.filter({isBlack($0)}){let before=whites.filter{$0<n}.count;result.append((n,CGRect(x:CGFloat(before)*width-width*0.3,y:0,width:width*0.6,height:bounds.height*0.63),true))};return result }
    private func note(at point:CGPoint)->Int? {guard bounds.contains(point) else{return nil};switch style {
    case .piano,.mallet: return keyRects().reversed().first{$0.1.contains(point)}?.0
    case .pads:let col=min(3,Int(point.x/bounds.width*4)),row=min(3,Int(point.y/bounds.height*4));return min(127,firstNote+(3-row)*4+col)
    case .fretboard:let strings=[0,5,10,15,19,24],row=min(5,Int(point.y/bounds.height*6)),fret=min(8,Int(point.x/bounds.width*9));return min(127,firstNote+strings[row]+fret)
    }}
    override func touchesBegan(_ touches:Set<UITouch>,with event:UIEvent?){for touch in touches {let point=touch.location(in:self);guard let midi=note(at:point),let slot=(0..<32).first(where:{candidate in !contacts.values.contains{$0.slot==candidate}})else{continue};let normalized=Float(point.y/max(1,bounds.height));let velocity:Float=touch.maximumPossibleForce>0&&touch.force>0 ? max(0.15,min(1,Float(touch.force/touch.maximumPossibleForce))) : 0.35+0.6*normalized;contacts[touch]=Contact(slot:slot,midi:midi,origin:point,location:point);model.unit.touchBend(slot,semitones:0);model.unit.touchNote(slot,midi:midi,velocity:velocity,down:true)};setNeedsDisplay()}
    override func touchesMoved(_ touches:Set<UITouch>,with event:UIEvent?){for touch in touches {guard var contact=contacts[touch]else{continue};let point=touch.location(in:self);contact.location=point;contacts[touch]=contact;let pixelsPerSemitone=bounds.width/CGFloat(style == .fretboard ? 9 : style == .pads ? 4 : noteCount);let semitones=Float((point.x-contact.origin.x)/max(1,pixelsPerSemitone));if independent {model.unit.touchBend(contact.slot,semitones:min(model.value(17),max(-model.value(17),semitones)))}else{model.set(15,min(1,max(-1,semitones/max(0.1,model.value(17)))))} };setNeedsDisplay()}
    override func touchesEnded(_ touches:Set<UITouch>,with event:UIEvent?){end(touches)}
    override func touchesCancelled(_ touches:Set<UITouch>,with event:UIEvent?){end(touches)}
    private func end(_ touches:Set<UITouch>){for touch in touches {guard let contact=contacts.removeValue(forKey:touch)else{continue};model.unit.touchNote(contact.slot,midi:contact.midi,velocity:0,down:false);model.unit.touchBend(contact.slot,semitones:0)};if contacts.isEmpty && !independent {model.set(15,0)};setNeedsDisplay()}
    override func draw(_ rect:CGRect){guard let context=UIGraphicsGetCurrentContext()else{return};let active=Set(contacts.values.map(\.midi));switch style {
    case .piano,.mallet:
        for (midi,key,black) in keyRects(){var shape=key.insetBy(dx:1,dy:style == .mallet ? 8:1);if style == .mallet && black {shape.origin.y=4;shape.size.height=bounds.height*0.66};let color:UIColor=active.contains(midi) ? .systemOrange : black ? UIColor(red:0.14,green:0.22,blue:0.25,alpha:1) : style == .mallet ? UIColor(red:0.72,green:0.53,blue:0.28,alpha:1) : UIColor(white:0.92,alpha:1);color.setFill();UIBezierPath(roundedRect:shape,cornerRadius:style == .mallet ? 9:2).fill();label(noteName(midi),in:shape,color:active.contains(midi) ? .black : black ? .white:.black)}
    case .pads:
        for row in 0..<4 {for col in 0..<4 {let midi=min(127,firstNote+(3-row)*4+col);let key=CGRect(x:CGFloat(col)*bounds.width/4,y:CGFloat(row)*bounds.height/4,width:bounds.width/4,height:bounds.height/4).insetBy(dx:3,dy:3);(active.contains(midi) ? UIColor.systemOrange:UIColor(red:0.2,green:0.4,blue:0.43,alpha:1)).setFill();UIBezierPath(roundedRect:key,cornerRadius:10).fill();label(noteName(midi),in:key,color:.white)}}
    case .fretboard:
        UIColor(red:0.25,green:0.17,blue:0.1,alpha:1).setFill();context.fill(bounds);for fret in 0...9 {context.setStrokeColor(UIColor.systemGray.cgColor);context.setLineWidth(2);let x=CGFloat(fret)*bounds.width/9;context.move(to:CGPoint(x:x,y:0));context.addLine(to:CGPoint(x:x,y:bounds.height));context.strokePath()};for row in 0..<6 {let y=(CGFloat(row)+0.5)*bounds.height/6;context.setStrokeColor(UIColor.systemGray4.cgColor);context.setLineWidth(CGFloat(6-row)*0.3+0.7);context.move(to:CGPoint(x:0,y:y));context.addLine(to:CGPoint(x:bounds.width,y:y));context.strokePath();for fret in 0..<9 {let key=CGRect(x:CGFloat(fret)*bounds.width/9,y:CGFloat(row)*bounds.height/6,width:bounds.width/9,height:bounds.height/6);let midi=min(127,firstNote+[0,5,10,15,19,24][row]+fret);label(noteName(midi),in:key,color:active.contains(midi) ? .systemOrange:.white)}}
    }
    for c in contacts.values {UIColor.systemOrange.withAlphaComponent(0.5).setFill();context.fillEllipse(in:CGRect(x:c.location.x-10,y:c.location.y-10,width:20,height:20))}
    }
    private func label(_ text:String,in rect:CGRect,color:UIColor){let attrs:[NSAttributedString.Key:Any]=[.font:UIFont.systemFont(ofSize:11,weight:.medium),.foregroundColor:color];let size=(text as NSString).size(withAttributes:attrs);(text as NSString).draw(at:CGPoint(x:rect.midX-size.width/2,y:rect.maxY-size.height-7),withAttributes:attrs)}
}
