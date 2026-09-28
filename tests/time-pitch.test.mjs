import {test} from 'node:test';
import assert from 'node:assert/strict';
import {renderExpressiveNote} from '../src/time-pitch.js';

const rate=22050,length=Math.round(.6*rate),input=new Float32Array(length);
let phase=0;
for(let i=0;i<length;i++){
  phase+=2*Math.PI*(440+6*Math.sin(2*Math.PI*5*i/rate))/rate;
  input[i]=.4*Math.sin(phase);
}
function measuredPitch(signal,from,to){
  const crossings=[];
  for(let i=Math.floor(from*rate)+1;i<Math.min(signal.length,Math.floor(to*rate));i++)if(signal[i-1]<0&&signal[i]>=0)crossings.push(i);
  return (crossings.length-1)*rate/(crossings.at(-1)-crossings[0]);
}

test('untouched natural anchor keeps the original waveform',()=>{
  assert.deepEqual(renderExpressiveNote(input,rate,1,input.length/rate),input);
});
test('granular rendering changes pitch and length independently',()=>{
  const ratio=2**(2/12),natural=renderExpressiveNote(input,rate,ratio,.6),extended=renderExpressiveNote(input,rate,ratio,1);
  assert.equal(natural.length,length);
  assert.equal(extended.length,rate);
  for(const sound of [natural,extended]){
    assert.ok(Math.abs(measuredPitch(sound,.15,.45)-440*ratio)<8);
    assert.ok(sound.every(Number.isFinite));
  }
  assert.throws(()=>renderExpressiveNote(input,rate,2,1),/Unsupported/);
});
test('struck rendering keeps the opening mallet transient',()=>{
  const hit=new Float32Array(rate*.5);
  for(let i=0;i<hit.length;i++){const t=i/rate;hit[i]=Math.exp(-(((t-.007)/.0015)**2))*Math.cos(2*Math.PI*440*t)}
  const normal=renderExpressiveNote(hit,rate,1.1,.5),struck=renderExpressiveNote(hit,rate,1.1,.5,{preserveAttack:true});
  const peak=signal=>Math.max(...signal.subarray(0,Math.round(rate*.02)).map(Math.abs));
  assert.ok(peak(struck)>peak(normal)*1.3);
  assert.ok(struck.every(Number.isFinite));
});
