-- Run with Studio MCP execute_luau in Server mode after starting a fresh Play.
-- Uses the real bridge process and SubmitGift; replaces only connection setup.
assert(game:GetService("RunService"):IsStudio(),"Studio only")
local kit=game.ReplicatedStorage.BlackHole
local source=game.ServerScriptService.TikTokBridge.Source
local boundary=assert(source:find("control.OnServerEvent:Connect",1,true))
local fixture=Instance.new("ModuleScript")
fixture.Source=source:sub(1,boundary-1)..'\ntoken="qa";generation=1;return function(e)return process(e,1,"qa",1)end'
fixture.Parent=game.ServerStorage
local process=require(fixture)
local portraitId="p"..string.rep("a",32)
local prefix="qa-"..os.clock()
local function receipt(key,suffix)
 return {id=prefix..suffix,giftId=key,quantity=1,sender={name="LIVE_QA",seed=777,portraitId=portraitId}}
end
local ok,issue=process(receipt("Rose","rose"))
assert(ok,issue)
local before=kit.State:GetAttribute("Pending")
local late,reason=process({id=prefix.."portrait",kind="Portrait",sender={portraitId=portraitId,pixels=table.create(1024,123456)}})
assert(late,reason)
assert(kit.State:GetAttribute("Pending")==before,"Portrait granted a second gift")
assert(#game.HttpService:JSONDecode(kit.LivePortraits[portraitId].Value)==1024)
assert(process(receipt("Friendship","freeze")))
local freezeUntil=kit.State:GetAttribute("FreezeUntil")
assert(freezeUntil-workspace:GetServerTimeNow()>=4.9,"Freeze did not start")
assert(process(receipt("Friendship","freeze")))
assert(kit.State:GetAttribute("FreezeUntil")==freezeUntil,"Replay extended freeze")
local _,oldTarget=require(kit.ArenaMath).Read()
assert(process(receipt("Donut","expand")))
local _,newTarget=require(kit.ArenaMath).Read()
assert(math.abs(newTarget-oldTarget-.1)<.001,"Donut did not expand arena")
fixture:Destroy()
return game.HttpService:JSONEncode({passed=true,portraitPixels=1024,freezeSeconds=5,expansionPercentagePoints=10,replaySuppressed=true})
