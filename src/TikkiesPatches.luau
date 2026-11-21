-- Pure, checked source transforms. Install against current native scripts, never old copies.
local Patch={}
local function once(source,old,new)
 local first,last=source:find(old,1,true)
 assert(first,"Native hook anchor missing: "..old:sub(1,80))
 assert(not source:find(old,last+1,true),"Native hook anchor is ambiguous")
 return source:sub(1,first-1)..new..source:sub(last+1)
end
local bridgeHook=[====[
-- TIKKIES_GATEWAY_V3_BEGIN
local tikkiesDispatch=require(ServerScriptService:WaitForChild("TikkiesDispatch")).new({
 valid=function(playerId,session)
  return tikkiesExternal~=nil and tikkiesExternal.session==session and token==session
   and generation==tikkiesExternal.version and owner==playerId and Players:GetPlayerByUserId(playerId)~=nil
 end,
 sender=filteredSender,
 process=function(e,playerId,session)
  local context=tikkiesExternal
  if not context or context.session~=session then return false,"cancelled"end
  return process(e,playerId,session,context.version)
 end,
 gift=function(effect,sender,amount,receipt,playerId)return gateway:Invoke(effect,sender,amount,receipt,playerId)end,
 helper=function(effect,playerId,sender,amount,receipt)
  local player=Players:GetPlayerByUserId(playerId)
  if not player then return false,"owner_unavailable"end
  local native=ServerScriptService:WaitForChild("BlackHoleServer")
  if effect=="HelpGacha"then return native:WaitForChild("TikkiesHelpGacha"):Invoke(sender,amount,receipt,playerId)
  elseif effect=="WinAdd"or effect=="WinRemove"then
   return native:WaitForChild("TikkiesWinAdjustment"):Invoke(player,effect=="WinAdd"and 1 or -1,receipt)
  elseif effect=="Shrink"then return ServerScriptService:WaitForChild("ArenaSettings"):WaitForChild("Shrink"):Invoke(player)
  else return ServerScriptService:WaitForChild("HelperQueue"):WaitForChild("Enqueue"):Invoke(player,effect)end
 end,
 yield=function()task.wait()end,
})
local tikkiesGateway=Instance.new("BindableFunction")
tikkiesGateway.Name="TikkiesGateway";tikkiesGateway.Parent=script
tikkiesGateway.OnInvoke=function(action,a,b,c,d)
 if action=="status"then return {nativeBusy=token~=nil and tikkiesExternal==nil,external=tikkiesExternal~=nil}end
 if action=="begin"then
  local playerId=type(a)=="string"and a:match("^%d+$")and tonumber(a)or nil
  local player=playerId and Players:GetPlayerByUserId(playerId)
  if not player or type(b)~="string"or #b<1 or #b>24 or not b:match("^[%w_][%w_%.]*$")
   or type(c)~="string"or #c<1 or #c>120 or type(d)~="string"or #d~=36 then return false,"invalid_binding"end
  if tikkiesExternal then
   return tikkiesExternal.session==c and owner==playerId and tikkiesExternal.namespace==d,"room_busy"
  end
  if token or busy then return false,"native_busy"end
  disconnect()
  owner=playerId;token=c
  tikkiesExternal={session=c,version=generation,namespace=d}
  live:SetAttribute("Transport","Tikkies");live:SetAttribute("Username",b);status("LIVE")
  return true
 elseif action=="submit"then
  local context=tikkiesExternal
  if not context or context.session~=a or token~=a or generation~=context.version then return false,"cancelled"end
  if not owner or not Players:GetPlayerByUserId(owner)then return false,"owner_unavailable"end
  if type(b)~="table"or type(b.id)~="string"or type(b.sender)~="table"then return false,"invalid_event"end
  local e=table.clone(b)
  if e.kind=="Portrait"then e.id=context.namespace..":portrait:"..tostring(e.sender.portraitId)
  else
   if #e.id<1 or #e.id>100 then return false,"invalid_event_id"end
   -- Binding UUID36 + colon + external ID100 fits native processor's 140-byte bound.
   e.id=context.namespace..":"..e.id
  end
  return tikkiesDispatch.Submit(e,owner,a)
 elseif action=="end"then
  if tikkiesExternal and tikkiesExternal.session==a then disconnect();return true end
  return false,"cancelled"
 end
 return false,"invalid_action"
end
-- TIKKIES_GATEWAY_V3_END
]====]
local function nativePost(source)
 source=once(source,"local function request(method, path, body, session, acks)\n","local function request(method, path, body, session, acks)\n    -- TIKKIES_NATIVE_POST_V1: Roblox rejects JSON array punctuation in header values.\n    if method==\"GET\" and type(acks)==\"table\" then method=\"POST\";body={acks=acks}end\n")
 return once(source,',["X-Magnet-Ack"]=acks and #acks>0 and Http:JSONEncode(acks)or nil',"")
