local Patch=require("../../src/TikkiesPatches")
local fixtures=require("../fixtures/tikkies-native-fixtures")
local source=Patch.Bridge(fixtures.bridge)
local first=assert(source:find("local function request(method, path, body, session, acks)",1,true))
local last=assert(source:find("\nend\n",first,true))
local calls={}
local env=setmetatable({
 config={BridgeUrl="https://example.invalid",BridgeKey="synthetic-map-key"},
 Http={JSONEncode=function(_,value)return value end,JSONDecode=function(_,value)return value end,
  RequestAsync=function(_,options)table.insert(calls,options);return {Success=true,Body={ok=true}}end},
},{__index=getfenv()})
local chunk=assert(loadstring(source:sub(first,last+4).."\nreturn request"));setfenv(chunk,env)
local request=chunk()
assert(request("GET","/session/events?limit=100&waitMs=1000",nil,"native-session",{2,3}).ok)
assert(calls[1].Method=="POST"and calls[1].Body.acks[1]==2 and calls[1].Body.acks[2]==3,"Native reliable ACKs must use JSON POST body")
assert(calls[1].Headers["X-Magnet-Ack"]==nil,"JSON ACK values are rejected by Roblox HTTP headers")
assert(calls[1].Headers["X-Magnet-Session"]=="native-session"and calls[1].Url=="https://example.invalid/session/events?limit=100&waitMs=1000","Native auth scope and poll query must remain unchanged")
request("GET","/session/events?after=42",nil,"native-session",nil)
assert(calls[2].Method=="GET"and calls[2].Body==nil,"Legacy nonreliable cursor transport must remain GET")
request("POST","/connect",{username="viewer"},"native-session",nil)
assert(calls[3].Body.username=="viewer"and calls[3].Method=="POST")
print("PASS native fallback POST: reliable ACK body, unchanged auth/query, legacy cursor compatibility")
