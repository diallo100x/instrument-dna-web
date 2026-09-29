import {clamp} from './dna.js';

function spectrum(samples,start,size){
  const re=new Float64Array(size),im=new Float64Array(size);
  for(let i=0;i<size;i++)re[i]=(samples[start+i]||0)*(.5-.5*Math.cos(2*Math.PI*i/(size-1)));
  for(let i=1,j=0;i<size;i++){
    let bit=size>>1;for(;j&bit;bit>>=1)j^=bit;j^=bit;
    if(i<j){[re[i],re[j]]=[re[j],re[i]]}
  }
  for(let len=2;len<=size;len<<=1){const angle=-2*Math.PI/len,cr=Math.cos(angle),ci=Math.sin(angle);
    for(let i=0;i<size;i+=len){let wr=1,wi=0;for(let j=0;j<len/2;j++){
      const k=i+j,l=k+len/2,tr=wr*re[l]-wi*im[l],ti=wr*im[l]+wi*re[l];
      re[l]=re[k]-tr;im[l]=im[k]-ti;re[k]+=tr;im[k]+=ti;
      [wr,wi]=[wr*cr-wi*ci,wr*ci+wi*cr];
    }}
  }
  return Float64Array.from({length:size/2},(_,i)=>Math.hypot(re[i],im[i]));
}

// A conservative onset-level multipitch estimate. A shared recording is NOT
// an isolated sample for any of these pitches. Octave-overlapping partials
// are deliberately consumed by the strongest note, so ambiguous octaves may
// be missed rather than asserted as independent notes.
export function estimatePolyphonicPitches(samples,sampleRate,start,end,{maxNotes=4}={}){
  const from=Math.max(0,Math.min(samples.length,start+Math.round(sampleRate*.028)));
  const available=Math.min(samples.length,end)-from;
  let size=8192;while(size>available)size>>=1;
  if(size<2048)return [];
  const bins=spectrum(samples,from,size),residual=bins.slice(),resolution=sampleRate/size;
  const peak=Math.max(...bins),sorted=Array.from(bins).sort((a,b)=>a-b),floor=sorted[Math.floor(sorted.length*.5)];
  if(peak<.01)return [];
  const near=(array,hz)=>{const center=hz/resolution,range=Math.max(1,Math.round(center*.025));let value=0;
    for(let i=Math.max(1,Math.round(center)-range);i<=Math.min(array.length-1,Math.round(center)+range);i++)value=Math.max(value,array[i]);return value};
  const found=[];
  for(let count=0;count<maxNotes;count++){
    let best=null;
    for(let midi=48;midi<=96;midi++){
      if(found.some(x=>x.midi===midi))continue;
      const hz=440*2**((midi-69)/12),fundamental=near(residual,hz);
      if(fundamental<Math.max(peak*.14,floor*7))continue;
      const second=hz*2<sampleRate*.48?near(residual,hz*2):0,third=hz*3<sampleRate*.48?near(residual,hz*3):0;
      const score=fundamental+.42*second+.2*third;
      if(score<peak*.2||best&&score<=best.score)continue;
      best={midi,hz,score,fundamental};
    }
    if(!best)break;
    found.push({midi:best.midi,confidence:clamp(.2+.55*best.fundamental/peak),strength:best.fundamental/peak});
    for(let h=1;h<=10&&best.hz*h<sampleRate/2;h++){
      const center=best.hz*h/resolution,range=Math.max(2,Math.ceil(center*.027));
      for(let i=Math.max(1,Math.floor(center)-range);i<=Math.min(residual.length-1,Math.ceil(center)+range);i++)residual[i]=0;
    }
  }
  return found.sort((a,b)=>a.midi-b.midi);
}
