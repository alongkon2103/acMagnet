local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local Tween=game:GetService("TweenService")
local player=Players.LocalPlayer
local kit=game.ReplicatedStorage:WaitForChild("BlackHole")
local remote=kit:WaitForChild("BlockGacha")
local Rewards=require(kit:WaitForChild("GachaRewards"))
local ContentProvider=game:GetService("ContentProvider")
local function preloadCards()
 local images={}
 for _,r in ipairs(Rewards.Rewards)do
  local id=kit:GetAttribute("GachaCard"..r.tier)
  if type(id)=="string" and id:match("^rbxassetid://%d+$") then
   local image=Instance.new("ImageLabel")
   image.Image=id
   table.insert(images,image)
  end
 end
 if #images>0 then task.spawn(function()
  pcall(function()ContentProvider:PreloadAsync(images)end)
  for _,image in ipairs(images)do image:Destroy()end
 end)end
end
for _,r in ipairs(Rewards.Rewards)do kit:GetAttributeChangedSignal("GachaCard"..r.tier):Connect(preloadCards)end
preloadCards()
local gui=Instance.new("ScreenGui")
gui.Name="BlockGachaHUD";gui.ResetOnSpawn=false;gui.DisplayOrder=25
gui.Parent=player:WaitForChild("PlayerGui")
local senderBadge=require(kit:WaitForChild("GachaSenderBadge")).Create(gui)
local function make(class,parent,props)
 local o=Instance.new(class)
 for k,v in pairs(props)do o[k]=v end
 o.Parent=parent;return o
end
local function round(o,r)make("UICorner",o,{CornerRadius=UDim.new(0,r)})end
local function stroke(o,c,n)return make("UIStroke",o,{Color=c,Thickness=n or 1})end
local function label(p,name,x,y,w,h,value,size,color)
 return make("TextLabel",p,{Name=name,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,Text=value,TextColor3=color or Color3.fromRGB(244,245,233),TextSize=size,Font=Enum.Font.GothamBold})
end
local red=Color3.fromRGB(187,65,86)
local green=Color3.fromRGB(38,126,99)
local cream=Color3.fromRGB(245,240,212)
local ink=Color3.fromRGB(45,78,69)
local gold=Color3.fromRGB(188,164,105)
local dock=make("Frame",gui,{Name="GachaButtons",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-16,0,88),Size=UDim2.fromOffset(166,153),BackgroundColor3=cream})
round(dock,16);stroke(dock,Color3.fromRGB(218,219,184),1)
make("UIGradient",dock,{Color=ColorSequence.new(Color3.fromRGB(255,253,235),Color3.fromRGB(222,235,209)),Rotation=90})
label(dock,"Heading",10,4,116,24,"BLOCK GACHA",11,ink)
local request
for i,v in ipairs({{"Prank","สุ่มแกล้ง","G",red},{"Help","สุ่มช่วย","H",green},{"Mixed","สุ่มบวก / ลบ","F",Color3.fromRGB(117,77,169)}})do
 local b=make("TextButton",dock,{Name=v[1],Position=UDim2.fromOffset(8,31+(i-1)*37),Size=UDim2.fromOffset(150,32),BackgroundColor3=Color3.fromRGB(255,253,241),Text="",AutoButtonColor=false})
 round(b,10)
 local outline=stroke(b,v[4]:Lerp(cream,.65),1)
 local badge=make("Frame",b,{Position=UDim2.fromOffset(5,4),Size=UDim2.fromOffset(25,24),BackgroundColor3=v[4]})
 round(badge,7)
 label(badge,"Key",0,0,25,24,v[3],13,Color3.new(1,1,1))
 label(b,"Action",31,0,93,32,v[2],14,v[4])
 label(b,"Sign",123,0,24,32,i==1 and "+"or (i==2 and "−" or "±"),21,v[4])
 b.MouseEnter:Connect(function()Tween:Create(outline,TweenInfo.new(.15),{Color=v[4]}):Play()end)
 b.MouseLeave:Connect(function()Tween:Create(outline,TweenInfo.new(.15),{Color=v[4]:Lerp(cream,.65)}):Play()end)
 b.Activated:Connect(function()request(v[1])end)
