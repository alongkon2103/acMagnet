-- Run in Edit mode against the current native Studio project.
assert(not game:GetService("RunService"):IsRunning(),"Stop Play before installing")
local SSS=game:GetService("ServerScriptService")
local kit=game.ReplicatedStorage:WaitForChild("BlackHole")
assert(SSS:FindFirstChild("LikeRewardCounter"),"LikeRewardCounter module is required")
local config=kit.Config.Source
local n
config,n=config:gsub("LikesPerReward%s*=%s*%d+","LikesPerReward = 150",1)
assert(n==1,"LikesPerReward field not found")
config,n=config:gsub('(Likes%s*=%s*%{.-Name%s*=%s*)"[^"]*"','%1"กดใจ 150 ครั้ง"',1)
assert(n==1,"Likes display rule not found")
config,n=config:gsub("LikeRewardsEnabled%s*=%s*%a+","LikeRewardsEnabled = true",1)
assert(n==1,"LikeRewardsEnabled field not found")
local bridge=SSS.TikTokBridge.Source
bridge,n=bridge:gsub('("/connect",%s*)(%b{})',function(prefix,body)
 if body:find("rawLikes%s*=")then
  body=body:gsub("rawLikes%s*=%s*%a+","rawLikes=true")
 else body=body:sub(1,-2)..",rawLikes=true}"end
 return prefix..body
end,1)
assert(n==1,"LIVE connect request not found")
assert(loadstring(bridge,"TikTokBridge"))
local parse=assert(loadstring(config,"Config"))
local parsed=parse()
assert(parsed.LikesPerReward==150 and parsed.Gifts.Likes.Blocks==10 and parsed.LikeRewardsEnabled)
local backup=Instance.new("Folder")
backup.Name="BeforeLikes150_"..os.date("!%Y%m%d_%H%M%S").."_"..game.HttpService:GenerateGUID(false):sub(1,8)
backup.Parent=game.ServerStorage
SSS.TikTokBridge:Clone().Parent=backup
kit.Config:Clone().Parent=backup
SSS.TikTokBridge.Source=bridge
kit.Config.Source=config
return "Installed150 likes =10 blocks with raw-likes delivery; backup: "..backup.Name