end
function Patch.Bridge(source)
 if source:find("-- TIKKIES_GATEWAY_V3_BEGIN",1,true)then
  assert(source:find("-- TIKKIES_GATEWAY_V3_END",1,true)and source:find("-- TIKKIES_NATIVE_POST_V1",1,true),"Incomplete Tikkies POST patch")
  return source
 end
 if source:find("-- TIKKIES_GATEWAY_V2_BEGIN",1,true)then
  assert(source:find("-- TIKKIES_GATEWAY_V2_END",1,true),"Incomplete Tikkies gateway patch")
  source=once(source,"-- TIKKIES_GATEWAY_V2_BEGIN","-- TIKKIES_GATEWAY_V3_BEGIN")
  source=once(source,"-- TIKKIES_GATEWAY_V2_END","-- TIKKIES_GATEWAY_V3_END")
  return nativePost(source)
 end
 if source:find("-- TIKKIES_GATEWAY_V1_BEGIN",1,true)then
  assert(source:find("-- TIKKIES_GATEWAY_V1_END",1,true),"Incomplete Tikkies gateway patch")
  -- Upgrade only the external hook. Native LIVE's saved-channel setter stays intact.
  source=once(source,'  require(ServerScriptService:WaitForChild("WinProfile")).SetChannel(player,b)\n',"")
  source=once(source,"-- TIKKIES_GATEWAY_V1_BEGIN","-- TIKKIES_GATEWAY_V3_BEGIN")
  source=once(source,"-- TIKKIES_GATEWAY_V1_END","-- TIKKIES_GATEWAY_V3_END")
  return nativePost(source)
 end
 source=once(source,"local token, generation, cursor, owner = nil, 0, 0, nil","local token, generation, cursor, owner = nil, 0, 0, nil\nlocal tikkiesExternal=nil -- TIKKIES_OWNERSHIP_V1")
 source=once(source,"    local previous=token\n    token=nil; owner=nil; busy=false","    local previous=tikkiesExternal==nil and token or nil\n    tikkiesExternal=nil;live:SetAttribute(\"Transport\",nil)\n    token=nil; owner=nil; busy=false")
 source=once(source,"control.OnServerEvent:Connect(function(player,action,input)",bridgeHook.."\ncontrol.OnServerEvent:Connect(function(player,action,input)\n    if tikkiesExternal then return end -- Tikkies owns this shared arena lease.")
 source=once(source,'    status("CONNECTING");live:SetAttribute("Username",name)','    live:SetAttribute("Transport","Native")\n    status("CONNECTING");live:SetAttribute("Username",name)')
 source=once(source,'game:BindToClose(function() if token then pcall(request,"POST","/disconnect",{},token) end end)','game:BindToClose(function() if token and not tikkiesExternal then pcall(request,"POST","/disconnect",{},token) end end)')
 return nativePost(source)
end
local serverHook=[====[
-- TIKKIES_GAME_GATEWAYS_V1_BEGIN
local tikkiesHelpGacha=Instance.new("BindableFunction")
tikkiesHelpGacha.Name="TikkiesHelpGacha";tikkiesHelpGacha.Parent=script
tikkiesHelpGacha.OnInvoke=function(sender,quantity,eventId,requesterUserId)
 local player=type(requesterUserId)=="number"and Players:GetPlayerByUserId(requesterUserId)or nil
 if not player then return false,"owner_unavailable"end
 if type(quantity)~="number"or quantity~=quantity or quantity%1~=0 or quantity<1 or quantity>100 then return false,"invalid_quantity"end
 if type(eventId)~="string"or #eventId<1 or #eventId>160 then return false,"invalid_event_id"end
 if seen[eventId]then return false,"duplicate"end
 if type(sender)~="table"or type(sender.name)~="string"or #sender.name>160 then return false,"invalid_sender"end
 local clean={name=sender.name,seed=tonumber(sender.seed)or 1,blockScale=1}
 if clean.seed~=clean.seed or math.abs(clean.seed)>2147483646 then clean.seed=1 end
 if type(sender.avatarId)=="string"and((#sender.avatarId==33 and sender.avatarId:match("^p%x+$"))or kit.LivePortraits:FindFirstChild(sender.avatarId))then clean.avatarId=sender.avatarId end
 if type(sender.nameId)=="string"and kit.LiveNames:FindFirstChild(sender.nameId)then clean.nameId=sender.nameId end
 local ok,reason=gachaQueue.Submit(player,"Help",clean,quantity,{paid=true,giftId="HelpGacha"})
 if not ok then return false,reason end
 seen[eventId]=workspace:GetServerTimeNow();sync();return true
end
local tikkiesWinAdjustment=Instance.new("BindableFunction")
tikkiesWinAdjustment.Name="TikkiesWinAdjustment";tikkiesWinAdjustment.Parent=script
tikkiesWinAdjustment.OnInvoke=function(player,delta,eventId)
 if not player or player.Parent~=Players then return false,"owner_unavailable"end
 if delta~=1 and delta~=-1 then return false,"invalid_quantity"end
 if type(eventId)~="string"or #eventId<1 or #eventId>160 then return false,"invalid_event_id"end
 if seen[eventId]then return false,"duplicate"end
 table.insert(winQueue,{player=player,delta=delta})
 state:SetAttribute("WinAdjustmentQueue",#winQueue)
 seen[eventId]=workspace:GetServerTimeNow();playWinQueue();return true
end
-- TIKKIES_GAME_GATEWAYS_V1_END
]====]
function Patch.Server(source)
 if source:find("-- TIKKIES_GAME_GATEWAYS_V1_BEGIN",1,true)then
  assert(source:find("-- TIKKIES_GAME_GATEWAYS_V1_END",1,true),"Incomplete Tikkies game gateway patch")
  return source
 end
 return once(source,"gateway.OnInvoke = accept","gateway.OnInvoke = accept\n"..serverHook)
end
return Patch
