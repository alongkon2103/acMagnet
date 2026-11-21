// Run from any directory. Audited baselines remain fixed; current installer inputs
// are refreshed from tracked source. LiveConfig and environment files are never read.
import {readFile,writeFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
const fixture=new URL('./tikkies-native-fixtures.luau',import.meta.url);
const source=await readFile(fixture,'utf8');
const blocks=Object.fromEntries([...source.matchAll(/(\w+)=\[==========\[([\s\S]*?)\]==========\]/g)].map(match=>[match[1],match[2]]));
const hash=value=>{let h=0;for(const byte of Buffer.from(value.replaceAll('\r\n','\n')))h=(h*31+byte)%2147483647;return h;};
const parts={};
for(const [name,expected] of Object.entries({bridge:2058389496,bridgeV1:740631241,bridgeV2:1140701286,server:1913009151})){
 if(typeof blocks[name]!=='string'||hash(blocks[name])!==expected)throw Error(`Audited baseline changed: ${name}`);
 parts[name]=blocks[name];
}
for(const [name,file] of Object.entries({dispatch:'TikkiesDispatch.luau',roomClient:'TikkiesRoomClient.luau',controller:'TikkiesBridge.server.luau',patches:'TikkiesPatches.luau',installer:'StudioTikkiesSetup.luau'})){
 parts[name]=await readFile(new URL(`../../src/${file}`,import.meta.url),'utf8');
}
const output='-- Nonsecret native audit baselines and generated installer inputs. No LiveConfig source.\n-- Refresh current inputs: node tests/fixtures/generate-tikkies-native-fixtures.mjs\nreturn {'+Object.entries(parts).map(([name,value])=>`${name}=[==========[${value}]==========]`).join(',')+'}\n';
if(/(?:BridgeKey|API_KEY|MAGNET_KEY|TIKKIES_KEY)\s*=\s*["'][^"']+/.test(output))throw Error('Unexpected literal credential assignment');
await writeFile(fixture,output,'utf8');
console.log(`Refreshed nonsecret fixtures: ${fileURLToPath(fixture)}`);
