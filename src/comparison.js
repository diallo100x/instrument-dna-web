import {serializable,importReflection} from './dna.js';

// Playable comparison files are explicitly separate from audio-free DNA Reflections.
const encode=bytes=>{let result='';for(let i=0;i<bytes.length;i+=16384)result+=String.fromCharCode(...bytes.subarray(i,i+16384));return btoa(result)};
const decode=base64=>{const text=atob(base64),bytes=new Uint8Array(text.length);for(let i=0;i<text.length;i++)bytes[i]=text.charCodeAt(i);return bytes};
export function saveComparison(dna,clips,hybridMode){
  const audio=[];
  for(const [midi,clip] of clips){
    if(!dna.anchors.some(a=>a.midi===midi))continue;
    audio.push({midi,sampleRate:clip.sampleRate,channels:Array.from({length:clip.numberOfChannels},(_,i)=>{
      const samples=clip.getChannelData(i),bytes=new Uint8Array(samples.buffer,samples.byteOffset,samples.byteLength);
      return encode(bytes);
    })});
  }
  return {format:'instrument-dna-playable-comparison',version:1,hybridMode,reflection:serializable(dna),audio};
}
export function loadComparison(data,makeBuffer){
  if(data?.format!=='instrument-dna-playable-comparison'||data.version!==1||!Array.isArray(data.audio)||data.audio.length>127)throw Error('Invalid playable comparison');
  const dna=importReflection(data.reflection),clips=new Map();
  for(const entry of data.audio){
    if(!Number.isInteger(entry.midi)||!dna.anchors.some(a=>a.midi===entry.midi)||clips.has(entry.midi)||!Number.isInteger(entry.sampleRate)||entry.sampleRate<8000||entry.sampleRate>192000||!Array.isArray(entry.channels)||entry.channels.length<1||entry.channels.length>8)throw Error('Invalid comparison anchor');
    const channels=entry.channels.map(encoded=>{
      if(typeof encoded!=='string'||encoded.length>32_000_000)throw Error('Comparison clip is too large');
      const bytes=decode(encoded);if(bytes.length%4||bytes.length<entry.sampleRate*.08*4||bytes.length>entry.sampleRate*15*4)throw Error('Invalid comparison clip length');
      const aligned=bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),samples=new Float32Array(aligned);
      if(!samples.every(Number.isFinite))throw Error('Invalid comparison audio');
      return samples;
    });
    if(channels.some(ch=>ch.length!==channels[0].length))throw Error('Inconsistent audio channels');
    const clip=makeBuffer(channels.length,channels[0].length,entry.sampleRate);
    channels.forEach((samples,i)=>clip.copyToChannel(samples,i));clips.set(entry.midi,clip);
  }
  return {dna,clips,hybridMode:['HybridOriginal','HybridStretch'].includes(data.hybridMode)?data.hybridMode:'HybridOriginal'};
}
