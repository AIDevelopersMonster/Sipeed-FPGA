// PiKoSoL LAB-20.4: reproducible, read-only Node.js ROM consistency test.
'use strict';
const fs = require('node:fs'), assert = require('node:assert/strict'), crypto = require('node:crypto');
const rom = fs.readFileSync(__dirname+'/PiKoSoL_LAB20_ROM_32KiB.bin');
const html = fs.readFileSync(__dirname+'/index.html','utf8');
const manifest = JSON.parse(fs.readFileSync(__dirname+'/PiKoSoL_ROM_32KiB_manifest.json','utf8'));
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
assert.equal(rom.length,32768);
assert.equal(sha(rom),manifest.canonical_sha256);
const b64 = html.match(/<script id="factory-rom" type="application\/octet-stream">([\s\S]*?)<\/script>/);
assert(b64,'Embedded ROM absent');
assert.deepEqual(Buffer.from(b64[1].trim(),'base64'),rom);
const whole=Buffer.concat([rom,rom,rom,rom]);
assert.equal(sha(whole),manifest.source_sha256);
assert.equal(whole.length,131072);
for(const offset of [0,0x8000,0x10000,0x18000]){
  assert.deepEqual(whole.subarray(offset+0xB0,offset+0xC0),rom.subarray(0xB0,0xC0));
}
let crc = 0xffffffff;
for(let i=0;i<0x6644;i++){crc^=rom[i];for(let k=0;k<8;k++)crc=(crc>>>1)^((crc&1)?0xedb88320:0)}
crc=(crc^0xffffffff)>>>0;
assert.equal(crc,0xf2b1f4f6);
assert.equal(rom.readUInt32LE(0x6644),crc);
console.log('PASS canonical32 image + HTML embedded ROM + mirror128 + CRC32');
