-- Run manually on Server during an authorized Play test AFTER installing Tikkies.
-- Uses synthetic sender identity and test=true; never claims a real Follow reward.
local SSS=game:GetService("ServerScriptService")
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local player=assert(Players:GetPlayers()[1],"Join the Play test first")
local kit=game.ReplicatedStorage.BlackHole
local hook=SSS.TikTokBridge:WaitForChild("TikkiesGateway")
assert(not hook:Invoke("status").nativeBusy,"Disconnect native LIVE before QA")
local namespace=Http:GenerateGUID(false)
local session=namespace..":qa"
local portraitId="p"..string.rep("c",32)
local sender={name="TestViewer",uniqueId="tikkies_test_viewer",userId="9000000000000000001",seed=312,portraitId=portraitId}
local savedUsername=player:GetAttribute("SavedUsername")
local channel=type(savedUsername)=="string"and #savedUsername>0 and savedUsername or "tikkies_test"
assert(hook:Invoke("begin",tostring(player.UserId),channel,session,namespace))
local results={}
local called,issue=pcall(function()
 local receipt={id="qa-likes",effect="Likes",quantity=1,sender=sender,test=true}
 assert(hook:Invoke("submit",session,receipt))
 assert(hook:Invoke("submit",session,receipt),"Receipt replay must be accepted without repeating")
 table.insert(results,"Likes")
 assert(hook:Invoke("submit",session,{id="qa-follow",effect="Follow",quantity=1,sender=sender,test=true,triggerType="follow"}))
 table.insert(results,"Follow")
 local pixels={};for i=1,1024 do pixels[i]=i%2==0 and 0xD47869 or 0x83B891 end
 assert(hook:Invoke("submit",session,{id="qa-profile",kind="Portrait",sender={portraitId=portraitId,pixels=pixels},test=true}))
 assert(kit.LivePortraits:FindFirstChild(portraitId),"Late profile must populate existing portrait registry")
 for _,effect in ipairs({"Rose","Roses","Friendship","Donut","Bear","HeartMe","GoatBusker","HelpGacha","Remove","Speed","Range","Storm","Shrink","WinAdd","WinRemove"})do
  local ok,reason=hook:Invoke("submit",session,{id="qa-"..effect,effect=effect,quantity=1,sender=sender,test=true})
  assert(ok,tostring(effect)..":"..tostring(reason));table.insert(results,effect)
 end
 assert(not hook:Invoke("submit",session..":stale",receipt),"Stale room session must be fenced")
 assert(kit.LiveState:GetAttribute("Transport")=="Tikkies")
end)
hook:Invoke("end",session)
assert(kit.LiveState:GetAttribute("Transport")==nil,"Native fallback must be released after QA")
assert(player:GetAttribute("SavedUsername")==savedUsername,"Tikkies QA must preserve saved native LIVE channel")
assert(called,issue)
return Http:JSONEncode({passed=true,effects=results,effectCount=#results,latePortrait=true,testFollowOnly=true,nativeFallbackReleased=true,savedUsernameUnchanged=true})