end
local info=make("TextButton",dock,{Name="OddsButton",Position=UDim2.fromOffset(134,5),Size=UDim2.fromOffset(23,22),BackgroundColor3=Color3.fromRGB(214,227,201),Text="i",TextColor3=ink,TextSize=14,Font=Enum.Font.GothamBold})
round(info,8)
local queueText=label(dock,"Queue",0,154,166,20,"",12,ink)
local odds=make("Frame",gui,{Name="Odds",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-16,0,269),Size=UDim2.fromOffset(250,201),BackgroundColor3=cream,Visible=false})
round(odds,14);stroke(odds,gold,1)
label(odds,"Title",12,9,198,25,"อัตรารางวัล",15,ink)
local dismiss=make("TextButton",odds,{Name="Close",Position=UDim2.fromOffset(217,8),Size=UDim2.fromOffset(25,25),BackgroundTransparency=1,Text="×",TextColor3=ink,TextSize=20})
dismiss.Activated:Connect(function()odds.Visible=false end)
for i,r in ipairs(Rewards.Rewards)do
 local y=40+(i-1)*30
 local row=make("Frame",odds,{Name=r.tier,Position=UDim2.fromOffset(9,y),Size=UDim2.fromOffset(232,27),BackgroundColor3=Color3.fromRGB(255,253,243),BorderSizePixel=0});round(row,7)
 local dot=make("Frame",row,{Position=UDim2.fromOffset(8,9),Size=UDim2.fromOffset(8,8),BackgroundColor3=r.color,BorderSizePixel=0});round(dot,4)
 local t=label(row,"Tier",23,0,97,27,r.tier,11,ink);t.TextXAlignment=Enum.TextXAlignment.Left
 label(row,"Amount",116,0,57,27,tostring(r.amount),12,ink)
 label(row,"Chance",176,0,51,27,r.weight.."%",12,ink)
end
info.Activated:Connect(function()odds.Visible=not odds.Visible end)
local panel=make("Frame",gui,{Name="ReelPanel",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,.19,0),Size=UDim2.fromOffset(500,230),BackgroundColor3=cream,Visible=false})
round(panel,19)
make("UIGradient",panel,{Color=ColorSequence.new(Color3.fromRGB(255,253,235),Color3.fromRGB(221,235,213)),Rotation=90})
local edge=stroke(panel,gold,1.5)
local scale=make("UIScale",panel,{Scale=1})
local title=label(panel,"Title",16,8,270,24,"BLOCK GACHA",14,ink);title.TextXAlignment=Enum.TextXAlignment.Left
local owner=label(panel,"Sender",290,10,192,21,"",11,Color3.fromRGB(105,130,110));owner.TextXAlignment=Enum.TextXAlignment.Right
owner.TextTruncate=Enum.TextTruncate.AtEnd
local well=make("Frame",panel,{Name="ReelWell",Position=UDim2.fromOffset(8,43),Size=UDim2.fromOffset(484,156),BackgroundColor3=Color3.fromRGB(192,211,184),BorderSizePixel=0})
round(well,13)
local viewport=make("Frame",panel,{Name="ReelViewport",Position=UDim2.fromOffset(10,49),Size=UDim2.fromOffset(480,144),BackgroundTransparency=1,ClipsDescendants=true})
local strip=make("Frame",viewport,{Name="CardStrip",Size=UDim2.fromOffset(3400,140),BackgroundTransparency=1})
local marker=make("Frame",panel,{Name="Selection",Position=UDim2.fromOffset(202,47),Size=UDim2.fromOffset(96,148),BackgroundTransparency=1,ZIndex=4})
round(marker,11)
local markerEdge=stroke(marker,gold,2.5)
local pointer=label(panel,"Pointer",236,32,28,20,"▼",17,ink);pointer.ZIndex=5
local resultLabel=label(panel,"Result",8,202,484,23,"",14,ink)
-- Borderless reel: preserve artwork and the selection marker.
panel.BackgroundTransparency=1
edge.Transparency=1
well.BackgroundTransparency=1
for _,textLabel in ipairs({title,owner,resultLabel})do
 textLabel.TextStrokeColor3=Color3.fromRGB(255,253,236)
 textLabel.TextStrokeTransparency=.25
