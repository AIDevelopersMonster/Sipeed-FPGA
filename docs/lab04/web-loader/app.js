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
  sd08:Object.freeze({name:"PiKoSoL SD-08 · FAT32",sha:"37ddb2fb7d20f7e4ad610dad4160dc98ed38e5197221b62644642d32c8c09f4b",url:"./firmware/sd08_pikosol_fat32_readonly.fs",filename:"sd08_pikosol_fat32_readonly.fs",release:"https://github.com/AIDevelopersMonster/Sipeed-FPGA/releases/download/pikosol-sd08-fat32-ro/sd08_pikosol_fat32_readonly.fs",notes:"25.10.2026 HARDWARE PASS: FS, DIR, TYPE PIKO.TXT. Только FAT32 8.3 read-only. Автозагрузка станет доступна после публикации файла."})
});
let activeProfile=PROFILES.v020;
let device=null, firmware=null, loadedSha="", isVerified=false, localUnverified=false, busy=false, engine=null;
const logEl=$("log");
function log(message){const date=new Date();logEl.textContent+="["+date.toLocaleTimeString("ru-RU")+"] "+message+"\n";if(logEl.textContent.length>90000)logEl.textContent=logEl.textContent.slice(-80000);logEl.scrollTop=logEl.scrollHeight;}
function status(msg,type="neutral"){$("operation-status").textContent=msg;$("operation-status").className="notice "+type;}
function hashResult(msg,type="neutral"){$("hash-result").textContent=msg;$("hash-result").className="notice "+type;}
function metric(id,text,pass=null){const e=$(id);e.textContent=text;e.className=pass===true?"pass":pass===false?"fail":"";}
function ready(){ $("program").disabled=busy||!firmware||!device||(!isVerified&&!localUnverified&&!$("custom-confirm").checked);$("load-github").disabled=busy;$("connect-jtag").disabled=busy;$("input-file").disabled=busy;$("input-hash").disabled=busy;$("firmware-profile").disabled=busy;}
function selectFirmwareProfile(){
  activeProfile=PROFILES[$("firmware-profile").value]||PROFILES.v020;
  firmware=null;loadedSha="";isVerified=false;localUnverified=false;
  $("input-file").value="";$("input-hash").value="";$("firmware-name").textContent="Нет файла";
  $("firmware-size").textContent="—";$("actual-sha").textContent="Файл ещё не выбран";$("expected-sha").textContent="Не указан";$("hash-file-name").textContent="Эталон SHA-256: необязательно";
  $("profile-name").textContent=activeProfile.name;$("profile-notes").textContent=activeProfile.notes;
  $("release-download").href=activeProfile.release;
  $("custom-confirm").checked=false;$("custom-confirm").disabled=true;
  hashResult("Контрольная сумма не проверена.");ready();
}
function hex(array){return [...new Uint8Array(array)].map(x=>x.toString(16).padStart(2,"0")).join("")}

