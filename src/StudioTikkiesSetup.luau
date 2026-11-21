-- Stage the FOUR exact source files below as ModuleScripts s0..s3 in
-- ServerStorage.TikkiesStage_20261121. DryRun defaults true; explicitly set false
-- only after reviewing the dry-run result. This script never reads LiveConfig.
assert(not game:GetService("RunService"):IsRunning(),"Stop Play before installing Tikkies")
assert(game.PlaceId==113965026399564 and game.GameId==10775380860,"This installer is only for AC Magnet")
local stage=assert(game.ServerStorage:FindFirstChild("TikkiesStage_20261121"),"Tikkies staging folder missing")
local dryRun=stage:GetAttribute("DryRun")~=false
local function canonical(source)return(source:gsub("\r\n","\n"))end
local function hash(source)local h=0;for i=1,#source do h=(h*31+string.byte(source,i))%2147483647 end;return h end
local definitions={
 {key="s0",name="TikkiesDispatch",class="ModuleScript",hash=328877201},
 {key="s1",name="TikkiesRoomClient",class="ModuleScript",hash=1034121520,previousHashes={4204728,369874353,17747929}},
 {key="s2",name="TikkiesBridge",class="Script",hash=416709790,previousHashes={1550812153,996429594,761194767}},
 {key="s3",name="TikkiesPatches",class="ModuleScript",hash=2105567924,installerOnly=true},
}
local sources={}
for _,definition in ipairs(definitions)do
 local object=assert(stage:FindFirstChild(definition.key),"Missing stage source: "..definition.name)
 assert(object:IsA("LuaSourceContainer"),"Stage source must be a script")
 local source=canonical(object.Source)
 assert(hash(source)==definition.hash,"Staged source differs from review: "..definition.name)
 assert(loadstring(source,definition.name))
 sources[definition.name]=source
end
local Patch=assert(loadstring(sources.TikkiesPatches,"TikkiesPatches"))()
local SSS=game:GetService("ServerScriptService")
local targets={}
for _,definition in ipairs(definitions)do
 if not definition.installerOnly then
  local current=SSS:FindFirstChild(definition.name)
  if current then
   assert(current.ClassName==definition.class,"Unexpected existing class: "..definition.name)
   local matches=canonical(current.Source)==sources[definition.name]
   for _,oldHash in ipairs(definition.previousHashes or {})do if hash(canonical(current.Source))==oldHash then matches=true end end
   assert(matches,"Existing Tikkies module differs; review before updating: "..definition.name)
  end
  table.insert(targets,{name=definition.name,class=definition.class,current=current,source=sources[definition.name]})
 end
end
for _,definition in ipairs({
 {name="TikTokBridge",old=2058389496,previousHashes={740631241,1140701286},new=2031171183,patch=Patch.Bridge},
 {name="BlackHoleServer",old=1913009151,new=627228452,patch=Patch.Server},
})do
 local current=assert(SSS:FindFirstChild(definition.name),"Missing native script: "..definition.name)
 local old=canonical(current.Source)
 local oldHash=hash(old)
 local expected=oldHash==definition.old or oldHash==definition.new
 for _,known in ipairs(definition.previousHashes or {})do if oldHash==known then expected=true end end
 assert(expected,"Native source changed since audit; preserve and re-review: "..definition.name)
 local patched=definition.patch(old)
 assert(hash(patched)==definition.new,"Generated native patch differs: "..definition.name)
 assert(loadstring(patched,definition.name))
 table.insert(targets,{name=definition.name,class=current.ClassName,current=current,source=patched})
end
local changed={}
for _,target in ipairs(targets)do
 if not target.current or canonical(target.current.Source)~=target.source then table.insert(changed,target.name)end
end
if dryRun then return game:GetService("HttpService"):JSONEncode({dryRun=true,compiled=5,changes=changed,credentialsUntouched=true})end
if #changed==0 then return "Tikkies already installed; no changes"end
local backup=Instance.new("Folder")
backup.Name="BeforeTikkies_"..os.date("!%Y%m%d_%H%M%S").."_"..game:GetService("HttpService"):GenerateGUID(false):sub(1,8)
backup.Parent=game.ServerStorage
for _,target in ipairs(targets)do if target.current then target.current:Clone().Parent=backup end end
for _,target in ipairs(targets)do
 local object=target.current or Instance.new(target.class)
 object.Name=target.name;object.Source=target.source;object.Parent=SSS
end
return game:GetService("HttpService"):JSONEncode({installed=true,changes=changed,backup=backup.Name,credentialsUntouched=true})
