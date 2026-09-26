import {test} from 'node:test';
import assert from 'node:assert/strict';
import {panView,zoomView,selectionShades} from '../src/wave-view.js';

test('zoom and pan stay within the recording while crop times remain absolute',()=>{
  const full={start:0,end:40};
  const close=zoomView(full,40,2,5);
  assert.deepEqual(close,{start:0,end:20});
  assert.deepEqual(panView(35,20,40),{start:20,end:40});
  assert.deepEqual(zoomView(close,40,.5),full);
  assert.deepEqual(selectionShades(close,{start:2,end:10}),{left:10,right:50});
  assert.deepEqual(selectionShades({start:20,end:30},{start:2,end:10}),{left:0,right:100});
});
