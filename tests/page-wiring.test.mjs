import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

test('the page has complete HTML attributes and every statically wired control',async()=>{
  const html=await readFile(new URL('../index.html',import.meta.url),'utf8');
  const app=await readFile(new URL('../src/app.js',import.meta.url),'utf8');
  for(const tag of html.match(/<[^>]+>/g)||[]){
    assert.equal((tag.match(/"/g)||[]).length%2,0,`Unclosed attribute near ${tag.slice(0,90)}`);
  }
  const ids=new Set([...html.matchAll(/\bid="([^"]+)"/g)].map(match=>match[1]));
  for(const [,id] of app.matchAll(/\$\('([^']+)'\)/g))assert.ok(ids.has(id),`Missing UI control #${id}`);
});
