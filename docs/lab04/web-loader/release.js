"use strict";
/* PiKoSoL Web Lab: pinned images + SRAM WebUSB + real UART Web Serial.
 * No factory image claim, no JTAG erase / flash operations, no SD write.
 */
const $=id=>document.getElementById(id);
const PROFILES=Object.freeze({
  v020:{name:"PiKoSoL v0.2.0",file:"picorv32_lab04_hdmi_nano9k.fs",sha:"6862c034715dbf557c93c8f8af8d8aa856ca8f4e62997660cea9740f3efda356",url:"./firmware/picorv32_lab04_hdmi_nano9k.fs",source:"https://github.com/AIDevelopersMonster/Sipeed-FPGA/releases/tag/pikosol-v0.2.0",tested:true,description:"Аппаратно проверены CPU, UART, HDMI и графика. Команд FAT32 нет."},
  sd08:{name:"PiKoSoL SD-08",file:"sd08_pikosol_fat32_readonly.fs",sha:"37ddb2fb7d20f7e4ad610dad4160dc98ed38e5197221b62644642d32c8c09f4b",url:"./firmware/sd08_pikosol_fat32_readonly.fs",source:"https://github.com/AIDevelopersMonster/Sipeed-FPGA/releases/tag/pikosol-sd08-fat32-ro",tested:true,description:"25.10.2026 аппаратный PASS: FS, DIR, TYPE PIKO.TXT, FAT32 8.3 read-only. Если файл ещё не опубликован на Pages, выберите локальный .fs."},
  sipeed:{name:"Sipeed PicoTiny (example)",file:"picotiny.fs",sha:"5a9558e4b0ad2dad2812ad90757bfe6a27f6367992bf536a3304bc948a41659e",url:null,source:"https://github.com/sipeed/TangNano-9K-example/blob/main/picotiny/picotiny.fs",tested:false,description:"Официальный пример Sipeed, не подтверждён как заводской образ. Может требовать отдельной прошивки в SPI Flash; только ручная загрузка .fs и явное подтверждение."},
  sipeed_hdmi:{name:"Sipeed HDMI (example)",file:"picotiny.fs",sha:"830bd2affecee53ce344fdb518ddfea70ca22655d0cb0595af1de921098d339f",url:null,source:"https://github.com/sipeed/TangNano-9K-example/blob/main/hdmi/picotiny.fs",tested:false,description:"Официальный HDMI-пример Sipeed, не подтверждён как заводской образ. Только ручная загрузка .fs и явное подтверждение."}
});
let active=PROFILES.v020;
let firmware=null,verified=false,jtag=null,jtagBusy=false,serialPort=null,serialReader=null,serialTask=null,serialClosing=false;
let serialConnected=false,serialQueue=Promise.resolve(),terminalRaw="";
const encoder=new TextEncoder(),decoder=new TextDecoder("ascii");
function show(id,message,type="neutral"){$(id).textContent=message;$(id).className="notice"+(type==="neutral"?"":" "+type);}
function journal(message){const el=$("program-log");el.textContent+="\n"+message;if(el.textContent.length>70000)el.textContent=el.textContent.slice(-60000);el.scrollTop=el.scrollHeight;}
function append(text){terminalRaw+=text;if(terminalRaw.length>55000)terminalRaw=terminalRaw.slice(-55000);
  $("terminal").textContent=terminalRaw.replace(/\r\n/g,"\n").replace(/\r/g,"\n").replace(/[\x0e\x0f]/g,"").replace(/\f/g,"\n[HDMI CLS]\n").replace(/[^\x09\x0a\x20-\x7e]/g,"");
  $("terminal").scrollTop=$("terminal").scrollHeight;}
