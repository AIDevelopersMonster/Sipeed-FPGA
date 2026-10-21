/* LAB-03 Trace Observatory: deterministic, offline-capable parser and RV32I reader.
 * No generated PASS is based on a simulation; accepted bus events != retired instructions.
 */
export const ROM_SHA256 = '14b85bc20ce43cdf4ce09ef1db7a20af5677c1c728c64b71258f6c63ab5b8a3d';
export const BITSTREAM_DECLARED_SHA256 = '62596847427f0258cb729a8b3c042ab7e0f39a8725990ba39a831b98c6554f13';
export const MMIO_LED_ADDR = 0x20000000;
export const CORE_ANCHOR_PC = 0x48;
export const REG_ABI = [
  'zero','ra','sp','gp','tp','t0','t1','t2','s0','s1','a0','a1','a2','a3','a4','a5','a6','a7',
  's2','s3','s4','s5','s6','s7','s8','s9','s10','s11','t3','t4','t5','t6'
];
export const hex32 = n => '0x' + (Number(n) >>> 0).toString(16).padStart(8,'0').toUpperCase();
const fail = msg => { throw new Error(msg); };
const signExtend = (value,bits) => (value << (32-bits)) >> (32-bits);

export function parseRom(text) {
  const lines = text.trim().split(/\r?\n/).map(x => x.trim());
  if (lines.length !== 256 || lines.some(x => !/^[0-9a-fA-F]{8}$/.test(x))) {
    fail(`ROM: ожидалось 256 строк по 8 hex-разрядов, найдено ${lines.length}`);
  }
  return lines.map(x => parseInt(x,16) >>> 0);
}

export function expectedLedMask(command) {
  if (!/^[0-6]$/.test(String(command))) fail('Команда LED должна быть 0…6');
  const c = Number(command);
  return c === 0 ? 0 : (1 << (c-1));
}

export function parseTrace(text, rom=null) {
  if (typeof text !== 'string' || text.length > 140000) fail('T3: недопустимый размер файла');
  const lines = text.replace(/\r\n/g,'\n').replace(/\r/g,'\n').trim().split('\n').map(s => s.trim());
  const header = /^T3:([0-9a-fA-F]{8}):([0-9a-fA-F]{8})$/.exec(lines[0] || '');
  if (!header) fail('T3: отсутствует или повреждён заголовок T3:STATUS:COMMAND');
  if (lines.at(-1) !== 'Z') fail('T3: отсутствует завершающий маркер Z');
  const status = parseInt(header[1],16) >>> 0;
  const code = parseInt(header[2],16) >>> 0;
  if (status >>> 24 !== 3 || ((status >>> 16)&255) !== 128) fail('T3: некорректная версия/ёмкость регистратора');
  if ((status & 0xE000) !== 0) fail('T3: зарезервированные биты статуса установлены');
  const count = status & 255;
  if (count > 128 || lines.length !== count + 2) fail(`T3: объявлено ${count} событий, обнаружено ${lines.length-2}`);
  const flags = {
    done: !!(status & 0x100), truncated: !!(status & 0x200),
    overlap: !!(status & 0x400), wrapped: !!(status & 0x800),
    capturing: !!(status & 0x1000)
  };
  if (!flags.done || flags.truncated || flags.overlap || flags.wrapped || flags.capturing) {
    fail(`T3: неполный/непригодный снимок, флаги=${JSON.stringify(flags)}`);
  }
  if (code > 0xFF || code < 48 || code > 54) fail(`T3: неподдерживаемый код команды ${hex32(code)}`);
  const command = String.fromCharCode(code);
  const re = /^E:([0-9a-fA-F]{8}):([0-9a-fA-F]{8}):([0-9a-fA-F]{8}):([0-9a-fA-F]{8})$/;
  const events = lines.slice(1,-1).map((line,i) => {
    const m = re.exec(line);
    if (!m) fail(`T3: неверная строка события №${i}`);
    const index = parseInt(m[1],16) >>> 0;
    const meta = parseInt(m[2],16) >>> 0;
    const address = parseInt(m[3],16) >>> 0;
    const value = parseInt(m[4],16) >>> 0;
    if (index !== i) fail(`T3: индекс №${i} не совпадает`);
    if (meta >>> 18) fail(`T3: неизвестные биты CYCLE_KIND в строке ${i}`);
    const typeCode = (meta >>> 16) & 3;
    if (typeCode !== 1 && typeCode !== 2) fail(`T3: недопустимый тип события №${i}`);
    const cycle = meta & 0xFFFF;
    const kind = typeCode === 1 ? 'FETCH' : 'LED_WRITE';
    if (kind === 'FETCH') {
      if (address >= 1024 || address % 4) fail(`T3: неверный адрес ROM ${hex32(address)} (№${i})`);
      if (rom && rom[address/4] !== value) fail(`T3: ROM mismatch на ${hex32(address)} (№${i})`);
    } else if (address !== MMIO_LED_ADDR) fail(`T3: LED_WRITE вне адреса MMIO (№${i})`);
    return { index, cycle, kind, address, value };
  });
  for (let i=1;i<events.length;i++) {
    if (events[i].cycle < events[i-1].cycle) fail(`T3: уменьшение относительного счётчика между ${i-1} и ${i}`);
  }
  const writes = events.filter(e => e.kind === 'LED_WRITE');
  if (events.length < 2 || writes.length !== 1 || events.at(-1).kind !== 'LED_WRITE') {
    fail('T3: завершённый снимок должен содержать ровно одну финальную LED_WRITE');
  }
  if (events.at(-1).value !== expectedLedMask(command)) {
    fail(`T3: LED_WRITE ${hex32(events.at(-1).value)} не соответствует команде ${command}`);
  }
  return { protocol:'LAB03-T3-ASCII-v0.1', status, command, count, flags, events,
           fetchCount:events.length-1, ledMask:events.at(-1).value, raw:text.replace(/\r?\n/g,'\r\n').trim()+ '\r\n' };
}