end

title.Visible=false
owner.Visible=false
resultLabel.Visible=false
local random=Random.new()
local cards={}
-- Draw the block artwork with vector UI so it stays sharp at any display size.
local function card(index,reward,mode)
 local box=make("Frame",strip,{Name="Reward"..index,Position=UDim2.fromOffset((index-1)*100,2),Size=UDim2.fromOffset(92,140),BackgroundColor3=reward.color:Lerp(Color3.fromRGB(255,254,241),.87)})
 round(box,10);stroke(box,reward.color:Lerp(Color3.fromRGB(110,134,113),.25),1)
 make("UIGradient",box,{Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(225,235,213)),Rotation=90})
 local rarityLine=make("Frame",box,{Position=UDim2.fromOffset(25,4),Size=UDim2.fromOffset(42,3),BackgroundColor3=reward.color,BorderSizePixel=0});round(rarityLine,2)
 local cubeShadow=make("Frame",box,{Position=UDim2.fromOffset(31,17),Size=UDim2.fromOffset(38,38),Rotation=-10,BackgroundColor3=Color3.fromRGB(47,135,112),BorderSizePixel=0})
 round(cubeShadow,8)
 local cube=make("Frame",box,{Name="BlockArt",Position=UDim2.fromOffset(26,12),Size=UDim2.fromOffset(38,38),Rotation=-10,BackgroundColor3=Color3.fromRGB(187,255,203),BorderSizePixel=0})
 round(cube,8);stroke(cube,Color3.fromRGB(225,255,220),1.5)
 make("UIGradient",cube,{Color=ColorSequence.new(Color3.fromRGB(245,255,219),Color3.fromRGB(85,218,162)),Rotation=65})
 for _,x in ipairs({10,24})do
  local eye=make("Frame",cube,{Position=UDim2.fromOffset(x,14),Size=UDim2.fromOffset(4,7),BackgroundColor3=Color3.fromRGB(22,48,41),BorderSizePixel=0});round(eye,3)
  local cheek=make("Frame",cube,{Position=UDim2.fromOffset(x-3,23),Size=UDim2.fromOffset(6,4),BackgroundColor3=Color3.fromRGB(255,141,163),BorderSizePixel=0});round(cheek,3)
 end
 label(cube,"Smile",12,17,14,18,"⌣",14,Color3.fromRGB(22,48,41))
 label(box,"Amount",0,55,92,24,(mode=="Prank" and "+"or "−")..reward.amount,20,mode=="Prank" and red or green)
 label(box,"Tier",0,80,92,16,string.upper(reward.tier),9,reward.color:Lerp(ink,.55))
 local imageId=kit:GetAttribute("GachaCard"..reward.tier)
 if type(imageId)=="string" and imageId:match("^rbxassetid://%d+$") then
  local picture=make("ImageLabel",box,{
   Name="FullArtCard",BackgroundTransparency=1,Position=UDim2.fromOffset(0,0),
   Size=UDim2.fromOffset(92,123),Image=imageId,ScaleType=Enum.ScaleType.Fit,ZIndex=2
  })
  cube.Visible=false;cubeShadow.Visible=false;rarityLine.Visible=false
  local amount=box.Amount
  amount.Position=UDim2.fromOffset(3,104);amount.Size=UDim2.fromOffset(86,16)
  amount.TextSize=15;amount.ZIndex=3
  amount.TextColor3=mode=="Prank" and Color3.fromRGB(255,122,141) or Color3.fromRGB(112,255,174)
  stroke(amount,Color3.fromRGB(12,32,24),1)
  box.Tier.Position=UDim2.fromOffset(0,124);box.Tier.ZIndex=3
  box:SetAttribute("ArtworkTier",reward.tier)
 else
  -- Remain playable while upload permission or image moderation is pending.
  box.Tier.Position=UDim2.fromOffset(0,120)
  box.Amount.Position=UDim2.fromOffset(0,93)
 end
 box.Tier.Visible=false
 cards[index]=box

