import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {renderPhysical,validatePhysicalModel} from '../src/physical.js';
import {importReflection,serializable} from '../src/dna.js';
const catalog=JSON.parse(fs.readFileSync('presets/factory/manifest.json'));
const preset=id=>JSON.parse(fs.readFileSync(`presets/factory/${id}.json`));
const power=(a,start=0,end=a.length)=>a.slice(start,end).reduce((sum,x)=>sum+x*x,0)/(end-start);
function component(a,hz,from=.04,to=.2,sr=24000){let re=0,im=0;const begin=Math.round(from*sr),end=Math.round(to*sr);for(let i=begin;i<end;i++){re+=a[i]*Math.cos(2*Math.PI*hz*i/sr);im+=a[i]*Math.sin(2*Math.PI*hz*i/sr);}return Math.hypot(re,im)/(end-begin);}
test('six portable authored factory models roundtrip without embedded audio or invented measurements',()=>{
 assert.equal(catalog.length,6);
 for(const entry of catalog){const dna=importReflection(preset(entry.id)),m=dna.extensions.physicalModel;validatePhysicalModel(m);const copy=JSON.parse(JSON.stringify(serializable(dna)));assert.deepEqual(copy.extensions,m?dna.extensions:{});assert(dna.anchors.every(a=>a.parameters.f0.analyzed===null&&a.confidence.overall===0));assert.equal(dna.sampleSlots.length,0);assert.equal(fs.readFileSync(entry.path,'utf8'),fs.readFileSync(`native/InstrumentDNA/Resources/${entry.id}.json`,'utf8'));}
});
test('all physical families produce finite bounded audible output across low/high registers',()=>{
 for(const {id}of catalog)for(const midi of [36,60,84]){const out=renderPhysical(preset(id).extensions.physicalModel,24000,midi,100,.5);assert(out.every(Number.isFinite));assert(Math.max(...out.map(Math.abs))<=1);assert(power(out)>1e-9,`${id} ${midi} silent`);}
});
test('modal strike has independently tuned inharmonic peaks and finite damping',()=>{
 const model=preset('marimba').extensions.physicalModel,out=renderPhysical(model,24000,60,120,2,{noise:0,brightness:1});const f0=261.6256;
 assert(component(out,f0)>component(out,f0*1.1)*8);
 assert(component(out,f0*3.98)>component(out,f0*3.5)*4);
 assert(power(out,36000,48000)<power(out,1000,6000)*.02);
});
test('velocity changes modal timbre as well as volume',()=>{
 const model=preset('marimba').extensions.physicalModel;
 const soft=renderPhysical(model,24000,60,35,.3,{noise:0,brightness:1}),hard=renderPhysical(model,24000,60,120,.3,{noise:0,brightness:1}),hz=261.6256;
 const softRatio=component(soft,hz*3.98)/component(soft,hz),hardRatio=component(hard,hz*3.98)/component(hard,hz);
 assert(hardRatio>softRatio*1.2);assert(power(hard)>power(soft));
});
test('waveguide string tuning tracks requested note',()=>{
 const model=preset('nylon-string').extensions.physicalModel,out=renderPhysical(model,24000,69,100,1.2,{brightness:1});
 let best=0,bestHz=0;for(let hz=425;hz<=450;hz+=.5){const magnitude=component(out,hz,.2,1);if(magnitude>best){best=magnitude;bestHz=hz;}}
 assert(Math.abs(bestHz-440)<4,`string tuned to ${bestHz}`);
});
test('physical models reject unsupported versions, excessive modes and invalid feedback inputs',()=>{
 const model=preset('marimba').extensions.physicalModel;
 for(const modified of [{...model,version:2},{...model,decay:Infinity},{...model,modes:[]},{...model,modes:Array(17).fill(model.modes[0])},{...model,modes:[{ratio:NaN,gain:1,t60:1}]}])assert.throws(()=>validatePhysicalModel(modified));
});
