import Foundation

/// Deterministic monophonic analysis. No instrument recognition or chord separation.
enum NativeAnalyzer {
    static let version = "native-monophonic-0.2.0"
    struct Detection {
        let midi: Int
        let start: Double
        let end: Double
        let confidence: Double
        let f0: Double
        let harmonics: [Double]
        let attack: Double
    }
    private struct Frame { let time: Double; let midi: Int; let f0: Double; let confidence: Double; let rms: Double }
    static func analyze(_ samples: [Float], sampleRate: Double, profile: String, density: Int) -> [Detection] {
        guard sampleRate >= 8000, samples.count > 1024 else { return [] }
        // Low-pass before decimation avoids treating aliased upper partials as fundamentals.
        let step = max(1, Int(sampleRate / 8000)), rate = sampleRate / Double(step)
        var pcm: [Double] = []; pcm.reserveCapacity(samples.count / step)
        var filtered = 0.0
        let coefficient = 1-exp(-2 * Double.pi * 3000/sampleRate)
        for (i,sample) in samples.enumerated() { filtered += coefficient * (Double(sample)-filtered); if i % step == 0 { pcm.append(filtered) } }
        let size = 1024, hop = 256
        guard pcm.count >= size else { return [] }
        var frames: [Frame] = []
        let peakRMS = stride(from:0,through:pcm.count-size,by:hop).map { begin in sqrt(pcm[begin..<begin+size].reduce(0){$0+$1*$1}/Double(size)) }.max() ?? 0
        guard peakRMS > 0.0003 else { return [] }
        for begin in stride(from:0,through:pcm.count-size,by:hop) {
            let window = Array(pcm[begin..<begin+size])
            let rms = sqrt(window.reduce(0){$0+$1*$1}/Double(size))
            let time = Double(begin)/rate
            guard rms > max(0.0003,peakRMS*0.035), let pitch = yin(window,rate:rate), pitch.confidence >= 0.75 else {
                frames.append(Frame(time:time,midi:-1,f0:0,confidence:0,rms:rms)); continue
            }
            let midi = Int((69+12*log2(pitch.f0/440)).rounded())
            frames.append(Frame(time:time,midi:(24...108).contains(midi) ? midi : -1,f0:pitch.f0,confidence:pitch.confidence,rms:rms))
        }
        var detections: [Detection] = []
        var first = 0
        while first < frames.count {
            guard frames[first].midi >= 0 else { first += 1; continue }
            var last = first+1
            while last < frames.count, frames[last].midi == frames[first].midi {
                // Repeated struck/plucked notes can share pitch but have separate onsets.
                if profile != "sustained", last-first >= 5, frames[last].rms > frames[last-1].rms*1.8 { break }
                last += 1
            }
            let run = Array(frames[first..<last])
            let start = frames[first].time
            let end = min(Double(samples.count)/sampleRate,frames[last-1].time+Double(size)/rate)
            if run.count >= 3 {
                let pitches = run.map{$0.f0}.sorted(), f0 = pitches[pitches.count/2]
                let center = min(pcm.count-size,Int((start+(end-start)*0.35)*rate))
                let harmonics = harmonicAmplitudes(Array(pcm[center..<center+size]),rate:rate,f0:f0)
                let peakIndex = run.indices.max(by:{run[$0].rms < run[$1].rms}) ?? 0
                detections.append(Detection(midi:frames[first].midi,start:start,end:end,confidence:run.map{$0.confidence}.reduce(0,+)/Double(run.count),f0:f0,harmonics:harmonics,attack:min(0.5,max(0.005,Double(peakIndex*hop)/rate))))
            }
            first = last
        }
        // Preserve the strongest stable occurrence of each measured key, then spread sparse anchors.
        var best: [Int: Detection] = [:]
        for detection in detections {
            let score = detection.confidence * min(2,detection.end-detection.start)
            if let prior = best[detection.midi], prior.confidence * min(2,prior.end-prior.start) >= score { continue }
            best[detection.midi] = detection
        }
        var selected: [Detection] = []
        for octave in Set(best.keys.map{$0/12}).sorted() {
            var available = best.values.filter{$0.midi/12 == octave}.sorted{$0.midi < $1.midi}
            if available.count <= density { selected += available; continue }
            for position in 0..<max(1,density) {
                let target = Double(octave*12) + (Double(position)+0.5)*12/Double(max(1,density))
                let index = available.indices.min { abs(Double(available[$0].midi)-target) < abs(Double(available[$1].midi)-target) }!
                selected.append(available.remove(at:index))
            }
        }
        return selected.sorted{$0.midi < $1.midi}
    }
    private static func yin(_ samples:[Double],rate:Double) -> (f0:Double,confidence:Double)? {
        let maxLag = min(samples.count/2,Int(rate/65)), minLag = max(2,Int(rate/1800))
        var normalized = [Double](repeating:1,count:maxLag+1), differences = normalized
        var sum = 0.0
        for lag in 1...maxLag {
            var difference = 0.0
            for i in 0..<samples.count-maxLag { let delta=samples[i]-samples[i+lag]; difference += delta*delta }
            differences[lag]=difference;sum += difference
            normalized[lag] = sum > 1e-14 ? difference*Double(lag)/sum : 1
        }
        var chosen: Int?
        var lag = minLag
        while lag < maxLag {
            if normalized[lag] < 0.15 { while lag+1 <= maxLag && normalized[lag+1] < normalized[lag] {lag += 1};chosen=lag;break };lag += 1
        }
        guard let index = chosen else {return nil}
        var refined = Double(index)
        if index>1 && index<maxLag {let a=differences[index-1],b=differences[index],c=differences[index+1],denominator=a-2*b+c;if abs(denominator)>1e-12 {refined += max(-0.5,min(0.5,0.5*(a-c)/denominator))}}
        return (rate/refined,max(0,min(1,1-normalized[index])))
    }
    private static func harmonicAmplitudes(_ samples:[Double],rate:Double,f0:Double)->[Double] {
        var amplitudes:[Double]=[]
        for harmonic in 1...12 {
            guard f0*Double(harmonic) < rate*0.45 else {amplitudes.append(0);continue}
            var real=0.0,imaginary=0.0
            for i in samples.indices {let window=0.5-0.5*cos(2*Double.pi*Double(i)/Double(samples.count-1)),angle=2*Double.pi*f0*Double(harmonic*i)/rate;real += samples[i]*window*cos(angle);imaginary += samples[i]*window*sin(angle)}
            amplitudes.append(hypot(real,imaginary))
        }
        let peak=amplitudes.max() ?? 0
        return amplitudes.map{peak>0 ? $0/peak : 0}
    }
}
