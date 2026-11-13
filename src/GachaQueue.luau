-- One authoritative queue for keyboard and authenticated LIVE gacha.
local Queue={MaxBatch=32,MaxGiftBatch=100,MaxPending=128}
function Queue.new(options)
 local jobs,counts={},{}
 local running=false
 local serial=0
 local pendingUnits=0
 local paidLimit=options.paidLimit or 50000
 local random=options.random or Random.new()
 local spawn=options.spawn or task.spawn
 local wait=options.wait or task.wait
 local now=options.now or function()return workspace:GetServerTimeNow()end
 local function update(player)
  if player.Parent then player:SetAttribute("GachaQueue",counts[player] or 0)end
 end
 local function run()
  if running then return end
  running=true
  spawn(function()
   while #jobs>0 do
    local job=table.remove(jobs,1)
    pendingUnits-=1
    local player=job.player
    counts[player]=math.max(0,(counts[player] or 1)-1)
    update(player)
    if not player.Parent and not job.paid then continue end
    local mode=job.mode
    if mode=="Mixed"then mode=random:NextNumber()<.5 and "Prank" or "Help"end
    local reward=options.rewards.Roll(random)
    local function payload()
     return {rollId=job.id,mode=mode,requestedMode=job.mode,sender=table.clone(job.sender),
      name=job.sender.name,giftId=job.giftId,amount=reward.amount,tier=reward.tier,chance=reward.weight}
    end
    local rolling=payload();rolling.duration=options.rewards.RollSeconds
    options.fire("Roll",rolling)
    wait(options.rewards.RollSeconds)
    local actual
    if mode=="Prank"then
     local sender=table.clone(job.sender)
     sender.blockScale=1;sender.gachaTier=reward.tier
     actual=options.add(reward.amount,sender)
    else actual=options.remove(player,reward.amount)end
    local meteorEnds
    if reward.amount==2000 and actual>0 then meteorEnds=options.meteor(actual)end
    options.sync()
    local result=payload();result.actual=actual;result.meteor=meteorEnds~=nil
    options.fire("Result",result)
    wait(math.max(options.rewards.ResultSeconds,(meteorEnds or 0)-now()))
    if not player.Parent and (counts[player] or 0)==0 then counts[player]=nil end
   end
   running=false
  end)
 end
 local api={}
 function api.Submit(player,mode,sender,quantity,context)
  context=context or {}
  local paid=context.paid==true
  if mode~="Mixed" and mode~="Prank" and mode~="Help"then return false,"invalid_gacha_mode"end
  if type(quantity)~="number" or quantity~=quantity or quantity%1~=0 or quantity<1 or quantity>(paid and Queue.MaxGiftBatch or Queue.MaxBatch) then return false,"invalid_quantity"end
  if not player or not player.Parent then return false,"owner_unavailable"end
  if type(sender)~="table" or type(sender.name)~="string" or #sender.name>160 then return false,"invalid_sender"end
  local globalLimit=paid and paidLimit or Queue.MaxPending
  local playerLimit=paid and paidLimit or Queue.MaxBatch
  if pendingUnits+quantity>globalLimit or (counts[player] or 0)+quantity>playerLimit then return false,"gacha_queue_full"end
  for _=1,quantity do
   serial+=1
   table.insert(jobs,{id=serial,player=player,mode=mode,sender=table.clone(sender),paid=context.paid==true,giftId=context.giftId})
  end
  counts[player]=(counts[player] or 0)+quantity
  pendingUnits+=quantity
  update(player)
  run()
  return true
 end
 function api.RemovePlayer(player)
  local retained=0
  for i=#jobs,1,-1 do
   local job=jobs[i]
   if job.player==player then
    if job.paid then retained+=1 else table.remove(jobs,i);pendingUnits-=1 end
   end
  end
  counts[player]=retained>0 and retained or nil
 end
 return api
end
return Queue
