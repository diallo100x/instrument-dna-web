import {test} from 'node:test';
import assert from 'node:assert/strict';
import {emptyReflection,param} from '../src/dna.js';
import {saveComparison,loadComparison} from '../src/comparison.js';

function fakeBuffer(channels,length,rate){const data=Array.from({length:channels},()=>new Float32Array(length));return {sampleRate:rate,numberOfChannels:channels,length,getChannelData:i=>data[i],copyToChannel:(samples,i)=>data[i].set(samples)}}
test('playable comparison retains original anchor samples and mode independently of Reflection',()=>{
  const dna=emptyReflection();dna.anchors=[{midi:69,confidence:{overall:.8},parameters:{brightness:param(.4)}}];
  const original=fakeBuffer(1,8820,22050);for(let i=0;i<original.length;i++)original.getChannelData(0)[i]=.31*Math.sin(2*Math.PI*440*i/22050);
  const data=saveComparison(dna,new Map([[69,original]]),'HybridOriginal');
  assert.equal(data.reflection.audio,undefined);
  assert.equal(data.audio.length,1);
  const restored=loadComparison(JSON.parse(JSON.stringify(data)),fakeBuffer);
  assert.equal(restored.hybridMode,'HybridOriginal');
  assert.deepEqual(restored.clips.get(69).getChannelData(0),original.getChannelData(0));
  delete data.reflection.name;data.reflection.classification.name='Pífano';
  assert.equal(loadComparison(data,fakeBuffer).dna.name,'Pífano DNA Model');
  assert.throws(()=>loadComparison({...data,audio:[{...data.audio[0],midi:70}]},fakeBuffer),/Invalid comparison anchor/);
  dna.performance.layers={sustain:[dna.anchors[0]],trill:[{...dna.anchors[0],articulation:'trill'}]};
  const layered=saveComparison(dna,new Map([[69,original]]),'HybridStretch',new Map([['trill:69',original]]));
  const loadedLayer=loadComparison(JSON.parse(JSON.stringify(layered)),fakeBuffer);
  assert.deepEqual(loadedLayer.layerClips.get('trill:69').getChannelData(0),original.getChannelData(0));
});
