local Players=game:GetService("Players")
local Tween=game:GetService("TweenService")
local kit=game.ReplicatedStorage:WaitForChild("BlackHole")
local registry=kit:WaitForChild("LivePortraits")
local Portrait=require(kit:WaitForChild("PixelPortrait"))
local thumbnails={}
local thumbnailCount=0
local Badge={}
local function corner(parent,radius)
 local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,radius);c.Parent=parent
end
function Badge.Create(parent)
 local frame=Instance.new("CanvasGroup")
 frame.Name="GachaSenderBadge";frame.AnchorPoint=Vector2.new(.5,1)
 frame.Position=UDim2.new(.5,0,.19,-12);frame.Size=UDim2.fromOffset(232,48)
 frame.BackgroundColor3=Color3.fromRGB(249,246,229);frame.BackgroundTransparency=.06
 frame.BorderSizePixel=0;frame.Visible=false;frame.ZIndex=30;frame.Parent=parent;corner(frame,14)
 local outline=Instance.new("UIStroke");outline.Color=Color3.fromRGB(190,181,139);outline.Transparency=.35;outline.Parent=frame
 local scale=Instance.new("UIScale");scale.Parent=frame
 local photo=Instance.new("ImageLabel")
 photo.Name="Profile";photo.BackgroundColor3=Color3.fromRGB(208,226,198);photo.BorderSizePixel=0
 photo.Position=UDim2.fromOffset(5,5);photo.Size=UDim2.fromOffset(38,38)
 photo.Image="";photo.ScaleType=Enum.ScaleType.Crop;photo.ZIndex=31;photo.Parent=frame;corner(photo,19)
 local initial=Instance.new("TextLabel")
 initial.Name="Initial";initial.BackgroundTransparency=1;initial.Size=UDim2.fromScale(1,1)
 initial.Font=Enum.Font.GothamBold;initial.TextSize=18;initial.TextColor3=Color3.fromRGB(53,92,69)
 initial.ZIndex=33;initial.Parent=photo
 local name=Instance.new("TextLabel")
 name.Name="SenderName";name.BackgroundTransparency=1;name.Position=UDim2.fromOffset(53,0)
 name.Size=UDim2.fromOffset(167,48);name.Font=Enum.Font.GothamMedium;name.TextSize=14
 name.TextColor3=Color3.fromRGB(50,79,61);name.TextXAlignment=Enum.TextXAlignment.Left
 name.TextTruncate=Enum.TextTruncate.AtEnd;name.ZIndex=31;name.Parent=frame
 local generation,current,tween=0,nil,nil
 local function clearPhoto()
  photo.Image=""
  for _,v in photo:GetChildren()do if v.Name=="PixelRun"then v:Destroy()end end
  initial.Visible=true
 end
 local function renderPortrait(id)
  local entry=Portrait.Get(id)
  if not entry then return false end
  clearPhoto()
  if entry.image then
   photo.ImageContent=Content.fromObject(entry.image)
   photo.ResampleMode=Enum.ResamplerMode.Pixelated
  else
   -- A single small badge can draw the pixels even when EditableImage is unavailable.
   local size=entry.size
   for y=0,size-1 do
    local x=0
    while x<size do
     local value=entry.pixels[y*size+x+1]
     local finish=x+1
     while finish<size and entry.pixels[y*size+finish+1]==value do finish+=1 end
     local middle=size/2
     local left=x
     while left<finish and ((left+.5-middle)^2+(y+.5-middle)^2)>middle^2 do left+=1 end
     local right=finish
     while right>left and ((right-.5-middle)^2+(y+.5-middle)^2)>middle^2 do right-=1 end
     if right>left then
      local run=Instance.new("Frame");run.Name="PixelRun";run.BorderSizePixel=0
      run.BackgroundColor3=Color3.fromRGB(math.floor(value/65536),math.floor(value/256)%256,value%256)
      run.Position=UDim2.fromScale(left/size,y/size);run.Size=UDim2.fromScale((right-left)/size,1/size)
      run.ZIndex=32;run.Parent=photo
     end
     x=finish
    end
   end
  end
  initial.Visible=false;frame:SetAttribute("ProfileReady",true)
  return true
 end
 local function resize()
  scale.Scale=math.min(1,math.max(.1,(parent.AbsoluteSize.X-24)/232))
 end
 local resizeConnection=parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize);resize()
 local portraitConnection=registry.ChildAdded:Connect(function(value)
  if current and frame.Visible and value.Name==current.avatarId then renderPortrait(value.Name)end
 end)
 local api={Root=frame}
 function api.Show(sender)
  generation+=1;local version=generation
  current=table.clone(sender or {})
  clearPhoto()
  name.Text=tostring(current.name or "viewer")
  initial.Text=name.Text:match("[A-Za-z0-9]")or "?"
  frame:SetAttribute("SenderName",name.Text)
  frame:SetAttribute("SenderAvatarId",current.avatarId)
  frame:SetAttribute("SenderUserId",current.userId)
  frame:SetAttribute("ProfileReady",false)
  frame.Visible=true;frame.GroupTransparency=1
  if tween then tween:Cancel()end
  tween=Tween:Create(frame,TweenInfo.new(.18,Enum.EasingStyle.Quad),{GroupTransparency=0});tween:Play()
  if type(current.avatarId)=="string" then renderPortrait(current.avatarId)
  elseif type(current.userId)=="number" and current.userId>0 then
   local userId=current.userId
   task.spawn(function()
    local image=thumbnails[userId]
    if not image then
     local ok,result=pcall(function()return Players:GetUserThumbnailAsync(userId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size150x150)end)
     if not ok then return end
     image=result
     if thumbnailCount<32 then thumbnails[userId]=image;thumbnailCount+=1 end
    end
    if generation~=version or not frame.Visible then return end
    photo.ResampleMode=Enum.ResamplerMode.Default;photo.Image=image;initial.Visible=false
    frame:SetAttribute("ProfileReady",true)
   end)
  end
 end
 function api.Hide()
  generation+=1;current=nil
  if tween then tween:Cancel()end
  frame.Visible=false
 end
 function api.Destroy()
  api.Hide();resizeConnection:Disconnect();portraitConnection:Disconnect();frame:Destroy()
 end
 return api
end
return Badge
