import {selectAnchors} from './analyzer.js';

export const ARTICULATIONS=['sustain','trill','staccato','accent','breathy','alternate'];
export const articulationOf=event=>ARTICULATIONS.includes(event.articulation)?event.articulation:'sustain';
export function buildArticulationLayers(events,density){
  const layers=Object.fromEntries(ARTICULATIONS.map(name=>[name,[]]));
  for(const event of events.filter(e=>e.enabled!==false))layers[articulationOf(event)].push(event);
  for(const name of ARTICULATIONS){
    const byPitch=new Map();
    for(const event of layers[name]){
      const old=byPitch.get(event.midi);
      if(!old||event.confidence.overall>old.confidence.overall)byPitch.set(event.midi,event);
    }
    layers[name]=selectAnchors([...byPitch.values()],density);
  }
  return layers;
}
export function performanceArticulation(selected,velocity,velocityTrill,threshold=100){
  return velocityTrill&&velocity>=threshold?'trill':ARTICULATIONS.includes(selected)?selected:'sustain';
}
export function nearestArticulationAnchor(anchors,n){
  return [...anchors].sort((a,b)=>Math.abs(a.midi-n)-Math.abs(b.midi-n)||a.midi-b.midi)[0]||null;
}
