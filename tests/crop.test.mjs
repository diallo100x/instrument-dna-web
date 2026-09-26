import {test} from 'node:test';
import assert from 'node:assert/strict';
import {cropBounds,cropBuffer} from '../src/crop.js';
import {emptyReflection} from '../src/dna.js';
import {analyzeBuffer} from '../src/analyzer.js';

test('crop keeps the requested samples and rejects an empty selection',()=>{
  const sr=1000,source=Float32Array.from({length:3000},(_,i)=>i<1000?.2:i<2000?.5:-.3);
  const buffer={duration:3,sampleRate:sr,length:source.length,numberOfChannels:1,getChannelData:()=>source};
  const context={createBuffer:(_,length,rate)=>{const data=new Float32Array(length);return {length,sampleRate:rate,numberOfChannels:1,duration:length/rate,copyToChannel:(samples)=>data.set(samples),getChannelData:()=>data}}};
  const cut=cropBuffer(context,buffer,1,2);
  assert.equal(cut.length,1000);
  assert.ok([...cut.getChannelData()].every(v=>Math.abs(v-.5)<1e-6));
  assert.deepEqual(cropBounds(-4,5,3),{start:0,end:3,duration:3});
  assert.throws(()=>cropBuffer(context,buffer,1,1.02),/at least 0.1/);
});

test('only the selected note is passed to analysis',()=>{
  const sr=44100,source=new Float32Array(sr*3);
  for(let i=sr/5;i<sr;i++)source[i]=.4*Math.sin(2*Math.PI*440*i/sr);
  for(let i=sr*2;i<sr*2.8;i++)source[i]=.4*Math.sin(2*Math.PI*220*i/sr);
  const buffer={duration:3,sampleRate:sr,length:source.length,numberOfChannels:1,getChannelData:()=>source};
  const context={createBuffer:(_,length,rate)=>{const data=new Float32Array(length);return {length,sampleRate:rate,numberOfChannels:1,duration:length/rate,copyToChannel:(samples)=>data.set(samples),getChannelData:()=>data}}};
  const dna=emptyReflection(),cut=cropBuffer(context,buffer,0,1);
  analyzeBuffer(cut,dna);
  assert.ok(dna.anchors.some(anchor=>Math.abs(anchor.midi-69)<=1));
  assert.ok(!dna.anchors.some(anchor=>Math.abs(anchor.midi-57)<=1));
});
