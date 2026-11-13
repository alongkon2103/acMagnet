-- Studio MCP Server command. Exercise the real bridge processor with a controlled server-only gateway.
local Http=game:GetService("HttpService")
local source=game.ServerScriptService.TikTokBridge.Source
local boundary=assert(source:find("control.OnServerEvent:Connect",1,true))
source=source:sub(1,boundary-1)
local old='local gateway = ServerScriptService:WaitForChild("BlackHoleServer"):WaitForChild("SubmitGift")'
local a,b=assert(source:find(old,1,true))
source=source:sub(1,a-1)..'local gateway=script:WaitForChild("Gateway")'..source:sub(b+1)
local module=Instance.new("ModuleScript")
module.Source=source..'\ntoken="qa";generation=1;return function(e,id)return process(e,id,"qa",1)end'
local gateway=Instance.new("BindableFunction");gateway.Name="Gateway";gateway.Parent=module
local accepted,attempts={},{}
local blocked=true
local granted=0
gateway.OnInvoke=function(key,sender,quantity,id,owner)
 table.insert(attempts,{id=id,quantity=quantity,owner=owner})
 if accepted[id]then return false,"duplicate"end
 if blocked and id:sub(-2)==":2"then return false,"gacha_queue_full"end
 accepted[id]={key=key,quantity=quantity,owner=owner,sender=sender}
 granted+=quantity
 return true
end
module.Parent=game.ServerStorage
local process=require(module)
local user=game.Players:GetPlayers()[1].UserId
local receipt={id="batch-replay",giftId="HeartMe",quantity=201,sender={name="@batch_sender",seed=12,portraitId="p"..string.rep("e",32)}}
local ok,reason=process(receipt,user)
assert(not ok and reason=="gacha_queue_full")
assert(accepted["batch-replay:1"].quantity==100 and not accepted["batch-replay:2"])
-- Model a retry after the server's one-hour deduplication retention expired.
table.clear(accepted)
blocked=false
assert(process(receipt,user))
assert(accepted["batch-replay:2"].quantity==100 and accepted["batch-replay:3"].quantity==1)
for _,e in accepted do assert(e.owner==user and e.sender.avatarId==receipt.sender.portraitId)end
assert(granted==201,"Expired dedup records must not cause accepted chunks to reroll")
assert(#attempts==4,"Retry must resume chunk2 rather than replay chunk1")
module:Destroy()
return Http:JSONEncode({passed=true,totalUnits=granted,attempts=#attempts,ownerContext=true,portraitContext=true,expiredDedupSafe=true})
