import test from 'node:test';
import assert from 'node:assert/strict';
import {emptyReflection} from '../src/dna.js';
import {analyzeBuffer} from '../src/analyzer.js';
import {estimatePolyphonicPitches} from '../src/polyphonic.js';

const sr=22050;
function chord(notes){const a=new Float32Array(sr*1.5),start=Math.round(sr*.2);
  for(let i=start;i<Math.min(a.length,start+sr);i++){
    const t=(i-start)/sr,env=Math.min(1,t/.005)*Math.exp(-t/1.4);
    for(const [midi,amplitude] of notes){const f=440*2**((midi-69)/12);
      a[i]+=amplitude*env*(Math.sin(2*Math.PI*f*t)+.23*Math.sin(4*Math.PI*f*t)+.11*Math.sin(6*Math.PI*f*t));
    }
  }
  return {a,start};
}
test('polyphonic onset identifies independent chord pitches without treating harmonics as notes',()=>{
  const {a,start}=chord([[60,.19],[64,.19],[67,.19]]);
  const pitches=estimatePolyphonicPitches(a,sr,start,a.length).map(x=>x.midi);
  assert.deepEqual(pitches,[60,64,67]);
  const dna=emptyReflection(),result=analyzeBuffer({sampleRate:sr,length:a.length,getChannelData:()=>a},dna,'polyphonic');
  assert.deepEqual(result.events.map(e=>e.midi),[60,64,67]);
  assert.ok(result.events.every(e=>e.source==='polyphonic mixture'&&e.measurements.sharedSource&&e.unsupported.includes('isolated note audio')));
  assert.ok(result.events.every(e=>e.parameters.harmonicAmplitudes===undefined));
});
test('a single rich note does not create separate octave anchors',()=>{
  const {a,start}=chord([[60,.5]]);
  const pitches=estimatePolyphonicPitches(a,sr,start,a.length).map(x=>x.midi);
  assert.deepEqual(pitches,[60]);
});
