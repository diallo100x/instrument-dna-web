import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
const browser=await chromium.launch({args:['--autoplay-policy=no-user-gesture-required']});
const page=await browser.newPage({viewport:{width:1100,height:820},acceptDownloads:true});
const errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
await page.addInitScript(()=>{
 const Native=window.AudioContext;window.AudioContext=new Proxy(Native,{construct(target,args){const ctx=new target(...args);window.__testContext=ctx;return ctx;}});
 const connect=AudioNode.prototype.connect;AudioNode.prototype.connect=function(destination,...args){
  if(destination instanceof AudioDestinationNode){const analyser=this.context.createAnalyser();analyser.fftSize=2048;connect.call(this,analyser);connect.call(analyser,destination,...args);window.__testAnalyser=analyser;return destination;}return connect.call(this,destination,...args);
 };
});
await page.goto('http://127.0.0.1:8000');await page.waitForFunction(()=>document.querySelector('#factoryPreset').options.length===7);
const ids=['marimba','kalimba','chime','djembe','nylon-string','reed-pipe'];
for(const id of ids){
 await page.selectOption('#factoryPreset',id);await page.click('#loadFactory');await page.waitForFunction(()=>document.querySelector('#status').textContent.includes('authored physical model'));
 assert.equal(await page.inputValue('#mode'),'Physical');
 const key=page.locator('[data-n="60"]');await key.scrollIntoViewIfNeeded();

 const box=await key.boundingBox();await page.mouse.move(box.x+box.width/2,box.y+box.height/2);await page.mouse.down();
 await page.waitForTimeout(160);
 const power=await page.evaluate(()=>{const a=new Float32Array(window.__testAnalyser.fftSize);window.__testAnalyser.getFloatTimeDomainData(a);return a.reduce((sum,x)=>sum+x*x,0)/a.length;});assert(power>1e-10,`${id} silent (${power})`);
 await page.mouse.up();await page.waitForTimeout(160);
}
// Save/load audio-free physical edits through the existing Reflection workflow.
await page.selectOption('#factoryPreset','marimba');await page.click('#loadFactory');await page.waitForFunction(()=>document.querySelector('#modelName').value.includes('Marimba'));
await page.locator('[aria-label="Damping"]').evaluate(e=>{e.value='0.81';e.dispatchEvent(new Event('input',{bubbles:true}));});
const downloadPromise=page.waitForEvent('download');await page.click('#export');const download=await downloadPromise;const filename=await download.path();const dna=JSON.parse(await fs.readFile(filename,'utf8'));assert.equal(dna.extensions.physicalControls.damping,.81);assert(!dna.audio);
await page.locator('#import').setInputFiles(filename);await page.waitForFunction(()=>document.querySelector('#mode').value==='Physical');
await page.screenshot({path:'physical-browser.png',fullPage:true});
// Preserve ordinary source import/analysis and audition.
const sr=16000,n=sr;const wav=Buffer.alloc(44+n*2);wav.write('RIFF');wav.writeUInt32LE(36+n*2,4);wav.write('WAVEfmt ',8);wav.writeUInt32LE(16,16);wav.writeUInt16LE(1,20);wav.writeUInt16LE(1,22);wav.writeUInt32LE(sr,24);wav.writeUInt32LE(sr*2,28);wav.writeUInt16LE(2,32);wav.writeUInt16LE(16,34);wav.write('data',36);wav.writeUInt32LE(n*2,40);for(let i=0;i<n;i++)wav.writeInt16LE(Math.round(.5*32767*Math.sin(2*Math.PI*440*i/sr)),44+i*2);
await page.locator('#file').setInputFiles({name:'A4-reference.wav',mimeType:'audio/wav',buffer:wav});await page.waitForFunction(()=>!document.querySelector('#cropWrap').hidden);await page.click('#analyze');await page.waitForFunction(()=>document.querySelector('#eventList tbody')||document.querySelector('#eventList table tr:nth-child(2)'));
await page.selectOption('#mode','HybridOriginal');const key=page.locator('[data-n="69"]');await key.scrollIntoViewIfNeeded();const box=await key.boundingBox();await page.mouse.move(box.x+box.width/2,box.y+box.height/2);await page.mouse.down();await page.waitForTimeout(100);assert(await page.evaluate(()=>{const a=new Float32Array(window.__testAnalyser.fftSize);window.__testAnalyser.getFloatTimeDomainData(a);return a.some(x=>Math.abs(x)>.00001);}), 'Hybrid audition silent');await page.mouse.up();
assert.equal(errors.length,0,errors.join('\n'));await browser.close();console.log('Browser: six live AudioWorklet presets audible, physical edits export/import, source import/analysis and Hybrid audition passed; no console/page errors.');