export function normalizedCore(trace) {
  const positions = trace.events.map((e,i) => (e.kind === 'FETCH' && e.address === CORE_ANCHOR_PC) ? i : -1).filter(i=>i>=0);
  if (positions.length !== 1) fail(`Нормализация: PC=${hex32(CORE_ANCHOR_PC)} найден ${positions.length} раз (ожидается 1)`);
  const idx = positions[0];
  const permitted = new Set([0x38,0x3c,0x40,0x44]);
  if (!trace.events.slice(0,idx).every(e => e.kind==='FETCH' && permitted.has(e.address))) {
    fail('Нормализация: неожиданные события до PC=0x048');
  }
  const core = trace.events.slice(idx);
  if (core.at(-1)?.kind!=='LED_WRITE') fail('Нормализация: нет завершающей MMIO записи');
  return { prefixCount:idx, events:core, fetchCount:core.filter(e=>e.kind==='FETCH').length, fullCount:trace.events.length };
}

export function eventKey(e) { return `${e.kind}:${hex32(e.address)}:${hex32(e.value)}`; }
export function compareTraces(a,b) {
  if (a.command !== b.command) return {match:false,reason:`Команды различны: ${a.command} и ${b.command}`,rows:[],left:null,right:null};
  const left=normalizedCore(a), right=normalizedCore(b);
  const max=Math.max(left.events.length,right.events.length);
  const rows=Array.from({length:max},(_,i)=>{
    const l=left.events[i]||null,r=right.events[i]||null;
    return {pos:i,left:l,right:r,match:!!l&&!!r&&eventKey(l)===eventKey(r)};
  });
  const first=rows.findIndex(x=>!x.match);
  return {match:first<0,firstDifference:first,reason:first<0?`Совпадают ${rows.length} шинных событий`:`Различие в событии №${first+1}`,
          rows,left,right};
}

