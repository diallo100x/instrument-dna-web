import fs from 'node:fs';
import {emptyReflection,param} from '../src/dna.js';
// Original DBAL designs from elementary vibrating-object relationships and
// independently chosen tunings. No vendor preset tables, samples or source code.
const plate=()=>[...new Set(Array.from({length:9},(_,i)=>{const m=1+Math.floor(i/3),n=1+i%3;return (m*m+.73*.73*n*n)/(1+.73*.73);})).values()].sort((a,b)=>a-b).slice(0,6);
const membrane=()=>plate().map(Math.sqrt);
const recipes=[
 ['coupled-vibes','Coupled Vibes','mallet','bar / open resonator','strike',[1,4,9.8,17.2,26.4],[1,.55,.24,.1,.05],[4.2,1.9,.8,.3,.16],[1,2,3],[1,.3,.1],[1.4,.7,.3],.7,.28,.12,.5,.7,1,.75,.0012,.08,.00003],
 ['coupled-marimba','Coupled Wooden Marimba','mallet','wooden bar / tube','strike',[1,4,10,18,28],[1,.42,.19,.08,.03],[1.8,.8,.3,.14,.08],[1,2,3],[1,.22,.08],[.7,.3,.15],.48,.27,.12,.5,.55,1,.65,.002,.2,.00001],
 ['coupled-xylophone','Coupled Xylophone','mallet','bright bar / body','strike',[1,3,6.3,10.8,16.6,24],[1,.62,.28,.12,.05,.02],[.8,.35,.16,.09,.05,.03],[1,2,3],[1,.3,.1],[.28,.15,.08],.88,.23,.08,.35,.4,1,.85,.0005,.12,.00005],
 ['coupled-plate','Coupled Plate Bell','bell','plate / supporting body','strike',plate(),[1,.65,.4,.25,.15,.08],[4,3,2.2,1.6,1,.6],[.61,1.23,2.47],[1,.4,.2],[1.3,.6,.3],.82,.31,.12,.55,.65,.25,.7,.0008,.08,.0002],
 ['coupled-membrane','Coupled Membrane & Shell','percussion','rectangular membrane / shell','strike',membrane(),[1,.55,.4,.28,.17,.1],[.8,.5,.35,.23,.16,.1],[.72,1.4,2.6],[1,.4,.15],[.4,.2,.1],.42,.33,.55,.65,.55,.2,.85,.0015,.15,.0002],
 ['coupled-string','Coupled Plucked String & Body','string','string / body','pluck',[1,2,3,4,5,6,7,8],[1,.55,.35,.22,.14,.1,.06,.04],[3.5,2,1.3,.8,.5,.35,.2,.15],[.43,.94,1.63],[1,.6,.3],[.32,.22,.14],.62,.22,.16,.55,.65,0,.7,.0008,.12,.00015],
 ['coupled-air-pipe','Coupled Air Pipe (experimental)','wind','open pipe / body','air',[1,2,3,4,5,6],[1,.35,.2,.1,.06,.03],[.2,.16,.12,.09,.07,.05],[1,2,3],[1,.25,.1],[.18,.12,.08],.5,.28,.45,.45,.45,1,.5,.0015,.1,0],
];
let manifest=JSON.parse(fs.readFileSync('presets/factory/manifest.json'));
for(const [id,title,family,material,excitation,ratios,gains,t60,bodyRatios,bodyGains,bodyT60,hardness,position,noise,coupling,mix,follow,velocityResponse,contactSeconds,materialLoss,inharmonicity]of recipes){
 const d=emptyReflection(),continuous=excitation==='air';d.name=`DBAL · ${title}`;d.classification={name:title,family};d.created='2026-10-31T00:00:00.000Z';d.capture={density:3,range:[36,96],analysisProfile:continuous?'sustained':excitation==='pluck'?'plucked':'struck'};
 const modes=ratios.map((ratio,i)=>({ratio,gain:gains[i],t60:t60[i]}));
 d.extensions.physicalModel={version:1,kind:'coupled-modal',origin:'authored',referenceMidi:60,continuous,hardness,position,noise,decay:t60[0],modes,coupledBody:{family:material,excitation,referenceHz:440*2**((60-69)/12),coupling,mix,follow,velocityResponse,contactSeconds,materialLoss,inharmonicity,modes:bodyRatios.map((ratio,i)=>({ratio,gain:bodyGains[i],t60:bodyT60[i]}))}};
 d.extensions.nativePerformance={engineMode:4,bendRange:2,volume:.7};
 d.provenance=[{source:'Diallo Beats Audio Lab original coupled-body design',itemId:id,rightsStatus:'original authored preset',redistributionPermitted:true,analysisDate:null,analyzerVersion:null,modelVersion:'coupled-body-1'}];
 d.global={attackSeconds:{...param(.005),analyzed:null,confidence:0},decaySeconds:{...param(t60[0]),analyzed:null,confidence:0}};
 d.anchors=Array.from({length:16},(_,i)=>({midi:36+i*4,source:'authored coupled-body model',articulation:'sustain',start:0,end:0,confidence:{pitch:0,harmonic:0,transient:0,resonance:0,overall:0},parameters:{f0:{...param(440*2**((36+i*4-69)/12),0,'Hz'),analyzed:null},attackSeconds:{...param(.005),analyzed:null},decaySeconds:{...param(t60[0]),analyzed:null},harmonicAmplitudes:{...param(gains),analyzed:null}},unsupported:['reference-audio measurements','automatic instrument identification','learned articulation response']}));
 d.performance.voiceMode=continuous?'legato':'poly';
 const path=`presets/factory/${id}.json`;fs.writeFileSync(path,JSON.stringify(d,null,2)+'\n');manifest=manifest.filter(x=>x.id!==id);manifest.push({id,name:d.name,path,collection:'Coupled bodies · original DBAL designs'});
}
fs.writeFileSync('presets/factory/manifest.json',JSON.stringify(manifest,null,2)+'\n');
for(const e of manifest)fs.copyFileSync(e.path,`native/InstrumentDNA/Resources/${e.id}.json`);
fs.copyFileSync('presets/factory/manifest.json','native/InstrumentDNA/Resources/manifest.json');
