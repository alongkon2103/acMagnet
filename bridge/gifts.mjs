import {readFileSync} from 'node:fs';
export const gifts=JSON.parse(readFileSync(new URL('../data/game-gifts.json',import.meta.url),'utf8'));
export const giftMap=Object.fromEntries(gifts.map(g=>[String(g.id),g.key]));
