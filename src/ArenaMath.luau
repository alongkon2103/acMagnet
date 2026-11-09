local Http=game:GetService("HttpService")
local kit=game.ReplicatedStorage:WaitForChild("BlackHole")
local Config=require(kit.Config)
local state=kit:WaitForChild("State")
local Arena={}
local defaultScale=Config.DefaultArenaPercent/100
local encoded,transition=nil,{from=defaultScale,to=defaultScale,started=0}
function Arena.NormalizePercent(value)
    if type(value)~="number" or value~=value or math.abs(value)==math.huge then return nil end
    return math.clamp(math.floor(value+.5),Config.MinArenaPercent,Config.MaxArenaPercent)
end
function Arena.CanChange(isStudio,isCreator,isPrivateOwner,isListed)
    return isStudio or isCreator or isPrivateOwner or isListed
end
function Arena.ScaleAt(from,to,started,now)
    local t=math.clamp((now-started)/Config.ArenaResizeSeconds,0,1)
    return from+(to-from)*(1-(1-t)^3)
end
function Arena.Read(now)
    local current=state:GetAttribute("ArenaTransition")
    if current~=encoded then
        encoded=current
        transition=current and Http:JSONDecode(current)or {from=defaultScale,to=defaultScale,started=0}
    end
    return Arena.ScaleAt(transition.from,transition.to,transition.started,now or workspace:GetServerTimeNow()),transition.to
end
function Arena.FloorOffset(scale)return Config.ArenaFloorY*(scale-1)end
return Arena
