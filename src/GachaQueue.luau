-- One authoritative queue for keyboard and authenticated LIVE gacha.
local Queue={MaxBatch=32,MaxGiftBatch=100,MaxPending=128}
function Queue.new(options)
 local jobs,counts={},{}
 local paidJobs,paidHead,paidTail={},1,0
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
   while pendingUnits>0 do
    local job
    if paidHead<=paidTail then
     job=paidJobs[paidHead];paidJobs[paidHead]=nil;paidHead+=1
     if paidHead>paidTail then table.clear(paidJobs);paidHead=1;paidTail=0 end
    else job=table.remove(jobs,1)end
    pendingUnits-=1
    local player=job.player
    counts[player]=math.max(0,(counts[player] or 1)-1)
    update(player)
    if not player.Parent and not job.paid then continue end
    local mode=job.mode
    local reward
    if mode=="Mixed" and options.items then reward=options.items.Roll(random);mode=reward.mode
    else
     if mode=="Mixed"then mode=random:NextNumber()<.5 and "Prank" or "Help"end
     reward=options.rewards.Roll(random)
    end
    local function payload()
     return {rollId=job.id,mode=mode,requestedMode=job.mode,sender=table.clone(job.sender),
      name=job.sender.name,giftId=job.giftId,itemId=reward.id,amount=reward.amount,tier=reward.tier,chance=reward.weight}
    end
    local rollSeconds=options.rewards.RollSeconds
    if job.paid then rollSeconds=math.min(rollSeconds,pendingUnits>=10 and .2 or pendingUnits>0 and .45 or .9)end
    local rolling=payload();rolling.duration=rollSeconds
    options.fire("Roll",rolling)
    wait(rollSeconds)
    local actual,meteorEnds=0,nil
    local function waiting(value)
     if player.Parent then player:SetAttribute("GachaWaiting",value)end
    end
    if reward.id then
     repeat
      local ok,value,ends=pcall(function()
       local target=options.resolvePlayer and options.resolvePlayer(player,job.paid)or player
       return options.applyItem(reward,target,job.sender,job.id,{paid=job.paid})
      end)
      actual=ok and value or 0;meteorEnds=ok and ends or nil
      if actual<=0 and job.paid then waiting(true);wait(.2)end
     until actual>0 or not job.paid
    elseif mode=="Prank"then
     local sender=table.clone(job.sender)
     sender.blockScale=1;sender.gachaTier=reward.tier
     repeat
      local ok,credited=pcall(options.add,reward.amount-actual,sender)
      actual+=math.clamp(ok and credited or 0,0,reward.amount-actual)
      if actual<reward.amount and job.paid then waiting(true);wait(.2)end
     until actual>=reward.amount or not job.paid
    else
     local target=options.resolvePlayer and options.resolvePlayer(player,job.paid)or player
     actual=options.remove(target,reward.amount)
    end
    waiting(false)
    if not reward.id and reward.amount==2000 and actual>0 then meteorEnds=options.meteor(actual)end
    options.sync()
    local result=payload();result.actual=actual;result.meteor=meteorEnds~=nil
    options.fire("Result",result)
    if job.paid then
     wait(math.min(options.rewards.ResultSeconds,pendingUnits>0 and .15 or .65))
    else wait(math.max(options.rewards.ResultSeconds,(meteorEnds or 0)-now()))end
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
   local job={id=serial,player=player,mode=mode,sender=table.clone(sender),paid=paid,giftId=context.giftId}
   if paid then paidTail+=1;paidJobs[paidTail]=job else table.insert(jobs,job)end
  end
  counts[player]=(counts[player] or 0)+quantity
  pendingUnits+=quantity
  update(player)
  run()
  return true
 end
 function api.RemovePlayer(player)
  local retained=0
  for i=paidHead,paidTail do if paidJobs[i].player==player then retained+=1 end end
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
