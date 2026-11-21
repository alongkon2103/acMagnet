local Client=require("../../src/TikkiesRoomClient")
local published={}
local fail=true
local c=Client.new({
 now=function()return 0 end,players=function()return {"42"}end,nativeBusy=function()return false end,
 request=function(_,path)
  if path=="/tikkies/events"and fail then error("HTTP_400:INVALID_ACK",0)end
  return {status="WAITING",events={}}
 end,
 hook=function()return true end,pump=function()error("No binding in diagnostics test")end,
 publish=function(value)table.insert(published,value)end,
})
c.Step()
assert(published[1].issue=="HTTP_400:INVALID_ACK","Native ACK failures must preserve safe HTTP status and server error code")
fail=false;c.Step()
assert(published[2].issue==nil,"A successful poll must clear the stale HTTP issue")
assert(Client.HttpIssue(400,"INVALID_ACK")=="HTTP_400:INVALID_ACK")
assert(Client.HttpIssue(503,"https://private.example/?key=do-not-print")=="HTTP_503","Response URLs and arbitrary bodies must never enter diagnostics")
assert(Client.SafeIssue("Script:99: HTTP_409:STALE_BINDING")=="HTTP_409:STALE_BINDING")
assert(Client.SafeIssue("request to https://private.example/?key=do-not-print failed")=="HTTP_REQUEST_FAILED")
assert(Client.SafeIssue("HTTP_400:INVALID_ACK https://private.example")=="HTTP_400:INVALID_ACK")
assert(Client.SanitizeNativeIssue("header failed https://private.example/a?x=1 key do-not-print","do-not-print")=="header failed [redacted-url] key [redacted-key]","Exact native errors must redact actual map key and every URL")
print("PASS Tikkies HTTP diagnostics: exact safe codes, credential/URL exclusion, stale issue clearing")
