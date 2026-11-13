-- Studio MCP Server command: real follow processor and game gateway, in-memory reward store only.
assert(game:GetService("RunService"):IsStudio())
local kit=game.ReplicatedStorage.BlackHole
local source=game.ServerScriptService.TikTokBridge.Source
local boundary=assert(source:find("control.OnServerEvent:Connect",1,true))
source=source:sub(1,boundary-1)
local old='function(channel) return game:GetService("DataStoreService"):GetDataStore("TikTokFollowRewards_v1", channel) end'
local first,last=assert(source:find(old,1,true))
source=source:sub(1,first-1)..'function(channel)return testStore(channel)end'..source:sub(last+1)
local module=Instance.new("ModuleScript")
module.Name="FollowProfileQA"
module.Source='local stores={} local function testStore(channel) stores[channel]=stores[channel]or{} local values=stores[channel] return {UpdateAsync=function(_,key,change)values[key]=change(values[key]);return values[key]end}end\n'..source..'\ntoken="qa";generation=1;return function(e,id)return process(e,id,"qa",1)end'
module.Parent=game.ServerStorage
local process=require(module)
local oldChannel=kit.LiveState:GetAttribute("Username")
kit.LiveState:SetAttribute("Username","qa_follow_channel")
local p=game.Players:GetPlayers()[1]
local portraitId="p"..string.rep("b",32)
local pending=kit.State:GetAttribute("Pending")
local sender={name="@follow_profile_qa",seed=555,userId="9223372036854775801",uniqueId="follow_profile_qa",portraitId=portraitId}
local ok,reason=process({id="qa-follow-1",giftId="Follow",quantity=1,sender=sender},p.UserId)
assert(ok,reason)
local after=kit.State:GetAttribute("Pending")
assert(after-pending==10,"Follow must enqueue exactly10 blocks")
assert(process({id="qa-follow-duplicate",giftId="Follow",quantity=1,sender=sender},p.UserId))
assert(kit.State:GetAttribute("Pending")==after,"Refollow granted a second reward")
assert(process({id="qa-follow-portrait",kind="Portrait",sender={portraitId=portraitId,pixels=table.create(1024,0x33aa77)}},p.UserId))
assert(#game.HttpService:JSONDecode(kit.LivePortraits[portraitId].Value)==1024)
kit.LiveState:SetAttribute("Username",oldChannel)
module:Destroy()
return game.HttpService:JSONEncode({passed=true,spawned=10,portraitId=portraitId,duplicateSuppressed=true,pixels=1024})
