// Independently authored physical DSP. See docs/physical-modeling.md for provenance.
const clamp=(x,a=0,b=1)=>Math.min(b,Math.max(a,x));
export function validatePhysicalModel(m){
 if(!m||m.version!==1||!['modal','waveguide'].includes(m.kind)||typeof m.continuous!=='boolean'||!Array.isArray(m.modes)||m.modes.length<1||m.modes.length>16)throw Error('Unsupported physical model');
 if(m.waveguideTone!==undefined&&(!Number.isFinite(m.waveguideTone)||m.waveguideTone<.05||m.waveguideTone>.98))throw Error('Invalid waveguide loss tone');
 if(m.lossSampleRate!==undefined&&(!Number.isFinite(m.lossSampleRate)||m.lossSampleRate<8000||m.lossSampleRate>192000))throw Error('Invalid loss sample rate');
 for(const [key,lo,hi] of [['hardness',0,1],['position',0,1],['noise',0,1],['decay',.05,15]])if(!Number.isFinite(m[key])||m[key]<lo||m[key]>hi)throw Error(`Invalid physical ${key}`);
 if(m.modes.some(x=>!x||!Number.isFinite(x.ratio)||x.ratio<.25||x.ratio>64||!Number.isFinite(x.gain)||x.gain<0||x.gain>1||!Number.isFinite(x.t60)||x.t60<.02||x.t60>15))throw Error('Invalid physical modes');return m;
}
export class PhysicalVoice {
 constructor(model,rate){this.model=validatePhysicalModel(model);this.rate=rate;this.y1=new Float64Array(16);this.y2=new Float64Array(16);this.a1=new Float64Array(16);this.a2=new Float64Array(16);this.inputGain=new Float64Array(16);this.delay=new Float32Array(8192);this.frame=0;this.age=0;this.write=0;this.random=12345;this.exciter=0;this.loop=0;this.lastSample=0;}
 tick(hz,controls={}){
  const m=this.model,sr=this.rate,v=clamp(controls.velocity??.8),hardness=clamp(controls.hardness??m.hardness),position=clamp(controls.position??m.position,.02,.98),damping=clamp(controls.damping??.5),richness=clamp(controls.richness??.5),noiseAmount=clamp(controls.noise??m.noise);
  hz=clamp(hz,40,sr*.4);this.random=(Math.imul(this.random,1664525)+1013904223)>>>0;const noise=this.random/4294967295*2-1;
  const cutoff=500+hardness**2*14000*(.3+.7*v),coefficient=1-Math.exp(-2*Math.PI*Math.min(cutoff,sr*.45)/sr);this.exciter+=coefficient*(noise-this.exciter);let output=0;
  if(m.kind==='waveguide'){
   const fittedTone=m.waveguideTone?1-Math.pow(1-m.waveguideTone,(m.lossSampleRate??sr)/sr):0;
   const tone=m.waveguideTone?clamp(fittedTone+(hardness-m.hardness)*.3,.01,.99):clamp(.2+.7*hardness+.08*v,.2,.98),delay=clamp(sr/hz-(m.waveguideTone?(1-tone)/tone:.5),2,8189),whole=Math.floor(delay),fraction=delay-whole;
   const at=(this.write+8192-whole)%8192,previous=(at+8191)%8192,delayed=this.delay[at]*(1-fraction)+this.delay[previous]*fraction;
   const feedback=Math.exp(-6.907755*delay/(sr*m.decay*(1.5-damping)));this.loop+=tone*(delayed-this.loop);
   const pluck=this.age<1/hz?this.exciter*(.35+.65*v):0,comb=(this.write+8192-Math.floor(Math.max(1,delay*position)))%8192;
   const excitation=pluck-(this.age<1/hz?this.delay[comb]*.45:0);this.delay[this.write]=clamp(excitation+this.loop*feedback,-2,2);this.write=(this.write+1)%8192;output=delayed;
  }else{
   if(this.frame%32===0)for(let i=0;i<m.modes.length;i++){
    const mode=m.modes[i],frequency=hz*mode.ratio,t60=mode.t60*(1.5-damping),r=Math.exp(-6.907755/(t60*sr)),angle=2*Math.PI*Math.min(frequency,sr*.45)/sr;
    this.a1[i]=2*r*Math.cos(angle);this.a2[i]=-r*r;
    const spectral=Math.pow(m.origin==='analyzed'?clamp(1+(hardness-m.hardness)*.7+(richness-.5)*.35+(v-100/127)*.3,.15,1.5):clamp(.3+.7*hardness*v+.35*richness,.15,1),Math.log2(Math.max(1,mode.ratio))),hit=i===0?1:m.origin==='analyzed'?(.25+.75*Math.abs(Math.sin(Math.PI*position*mode.ratio)))/(.25+.75*Math.abs(Math.sin(Math.PI*.5*mode.ratio))):.25+.75*Math.abs(Math.sin(Math.PI*position*mode.ratio));
    this.inputGain[i]=frequency<sr*.45?mode.gain*spectral*hit*Math.sin(angle):0;
   }
   const width=.001+(1-hardness)*.012;let excitation=(this.frame===0?1:0)+this.exciter*noiseAmount*.08*Math.exp(-this.age/width);
   if(m.continuous)excitation+=this.exciter*(.002+.005*v)*(.2+noiseAmount);
   let normal=0;
   for(let i=0;i<m.modes.length;i++){
    if(!this.inputGain[i]){this.y1[i]=this.y2[i]=0;continue;}
    const y=clamp(this.a1[i]*this.y1[i]+this.a2[i]*this.y2[i]+excitation*this.inputGain[i],-8,8);this.y2[i]=this.y1[i];this.y1[i]=y;output+=y;normal+=m.modes[i].gain;
   }
   output/=Math.max(1,normal*.6);
  }
  if(m.kind==='waveguide')output*=2.5;const drive=clamp(controls.drive??0)*3*v;output=Math.tanh(output*(1+drive))/(1+drive*.4);
  const tone=1-Math.exp(-2*Math.PI*Math.min(500+clamp(controls.brightness??.5)*15000,sr*.45)/sr);this.lastSample+=tone*(output-this.lastSample);this.age+=1/sr;this.frame++;
  return this.lastSample*(.25+.75*v)*(.5+clamp(controls.body??.5)*.5);
 }
}
export function renderPhysical(model,sampleRate,midi,velocity=100,seconds=2,controls={}){
 const voice=new PhysicalVoice(model,sampleRate),output=new Float32Array(Math.round(sampleRate*seconds)),hz=440*2**((midi-69)/12);
 for(let i=0;i<output.length;i++)output[i]=voice.tick(hz,{...controls,velocity:velocity/127});return output;
}