end
local serial=0
local reelTween
local endOffset
local selected
local function refresh()
 dock.Visible=player:GetAttribute("CanUseMagnetBoost")==true
 local n=player:GetAttribute("GachaQueue")or 0
 queueText.Text=n>0 and ("คิว "..n)or ""
end
player:GetAttributeChangedSignal("GachaQueue"):Connect(refresh)
player:GetAttributeChangedSignal("CanUseMagnetBoost"):Connect(refresh);refresh()
request=function(mode)
 if player:GetAttribute("CanUseMagnetBoost")==true then remote:FireServer(mode)end
end
UIS.InputBegan:Connect(function(input,processed)
 if processed or UIS:GetFocusedTextBox()or not dock.Visible then return end
 if input.KeyCode==Enum.KeyCode.F then request("Mixed")
 elseif input.KeyCode==Enum.KeyCode.G then request("Prank")
 elseif input.KeyCode==Enum.KeyCode.H then request("Help")end
end)
local function resize()
 scale.Scale=math.min(1,(gui.AbsoluteSize.X-24)/500,(gui.AbsoluteSize.Y*.7)/230)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize);resize()
local sound=make("Sound",gui,{Name="RevealSound",SoundId="rbxasset://sounds/volume_slider.ogg",Volume=.65})
make("EqualizerSoundEffect",sound,{Name="SoftPopTone",LowGain=3,MidGain=0,HighGain=-5})
local tickSound=make("Sound",gui,{Name="ReelTick",SoundId="rbxasset://sounds/volume_slider.ogg",Volume=.18,PlaybackSpeed=1.7})
local rareSound=make("Sound",gui,{Name="RareChime",SoundId="rbxasset://sounds/electronicpingshort.wav",Volume=.45})
local lastTick,lastSlot=0,nil
strip:GetPropertyChangedSignal("Position"):Connect(function()
 if panel:GetAttribute("Phase")~="Rolling"then return end
 local slot=math.floor(strip.Position.X.Offset/100)
 if slot~=lastSlot and os.clock()-lastTick>.045 then
  lastSlot=slot;lastTick=os.clock();tickSound:Stop();tickSound:Play()
 end
end)
local rarePopup,rareVersion=nil,0
local function clearRare()
 rareVersion+=1
 if rarePopup then rarePopup:Destroy();rarePopup=nil end
