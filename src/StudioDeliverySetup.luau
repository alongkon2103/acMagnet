-- Stage sources from their tracked src files into ServerStorage.DeliveryStage_20261116 first.
assert(not game:GetService("RunService"):IsRunning(),"Stop Play before installing")
local stage=assert(game.ServerStorage:FindFirstChild("DeliveryStage_20261116"),"Delivery staging folder missing")
local function hash(s)local h=0;for i=1,#s do h=(h*31+string.byte(s,i))%2147483647 end return h end
local function canonical(s)return (s:gsub("\r\n","\n"))end
local definitions={
 {path="ServerScriptService.TikTokBridge",key="s0",old=1815836234,installed=253100331,new=2058389496},
 {path="ServerScriptService.BlackHoleServer",key="s1",old=1013671912,installed=1159531257,new=1913009151},
 {path="ServerScriptService.GachaQueue",key="s2",old=1936827867,installed=883591137,new=1234660384},
 {path="ServerScriptService.ArenaSettings",key="s3",old=1292184872,new=1211443343},
 {path="StarterPlayer.StarterPlayerScripts.BlackHoleClient",key="s4",old=1976228863,installed=240816414,new=1643823945},
 {path="StarterPlayer.StarterPlayerScripts.BlockGachaClient",key="s5",old=327375642,installed=514574720,new=514574720},
 {path="ReplicatedStorage.BlackHole.GachaSenderBadge",key="s6",old=1001547299,installed=1974541155,new=1974541155},
 {path="ReplicatedStorage.BlackHole.Config",key="s7",old=1337218482,installed=77189241,new=245382834},
 {path="ServerScriptService.LiveNameCache",key="s8",old=nil,new=1789694716},
 {path="ServerScriptService.LiveDeliveryPump",key="s9",old=nil,installed=939170943,new=217302457},
}
local targets={}
for _,d in definitions do
 local parent=game
 local last
 for part in d.path:gmatch("[^%.]+")do
  if last then parent=assert(parent:FindFirstChild(last),d.path)end
  last=part
 end
 local current=parent:FindFirstChild(last)
 local staged=assert(stage:FindFirstChild(d.key),d.path)
 assert(hash(canonical(staged.Source))==d.new,"Staged source differs: "..d.path)
 assert(loadstring(staged.Source,d.path))
 if current then local h=hash(current.Source);assert(h==d.old or h==d.installed or hash(canonical(current.Source))==d.new,"Native source changed since audit: "..d.path)
 else assert(d.old==nil,"Target missing: "..d.path)end
 table.insert(targets,{parent=parent,name=last,current=current,source=canonical(staged.Source)})
end
local backup=Instance.new("Folder");backup.Name="BeforeDelivery_"..os.date("!%Y%m%d_%H%M%S").."_"..game.HttpService:GenerateGUID(false):sub(1,8);backup.Parent=game.ServerStorage
for _,t in targets do if t.current then t.current:Clone().Parent=backup end end
local names=game.ReplicatedStorage.BlackHole:FindFirstChild("LiveNames")
if not names then names=Instance.new("Folder");names.Name="LiveNames";names.Parent=game.ReplicatedStorage.BlackHole end
for _,t in targets do
 local object=t.current or Instance.new("ModuleScript")
 object.Name=t.name;object.Source=t.source;object.Parent=t.parent
end
stage:Destroy()
return "Installed reliable delivery; backup: "..backup.Name
