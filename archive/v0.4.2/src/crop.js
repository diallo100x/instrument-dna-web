export function cropBounds(start,end,duration){
  const max=Math.max(0,Number(duration)||0);
  let from=Math.min(max,Math.max(0,Number(start)||0));
  let to=Math.min(max,Math.max(0,Number(end)||0));
  if(to<from)[from,to]=[to,from];
  return {start:from,end:to,duration:to-from};
}

export function cropBuffer(context,buffer,start,end){
  const range=cropBounds(start,end,buffer.duration);
  const first=Math.floor(range.start*buffer.sampleRate),last=Math.min(buffer.length,Math.ceil(range.end*buffer.sampleRate));
  if(last-first<Math.round(buffer.sampleRate*.05))throw Error('Select at least 0.05 seconds of audio.');
  const cropped=context.createBuffer(buffer.numberOfChannels,last-first,buffer.sampleRate);
  for(let channel=0;channel<buffer.numberOfChannels;channel++)cropped.copyToChannel(buffer.getChannelData(channel).subarray(first,last),channel);
  return cropped;
}