end
local function popRare(reward,mode,meteor)
 clearRare()
 if reward.amount<1000 then return end
 local own=rareVersion
 local duration=meteor and 1.25 or 1.65
 local group=make("CanvasGroup",gui,{Name="RareRewardPopup",AnchorPoint=Vector2.new(.5,.5),
  Position=UDim2.fromScale(.5,.46),Size=UDim2.fromOffset(300,380),
  BackgroundTransparency=1,GroupTransparency=0,ZIndex=20})
 rarePopup=group
 group:SetAttribute("RewardAmount",reward.amount)
 local fit=make("UIScale",group,{Scale=math.min(1,(gui.AbsoluteSize.X-32)/300,(gui.AbsoluteSize.Y*.68)/380)})
 local art=make("ImageLabel",group,{Name="RareCard",AnchorPoint=Vector2.new(.5,.5),
  Position=UDim2.fromScale(.5,.46),Size=UDim2.fromOffset(250,334),BackgroundTransparency=1,
  Image=kit:GetAttribute("GachaCard"..reward.tier) or "",ScaleType=Enum.ScaleType.Fit,ZIndex=21,Rotation=-9})
 local grow=make("UIScale",art,{Scale=.12})
 local amount=label(group,"RareAmount",0,318,300,52,(mode=="Prank" and "+" or "−")..reward.amount,42,
  mode=="Prank" and Color3.fromRGB(255,105,130) or Color3.fromRGB(105,255,164))
 amount.ZIndex=22;stroke(amount,Color3.fromRGB(18,24,32),3)
 Tween:Create(grow,TweenInfo.new(.48,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
 Tween:Create(art,TweenInfo.new(.48,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Rotation=0}):Play()
 rareSound.PlaybackSpeed=reward.amount==2000 and .8 or 1
 rareSound:Stop();rareSound:Play()
 task.delay(.18,function()
  if own~=rareVersion then return end
  rareSound.PlaybackSpeed=reward.amount==2000 and 1.25 or 1.4;rareSound:Stop();rareSound:Play()
 end)
 task.delay(duration-.3,function()
  if own~=rareVersion then return end
  Tween:Create(group,TweenInfo.new(.3),{GroupTransparency=1}):Play()
  Tween:Create(grow,TweenInfo.new(.3),{Scale=.85}):Play()
 end)
 task.delay(duration,function()if own==rareVersion then clearRare()end end)
end
local function display(kind,data)

 if kind=="Full" then queueText.Text="คิวเต็ม";return end
 if kind=="Roll" then
  serial+=1
  clearRare();lastSlot=nil;tickSound:Stop()
  if reelTween then reelTween:Cancel()end
  strip:ClearAllChildren();table.clear(cards)
  local reward=Rewards.Find(data.amount)
  if not reward then return end
  selected=reward
  local targetIndex=29
  for i=1,33 do
   local mode=data.mode
   if data.requestedMode=="Mixed" and i~=targetIndex then mode=random:NextNumber()<.5 and "Prank" or "Help" end
   card(i,i==targetIndex and reward or Rewards.Roll(random),mode)
  end
  panel.Visible=true
  panel:SetAttribute("Phase","Rolling");panel:SetAttribute("ExpectedAmount",data.amount)
  panel:SetAttribute("RequestedMode",data.requestedMode or data.mode)
  panel:SetAttribute("SelectedIndex",targetIndex)
  title.Text=data.mode=="Prank" and "G  ·  สุ่มแกล้ง"or "H  ·  สุ่มช่วย"
  title.TextColor3=data.mode=="Prank" and red or green
  owner.Text=data.name
  senderBadge.Show(data.sender or {name=data.name})
  resultLabel.Text="กำลังสุ่ม..."
  resultLabel.TextColor3=ink
  edge.Color=gold;markerEdge.Color=gold
  strip.Position=UDim2.fromOffset(240-46-100,0)
  endOffset=240-46-(targetIndex-1)*100
  reelTween=Tween:Create(strip,TweenInfo.new(data.duration,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Position=UDim2.fromOffset(endOffset,0)})
  reelTween:Play()
 elseif kind=="Result" then
  serial+=1;local token=serial
  if not senderBadge.Root.Visible then senderBadge.Show(data.sender or {name=data.name})end
  tickSound:Stop()
  local reward=Rewards.Find(data.amount)
  if not reward then return end
  if reelTween then reelTween:Cancel()end
  if endOffset then strip.Position=UDim2.fromOffset(endOffset,0)end
  edge.Color=reward.color:Lerp(gold,.4);markerEdge.Color=reward.color:Lerp(ink,.25)
  panel:SetAttribute("Phase","Result");panel:SetAttribute("ResultAmount",data.amount)
  panel:SetAttribute("ResolvedMode",data.mode)
  if data.meteor then panel.Visible=false end
  resultLabel.Text=reward.tier.."  ·  "..(data.mode=="Prank" and "+"or "−")..data.actual.." บล็อก"
  if data.actual<data.amount then resultLabel.Text..=data.mode=="Help" and " (หมดสนามแล้ว)"or " (คิวเต็ม)"end
  resultLabel.TextColor3=reward.color:Lerp(ink,.55)
  sound.PlaybackSpeed=reward.amount>=1000 and .85 or 1;sound:Stop();sound:Play()
  popRare(reward,data.mode,data.meteor)
  if reward.amount>=1000 then panel.Visible=false end
  markerEdge.Thickness=4
  Tween:Create(markerEdge,TweenInfo.new(.6),{Thickness=2.5}):Play()
  task.delay(Rewards.ResultSeconds-.1,function()
   if serial==token then panel.Visible=false;panel:SetAttribute("Phase","Idle");senderBadge.Hide()end
  end)
 end
end
remote.OnClientEvent:Connect(display)