function referenceHash(text,filename){
  const matches=[];
  for(const line of text.split(/\r?\n/)){
    const m=line.trim().match(/^([0-9a-f]{64})(?:\s+\*?(.+))?$/i);
    if(m && (!m[2] || m[2].trim().replace(/^\.\//,"")===filename)){
      matches.push(m[1].toLowerCase());
    }
  }
  if(matches.length!==1)throw new Error("SHA256SUMS: нужен ровно один SHA-256 для "+filename);
  return matches[0];
}
async function acceptFile(bytes,name,source="github",expected=null){
  const buffer=bytes instanceof Uint8Array?bytes:new Uint8Array(bytes);
  if(!name.toLowerCase().endsWith(".fs"))throw new Error("Нужен файл Gowin .fs");
  if(buffer.length<10000||buffer.length>12*1024*1024)throw new Error("Размер .fs вне допустимого диапазона");
  if(!crypto.subtle)throw new Error("SHA-256 требует HTTPS");
  const digest=hex(await crypto.subtle.digest("SHA-256",buffer));
  const known=Object.values(PROFILES).find(p=>p.sha===digest);
  const failed=source==="github"
    ? (!expected || digest!==expected || digest!==activeProfile.sha)
    : (!!expected && digest!==expected);
  firmware=failed?null:buffer;loadedSha=digest;
  isVerified=!failed && (source==="github" || !!expected || !!known);
  localUnverified=!failed && source==="local" && !isVerified;
  $("firmware-name").textContent=name;
  $("firmware-size").textContent=(buffer.length/1048576).toFixed(2)+" MiB";
  $("actual-sha").textContent=digest.toUpperCase();
  $("expected-sha").textContent=(expected || (known&&known.sha) || "Не указан").toUpperCase();
  $("custom-confirm").checked=false;$("custom-confirm").disabled=true;
  if(failed){
    hashResult("SHA-256 FAIL: файл не совпадает со своим эталоном. Программирование запрещено.","error");
    status("Ошибка SHA-256 именно этого .fs, загрузка отменена.","error");
    log("SHA256_FAIL "+name+" expected="+expected+" actual="+digest);
  }else if(isVerified){
    hashResult("SHA-256 PASS: "+(known?known.name:"совпадение с выбранным хеш-файлом"),"ok");
    status("Файл проверен. Можно подключить JTAG и загрузить в SRAM.","ok");
    log("SHA256_PASS "+name+" "+digest+" source="+source);
  }else{
    hashResult("Хеш SHA-256 вычислен. Эталона для файла нет; подлинность не проверена. Загрузка в SRAM доступна.","neutral");
    status("Локальный .fs выбран. Можно загрузить его в SRAM без проверки подлинности.","neutral");
    log("LOCAL_SHA256_ONLY "+name+" "+digest);
  }
  ready();
}
async function loadLocal(){
  const file=$("input-file").files?.[0];
  if(!file)return;
  try{
    const checksumFile=$("input-hash").files?.[0];
    let expected=null;
    if(checksumFile){
      if(checksumFile.size>65536)throw new Error("Слишком большой файл SHA-256");
      expected=referenceHash(await checksumFile.text(),file.name);
    }
    $("hash-file-name").textContent=checksumFile?"SHA-256: "+checksumFile.name:"Эталон SHA-256: необязательно";
    await acceptFile(new Uint8Array(await file.arrayBuffer()),file.name,"local",expected);
  }catch(err){
    firmware=null;isVerified=false;localUnverified=false;ready();
    hashResult("Проверка файла: "+err.message,"error");status(err.message,"error");
    log("LOCAL_FILE_ERROR: "+err.message);
  }
}
$("input-file").addEventListener("change",loadLocal);
$("input-hash").addEventListener("change",loadLocal);
$("custom-confirm").addEventListener("change",ready);
$("firmware-profile").addEventListener("change",selectFirmwareProfile);
$("load-github").addEventListener("click",async()=>{
  const profile=activeProfile;
  status("Скачиваем "+profile.filename+" и его SHA-256 с GitHub Pages...");
  log("GET "+profile.url);
  try{
    const response=await fetch(profile.url,{cache:"no-store"});
    if(!response.ok)throw new Error("Файл "+profile.filename+" недоступен на GitHub Pages (HTTP "+response.status+").");
    const manifestResponse=await fetch("./firmware/SHA256SUMS.txt",{cache:"no-store"});
    if(!manifestResponse.ok)throw new Error("SHA256SUMS.txt HTTP "+manifestResponse.status);
    const expected=referenceHash(await manifestResponse.text(),profile.filename);
    if(expected!==profile.sha)throw new Error("Эталон "+profile.filename+" в SHA256SUMS.txt не совпадает с закрепленным профилем");
    const bytes=new Uint8Array(await response.arrayBuffer());
    if(profile!==activeProfile){log("Профиль изменён; загруженный файл отброшен");return;}
    await acceptFile(bytes,profile.filename,"github",expected);
  }catch(e){
    if(profile!==activeProfile)return;
    firmware=null;isVerified=false;localUnverified=false;ready();
    status("Не удалось скачать "+profile.filename+": "+e.message+" Если файл есть на ПК, выберите его локально.","error");
    log("GITHUB_DOWNLOAD_FAIL: "+e.message);
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
  if(busy||!firmware||!device||(!isVerified&&!localUnverified&&!$("custom-confirm").checked))return;
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
