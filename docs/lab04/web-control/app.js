"use strict";
const $ = id=>document.getElementById(id);
const state={port:null,reader:null,reading:null,closing:false,bytesRx:0,bytesTx:0,mask:null,mode:"unknown",live:false,object:null,connected:false,confirmed:false,raw:"",lines:[],rxLine:"",pendingCR:false,sendQueue:Promise.resolve(),commandHistory:[],historyIndex:0};
const ENC=new TextEncoder();
function notice(s,error=false){$("notice").textContent=s;$("notice").classList.toggle("error",error)}
function setEnabled(on){document.querySelectorAll(".requires-link").forEach(el=>el.disabled=!on);$("btn-connect").disabled=on;$("btn-disconnect").disabled=!on;$("btn-send").disabled=!on;$("command-input").disabled=!on;$("btn-test").disabled=!on;$("btn-recall").disabled=!on;$("btn-live-exit").disabled=!on;$("port-state").textContent=on?"ОТКРЫТ 115200":"ОТКЛЮЧЕНО";$("status-text").textContent=on?"UART подключён":"Не подключено";$("status-led").classList.toggle("connected",on)}
function setMode(mode){state.mode=mode;$("mode-indicator").textContent=mode==="term"?"TERM":mode==="gfx"?"GFX":"НЕИЗВЕСТЕН";if(mode==="term"){state.live=false;$("live-status").textContent="Режим: строковый ввод"}}
function resetObserved(){state.mask=null;state.confirmed=false;state.object=null;state.rxLine="";state.pendingCR=false;state.live=false;state.mode="unknown";$("device-confirmed").textContent="НЕ ПРОВЕРЕН";$("led-mask").textContent="—";$("obj-a").classList.remove("active");$("obj-b").classList.remove("active");document.querySelectorAll("[data-led]").forEach(x=>x.classList.remove("on"));setMode("unknown")}
function setMask(m){m=m&63;state.mask=m;$("led-mask").textContent="0x"+m.toString(16).padStart(2,"0").toUpperCase();document.querySelectorAll("[data-led]").forEach(el=>el.classList.toggle("on",Boolean(m&(1<<Number(el.dataset.led)))))}
function parseLine(line){
  const s=line.trim();
  if(!s)return;
  if(s.includes("PiKoSoL LAB-04")){state.confirmed=true;$("device-confirmed").textContent="PiKoSoL ✓";notice("PiKoSoL отвечает по реальному UART — связь подтверждена.")}
  const m=s.match(/^M=([0-9A-Fa-f]{2})$/);if(m){setMask(parseInt(m[1],16));state.confirmed=true;$("device-confirmed").textContent="MMIO ✓";notice("Получен ответ PicoRV32: маска LED считана из FPGA.")}
  const n=s.match(/^([CL])=([0-6])$/);if(n){const i=Number(n[2]);setMask(n[1]==="C"?(1<<i)-1:1<<(i-1));state.confirmed=true;$("device-confirmed").textContent="MMIO ✓"}
  if(s.includes("MODE: GRAPHICS"))setMode("gfx");
  if(s.includes("MODE: TERMINAL"))setMode("term");
  if(s.includes("LIVE KEYS:")){state.live=true;$("live-status").textContent="Режим: KEYS (без Enter)"}
}
function processText(text){
  for(const ch of text){
    if(ch==="\r"){parseLine(state.rxLine);state.rxLine="";state.pendingCR=true;}
    else if(ch==="\n"){if(!state.pendingCR)parseLine(state.rxLine);state.rxLine="";state.pendingCR=false}
    else if(ch==="\b"){state.rxLine=state.rxLine.slice(0,-1);state.pendingCR=false}
    else if(ch==="\f"){state.pendingCR=false;state.rxLine=""}
    else if(ch==="\x0e"){setMode("term")}
    else if(ch==="\x0f"){setMode("gfx")}
    else if(ch>=" "&&ch<="\x7e"){state.rxLine+=ch;if(state.rxLine.length>256)state.rxLine=state.rxLine.slice(-256);state.pendingCR=false}
  }
}
const MAX_CHARS=60000;
function appendTerminal(text){
  const pre=$("terminal-output");
  state.raw+=text;
  if(state.raw.length>MAX_CHARS)state.raw=state.raw.slice(-MAX_CHARS);
  // Treat CRLF as newline, lone CR as newline, form-feed as a marker.
  const display=state.raw.replace(/\r\n/g,"\n").replace(/\r/g,"\n").replace(/\x0e/g,"").replace(/\x0f/g,"").replace(/\f/g,"\n[HDMI CLS]\n").replace(/\x07/g,"[BEL]").replace(/\x08 \x08/g,"[BS]").replace(/[\x00-\x06\x0b\x10-\x1f\x7f]/g,"");
  pre.textContent=display;
  $("terminal-scroll").scrollTop=$("terminal-scroll").scrollHeight;
}
function updateBytes(){ $("rx-count").textContent=state.bytesRx+" B";$("tx-count").textContent=state.bytesTx+" B"}
async function readLoop(port){
  const decoder=new TextDecoder("ascii");
  try{
    while(!state.closing&&port.readable){
      const reader=port.readable.getReader();state.reader=reader;
      try{
        while(!state.closing){
          const {value,done}=await reader.read();
          if(done)break;
          if(!value)continue;
          state.bytesRx+=value.byteLength;updateBytes();
          const text=decoder.decode(value,{stream:true});processText(text);appendTerminal(text);
        }
      }finally{reader.releaseLock();if(state.reader===reader)state.reader=null}
      if(!state.closing)break;
    }
  }catch(e){if(!state.closing)notice("Приём UART: "+e.message,true)}
  finally{if(!state.closing)await disconnect(true)}
}
async function connect(){
  if(!window.isSecureContext||!("serial" in navigator)){notice("Web Serial недоступен. Откройте страницу через HTTPS в Chrome/Edge.",true);return}
  if(state.connected)return;
  let port;
  try{
    port=await navigator.serial.requestPort();
    await port.open({baudRate:115200,dataBits:8,stopBits:1,parity:"none",flowControl:"none"});
    state.port=port;state.connected=true;state.closing=false;resetObserved();setEnabled(true);
    const info=port.getInfo?.()||{};$("port-label").textContent="Web Serial · VID "+(info.usbVendorId??"?").toString(16)+" · PID "+(info.usbProductId??"?").toString(16);
    notice("Порт открыт. Нажмите «Проверить PicoRV32» для подтверждения настоящего UART.");
    appendTerminal("\n[WEB SERIAL CONNECTED · 115200 8N1]\n");
    state.reading=readLoop(port);
  }catch(e){notice("Подключение не состоялось: "+e.message,true);if(port&&!state.connected){try{await port.close()}catch{}}}
}
async function disconnect(fromReader=false){
  if(!state.port)return;
  state.closing=true;state.connected=false;setEnabled(false);resetObserved();
  const port=state.port;state.port=null;
  try{if(!fromReader&&state.reader){await state.reader.cancel();if(state.reading)await state.reading}}catch(e){console.warn(e)}
  try{await port.close()}catch(e){console.warn("Serial close:",e)}
  appendTerminal("\n[WEB SERIAL DISCONNECTED]\n");notice("COM-порт закрыт.");
}
function queueBytes(bytes){
  if(!state.connected||!state.port){notice("Сначала подключите COM.",true);return Promise.resolve(false)}
  state.sendQueue=state.sendQueue.catch(()=>{}).then(async()=>{
    if(!state.connected||!state.port)return false;
    const writer=state.port.writable.getWriter();
    try{await writer.write(bytes);state.bytesTx+=bytes.length;updateBytes();return true}
    finally{writer.releaseLock()}
  });
  return state.sendQueue.catch(e=>{notice("Ошибка передачи: "+e.message,true);return false});
}
async function sendLine(cmd){
  if(state.live){notice("Активен KEYS. Сначала вернитесь в TERM клавишей T.",true);return false}
  if(!cmd||!cmd.trim())return false;
  if(!/^[\x20-\x7e]{1,47}$/.test(cmd)){notice("Допустимо не более 47 печатных ASCII-символов.",true);return false}
  state.commandHistory.push(cmd);if(state.commandHistory.length>100)state.commandHistory.shift();state.historyIndex=state.commandHistory.length;
  return queueBytes(ENC.encode(cmd+"\r"));
}
function sendCommand(cmd){void sendLine(cmd)}
function sendLive(raw){
  if(!state.live){notice("Сначала GFX, затем KEYS.",true);return}
  if(!/^[ijklABRGUWXOKtT+-]$/.test(raw)){notice("Недопустимая клавиша KEYS.",true);return}
  void queueBytes(ENC.encode(raw))
}
function graphicsCommand(kind,value){
  if(state.live){
    const single=kind==="obj"?value:kind==="move"?value.toLowerCase():kind==="color"?value:value;
    sendLive(single);
    return;
  }
  if(state.mode!=="gfx"){notice("Сначала нажмите GFX.",true);return}
  sendCommand(kind==="obj"?"OBJ "+value:kind==="move"?"MOVE "+value:kind==="color"?"COLOR "+value:"SIZE "+value)
}
$("btn-connect").addEventListener("click",connect);
$("btn-disconnect").addEventListener("click",()=>void disconnect());
$("btn-test").addEventListener("click",async()=>{await sendLine("INFO");await sendLine("LED ?")});
$("command-form").addEventListener("submit",ev=>{ev.preventDefault();const value=$("command-input").value;sendCommand(value);$("command-input").value=""});
$("command-input").addEventListener("keydown",e=>{if(e.key==="ArrowUp"){e.preventDefault();if(state.historyIndex>0)$("command-input").value=state.commandHistory[--state.historyIndex]}else if(e.key==="ArrowDown"){e.preventDefault();if(state.historyIndex<state.commandHistory.length-1)$("command-input").value=state.commandHistory[++state.historyIndex];else{state.historyIndex=state.commandHistory.length;$("command-input").value=""}}});
document.querySelectorAll("[data-cmd]").forEach(b=>b.addEventListener("click",()=>{const cmd=b.dataset.cmd;if(cmd==="KEYS"){if(state.mode!=="gfx"){notice("Сначала переключитесь в GFX.",true);return}sendCommand(cmd)}else sendCommand(cmd)}));
document.querySelectorAll("[data-obj]").forEach(b=>b.addEventListener("click",()=>{graphicsCommand("obj",b.dataset.obj);$("obj-a").classList.toggle("active",b.dataset.obj==="A");$("obj-b").classList.toggle("active",b.dataset.obj==="B")}));
document.querySelectorAll("[data-move]").forEach(b=>b.addEventListener("click",()=>graphicsCommand("move",b.dataset.move)));
document.querySelectorAll("[data-color]").forEach(b=>b.addEventListener("click",()=>graphicsCommand("color",b.dataset.color)));
document.querySelectorAll("[data-size]").forEach(b=>b.addEventListener("click",()=>graphicsCommand("size",b.dataset.size)));
$("btn-live-exit").addEventListener("click",()=>{if(state.live)sendLive("T");else notice("Режим KEYS не подтверждён.")});
$("raw-zone").addEventListener("keydown",ev=>{if(!state.live)return;const key=ev.key;if(key==="ArrowLeft"||key==="ArrowRight"||key==="ArrowUp"||key==="ArrowDown"){ev.preventDefault();sendLive(({ArrowLeft:"j",ArrowRight:"l",ArrowUp:"i",ArrowDown:"k"})[key]);return}if(/^[ijklABRGUWXOKtT+-]$/.test(key)){ev.preventDefault();sendLive(key)}});
$("btn-recall").addEventListener("click",()=>{if(state.live){notice("Сначала T для выхода из KEYS.",true);return}void queueBytes(Uint8Array.of(0x10,0x0d))});
$("btn-terminal-clear").addEventListener("click",()=>{state.raw="";$("terminal-output").textContent="";notice("Очищено только окно браузера. HDMI не затронут.")});
$("btn-copy-log").addEventListener("click",async()=>{try{await navigator.clipboard.writeText(state.raw);notice("Журнал скопирован.")}catch(e){notice("Не удалось скопировать: "+e.message,true)}});
$("btn-save-log").addEventListener("click",()=>{const blob=new Blob([state.raw],{type:"text/plain;charset=utf-8"});const url=URL.createObjectURL(blob);const a=document.createElement("a");a.href=url;a.download="PiKoSoL_UART_log.txt";a.click();setTimeout(()=>URL.revokeObjectURL(url),500)});
window.addEventListener("pagehide",()=>{if(state.port)void disconnect()});
if(!("serial" in navigator)||!window.isSecureContext){notice("Для подключения UART требуется Chrome/Edge и защищённая HTTPS-страница.",true)}
