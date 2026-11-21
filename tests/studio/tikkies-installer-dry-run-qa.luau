local fixture=require("../fixtures/tikkies-native-fixtures")
local Patch=require("../../src/TikkiesPatches")
local function scriptObject(source,class)
 return {Source=source,ClassName=class or "ModuleScript",IsA=function(_,kind)return kind=="LuaSourceContainer"end}
end
local installed=false
local originals={TikTokBridge=scriptObject(fixture.bridge,"Script"),BlackHoleServer=scriptObject(fixture.server,"Script")}
local stageObjects={s0=scriptObject(fixture.dispatch),s1=scriptObject(fixture.roomClient),s2=scriptObject(fixture.controller),s3=scriptObject(fixture.patches)}
local stage={GetAttribute=function()return true end,FindFirstChild=function(_,name)return stageObjects[name]end}
local storage={FindFirstChild=function(_,name)return name=="TikkiesStage_20261121"and stage or nil end}
local services={
 RunService={IsRunning=function()return false end},
 ServerScriptService={FindFirstChild=function(_,name)return originals[name]end},
 HttpService={JSONEncode=function(_,value)return value end},
}
local fakeGame={PlaceId=113965026399564,GameId=10775380860,ServerStorage=storage,GetService=function(_,name)return services[name]end}
local env=setmetatable({game=fakeGame,Instance={new=function()installed=true;error("Dry run attempted a mutation")end}},{__index=getfenv()})
local function run()local fn=assert(loadstring(fixture.installer));setfenv(fn,env);return fn()end
local result=run()
assert(result.dryRun and result.compiled==5 and #result.changes==5 and not installed,"Dry run must compile all targets without installing")
originals.TikTokBridge.Source=Patch.Bridge(fixture.bridge)
originals.BlackHoleServer.Source=Patch.Server(fixture.server)
originals.TikkiesDispatch=scriptObject(fixture.dispatch)
originals.TikkiesRoomClient=scriptObject(fixture.roomClient)
originals.TikkiesBridge=scriptObject(fixture.controller,"Script")
originals.TikTokBridge.Source=fixture.bridgeV1
local upgrade=run()
assert(#upgrade.changes==1 and upgrade.changes[1]=="TikTokBridge","V1 upgrade must change only the external bridge hook")
originals.TikTokBridge.Source=Patch.Bridge(fixture.bridgeV1)
assert(#run().changes==0,"Installed sources must produce an empty idempotent dry run")
originals.TikTokBridge.Source=originals.TikTokBridge.Source.."\n-- newer user work"
assert(not pcall(run),"Unreviewed native drift must abort before mutation")
assert(not installed)
print("PASS Tikkies installer: full dry run, idempotence, exact native drift fence, no mutations")