const r = n => REG_ABI[n];
export function disassemble(word,pc=0) {
  word=Number(word)>>>0;pc=Number(pc)>>>0;
  const opcode=word & 127,rd=(word>>>7)&31,f3=(word>>>12)&7,rs1=(word>>>15)&31,rs2=(word>>>20)&31,f7=(word>>>25)&127;
  const iImm=signExtend(word>>>20,12), sImm=signExtend(((word>>>25)<<5)|((word>>>7)&31),12);
  const bImm=signExtend((((word>>>31)&1)<<12)|(((word>>>7)&1)<<11)|(((word>>>25)&63)<<5)|(((word>>>8)&15)<<1),13);
  const jImm=signExtend((((word>>>31)&1)<<20)|(((word>>>12)&255)<<12)|(((word>>>20)&1)<<11)|(((word>>>21)&1023)<<1),21);
  const reg=(id)=>r(id);
  const result=(asm,klass,explanation)=>({asm,klass,explanation,word,pc});
  if (word===0x00000013) return result('nop','ALU','Псевдоним addi zero, zero, 0. Запрошенное слово может не быть выполнено.');
  if (opcode===0x37) return result(`lui ${reg(rd)}, ${hex32(word&0xfffff000)}`,'ALU','Загружает старшие 20 разрядов константы в регистр.');
  if (opcode===0x17) return result(`auipc ${reg(rd)}, ${hex32(word&0xfffff000)}`,'ALU','Создаёт PC-относительное значение.');
  if (opcode===0x6f) return result(`jal ${reg(rd)}, ${hex32(pc+jImm)}`,'CONTROL','Безусловный переход с сохранением адреса возврата (если rd ≠ zero).');
  if (opcode===0x67 && f3===0) return result(`jalr ${reg(rd)}, ${iImm}(${reg(rs1)})`,'CONTROL','Косвенный переход через регистр.');
  if (opcode===0x63) {
    const op={0:'beq',1:'bne',4:'blt',5:'bge',6:'bltu',7:'bgeu'}[f3];
    if(op) return result(`${op} ${reg(rs1)}, ${reg(rs2)}, ${hex32(pc+bImm)}`,'CONTROL','Условный переход. FETCH в трассе ещё не удостоверяет, что переход состоялся.');
  }
  if(opcode===0x03){const op={0:'lb',1:'lh',2:'lw',4:'lbu',5:'lhu'}[f3];if(op) return result(`${op} ${reg(rd)}, ${iImm}(${reg(rs1)})`,'LOAD','Чтение данных из памяти или MMIO.');}
  if(opcode===0x23){const op={0:'sb',1:'sh',2:'sw'}[f3];if(op)return result(`${op} ${reg(rs2)}, ${sImm}(${reg(rs1)})`,'STORE','Запись данных в память или MMIO.');}
  if(opcode===0x13){
    const op={0:'addi',2:'slti',3:'sltiu',4:'xori',6:'ori',7:'andi'}[f3];
    if(op) return result(`${op} ${reg(rd)}, ${reg(rs1)}, ${iImm}`,'ALU','Целочисленная операция с константой (immediate).');
    if(f3===1&&f7===0) return result(`slli ${reg(rd)}, ${reg(rs1)}, ${(word>>>20)&31}`,'ALU','Логический сдвиг влево.');
    if(f3===5&&(f7===0||f7===32))return result(`${f7===32?'srai':'srli'} ${reg(rd)}, ${reg(rs1)}, ${(word>>>20)&31}`,'ALU',f7===32?'Арифметический сдвиг вправо.':'Логический сдвиг вправо.');
  }
  if(opcode===0x33){
    const op=f7===0?{0:'add',1:'sll',2:'slt',3:'sltu',4:'xor',5:'srl',6:'or',7:'and'}[f3]:f7===32?{0:'sub',5:'sra'}[f3]:null;
    if(op) return result(`${op} ${reg(rd)}, ${reg(rs1)}, ${reg(rs2)}`,'ALU','Целочисленная регистровая операция.');
  }
  if(opcode===0x73&&word===0x00000073)return result('ecall','SYSTEM','Вызов окружения.');
  return result(`.word ${hex32(word)}`,'UNKNOWN','Код не распознан этим учебным декодером; не следует угадывать мнемонику.');
}

export function eventInterpretation(e) {
  if (e.kind === 'LED_WRITE') return `Принята запись в регистр GPIO/MMIO ${hex32(e.address)}, маска светодиодов ${hex32(e.value)}. Это шинное событие, не оптическое измерение.`;
  const d=disassemble(e.value,e.address);
  return `Процессор принял из ROM машинное слово ${hex32(e.value)} по адресу PC=${hex32(e.address)}. Декодирование: ${d.asm}. Это FETCH, а не доказанное завершение инструкции.`;
}
