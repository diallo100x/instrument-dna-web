import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
const browser=await chromium.launch({args:['--autoplay-policy=no-user-gesture-required']});
const page=await browser.newPage({viewport:{width:1100,height:820},acceptDownloads:true});
const errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
await page.addInitScript(()=>{
 const input={onmidimessage:null};window.__testMidi=input;Object.defineProperty(navigator,'requestMIDIAccess',{value:async()=>({inputs:new Map([['test',input]]),onstatechange:null})});
 const OriginalWorklet=window.AudioWorkletNode;window.AudioWorkletNode=new Proxy(OriginalWorklet,{construct(target,args){const voice=new target(...args);window.__testWorklet=voice;return voice;}});
 const Native=window.AudioContext;window.AudioContext=new Proxy(Native,{construct(target,args){const ctx=new target(...args);window.__testContext=ctx;return ctx;}});
 const connect=AudioNode.prototype.connect;AudioNode.prototype.connect=function(destination,...args){
  if(destination instanceof AudioDestinationNode){const analyser=this.context.createAnalyser();analyser.fftSize=2048;connect.call(this,analyser);connect.call(analyser,destination,...args);window.__testAnalyser=analyser;return destination;}return connect.call(this,destination,...args);
 };
});
await page.goto('http://127.0.0.1:8000');await page.waitForFunction(()=>document.querySelector('#factoryPreset').options.length===8);
const ids=['marimba','kalimba','chime','djembe','nylon-string','reed-pipe','scalar-guitar'];
for(const id of ids){
 await page.selectOption('#factoryPreset',id);await page.click('#loadFactory');await page.waitForFunction(()=>document.querySelector('#status').textContent.includes('authored physical model'));
 assert.equal(await page.inputValue('#mode'),'Physical');
 const key=page.locator('[data-n="60"]');await key.scrollIntoViewIfNeeded();

 const box=await key.boundingBox();await page.mouse.move(box.x+box.width/2,box.y+box.height/2);await page.mouse.down();
 await page.waitForTimeout(160);
 const power=await page.evaluate(()=>{const a=new Float32Array(window.__testAnalyser.fftSize);window.__testAnalyser.getFloatTimeDomainData(a);return a.reduce((sum,x)=>sum+x*x,0)/a.length;});assert(power>1e-10,`${id} silent (${power})`);
 await page.mouse.up();await page.waitForTimeout(160);
}
// Exercise the existing Web MIDI input handler (synthetic port; no physical hardware).
await page.waitForFunction(()=>!!window.__testMidi.onmidimessage);
await page.evaluate(()=>window.__testMidi.onmidimessage({data:new Uint8Array([144,67,90])}));
await page.waitForTimeout(120);
assert(await page.evaluate(()=>{const a=new Float32Array(window.__testAnalyser.fftSize);window.__testAnalyser.getFloatTimeDomainData(a);return a.some(x=>Math.abs(x)>.00001);}), 'MIDI physical voice silent');
await page.evaluate(()=>window.__testMidi.onmidimessage({data:new Uint8Array([128,67,0])}));
await page.waitForTimeout(260);
// Scalar Guitar: all generated layers, tuning at the actual worklet and persistence.
await page.selectOption('#factoryPreset','scalar-guitar');await page.click('#loadFactory');await page.waitForFunction(()=>document.querySelector('#modelName').value.includes('Scalar Guitar'));
for(const reference of ['432','440'])for(const role of ['sustain','trill','staccato','accent','breathy','alternate']){
 await page.selectOption('#referenceHz',reference);await page.selectOption('#articulation',role);
 const key=page.locator('[data-n="69"]');await key.scrollIntoViewIfNeeded();const b=await key.boundingBox();await page.mouse.move(b.x+b.width/2,b.y+b.height/2);await page.mouse.down();await page.waitForTimeout(90);
 assert.equal(await page.evaluate(()=>window.__testWorklet.parameters.get('frequency').value),Number(reference));
 assert(await page.evaluate(()=>{const a=new Float32Array(window.__testAnalyser.fftSize);window.__testAnalyser.getFloatTimeDomainData(a);return a.some(x=>Math.abs(x)>.00001);}),`Scalar ${reference} ${role} silent`);
 await page.mouse.up();await page.waitForTimeout(200);
}
await page.selectOption('#referenceHz','432');await page.selectOption('#articulation','staccato');
const scalarDownload=page.waitForEvent('download');await page.click('#export');const scalarFile=await (await scalarDownload).path();const scalar=JSON.parse(await fs.readFile(scalarFile,'utf8'));
assert.equal(scalar.performance.referenceHz,432);assert.equal(scalar.performance.selectedArticulation,'staccato');assert.equal(scalar.extensions.physicalModel.kind,'additive-string');
await page.selectOption('#referenceHz','440');await page.locator('#import').setInputFiles(scalarFile);await page.waitForFunction(()=>document.querySelector('#referenceHz').value==='432');assert.equal(await page.inputValue('#articulation'),'staccato');
// Save/load audio-free physical edits through the existing Reflection workflow.
await page.selectOption('#factoryPreset','marimba');await page.click('#loadFactory');await page.waitForFunction(()=>document.querySelector('#modelName').value.includes('Marimba'));
await page.locator('[aria-label="Damping"]').evaluate(e=>{e.value='0.81';e.dispatchEvent(new Event('input',{bubbles:true}));});
const downloadPromise=page.waitForEvent('download');await page.click('#export');const download=await downloadPromise;const filename=await download.path();const dna=JSON.parse(await fs.readFile(filename,'utf8'));assert.equal(dna.extensions.physicalControls.damping,.81);assert(!dna.audio);
await page.locator('#import').setInputFiles(filename);await page.waitForFunction(()=>document.querySelector('#mode').value==='Physical');
await page.screenshot({path:'physical-browser.png',fullPage:true});
// Preserve ordinary source import/analysis and audition.
const sr=16000,n=sr;const wav=Buffer.alloc(44+n*2);wav.write('RIFF');wav.writeUInt32LE(36+n*2,4);wav.write('WAVEfmt ',8);wav.writeUInt32LE(16,16);wav.writeUInt16LE(1,20);wav.writeUInt16LE(1,22);wav.writeUInt32LE(sr,24);wav.writeUInt32LE(sr*2,28);wav.writeUInt16LE(2,32);wav.writeUInt16LE(16,34);wav.write('data',36);wav.writeUInt32LE(n*2,40);for(let i=0;i<n;i++)wav.writeInt16LE(Math.round(.5*32767*Math.sin(2*Math.PI*440*i/sr)),44+i*2);
await page.locator('#file').setInputFiles({name:'A4-reference.wav',mimeType:'audio/wav',buffer:wav});await page.waitForFunction(()=>!document.querySelector('#cropWrap').hidden);await page.selectOption('#analysisProfile','sustained');await page.click('#analyze');console.log('Source analysis:',await page.textContent('#status'));await page.waitForFunction(()=>document.querySelector('#eventList tbody')||document.querySelector('#eventList table tr:nth-child(2)'));
await page.locator('#eventList button').filter({hasText:'Listen'}).first().click();await page.waitForTimeout(100);
assert(await page.evaluate(()=>{const a=new Float32Array(window.__testAnalyser.fftSize);window.__testAnalyser.getFloatTimeDomainData(a);return a.some(x=>Math.abs(x)>.00001);}), 'Source slice preview silent');
await page.waitForTimeout(1100);
await page.selectOption('#mode','HybridOriginal');const key=page.locator('[data-n="69"]');await key.scrollIntoViewIfNeeded();const box=await key.boundingBox();await page.mouse.move(box.x+box.width/2,box.y+box.height/2);await page.mouse.down();await page.waitForTimeout(100);assert(await page.evaluate(()=>{const a=new Float32Array(window.__testAnalyser.fftSize);window.__testAnalyser.getFloatTimeDomainData(a);return a.some(x=>Math.abs(x)>.00001);}), 'Hybrid audition silent');await page.mouse.up();
// Fit a real imported PCM recording, exercise both engines and preserve comparison audio.
const count=sr*2,plucked=Buffer.alloc(44+count*2);wav.copy(plucked,0,0,44);plucked.writeUInt32LE(36+count*2,4);plucked.writeUInt32LE(count*2,40);
for(let i=0;i<count;i++){const hz=440,tone=.72,base=-Math.log(1000)/2;let value=0;for(let h=1;h<=4;h++){const loss=hz*Math.log(tone/Math.sqrt(1+(1-tone)**2-2*(1-tone)*Math.cos(2*Math.PI*hz*h/sr)));value+=.35/h*Math.sin(2*Math.PI*hz*h*i/sr)*Math.exp((base+loss)*i/sr);}plucked.writeInt16LE(Math.round(Math.max(-1,Math.min(1,value))*32767),44+i*2);}
await page.locator('#addSource').uncheck();await page.locator('#file').setInputFiles({name:'plucked-reference.wav',mimeType:'audio/wav',buffer:plucked});await page.waitForFunction(()=>document.querySelector('#cropEnd').value>1.5);await page.selectOption('#analysisProfile','plucked');await page.click('#analyze');
for(const kind of ['modal','waveguide']){
 await page.selectOption('#fitKind',kind);await page.click('#fitPhysical');await page.waitForFunction(()=>!document.querySelector('#fitPhysical').disabled);
 assert.equal(await page.inputValue('#mode'),'Physical',await page.textContent('#status'));
 const save=page.waitForEvent('download');await page.click('#saveComparison');const file=await (await save).path();const comparison=JSON.parse(await fs.readFile(file,'utf8'));
 assert(comparison.reflection.extensions.physicalFits.anchors.length>0);assert(comparison.audio.length>0);assert.equal(comparison.reflection.extensions.physicalModel.kind,kind);
 await page.locator('#import').setInputFiles(file);await page.waitForFunction(()=>document.querySelector('#status').textContent.includes('Original slices retained'));
 for(const mode of ['Physical','HybridOriginal']){await page.selectOption('#mode',mode);const k=page.locator('[data-n="69"]');await k.scrollIntoViewIfNeeded();const b=await k.boundingBox();await page.mouse.move(b.x+b.width/2,b.y+b.height/2);await page.mouse.down();await page.waitForTimeout(160);assert(await page.evaluate(()=>{const a=new Float32Array(window.__testAnalyser.fftSize);window.__testAnalyser.getFloatTimeDomainData(a);return a.some(x=>Math.abs(x)>.00001);}),`${kind} ${mode} silent`);await page.mouse.up();await page.waitForTimeout(250);}
}
const hybridSave=page.waitForEvent('download');await page.click('#saveComparison');const hybridFile=await (await hybridSave).path();await page.locator('#import').setInputFiles(hybridFile);await page.waitForFunction(()=>document.querySelector('#status').textContent.includes('Original slices retained'));assert.equal(await page.inputValue('#mode'),'HybridOriginal');
await page.screenshot({path:'physical-browser.png',fullPage:true});
assert.equal(errors.length,0,errors.join('\n'));await browser.close();console.log('Browser: modal/string source fitting and playable comparison roundtrip, seven live AudioWorklet presets audible, physical edits export/import, source import/analysis, slice preview, synthetic Web MIDI and Hybrid audition passed; no console/page errors.');
