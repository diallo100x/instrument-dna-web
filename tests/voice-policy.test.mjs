import test from 'node:test';
import assert from 'node:assert/strict';
import {emptyReflection,importReflection} from '../src/dna.js';
import {previousHeld,glideSeconds,glideRatio} from '../src/voice-policy.js';

test('mono priority returns to the most recently held key after release',()=>{
  const held=new Map([[60,82],[64,100],[67,95]]);
  assert.deepEqual(previousHeld(held),[67,95]);
  held.delete(67);
  assert.deepEqual(previousHeld(held),[64,100]);
  held.delete(64);held.delete(60);
  assert.equal(previousHeld(held),null);
});
test('legato glide converts semitone distance and caps transition time',()=>{
  assert.ok(Math.abs(glideRatio(60,72)-.5)<1e-9);
  assert.equal(glideSeconds(70),.07);
  assert.equal(glideSeconds(1000),.25);
});
test('older Reflections remain polyphonic and voice settings round trip',()=>{
  const old=emptyReflection();delete old.performance.voiceMode;delete old.performance.glideMs;
  assert.equal(importReflection(old).performance.voiceMode,'poly');
  assert.equal(importReflection(old).performance.glideMs,70);
  old.performance.voiceMode='legato';old.performance.glideMs=120;
  assert.equal(importReflection(old).performance.voiceMode,'legato');
  assert.equal(importReflection(old).performance.glideMs,120);
});
