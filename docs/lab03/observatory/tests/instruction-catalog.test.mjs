/* Actual evidence -> observed RV32I catalog; ROM -> entire active program.
 * No synthetic fake mnemonics, no assumption FETCH == retirement.
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {parseRom,parseTrace,disassemble} from '../src/trace-core.mjs';
import {catalogFromTraces,catalogFromRom,instructionExamples,MNEMONIC_NOTES,binaryWord,opcodeBits} from '../src/instruction-catalog.mjs';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const rom=parseRom(fs.readFileSync(path.join(root,'data/lab03_boot.hex'),'utf8'));
const campaign=JSON.parse(fs.readFileSync(path.join(root,'data/campaign.json'),'utf8'));
const traces=campaign.boardCaptures.map(c=>({id:`board-${c.run}`,run:c.run,decoded:parseTrace(c.trace,rom)}));

const observed=catalogFromTraces(traces);
const program=catalogFromRom(rom);

test('EXACTLY six RV32I mnemonics were observed by the real hardware campaign',()=>{
  assert.deepEqual(observed.entries.map(x=>x.mnemonic).sort(),['addi','andi','beq','jal','lw','sw']);
  assert.equal(observed.fetchTotal,269);
  assert.equal(observed.uniqueSites,29);
  const counts=Object.fromEntries(observed.entries.map(e=>[e.mnemonic,e.count]));
  assert.deepEqual(counts,{addi:108,beq:87,lw:39,jal:12,sw:12,andi:11});
  assert.equal(observed.entries.reduce((a,e)=>a+e.count,0),269);
});
test('10 actual instruction mnemonics appear in active LAB-03 ROM, plus 54 padding NOPs',()=>{
  assert.deepEqual(program.entries.map(e=>e.mnemonic).sort(),[
    'addi','andi','beq','bne','jal','jalr','lui','lw','srli','sw'
  ]);
  assert.equal(program.activeWords,202);
  assert.equal(program.paddingNops,54);
  assert.equal(program.uniqueSites,202);
  assert.equal(program.entries.reduce((s,e)=>s+e.count,0),202);
  assert.ok(!program.entries.some(e=>e.mnemonic==='nop'));
});
test('every observed address and machine word comes from pinned ROM (no invented examples)',()=>{
 for(const entry of observed.entries)for(const site of entry.sites){
   assert.equal(rom[site.address/4],site.value);
   assert.equal(disassemble(site.value,site.address).asm,site.asm);
   assert.ok(traces.some(t=>t.decoded.events.some(e=>e.kind==='FETCH'&&e.address===site.address&&e.value===site.value)));
 }
});
test('every exposed ROM example matches a real instruction word in the active image',()=>{
 for(const entry of program.entries)for(const site of entry.sites){
   assert.equal(rom[site.address/4],site.value);
   assert.equal(disassemble(site.value,site.address).asm,site.asm);
 }
});
test('ROM-only mnemonic cards do not appear among measured FETCHes',()=>{
 for(const name of ['lui','bne','srli','jalr']){
  assert.equal(instructionExamples(observed,name).length,0);
  assert.ok(instructionExamples(program,name).length>0);
 }
});
test('tutorial has semantic cards for EVERY instruction present, and not random extras',()=>{
 for(const item of program.entries){
   assert.ok(item.note,`no notes for ${item.mnemonic}`);
   assert.ok(item.note.syntax && item.note.effect && item.note.role && item.note.caveat && item.note.operands.length);
 }
 assert.ok(MNEMONIC_NOTES.nop.caveat.includes('хвосте'));
});
test('actual sw machine word, binary representation and opcode are stable',()=>{
 const sw=instructionExamples(observed,'sw');
 assert.equal(sw.length,1);
 assert.equal(sw[0].address,0x100);
 assert.equal(sw[0].value,0x01D2A023);
 assert.equal(sw[0].asm,'sw t4, 0(t0)');
 assert.equal(binaryWord(sw[0].value).replace(/ /g,''),'00000001110100101010000000100011');
 assert.equal(opcodeBits(sw[0].value),'0100011');
});
test('selected trace mode reports counts from selected capture, not from full archive',()=>{
 const one=catalogFromTraces([traces[0]]);
 assert.equal(one.fetchTotal,traces[0].decoded.fetchCount);
 assert.ok(one.fetchTotal<observed.fetchTotal);
 assert.ok(one.entries.every(e=>e.count>0));
});
test('no accepted FETCH claims instruction retirement or readback value',()=>{
 assert.ok(!JSON.stringify(observed).includes('retiredCount'));
 for(const t of traces)assert.ok(t.decoded.events.every(e=>!('retired' in e)));
});
