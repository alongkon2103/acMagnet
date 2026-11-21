-- Transport state is separate from native gameplay. No credentials are stored here.
local Client={}
function Client.SanitizeNativeIssue(value,key)
 local raw=tostring(value)
 if type(key)=="string"and #key>0 then raw=raw:gsub((key:gsub("(%W)","%%%1")),"[redacted-key]")end
 raw=raw:gsub("[Hh][Tt][Tt][Pp][Ss]?://%S+","[redacted-url]")
 return raw:sub(1,1000)
end
function Client.HttpIssue(status,reason)
 if type(status)~="number"or status%1~=0 or status<100 or status>599 then return "HTTP_REQUEST_FAILED"end
 local issue="HTTP_"..status
 if type(reason)=="string"and #reason<=64 and reason:match("^[%a][%w_%-]*$")then issue..=":"..reason end
 return issue
end
function Client.SafeIssue(value)
 local raw=tostring(value)
 local status,reason=raw:match("HTTP_(%d%d%d):([%w_%-]+)")
 if status then return Client.HttpIssue(tonumber(status),reason)end
 status=raw:match("HTTP_(%d%d%d)")
 if status then return Client.HttpIssue(tonumber(status))end
 for _,code in ipairs({"HTTP_TIMEOUT","HTTP_DISABLED","HTTP_THROTTLED","HTTP_INVALID_JSON","HTTP_REQUEST_FAILED"})do
  if raw:find(code,1,true)then return code end
 end
 return "HTTP_REQUEST_FAILED"
end
function Client.new(options)
 local gameId=options.gameId
 assert(gameId==nil or type(gameId)=="string"and #gameId>0 and #gameId<=160 and gameId:match("^[%w_%-]+$"),"invalid_game_id")
 local function headers()return gameId and {["X-Tikkies-Game"]=gameId}or {}end
 local binding,pump=nil,nil
 local lastRegistration,failures=nil,0
 local closed=false
 local api={}
 local function same(a,b)
  return a and b and a.id==b.id and a.generation==b.generation and a.ownerRobloxId==b.ownerRobloxId and a.channel==b.channel
 end
 local function present(id)
  for _,value in ipairs(options.players())do if value==id then return true end end
  return false
 end
 local function session(b)return b.id..":"..b.generation end
 local function finish()
  if binding then options.hook("end",session(binding))end
  binding=nil;pump=nil
 end
 local function valid(b)
  return not closed and same(binding,b)and b.expiresAt>options.now()and present(b.ownerRobloxId)
 end
 local function validBinding(value)
  return type(value)=="table"and type(value.id)=="string"and #value.id==36
   and type(value.ownerRobloxId)=="string"and value.ownerRobloxId:match("^%d+$")
   and type(value.channel)=="string"and #value.channel>0 and #value.channel<=24
   and value.channel:match("^[%w_][%w_%.]*$")
   and type(value.generation)=="number"and value.generation>0 and value.generation%1==0
   and type(value.expiresAt)=="number"and value.expiresAt>options.now()
 end
 function api.Step()
  if closed then return 20 end
  if binding and not valid(binding)then finish()end
  local ok,data=pcall(function()
   local now=options.now()
   if not lastRegistration or now-lastRegistration>=8000 then
    options.request("POST","/tikkies/room",{placeId=options.placeId,universeId=options.universeId,players=options.players(),nativeBusy=options.nativeBusy()}, headers())
    lastRegistration=now
   end
   local sentBinding,sentPump=binding,pump
   local acks=sentPump and sentPump.Acks()or {}
   local response=options.request("POST","/tikkies/events",{
    waitMs=1000,limit=100,
    acks=acks,binding=sentBinding and sentBinding.id,generation=sentBinding and sentBinding.generation,
   },headers())
   assert(type(response)=="table","invalid_room_response")
   local nextBinding=response.binding
   if not validBinding(nextBinding)or not present(nextBinding.ownerRobloxId)then
    finish()
   else
    if not same(binding,nextBinding)then
     finish()
     local started=options.hook("begin",nextBinding.ownerRobloxId,nextBinding.channel,session(nextBinding),nextBinding.id)
     if started then
      binding=table.clone(nextBinding)
      local activeBinding=binding
      pump=options.pump({
       valid=function()return valid(activeBinding)end,
       process=function(e)
        if not valid(activeBinding)then return false,"cancelled"end
        return options.hook("submit",session(activeBinding),e)
       end,
      })
     end
    else binding.expiresAt=nextBinding.expiresAt end
    if pump and valid(binding)then
     -- A response from another generation can never confirm this generation's ACKs.
     if sentPump==pump and same(sentBinding,nextBinding)then pump.Confirm(acks)end
     pump.Receive(response.events)
    end
   end
   response.issue=nil -- A successful poll clears old transport failures.
   options.publish(response,binding~=nil,pump and pump.Stats()or nil)
   return response
  end)
  if ok then failures=0;return 1.35 end
  failures+=1
  -- A stale ACK fence must be dropped before the next poll, or every retry is stale.
  if tostring(data):find("HTTP_409",1,true)then finish()end
  options.publish({status="retrying",issue=Client.SafeIssue(data)},binding~=nil,nil)
  return math.min(20,1.35*2^math.min(failures,4))
 end
 function api.Close()
  if closed then return end
  closed=true;finish()
  pcall(options.request,"POST","/tikkies/room/leave",{},headers())
 end
 return api
end
return Client
