import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {renderPhysical,renderGuitarAudition,validatePhysicalModel} from '../src/physical.js';
import {GuitarRoom,scalarControls} from '../src/scalar-controls.js';
import {importReflection,serializable} from '../src/dna.js';
const preset=JSON.parse(fs.readFileSync('presets/factory/scalar-guitar.json')),model=preset.extensions.physicalModel;
const power=(x,from=0,to=x.length)=>x.slice(from,to).reduce((s,v)=>s+v*v,0)/(to-from);
function partial(a,h){let re=0,im=0;for(let i=1000;i<4000;i++){const phase=2*Math.PI*440*h*i/24000;re+=a[i]*Math.cos(phase);im+=a[i]*Math.sin(phase);}return Math.hypot(re,im);}
test('pickup recipes and ten supplied phases change harmonic balance without changing pitch DNA',()=>{
 assert.deepEqual(model.modes.map(m=>m.phase),[0,.23,-.45,.12,.78,-.34,.55,-.19,.62,-.05]);
 const options={noise:0,brightness:1},neck=renderPhysical(model,24000,69,100,.3,{...options,pickup:1}),bridge=renderPhysical(model,24000,69,100,.3,{...options,pickup:2}),piezo=renderPhysical(model,24000,69,100,.3,{...options,pickup:3});
 assert(partial(bridge,4)/partial(bridge,1)>partial(neck,4)/partial(neck,1)*2);
 assert(partial(piezo,9)>partial(neck,9)*2);
 for(const phase of [NaN,4,'bad']){const invalid=structuredClone(model);invalid.modes[0].phase=phase;assert.throws(()=>validatePhysicalModel(invalid));}
});
test('all guitar controls persist and invalid values are rejected before import',()=>{
 const d=structuredClone(preset);d.performance.referenceHz=435;d.performance.glideMs=2000;d.extensions.scalarControls={pickup:3,vibratoDepth:.3,vibratoRate:7,bodyTexture:.7,room:.8,slideFrom:5,auditionMidi:88};
 assert.deepEqual(importReflection(serializable(d)),d);
 for(const [key,bad] of [['pickup',4],['pickup',1.5],['vibratoDepth',-1],['vibratoRate',0],['bodyTexture',NaN],['room',2],['slideFrom',-13],['auditionMidi',39]]){const x=structuredClone(d);x.extensions.scalarControls[key]=bad;assert.throws(()=>importReflection(x));}
 const original=JSON.parse(fs.readFileSync('presets/factory/scalar-guitar-original.json'));assert.equal(original.extensions.physicalModel.modes.length,8);assert.equal(scalarControls(original).pickup,0);assert.equal(scalarControls(original).room,0);assert.equal(scalarControls(original).vibratoDepth,0);
});
test('vibrato has a delayed onset and offline slides reach a different target path',()=>{
 const common={noise:0,referenceHz:440,pickup:2,vibratoDepth:0,gain:.35},plain=renderGuitarAudition(model,16000,66,100,1,common),vibrato=renderGuitarAudition(model,16000,66,100,1,{...common,vibratoDepth:.5,vibratoRate:5.6}),slide=renderGuitarAudition(model,16000,66,100,1,{...common,slide:true,slideFrom:-4,glideSeconds:.3});
 assert.deepEqual(plain.slice(0,1500),vibrato.slice(0,1500));assert(power(plain.map((x,i)=>x-vibrato[i]),8000,12000)>1e-7);assert(power(plain.map((x,i)=>x-slide[i]),1000,3000)>1e-6);
});
test('shared room has a bounded tail, dry bypass and a reset',()=>{
 const room=new GuitarRoom(48000);let later=0;for(let i=0;i<48000;i++){const x=room.tick(i===0?1:0,1);assert(Number.isFinite(x)&&Math.abs(x)<=1);if(i>2000)later+=x*x;}assert(later>1e-5);room.reset();for(let i=0;i<5000;i++)assert.equal(room.tick(0,1),0);
 const dry=new GuitarRoom(24000);for(let i=0;i<500;i++)assert.equal(dry.tick(.1,0),.1);
 const a=renderGuitarAudition(model,16000,66,100,5,{pickup:1,room:0}),b=renderGuitarAudition(model,16000,66,100,5,{pickup:1,room:1});assert(power(b,68000)>power(a,68000)*10);
});
