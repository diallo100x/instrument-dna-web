import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {renderPhysical} from '../src/physical.js';
import {importReflection,serializable,modelAt} from '../src/dna.js';
const preset=JSON.parse(fs.readFileSync('presets/factory/scalar-guitar.json'));
const model=preset.extensions.physicalModel;
const power=(a,from=0,to=a.length)=>a.slice(from,to).reduce((s,x)=>s+x*x,0)/(to-from);
function component(a,hz,from=.04,to=.2,sr=24000){let re=0,im=0;for(let i=Math.floor(from*sr);i<to*sr;i++){re+=a[i]*Math.cos(2*Math.PI*hz*i/sr);im+=a[i]*Math.sin(2*Math.PI*hz*i/sr);}return Math.hypot(re,im);}
function peak(a,expected){let best=-1,at=0;for(let f=expected-2;f<=expected+2;f+=.1){let v=component(a,f,.08,.7);if(v>best){best=v;at=f;}}return at;}
test('Scalar Guitar keeps the supplied harmonic recipe and generated, audio-free sparse layers',()=>{
 assert.deepEqual(model.modes.slice(0,8).map(m=>m.gain),[1,.5,.6,.3,.4,.1,.25,.15]);
 assert.deepEqual(preset.capture.range,[40,88]);assert(!preset.anchors.some(a=>a.midi===66));
 assert.deepEqual(modelAt(preset,66).anchors,[64,68]);
 assert(preset.anchors.every(a=>a.parameters.f0.analyzed===null&&a.confidence.overall===0));
 assert.equal(Object.keys(preset.performance.layers).length,6);
 const copy=importReflection(JSON.parse(JSON.stringify(serializable(preset))));assert.deepEqual(copy,preset);assert.equal(copy.sampleSlots.length,0);
});
test('A4 and inferred F#4 tune to both references without changing harmonic DNA',()=>{
 for(const referenceHz of [432,435,440,444])for(const midi of [66,69]){
  const hz=referenceHz*2**((midi-69)/12),out=renderPhysical(model,24000,midi,100,1,{referenceHz,noise:0});
  assert(Math.abs(peak(out,hz)-hz)<.3);
 }
 const edited=structuredClone(preset);edited.performance.referenceHz=432;
 assert.equal(importReflection(serializable(edited)).performance.referenceHz,432);assert.deepEqual(edited.anchors,preset.anchors);
 const old=structuredClone(preset);delete old.performance.referenceHz;assert.equal(importReflection(old).performance.referenceHz,440);
 for(const bad of [0,433,NaN,'432']){const invalid=structuredClone(preset);invalid.performance.referenceHz=bad;assert.throws(()=>importReflection(invalid));}
});
test('every guitar key and layer renders finite bounded sound at 432 and 440',()=>{
 for(const referenceHz of [432,435,440,444])for(let midi=40;midi<=88;midi++)for(const articulation of [0,2,3,4,5]){
  const out=renderPhysical(model,16000,midi,100,.12,{referenceHz,articulation});assert(out.every(x=>Number.isFinite(x)&&Math.abs(x)<=1));assert(power(out)>1e-9,`${midi} ${articulation}`);
 }
});
test('upper harmonics decay faster; velocity and palm mute change timbre and sustain',()=>{
 const hz=440*2**((66-69)/12),options={noise:0,brightness:1},normal=renderPhysical(model,24000,66,100,1,options),muted=renderPhysical(model,24000,66,100,1,{...options,articulation:2});
 assert(power(muted,12000,20000)<power(normal,12000,20000)*.1);
 const early=component(normal,3*hz)/component(normal,hz),late=component(normal,3*hz,.5,.7)/component(normal,hz,.5,.7);assert(late<early*.4);
 const soft=renderPhysical(model,24000,66,30,.3,options),hard=renderPhysical(model,24000,66,120,.3,options);
 assert(component(hard,hz*3)/component(hard,hz)>component(soft,hz*3)/component(soft,hz)*1.5);
});
