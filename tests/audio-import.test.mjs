import assert from 'node:assert/strict';
import {test} from 'node:test';
import {decodeAiff} from '../src/audio-import.js';
function aiff(){let b=new Uint8Array(58),v=new DataView(b.buffer),str=(p,s)=>{for(let i=0;i<s.length;i++)b[p+i]=s.charCodeAt(i)};str(0,'FORM');v.setUint32(4,50);str(8,'AIFF');str(12,'COMM');v.setUint32(16,18);v.setUint16(20,1);v.setUint32(22,2);v.setUint16(26,16);b.set([0x40,0x0e,0xac,0x44,0,0,0,0,0,0],28);str(38,'SSND');v.setUint32(42,12);v.setUint32(46,0);v.setUint32(50,0);v.setInt16(54,16384);v.setInt16(56,-16384);return b}
const ctx={createBuffer:(channels,length,sampleRate)=>{let data=Array.from({length:channels},()=>new Float32Array(length));return {sampleRate,length,numberOfChannels:channels,getChannelData:i=>data[i]}}};
test('PCM AIFF fallback decodes rate and signed samples',()=>{let b=decodeAiff(ctx,aiff());assert.equal(b.sampleRate,44100);assert.equal(b.length,2);assert.deepEqual([...b.getChannelData(0)],[.5,-.5])});
test('reject truncated AIFF',()=>assert.throws(()=>decodeAiff(ctx,aiff().subarray(0,53)),/Truncated|Unsupported/));
