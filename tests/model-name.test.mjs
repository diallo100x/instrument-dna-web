import test from 'node:test';
import assert from 'node:assert/strict';
import {emptyReflection,importReflection,serializable} from '../src/dna.js';
import {suggestedModelName,modelFilename} from '../src/model-name.js';

test('instrument name suggests a model name and safe preset filenames',()=>{
  assert.equal(suggestedModelName('Pífano'),'Pífano DNA Model');
  assert.equal(modelFilename('Pífano · Airy Legato','reflection'),'pifano-airy-legato-reflection.json');
  assert.equal(modelFilename('Pífano / Trill','comparison'),'pifano-trill-playable-comparison.json');
  assert.equal(modelFilename('***','comparison'),'instrument-dna-playable-comparison.json');
});
test('custom names round trip and older unnamed presets inherit instrument name',()=>{
  const dna=emptyReflection();dna.classification.name='Pífano';dna.name='Pífano · Airy Legato';dna.performance.voiceMode='legato';dna.performance.glideMs=110;
  const updated=importReflection(serializable(dna));
  assert.equal(updated.name,'Pífano · Airy Legato');
  assert.equal(updated.performance.glideMs,110);
  delete dna.name;
  assert.equal(importReflection(dna).name,'Pífano DNA Model');
});
