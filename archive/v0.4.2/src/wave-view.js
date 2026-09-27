export function panView(start,span,duration){
  const width=Math.min(duration,Math.max(.1,span));
  const left=Math.max(0,Math.min(Number(start)||0,duration-width));
  return {start:left,end:left+width};
}

export function zoomView(view,duration,factor,focus=(view.start+view.end)/2){
  const span=Math.min(duration,Math.max(.1,(view.end-view.start)/factor));
  return panView(focus-span/2,span,duration);
}

export function selectionShades(view,selection){
  const span=view.end-view.start;
  return {left:Math.max(0,Math.min(100,(selection.start-view.start)/span*100)),right:Math.max(0,Math.min(100,(view.end-selection.end)/span*100))};
}
