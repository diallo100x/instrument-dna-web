import Foundation
func tone(_ hz:Double,_ seconds:Double,rate:Double=44100)->[Float]{(0..<Int(seconds*rate)).map{Float(0.4*sin(2*Double.pi*hz*Double($0)/rate))}}
let silence=[Float](repeating:0,count:44100/4)
assert(NativeAnalyzer.analyze(silence,sampleRate:44100,profile:"sustained",density:3).isEmpty)
let notes=NativeAnalyzer.analyze(tone(440,0.8)+silence+tone(523.251,0.8),sampleRate:44100,profile:"sustained",density:3)
assert(notes.map{$0.midi} == [69,72],"Pitch detection returned \(notes.map{$0.midi})")
assert(notes.allSatisfy{$0.confidence>0.8 && $0.end>$0.start && $0.harmonics.count==12})
let input=(60...71).flatMap{tone(440*pow(2,Double($0-69)/12),0.3)+silence}
assert(NativeAnalyzer.analyze(input,sampleRate:44100,profile:"struck",density:3).count==3)
assert(NativeAnalyzer.analyze(input,sampleRate:44100,profile:"struck",density:12).count==12)
let anchor:[String:Any]=["midi":69,"parameters":["f0":["analyzed":440,"model":440,"offset":0]],"articulation":"sustain"]
let reflection:[String:Any]=["format":"instrument-dna-reflection","anchors":[anchor],"performance":["layers":[:]]]
let clip:[String:Any]=["midi":69,"channels":["unchanged-audio"],"sampleRate":44100]
let document:[String:Any]=["format":"instrument-dna-playable-comparison","reflection":reflection,"audio":[clip]]
let entries=NoteMap.entries(document);assert(entries.count==1 && entries[0].hasAudio)
let edited=try NoteMap.copy(entries[0],to:"trill",in:document)
assert(NoteMap.entries(edited).count==2 && NoteMap.entries(edited).allSatisfy{$0.hasAudio})
let original=(edited["reflection"] as! [String:Any])["anchors"] as! [[String:Any]]
assert((original[0] as NSDictionary).isEqual(to:anchor))
assert((edited["audio"] as! [[String:Any]])[0]["channels"] as! [String] == ["unchanged-audio"])
do { _=try NoteMap.copy(entries[0],to:"trill",in:edited);assertionFailure("Collision should preserve existing layer") }catch{}
let encoded=try JSONSerialization.data(withJSONObject:edited)
let loaded=try JSONSerialization.jsonObject(with:encoded) as! [String:Any]
assert(NoteMap.entries(loaded).count==2)
assert(!NoteMap.entries(reflection)[0].hasAudio)
print("Native analysis/model: silence rejection, pitch detection, sparse/chromatic capture, non-destructive layer copy, audio preservation, collisions and JSON roundtrip passed.")
