import {selectAnchors} from './analyzer.js';

// Sustain takes precedence for the ordinary keyboard when multiple sources
// supply the same pitch. Articulation layers retain their own candidates.
export function selectBaseAnchors(events,density,preferSustain=false){
  const best=new Map();
  for(const event of events.filter(e=>e.enabled!==false)){
    const old=best.get(event.midi);
    if(!old||(preferSustain&&(event.articulation==='sustain')!==(old.articulation==='sustain')?event.articulation==='sustain':event.confidence.overall>old.confidence.overall))best.set(event.midi,event);
  }
  return selectAnchors([...best.values()],density);
}
export function sourceForEvent(event,buffers){
  return event.sourceId?buffers.get(event.sourceId):null;
}
