-- Run as a temporary LocalScript in StarterPlayerScripts, not from the command-bar require cache.
-- Creates only client-local test blocks, measures them, and cleans up all test objects/registrations.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Http=game:GetService("HttpService")
local player=Players.LocalPlayer
local kit=game.ReplicatedStorage:WaitForChild("BlackHole")
local Shadow=require(kit:WaitForChild("BlockShadows"))
local Portrait=require(kit:WaitForChild("PixelPortrait"))
local Arena=require(kit:WaitForChild("ArenaMath"))
local made={}
local hiddenRoot
local folder=Instance.new("Folder");folder.Name="ContactShadowStressQA"
local result={}
local ok,err=xpcall(function()
    local ready=0
    for i=1,120 do
        local bodies=workspace:FindFirstChild("LocalGiftBlocks")
        if bodies and #bodies:GetChildren()>0 and #bodies:GetChildren()>=(kit.State:GetAttribute("Active")or 500)then ready+=1 else ready=0 end
        if ready>=5 then break end;task.wait(.1)
    end
    player:SetAttribute("CameraZoomTarget",2.5);task.wait(.4)
    local count=#workspace.LocalGiftBlocks:GetChildren()
    local amount=math.max(0,1600-count);local rng=Random.new(526);local scale=Arena.Read()
    for first=1,amount,80 do
        local batch=Instance.new("Folder")
        for i=first,math.min(first+79,amount)do
            local body=kit.RoundedBlock:Clone();body.Anchored=true;body.CanCollide=false;body.CanTouch=false;body.CanQuery=false;body.CastShadow=false
            local radius=math.sqrt(rng:NextNumber())*43*scale;local angle=rng:NextNumber()*math.pi*2
            body.CFrame=CFrame.new(radius*math.cos(angle),1.1+.2*(scale-1),radius*math.sin(angle))*CFrame.Angles(0,angle,0)
            Portrait.ApplyFallback(body,101);body.Parent=batch
            local shadow=Shadow.Acquire();shadow.CFrame=Shadow.Place(shadow,body.CFrame,scale,1,0)
            table.insert(made,{body=body,shadow=shadow})
        end
        batch.Parent=folder;if not folder.Parent then folder.Parent=workspace end;task.wait()
    end
    task.wait(1)
    result.blocksAtSample=#workspace.LocalGiftBlocks:GetChildren()+#made
    result.shadowsAtSample=#workspace.LocalBlockShadows:GetChildren()
    assert(result.blocksAtSample==result.shadowsAtSample,"Shadow count must match blocks in the real client context")
    local function sample()
        local frames={};for i=1,60 do table.insert(frames,RunService.RenderStepped:Wait())end;table.sort(frames)
        return {medianFPS=1/frames[30],p95ms=frames[57]*1000,frames=#frames}
    end
    result.shadowsOn=sample()
    local shadowRoot=workspace.LocalBlockShadows;hiddenRoot=shadowRoot;shadowRoot.Parent=nil
    result.shadowsOff=sample()
    shadowRoot.Parent=workspace;hiddenRoot=nil
    result.zoom=player:GetAttribute("CameraZoomTarget")
end,debug.traceback)
if hiddenRoot then hiddenRoot.Parent=workspace end
for _,item in made do Portrait.Clear(item.body);Shadow.Release(item.shadow)end
folder:Destroy()
result.ok=ok;result.error=err
result.remainingBlocks=#workspace.LocalGiftBlocks:GetChildren()
result.remainingShadows=#workspace.LocalBlockShadows:GetChildren()
local value=Instance.new("StringValue");value.Name="ContactShadowQAResult";value.Value=Http:JSONEncode(result);value.Parent=player.PlayerScripts
script:Destroy()
