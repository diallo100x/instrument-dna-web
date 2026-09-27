// Neutral research interchange: no external classifier, model weights, or audio data.
export const EVIDENCE_FORMAT='instrument-dna-research-evidence';
export const MANIFEST_FORMAT='instrument-dna-research-manifest';

export function validateManifest(manifest){
  if(manifest?.format!==MANIFEST_FORMAT||manifest.version!==1||!Array.isArray(manifest.sources)||!Array.isArray(manifest.segments))throw Error('Invalid research manifest');
  const ids=new Set();
  for(const source of manifest.sources){
    if(!source.id||ids.has(source.id)||!source.rightsStatus||typeof source.redistributionPermitted!=='boolean')throw Error('Source needs a unique ID and explicit rights metadata');
    ids.add(source.id);
  }
  const segments=new Set();
  for(const segment of manifest.segments){
    if(!segment.id||segments.has(segment.id)||!ids.has(segment.sourceId)||!Number.isFinite(segment.start)||!Number.isFinite(segment.end)||segment.start<0||segment.end<=segment.start)throw Error('Invalid research segment');
    segments.add(segment.id);
  }
  return manifest;
}

export function validateEvidence(evidence,manifest){
  validateManifest(manifest);
  if(evidence?.format!==EVIDENCE_FORMAT||evidence.version!==1||!evidence.system?.id||!evidence.system?.version||!evidence.system?.license||!Array.isArray(evidence.segments))throw Error('Invalid research evidence');
  if(/"(?:audioData|audioBase64|pcm|wavData|embeddedAudio)"\s*:/.test(JSON.stringify(evidence)))throw Error('Research evidence must not embed source audio');
  const sources=new Map(manifest.sources.map(s=>[s.id,s]));
  const source=sources.get(evidence.source?.id);
  if(!source||evidence.source.rightsStatus!==source.rightsStatus||evidence.source.redistributionPermitted!==source.redistributionPermitted)throw Error('Evidence must carry matching source rights metadata');
  const available=new Set(manifest.segments.filter(s=>s.sourceId===source.id).map(s=>s.id));
  const seen=new Set();
  for(const segment of evidence.segments){
    if(!available.has(segment.id)||seen.has(segment.id)||segment.notes&&!Array.isArray(segment.notes)||segment.family&&(!segment.family.label||!Number.isFinite(segment.family.score)))throw Error('Invalid segment prediction');
    seen.add(segment.id);
    for(const note of segment.notes||[]){if(!Number.isInteger(note.midi)||note.midi<0||note.midi>127||!Number.isFinite(note.start)||!Number.isFinite(note.end)||note.end<=note.start)throw Error('Invalid predicted note')}
  }
  return evidence;
}

export function matchNotes(truth=[],predicted=[],onsetTolerance=.12){
  const used=new Set();let matches=0;
  for(const expected of [...truth].sort((a,b)=>a.start-b.start)){
    const candidates=predicted.map((note,i)=>({note,i,distance:Math.abs(note.start-expected.start)})).filter(({note,i,distance})=>!used.has(i)&&note.midi===expected.midi&&distance<=onsetTolerance);
    candidates.sort((a,b)=>a.distance-b.distance);
    const index=candidates[0]?.i??-1;
    if(index>=0){used.add(index);matches++}
  }
  const precision=predicted.length?matches/predicted.length:truth.length?0:1;
  const recall=truth.length?matches/truth.length:predicted.length?0:1;
  return {matches,precision,recall,f1:precision+recall?2*precision*recall/(precision+recall):0};
}

export function evaluateSystem(manifest,evidence){
  validateEvidence(evidence,manifest);
  const byId=new Map(evidence.segments.map(x=>[x.id,x])),rows=[];
  for(const reference of manifest.segments){
    const predicted=byId.get(reference.id);if(!predicted)continue;
    const truth=reference.truth||{},row={segmentId:reference.id};
    if(typeof truth.family==='string')row.familyCorrect=predicted.family?.label===truth.family;
    if(typeof truth.speech==='boolean')row.speechCorrect=predicted.speech?.present===truth.speech;
    if(Array.isArray(truth.notes))row.notes=matchNotes(truth.notes,predicted.notes||[]);
    if(Object.keys(row).length>1)rows.push(row);
  }
  return {system:evidence.system.id,version:evidence.system.version,scoredSegments:rows.length,rows};
}

export function compareSystems(manifest,evidenceList){
  validateManifest(manifest);
  const ids=new Set();for(const e of evidenceList){validateEvidence(e,manifest);if(ids.has(e.system.id))throw Error('Use one evidence file per system ID');ids.add(e.system.id)}
  const suggestions=[];
  for(const segment of manifest.segments){
    const votes=new Map();
    for(const evidence of evidenceList){const result=evidence.segments.find(x=>x.id===segment.id);if(result?.family?.label){const label=result.family.label;votes.set(label,[...(votes.get(label)||[]),evidence.system.id])}}
    const ranked=[...votes].sort((a,b)=>b[1].length-a[1].length);
    const winner=ranked[0];
    suggestions.push({segmentId:segment.id,family:winner&&winner[1].length>=2&&winner[1].length>(ranked[1]?.[1].length||0)?winner[0]:null,agreement:winner?.[1].length||0,systems:winner?.[1]||[],status:winner&&winner[1].length>=2&&winner[1].length>(ranked[1]?.[1].length||0)?'suggested':'review required'});
  }
  return {evaluations:evidenceList.map(e=>evaluateSystem(manifest,e)),suggestions};
}
