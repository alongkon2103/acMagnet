-- Apply narrowly to the existing Studio game; retain its current UI, powers and round logic.
local SSS=game:GetService("ServerScriptService")
local kit=game:GetService("ReplicatedStorage"):WaitForChild("BlackHole")
local function replace(source,old,new)
 if source:find(new,1,true) then return source end
 local first,last=source:find(old,1,true)
 assert(first,"Latency patch does not match current source: "..old)
 return source:sub(1,first-1)..new..source:sub(last+1)
end
local bridge=SSS.TikTokBridge.Source
bridge=replace(bridge,[==[    local pixels=sender.pixels]==],[==[    local requested=sender.portraitId
    if type(requested)~="string" or #requested~=33 or not requested:match("^p%x+$") then requested=nil end
    local pixels=sender.pixels]==])
bridge=replace(bridge,[==[if type(pixels)~="table" or (#pixels~=256 and #pixels~=1024) then return nil end]==],[==[if type(pixels)~="table" or (#pixels~=256 and #pixels~=1024) then return requested end]==])
bridge=replace(bridge,[==[local id="p"..hash]==],[==[local id=requested or ("p"..hash)]==])
if not bridge:find('if e.kind=="Portrait"',1,true) then
 if bridge:find('    local following=isFollow(e)',1,true) then
  bridge=replace(bridge,[==[    local following=isFollow(e)]==],[==[    if e.kind=="Portrait" then portrait(e.sender);return true end
    local following=isFollow(e)]==])
 else
  bridge=replace(bridge,'    if type(e.quantity)~="number"', '    if e.kind=="Portrait" then portrait(e.sender);return true end\n    if type(e.quantity)~="number"')
 end
end
bridge=replace(bridge,[==[task.wait(math.min(10,config.PollSeconds*math.max(1,failures)))]==],[==[task.wait(failures>0 and math.min(10,math.max(.2,config.PollSeconds)*failures) or (data and data.hasMore and .03 or math.min(.2,config.PollSeconds)))]==])
bridge=replace(bridge,'"/connect",{username=name},session','"/connect",{username=name,protocol=2},session')
local server=SSS.BlackHoleServer.Source
server=replace(server,'if type(sender.avatarId)=="string" and kit.LivePortraits:FindFirstChild(sender.avatarId) then cleanSender.avatarId=sender.avatarId end','if type(sender.avatarId)=="string" and ((#sender.avatarId==33 and sender.avatarId:match("^p%x+$")) or kit.LivePortraits:FindFirstChild(sender.avatarId)) then cleanSender.avatarId=sender.avatarId end')
server=replace(server,'enqueue(gift.Blocks * quantity, cleanSender, playMeteor and now+2.3 or 0)','enqueue(gift.Blocks * quantity, cleanSender, 0)')
-- Keep the existing bear cinematic and smooth expansion; the block queue starts immediately.
local config=kit.Config.Source
config=replace(config,'Friendship = {Name =','Friendship = {GiftId = 9947, Name =')
config=replace(config,'Donut = {Name =','Donut = {GiftId = 5879, Name =')
-- Update only the polling value. Never copy credentials into the patch or logs.
local live=SSS.LiveConfig.Source
local n
live,n=live:gsub("PollSeconds%s*=%s*[%d%.]+","PollSeconds = 0.2")
assert(n==1,"PollSeconds field not found")
-- Validate all replacements before modifying any source, and retain a complete rollback.
local backup=Instance.new("Folder")
backup.Name="BeforeLiveLatencyFix_"..os.date("!%Y%m%d_%H%M%S")
backup.Parent=game:GetService("ServerStorage")
for _,obj in {SSS.TikTokBridge,SSS.BlackHoleServer,SSS.LiveConfig,kit.Config}do obj:Clone().Parent=backup end
SSS.TikTokBridge.Source=bridge
SSS.BlackHoleServer.Source=server
kit.Config.Source=config
SSS.LiveConfig.Source=live
return "Installed live delivery patch; backup: "..backup.Name
