-- Deterministic visual physics. Settled blocks require no per-frame work.
local Motion={}
function Motion.Rest(age,angle,seed)
    age=math.max(0,age)
    local fallTime=math.sqrt(9/88)
    local h
    if age<fallTime then h=4.5-44*age*age
    else local t=age-fallTime;h=math.abs(math.sin(t*22))*.55*math.exp(-8*t) end
    if age>=.9 then h=0 end
    local remaining=math.max(0,1-age/.9)
    local phase=(seed%19)*.31
    local offset=Vector3.new(math.cos(phase)*.28*remaining,h,math.sin(phase)*.28*remaining)
    local rotation=CFrame.Angles(math.sin(phase)*remaining*.32,angle+remaining*.4,math.cos(phase)*remaining*.32)
    return offset,rotation,age>=.9
end
function Motion.Capture(base,target,age,progress,angle,seed)
    local t=math.clamp(progress,0,1)
    local offset,rotation=Motion.Rest(age,angle,seed)
    local from=base+Vector3.new(0,1.1,0)+offset
    local ease=t*t*(3-2*t)
    local delta=target-from
    local side=Vector3.new(-delta.Z,0,delta.X)
    if side.Magnitude>.001 then side=side.Unit end
    local point=from:Lerp(target,ease)+Vector3.new(0,math.sin(t*math.pi)*1.1,0)+side*math.sin(t*math.pi)*.28
    return CFrame.new(point)*rotation*CFrame.Angles(t*t*.7,t*t*2.4,t*t*.4),1-.8*t*t*t,math.clamp((t-.84)/.16,0,1)
end
return Motion
