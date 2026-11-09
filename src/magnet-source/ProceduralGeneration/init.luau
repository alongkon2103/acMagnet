--!strict
-- generationId: c623f72e-e96d-4618-84e2-64b10534b28e
local CSG = require(script.Dependencies.ConstructiveSolidGeometry)
local GP = require(script.Dependencies.GeometryPrimitives)
local SO = require(script.Dependencies.SmartObject)
local MU = require(script.Dependencies.MathUtils)


local Magnet = {}

type Parameters = {
	Size: Vector3,
	Attributes: {
		ColorCream: Color3?,
		ColorGreen: Color3?,
		ColorCopper: Color3?,
		ColorDarkCopper: Color3?,
	},
}
local startTime = 0
local timerThread : thread = task.spawn(function()
while true do
	if not script:IsDescendantOf(game) then
		startTime = 0
		return
	end
	if startTime > 0 then
		local elapsed = tick() - startTime
		print("[ProceduralModel] " .. script:GetFullName() .. " rendering... " .. string.format("%.0f", elapsed) .. " seconds")
	end
	task.wait(3)
end
end)
script.Destroying:Connect(function()
	task.cancel(timerThread)
end)

Magnet.OnGenerate = function(parameters: Parameters, targetContainer: Instance)
	-- Timer setup
	startTime = tick()

	local model = GP.model("Magnet", nil)-- Fix orientation of the model
	model.WorldPivot = CFrame.identity
	
	
	-- REQUIRED: all three smart dimensions (default is always 10)
	local smartWidth  = parameters.Size.X
	local smartHeight = parameters.Size.Y
	local smartDepth  = parameters.Size.Z
	
	local scaleX = smartWidth / 10
	local scaleY = smartHeight / 10
	local scaleZ = smartDepth / 10
	
	-- Colors & Materials
	local cCream = parameters.Attributes.ColorCream or Color3.fromRGB(240, 235, 220)
	local cGreen = parameters.Attributes.ColorGreen or Color3.fromRGB(130, 150, 140)
	local cCopper = parameters.Attributes.ColorCopper or Color3.fromRGB(200, 120, 80)
	local cDarkCopper = parameters.Attributes.ColorDarkCopper or Color3.fromRGB(150, 80, 50)
	
	local matSmooth = "SmoothPlastic"
	local matMetal = "Metal"
	
	-- Top-level Models
	local handle = GP.model("handle", model)
	local magneticPlate = GP.model("magnetic plate", model)
	local casing = GP.model("casing", model)
	
	-- Dimensions
	local uWidth = 6.5 * scaleX
	local uHeight = 7.0 * scaleY
	local tubeRadius = 1.6 * math.min(scaleX, scaleY)
	local pipeRadius = 0.25 * math.min(scaleX, scaleY)
	local zOffset = 0.5 * scaleZ -- Offset between layers
	
	local curveRadius = uWidth / 2
	local legHeight = uHeight - curveRadius
	local centerY = 0
	
	-- Path Generation for U-Shape
	local function generateUPath(zPos, startY, endY)
	    local points = {}
	    local segments = 16
	    
	    -- Left Leg (Viewer Left -> +X)
	    table.insert(points, Vector3.new(curveRadius, startY, zPos))
	    table.insert(points, Vector3.new(curveRadius, centerY, zPos))
	    
	    -- Bottom Curve
	    for i = 1, segments - 1 do
	        -- Angle from 0 to -180 degrees (in radians)
	        local angle = -math.pi * (i / segments)
	        local x = math.cos(angle) * curveRadius
	        local y = math.sin(angle) * curveRadius + centerY
	        table.insert(points, Vector3.new(x, y, zPos))
	    end
	    
	    -- Right Leg (Viewer Right -> -X)
	    table.insert(points, Vector3.new(-curveRadius, centerY, zPos))
	    table.insert(points, Vector3.new(-curveRadius, endY, zPos))
	    
	    return points
	end
	
	-- ==========================================
	-- 1. HANDLE (Main Body)
	-- ==========================================
	-- Back Layer (Green)
	local pathGreen = generateUPath(zOffset, legHeight, legHeight)
	GP.tube("BackLayer", pathGreen, tubeRadius, cGreen, matSmooth, handle)
	
	-- Front Layer (Cream)
	local pathCream = generateUPath(0, legHeight, legHeight)
	GP.tube("FrontLayer", pathCream, tubeRadius, cCream, matSmooth, handle)
	
	
	-- ==========================================
	-- 2. MAGNETIC PLATE (Top Cubes)
	-- ==========================================
	local cubeSize = 2.0 * math.min(scaleX, scaleY)
	local cubeHalf = cubeSize / 2
	local cubeY = legHeight + cubeHalf + 0.1 * scaleY
	
	-- Viewer Left (+X)
	GP.roundedBox("PlateLeft", 
	    Vector3.new(curveRadius, cubeY, 0), 
	    Vector3.new(cubeSize, cubeSize, cubeSize + zOffset), 
	    0.4 * scaleX, cCopper, matMetal, magneticPlate)
	
	-- Viewer Right (-X)
	GP.roundedBox("PlateRight", 
	    Vector3.new(-curveRadius, cubeY, 0), 
	    Vector3.new(cubeSize, cubeSize, cubeSize + zOffset), 
	    0.4 * scaleX, cCopper, matMetal, magneticPlate)
	
	
	-- ==========================================
	-- 3. CASING (Front Details)
	-- ==========================================
	local frontZ = -tubeRadius - 0.05 * scaleZ
	local pipeStartY = legHeight - 1.5 * scaleY
	
	-- 3A. Copper Pipe
	local pathPipe = generateUPath(frontZ, pipeStartY, pipeStartY)
	GP.tube("CopperPipe", pathPipe, pipeRadius, cCopper, matMetal, casing)
	
	-- 3B. Rivets (at pipe ends)
	local function createRivet(name, xPos, yPos)
	    local rivetZ = frontZ + 0.1 * scaleZ -- Embedded slightly into pipe
	    local baseRadius = 0.5 * scaleX
	    
	    -- Green base
	    GP.cylinder(name.."_Base", 
	        Vector3.new(xPos, yPos, rivetZ + 0.1 * scaleZ), 
	        Vector3.new(xPos, yPos, rivetZ - 0.1 * scaleZ), 
	        baseRadius, cGreen, matSmooth, casing)
	        
	    -- Cream center
	    GP.sphere(name.."_Pin", Vector3.new(xPos, yPos, rivetZ - 0.1 * scaleZ), baseRadius * 0.6, cCream, matSmooth, casing)
	end
	
	createRivet("RivetLeft", curveRadius, pipeStartY)
	createRivet("RivetRight", -curveRadius, pipeStartY)
	
	-- 3C. Bottom Cuff
	local cuffY = centerY - curveRadius
	local cuffRadius = tubeRadius + 0.2 * scaleX
	local cuffWidth = 1.2 * scaleX
	local cuffStartX = cuffWidth / 2
	local cuffEndX = -cuffWidth / 2
	
	-- Use a hollow cylinder facing sideways to wrap around the bottom tube
	GP.hollowCylinder("BottomCuff", 
	    Vector3.new(cuffStartX, cuffY, 0), 
	    Vector3.new(cuffEndX, cuffY, 0), 
	    cuffRadius, 0.4 * scaleX, cCopper, matMetal, casing)
	
	-- Cuff Ribs (Indents)
	GP.hollowCylinder("CuffRib1", Vector3.new(cuffWidth/3, cuffY, 0), Vector3.new(cuffWidth/3 - 0.1*scaleX, cuffY, 0), cuffRadius + 0.05*scaleX, 0.1*scaleX, cDarkCopper, matMetal, casing)
	GP.hollowCylinder("CuffRib2", Vector3.new(-cuffWidth/3, cuffY, 0), Vector3.new(-cuffWidth/3 + 0.1*scaleX, cuffY, 0), cuffRadius + 0.05*scaleX, 0.1*scaleX, cDarkCopper, matMetal, casing)
	
	-- 3D. Gear Mechanism
	-- Placed on the right side of the curve (Viewer Right -> World -X)
	local gearAngle = -math.pi * 0.75 -- 135 degrees (bottom right)
	local gearX = math.cos(gearAngle) * curveRadius
	local gearY = math.sin(gearAngle) * curveRadius + centerY
	local gearZ = frontZ - 0.1 * scaleZ
	
	local gearRadius = 0.8 * scaleX
	local gearThickness = 0.2 * scaleZ
	
	-- Main Gear Body (8-sided regular prism to look like a cog)
	GP.regularPrism("GearBody", 
	    Vector3.new(gearX, gearY, gearZ + gearThickness/2), 
	    Vector3.new(gearX, gearY, gearZ - gearThickness/2), 
	    gearRadius, 8, cCopper, matMetal, casing)
	
	-- Gear Center
	GP.cylinder("GearCenter", 
	    Vector3.new(gearX, gearY, gearZ + gearThickness/2 + 0.05*scaleZ), 
	    Vector3.new(gearX, gearY, gearZ - gearThickness/2 - 0.05*scaleZ), 
	    gearRadius * 0.5, cCream, matSmooth, casing)
	
	-- Gear Pin
	GP.sphere("GearPin", Vector3.new(gearX, gearY, gearZ - gearThickness/2 - 0.05*scaleZ), 0.2 * scaleX, cCopper, matMetal, casing)
	
	-- Small Gear Arm/Indicator
	local armDir = Vector3.new(-0.7, 0.7, 0).Unit
	local armStart = Vector3.new(gearX, gearY, gearZ - gearThickness/2)
	local armEnd = armStart + armDir * (gearRadius * 0.8)
	GP.strutFromTwoPoints("GearArm", armStart + Vector3.new(0, 0, -2e-3), armEnd, 0.1 * scaleX, 0.1 * scaleY, cCopper, matMetal, casing) -- zf-prevention: vector3_component
	
	
	model.Parent = targetContainer
	-- reposition
	for _, part in targetContainer:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame -= Vector3.yAxis * parameters.Size.Y / 2
		end
	end
	for _, model in targetContainer:GetDescendants() do
		if model:IsA("Model") then
			model.WorldPivot -= Vector3.yAxis * parameters.Size.Y / 2
		end
	end

	-- Stop timer when generation completes
	local timeElapsed = tick() - startTime
	startTime = 0
	if timeElapsed > 3 and script:IsDescendantOf(game) then
		print("[ProceduralModel] " .. script:GetFullName() .. " rendering completed")
	end

end

return Magnet

