import test from 'node:test';
import assert from 'node:assert/strict';
import {selectBaseAnchors,sourceForEvent} from '../src/source-map.js';
import {buildArticulationLayers} from '../src/articulation.js';
const event=(sourceId,articulation,confidence)=>({sourceId,sourceFilename:`${sourceId}.wav`,midi:60,articulation,enabled:true,confidence:{overall:confidence},parameters:{}});
test('a second source can provide a trill at the same pitch without replacing sustain',()=>{
  const sustain=event('first','sustain',.62),trill=event('second','trill',.9),events=[sustain,trill];
  assert.equal(selectBaseAnchors(events,3,true)[0],sustain);
  const layers=buildArticulationLayers(events,3);
  assert.equal(layers.sustain[0],sustain);assert.equal(layers.trill[0],trill);
  assert.equal(selectBaseAnchors(events,3,false)[0],trill);
});
test('disabled source candidates are excluded from both layers',()=>{
  const old=event('first','sustain',.7),newer=event('second','trill',.9);newer.enabled=false;
  assert.deepEqual(selectBaseAnchors([old,newer],3,true),[old]);
  assert.equal(buildArticulationLayers([old,newer],3).trill.length,0);
});

test('an event keeps the buffer belonging to its source ID',()=>{const first={},second={},buffers=new Map([['first',first],['second',second]]);assert.equal(sourceForEvent(event('first','sustain',.5),buffers),first);assert.equal(sourceForEvent(event('second','trill',.5),buffers),second)});
