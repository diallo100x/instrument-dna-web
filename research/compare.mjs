import {readFile} from 'node:fs/promises';
import {compareSystems} from '../src/recognition.js';

const [manifestPath,...evidencePaths]=process.argv.slice(2);
if(!manifestPath||!evidencePaths.length){console.error('Usage: node research/compare.mjs MANIFEST.json EVIDENCE1.json [EVIDENCE2.json ...]');process.exitCode=2}
else try{
  const manifest=JSON.parse(await readFile(manifestPath,'utf8'));
  const evidence=await Promise.all(evidencePaths.map(async path=>JSON.parse(await readFile(path,'utf8'))));
  console.log(JSON.stringify(compareSystems(manifest,evidence),null,2));
}catch(error){console.error(error.message);process.exitCode=1}
