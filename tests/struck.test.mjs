import test from 'node:test';
import assert from 'node:assert/strict';
import {emptyReflection} from '../src/dna.js';
import {analyzeBuffer} from '../src/analyzer.js';
import {detectStrikes} from '../src/struck.js';

test('struck profile keeps attacks and separates repeated ringing notes',()=>{
  const sr=44100,a=new Float32Array(sr*3),hits=[{at:.25,hz:440},{at:.85,hz:440},{at:1.45,hz:523.251}];
  for(const {at,hz} of hits){const start=Math.round(at*sr);
    for(let i=start;i<Math.min(a.length,start+sr*1.3);i++){
      const t=(i-start)/sr,envelope=Math.min(1,t/.004)*Math.exp(-t/.3);
      a[i]+=.55*envelope*(Math.sin(2*Math.PI*hz*t)+.12*Math.sin(2*Math.PI*3*hz*t));
    }
  }
  const onsets=detectStrikes(a,sr);
  assert.equal(onsets.length,3);
  const dna=emptyReflection(),result=analyzeBuffer({sampleRate:sr,length:a.length,getChannelData:()=>a},dna,'struck');
  assert.equal(result.events.length,3);
  assert.deepEqual(result.events.map(e=>e.midi),[69,69,72]);
  for(let i=0;i<hits.length;i++){
    assert.ok(Math.abs(result.events[i].start-hits[i].at)<.035,'attack should stay in the source slice');
    assert.ok(result.events[i].measurements.onsetStrength>0);
  }
  assert.ok(result.events[0].end<=result.events[1].start+.015);
  assert.equal(dna.anchors.filter(a=>a.midi===69).length,1);
});

test('struck profile does not invent notes from silence',()=>{
  const sr=44100,a=new Float32Array(sr);
  assert.deepEqual(analyzeBuffer({sampleRate:sr,length:a.length,getChannelData:()=>a},emptyReflection(),'struck').events,[]);
});

test('struck profile can assign an isolated high glockenspiel-range pitch',()=>{
  const sr=44100,a=new Float32Array(sr),hz=2093.005;
  for(let i=Math.round(sr*.15);i<sr*.75;i++){
    const t=(i/sr)-.15;a[i]=.48*Math.min(1,t/.004)*Math.exp(-t/.22)*Math.sin(2*Math.PI*hz*t);
  }
  const events=analyzeBuffer({sampleRate:sr,length:a.length,getChannelData:()=>a},emptyReflection(),'struck').events;
  assert.ok(events.some(e=>e.midi===96),'C7 should be mapped rather than folded into a lower octave');
});
