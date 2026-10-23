"use strict";
/*
 * PiKoSoL WebUSB Loader. SRAM ONLY. openFPGALoader supplied by
 * @yowasp/openfpgaloader (the WebUSB/WASM runtime used by trabucayre).
 * No JTAG commands for Flash / --flash / -f / --erase are exposed.
 */
const $=id=>document.getElementById(id);
const FW_SHA="6862c034715dbf557c93c8f8af8d8aa856ca8f4e62997660cea9740f3efda356";
const FW_URL="./firmware/picorv32_lab04_hdmi_nano9k.fs";
const RELEASE_URL="https://github.com/AIDevelopersMonster/Sipeed-FPGA/releases/download/pikosol-v0.2.0/picorv32_lab04_hdmi_nano9k.fs";
const ENGINE_URL="./vendor/bundle.js";
let device=null, firmware=null, loadedSha="", isVerified=false, busy=false, engine=null;
const logEl=$("log");
function log(message){const date=new Date();logEl.textContent+="["+date.toLocaleTimeString("ru-RU")+"] "+message+"\n";if(logEl.textContent.length>90000)logEl.textContent=logEl.textContent.slice(-80000);logEl.scrollTop=logEl.scrollHeight;}
function status(msg,type="neutral"){$("operation-status").textContent=msg;$("operation-status").className="notice "+type;}
function hashResult(msg,type="neutral"){$("hash-result").textContent=msg;$("hash-result").className="notice "+type;}
function metric(id,text,pass=null){const e=$(id);e.textContent=text;e.className=pass===true?"pass":pass===false?"fail":"";}
function ready(){ $("program").disabled=busy||!firmware||!device||(!isVerified&&!$("custom-confirm").checked);$("load-github").disabled=busy;$("connect-jtag").disabled=busy;$("input-file").disabled=busy;}
function hex(array){return [...new Uint8Array(array)].map(x=>x.toString(16).padStart(2,"0")).join("")}
async function acceptFile(bytes,name){
  const buffer=bytes instanceof Uint8Array?bytes:new Uint8Array(bytes);
  if(!name.toLowerCase().endsWith(".fs"))throw new Error("Нужен файл Gowin .fs");
  if(buffer.length<10000||buffer.length>12*1024*1024)throw new Error("Размер .fs вне безопасного диапазона");
  if(!crypto.subtle)throw new Error("SHA-256 требует безопасного HTTPS-соединения");
  const digest=hex(await crypto.subtle.digest("SHA-256",buffer));
  firmware=buffer;loadedSha=digest;isVerified=digest.toLowerCase()===FW_SHA;
  $("firmware-name").textContent=name;$("firmware-size").textContent=(buffer.length/1024/1024).toFixed(2)+" MiB";
  $("actual-sha").textContent=digest.toUpperCase();
  $("custom-confirm").checked=false;$("custom-confirm").disabled=isVerified;
  if(isVerified){hashResult("✓ SHA-256 совпадает с аппаратно проверенной PiKoSoL v0.2.0","ok");status("Прошивка прошла SHA-256 проверку. Выберите JTAG Debugger.","neutral");log("Файл "+name+": SHA-256 PASS ("+buffer.length+" B)")}
  else{hashResult("⚠ SHA-256 отличается от проверенного релиза. Пользовательский bitstream требует отдельного подтверждения.","error");status("Непроверенная прошивка; подтвердите использование чужого .fs отдельно.","error");log("Файл "+name+": SHA-256 mismatch "+digest)}
  ready()
}
$("input-file").addEventListener("change",async e=>{
  const file=e.target.files?.[0];if(!file)return;
  try{await acceptFile(new Uint8Array(await file.arrayBuffer()),file.name)}catch(err){firmware=null;ready();status(err.message,"error")}
});
$("custom-confirm").addEventListener("change",ready);
$("load-github").addEventListener("click",async()=>{
  status("Получение проверенного .fs с нашего GitHub Pages...");log("Получаем прошивку "+FW_URL);
  try{
    const response=await fetch(FW_URL,{mode:"cors",redirect:"follow",cache:"no-store"});
    if(!response.ok)throw new Error("HTTP "+response.status);
    await acceptFile(new Uint8Array(await response.arrayBuffer()),"picorv32_lab04_hdmi_nano9k.fs");
  }catch(e){
    status("Автоматическая загрузка с GitHub Pages недоступна. Скачайте .fs из Releases и выберите его вручную. "+e.message,"error");
    log("GitHub Pages firmware fetch: "+e.message+"; local file fallback available");
  }
});
async function connect(){
  if(!navigator.usb){status("WebUSB недоступен; нужен Chrome/Edge на HTTPS.", "error");return;}
  try{
    device=await navigator.usb.requestDevice({filters:[{vendorId:0x0403,productId:0x6010}]});
    metric("jtag-status","ВЫБРАН ✓",true);
    $("device-message").textContent="USB-устройство: "+device.productName+" · VID 0403 / PID 6010. Разрешение получено; открытие интерфейса будет проверено при запуске openFPGALoader.";
    status("USB-устройство выбрано. Это ещё не подтверждает открытие JTAG.","neutral");
    log("User selected USB device: "+device.productName+" (0403:6010)");
  }catch(e){device=null;metric("jtag-status","НЕ ПОДКЛЮЧЁН");status("Выбор USB не выполнен: "+e.message,"error");log("WebUSB requestDevice: "+e.message)}
  ready()
}
$("connect-jtag").addEventListener("click",connect);
navigator.usb?.addEventListener("disconnect",event=>{if(event.device===device){device=null;metric("jtag-status","ОТКЛЮЧЕНО",false);ready();status("USB-JTAG отключён.","error");log("USB disconnected")}});
async function resolveEngine(){
  if(engine)return engine;
  metric("engine-status","ЗАГРУЗКА");
  log("Импорт WASM WebUSB runtime: "+ENGINE_URL);
  // Dynamic import on direct user click, no third-party web page/iframe.
  const module=await import(ENGINE_URL);
  if(typeof module.runOpenFPGALoader!=="function")throw new Error("Модуль не экспортирует runOpenFPGALoader");
  engine=module.runOpenFPGALoader;
  metric("engine-status","ЗАГРУЖЕН ✓",true);
  return engine;
}
async function program(){
  if(busy||!firmware||!device||(!isVerified&&!$("custom-confirm").checked))return;
  if(!navigator.usb){status("Нет WebUSB.","error");return;}
  if(!window.crossOriginIsolated){status("Нет изоляции SharedArrayBuffer (COOP/COEP); обновите страницу после установки service worker. На GitHub Pages первый запуск может автоматически перезагрузиться.","error");log("crossOriginIsolated=false; abort");return;}
  busy=true;ready();
  const args=["-c","ft2232","-b","tangnano9k","pikosol.fs"];
  const begin=performance.now();
  status("Программирование SRAM... Не отключайте плату.");$("command-preview").textContent="openFPGALoader "+args.join(" ");
  log("START openFPGALoader "+args.join(" "));log("USB permissions: "+device.productName+"; board tangnano9k; destination SRAM");
  try{
    const run=await resolveEngine();
    await run(args,{"pikosol.fs":firmware},{
      stdout:message=>{if(message)log(new TextDecoder().decode(message).trimEnd())},
      stderr:message=>{if(message)log(new TextDecoder().decode(message).trimEnd())}
    });
    status("Программирование завершилось с кодом 0. Проверьте HDMI и затем откройте Web Serial терминал.","ok");
    log("OPENFPGALOADER EXIT 0 · "+Math.round(performance.now()-begin)+" ms · SRAM ONLY");
    metric("jtag-status","ОПЕРАЦИЯ PASS",true);
  }catch(e){
    status("Ошибка openFPGALoader: "+e.message+". Смотрите подробности в журнале.","error");
    log("OPENFPGALOADER ERROR: "+e.message);
  }finally{busy=false;ready()}
}
$("program").addEventListener("click",program);
$("clear-log").addEventListener("click",()=>{logEl.textContent=""});
$("save-log").addEventListener("click",()=>{const url=URL.createObjectURL(new Blob([logEl.textContent],{type:"text/plain;charset=utf-8"}));const a=document.createElement("a");a.href=url;a.download="PiKoSoL_WebUSB_log.txt";a.click();setTimeout(()=>URL.revokeObjectURL(url),300)});
$("release-download").href=RELEASE_URL;
const secure=window.isSecureContext&&"usb" in navigator;
metric("usb-support",secure?"ДОСТУПЕН ✓":"НЕДОСТУПЕН",secure);
metric("isolation-status",window.crossOriginIsolated?"ГОТОВО ✓":"НЕТ COOP/COEP",window.crossOriginIsolated);
log("WebUSB: "+secure+"; crossOriginIsolated: "+window.crossOriginIsolated);
if(!secure)status("Требуется Chrome/Edge с WebUSB через HTTPS.","error");
else if(!window.crossOriginIsolated)status("Service worker подготавливает COOP/COEP. Возможно, страницу нужно обновить.","neutral");
else status("WebUSB и COOP/COEP готовы. Выберите файл .fs и JTAG Debugger.","neutral");
ready();