function updateButtons(){
  $("fetch").disabled=jtagBusy||!active.url;
  $("connect-jtag").disabled=jtagBusy;
  $("program").disabled=jtagBusy||!jtag||!firmware||!verified||(!active.tested&&!$("reference-confirm").checked);
  $("profile").disabled=jtagBusy;$("local-file").disabled=jtagBusy;
  $("reference-confirm").disabled=!firmware||!verified||active.tested||jtagBusy;
  $("connect-serial").disabled=!!serialPort;
  $("disconnect-serial").disabled=!serialPort;
  for(const el of document.querySelectorAll(".uart-command"))el.disabled=!serialConnected;
  $("send-type").disabled=!serialConnected;
}
function selectProfile(){
  active=PROFILES[$("profile").value]||PROFILES.v020;
  firmware=null;verified=false;$("reference-confirm").checked=false;
  $("file-name").textContent="Файл не выбран";$("file-hash").textContent="SHA-256: ожидаем файл";
  $("profile-note").textContent=active.description;
  $("profile-source").href=active.source;
  $("profile-source").textContent=active.url?"Открыть страницу релиза":"Открыть оригинальный пример Sipeed";
  show("verify-result","Для программирования выберите файл с точным SHA-256 профиля.");
  updateButtons();
}
function toHex(bytes){return [...new Uint8Array(bytes)].map(b=>b.toString(16).padStart(2,"0")).join("");}
async function acceptFile(data,name){
  const bytes=data instanceof Uint8Array?data:new Uint8Array(data);
  if(!name.toLowerCase().endsWith(".fs"))throw Error("Ожидался файл .fs");
  if(bytes.length<10000||bytes.length>12*1024*1024)throw Error("Недопустимый размер .fs");
  if(!crypto.subtle)throw Error("SHA-256 требует HTTPS");
  const hash=toHex(await crypto.subtle.digest("SHA-256",bytes));
  firmware=bytes;verified=hash===active.sha;$("reference-confirm").checked=false;
  $("file-name").textContent=name+" · "+bytes.length+" bytes";
  $("file-hash").textContent="SHA-256: "+hash.toUpperCase();
  if(verified){
    show("verify-result",active.tested?"SHA-256 PASS. Образ проходил аппаратные испытания.":"SHA-256 совпадает с примером Sipeed, но заводское происхождение и аппаратная пригодность не доказаны.",active.tested?"ok":"neutral");
    journal("SHA-256 PASS: "+active.name+" ("+bytes.length+" bytes)");
  }else{
    firmware=null;
    show("verify-result","SHA-256 НЕ совпадает с профилем. Программирование заблокировано.","error");
    journal("SHA-256 MISMATCH: "+name+" => "+hash);
  }
  updateButtons();
}
$("profile").addEventListener("change",selectProfile);
$("local-file").addEventListener("change",async ev=>{
  const file=ev.target.files&&ev.target.files[0];if(!file)return;
  try{await acceptFile(new Uint8Array(await file.arrayBuffer()),file.name);}catch(err){firmware=null;verified=false;show("verify-result",err.message,"error");updateButtons();}
});
$("fetch").addEventListener("click",async()=>{
  if(!active.url)return;const url=active.url,file=active.file;
  show("verify-result","Загрузка образа с GitHub Pages...");
  try{const r=await fetch(url,{cache:"no-store",mode:"cors"});if(!r.ok)throw Error("HTTP "+r.status);
    await acceptFile(new Uint8Array(await r.arrayBuffer()),file);
  }catch(err){firmware=null;verified=false;updateButtons();show("verify-result","Образ ещё не опубликован на Pages или недоступен: "+err.message+". Выберите локальный проверенный .fs.","error");}
});
$("reference-confirm").addEventListener("change",updateButtons);
$("connect-jtag").addEventListener("click",async()=>{
  if(!navigator.usb){show("program-status","WebUSB отсутствует; нужен Chrome или Edge на HTTPS.","error");return;}
  try{jtag=await navigator.usb.requestDevice({filters:[{vendorId:0x0403,productId:0x6010}]});
    show("program-status","Выбрано "+(jtag.productName||"FT2232")+"; JTAG ещё не проверен.");
    journal("JTAG device selected: 0403:6010");
  }catch(err){jtag=null;show("program-status",err.message,"error");}
  updateButtons();
});
navigator.usb?.addEventListener("disconnect",ev=>{if(ev.device===jtag){jtag=null;updateButtons();show("program-status","JTAG отключён.","error");}});
$("program").addEventListener("click",async()=>{
  if(jtagBusy||!jtag||!firmware||!verified||(!active.tested&&!$("reference-confirm").checked))return;
  if(!window.crossOriginIsolated){show("program-status","COOP/COEP ещё не готов; обновите страницу после установки service worker.","error");return;}
  jtagBusy=true;updateButtons();
  const args=["-c","ft2232","-b","tangnano9k","pikosol.fs"];
  journal("SRAM START: openFPGALoader "+args.join(" "));
  show("program-status","Загрузка в SRAM; не отключайте плату.");
  try{
    const module=await import("./vendor/bundle.js");
    if(typeof module.runOpenFPGALoader!=="function")throw Error("Нет runOpenFPGALoader");
    await module.runOpenFPGALoader(args,{"pikosol.fs":firmware},{
      stdout:chunk=>{if(chunk)journal(decoder.decode(chunk).trimEnd());},
      stderr:chunk=>{if(chunk)journal(decoder.decode(chunk).trimEnd());}
    });
    journal("SRAM DONE: openFPGALoader exit 0");
    show("program-status","SRAM PASS по коду завершения загрузчика. Проверьте HDMI и реальный UART.","ok");
  }catch(err){journal("SRAM ERROR: "+err.message);show("program-status","Ошибка: "+err.message,"error");}
  finally{jtagBusy=false;updateButtons();}
});
async function receive(port){
  try{
    const reader=port.readable.getReader();serialReader=reader;
    try{while(!serialClosing){const part=await reader.read();if(part.done)break;
      if(part.value)append(decoder.decode(part.value,{stream:true}));}}
    finally{reader.releaseLock();serialReader=null;}
    if(!serialClosing)show("serial-status","Приём UART завершился. Отключите и заново подключите COM.","error");
  }catch(err){if(!serialClosing)show("serial-status","UART: "+err.message,"error");}
  if(!serialClosing){serialConnected=false;updateButtons();}
}
$("connect-serial").addEventListener("click",async()=>{
  if(serialPort)return;
  if(!window.isSecureContext||!("serial" in navigator)){show("serial-status","Web Serial требует Chrome/Edge на HTTPS.","error");return;}
  let port=null;
  try{port=await navigator.serial.requestPort();
    await port.open({baudRate:115200,dataBits:8,stopBits:1,parity:"none",flowControl:"none"});
    serialPort=port;serialConnected=true;serialClosing=false;terminalRaw="";
    append("[Web Serial / 115200 8N1]\n");
    serialTask=receive(port);
    show("serial-status","COM подключён. Команды исполняет физическая FPGA.","ok");
    updateButtons();
  }catch(err){show("serial-status",err.message,"error");if(port){try{await port.close();}catch{}}}
});
async function closeSerial(){
  if(!serialPort)return;
  serialClosing=true;serialConnected=false;updateButtons();
  try{if(serialReader)await serialReader.cancel();}catch{}
  try{if(serialTask)await serialTask;}catch{}
  try{await serialPort.close();}catch(err){show("serial-status","UART close: "+err.message,"error");}
  serialPort=null;serialTask=null;serialReader=null;serialClosing=false;
  updateButtons();show("serial-status","COM закрыт.");
}
$("disconnect-serial").addEventListener("click",()=>void closeSerial());
function send(command){
  if(!serialConnected||!serialPort)return;
  if(!/^[\x20-\x7e]{1,47}$/.test(command)){show("serial-status","Неверный формат UART-команды.","error");return;}
  serialQueue=serialQueue.catch(()=>{}).then(async()=>{
    if(!serialConnected||!serialPort)return;
    const writer=serialPort.writable.getWriter();
    try{await writer.write(encoder.encode(command+"\r"));}
    finally{writer.releaseLock();}
  }).catch(err=>show("serial-status","UART write: "+err.message,"error"));
}
document.querySelectorAll(".uart-command").forEach(button=>button.addEventListener("click",()=>send(button.dataset.command)));
$("send-type").addEventListener("click",()=>{
  const name=$("filename").value.trim().toUpperCase();
  if(!/^[A-Z0-9_-]{1,8}\.[A-Z0-9_-]{1,3}$/.test(name)){
    show("serial-status","Введите имя FAT32 8.3, например PIKO.TXT.","error");return;
  }
  send("TYPE "+name);
});
$("clear-terminal").addEventListener("click",()=>{terminalRaw="";$("terminal").textContent="";});
window.addEventListener("pagehide",()=>{if(serialPort)void closeSerial();});
$("usb-support").textContent="WebUSB: "+(window.isSecureContext&&"usb" in navigator?"доступен":"недоступен");
$("serial-support").textContent="Web Serial: "+(window.isSecureContext&&"serial" in navigator?"доступен":"недоступен");
$("isolation").textContent="WASM COOP/COEP: "+(window.crossOriginIsolated?"готово":"ожидает перезагрузки");
selectProfile();