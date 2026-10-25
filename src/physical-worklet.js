import {PhysicalVoice} from './physical.js?v=0.8.0';
class PhysicalProcessor extends AudioWorkletProcessor {
 static get parameterDescriptors(){return ['frequency','velocity','hardness','position','damping','noise','richness','body','drive','brightness','attack','movement','midi','articulation','trillRate','trillInterval'].map(name=>({name,defaultValue:name==='midi'?69:name==='articulation'?0:name==='trillRate'?7:name==='trillInterval'?1:name==='frequency'?440:name==='velocity'?.8:name==='attack'?.005:name==='movement'?0:.5,automationRate:name==='frequency'?'a-rate':'k-rate'}));}
 constructor(options){super();this.voice=new PhysicalVoice(options.processorOptions.model,sampleRate);this.running=false;this.release=null;this.end=null;this.envelope=0;this.finished=false;this.port.onmessage=e=>{if(e.data.type==='start')this.running=true;if(e.data.type==='stop')this.end=e.data.time;};}
 process(inputs,outputs,parameters){
  if(this.finished)return false;
  const channels=outputs[0];if(!channels.length)return true;
  const p={};for(const [key,array]of Object.entries(parameters))p[key]=array[0];
  for(let i=0;i<channels[0].length;i++){
   const now=currentTime+i/sampleRate;if(this.end!==null&&now>=this.end&&this.release===null)this.release=now;
   if(!this.running){for(const channel of channels)channel[i]=0;continue;}
   if(this.release!==null)this.envelope*=Math.exp(-1/(.02*sampleRate));else this.envelope=Math.min(1,this.envelope+1/(Math.max(.001,p.attack)*sampleRate));
   let hz=(parameters.frequency.length>1?parameters.frequency[i]:p.frequency)*2**((p.movement*Math.sin(2*Math.PI*5.2*this.voice.age)*.08)/12);
   if(Math.round(p.articulation)===1&&Math.sin(2*Math.PI*p.trillRate*this.voice.age)>0)hz*=2**(p.trillInterval/12);
   const output=this.voice.tick(hz,p)*this.envelope;for(const channel of channels)channel[i]=output;
  }
  if(this.release!==null&&this.envelope<.0001){this.finished=true;this.port.postMessage({type:'ended'});return false;}return true;
 }
}
registerProcessor('instrument-dna-physical',PhysicalProcessor);
