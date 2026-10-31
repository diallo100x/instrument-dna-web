import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import crypto from 'node:crypto';
import {PhysicalVoice,renderPhysical,validatePhysicalModel} from '../src/physical.js';import {importReflection,serializable} from '../src/dna.js';
const read=id=>JSON.parse(fs.readFileSync(`presets/factory/${id}.json`)),model=id=>read(id).extensions.physicalModel;
const rms=a=>Math.sqrt(a.reduce((s,x)=>s+x*x,0)/a.length);
const difference=(a,b)=>rms(a.map((x,i)=>x-b[i]));
test('legacy factory files retain their preserved baseline hashes',()=>{
 const old=JSON.parse(fs.readFileSync('tests/legacy-factory-hashes.json'));for(const [id,hash]of Object.entries(old))assert.equal(crypto.createHash('sha256').update(fs.readFileSync(`presets/factory/${id}.json`)).digest('hex'),hash);
});
test('seven coupled presets are separate audio-free authored Reflections with editable baselines',()=>{
 const catalog=JSON.parse(fs.readFileSync('presets/factory/manifest.json')),added=catalog.filter(e=>e.id.startsWith('coupled-'));assert.equal(added.length,7);
 for(const {id}of added){const d=importReflection(read(id));assert.equal(d.extensions.physicalModel.origin,'authored');assert(d.anchors.every(a=>a.parameters.f0.analyzed===null&&a.confidence.overall===0));assert.equal(d.sampleSlots.length,0);d.extensions.physicalControls={coupling:.8,bodyMix:.7,resonatorFollow:0,velocityResponse:.9};const round=importReflection(JSON.parse(JSON.stringify(serializable(d))));assert.deepEqual(round.extensions.physicalControls,d.extensions.physicalControls);assert.deepEqual(round.extensions.physicalModel,read(id).extensions.physicalModel);}
});
test('coupling and resonator mix change synthesized output, including compatibility rendering',()=>{
 const m=model('coupled-vibes'),dry=renderPhysical(m,24000,60,100,1,{coupling:0,bodyMix:1}),wet=renderPhysical(m,24000,60,100,1,{coupling:1,bodyMix:1});assert(difference(dry,wet)>1e-5);
 const bypass=renderPhysical(m,24000,60,100,1,{coupling:1,bodyMix:0});assert(difference(bypass,wet)>1e-5);
});
test('resonator pitch tracking can remain fixed while played-note resonances move',()=>{
 const m=model('coupled-vibes'),fixed=new PhysicalVoice(m,24000),following=new PhysicalVoice(m,24000);
 fixed.tick(523.251,{resonatorFollow:0,velocity:.5});following.tick(523.251,{resonatorFollow:1,velocity:.5});
 const b=m.coupledBody,angle=2*Math.PI*b.referenceHz/24000,rad=Math.exp(-6.907755/(b.modes[0].t60*24000));
 assert(Math.abs(fixed.coupled.secondary[0].a1-2*rad*Math.cos(angle))<1e-6);
 assert.notEqual(fixed.coupled.secondary[0].a1,following.coupled.secondary[0].a1);
});
test('velocity response changes normalized timbre and decay, beyond volume',()=>{
 const m=model('coupled-xylophone'),soft=renderPhysical(m,24000,60,30,.5,{velocityResponse:1}),hard=renderPhysical(m,24000,60,120,.5,{velocityResponse:1});
 assert(rms(hard)>rms(soft));const ns=rms(soft),nh=rms(hard);assert(difference(soft.map(x=>x/ns),hard.map(x=>x/nh))>.02);
});
test('new voices remain finite across supported rates, extremes and continuous retuning',()=>{
 for(const rate of [8000,24000,48000,192000])for(const id of ['coupled-vibes','coupled-plate','coupled-string','coupled-air-pipe']){
  const voice=new PhysicalVoice(model(id),rate);let energy=0;
  for(let i=0;i<Math.round(rate*.08);i++){const x=voice.tick(i<rate*.04?65:2093,{velocity:1,hardness:1,damping:0,richness:1,coupling:1,bodyMix:1,resonatorFollow:1,velocityResponse:1});assert(Number.isFinite(x)&&Math.abs(x)<=1);energy+=x*x;}
  assert(energy>1e-10,`${rate} ${id} silent`);
 }
});
test('invalid coupled models and control edits are rejected before rendering',()=>{
 const original=read('coupled-vibes');
 for(const key of ['coupling','mix','follow','velocityResponse','referenceHz','contactSeconds','materialLoss','inharmonicity']){
  const d=structuredClone(original);d.extensions.physicalModel.coupledBody[key]=Infinity;assert.throws(()=>validatePhysicalModel(d.extensions.physicalModel));
 }
 for(const body of [null,{},'bad',{...original.extensions.physicalModel.coupledBody,modes:Array(9).fill({ratio:1,gain:1,t60:1})}]){
  const d=structuredClone(original);d.extensions.physicalModel.coupledBody=body;assert.throws(()=>importReflection(d));
 }
 for(const key of ['coupling','bodyMix','resonatorFollow','velocityResponse']){const d=structuredClone(original);d.extensions.physicalControls={[key]:2};assert.throws(()=>importReflection(d));}
});
