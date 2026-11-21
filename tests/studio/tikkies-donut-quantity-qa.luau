-- Execute the real audited native accept() with engine boundaries replaced.
-- This never mutates a running Roblox game or sends a paid gift.
local fixture=require('../fixtures/tikkies-native-fixtures')
local first=assert(fixture.server:find('local function accept(giftId, sender, quantity, eventId, requesterUserId)',1,true))
local last=assert(fixture.server:find('-- Server-only integration.',first,true))
local source=fixture.server:sub(first,last-1)..'\nreturn accept'
local function gameFixture()
 local attrs,events={},{}
 local http={JSONEncode=function(_,v)return v end,JSONDecode=function(_,v)return v end}
 local env=setmetatable({
  Config={Gifts={Donut={ArenaExpandPercent=10}},MaxGiftArenaPercent=800},
  seen={},workspace={GetServerTimeNow=function()return 100 end},
  kit={LivePortraits={FindFirstChild=function()end},LiveNames={FindFirstChild=function()end}},
  state={GetAttribute=function(_,k)return attrs[k]end,SetAttribute=function(_,k,v)attrs[k]=v end},
  Arena={Read=function()return 1.6,attrs.ArenaTransition and attrs.ArenaTransition.to or 1.6 end},
  game={GetService=function()return http end},sync=function()end,
  event={FireAllClients=function(_,_,data)table.insert(events,data)end},
 },{__index=getfenv()})
 local chunk=assert(loadstring(source));setfenv(chunk,env)
 return chunk(),attrs,events
end
local sender={name='QuantityQA',seed=42}
for _,quantities in ipairs({{3},{1,1,1},{1,2}})do
 local accept,attrs,events=gameFixture()
 for i,quantity in ipairs(quantities)do assert(accept('Donut',sender,quantity,'donut-'..i))end
 assert(math.abs(attrs.ArenaTransition.to*100-190)<.0001,'Three donuts must add 30 percentage points')
 assert(#events==#quantities,'Each distinct receipt emits its own native Gift event')
 local sum=0;for _,event in events do sum+=event.quantity end;assert(sum==3,'Native event quantities remain complete')
 local ok,issue=accept('Donut',sender,quantities[1],'donut-1');assert(not ok and issue=='duplicate')
 assert(math.abs(attrs.ArenaTransition.to*100-190)<.0001,'A retry must not grow the arena twice')
end
print('PASS native Donut: x3, three x1, x1+x2 all add30%; receipt replay adds nothing; animation can coalesce')
