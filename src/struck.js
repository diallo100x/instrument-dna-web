// Onset candidates for isolated mallet/bar strikes. Timing comes from the
// amplitude rise; pitch is measured separately after the noisy attack.
export function detectStrikes(samples,sampleRate){
  const size=Math.max(256,Math.round(sampleRate*.012)),hop=Math.max(128,Math.round(sampleRate*.006));
  const levels=[];
  for(let p=0;p+size<=samples.length;p+=hop){
    let power=0;for(let i=p;i<p+size;i++)power+=samples[i]*samples[i];
    levels.push({p,level:Math.sqrt(power/size)});
  }
  const hits=[],lookback=Math.max(2,Math.round(sampleRate*.03/hop)),refractory=Math.ceil(sampleRate*.085/hop);
  let last=-refractory;
  for(let i=lookback;i<levels.length-2;i++){
    const current=levels[i].level,previous=levels[i-lookback].level;
    if(i-last<refractory||current<.012||current<Math.max(.008,previous*1.65)||current<=levels[i-1].level*1.025)continue;
    // Follow the rising edge back, retaining the strike transient in the clip.
    let edge=i;
    while(edge>Math.max(last+refractory, i-lookback)&&levels[edge-1].level<current*.65&&levels[edge-1].level>Math.max(.004,previous*1.2))edge--;
    hits.push({sample:levels[edge].p,strength:Math.min(1,(current-previous)/Math.max(.02,current))});last=i;
  }
  return hits;
}

export function strikeEnd(samples,sampleRate,start,limit){
  const size=Math.max(256,Math.round(sampleRate*.012)),hop=size;
  let peak=0,quiet=0;
  for(let p=start;p+size<=limit;p+=hop){
    let power=0;for(let i=p;i<p+size;i++)power+=samples[i]*samples[i];
    const level=Math.sqrt(power/size);peak=Math.max(peak,level);
    if(p-start<sampleRate*.13)continue;
    quiet=level<Math.max(.004,peak*.045)?quiet+1:0;
    if(quiet>=3)return Math.min(limit,p+size);
  }
  return limit;
}
