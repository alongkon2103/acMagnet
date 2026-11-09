-- Run once in Edit mode. Visible geometry animates locally; only collision geometry replicates.
local arena=workspace.BlackHoleArena
local storage=game.ServerStorage
if not storage:FindFirstChild("BeforeArenaSize_20261109")then
    local backup=arena:Clone();backup.Name="BeforeArenaSize_20261109";backup.Parent=storage
end
if not arena:FindFirstChild("ArenaVisuals")then
    local visuals=Instance.new("Model");visuals.Name="ArenaVisuals";visuals.WorldPivot=CFrame.identity;visuals.Parent=arena
    local collisions=Instance.new("Model");collisions.Name="ArenaCollisions";collisions.WorldPivot=CFrame.identity;collisions.Parent=arena
    local original=arena:FindFirstChild("CharacterCollision")
    local batch=0
    for _,v in arena:GetDescendants()do
        if v:IsA("BasePart")then
            if original and v:IsDescendantOf(original)then v.Parent=collisions
            elseif v.Transparency<1 and v.Name~="Backdrop" and v.Name~="MagnetSpawn"then
                v.CanCollide=false;v.Parent=visuals
            end
            batch+=1;if batch%200==0 then task.wait()end
        end
    end
    visuals.WorldPivot=CFrame.identity;collisions.WorldPivot=CFrame.identity
    visuals:ScaleTo(1);collisions:ScaleTo(1)
    if original then original:Destroy()end
end
local backdrop=arena:FindFirstChild("Backdrop")
if backdrop then backdrop.Size=Vector3.new(840,backdrop.Size.Y,840)end
local kit=game.ReplicatedStorage.BlackHole
local scale=require(kit.Config).DefaultArenaPercent/100
arena.ArenaVisuals:ScaleTo(scale);arena.ArenaCollisions:ScaleTo(scale)
local floor=arena:FindFirstChild("ArenaCollisionFloor")or arena.ArenaCollisions:FindFirstChild("SmoothCollisionFloor")
if floor then
    floor.Name="ArenaCollisionFloor";floor.Parent=arena
    floor.Size=Vector3.new(1,90*require(kit.Config).MaxArenaPercent/100,90*require(kit.Config).MaxArenaPercent/100)
    floor.Position=Vector3.new(0,require(kit.Config).ArenaFloorY*scale-.5,0)
end
if not kit:FindFirstChild("ArenaSettings")then local remote=Instance.new("RemoteEvent");remote.Name="ArenaSettings";remote.Parent=kit end
return {visualParts=#arena.ArenaVisuals:GetChildren(),collisionParts=#arena.ArenaCollisions:GetChildren()}
