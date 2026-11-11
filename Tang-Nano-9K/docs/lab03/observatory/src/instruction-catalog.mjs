/* LAB-03 v1.1: RV32I educational catalog built strictly from captured FETCHes
 * and from the pinned LAB-03 ROM. Descriptions are documentation, NOT execution
 * claims. Never count ROM membership or FETCH as retired instructions.
 */
import {disassemble, hex32} from './trace-core.mjs';

export const MNEMONIC_NOTES = Object.freeze({
  addi: {
    en:'Add Immediate', format:'I', title:'Сложение с непосредственным операндом',
    syntax:'addi rd, rs1, imm',
    effect:'rd ← rs1 + sign_extend(imm) (по модулю 2³²).',
    role:'В нашей программе загружает ASCII-коды команд, значения масок LED и другие небольшие константы; часто используется с zero.',
    caveat:'Если rs1 = zero, получается загрузка небольшого знакового числа, но это всё та же машинная команда ADDI.',
    operands:['rd — регистр результата','rs1 — исходный регистр','imm — знаковая константа, 12 бит']
  },
  andi: {
    en:'AND Immediate', format:'I',title:'Побитовое И с константой',syntax:'andi rd, rs1, imm',
    effect:'rd ← rs1 AND sign_extend(imm).',
    role:'По адресу PC=0x03C выполняет маскирование младшего бита состояния UART_RX_STATUS: andi t2, t2, 1.',
    caveat:'Операция AND работает с битами; это не логическое короткое замыкание языка C.',
    operands:['rd — регистр результата','rs1 — значение для маскирования','imm — битовая маска (12 бит)']
  },
  beq: {
    en:'Branch if Equal',format:'B',title:'Условный переход при равенстве',syntax:'beq rs1, rs2, offset',
    effect:'Если rs1 = rs2, PC ← PC + sign_extend(offset); иначе следующий последовательный адрес.',
    role:'В цикле ожидания UART, PC=0x040, сравнивает t2 с zero; при отсутствии байта адрес перехода равен 0x038.',
    caveat:'FETCH по адресу ветвления сам по себе НЕ сообщает, была ли ветвь принята, и не гарантирует завершение инструкции.',
    operands:['rs1 — первый операнд','rs2 — второй операнд','offset — относительное смещение перехода; в интерфейсе показана конечная цель']
  },
  jal: {
    en:'Jump And Link',format:'J',title:'Безусловный PC-относительный переход',syntax:'jal rd, offset',
    effect:'rd ← PC + 4; PC ← PC + sign_extend(offset). Если rd=zero, адрес возврата отбрасывается.',
    role:'В измеренном маршруте команда jal zero, 0x00000100 направляет поток к общей процедуре apply, записывающей LED.',
    caveat:'Трасса FETCH показывает запрос слова перехода; не заменяет наблюдение архитектурного потока выполнения.',
    operands:['rd — регистр адреса возврата (zero означает без сохранения)','offset — PC-относительное смещение; показана цель']
  },
  lw: {
    en:'Load Word',format:'I',title:'Чтение 32-битного слова',syntax:'lw rd, offset(rs1)',
    effect:'rd ← MEM32[rs1 + sign_extend(offset)].',
    role:'В цикле UART читает флаги/байт: lw t2, 28(t0) и lw t3, 24(t0). После записи LED код содержит lw t6, 0(t0), предназначенный для обратного чтения.',
    caveat:'Наш прибор фиксирует именно FETCH машинного слова LW, а не факт принятого DATA_READ и не прочитанное значение регистра!',
    operands:['rd — регистр назначения','offset — смещение в байтах','rs1 — базовый регистр адреса']
  },
  sw: {
    en:'Store Word',format:'S',title:'Запись 32-битного слова',syntax:'sw rs2, offset(rs1)',
    effect:'MEM32[rs1 + sign_extend(offset)] ← rs2.',
    role:'PC=0x100: sw t4, 0(t0) — программный код записи в регистр светодиодов. Следующее отдельное событие LED_WRITE подтверждает принятую шиной MMIO-запись.',
    caveat:'Наличие FETCH с SW и отдельной LED_WRITE в одном захвате не удостоверяет архитектурный retirement всех промежуточных инструкций.',
    operands:['rs2 — регистр записываемых данных','offset — смещение в байтах','rs1 — регистр базового адреса']
  },
  lui: {
    en:'Load Upper Immediate',format:'U',title:'Загрузка старших разрядов константы',syntax:'lui rd, imm20',
    effect:'rd ← imm20 << 12 (нижние 12 бит становятся нулями).',
    role:'В начале ROM, PC=0x000, стоит lui t0, 0x20000000: формирует базовый MMIO-адрес 0x20000000 для GPIO и UART.',
    caveat:'Эта инструкция есть в ROM, но не попала в наши захваты, запускаемые после приёма UART-команды.',
    operands:['rd — регистр назначения','imm20 — константа в старших 20 битах']
  },
  bne: {
    en:'Branch if Not Equal',format:'B',title:'Условный переход при неравенстве',syntax:'bne rs1, rs2, offset',
    effect:'Если rs1 ≠ rs2, PC ← PC + sign_extend(offset); иначе следующий адрес.',
    role:'PC=0x108: bne t6, t4, 0x000001C0 — часть проверки соответствия считанной LED-маски записанному значению.',
    caveat:'Инструкция присутствует в ROM, но в наших захватах после LED_WRITE прибор уже закончил запись событий.',
    operands:['rs1 — первый регистр','rs2 — второй регистр','offset — PC-относительное смещение']
  },
  srli: {
    en:'Shift Right Logical Immediate',format:'I',title:'Логический сдвиг вправо',syntax:'srli rd, rs1, shamt',
    effect:'rd ← unsigned(rs1) >> shamt; слева добавляются нули.',
    role:'В функции print_hex32 последовательно сдвигает 32-битное число, выделяя группы по четыре бита для печати в UART.',
    caveat:'Функция печати трассы запускается после окончания аппаратного захвата, поэтому эти FETCH отсутствуют в измеренном снимке.',
    operands:['rd — регистр результата','rs1 — источник','shamt — число сдвигаемых разрядов (0…31)']
  },
  jalr: {
    en:'Jump And Link Register',format:'I',title:'Косвенный переход через регистр',syntax:'jalr rd, offset(rs1)',
    effect:'rd ← PC + 4; PC ← (rs1 + sign_extend(offset)) & ~1.',
    role:'Используется для возврата из подпрограмм печати через сохранённые адреса в регистрах s7, s6 и ra.',
    caveat:'Наличие этой команды в ROM не означает, что наши 12 измерений наблюдали её FETCH.',
    operands:['rd — место для адреса возврата (zero — отбросить)','rs1 — регистр цели','offset — смещение в байтах']
  },
  nop: {
    en:'No Operation (pseudo-instruction)',format:'I',title:'Псевдокоманда «нет действия»',syntax:'nop (= addi zero, zero, 0)',
    effect:'Не изменяет архитектурного состояния регистров; кодировка 0x00000013.',
    role:'В нашем ROM это хвостовое заполнение до 256 слов (1 КиБ), не часть зарегистрированного исполнения.',
    caveat:'NOP в хвосте ROM не включён в список 10 мнемоник активной части программы; это не отдельная базовая команда ISA.',
    operands:['zero — всегда нулевой регистр','0 — непосредственное значение']
  }
});

