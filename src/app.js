import {emptyReflection,importReflection,serializable,modelAt,midiName,MACROS,clamp,value,param,buildHierarchy} from './dna.js?v=0.5.7';
import {analyzeBuffer,selectAnchors} from './analyzer.js?v=0.5.7';
import {decodeAudioFile} from './audio-import.js';
import {cropBounds,cropBuffer} from './crop.js?v=0.3.8';
import {panView,zoomView,selectionShades} from './wave-view.js?v=0.4.0';
import {renderExpressiveNote} from './time-pitch.js?v=0.5.3';
import {malletMapping,malletResponse,renderModeledMallet} from './mallet.js?v=0.5.5';
import {saveComparison,loadComparison} from './comparison.js?v=0.5.5';
import {selectBaseAnchors,sourceForEvent} from './source-map.js?v=0.5.7';
import {ARTICULATIONS,buildArticulationLayers,performanceArticulation,nearestArticulationAnchor} from './articulation.js?v=0.5.0';
import {previousHeld,transitionFrom,glideSeconds,glideRatio} from './voice-policy.js?v=0.5.2';
import {suggestedModelName,modelFilename} from './model-name.js?v=0.5.2';
const A=window.AudioContext||window.webkitAudioContext,ctx=new A(),$=id=>document.getElementById(id);let dna=emptyReflection(),buffer=null,clips=new Map(),layerClips=new Map(),sustainDNA=null,renderCache=new Map(),active=new Map(),held=new Map(),detectedEvents=[],sourceBuffers=new Map(),currentSourceId=null,currentFilename='',retainedClips=new Map(),retainedLayerClips=new Map(),compare='B',modelNameEdited=false;const audioState=message=>$('audioStatus').textContent=`Audio: ${message} (context ${ctx.state}, ${ctx.sampleRate} Hz)`;ctx.onstatechange=()=>{if($('audioStatus').textContent.includes('waiting for a click'))audioState('state changed')};
const frequency=n=>440*2**((n-69)/12);
function slice(start,end){return cropBuffer(ctx,buffer,start,end)}
function eventSlice(event,role='sustain'){const source=sourceForEvent(event,sourceBuffers);if(source)return cropBuffer(ctx,source,event.start,event.end);const saved=retainedLayerClips.get(`${role}:${event.midi}`)??retainedClips.get(event.midi);if(saved)return saved;throw Error('Source audio is unavailable for this anchor')}
function sourceCount(){return new Set(detectedEvents.map(e=>e.sourceId).filter(Boolean)).size}
let waveView={start:0,end:0};
function draw(){if(!buffer)return;let c=$('wave'),d=window.devicePixelRatio||1;c.width=Math.max(1,Math.round(c.clientWidth*d));c.height=Math.max(1,Math.round(c.clientHeight*d));let x=c.getContext('2d'),a=buffer.getChannelData(0),first=Math.floor(waveView.start*buffer.sampleRate),last=Math.min(a.length,Math.ceil(waveView.end*buffer.sampleRate)),step=Math.max(1,Math.ceil((last-first)/c.width)),mid=c.height/2;x.clearRect(0,0,c.width,c.height);x.beginPath();for(let i=0;i<c.width;i++){let mn=1,mx=-1,at=first+i*step;for(let j=at;j<Math.min(last,at+step);j++){let q=a[j]||0;mn=Math.min(mn,q);mx=Math.max(mx,q)}if(mn>mx)mn=mx=0;x.moveTo(i,mid+mn*mid);x.lineTo(i,mid+mx*mid)}x.strokeStyle='#e7b568';x.stroke()}
function refresh(){const mallet=dna.capture?.analysisProfile==='struck'&&$('mode').value==='Mallet';$('malletLegend').hidden=!mallet;$('screenVelocityWrap').hidden=!mallet;const polyphonic=dna.capture?.analysisProfile==='polyphonic';$('polyLegend').hidden=!polyphonic||!dna.anchors.length;document.querySelectorAll('.key').forEach(k=>{let n=+k.dataset.n;k.classList.toggle('poly-anchor',polyphonic&&dna.anchors.some(a=>a.midi===n));k.classList.toggle('poly-inferred',polyphonic&&dna.anchors.length>0&&!dna.anchors.some(a=>a.midi===n));k.classList.toggle('extracted',clips.has(n));k.classList.toggle('reconstructed',!clips.has(n)&&!!modelAt(dna,n));k.classList.toggle('mallet-shifted',mallet&&malletMapping(dna.anchors,n,p=>clips.has(p)).kind==='shifted');k.classList.toggle('mallet-modeled',mallet&&malletMapping(dna.anchors,n,p=>clips.has(p)).kind==='modeled')});$('expert').replaceChildren();let table=document.createElement('table');table.innerHTML='<tr><th>Anchor</th><th>Pitch confidence</th><th>Attack</th><th>Brightness</th><th>Slice available</th></tr>';for(let a of dna.anchors){let tr=document.createElement('tr');for(let cell of [midiName(a.midi),(a.confidence?.pitch??0).toFixed(2),(a.parameters?.attackSeconds?.analyzed??0).toFixed(3),(a.parameters?.brightness?.analyzed??0).toFixed(2),clips.has(a.midi)?'yes':'no']){let td=document.createElement('td');td.textContent=cell;tr.append(td)}table.append(tr)}$('expert').append(table);renderEvents();renderAdvanced();renderMacros();renderXY()}
function mapCandidates(){stopVoices();
  const offsets=Object.fromEntries(Object.entries(dna.global).map(([key,p])=>[key,p.offset]));dna.anchors=selectBaseAnchors(detectedEvents,dna.capture.density,sourceCount()>1||retainedClips.size>0);buildHierarchy(dna);for(const [key,offset] of Object.entries(offsets))if(dna.global[key])dna.global[key].offset=offset;clips.clear();layerClips.clear();renderCache.clear();
  for(const anchor of dna.anchors)if(anchor.source!=='polyphonic mixture'&&(sourceCount()<2||anchor.articulation==='sustain'))try{clips.set(anchor.midi,eventSlice(anchor))}catch{}
  dna.performance.layers=buildArticulationLayers(detectedEvents,dna.capture.density);
  for(const [layer,anchors] of Object.entries(dna.performance.layers))for(const anchor of anchors)if(anchor.source!=='polyphonic mixture')try{layerClips.set(`${layer}:${anchor.midi}`,eventSlice(anchor,layer))}catch{}
  sustainDNA=dna.performance.layers.sustain.length?buildHierarchy({anchors:dna.performance.layers.sustain,global:{},registers:[],capture:{range:null}}):null;
  dna.sampleSlots=dna.anchors.filter(a=>clips.has(a.midi)).map(a=>({role:'attack',anchorMidi:a.midi,sourceId:a.sourceId,pitchFollow:true,formantFollow:false,resonatorFollow:false,filterFollow:false,excitesResonator:false,embedded:false}));
  refresh();
  $('status').textContent=dna.capture.analysisProfile==='polyphonic'?`${detectedEvents.filter(e=>e.enabled).length} pitch candidates enabled · ${dna.anchors.length} model-only anchors. Each Listen button plays the entire shared onset; no isolated note audio is mapped.`:`${detectedEvents.filter(e=>e.enabled).length} candidate slices enabled · ${dna.anchors.length} base anchors · ${dna.performance.layers.sustain.length} sustained / ${dna.performance.layers.trill.length} trill anchors. Capture ${dna.capture.density} is a maximum per octave. Review articulation tags before saving.`;
}
function previewEvent(event){try{preview.pause();if(ctx.state!=='running')ctx.resume();const source=ctx.createBufferSource();source.buffer=eventSlice(event,event.articulation);source.connect(ctx.destination);source.start();$('detail').textContent=`Previewing ${event.sourceFilename||'source'} · ${midiName(event.midi)} at ${event.start.toFixed(2)}–${event.end.toFixed(2)} sec`;audioState('individual source slice started')}catch(e){audioState(`slice preview failed: ${e.message}`)}}
function renderEvents(){const panel=$('eventPanel'),box=$('eventList');panel.hidden=!detectedEvents.length;box.replaceChildren();if(panel.hidden)return;
  const table=document.createElement('table');table.innerHTML='<thead><tr><th>Use</th><th>File</th><th>Source time</th><th>Assigned key</th><th>Articulation</th><th>Pitch confidence</th><th>Listen</th><th>Mapped</th></tr></thead>';
  for(const event of detectedEvents){const tr=document.createElement('tr'),use=document.createElement('input');use.type='checkbox';use.checked=event.enabled;use.setAttribute('aria-label',`Use slice at ${event.start.toFixed(2)} seconds`);use.onchange=()=>{event.enabled=use.checked;mapCandidates()};
    const note=document.createElement('input');note.type='number';note.min=24;note.max=108;note.step=1;note.value=event.midi;note.setAttribute('aria-label',`MIDI key for slice at ${event.start.toFixed(2)} seconds`);let editTimer;const commitNote=()=>{let n=Number(note.value);if(!Number.isInteger(n)||n<24||n>108){note.value=event.midi;return}if(n===event.midi)return;event.midi=n;event.note=midiName(n);event.parameters.f0=param(frequency(n),event.confidence.pitch,'Hz');mapCandidates()};note.oninput=()=>{clearTimeout(editTimer);editTimer=setTimeout(commitNote,350)};note.onchange=()=>{clearTimeout(editTimer);commitNote()};
    const articulation=document.createElement('select');articulation.setAttribute('aria-label',`Articulation for slice at ${event.start.toFixed(2)} seconds`);for(const role of ARTICULATIONS){const option=document.createElement('option');option.value=role;option.textContent=role[0].toUpperCase()+role.slice(1);articulation.append(option)}articulation.value=event.articulation||'sustain';articulation.onchange=()=>{event.articulation=articulation.value;mapCandidates()};
    const listen=document.createElement('button');listen.textContent='Listen';listen.onclick=()=>previewEvent(event);
    const sameAnchor=a=>a===event||a.midi===event.midi&&a.sourceId===event.sourceId&&a.start===event.start&&a.articulation===event.articulation;
    const baseMapped=dna.anchors.some(sameAnchor),layerMapped=Object.entries(dna.performance.layers||{}).find(([,anchors])=>anchors.some(sameAnchor))?.[0];
    for(const content of [use,event.sourceFilename||'loaded preset',`${event.start.toFixed(2)}–${event.end.toFixed(2)} s`,note,articulation,`${midiName(event.midi)} · ${event.confidence.pitch.toFixed(2)}`,listen,baseMapped?event.source==='polyphonic mixture'?'◇ model only':'● original':layerMapped?`◆ ${layerMapped}`:'—']){const td=document.createElement('td');if(content instanceof Node)td.append(content);else td.textContent=content;tr.append(td)}table.append(tr)}box.append(table);
}
function nearest(n){return [...dna.anchors].sort((a,b)=>Math.abs(a.midi-n)-Math.abs(b.midi-n))[0]}
function roleClip(anchor,role){return layerClips.get(`${role}:${anchor.midi}`)??(role==='sustain'?clips.get(anchor.midi):null)}
function modeledClip(anchor,n,duration,role='sustain'){
  const original=roleClip(anchor,role),seconds=duration??original.duration,ratio=2**((n-anchor.midi)/12),key=`${role}/${anchor.midi}/${n}/${seconds.toFixed(3)}`;
  if(renderCache.has(key))return renderCache.get(key);
  const modeled=ctx.createBuffer(original.numberOfChannels,Math.max(1,Math.round(seconds*original.sampleRate)),original.sampleRate);
  for(let channel=0;channel<original.numberOfChannels;channel++)modeled.copyToChannel(renderExpressiveNote(original.getChannelData(channel),original.sampleRate,ratio,seconds,{preserveAttack:dna.capture.analysisProfile==='struck'}),channel);
  renderCache.set(key,modeled);return modeled;
}
function eraOutput(node){let preset=$('era').value,amount=+$('eraAmount').value;if(preset==='none'||!amount){node.connect(ctx.destination);return}let filter=ctx.createBiquadFilter();filter.type='lowpass';filter.frequency.value=20000*(1-amount)+(preset==='vintage'?3800:7500)*amount;node.connect(filter).connect(ctx.destination)}
function playMallet(n,v,m){
  let mapping=malletMapping(dna.anchors,n,p=>clips.has(p));const response=malletResponse(v);
  const source=ctx.createBufferSource(),requested=Number($('noteLength').value)||null;
  if(mapping.kind==='recorded')source.buffer=clips.get(n);
  else if(mapping.kind==='shifted')try{source.buffer=modeledClip(mapping.anchor,n,requested,'sustain')}catch(error){console.warn('Mallet anchor render unavailable; using modeled strike',error);mapping={...mapping,kind:'modeled'}}
  if(!source.buffer){const duration=requested||Math.min(3,Math.max(.45,(Number(m.parameters.decaySeconds)||1.3)*1.5));
    const samples=renderModeledMallet(ctx.sampleRate,n,m.parameters,v,duration),clip=ctx.createBuffer(1,samples.length,ctx.sampleRate);clip.copyToChannel(samples,0);source.buffer=clip}
  const now=ctx.currentTime,end=now+source.buffer.duration,tone=ctx.createBiquadFilter(),gain=ctx.createGain();
  tone.type='lowpass';tone.frequency.value=response.cutoff;
  const peak=response.gain*(.5+dna.macros.Dynamics*.5);
  gain.gain.setValueAtTime(0,now);gain.gain.linearRampToValueAtTime(peak,now+response.attack);
  gain.gain.setValueAtTime(peak,Math.max(now+response.attack,end-.065));gain.gain.linearRampToValueAtTime(0,end);
  source.connect(tone);tone.connect(gain);eraOutput(gain);source.start(now);source.stop(end+.02);
  const name=mapping.kind==='recorded'?'recorded mallet strike':mapping.kind==='shifted'?'shifted mallet strike':'modeled mallet strike';
  return {source,gain,anchor:mapping.kind==='modeled'?null:mapping.anchor,exact:mapping.kind==='recorded',mode:name,m,fixed:true,role:'sustain',peak};
}
function play(n,v,legatoFrom=null){
  const role=performanceArticulation($('articulation').value,v,$('velocityTrill').checked,Number($('trillThreshold').value)||100);
  const mode=$('mode').value,layered=mode!=='Raw'&&(role!=='sustain'||!!dna.performance?.layers?.trill?.length||ARTICULATIONS.slice(2).some(name=>dna.performance?.layers?.[name]?.length));
  const layer=dna.performance?.layers?.[role]||[],base=role==='sustain'&&sustainDNA?sustainDNA:dna,m=modelAt(base,n)||modelAt(dna,n);
  if(!m)return {error:'Analyze or load a DNA Reflection first'};
  if(mode==='Mallet')return dna.capture?.analysisProfile==='struck'?playMallet(n,v,m):{error:'Mallet audition requires a Struck / mallet model.'};
  if(layered&&role!=='sustain'&&!layer.length)return {error:`Tag at least one ${role} source slice before auditioning this articulation.`};
  const anchor=layered?nearestArticulationAnchor(layer,n):nearest(n),exact=layered?!!anchor&&anchor.midi===n&&!!roleClip(anchor,role):clips.has(n),requestedLength=Number($('noteLength').value)||null;
  const duration=mode==='HybridOriginal'||mode==='Raw'?null:requestedLength;
  if(mode==='Raw'&&!exact)return {error:dna.capture?.analysisProfile==='polyphonic'?'Polyphonic capture has no isolated source slices. Use Hybrid model playback or record isolated notes.':`No recorded slice mapped to ${midiName(n)}. Try a green key or use Hybrid for the estimated model.`};
  const now=ctx.currentTime,intensity=v/127,gain=ctx.createGain(),glide=glideSeconds($('glideMs').value);let source;
  const sample=anchor&&roleClip(anchor,layered?role:'sustain');
  const useNearby=layered&&role!=='sustain'||mode==='HybridStretch';
  if(mode!=='Reconstructed'&&sample&&(exact||useNearby&&Math.abs(anchor.midi-n)<=4&&sample.duration>=.08)){
    source=ctx.createBufferSource();
    try{source.buffer=mode==='Raw'||exact&&!duration?sample:modeledClip(anchor,n,duration,layered?role:'sustain')}catch(error){
      console.warn('Expressive rendering unavailable; using original Hybrid voice',error);
      if(exact)source.buffer=sample;
      else source=null;
    }
    if(mode==='Raw'){
      gain.gain.setValueAtTime(intensity,now);source.connect(gain);gain.connect(ctx.destination);source.start(now);
      return {source,gain,anchor,exact,mode:'recorded slice',m,fixed:false,role,peak:intensity};
    }
  }
  if(!source){
    source=ctx.createOscillator();let h=m.parameters.harmonicAmplitudes;
    if(Array.isArray(h)&&h.length){const real=new Float32Array(h.length+1),imag=new Float32Array(h.length+1);h.forEach((amp,i)=>imag[i+1]=amp);source.setPeriodicWave(ctx.createPeriodicWave(real,imag))}
    else source.type='sine';
    source.frequency.value=frequency(n);
  }
  let modulation=null;
  if(role==='trill'&&!source.buffer){
    const baseHz=frequency(n),upperHz=frequency(n+Number($('trillInterval').value||1));
    source.frequency.value=(baseHz+upperHz)/2;
    modulation=ctx.createOscillator();modulation.type='square';modulation.frequency.value=Number($('trillRate').value)||7;
    const depth=ctx.createGain();depth.gain.value=(upperHz-baseHz)/2;modulation.connect(depth).connect(source.frequency);modulation.start(now);
  }
  if(legatoFrom!==null){
    if(source.buffer){source.playbackRate.setValueAtTime(glideRatio(legatoFrom,n),now);source.playbackRate.linearRampToValueAtTime(1,now+glide)}
    else {const target=source.frequency.value;source.frequency.setValueAtTime(target*glideRatio(legatoFrom,n),now);source.frequency.exponentialRampToValueAtTime(target,now+glide)}
  }
  const tone=ctx.createBiquadFilter();tone.type='lowpass';
  const bright=clamp((m.parameters.brightness??.5)+((dna.macros.Brightness-.5)*.75)+(dna.xy.tone[0]-.5)*.6);
  tone.frequency.value=450+bright*15000;
  const attack=legatoFrom!==null?Math.max(.012,glide*.7):clamp((m.parameters.attackSeconds??.02)*(1.5-dna.macros.Attack),.002,.3),sustain=clamp(intensity*(.4+dna.macros.Dynamics*.6));
  gain.gain.setValueAtTime(0,now);gain.gain.linearRampToValueAtTime(sustain,now+attack);
  if(duration){const end=now+duration,release=Math.min(.09,duration*.2);gain.gain.setValueAtTime(sustain,Math.max(now+attack,end-release));gain.gain.linearRampToValueAtTime(0,end)}
  source.connect(tone);tone.connect(gain);eraOutput(gain);source.start(now,legatoFrom!==null&&source.buffer?Math.min(.045,source.buffer.duration*.12):0);
  if(duration)source.stop(now+duration+.02);
  const voiceMode=source.buffer?(role==='sustain'?(exact?'recorded slice':'shifted anchor with natural vibrato'):(exact?`recorded ${role}`:`shifted ${role} anchor`)):(role==='trill'?'generated trill from harmonic model':role==='sustain'?'estimated harmonic model':`estimated harmonic model · ${role} reference too far`);
  return {source,gain,anchor,exact,mode:voiceMode,m,fixed:!!duration,modulation,role,peak:sustain};
}
function stopVoice(n,fade=.06){const voice=active.get(n);if(!voice)return;const t=ctx.currentTime,p=voice.gain.gain;if(p.cancelAndHoldAtTime)p.cancelAndHoldAtTime(t);else {p.cancelScheduledValues(t);p.setValueAtTime(voice.peak,t)}p.setTargetAtTime(.0001,t,Math.max(.003,fade/3));try{voice.source.stop(t+fade+.02)}catch{}active.delete(n);document.querySelector(`[data-n="${n}"]`)?.classList.remove('active')}
function stopVoices(){for(const n of active.keys())stopVoice(n,.012);held.clear()}
function noteOn(n,v,k=document.querySelector(`[data-n="${n}"]`)){try{
  if(ctx.state==='closed')throw Error('Audio engine closed; reload the page');preview.pause();let unlock=ctx.state==='running'?null:ctx.resume();
  const behavior=$('voiceMode').value,from=behavior==='legato'?transitionFrom(active,n):null;
  let voice=play(n,v,behavior==='legato'?from:null);if(voice.error){$('detail').textContent=voice.error;audioState('no voice started');return}
  if(behavior!=='poly'){
    for(const old of [...active.keys()])stopVoice(old,behavior==='legato'&&from!==null&&$('mode').value!=='Raw'?glideSeconds($('glideMs').value):.012);
  }else stopVoice(n,.012);
  held.delete(n);held.set(n,v);k?.classList.add('active');active.set(n,voice);
  voice.source.onended=()=>{if(voice.modulation)try{voice.modulation.stop()}catch{}if(active.get(n)===voice){active.delete(n);k?.classList.remove('active')}};
  $('detail').textContent=`${midiName(n)} · ${voice.mode}${voice.anchor&&(voice.mode.includes('anchor')||voice.mode.includes('mallet strike')||voice.mode.startsWith('recorded'))?` from ${midiName(voice.anchor.midi)}`:''}${from!==null&&behavior==='legato'?' · legato transition':''} · model confidence ${voice.m.confidence.toFixed(2)}`;
  let message=`${voice.mode} started on ${midiName(n)}${from!==null&&behavior==='legato'?` · legato from ${midiName(from)}`:''}`;audioState(message);$('recommendation').textContent=voice.m.recommendation||'';unlock?.then(()=>audioState(message)).catch(e=>{audioState(`unlock failed: ${e.message}`);console.error('Instrument DNA audio unlock',e)})
}catch(e){$('detail').textContent=`Playback failed: ${e.message}`;audioState('playback error');console.error('Instrument DNA playback',e)}}
function noteOff(n,k=document.querySelector(`[data-n="${n}"]`)){held.delete(n);const voice=active.get(n);if(!voice){k?.classList.remove('active');return}if($('voiceMode').value!=='poly'){
  const previous=previousHeld(held);if(previous){noteOn(previous[0],previous[1]);return}
}if(voice.fixed){k?.classList.remove('active');return}stopVoice(n,.08)}
$('testSound').onclick=()=>{try{if(ctx.state==='closed')throw Error('Audio engine closed; reload the page');let unlock=ctx.state==='running'?null:ctx.resume();let source=ctx.createOscillator(),gain=ctx.createGain(),t=ctx.currentTime;source.type='sine';source.frequency.value=440;gain.gain.setValueAtTime(0,t);gain.gain.linearRampToValueAtTime(.22,t+.03);gain.gain.setValueAtTime(.22,t+.85);gain.gain.linearRampToValueAtTime(0,t+1);source.connect(gain).connect(ctx.destination);source.start(t);source.stop(t+1.02);let message='440 Hz test tone started for 1 second';audioState(message);$('detail').textContent='Test sound uses a direct tone and bypasses imported audio and instrument controls.';unlock?.then(()=>audioState(message)).catch(e=>{audioState(`test unlock failed: ${e.message}`);console.error('Instrument DNA test sound unlock',e)})}catch(e){audioState(`test failed: ${e.message}`);console.error('Instrument DNA test sound',e)}};
for(let n=36;n<=96;n++){let k=document.createElement('div');k.className='key '+([1,3,6,8,10].includes(n%12)?'black':'');k.textContent=midiName(n);k.dataset.n=n;k.onpointerdown=e=>{e.preventDefault();k.setPointerCapture(e.pointerId);noteOn(n,Number($('screenVelocity').value),k)};k.onpointerup=k.onpointercancel=()=>noteOff(n,k);$('keys').append(k)}
let previewURL=null,importSerial=0;
const preview=$('sourcePreview');preview.onplaying=()=>$('previewStatus').textContent='Browser media playback started.';preview.onpause=()=>{selectionPlaying=false;$('previewStatus').textContent='Preview paused.'};preview.onerror=()=>$('previewStatus').textContent='Browser media preview cannot play this format; try keyboard audition after analysis.';
let selectionPlaying=false;
function selected(){return cropBounds($('cropStart').value,$('cropEnd').value,buffer?.duration||0)}
function showView(){if(!buffer)return;let span=waveView.end-waveView.start,pan=$('wavePan');pan.max=Math.max(0,buffer.duration-span).toFixed(2);pan.value=waveView.start.toFixed(2);pan.disabled=span>=buffer.duration-.01;$('zoomIn').disabled=span<=.11;$('zoomOut').disabled=span>=buffer.duration-.01;$('viewStatus').textContent=`View ${waveView.start.toFixed(2)}–${waveView.end.toFixed(2)} sec · ${(buffer.duration/span).toFixed(1)}×`;let shade=selectionShades(waveView,selected());$('cropShadeLeft').style.width=`${shade.left}%`;$('cropShadeRight').style.width=`${shade.right}%`;draw()}
function showCrop(){if(!buffer)return;let r=selected(),duration=buffer.duration;for(let id of ['cropStart','cropEnd','startSlider','endSlider'])$(id).max=duration.toFixed(2);$('cropStart').value=$('startSlider').value=r.start.toFixed(2);$('cropEnd').value=$('endSlider').value=r.end.toFixed(2);$('cropStatus').textContent=`Selected ${r.start.toFixed(2)}–${r.end.toFixed(2)} sec (${r.duration.toFixed(2)} sec). Only this region will be analyzed.`;showView()}
$('zoomIn').onclick=()=>{if(!buffer)return;let r=selected(),focus=waveView.end-waveView.start>=buffer.duration-.01?(r.start+r.end)/2:(waveView.start+waveView.end)/2;waveView=zoomView(waveView,buffer.duration,2,focus);showView()};
$('zoomOut').onclick=()=>{if(!buffer)return;waveView=zoomView(waveView,buffer.duration,.5);showView()};
$('zoomFit').onclick=()=>{if(!buffer)return;waveView={start:0,end:buffer.duration};showView()};
$('wavePan').oninput=()=>{if(!buffer)return;waveView=panView($('wavePan').value,waveView.end-waveView.start,buffer.duration);showView()};
window.addEventListener('resize',()=>{if(buffer)draw()});
function changeCrop(changed){if(!buffer)return;stopVoices();let start=Number($('cropStart').value),end=Number($('cropEnd').value);if(changed==='start'&&start>end)end=start;if(changed==='end'&&end<start)start=end;$('cropStart').value=start;$('cropEnd').value=end;selectionPlaying=false;preview.pause();detectedEvents=detectedEvents.filter(e=>e.sourceId!==currentSourceId);dna.provenance=dna.provenance.filter(p=>p.sourceId!==currentSourceId);if(detectedEvents.length)mapCandidates();else{clips.clear();layerClips.clear();sustainDNA=null;renderCache.clear();dna.anchors=[];dna.performance.layers={};dna.sampleSlots=[];buildHierarchy(dna);refresh()}showCrop();$('status').textContent='Selection changed. Analyze this passage; earlier source layers remain in the model.'}
for(let [id,target] of [['cropStart','start'],['cropEnd','end'],['startSlider','start'],['endSlider','end']])$(id).addEventListener('input',()=>{if(id.includes('Slider'))$('crop'+target[0].toUpperCase()+target.slice(1)).value=$(id).value;changeCrop(target)});
$('fullSelection').onclick=()=>{if(!buffer)return;$('cropStart').value=0;$('cropEnd').value=buffer.duration;changeCrop('end')};
$('playSelection').onclick=async()=>{if(!buffer)return;let r=selected();if(r.duration<.1){$('cropStatus').textContent='Select at least 0.1 seconds to preview.';return}try{preview.pause();preview.currentTime=r.start;selectionPlaying=true;await preview.play()}catch(e){selectionPlaying=false;$('previewStatus').textContent=`Preview failed: ${e.message}`}};
preview.addEventListener('timeupdate',()=>{if(selectionPlaying&&preview.currentTime>=selected().end-.03){selectionPlaying=false;preview.pause();preview.currentTime=selected().start}});
$('file').onchange=async e=>{let f=e.target.files[0];if(!f)return;stopVoices();let serial=++importSerial,add=$('addSource').checked&&(detectedEvents.length||dna.anchors.length);selectionPlaying=false;$('cropWrap').hidden=true;$('waveControls').hidden=true;if(!add){clips.clear();layerClips.clear();retainedClips.clear();retainedLayerClips.clear();sourceBuffers.clear();sustainDNA=null;renderCache.clear();detectedEvents=[];dna=emptyReflection();dna.name=$('modelName').value.trim()||suggestedModelName($('source').value)}buffer=null;currentSourceId=null;refresh();$('status').textContent=`Opening ${f.name}…`;preview.pause();if(previewURL)URL.revokeObjectURL(previewURL);previewURL=URL.createObjectURL(f);preview.src=previewURL;$('previewWrap').hidden=false;try{let decoded=await decodeAudioFile(ctx,f,message=>$('status').textContent=message);if(serial!==importSerial)return;buffer=decoded.buffer;currentSourceId=crypto.randomUUID();currentFilename=f.name;sourceBuffers.set(currentSourceId,buffer);waveView={start:0,end:buffer.duration};$('cropStart').value=0;$('cropEnd').value=Math.min(buffer.duration,10);$('cropWrap').hidden=false;$('waveControls').hidden=false;showCrop();$('status').textContent=`${f.name} · ${buffer.duration.toFixed(2)} sec · ${decoded.decoder} decode · ${add?'adding to existing model':'new model'} · opening ${Math.min(buffer.duration,10).toFixed(2)} sec selected`}catch(err){if(serial!==importSerial)return;$('status').textContent=`Audio import failed: ${err.message}`;console.error('Instrument DNA audio import',err)}};
$('analyze').onclick=()=>{
  if(!buffer){$('status').textContent='Choose an audio file first.';return}
  const range=selected();if(range.duration<.1){$('status').textContent='Select at least 0.1 seconds before analyzing.';return}
  const settings={selectedArticulation:$('articulation').value,velocityTrill:$('velocityTrill').checked,trillThreshold:Number($('trillThreshold').value)||100,trillRateHz:Number($('trillRate').value)||7,trillInterval:Number($('trillInterval').value)||1,voiceMode:$('voiceMode').value,glideMs:Number($('glideMs').value)||70};
  dna.name=$('modelName').value.trim()||suggestedModelName($('source').value);Object.assign(dna.performance,settings);dna.performance.noteLengthSeconds=Number($('noteLength').value)||null;dna.classification.name=$('source').value.trim()||'unspecified instrument';dna.capture.density=+$('density').value;const profile=$('analysisProfile').value,role=$('captureRole').value;
  dna.provenance=dna.provenance.filter(p=>p.sourceId!==currentSourceId);
  dna.provenance.push({sourceId:currentSourceId,filename:currentFilename,analysisProfile:profile,articulation:role,archive:$('archive').value,itemId:$('item').value,recordingDate:$('recordingDate').value,instrument:dna.classification.name,performer:$('performer').value,rightsStatus:$('rights').value||'unverified',url:$('url').value,analysisDate:new Date().toISOString(),analyzerVersion:dna.analyzerVersion,redistributionPermitted:$('redistribute').checked,selectionStartSeconds:range.start,selectionEndSeconds:range.end});
  dna.capture.analysisProfile=profile;
  try{
    const selectedAudio=cropBuffer(ctx,buffer,range.start,range.end),result=analyzeBuffer(selectedAudio,emptyReflection(),profile);
    detectedEvents=detectedEvents.filter(e=>e.sourceId!==currentSourceId).concat(result.events.map(event=>({...event,start:event.start+range.start,end:event.end+range.start,enabled:true,articulation:role,sourceId:currentSourceId,sourceFilename:currentFilename,analysisProfile:profile})));dna.capture.sourceProfiles=[...new Set(detectedEvents.map(e=>e.analysisProfile).filter(Boolean))];$('addSource').checked=true;
    if(profile==='struck'&&sourceCount()===1)$('mode').value='Mallet';else if($('mode').value==='Mallet'&&profile!=='struck')$('mode').value='HybridOriginal';
    mapCandidates();
    $('status').textContent=detectedEvents.length?profile==='polyphonic'?`${result.events.length} new pitch candidates at shared onsets · ${dna.anchors.length} model-only keys. Listen and correct the notes. Mixed audio cannot supply isolated note samples.`:`${result.events.length} new note candidates · ${dna.anchors.length} model keys from ${dna.provenance.length} sources · selected passage ${range.start.toFixed(2)}–${range.end.toFixed(2)} sec. Review the list below and remove speech or wrong notes.`:'No stable isolated notes found. Try a clearer passage, adjust the note style, or record individual notes.';
  }catch(e){dna.provenance=dna.provenance.filter(p=>p.sourceId!==currentSourceId);$('status').textContent=`Analysis failed: ${e.message}`;console.error('Instrument DNA analysis',e)}
};
$('density').onchange=()=>{dna.capture.density=Number($('density').value);if(detectedEvents.length)mapCandidates()};
$('analysisProfile').onchange=()=>{if($('analysisProfile').value==='struck')$('mode').value='Mallet';else if($('mode').value==='Mallet')$('mode').value='HybridOriginal';refresh()};
$('mode').onchange=()=>{stopVoices();refresh()};
$('screenVelocity').oninput=()=>$('screenVelocityValue').textContent=$('screenVelocity').value;
function download(data,name){const blob=new Blob([JSON.stringify(data)],{type:'application/json'}),u=URL.createObjectURL(blob),a=document.createElement('a');a.href=u;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(u),1000)}
function syncPresetFields(){dna.name=$('modelName').value.trim()||suggestedModelName($('source').value);dna.performance.glideMs=Math.round(Math.max(10,Math.min(250,Number($('glideMs').value)||70)))}
$('export').onclick=()=>{syncPresetFields();download(serializable(dna),modelFilename(dna.name,'reflection'));$('detail').textContent=`Saved ${dna.name} DNA Reflection (no audio).`};
$('saveComparison').onclick=()=>{if(!clips.size){$('detail').textContent='Analyze source notes before saving a playable comparison.';return}try{syncPresetFields();download(saveComparison(dna,clips,$('mode').value,layerClips),modelFilename(dna.name,'comparison'));$('detail').textContent=`Saved ${dna.name} playable comparison with original and articulation slices. Keep this file private if the source rights are unverified.`}catch(error){$('detail').textContent=`Comparison save failed: ${error.message}`}};
$('import').onchange=async e=>{try{const file=e.target.files[0];if(!file)return;if(file.size>100_000_000)throw Error('Preset exceeds the 100 MB import limit');const data=JSON.parse(await file.text());let playable=data?.format==='instrument-dna-playable-comparison'?loadComparison(data,(channels,length,rate)=>ctx.createBuffer(channels,length,rate)):null;stopVoices();dna=playable?.dna??importReflection(data);$('source').value=dna.classification?.name==='unspecified instrument'?'':dna.classification?.name||'';$('modelName').value=dna.name;$('analysisProfile').value=['sustained','plucked','struck','polyphonic'].includes(dna.capture?.analysisProfile)?dna.capture.analysisProfile:'sustained';$('density').value=String(dna.capture?.density||3);modelNameEdited=dna.name!==suggestedModelName($('source').value);clips.clear();layerClips.clear();renderCache.clear();if(playable){for(const [n,clip] of playable.clips)clips.set(n,clip);for(const [key,clip] of playable.layerClips)layerClips.set(key,clip)}sustainDNA=dna.performance.layers?.sustain?.length?buildHierarchy({anchors:dna.performance.layers.sustain,global:{},registers:[],capture:{range:null}}):null;retainedClips=new Map(clips);retainedLayerClips=new Map(layerClips);sourceBuffers.clear();currentSourceId=null;currentFilename='';detectedEvents=[...dna.anchors,...Object.values(dna.performance.layers||{}).flat()].filter((e,i,list)=>list.findIndex(x=>x.sourceId===e.sourceId&&x.midi===e.midi&&x.start===e.start&&x.articulation===e.articulation)===i).map(e=>({...e,enabled:true}));$('addSource').checked=true;buffer=null;selectionPlaying=false;preview.pause();if(previewURL)URL.revokeObjectURL(previewURL);previewURL=null;preview.removeAttribute('src');$('previewWrap').hidden=true;$('cropWrap').hidden=true;$('waveControls').hidden=true;$('status').textContent=playable?`Loaded playable comparison with ${clips.size} original and ${layerClips.size} articulation slices.`:`Loaded ${dna.anchors.length} anchors. This DNA Reflection contains no audio; playback uses the modeled oscillator.`;$('era').value=dna.era?.recording||'none';$('eraAmount').value=dna.era?.amount||0;$('noteLength').value=String(dna.performance?.noteLengthSeconds||'');$('mode').value=playable?.hybridMode||'HybridOriginal';$('articulation').value=dna.performance.selectedArticulation||'sustain';$('velocityTrill').checked=!!dna.performance.velocityTrill;$('trillThreshold').value=dna.performance.trillThreshold||100;$('trillRate').value=dna.performance.trillRateHz||7;$('trillInterval').value=dna.performance.trillInterval||1;$('voiceMode').value=dna.performance.voiceMode;$('glideMs').value=dna.performance.glideMs;refresh()}catch(err){$('status').textContent=`Could not load preset: ${err.message}`}};
$('voiceMode').onchange=()=>{stopVoices();dna.performance.voiceMode=$('voiceMode').value};
$('glideMs').oninput=()=>dna.performance.glideMs=Math.round(Math.max(10,Math.min(250,Number($('glideMs').value)||70)));$('glideMs').onchange=()=>{$('glideMs').oninput();$('glideMs').value=dna.performance.glideMs};
$('source').oninput=()=>{if(!modelNameEdited){$('modelName').value=suggestedModelName($('source').value);dna.name=$('modelName').value}};
$('modelName').oninput=()=>{modelNameEdited=true;dna.name=$('modelName').value.trim()||suggestedModelName($('source').value)};
$('articulation').onchange=()=>dna.performance.selectedArticulation=$('articulation').value;
$('velocityTrill').onchange=()=>dna.performance.velocityTrill=$('velocityTrill').checked;
$('trillThreshold').onchange=()=>dna.performance.trillThreshold=Number($('trillThreshold').value)||100;
$('trillRate').onchange=()=>dna.performance.trillRateHz=Number($('trillRate').value)||7;
$('trillInterval').onchange=()=>dna.performance.trillInterval=Number($('trillInterval').value)||1;
$('noteLength').onchange=()=>{dna.performance??={};dna.performance.noteLengthSeconds=Number($('noteLength').value)||null;renderCache.clear()};
function renderMacros(){let box=$('macros');box.replaceChildren();for(let name of MACROS){let label=document.createElement('label'),input=document.createElement('input');label.textContent=name;input.type='range';input.min=0;input.max=1;input.step=.01;input.value=dna.macros[name]??.5;input.oninput=()=>dna.macros[name]=+input.value;label.append(input);box.append(label)}}
function renderXY(){for(let id of ['tone','behavior']){let pad=$(id),p=dna.xy[id]||[.5,.5],dot=pad.querySelector('span');dot.style.left=`${p[0]*100}%`;dot.style.top=`${(1-p[1])*100}%`}}
for(let id of ['tone','behavior']){let pad=$(id),update=e=>{let r=pad.getBoundingClientRect();dna.xy[id]=[clamp((e.clientX-r.left)/r.width),clamp(1-(e.clientY-r.top)/r.height)];renderXY()};pad.onpointerdown=e=>{pad.setPointerCapture(e.pointerId);update(e)};pad.onpointermove=e=>{if(e.buttons)update(e)};pad.onkeydown=e=>{let p=dna.xy[id];if(e.key==='ArrowRight')p[0]=clamp(p[0]+.02);else if(e.key==='ArrowLeft')p[0]=clamp(p[0]-.02);else if(e.key==='ArrowUp')p[1]=clamp(p[1]+.02);else if(e.key==='ArrowDown')p[1]=clamp(p[1]-.02);else return;e.preventDefault();renderXY()}}
function renderAdvanced(){let box=$('advanced');box.replaceChildren();let button=document.createElement('button');button.textContent=`Compare: ${compare} · ${compare==='B'?'edited':'analyzed'}`;button.onclick=()=>{compare=compare==='A'?'B':'A';for(let p of Object.values(dna.global)){if(compare==='A'){p.savedOffset=p.offset;p.offset=0}else p.offset=p.savedOffset??p.offset}renderAdvanced()};box.append(button);for(let [key,p] of Object.entries(dna.global)){if(typeof p.model!=='number')continue;let label=document.createElement('label'),input=document.createElement('input'),reset=document.createElement('button');label.textContent=`${key} · analyzed ${p.analyzed.toFixed(3)} · confidence ${p.confidence.toFixed(2)} · user offset`;input.type='number';input.step='.01';input.value=p.offset;input.disabled=compare==='A';input.onchange=()=>{p.offset=Number(input.value)||0};reset.textContent='Reset';reset.disabled=compare==='A';reset.onclick=()=>{input.value=0;input.onchange()};label.append(input,reset);box.append(label)}}
$('era').onchange=()=>dna.era.recording=$('era').value;$('eraAmount').oninput=()=>dna.era.amount=+$('eraAmount').value;
async function midi(){if(!navigator.requestMIDIAccess){$('midi').textContent='MIDI: unsupported';return}try{let m=await navigator.requestMIDIAccess(),bind=()=>{m.inputs.forEach(i=>i.onmidimessage=e=>{let[s,n,v]=e.data,t=s&240;if(t===144&&v)noteOn(n,v);else if(t===128||t===144&&!v)noteOff(n)});$('midi').textContent=`MIDI: ${m.inputs.size} inputs`};bind();m.onstatechange=bind}catch{$('midi').textContent='MIDI: permission needed'}}refresh();midi();
