import {test} from 'node:test';
import assert from 'node:assert/strict';
import {emptyReflection} from '../src/dna.js';
import {analyzeBuffer} from '../src/analyzer.js';

test('continuous melodic phrase creates separate note slices without silence',()=>{
  const sr=44100,a=new Float32Array(sr*2);
  for(let i=0;i<a.length;i++)a[i]=.3*Math.sin(2*Math.PI*(i<sr?440:523.251)*i/sr);
  const dna=emptyReflection(),result=analyzeBuffer({sampleRate:sr,length:a.length,getChannelData:()=>a},dna);
  assert.ok(result.events.some(e=>e.midi===69&&e.end<1.2));
  assert.ok(result.events.some(e=>e.midi===72&&e.start>.8));
  assert.ok(result.anchors.some(e=>e.midi===69));
  assert.ok(result.anchors.some(e=>e.midi===72));
});

test('plucked profile can split repeated attacks at the same pitch',()=>{
  const sr=44100,a=new Float32Array(sr*2);
  for(let i=0;i<a.length;i++){
    const phase=i%sr,env=phase<sr*.12?phase/(sr*.12):phase>sr*.8?.01:.35;
    a[i]=env*Math.sin(2*Math.PI*440*i/sr);
  }
  const result=analyzeBuffer({sampleRate:sr,length:a.length,getChannelData:()=>a},emptyReflection(),'plucked');
  assert.ok(result.events.filter(e=>e.midi===69).length>=2);
});