const mnemonic = asm => asm.split(/\s+/)[0];
const newRecord = (d) => ({mnemonic:mnemonic(d.asm),note:MNEMONIC_NOTES[mnemonic(d.asm)]||null,
  count:0,sites:new Map(),commands:new Set(),runs:new Set(),sampleRuns:new Map()});
const compareSite=(a,b)=>a.address-b.address;
const siteKey=(e)=>`${e.address}:${e.value}`;
function complete(groups){
  return [...groups.values()].map(entry=>({
    mnemonic:entry.mnemonic,note:entry.note,count:entry.count,uniqueSites:entry.sites.size,
    commands:[...entry.commands].sort(),runs:[...entry.runs].sort((a,b)=>a-b),
    sites:[...entry.sites.values()].sort(compareSite)
  })).sort((a,b)=>b.count-a.count||a.mnemonic.localeCompare(b.mnemonic));
}

export function catalogFromTraces(traces){
  const groups=new Map(); let fetchTotal=0;
  for(const source of traces){
    const t=source.decoded || source;
    if(!Array.isArray(t.events))throw new Error('Каталог: ожидается разобранная T3-трасса');
    for(const event of t.events){
      if(event.kind!=='FETCH')continue;
      fetchTotal++;
      const d=disassemble(event.value,event.address);
      const key=mnemonic(d.asm);
      if(!groups.has(key))groups.set(key,newRecord(d));
      const record=groups.get(key);record.count++;
      if(t.command)record.commands.add(t.command);
      if(Number.isSafeInteger(source.run))record.runs.add(source.run);
      const site=siteKey(event);
      if(!record.sites.has(site))record.sites.set(site,{
        address:event.address,value:event.value,asm:d.asm,format:record.note?.format||'?',
        count:0,traceId:source.id||null,traceIndex:event.index,run:source.run??null,command:t.command
      });
      record.sites.get(site).count++;
    }
  }
  const entries=complete(groups);
  return {scope:'traces',fetchTotal,uniqueSites:entries.reduce((s,e)=>s+e.uniqueSites,0),entries};
}

export function catalogFromRom(rom){
  if(!Array.isArray(rom)||rom.length!==256)throw new Error('Каталог ROM: ожидалось ровно 256 слов');
  let activeEnd=rom.length;
  while(activeEnd>0&&rom[activeEnd-1]===0x00000013)activeEnd--;
  const groups=new Map();
  for(let i=0;i<activeEnd;i++){
    const address=i*4,value=rom[i],d=disassemble(value,address),key=mnemonic(d.asm);
    if(!groups.has(key))groups.set(key,newRecord(d));
    const entry=groups.get(key);entry.count++;
    entry.sites.set(siteKey({address,value}),{address,value,asm:d.asm,format:entry.note?.format||'?',count:1,traceId:null,traceIndex:null,run:null,command:null});
  }
  const entries=complete(groups);
  return {scope:'rom',activeWords:activeEnd,paddingNops:rom.length-activeEnd,
    uniqueSites:activeEnd,entries};
}

export function binaryWord(value){return (value>>>0).toString(2).padStart(32,'0').replace(/(.{4})(?!$)/g,'$1 ')}
export function opcodeBits(value){return (value&127).toString(2).padStart(7,'0')}
export function instructionExamples(catalog, mnemonicName){
  return catalog.entries.find(x=>x.mnemonic===mnemonicName)?.sites||[];
}
