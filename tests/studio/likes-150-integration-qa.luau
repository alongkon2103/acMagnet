-- Studio MCP Server command. Prepend local fixture=JSONDecode(output of generate-likes-150.mjs).
assert(game:GetService("RunService"):IsStudio())
local kit=game.ReplicatedStorage.BlackHole
assert(require(kit.Config).LikesPerReward==150)
assert(#fixture.events==4,"Expected2 raw like packets and2 late portraits")
local source=game.ServerScriptService.TikTokBridge.Source
local boundary=assert(source:find("control.OnServerEvent:Connect",1,true))
local module=Instance.new("ModuleScript")
module.Name="Likes150IntegrationQA"
module.Source=source:sub(1,boundary-1)..'\ntoken="qa";generation=1;return function(e,id)return process(e,id,"qa",1)end'
module.Parent=game.ServerStorage
local process=require(module)
local owner=game.Players:GetPlayers()[1].UserId
local before=kit.State:GetAttribute("Pending")
assert(fixture.events[1].rawLikeCount==149 and fixture.events[2].rawLikeCount==1)
assert(process(fixture.events[1],owner))
assert(kit.State:GetAttribute("Pending")==before,"Sub-threshold packet spawned blocks")
assert(kit.LiveState:GetAttribute("LikeProgress")==149)
assert(process(fixture.events[2],owner))
assert(kit.State:GetAttribute("Pending")==before+10,"149+1 must spawn10 blocks")
assert(kit.LiveState:GetAttribute("LikeProgress")==0)
assert(process(fixture.events[1],owner));assert(process(fixture.events[2],owner))
assert(kit.State:GetAttribute("Pending")==before+10,"Duplicate receipt granted again")
assert(process(fixture.events[3],owner));assert(process(fixture.events[4],owner))
local profile=fixture.events[2].sender.portraitId
assert(#game.HttpService:JSONDecode(kit.LivePortraits[profile].Value)==1024)
module:Destroy()
task.wait(.2)
return game.HttpService:JSONEncode({passed=true,likes=150,blocks=10,duplicatesIgnored=true,profileId=profile,sender="@viewer_b",status=kit.LiveState:GetAttribute("LikeCounterStatus")})
