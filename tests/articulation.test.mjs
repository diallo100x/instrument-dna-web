import {test} from 'node:test';
import assert from 'node:assert/strict';
import {buildArticulationLayers,performanceArticulation,nearestArticulationAnchor} from '../src/articulation.js';
import {emptyReflection,importReflection} from '../src/dna.js';

test('articulations preserve independent notes at the same pitch',()=>{
  const events=[{midi:69,enabled:true,confidence:{overall:.8},articulation:'sustain'},
    {midi:69,enabled:true,confidence:{overall:.9},articulation:'trill'},
    {midi:72,enabled:true,confidence:{overall:.7},articulation:'trill'},
    {midi:74,enabled:false,confidence:{overall:1},articulation:'trill'}];
  const layers=buildArticulationLayers(events,12);
  assert.equal(layers.sustain.length,1);assert.equal(layers.trill.length,2);
  assert.equal(layers.sustain[0],events[0]);assert.equal(layers.trill[0],events[1]);
  assert.equal(nearestArticulationAnchor(layers.trill,71)?.midi,72);
  assert.equal(performanceArticulation('sustain',110,true,100),'trill');
  assert.equal(performanceArticulation('sustain',90,true,100),'sustain');
});
test('older Reflections gain layer defaults without losing their anchor data',()=>{
  const old=emptyReflection();delete old.performance.layers;delete old.performance.velocityTrill;
  old.anchors=[{midi:69,parameters:{},confidence:{overall:1}}];
  const updated=importReflection(old);
  assert.equal(updated.anchors.length,1);assert.deepEqual(updated.performance.layers,{});
  assert.equal(updated.performance.velocityTrill,false);
});
