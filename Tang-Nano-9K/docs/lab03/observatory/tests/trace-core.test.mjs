import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {parseRom,parseTrace,normalizedCore,compareTraces,hex32,disassemble,ROM_SHA256,expectedLedMask} from '../src/trace-core.mjs';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const romText=fs.readFileSync(path.join(root,'data/lab03_boot.hex'),'utf8');
const rom=parseRom(romText);const campaign=JSON.parse(fs.readFileSync(path.join(root,'data/campaign.json'),'utf8'));
const captures=campaign.boardCaptures.map(r=>({...r,decoded:parseTrace(r.trace,rom)}));
const by=cmd=>captures.filter(r=>r.command===cmd);
const replace=(text,a,b)=>{assert.ok(text.includes(a));return text.replace(a,b)};

test('ROM byte SHA256 pinned to the actual LAB-03, not evidence LAB-02 boot.hex',()=>{
 assert.equal(crypto.createHash('sha256').update(romText.replace(/\r\n/g,'\n')).digest('hex'),ROM_SHA256);assert.equal(rom.length,256);
 assert.equal(hex32(rom[0x48/4]),'0x05400413');assert.equal(hex32(rom[0x100/4]),'0x01D2A023');
});
test('all 12 archived raw dumps pass integrity, status, ROM and MMIO checks',()=>{
 assert.equal(captures.length,12);assert.equal(new Set(captures.map(c=>c.run)).size,12);
 for(const t of captures){
  assert.equal(crypto.createHash('sha256').update(t.trace).digest('hex'),t.rawSha256);
  assert.equal(t.decoded.command,t.command);assert.equal(t.decoded.flags.done,true);
  assert.equal(t.decoded.ledMask,expectedLedMask(t.command));
 }
 assert.equal(captures.reduce((a,c)=>a+c.decoded.fetchCount,0),269);
 assert.equal(by('0').length,6);assert.equal(by('4').length,6);
});
test('normalized cores have expected accepted bus lengths',()=>{
 for(const t of by('0'))assert.equal(normalizedCore(t.decoded).fetchCount,14);
 for(const t of by('4'))assert.equal(normalizedCore(t.decoded).fetchCount,22);
});
test('all six board captures of each command match normalized signatures',()=>{
 for(const cmd of ['0','4']){
  const xs=by(cmd);
  for(const a of xs)for(const b of xs)assert.equal(compareTraces(a.decoded,b.decoded).match,true);
 }
});
test('archive includes varying polling prefix for a repeated command',()=>{
 assert.ok(new Set(by('4').map(r=>normalizedCore(r.decoded).prefixCount)).size>=2);
 assert.ok(new Set(by('0').map(r=>r.decoded.fetchCount)).size>=2);
});
test('comparing different commands returns mismatch',()=>{
 const v=compareTraces(by('0')[0].decoded,by('4')[0].decoded);
 assert.equal(v.match,false);assert.match(v.reason,/Команды различны/);
});
test('one mutated accepted bus event leads to mismatch (valid ROM word at wrong position)',()=>{
 const orig=by('4')[0].decoded;
 const copy=structuredClone(orig);
 const core=normalizedCore(copy);
 const p=core.prefixCount;[copy.events[p+1],copy.events[p+2]]=[copy.events[p+2],copy.events[p+1]];
 assert.equal(compareTraces(orig,copy).match,false);
});
test('one changed code word fails ROM audit',()=>{
 const original=by('4')[0].trace;
 assert.throws(()=>parseTrace(replace(original,'00000048:05400413','00000048:05300413'),rom),/ROM mismatch/);
});
test('bad terminal MMIO data fails',()=>{
 const s=by('4')[0].trace;
 assert.throws(()=>parseTrace(replace(s,'20000000:00000008','20000000:00000000'),rom),/LED_WRITE/);
});
test('malformed header rejected',()=>{
 assert.throws(()=>parseTrace(replace(by('4')[0].trace,'T3:','T2:'),rom),/заголовок/);
});
test('incomplete trace flag rejected',()=>{
 const s=by('4')[0].trace;
 assert.throws(()=>parseTrace(s.replace(/^T3:([0-9a-f]{8}):/i,(_,st)=>`T3:${(parseInt(st,16)|0x200).toString(16).padStart(8,'0')}:`),rom),/неполный/);
});
test('unapproved prefix blocked even if accepted ROM word is valid',()=>{
 const x=structuredClone(by('4')[0].decoded);
 x.events[0].address=0x100;x.events[0].value=rom[0x100/4];
 assert.throws(()=>normalizedCore(x),/неожиданные события/);
});
test('disassembly: firmware examples and standard RISC-V operand conventions',()=>{
 assert.equal(disassemble(0x05400413,0x48).asm,'addi s0, zero, 84');
 assert.equal(disassemble(0x01d2a023,0x100).asm,'sw t4, 0(t0)');
 assert.equal(disassemble(0x0002af83,0x104).asm,'lw t6, 0(t0)');
 assert.equal(disassemble(0x00000013).asm,'nop');
});
test('no accepted trace event is silently turned into retirement',()=>{
 const t=by('4')[0].decoded;
 assert.ok(t.events.every(e=>!('retired' in e)));
 assert.equal(t.events.at(-1).kind,'LED_WRITE');
});
