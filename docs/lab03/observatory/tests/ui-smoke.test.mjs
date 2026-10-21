/* DOM-less integration smoke of the app state machine for environments where graphical Chromium is blocked.
 * This is not a rendered-browser or real-Web-Serial test.
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
import {webcrypto} from 'node:crypto';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
class FakeClassList {
  constructor(){this.names=new Set()}
  toggle(n,v){const yes=v===undefined?!this.names.has(n):!!v;yes?this.names.add(n):this.names.delete(n);return yes}
  add(n){this.names.add(n)} remove(n){this.names.delete(n)} contains(n){return this.names.has(n)}
}
class FakeElement {
  constructor(tag='div',id=''){this.tagName=tag.toUpperCase();this.id=id;this.children=[];this.classList=new FakeClassList();this.listeners=new Map();this.dataset={};this.style={setProperty(){}};this._text='';this._html='';this.value='';this.min='0';this.max='0';this.disabled=false;this.attrs={};}
  set innerHTML(v){this._html=String(v);this.children=[]} get innerHTML(){return this._html}
  set textContent(v){this._text=String(v);this.children=[]} get textContent(){return this._text}
  append(...el){this.children.push(...el)} appendChild(el){this.append(el)}
  replaceChildren(...el){this.children=[...el]}
  addEventListener(kind,fn){this.listeners.set(kind,fn)}
  fire(kind,v){const f=this.listeners.get(kind);if(f)return f(v||{target:this,key:undefined,preventDefault(){}})}
  setAttribute(k,v){this.attrs[k]=v}removeAttribute(k){delete this.attrs[k]}
  scrollIntoView(){}click(){this.fire('click')}
}
const html=fs.readFileSync(path.join(root,'index.html'),'utf8');
const elements=new Map([...html.matchAll(/\bid="([\w-]+)"/g)].map(m=>[m[1],new FakeElement('div',m[1])]));
const tabs=['explore','compare','instructions','worksheet','reference'].map(name=>{const x=new FakeElement('button');x.dataset.tab=name;return x});
const views=['explore','compare','instructions','worksheet','reference'].map(name=>{const x=elements.get('view-'+name);x.classList.toggle('hidden',name!=='explore');return x});
const get=s=>{
  if(s.startsWith('#') && !s.includes(' '))return elements.get(s.slice(1))||null;
  const m=/^#events-body tr\[data-event-index="(\d+)"\]$/.exec(s);
  if(m)return elements.get('events-body').children.find(x=>x.dataset.eventIndex===Number(m[1]))||null;
  throw new Error('Unknown mock selector '+s);
};
const getAll=s=>{
  if(s==='.tab')return tabs;
  if(s==='.view')return views;
  if(s==='#timeline [data-step]')return elements.get('timeline').children;
  if(s==='#events-body [data-event-index]')return elements.get('events-body').children;
  throw new Error('Unknown mock querySelectorAll '+s);
};
const documentMock={
  querySelector:get,querySelectorAll:getAll,
  createElement:tag=>new FakeElement(tag),
  addEventListener(){},
  activeElement:new FakeElement('body'),
  body:new FakeElement('body')
};
const fakeWindow={addEventListener(){}};
const oldFetch=globalThis.fetch;
globalThis.fetch=async url=>({ok:true,text:async()=>{
  const loc=path.resolve(root,String(url));
  if(!loc.startsWith(root+path.sep))throw new Error('Mock fetch escapes root');
  return fs.readFileSync(loc,'utf8');
}});
globalThis.document=documentMock;globalThis.window=fakeWindow;
Object.defineProperty(globalThis,'crypto',{value:webcrypto,configurable:true});

test('browser UI state loads 12 real traces and responds to playback, selection, comparison',async()=>{
  await import('../src/app.mjs');
  for(let i=0;i<40 && elements.get('trace-select').children.length<12;i++)await new Promise(r=>setTimeout(r,20));
  assert.equal(elements.get('trace-select').children.length,12,
     'archive did not load: '+elements.get('trace-meta').textContent);
  assert.equal(elements.get('stat-fetch').textContent,'269');
  assert.equal(elements.get('events-body').children.length,26);
  assert.equal(elements.get('timeline').children.length,26);
  assert.equal(elements.get('event-disasm').textContent,'andi t2, t2, 1');
  elements.get('next-btn').fire('click');
  assert.match(elements.get('current-step').textContent,/02 \/ 26/);
  const traceSelect=elements.get('trace-select');traceSelect.value='board-2';traceSelect.fire('change',{target:traceSelect});
  assert.equal(elements.get('events-body').children.length,20);
  assert.match(elements.get('trace-meta').textContent,/LED 0/);
  tabs.find(x=>x.dataset.tab==='instructions').fire('click');
  assert.match(elements.get('instruction-summary').innerHTML,/6<\/strong>/);
  assert.match(elements.get('instruction-grid').innerHTML,/269|sw t4, 0\(t0\)/);
  const isaScope=elements.get('instruction-scope');isaScope.value='rom';isaScope.fire('change');
  assert.match(elements.get('instruction-summary').innerHTML,/10<\/strong>/);
  assert.match(elements.get('instruction-padding').innerHTML,/54/);
  isaScope.value='archive';isaScope.fire('change');
  // Jump from an actually observed sw at PC=0x100 to the T3 Event Inspector.
  elements.get('instruction-grid').fire('click', {
    target:{closest:()=>({dataset:{jumpId:'board-1',jumpIndex:'23'}})}
  });
  assert.equal(elements.get('event-pc').textContent,'0x00000100');
  assert.equal(elements.get('event-word').textContent,'0x01D2A023');
  assert.equal(elements.get('event-disasm').textContent,'sw t4, 0(t0)');
  elements.get('inspect-instruction-btn').fire('click');
  assert.equal(elements.get('instruction-scope').value,'selected');
  assert.equal(elements.get('instruction-search').value,'sw');
  assert.match(elements.get('instruction-grid').innerHTML,/sw t4, 0\(t0\)/);
  // Reset the catalog controls before proceeding to comparison.
  elements.get('instruction-search').value='';
  isaScope.value='archive';isaScope.fire('change');
  tabs.find(x=>x.dataset.tab==='compare').fire('click');
  assert.match(elements.get('compare-summary').innerHTML,/Сигнатуры совпадают/);
  const right=elements.get('compare-right');right.value='board-2';right.fire('change',{target:right});
  assert.match(elements.get('compare-summary').innerHTML,/Команды различны/);
  // Mock a permitted Web Serial port. The test verifies the actual ASCII C→4→T
  // command sequence and that the returned T3 is parsed into a new LIVE trace.
  let portController;const encoded=new TextEncoder();const sent=[];
  const realTrace=JSON.parse(fs.readFileSync(path.join(root,'data/campaign.json'),'utf8')).boardCaptures[0].trace;
  const fakePort={
    readable:new ReadableStream({start(controller){portController=controller}}),
    writable:new WritableStream({write(chunk){
      const s=new TextDecoder().decode(chunk);sent.push(s);
      if(s==='C')portController.enqueue(encoded.encode('C\n'));
      else if(s==='4')portController.enqueue(encoded.encode('L=4\n'));
      else if(s==='T')portController.enqueue(encoded.encode(realTrace));
      else if(s==='?')portController.enqueue(encoded.encode('L=4\n'));
    }}),
    async open(options){assert.equal(options.baudRate,115200)},
    async setSignals(){},async close(){}
  };
  Object.defineProperty(globalThis,'navigator',{value:{serial:{requestPort:async()=>fakePort}},configurable:true});
  elements.get('connect-btn').fire('click');
  for(let i=0;i<40 && elements.get('capture-btn').disabled;i++)await new Promise(r=>setTimeout(r,10));
  assert.equal(elements.get('capture-btn').disabled,false,'mock serial connection did not open');
  elements.get('command-select').value='4';
  elements.get('capture-btn').fire('click');
  for(let i=0;i<100 && !elements.get('trace-select').value.startsWith('live-');i++)await new Promise(r=>setTimeout(r,10));
  assert.ok(elements.get('trace-select').value.startsWith('live-'),'live capture did not reach observatory');
  assert.deepEqual(sent,['C','4','T']);
  assert.equal(elements.get('events-body').children.length,26);
  assert.match(elements.get('trace-meta').textContent,/LIVE/);
  elements.get('connect-btn').fire('click');
  // The fake DOM does not test visual layout, the native OS permission dialog or physical COM10.
  globalThis.fetch=oldFetch;
});
