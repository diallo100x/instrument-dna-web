import {readFile} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
import {emptyReflection,VERSION} from '../src/dna.js';
import {analyzeBuffer} from '../src/analyzer.js';
import {EVIDENCE_FORMAT,validateManifest} from '../src/recognition.js';

const [manifestPath,segmentId,audioPath]=process.argv.slice(2);
if(!manifestPath||!segmentId||!audioPath){console.error('Usage: node research/native-predict.mjs MANIFEST.json SEGMENT_ID local-audio-file');process.exitCode=2}
else try{
  const manifest=validateManifest(JSON.parse(await readFile(manifestPath,'utf8')));
  const segment=manifest.segments.find(x=>x.id===segmentId);if(!segment)throw Error('Segment not in manifest');
  // This research-only runner reads a local file through ffmpeg. It does not upload or copy it into Git.
  const rate=22050,run=spawnSync('ffmpeg',['-v','error','-ss',String(segment.start),'-i',audioPath,'-t',String(segment.end-segment.start),'-ac','1','-ar',String(rate),'-f','f32le','-'],{maxBuffer:64*1024*1024});
  if(run.error||run.status!==0)throw Error(`ffmpeg decode failed: ${run.error?.message||run.stderr.toString()}`);
  if(run.stdout.byteLength%4)throw Error('Incomplete PCM output');
  const aligned=run.stdout.buffer.slice(run.stdout.byteOffset,run.stdout.byteOffset+run.stdout.byteLength),samples=new Float32Array(aligned),dna=emptyReflection();
  const result=analyzeBuffer({sampleRate:rate,length:samples.length,getChannelData:()=>samples},dna,segment.profile||'sustained');
  const notes=result.events.map(e=>({midi:e.midi,start:segment.start+e.start,end:segment.start+e.end,confidence:e.confidence.pitch}));
  const source=manifest.sources.find(x=>x.id===segment.sourceId);
  console.log(JSON.stringify({format:EVIDENCE_FORMAT,version:1,system:{id:'instrument-dna-native',version:VERSION,license:'project-owned',role:'note-transcription',execution:'local research'},analysisDate:new Date().toISOString(),source:{id:source.id,reference:source.sourceReference,rightsStatus:source.rightsStatus,redistributionPermitted:source.redistributionPermitted},segments:[{id:segment.id,notes}]},null,2));
}catch(error){console.error(error.message);process.exitCode=1}
