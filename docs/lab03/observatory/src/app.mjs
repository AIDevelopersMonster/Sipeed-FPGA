import {
  ROM_SHA256, BITSTREAM_DECLARED_SHA256, hex32, parseRom, parseTrace,
  disassemble, normalizedCore, compareTraces, eventKey, eventInterpretation, expectedLedMask
} from './trace-core.mjs';
import {catalogFromTraces, catalogFromRom, binaryWord, opcodeBits} from './instruction-catalog.mjs';

const $ = s => document.querySelector(s);
const $$ = s => [...document.querySelectorAll(s)];
const html = value => String(value ?? '').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const scrollRow = (idx, auto=false) => {
  const row=$(`#events-body tr[data-event-index="${idx}"]`);
  if (row && auto) row.scrollIntoView({behavior:'smooth',block:'nearest'});
};
const state = { rom:null, campaign:null, traces:[], selectedId:null, currentIndex:0, playing:false, timer:null,
  compareLeft:null,compareRight:null, port:null, reader:null, serialBuffer:'', lineQueue:[], lineWaiters:[], connected:false, serialBusy:false, serialReadRunning:false };
const getTrace = id => state.traces.find(x=>x.id===id) || null;
const current = () => getTrace(state.selectedId);
const btn = (id, handler) => $(id).addEventListener('click',handler);
const unique = (key,arr) => [...new Set(arr.map(x=>x[key]))];
let toastTimer;
function toast(message,error=false){
  const el=$('#toast');el.textContent=message;el.classList.toggle('error',error);el.classList.add('visible');
  clearTimeout(toastTimer);toastTimer=setTimeout(()=>el.classList.remove('visible'),4500);
}
function notice(message,level='info'){
  const el=$('#serial-message');el.textContent=message;el.classList.toggle('error',level==='error');el.classList.toggle('good',level==='good');
}
async function digest(bytes) {
  if (!crypto?.subtle) throw new Error('SHA-256 недоступен: откройте стенд через http://127.0.0.1, а не по file://');
  const hash=await crypto.subtle.digest('SHA-256',bytes);
  return [...new Uint8Array(hash)].map(x=>x.toString(16).padStart(2,'0')).join('');
}
async function fetchText(url) {
  const res=await fetch(url,{cache:'no-store'});
  if(!res.ok)throw new Error(`HTTP ${res.status}: ${url}`);
  return res.text();
}
function addTrace({id,label,origin,raw,sha='',run=null,utc='',fileName='',select=false}) {
  const decoded=parseTrace(raw,state.rom);
  const core=normalizedCore(decoded);
  const src={id,label,origin,raw,sha,run,utc,fileName,decoded,core};
  if(state.traces.some(t=>t.id===id))throw new Error('Дублированный ID трассы');
  state.traces.push(src);
  if(select)state.selectedId=id;
  return src;
}
function sourceName(t){return t.origin==='BOARD'?'АППАРАТНАЯ FPGA':t.origin==='LIVE'?'LIVE · UART':t.origin==='RTL_FILE'?'ФАЙЛ · RTL (заявлен)': 'ИМПОРТ T3';}
function commandDescription(cmd){return cmd==='0'?'OFF · все светодиоды':`L${cmd} · маска ${hex32(expectedLedMask(cmd))}`;}
function traceOptionLabel(t){return `${t.origin==='BOARD'?'FPGA':t.origin==='RTL_FILE'?'RTL?':t.origin==='LIVE'?'LIVE':'T3'} · ${t.label} · cmd ${t.decoded.command} · FETCH ${t.decoded.fetchCount}`;}
function setOptions(selector,entries,value){
  const el=$(selector);el.replaceChildren();
  entries.forEach(e=>{let opt=document.createElement('option');opt.value=e.id;opt.textContent=traceOptionLabel(e);el.append(opt)});
  if(value&&entries.some(e=>e.id===value))el.value=value;
}
function refreshSelectors(){
  setOptions('#trace-select',state.traces,state.selectedId);
  setOptions('#compare-left',state.traces.filter(t=>t.origin!=='RTL_FILE'),state.compareLeft);
  setOptions('#compare-right',state.traces,state.compareRight);
}
function switchView(name){
  $$('.tab').forEach(b=>{b.classList.toggle('active',b.dataset.tab===name);if(b.dataset.tab===name)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current')});
  $$('.view').forEach(v=>v.classList.toggle('hidden',v.id!==`view-${name}`));
  if(name==='compare')renderComparison();
  if(name==='instructions')renderInstructionCatalog();
}
function stopPlay(){clearInterval(state.timer);state.timer=null;state.playing=false;$('#play-btn').innerHTML='▶ <span>Воспроизвести</span>'}
function stepTo(n,autoScroll=false){
  const t=current();if(!t)return;
  state.currentIndex=Math.max(0,Math.min(t.decoded.events.length-1,n));
  $('#step-range').value=state.currentIndex;
  $('#current-step').textContent=`${String(state.currentIndex+1).padStart(2,'0')} / ${String(t.decoded.events.length).padStart(2,'0')}`;
  $$('#timeline [data-step]').forEach(b=>b.classList.toggle('active',Number(b.dataset.step)===state.currentIndex));
  $$('#events-body [data-event-index]').forEach(row=>row.classList.toggle('row-selected',Number(row.dataset.eventIndex)===state.currentIndex));
  renderInspector(t.decoded.events[state.currentIndex],t.core.prefixCount);
  renderLed(t.decoded.events[state.currentIndex]);
  scrollRow(state.currentIndex,autoScroll);
}
function setTrace(id){
  if(!getTrace(id))return;
  stopPlay();state.selectedId=id;state.currentIndex=0;refreshSelectors();renderTrace();
}
function renderLed(event){
  const isWrite=event.kind==='LED_WRITE';const val=isWrite?event.value:0;
  const led=$('#led-bank');led.replaceChildren();led.classList.toggle('incomplete',!isWrite);
  for(let i=1;i<=6;i++){
    const unit=document.createElement('div');unit.className='led-unit'+(isWrite && (val&(1<<(i-1)))?' on':'');
    unit.title=isWrite?`L${i}: логическое ${val&(1<<(i-1))?1:0}`:`L${i}: ещё нет LED_WRITE в воспроизведённых событиях`;
    unit.innerHTML='<i class="led-bulb"></i><span>L'+i+'</span>';led.append(unit);
  }
  $('#led-mask-code').textContent=isWrite?hex32(val):'— (до LED_WRITE)';
}
function renderInspector(e,prefixCount){
  $('#event-kind').textContent=e.kind;$('#event-kind').classList.toggle('write',e.kind==='LED_WRITE');
  $('#event-ordinal').textContent=`#${String(e.index).padStart(3,'0')}`;
  $('#event-pc').textContent=hex32(e.address);$('#event-word').textContent=hex32(e.value);
  $('#event-pc').title=e.kind==='FETCH'?'Адрес 32-битного машинного слова в ROM (PC для принятого FETCH).':'Адрес регистра периферии в MMIO-пространстве.';
  $('#event-word').title=e.kind==='FETCH'?'32-битная кодировка инструкции RISC-V, считанной из ROM.':'32-битная маска светодиодов, записанная в MMIO. Это не код инструкции.';
  $('#event-cycle').textContent=String(e.cycle);
  $('#event-phase').textContent=e.kind==='LED_WRITE'?'MMIO / GPIO':e.index<prefixCount?'UART polling':'Нормализованный участок';
  const d=e.kind==='FETCH'?disassemble(e.value,e.address):null;
  $('#event-disasm').textContent=d?d.asm:'LED_WRITE · data';
  $('#event-disasm').title=d?d.explanation:'Шинная запись данных в периферийный регистр';
  $('#event-disasm-explain').textContent=d?d.explanation:'Здесь поле VALUE — данные MMIO, а не машинное слово инструкции.';
  $('#event-disasm-kind').textContent=d?`${d.klass} / MACHINE WORD`:'PERIPHERAL DATA WRITE';
  $('#inspect-instruction-btn').disabled=!d;
  $('#event-explanation').textContent=eventInterpretation(e);
}
function renderChart(){
  const chart=$('#capture-chart');chart.replaceChildren();
  const runs=state.traces.filter(t=>t.origin==='BOARD').sort((a,b)=>a.run-b.run);
  runs.forEach(t=>{
    const h=Math.round(t.decoded.fetchCount/30*77);
    const b=document.createElement('button');b.type='button';
    b.className=`bar-cell command-${t.decoded.command}`+(state.selectedId===t.id?' selected':'');
    b.title=`Аппаратный запуск №${t.run}; команда ${t.decoded.command}; ${t.decoded.fetchCount} FETCH`;
    b.setAttribute('aria-label',b.title);
    b.dataset.runId=t.id;b.style.setProperty('--barheight',`${h}px`);
    b.innerHTML=`<span class="bar-count">${t.decoded.fetchCount}</span><span class="bar-column" style="height:${h}px"></span>`;
    b.addEventListener('click',()=>setTrace(t.id));chart.append(b);
  });
}
function renderTrace(){
  const t=current();if(!t)return;
  renderChart();
  $('#trace-source-card').innerHTML=`<span class="source-symbol">◎</span><div><strong>${html(sourceName(t))}</strong><small>${t.sha?`SHA-256: ${html(t.sha.slice(0,12))}…`:'Файл проверен по T3 и ROM'}</small></div><span class="source-status">${t.origin==='BOARD'?'RAW':t.origin==='LIVE'?'LIVE':t.origin==='RTL_FILE'?'RTL?':'FILE'}</span>`;
  $('#trace-badges').innerHTML=`<span class="trace-badge">C:${html(t.decoded.command)}</span><span class="trace-badge secondary">${t.decoded.fetchCount} FETCH</span><span class="trace-badge secondary">${t.core.prefixCount} POLL</span>`;
  $('#trace-meta').textContent=`${t.label} · ${t.decoded.events.length} событий · ${commandDescription(t.decoded.command)}`;
  $('#trace-flags').textContent='DONE · TRUNC=0 · OVERLAP=0';
  if($('#instruction-scope').value==='selected')renderInstructionCatalog();
  const timeline=$('#timeline');timeline.replaceChildren();
  t.decoded.events.forEach((e,i)=>{
    const b=document.createElement('button');b.type='button';b.dataset.step=i;
    b.className=`timeline-event ${e.kind==='LED_WRITE'?'kind-write':i<t.core.prefixCount?'kind-prefix':'kind-fetch'}`;
    b.title=`№${i} · ${e.kind} · ${hex32(e.address)} · ${hex32(e.value)} · cycle ${e.cycle}`;
    b.setAttribute('aria-label',b.title);b.addEventListener('click',()=>stepTo(i,true));timeline.append(b);
  });
  const tbody=$('#events-body');tbody.replaceChildren();
  t.decoded.events.forEach((e,i)=>{
    const d=e.kind==='FETCH'?disassemble(e.value,e.address):null;
    const tag=e.kind==='LED_WRITE'?'write':i<t.core.prefixCount?'prefix':'';
    const tr=document.createElement('tr');tr.tabIndex=0;tr.dataset.eventIndex=i;
    tr.title='Нажмите, чтобы открыть событие в инспекторе';
    tr.innerHTML=`<td class="mono muted-cell">${String(i).padStart(2,'0')}</td><td class="mono">${e.cycle}</td><td><span class="kind-tag ${tag}">${e.kind}</span></td><td class="mono address" title="${e.kind==='FETCH'?'PC / адрес выборки ROM':'Адрес MMIO-регистра светодиодов'}">${hex32(e.address)}</td><td class="mono ${e.kind==='LED_WRITE'?'write-cell':''}" title="${e.kind==='FETCH'?'Машинное слово RV32I':'Данные записи в MMIO'}">${hex32(e.value)}</td><td class="assembly" title="${html(d?d.explanation:'Запись значения в регистр GPIO')}">${html(d?d.asm:'MMIO GPIO write')}</td>`;
    tr.addEventListener('click',()=>stepTo(i));
    tr.addEventListener('keydown',ev=>{if(ev.key==='Enter'||ev.key===' '){ev.preventDefault();stepTo(i)}});
    tbody.append(tr);
  });
  $('#events-foot').textContent=`${t.core.prefixCount} FETCH в префиксе · ${t.core.fetchCount} FETCH в стабильном участке · 1 LED_WRITE`;
  $('#step-range').max=String(t.decoded.events.length-1);
  stepTo(0);
}
function miniCard(t){
  if(!t)return '<p>Выберите трассу.</p>';
  return `<span class="section-kicker">${html(sourceName(t))}</span><h3>${html(t.label)}</h3><p>${html(commandDescription(t.decoded.command))}</p><div class="compare-metrics"><span>Всего FETCH<b>${t.decoded.fetchCount}</b></span><span>Префикс UART<b>${t.core.prefixCount}</b></span><span>Core FETCH<b>${t.core.fetchCount}</b></span><span>LED_WRITE<b>${html(hex32(t.decoded.ledMask))}</b></span></div>`;
}
function renderComparison(){
  const a=getTrace(state.compareLeft),b=getTrace(state.compareRight);
  $('#compare-left-card').innerHTML=miniCard(a);$('#compare-right-card').innerHTML=miniCard(b);
  const summary=$('#compare-summary'),tbody=$('#compare-body');tbody.replaceChildren();
  if(!a||!b){summary.classList.add('mismatch');summary.innerHTML='<span class="compare-result-icon">?</span><div><h3>Не хватает данных</h3><p>Выберите обе трассы.</p></div>';return;}
  let res;
  try{res=compareTraces(a.decoded,b.decoded);}catch(err){res={match:false,reason:err.message,rows:[]}}
  summary.classList.toggle('mismatch',!res.match);
  const ambiguous=a.id===b.id?'Выбрана одна и та же трасса — это проверка самотождества, не независимый эксперимент.':
     (a.origin==='RTL_FILE'||b.origin==='RTL_FILE')?'Один файл обозначен оператором как RTL; браузер не проверяет его происхождение.':'Сравниваются два независимых захвата физической FPGA.';
  const headline=res.match?'Сигнатуры совпадают':'Обнаружено расхождение';
  const qualifier=res.match&&a.decoded.command===b.decoded.command?` • core=${res.left.events.length} событий` : '';
  summary.innerHTML=`<span class="compare-result-icon">${res.match?'✓':'≠'}</span><div><h3>${html(headline)}</h3><p>${html(res.reason+qualifier)}. ${html(ambiguous)}</p></div>`;
  for(const row of (res.rows||[])){
    const tr=document.createElement('tr');if(!row.match)tr.className='diff';
    const left=row.left?eventKey(row.left):'—';const right=row.right?eventKey(row.right):'—';
    tr.innerHTML=`<td class="mono muted-cell">${String(row.pos+1).padStart(2,'0')}</td><td class="mono">${html(left)}</td><td class="mono">${html(right)}</td><td><span class="${row.match?'match-symbol':'mismatch-symbol'}">${row.match?'MATCH':'DIFF'}</span></td>`;
    tbody.append(tr);
  }
}
function saveBlob(filename,content,mime){
  const blob=new Blob([content],{type:mime});const url=URL.createObjectURL(blob);
  const a=document.createElement('a');a.href=url;a.download=filename;a.style.display='none';document.body.append(a);a.click();a.remove();
  setTimeout(()=>URL.revokeObjectURL(url),1000);
}
async function addFile(file,origin){
  if(file.size>140000)throw new Error(`${file.name}: превышен размер T3 (140 КБ)`);
  const raw=await file.text();const sha=await digest(new TextEncoder().encode(raw));
  const prefix=origin==='RTL_FILE'?'rtl': 'upload';const id=`${prefix}-${Date.now()}-${Math.random().toString(16).slice(2,6)}`;
  return addTrace({id,label:file.name,origin,raw,sha,fileName:file.name,select:origin!=='RTL_FILE'});
}
async function importFiles(event,origin){
  const files=[...(event.target.files||[])];if(!files.length)return;
  let ok=0,errors=[];let last;
  for(const file of files){try{last=await addFile(file,origin);ok++}catch(e){errors.push(`${file.name}: ${e.message}`)}}
  refreshSelectors();if(last){if(origin==='RTL_FILE'){state.compareRight=last.id;$('#compare-right').value=last.id;switchView('compare')}else setTrace(last.id)}
  if(errors.length)toast(`Загружено ${ok}; отклонено ${errors.length}. ${errors[0]}`,true);
  else toast(`Загружено ${ok} T3-файл(ов). Структура, завершение и ROM проверены.`);
  event.target.value='';
}
function exportWorksheet(){
  const safe=s=>String(s||'').replace(/\r\n/g,'\n');
  const board=state.traces.filter(t=>t.origin==='BOARD');
  const lines=[
    '# LAB-03 — протокол лабораторных наблюдений','',
    `- Исследователь: ${safe($('#student-name').value)||'—'}`,
    `- Дата составления: ${new Date().toLocaleString('ru-RU')}`,
    '- Стенд: Tang Nano 9K / PicoRV32 / T3 ASCII',
    `- Исходный архив: LAB03_3_EVIDENCE.zip, SHA256 ${state.campaign.archiveSha256}`,
    `- ROM SHA256: ${ROM_SHA256}`,
    `- Команда 0: FETCH = ${board.filter(t=>t.decoded.command==='0').map(t=>t.decoded.fetchCount).join(', ')}`,
    `- Команда 4: FETCH = ${board.filter(t=>t.decoded.command==='4').map(t=>t.decoded.fetchCount).join(', ')}`,
    '- Нормализованный core FETCH: 0 → 14, 4 → 22','',
    '## 1. Гипотеза','',safe($('#hypothesis').value)||'(не заполнено)','',
    '## 2. Наблюдения','',safe($('#observations').value)||'(не заполнено)','',
    '## 3. Интерпретация','',safe($('#interpretation').value)||'(не заполнено)','',
    '## 4. Вывод / ограничения','',safe($('#conclusion').value)||'(не заполнено)','',
    '---','',
    'Данные — сохранённые аппаратные захваты. FETCH ≠ instruction retirement. FPGA SRAM не считывалась.',''
  ];
  saveBlob(`LAB03_student_protocol_${new Date().toISOString().slice(0,10)}.md`,lines.join('\n'),'text/markdown;charset=utf-8');
  toast('Протокол сохранён в Markdown.');
}
function fillObservations(){
  const board=state.traces.filter(t=>t.origin==='BOARD');
  const by=cmd=>board.filter(t=>t.decoded.command===cmd).sort((a,b)=>a.run-b.run);
  const line=cmd=>by(cmd).map(t=>`№${t.run}: ${t.decoded.fetchCount} FETCH (префикс ${t.core.prefixCount})`).join('; ');
  const text=`Команда 0: ${line('0')}.\nКоманда 4: ${line('4')}.\nПосле PC=0x048: команда 0 — 14 FETCH; команда 4 — 22 FETCH.\nLED_WRITE: 0 → 0x00000000; 4 → 0x00000008.\nПолные счётчики FETCH изменчивы; относительные циклы при сравнении не приравниваются.`;
  const node=$('#observations');node.value=(node.value?node.value.trim()+'\n\n':'')+text;
  toast('Фактические показатели из 12 аппаратных захватов вставлены.');
}
function startPlay(){
  if(state.playing){stopPlay();return}
  const t=current();if(!t)return;
  if(state.currentIndex>=t.decoded.events.length-1)stepTo(0);
  state.playing=true;$('#play-btn').innerHTML='Ⅱ <span>Пауза</span>';
  state.timer=setInterval(()=>{
    const t=current();if(!t){stopPlay();return}
    if(state.currentIndex>=t.decoded.events.length-1){stopPlay();return}
    stepTo(state.currentIndex+1,true);
    if(state.currentIndex>=t.decoded.events.length-1)stopPlay();
  },Number($('#speed-select').value));
}

// Web Serial: explicit user-initiated access only, no flashing, no background reconnection.
function rejectReadWaiters(err){
  for(const w of state.lineWaiters.splice(0)){clearTimeout(w.timer);w.reject(err)}
}
function acceptLine(line){
  const normalized=line.trim();if(!normalized)return;
  const waiting=state.lineWaiters.shift();
  if(waiting){clearTimeout(waiting.timer);waiting.resolve(normalized)}
  else {state.lineQueue.push(normalized);if(state.lineQueue.length>512)state.lineQueue.shift()}
}
async function serialPump(){
  state.serialReadRunning=true;
  try{
    while(state.port?.readable){
      const reader=state.port.readable.getReader();state.reader=reader;
      try{
        const decoder=new TextDecoder('ascii');
        while(true){
          const {value,done}=await reader.read();if(done)break;
          state.serialBuffer+=decoder.decode(value,{stream:true});
          if(state.serialBuffer.length>40000)throw new Error('UART line buffer overflow');
          const rows=state.serialBuffer.split('\n');state.serialBuffer=rows.pop();
          rows.forEach(acceptLine);
        }
      }finally{reader.releaseLock();state.reader=null}
      break;
    }
  }catch(e){notice(`Ошибка чтения UART: ${e.message}`,'error')}
  finally{
    state.serialReadRunning=false;
    rejectReadWaiters(new Error('UART был закрыт'));
    if(state.connected){state.connected=false;refreshSerialUi();notice('UART отключился; повторите подключение.','error')}
  }
}
function readLine(timeoutMs=20000){
  if(state.lineQueue.length)return Promise.resolve(state.lineQueue.shift());
  return new Promise((resolve,reject)=>{
    const obj={resolve,reject,timer:null};
    obj.timer=setTimeout(()=>{
      const n=state.lineWaiters.indexOf(obj);if(n>=0)state.lineWaiters.splice(n,1);
      reject(new Error('Тайм-аут чтения UART: нет ответа платы'));
    },timeoutMs);state.lineWaiters.push(obj);
  });
}
async function meaningfulLine(deadline){
  for(let i=0;i<8;i++){
    const remain=deadline-Date.now();if(remain<1)throw new Error('Истекло время ответа UART');
    const s=await readLine(remain);if(s!=='READY')return s;
  }
  throw new Error('Слишком много повторных READY; проверьте прошивку');
}
async function sendAscii(s){
  if(!state.connected||!state.port?.writable)throw new Error('UART не подключён');
  const writer=state.port.writable.getWriter();
  try{await writer.write(new TextEncoder().encode(s))}
  finally{writer.releaseLock()}
}
function refreshSerialUi(){
  $('#port-pill').classList.toggle('connected',state.connected);
  $('#port-pill').innerHTML=`<i></i>${state.connected?'UART подключён':'UART отключён'}`;
  $('#connection-detail').textContent=state.connected?'115200 8N1 · соединение открыто':'Не подключён';
  $('#connect-btn').textContent=state.connected?'Отключить UART':'Подключить COM-порт';
  $('#connect-btn').disabled=state.serialBusy;
  ['#capture-btn','#reread-btn','#query-btn'].forEach(sel=>$(sel).disabled=!state.connected||state.serialBusy);
}
async function disconnect(){
  const port=state.port;
  state.connected=false;refreshSerialUi();
  try{await state.reader?.cancel()}catch{}
  try{await port?.close()}catch{}
  state.port=null;state.lineQueue=[];state.serialBuffer='';
  rejectReadWaiters(new Error('Порт закрыт пользователем'));
  notice('Порт закрыт. Архивные трассы доступны без платы.');
}
async function connect(){
  if(state.connected){await disconnect();return;}
  if(!('serial' in navigator)){
    notice('Web Serial недоступен. Откройте http://127.0.0.1 в Chromium/Edge; Firefox обычно не поддерживает Web Serial.','error');return;
  }
  let port;
  try{
    port=await navigator.serial.requestPort();
    await port.open({baudRate:115200,dataBits:8,stopBits:1,parity:'none',flowControl:'none'});
    try{if(port.setSignals)await port.setSignals({dataTerminalReady:false,requestToSend:false})}catch{}
    state.port=port;state.connected=true;state.lineQueue=[];state.serialBuffer='';
    void serialPump();refreshSerialUi();notice('UART подключён. Выберите команду и нажмите «Захватить».','good');
  }catch(e){
    if(port){try{await port.close()}catch{}}
    if(e?.name==='NotFoundError')return;
    notice(`Не удалось открыть UART: ${e.message}. Закройте терминалы и вкладки, использующие COM-порт.`,'error');
  }
}
async function operation(task){
  if(state.serialBusy||!state.connected)return;
  state.serialBusy=true;refreshSerialUi();
  try{await task()}catch(e){notice(`Операция не выполнена: ${e.message}`,'error');toast(e.message,true)}
  finally{state.serialBusy=false;refreshSerialUi()}
}
async function readSnapshot(){
  const deadline=Date.now()+30000;
  await sendAscii('T');
  const head=await meaningfulLine(deadline);
  if(!/^T3:[0-9a-fA-F]{8}:[0-9a-fA-F]{8}$/.test(head))throw new Error(`Ожидался T3-header, получено «${head.slice(0,80)}»`);
  const count=parseInt(head.slice(3,11),16)&255;
  if(count>128)throw new Error('T3: превышена ёмкость захвата');
  const rows=[head];
  for(let i=0;i<count+1;i++){
    const remain=deadline-Date.now();if(remain<1)throw new Error('UART: тайм-аут при чтении трассы');
    rows.push(await readLine(remain));
  }
  const trace=rows.join('\r\n')+'\r\n';
  const parsed=parseTrace(trace,state.rom);return {trace,parsed};
}
async function captureLive(){
  await operation(async()=>{
    const cmd=$('#command-select').value;
    state.lineQueue=[];
    notice(`Идёт захват: C → ${cmd} → T; ожидаем ACK и T3…`);
    await sendAscii('C');const clear=await meaningfulLine(Date.now()+20000);
    if(clear!=='C')throw new Error(`ACK после C: ожидалось C, получено ${clear}`);
    await sendAscii(cmd);const ack=await meaningfulLine(Date.now()+20000);
    if(ack!==`L=${cmd}`)throw new Error(`LED ACK: ожидалось L=${cmd}, получено ${ack}`);
    const {trace,parsed}=await readSnapshot();
    if(parsed.command!==cmd)throw new Error(`Команда снимка ${parsed.command} не совпала с ${cmd}`);
    const sha=await digest(new TextEncoder().encode(trace));
    const label=`LIVE ${new Date().toLocaleTimeString('ru-RU')} · команда ${cmd}`;
    const id=`live-${Date.now()}`;
    addTrace({id,label,origin:'LIVE',raw:trace,sha,utc:new Date().toISOString(),select:true});
    setTrace(id);notice(`Захват принят: ${parsed.fetchCount} FETCH, LED_WRITE ${hex32(parsed.ledMask)}. Оптическое состояние платы подтвердите отдельно.`, 'good');
    toast('LIVE T3: структура, ROM и MMIO проверены.');
  });
}
async function rereadLive(){
  await operation(async()=>{
    state.lineQueue=[];
    const {trace,parsed}=await readSnapshot();
    const sha=await digest(new TextEncoder().encode(trace));
    const id=`live-read-${Date.now()}`;
    addTrace({id,label:`T (повторное чтение) · ${new Date().toLocaleTimeString('ru-RU')}`,origin:'LIVE',raw:trace,sha,select:true});
    setTrace(id);notice(`Снимок T прочитан без сброса: команда ${parsed.command}, ${parsed.count} событий.`, 'good');
  });
}
async function queryLive(){
  await operation(async()=>{
    state.lineQueue=[];await sendAscii('?');
    const line=await meaningfulLine(Date.now()+20000);
    if(!/^L=[0-6]$/.test(line))throw new Error(`Неожиданный ответ на ?: ${line}`);
    notice(`Аппаратное чтение регистра LED: ${line}, маска ${hex32(expectedLedMask(line.at(-1)))}. Новая трасса не создавалась.`, 'good');
  });
}
// Observed FETCHes and ROM words have different evidence semantics.
// Every mnemonic below is selected by actual data; prose is from the ISA notes.
const formatTip = (txt, label='Пояснение') => `<button class="tip" type="button" data-tip="${html(txt)}" aria-label="${html(label)}">?</button>`;
function activeInstructionCatalog(){
  const scope=$('#instruction-scope').value;
  if(scope==='rom')return catalogFromRom(state.rom);
  if(scope==='selected')return catalogFromTraces(current()?[current()]:[]);
  return catalogFromTraces(state.traces.filter(t=>t.origin==='BOARD'));
}
function findMeasuredEvent(site){
  const candidates=[current(),...state.traces.filter(t=>t.origin==='BOARD'),...state.traces.filter(t=>t.origin==='LIVE')].filter(Boolean);
  for(const t of candidates){
    const index=t.decoded.events.findIndex(e=>e.kind==='FETCH'&&e.address===site.address&&e.value===site.value);
    if(index>=0)return {traceId:t.id,eventIndex:index};
  }
  return null;
}
function instructionCard(entry,catalog,scope){
  const note=entry.note;
  const name=entry.mnemonic;
  const cnt=(scope==='rom'?'слов в активном ROM':'наблюдений FETCH');
  const samples=entry.sites;
  const show=site=>{
    const measured=findMeasuredEvent(site);
    const jump=measured?`<button class="isa-jump" type="button" data-jump-id="${html(measured.traceId)}" data-jump-index="${measured.eventIndex}" title="Открыть именно этот FETCH в трассе">↗ В трассу</button>`:
      `<span class="isa-rom-only" title="Данный адрес не был выбран регистратором в архивной серии">Только ROM</span>`;
    return `<tr><td class="mono" title="Адрес машинного слова в ROM">${hex32(site.address)}</td>
      <td class="mono" title="32-битный код RISC-V">${hex32(site.value)}</td><td class="mono isa-asm">${html(site.asm)}</td>
      <td>${scope==='rom'?'ROM · 1':`${site.count} FETCH`}</td><td>${jump}</td></tr>`;
  };
  const limit=4;
  const examples=samples.slice(0,limit).map(show).join('');
  const remaining=samples.length>limit?`<details class="isa-more"><summary>Показать остальные ${samples.length-limit} адресов</summary>
    <div class="table-scroll"><table class="events-table isa-example-table"><thead><tr><th>PC</th><th>Машинное слово</th><th>Дизассемблирование</th><th>В данных</th><th>Переход</th></tr></thead><tbody>${samples.slice(limit).map(show).join('')}</tbody></table></div></details>`:'';
  const words=samples[0];
  const types=note?`<div class="isa-effect"><strong>Семантика:</strong> ${html(note.effect)}</div><p>${html(note.role)}</p>
    <div class="isa-syntax"><span>Синтаксис</span><code>${html(note.syntax)}</code>
       ${formatTip(note.operands.join('; '),'Операнды инструкции')}</div>
    <p class="isa-caveat">${html(note.caveat)}</p>`:
    `<p class="isa-caveat">Нет карточки ISA для ${html(name)}: проверьте кодировку. Программа не должна угадывать неизвестные машинные слова.</p>`;
  return `<details class="panel isa-card" ${['sw','beq'].includes(name)?'open':''}>
    <summary class="isa-card-head"><span class="isa-mnemonic">${html(name)}</span>
      <span class="isa-card-heading"><strong>${html(note?.title||'Неизвестное слово')}</strong><small>${html(note?.en||'UNRECOGNIZED')} · ${html(note?.format||'?')}-type</small></span>
      <span class="isa-count"><b>${entry.count}</b><small>${cnt}</small></span><span class="isa-chevron">⌄</span></summary>
    <div class="isa-card-body">${types}
      <div class="isa-code-breakdown"><span>Реальный код</span><code title="Машинное слово из наших данных">${hex32(words.value)}</code>
        <span>В двоичном виде</span><code class="isa-bits" title="32 бита инструкции, группы по 4 бита">${binaryWord(words.value)}</code>
        <span>Opcode</span><code title="Opcode — младшие семь бит инструкции; задают основной класс команды">${opcodeBits(words.value)}</code></div>
      <div class="isa-example-head"><strong>${scope==='rom'?'Адреса в ROM':'Наблюдённые адреса PC'}</strong><span>${samples.length} разных адресов / кодировок</span></div>
      <div class="table-scroll"><table class="events-table isa-example-table"><thead><tr><th>PC</th><th>Машинное слово</th><th>Дизассемблирование</th><th>В данных</th><th>Переход</th></tr></thead><tbody>${examples}</tbody></table></div>${remaining}
    </div></details>`;
}
function renderInstructionCatalog(){
  if(!state.rom||!state.campaign)return;
  let catalog;
  try{catalog=activeInstructionCatalog()}catch(error){$('#instruction-summary').textContent=`Каталог недоступен: ${error.message}`;return;}
  const scope=$('#instruction-scope').value;
  const query=$('#instruction-search').value.trim().toLowerCase();
  const entries=catalog.entries.filter(entry=>!query||[
    entry.mnemonic,entry.note?.en,entry.note?.title,entry.note?.syntax,...entry.sites.map(s=>`${hex32(s.address)} ${hex32(s.value)} ${s.asm}`)
  ].some(s=>String(s||'').toLowerCase().includes(query)));
  const currentTag=current()?`${current().label} · команда ${current().decoded.command}`:'нет выбранного захвата';
  const heading=scope==='rom'?`Полная прошивка LAB-03 · ${catalog.activeWords} инструкционных слов до дополнения NOP`:
    scope==='selected'?`Выбранная трасса: ${html(currentTag)}`:'Архив реальных измерений · 12 захватов FPGA';
  const figure=scope==='rom'?`${catalog.activeWords} слов в активной части ROM`:`${catalog.fetchTotal} принятых FETCH`;
  $('#instruction-summary').innerHTML=`<div class="isa-summary-stat"><strong>${catalog.entries.length}</strong><small>различных мнемоник</small></div>
    <div class="isa-summary-stat"><strong>${catalog.uniqueSites}</strong><small>уникальных адресов PC</small></div>
    <div class="isa-summary-stat"><strong>${figure}</strong><small>${heading}</small></div>
    <div class="isa-summary-caption">Показано ${entries.length} из ${catalog.entries.length} команд. ${scope==='rom'?'ROM-присутствие ≠ наблюдение исполнения.':'Числа — события FETCH, а не завершённые инструкции.'}</div>`;
  $('#instruction-grid').innerHTML=entries.length?entries.map(e=>instructionCard(e,catalog,scope)).join(''):
    '<div class="panel isa-empty">В выбранных данных нет команд, соответствующих поиску. Попробуйте другую мнемонику или адрес.</div>';
  const padding=$('#instruction-padding');
  padding.hidden=scope!=='rom';
  if(scope==='rom')padding.innerHTML=`<h3>Хвост ROM: ${catalog.paddingNops} слов NOP</h3>
    <p>После основной программы ROM дополнен ${catalog.paddingNops} словами <code>0x00000013</code> — это <code>nop</code>, псевдоним <code>addi zero, zero, 0</code>.
    Они <strong>не включены</strong> в число мнемоник активной прошивки и не были зарегистрированы среди 269 FETCH. Наличие данных в ROM не означает выполнение процессором.</p>`;
}
function openInstructionForEvent(){
  const t=current(),e=t?.decoded.events[state.currentIndex];
  if(!e||e.kind!=='FETCH')return;
  const name=disassemble(e.value,e.address).asm.split(' ')[0];
  $('#instruction-scope').value='selected';
  $('#instruction-search').value=name;
  switchView('instructions');
  toast(`Команда ${name}: открыт разбор реально наблюдённой выборки.`);
}
function goToInstructionTrace(e){
  const b=e.target?.closest?.('[data-jump-id]');
  if(!b)return;
  const t=getTrace(b.dataset.jumpId),index=Number(b.dataset.jumpIndex);
  if(!t||!Number.isSafeInteger(index)||index<0||index>=t.decoded.events.length)return;
  setTrace(t.id);switchView('explore');stepTo(index,true);
}

function bindEvents(){
  $$('.tab').forEach(b=>b.addEventListener('click',()=>switchView(b.dataset.tab)));
  $('#trace-select').addEventListener('change',e=>setTrace(e.target.value));
  $('#compare-left').addEventListener('change',e=>{state.compareLeft=e.target.value;renderComparison()});
  $('#compare-right').addEventListener('change',e=>{state.compareRight=e.target.value;renderComparison()});
  $('#instruction-scope').addEventListener('change',renderInstructionCatalog);
  $('#instruction-search').addEventListener('input',renderInstructionCatalog);
  $('#instruction-grid').addEventListener('click',goToInstructionTrace);
  btn('#inspect-instruction-btn',openInstructionForEvent);
  btn('#prev-btn',()=>stepTo(state.currentIndex-1,true));btn('#next-btn',()=>stepTo(state.currentIndex+1,true));
  btn('#play-btn',startPlay);$('#speed-select').addEventListener('change',()=>{if(state.playing){stopPlay();startPlay()}});
  $('#step-range').addEventListener('input',e=>stepTo(Number(e.target.value),true));
  btn('#import-trace-btn',()=>$('#import-trace-file').click());
  $('#import-trace-file').addEventListener('change',e=>void importFiles(e,'IMPORTED'));
  $('#rtl-file').addEventListener('change',e=>void importFiles(e,'RTL_FILE'));
  btn('#export-trace-btn',()=>{const t=current();if(t){saveBlob(`LAB03_${t.id.replace(/[^a-z0-9-_]/ig,'_')}.txt`,t.raw,'text/plain;charset=us-ascii');toast('Сырой T3-файл сохранён.')}});
  btn('#prefill-observations',fillObservations);btn('#export-worksheet',exportWorksheet);
  btn('#connect-btn',()=>void connect());btn('#capture-btn',()=>void captureLive());
  btn('#reread-btn',()=>void rereadLive());btn('#query-btn',()=>void queryLive());
  document.addEventListener('keydown',e=>{
    if(e.altKey||e.ctrlKey||e.metaKey||/INPUT|TEXTAREA|SELECT|BUTTON/.test(document.activeElement?.tagName||''))return;
    if($(`#view-explore`).classList.contains('hidden'))return;
    if(e.key==='ArrowLeft'){e.preventDefault();stepTo(state.currentIndex-1,true)}
    if(e.key==='ArrowRight'){e.preventDefault();stepTo(state.currentIndex+1,true)}
    if(e.key===' '){e.preventDefault();startPlay()}
  });
  window.addEventListener('pagehide',()=>{stopPlay();if(state.connected)void disconnect()});
}
async function init(){
  bindEvents();refreshSerialUi();
  try{
    const [romText,campaignText]=await Promise.all([fetchText('data/lab03_boot.hex'),fetchText('data/campaign.json')]);
    // Git for Windows may materialize text files as CRLF. Verify the canonical LF
    // ROM bytes only after strictly reversible CRLF→LF normalization.
    const canonicalRomText=romText.replace(/\r\n/g,'\n');
    const romDigest=await digest(new TextEncoder().encode(canonicalRomText));
    if(romDigest!==ROM_SHA256)throw new Error(`ROM SHA256 mismatch: ${romDigest}`);
    state.rom=parseRom(canonicalRomText);
    const campaign=JSON.parse(campaignText);
    if(campaign.romSha256!==ROM_SHA256||campaign.bitstreamSha256Declared!==BITSTREAM_DECLARED_SHA256||campaign.source!=='real-hardware-archive')throw new Error('Метаданные кампании не соответствуют зафиксированному эксперименту');
    if(!Array.isArray(campaign.boardCaptures)||campaign.boardCaptures.length!==12)throw new Error('Ожидалось 12 аппаратных захватов');
    const seenRun=new Set();let fetches=0;
    for(const capture of campaign.boardCaptures){
      if(seenRun.has(capture.run)||capture.status!=='PASS')throw new Error('Повтор номера запуска или ошибочный статус');
      seenRun.add(capture.run);
      const sha=await digest(new TextEncoder().encode(capture.trace));
      if(sha!==capture.rawSha256)throw new Error(`Контрольная сумма дампа #${capture.run} не совпала`);
      const t=addTrace({id:`board-${capture.run}`,label:`Захват №${String(capture.run).padStart(2,'0')} / LED ${capture.command}`,origin:'BOARD',raw:capture.trace,
        sha,run:capture.run,utc:capture.utc,select:capture.run===1});
      if(t.decoded.command!==capture.command)throw new Error('Команда в данных отличается от метаданных');
      fetches+=t.decoded.fetchCount;
    }
    if(fetches!==269||unique('command',campaign.boardCaptures).sort().join(',')!=='0,4')throw new Error('Счётчики архивной кампании расходятся с эталоном');
    state.campaign=campaign;
    renderInstructionCatalog();
    state.compareLeft='board-1';state.compareRight='board-7';
    refreshSelectors();renderTrace();renderComparison();
    $('#stat-fetch').textContent=String(fetches);$('#stat-captures').textContent=String(campaign.boardCaptures.length);
    $('#stat-writes').textContent=String(campaign.boardCaptures.length);
    toast('12 аппаратных трасс загружены, SHA-256 и ROM проверены.');
  }catch(e){
    $('#trace-meta').textContent=`Не удалось загрузить данные: ${e.message}`;
    notice(`Ошибка учебного архива: ${e.message}`,'error');toast(`Ошибка загрузки: ${e.message}`,true);
    console.error(e);
  }
}
void init();
