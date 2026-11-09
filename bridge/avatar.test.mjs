import test from 'node:test';
import assert from 'node:assert/strict';
import sharp from 'sharp';
import {pixelsFromBuffer,allowedAvatarUrl} from './avatar.mjs';
test('32x32 RGB profile is packed in row-major order',async()=>{
 const input=await sharp({create:{width:32,height:32,channels:3,background:'#ff8000'}}).png().toBuffer();
 const p=await pixelsFromBuffer(input);assert.equal(p.length,1024);assert.equal(p[0],0xff8000);assert.equal(p[1023],0xff8000);
});
test('avatar downloader rejects arbitrary hosts and credential URLs',()=>{
 assert.equal(allowedAvatarUrl('https://p16.tiktokcdn.com/a.jpg'),true);
 for(const u of ['http://p16.tiktokcdn.com/a','https://localhost/a','https://tiktokcdn.com.evil.com/a','https://u:p@p16.tiktokcdn.com/a'])assert.equal(allowedAvatarUrl(u),false);
});
