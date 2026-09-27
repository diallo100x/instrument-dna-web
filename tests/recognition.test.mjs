import {test} from 'node:test';
import assert from 'node:assert/strict';
import {MANIFEST_FORMAT,EVIDENCE_FORMAT,validateManifest,validateEvidence,compareSystems,matchNotes} from '../src/recognition.js';

const manifest={format:MANIFEST_FORMAT,version:1,sources:[{id:'test-signal',rightsStatus:'generated test audio',redistributionPermitted:true}],segments:[{id:'a',sourceId:'test-signal',start:0,end:2,truth:{family:'flute',speech:false,notes:[{midi:69,start:.5,end:.8}]}}]};
function evidence(id,label,notes=[]){return {format:EVIDENCE_FORMAT,version:1,system:{id,version:'1',license:'test-only'},source:{id:'test-signal',rightsStatus:'generated test audio',redistributionPermitted:true},segments:[{id:'a',family:{label,score:.9},speech:{present:false,score:.6},notes}]}}

test('research manifest requires rights and never accepts embedded audio',()=>{
  assert.equal(validateManifest(manifest),manifest);
  assert.throws(()=>validateManifest({...manifest,sources:[{id:'test-signal'}]}),/rights metadata/);
  assert.throws(()=>validateEvidence({...evidence('a','flute'),audioData:'base64'},manifest),/must not embed/);
  assert.throws(()=>validateEvidence({...evidence('a','flute'),source:{id:'test-signal',rightsStatus:'unverified',redistributionPermitted:true}},manifest),/matching source rights/);
});

test('note score uses labeled onset/pitch and does not invent unavailable truth',()=>{
  const score=matchNotes([{midi:69,start:.5,end:.8}],[{midi:69,start:.55,end:.9},{midi:72,start:1,end:1.2}]);
  assert.equal(score.matches,1);assert.equal(score.precision,.5);assert.equal(score.recall,1);
  assert.equal(matchNotes([{midi:69,start:0,end:.1},{midi:69,start:.18,end:.3}],[{midi:69,start:.1,end:.2},{midi:69,start:0,end:.1}]).matches,2);
  const unreviewed={...manifest,segments:[{...manifest.segments[0],truth:{annotationStatus:'pending'}}]};
  assert.equal(compareSystems(unreviewed,[evidence('native','flute')]).evaluations[0].scoredSegments,0);
});

test('two distinct systems can suggest a family but disagreement abstains',()=>{
  const agreed=compareSystems(manifest,[evidence('a','flute',[{midi:69,start:.54,end:.8}]),evidence('b','flute')]);
  assert.equal(agreed.suggestions[0].family,'flute');assert.equal(agreed.suggestions[0].status,'suggested');
  assert.equal(agreed.evaluations[0].rows[0].notes.f1,1);
  const split=compareSystems(manifest,[evidence('a','flute'),evidence('b','speech')]);
  assert.equal(split.suggestions[0].family,null);
  assert.throws(()=>compareSystems(manifest,[evidence('a','flute'),evidence('a','flute')]),/one evidence file/);
});
