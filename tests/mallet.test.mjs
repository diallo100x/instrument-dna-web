import test from 'node:test';
import assert from 'node:assert/strict';
import {malletMapping,malletResponse,renderModeledMallet} from '../src/mallet.js';

test('mallet map distinguishes exact, transferred and distant strikes',()=>{
  const anchors=[{midi:52},{midi:56},{midi:59},{midi:61},{midi:64}];
  assert.deepEqual(malletMapping(anchors,56),{kind:'recorded',anchor:anchors[1]});
  assert.deepEqual(malletMapping(anchors,60),{kind:'shifted',anchor:anchors[2]});
  assert.equal(malletMapping(anchors,80).kind,'modeled');
  assert.equal(malletMapping(anchors,56,n=>n!==56).kind,'shifted');
  assert.equal(malletMapping(anchors,56,()=>false).kind,'modeled');
});

test('soft mallet playing mutes attack and upper content, hard playing increases both',()=>{
  const soft=malletResponse(28),hard=malletResponse(120);
  assert.ok(hard.gain>soft.gain*2);
  assert.ok(hard.cutoff>soft.cutoff*4);
  assert.ok(hard.attack<soft.attack);
  assert.ok(hard.strike>soft.strike*4);
  const model=renderModeledMallet(22050,60,{harmonicAmplitudes:[1,.3],decaySeconds:1},100,.5);
  assert.equal(model.length,11025);
  assert.ok(model.some(x=>Math.abs(x)>.01));
  assert.ok(model.every(Number.isFinite));
});
