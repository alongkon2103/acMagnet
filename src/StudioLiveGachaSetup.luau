-- Run in Edit mode after installing GachaQueue (ServerScriptService) and GachaSenderBadge (BlackHole).
assert(not game:GetService("RunService"):IsRunning(),"Stop Play before installing")
local SSS=game:GetService("ServerScriptService")
local kit=game.ReplicatedStorage:WaitForChild("BlackHole")
assert(SSS:FindFirstChild("GachaQueue") and kit:FindFirstChild("GachaSenderBadge"),"Install the two new modules first")
local function replace(source,old,new)
 if source:find(new,1,true)then return source end
 local a,b=source:find(old,1,true)
 assert(a,"Existing Studio source changed; cannot match: "..old)
 return source:sub(1,a-1)..new..source:sub(b+1)
end
local function edits(source,list)
 for _,edit in list do source=replace(source,edit[1],edit[2])end
 return source
end
local server=SSS.BlackHoleServer.Source
if not server:find('local GachaQueue=require',1,true)then
 local a=assert(server:find('local gacha=kit:WaitForChild("BlockGacha")',1,true))
 local b=assert(server:find('local function accept(',a,true))
 server=server:sub(1,a-1)..[====[local gacha=kit:WaitForChild("BlockGacha")
local gachaCooldown={}
local GachaQueue=require(script.Parent:WaitForChild("GachaQueue"))
local function removeGachaBlocks(player,amount)
 local removed=removeTen(player,amount)
 local left=amount-removed
 while left>0 and #queue>0 do
  local job=queue[1]
  local take=math.min(left,job.remaining)
  job.remaining-=take
  pending-=take
  left-=take
  removed+=take
  consumed+=take
  if job.remaining==0 then table.remove(queue,1) end
 end
 sync()
 return removed
end

local gachaQueue=GachaQueue.new({
 rewards=require(kit:WaitForChild("GachaRewards")),paidLimit=Config.MaxPending,
 fire=function(kind,data)gacha:FireAllClients(kind,data)end,
 add=function(amount,sender)
  local actual=math.min(amount,math.max(0,Config.MaxPending-pending))
  if actual>0 then enqueue(actual,sender)end
  return actual
 end,
 remove=removeGachaBlocks,meteor=playBlockMeteor,sync=sync,
})
gacha.OnServerEvent:Connect(function(player,mode)
 if mode~="Prank" and mode~="Help" and mode~="Mixed" then return end
 if player:GetAttribute("CanUseMagnetBoost")~=true and not operator(player) then return end
 local now=os.clock()
 if now-(gachaCooldown[player] or -math.huge)<.12 then return end
 gachaCooldown[player]=now
 local ok,reason=gachaQueue.Submit(player,mode,{name=player.DisplayName,seed=player.UserId,userId=player.UserId},1)
 if not ok and reason=="gacha_queue_full" then gacha:FireClient(player,"Full")end
end)
Players.PlayerRemoving:Connect(function(player)
 gachaCooldown[player]=nil
 gachaQueue.RemovePlayer(player)
end)

]====]..server:sub(b)
end
server=replace(server,'rewards=require(kit:WaitForChild("GachaRewards")),','rewards=require(kit:WaitForChild("GachaRewards")),paidLimit=Config.MaxPending,')
server=edits(server,{
{[====[local function accept(giftId, sender, quantity, eventId)]====],[====[local function accept(giftId, sender, quantity, eventId, requesterUserId)]====]},
{[====[    if type(sender.avatarId)=="string" and ((#sender.avatarId==33 and sender.avatarId:match("^p%x+$")) or kit.LivePortraits:FindFirstChild(sender.avatarId)) then cleanSender.avatarId=sender.avatarId end]====],[====[    if type(sender.avatarId)=="string" and ((#sender.avatarId==33 and sender.avatarId:match("^p%x+$")) or kit.LivePortraits:FindFirstChild(sender.avatarId)) then cleanSender.avatarId=sender.avatarId end
    if gift.GachaMode then
        local player=type(requesterUserId)=="number" and Players:GetPlayerByUserId(requesterUserId) or nil
        local ok,reason=gachaQueue.Submit(player,gift.GachaMode,cleanSender,quantity,{paid=true,giftId=giftId})
        if not ok then return false,reason end
        seen[eventId]=workspace:GetServerTimeNow()
        sync()
        return true
    end]====]}
})
server=replace(server,"-- Server-authoritative free block gacha. The client supplies only the mode.","-- Shared server-authoritative gacha for keyboard controls and authenticated LIVE gifts.")
local bridge=SSS.TikTokBridge.Source
if not bridge:find("local receiptProgress",1,true)then
 bridge=replace(bridge,'gateway:Invoke(e.giftId,sender,amount,e.id..":"..chunk)','gateway:Invoke(e.giftId,sender,amount,e.id..":"..chunk,playerId)')
 bridge=replace(bridge,"local function process(e, playerId, session, version)","local receiptProgress\nlocal function process(e, playerId, session, version)")
 if bridge:find([====[    -- Existing gateway accepts at most 100 per receipt. Retry retains stable chunk IDs.
    local left=e.quantity
    local chunk=0
    while left>0 do
        chunk+=1
        local gift=require(kit.Config).Gifts[e.giftId]
        if not gift then return false,"unknown_gift" end
        local amount=math.min(left,math.min(gift.GachaMode and 32 or 100,math.floor(require(kit.Config).MaxPending/(gift.Blocks or 1))))
        local ok,reason=gateway:Invoke(e.giftId,sender,amount,e.id..":"..chunk,playerId)
        if not ok and reason~="duplicate" then return false,reason end
        left-=amount
    end
]====],1,true)then
  bridge=replace(bridge,[====[    -- Existing gateway accepts at most 100 per receipt. Retry retains stable chunk IDs.
    local left=e.quantity
    local chunk=0
    while left>0 do
        chunk+=1
        local gift=require(kit.Config).Gifts[e.giftId]
        if not gift then return false,"unknown_gift" end
        local amount=math.min(left,math.min(gift.GachaMode and 32 or 100,math.floor(require(kit.Config).MaxPending/(gift.Blocks or 1))))
        local ok,reason=gateway:Invoke(e.giftId,sender,amount,e.id..":"..chunk,playerId)
        if not ok and reason~="duplicate" then return false,reason end
        left-=amount
    end
]====],[====[    -- Resume the failed chunk even if a long queue outlives gateway dedup retention.
    local progress=receiptProgress
    if not progress or progress.id~=e.id or progress.session~=session or progress.version~=version then
        progress={id=e.id,session=session,version=version,left=e.quantity,chunk=1}
        receiptProgress=progress
    end
    while progress.left>0 do
        if token~=session or generation~=version then return false,"cancelled" end
        local gift=require(kit.Config).Gifts[e.giftId]
        if not gift then return false,"unknown_gift" end
        local amount=math.min(progress.left,math.min(100,math.floor(require(kit.Config).MaxPending/(gift.Blocks or 1))))
        local ok,reason=gateway:Invoke(e.giftId,sender,amount,e.id..":"..progress.chunk,playerId)
        if not ok and reason~="duplicate" then return false,reason end
        progress.left-=amount
        progress.chunk+=1
    end
    receiptProgress=nil
]====])
 else
  bridge=replace(bridge,[====[    -- Existing gateway accepts at most 100 per receipt. Retry retains stable chunk IDs.
    local left=e.quantity
    local chunk=0
    while left>0 do
        chunk+=1
        local gift=require(kit.Config).Gifts[e.giftId]
        if not gift then return false,"unknown_gift" end
        local amount=math.min(left,math.min(100,math.floor(require(kit.Config).MaxPending/(gift.Blocks or 1))))
        local ok,reason=gateway:Invoke(e.giftId,sender,amount,e.id..":"..chunk,playerId)
        if not ok and reason~="duplicate" then return false,reason end
        left-=amount
    end
]====],[====[    -- Resume the failed chunk even if a long queue outlives gateway dedup retention.
    local progress=receiptProgress
    if not progress or progress.id~=e.id or progress.session~=session or progress.version~=version then
        progress={id=e.id,session=session,version=version,left=e.quantity,chunk=1}
        receiptProgress=progress
    end
    while progress.left>0 do
        if token~=session or generation~=version then return false,"cancelled" end
        local gift=require(kit.Config).Gifts[e.giftId]
        if not gift then return false,"unknown_gift" end
        local amount=math.min(progress.left,math.min(100,math.floor(require(kit.Config).MaxPending/(gift.Blocks or 1))))
        local ok,reason=gateway:Invoke(e.giftId,sender,amount,e.id..":"..progress.chunk,playerId)
        if not ok and reason~="duplicate" then return false,reason end
        progress.left-=amount
        progress.chunk+=1
    end
    receiptProgress=nil
]====])
 end
end
if not bridge:find('{username=name,protocol=2,gacha=true,follow=true},session',1,true)then
 if bridge:find('{username=name,protocol=2,gacha=true},session',1,true)then
  bridge=replace(bridge,'{username=name,protocol=2,gacha=true},session','{username=name,protocol=2,gacha=true,follow=true},session')
 else
  bridge=replace(bridge,'{username=name,protocol=2},session','{username=name,protocol=2,gacha=true,follow=true},session')
 end
end
assert(bridge:find('local followGuard',1,true) and SSS:FindFirstChild('FollowRewardGuard'),'Existing follow guard is required')
assert(kit.Config.Source:find('Follow =',1,true),'Existing Follow +10 rule is required')

local client=edits(game.StarterPlayer.StarterPlayerScripts.BlockGachaClient.Source,{
{[====[gui.Parent=player:WaitForChild("PlayerGui")]====],[====[gui.Parent=player:WaitForChild("PlayerGui")
local senderBadge=require(kit:WaitForChild("GachaSenderBadge")).Create(gui)]====]},
{[====[  owner.Text=data.name]====],[====[  owner.Text=data.name
  senderBadge.Show(data.sender or {name=data.name})]====]},
{[====[ elseif kind=="Result" then
  serial+=1;local token=serial]====],[====[ elseif kind=="Result" then
  serial+=1;local token=serial
  if not senderBadge.Root.Visible then senderBadge.Show(data.sender or {name=data.name})end]====]},
{[====[if serial==token then panel.Visible=false;panel:SetAttribute("Phase","Idle")end]====],[====[if serial==token then panel.Visible=false;panel:SetAttribute("Phase","Idle");senderBadge.Hide()end]====]}
})
local config=kit.Config.Source
if not config:find("HeartMe =",1,true)then config=replace(config,"    },\n    Order =",[====[        HeartMe = {GiftId = 7934, Name = "Heart Me", Coins = 1, GachaMode = "Mixed"},
        GoatBusker = {GiftId = 626064, Name = "G.O.A.T. Busker", Coins = 20, GachaMode = "Prank"},
    },
    Order =]====])end
local portraits=kit.PixelPortrait.Source
if not portraits:find("function module.Get(",1,true)then portraits=replace(portraits,"return module","function module.Get(id)return get(id)end\nreturn module")end
local changes={{SSS.BlackHoleServer,server},{SSS.TikTokBridge,bridge},{game.StarterPlayer.StarterPlayerScripts.BlockGachaClient,client},{kit.Config,config},{kit.PixelPortrait,portraits}}
for _,entry in changes do assert(loadstring(entry[2],entry[1].Name))end
local backup=Instance.new("Folder")
backup.Name="BeforeLiveGacha_"..os.date("!%Y%m%d_%H%M%S")
backup.Parent=game.ServerStorage
for _,entry in changes do entry[1]:Clone().Parent=backup end
for _,entry in changes do entry[1].Source=entry[2]end
return "Installed LIVE gacha; backup: "..backup.Name
