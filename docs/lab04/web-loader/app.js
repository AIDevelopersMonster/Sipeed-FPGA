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
// Version selector changes only the verified bitstream, NOT the JTAG/WASM runtime.
const PROFILES=Object.freeze({
  v020:Object.freeze({name:"PiKoSoL v0.2.0",sha:FW_SHA,url:FW_URL,filename:"picorv32_lab04_hdmi_nano9k.fs",release:RELEASE_URL,notes:"Аппаратно проверенная базовая версия: PicoRV32, HDMI, UART, GFX. Команд FAT32 нет."}),
  sd08:Object.freeze({name:"PiKoSoL SD-08 · FAT32",sha:"37ddb2fb7d20f7e4ad610dad4160dc98ed38e5197221b62644642d32c8c09f4b",url:"./firmware/sd08_pikosol_fat32_readonly.fs",filename:"sd08_pikosol_fat32_readonly.fs",release:"https://github.com/AIDevelopersMonster/Sipeed-FPGA/releases/download/pikosol-sd08-fat32-ro/sd08_pikosol_fat32_readonly.fs",notes:"25.10.2026 HARDWARE PASS: FS, DIR, TYPE PIKO.TXT. Только FAT32 8.3 read-only. Автозагрузка станет доступна после публикации файла."}),
  picotiny:Object.freeze({name:"Sipeed PicoTiny (сторонняя)",sha:null,url:null,filename:"picotiny.fs",release:null,notes:"Эксперимент восстановления: выберите локальный picotiny.fs; это не подтверждённый заводской PicoSoc. Только SRAM."})
});
let activeProfile=PROFILES.v020;
let device=null, firmware=null, loadedSha="", isVerified=false, busy=false, engine=null, hashFailed=false;
const logEl=$("log");
function log(message){const date=new Date();logEl.textContent+="["+date.toLocaleTimeString("ru-RU")+"] "+message+"\n";if(logEl.textContent.length>90000)logEl.textContent=logEl.textContent.slice(-80000);logEl.scrollTop=logEl.scrollHeight;}
function status(msg,type="neutral"){$("operation-status").textContent=msg;$("operation-status").className="notice "+type;}
function hashResult(msg,type="neutral"){$("hash-result").textContent=msg;$("hash-result").className="notice "+type;}
function metric(id,text,pass=null){const e=$(id);e.textContent=text;e.className=pass===true?"pass":pass===false?"fail":"";}
function ready(){ $("program").disabled=busy||!firmware||!device||hashFailed;$("load-github").disabled=busy||!activeProfile.url;$("connect-jtag").disabled=busy;$("input-file").disabled=busy;$("hash-file").disabled=busy;$("firmware-profile").disabled=busy;}
function selectFirmwareProfile(){
  activeProfile=PROFILES[$("firmware-profile").value]||PROFILES.v020;
  firmware=null;loadedSha="";isVerified=false;hashFailed=false;
  $("input-file").value="";$("firmware-name").textContent="Нет файла";
  $("firmware-size").textContent="—";$("actual-sha").textContent="Файл ещё не выбран";$("expected-sha").textContent="Не выбран";$("hash-comparison").textContent="Для локального файла можно выбрать отдельный SHA256SUMS.txt. Без него хеш вычисляется, но подлинность не подтверждается.";
  $("profile-name").textContent=activeProfile.name;$("profile-notes").textContent=activeProfile.notes;
  $("release-download").hidden=!activeProfile.release;if(activeProfile.release)$("release-download").href=activeProfile.release;
  $("hash-file").value="";
  hashResult("Контрольная сумма не проверена.");ready();
}
function hex(array){return [...new Uint8Array(array)].map(x=>x.toString(16).padStart(2,"0")).join("")}
function manifestHash(text,name){
  const hashes=[];
  for(const line of text.split(/\r?\n/)){
    const m=line.trim().match(/^([a-fA-F0-9]{64})(?:\s+\*?(.+))?$/);
    if(m && (!m[2] || m[2].trim().replace(/^\.\//,"")===name)) hashes.push(m[1].toLowerCase());
  }
  return hashes.length===1?hashes[0]:null;
}
async function acceptFile(bytes,name,expected=null,source="local"){
  const buffer=bytes instanceof Uint8Array?bytes:new Uint8Array(bytes);
  if(!name.toLowerCase().endsWith(".fs"))throw new Error("Нужен файл Gowin .fs");
  if(buffer.length<10000||buffer.length>12*1024*1024)throw new Error("Размер .fs вне допустимого диапазона");
  const digest=hex(await crypto.subtle.digest("SHA-256",buffer));
  firmware=buffer;loadedSha=digest;hashFailed=!!expected && digest!==expected.toLowerCase();
  isVerified=!!expected && !hashFailed;
  $("firmware-name").textContent=name;$("firmware-size").textContent=(buffer.length/1048576).toFixed(2)+" MiB";
  $("actual-sha").textContent=digest.toUpperCase();
  $("expected-sha").textContent=expected?expected.toUpperCase():"Эталон отсутствует";
  $("hash-comparison").textContent="Файл: "+name+"; эталон: "+(source==="local"?"выбранный файл SHA-256 / без эталона":source)+".";
  if(hashFailed){
    firmware=null;hashResult("SHA-256 FAIL: файл не совпадает со своим эталоном. Загрузка запрещена.","error");status("Проверка SHA-256 не пройдена.","error");
  }else if(isVerified){
    hashResult("SHA-256 PASS: хеш файла совпадает с его эталоном.","ok");status("Файл проверен; можно загрузить в SRAM.","ok");
  }else{
    hashResult("SHA-256 вычислен. Эталона нет — подлинность не проверена. Загрузка в SRAM разрешена.","neutral");status("Локальный файл без эталона, можно загрузить в SRAM.","neutral");
  }
  log((hashFailed?"HASH FAIL ":isVerified?"HASH PASS ":"NO REFERENCE HASH ")+name+" actual="+digest+(expected?" expected="+expected:""));
  ready();
}
async function localSelection(){
  const file=$("input-file").files?.[0];if(!file)return;
  try{
    const hashFile=$("hash-file").files?.[0];
    const expected=hashFile?manifestHash(await hashFile.text(),file.name):null;
    if(hashFile&&!expected)throw new Error("В файле хешей нет однозначной SHA-256 для "+file.name);
    await acceptFile(new Uint8Array(await file.arrayBuffer()),file.name,expected,"local");
  }catch(err){firmware=null;hashFailed=true;ready();status(err.message,"error");hashResult(err.message,"error")}
}
$("input-file").addEventListener("change",localSelection);
$("hash-file").addEventListener("change",localSelection);
$("firmware-profile").addEventListener("change",selectFirmwareProfile);
$("load-github").addEventListener("click",async()=>{
  const profile=activeProfile;
  status("Получение проверенного .fs с нашего GitHub Pages...");log("Получаем прошивку "+profile.url);
  try{
    const response=await fetch(profile.url,{mode:"cors",redirect:"follow",cache:"no-store"});
    if(!response.ok)throw new Error("HTTP "+response.status);
    const bytes=new Uint8Array(await response.arrayBuffer());
    if(profile!==activeProfile){log("Профиль изменился во время загрузки: старый файл отброшен");return;}
    await acceptFile(bytes,profile.filename,profile.sha,"GitHub profile");
  }catch(e){
    if(profile!==activeProfile)return;
    status("Автоматическая загрузка "+profile.name+" с GitHub Pages недоступна. Выберите локальный проверенный .fs или скачайте его из Releases. "+e.message,"error");
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
  if(busy||!firmware||!device||hashFailed)return;
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
selectFirmwareProfile();
const secure=window.isSecureContext&&"usb" in navigator;
metric("usb-support",secure?"ДОСТУПЕН ✓":"НЕДОСТУПЕН",secure);
metric("isolation-status",window.crossOriginIsolated?"ГОТОВО ✓":"НЕТ COOP/COEP",window.crossOriginIsolated);
log("WebUSB: "+secure+"; crossOriginIsolated: "+window.crossOriginIsolated);
if(!secure)status("Требуется Chrome/Edge с WebUSB через HTTPS.","error");
else if(!window.crossOriginIsolated)status("Service worker подготавливает COOP/COEP. Возможно, страницу нужно обновить.","neutral");
else status("WebUSB и COOP/COEP готовы. Выберите файл .fs и JTAG Debugger.","neutral");
ready();
