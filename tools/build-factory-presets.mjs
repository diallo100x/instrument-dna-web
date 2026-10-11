import fs from 'node:fs';
import {emptyReflection,param} from '../src/dna.js';
const recipes=[
 ['marimba','DBAL · Warm Marimba','mallet','modal',[1,3.98,9.92,17.1],[1,.45,.22,.08],[1.5,.7,.28,.13],.52,.22,.16,1.5,false],
 ['kalimba','DBAL · Wooden Kalimba','plucked','modal',[1,2.76,5.4,8.93],[1,.38,.17,.07],[2.3,1.1,.52,.22],.7,.3,.1,2.3,false],
 ['chime','DBAL · Glass Chime','bell','modal',[1,2.71,4.08,5.43,6.79],[1,.5,.27,.15,.08],[4.5,3,2,1,.6],.84,.24,.05,4.5,false],
 ['djembe','DBAL · Hand Drum','percussion','modal',[1,1.59,2.14,2.3,2.65],[1,.55,.28,.17,.12],[.65,.4,.23,.17,.11],.45,.35,.65,.65,false],
 ['nylon-string','DBAL · Plucked String','string','waveguide',[1,2,3,4],[1,.42,.2,.1],[2.8,1.4,.7,.35],.62,.24,.15,2.8,false],
 ['reed-pipe','DBAL · Reed Pipe (experimental)','wind','modal',[1,3,5,7,9],[1,.4,.22,.12,.06],[.3,.22,.16,.12,.08],.6,.2,.3,.3,true],
];
const manifest=[];
for(const [id,name,family,kind,ratios,gains,t60,hardness,position,noise,decay,continuous] of recipes){
 const d=emptyReflection();d.name=name;d.classification={name:name.replace('DBAL · ',''),family};d.capture={density:3,range:[36,96],analysisProfile:continuous?'sustained':family==='string'?'plucked':'struck'};
 d.provenance=[{source:'Diallo Beats Audio Lab authored physical design',itemId:id,rightsStatus:'original authored preset',redistributionPermitted:true,analysisDate:null,analyzerVersion:null}];
 d.extensions.physicalModel={version:1,kind,origin:'authored',referenceMidi:60,continuous,hardness,position,noise,decay,modes:ratios.map((ratio,i)=>({ratio,gain:gains[i],t60:t60[i]}))};
 d.extensions.nativePerformance={engineMode:4,bendRange:2,volume:.7};
 d.anchors=Array.from({length:16},(_,i)=>({midi:36+i*4,source:'authored physical model',articulation:'sustain',start:0,end:0,confidence:{pitch:0,harmonic:0,transient:0,resonance:0,overall:0},parameters:{f0:{...param(440*2**((36+i*4-69)/12),0,'Hz'),analyzed:null},attackSeconds:{...param(.005),analyzed:null},decaySeconds:{...param(decay),analyzed:null},harmonicAmplitudes:{...param(gains),analyzed:null}},unsupported:['reference-audio measurements','automatic instrument identification']}));
 // Designed baselines are model values, never fabricated analyzed measurements.
 d.global={attackSeconds:{analyzed:null,model:.005,offset:0,confidence:0,unit:'s'},decaySeconds:{analyzed:null,model:decay,offset:0,confidence:0,unit:'s'}};
 d.performance.voiceMode=continuous?'legato':'poly';d.created='2026-10-10T00:00:00.000Z';
 fs.writeFileSync(`presets/factory/${id}.json`,JSON.stringify(d,null,2)+'\n');manifest.push({id,name,path:`presets/factory/${id}.json`});
}
fs.writeFileSync('presets/factory/manifest.json',JSON.stringify(manifest,null,2)+'\n');
fs.mkdirSync('native/InstrumentDNA/Resources',{recursive:true});for(const file of fs.readdirSync('presets/factory').filter(x=>x.endsWith('.json')))fs.copyFileSync(`presets/factory/${file}`,`native/InstrumentDNA/Resources/${file}`);
