import {test} from 'node:test';
import assert from 'node:assert/strict';
import {fitPhysicalNote,physicalModelAt} from '../src/physical-fit.js';
import {renderPhysical} from '../src/physical.js';
import {emptyReflection,importReflection,serializable} from '../src/dna.js';
const sr=16000;
function recording(midi,modes,seconds=2){const hz=440*2**((midi-69)/12);return Float32Array.from({length:sr*seconds},(_,i)=>modes.reduce((s,[ratio,gain,t60])=>s+gain*Math.sin(2*Math.PI*hz*ratio*i/sr)*Math.exp(-Math.log(1000)*i/sr/t60),0));}
test('modal fitting recovers independent inharmonic frequencies and decay, renders finite sound',()=>{
 const fit=fitPhysicalNote(recording(60,[[1,.5,2],[2.71,.3,1],[4.08,.2,.7]]),sr,60);
 assert.equal(fit.model.origin,'analyzed');assert.equal(fit.model.modes.length,3);
 for(const [i,expected] of [1,2.71,4.08].entries())assert(Math.abs(fit.model.modes[i].ratio-expected)<.01);
 for(const [i,expected] of [2,1,.7].entries())assert(Math.abs(fit.model.modes[i].t60-expected)<.12);
 const audio=renderPhysical(fit.model,sr,60,100);assert(audio.every(Number.isFinite));assert(audio.some(x=>Math.abs(x)>.001));
});
test('string fitting estimates one-pole loss and feedback from harmonic decay',()=>{
 const hz=440,tone=.72,base=-Math.log(1000)/2;
 const modes=[1,2,3,4].map(r=>[r,.5/r,-Math.log(1000)/(base+hz*Math.log(tone/Math.sqrt(1+(1-tone)**2-2*(1-tone)*Math.cos(2*Math.PI*hz*r/sr))))]);
 const fit=fitPhysicalNote(recording(69,modes),sr,69,'waveguide');assert(Math.abs(fit.model.waveguideTone-tone)<.03);assert(Math.abs(fit.model.decay-2)<.2);assert(fit.lossError<.1);
 assert(renderPhysical(fit.model,sr,69).some(x=>Math.abs(x)>.001));
});
test('silent, short, growing and sustained recordings do not masquerade as physical measurements',()=>{
 assert.throws(()=>fitPhysicalNote(new Float32Array(sr),sr,60));
 assert.throws(()=>fitPhysicalNote(new Float32Array(100),sr,60));
 assert.throws(()=>fitPhysicalNote(recording(60,[[1,.5,1e9]]),sr,60));
 const invalid=recording(60,[[1,.5,2]]);invalid[4]=NaN;assert.throws(()=>fitPhysicalNote(invalid,sr,60));
 assert.throws(()=>fitPhysicalNote(recording(60,[[1,.5,2]]),sr,60,'waveguide'));
});
test('per-anchor physical fits survive audio-free Reflection roundtrip without changing analyzed DNA',()=>{
 const dna=emptyReflection(),a=fitPhysicalNote(recording(60,[[1,.5,2],[2.71,.3,1]]),sr,60),b=fitPhysicalNote(recording(72,[[1,.5,1],[3,.3,.6]]),sr,72);
 dna.extensions={physicalModel:a.model,physicalFits:{version:1,anchors:[a,b]}};
 const loaded=importReflection(JSON.parse(JSON.stringify(serializable(dna))));assert.equal(physicalModelAt(loaded,73).referenceMidi,72);assert.equal(physicalModelAt(loaded,61).referenceMidi,60);assert(!loaded.audio);
});
