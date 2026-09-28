import {clamp} from './dna.js';

// Keep the recorded range visible in the UI. A distant note is synthesized
// instead of applying an extreme pitch shift to a short metallic recording.
export function malletMapping(anchors,n,available=()=>true){
  const mapped=anchors.filter(a=>available(a.midi)).sort((a,b)=>Math.abs(a.midi-n)-Math.abs(b.midi-n)||a.midi-b.midi);
  if(!mapped.length)return {kind:'modeled',anchor:null};
  const anchor=mapped[0],distance=Math.abs(anchor.midi-n);
  return {kind:distance===0?'recorded':distance<=5?'shifted':'modeled',anchor};
}

export function malletResponse(velocity){
  const force=clamp((Number(velocity)||0)/127);
  return {
    gain:.12+.88*force**1.35,
    cutoff:900+13500*force**1.55,
    attack:.002+(.024*(1-force)**1.7),
    strike:.05+.95*force**1.8,
  };
}

// Conservative fallback when no nearby source attack exists. The decay is
// deliberately finite and uses only the measured harmonic distribution;
// unmeasured bar modes and mallet hardness are not claimed as measurements.
export function renderModeledMallet(sampleRate,n,parameters={},velocity=100,duration=1.6){
  const length=Math.max(1,Math.round(sampleRate*duration)),out=new Float32Array(length);
  const f0=440*2**((n-69)/12),amps=parameters.harmonicAmplitudes||[1,.32,.14,.08];
  const response=malletResponse(velocity),decay=clamp(Number(parameters.decaySeconds)||1.3,.18,3);
  let noiseSeed=12345;
  for(let i=0;i<length;i++){
    const t=i/sampleRate,ring=Math.exp(-3*t/decay);let tone=0;
    for(let h=0;h<Math.min(amps.length,12);h++){
      const frequency=f0*(h+1)*(1+(Number(parameters.inharmonicity)||0)*h*h*.001);
      if(frequency<sampleRate*.47)tone+=(Number(amps[h])||0)*Math.sin(2*Math.PI*frequency*t);
    }
    noiseSeed=(1664525*noiseSeed+1013904223)>>>0;
    const hit=((noiseSeed/0xffffffff)*2-1)*response.strike*Math.exp(-t*110);
    out[i]=clamp((tone*ring*.25+hit*.12)*Math.min(1,t/.003),-1,1);
  }
  return out;
}
