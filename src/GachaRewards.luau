local M={}
M.RollSeconds=2.4
M.ResultSeconds=2
M.Rewards={
 {amount=30,tier="Common",weight=45,color=Color3.fromRGB(188,204,215)},
 {amount=100,tier="Uncommon",weight=30,color=Color3.fromRGB(78,225,151)},
 {amount=500,tier="Rare",weight=15,color=Color3.fromRGB(73,174,255)},
 {amount=1000,tier="Epic",weight=8,color=Color3.fromRGB(190,113,255)},
 {amount=2000,tier="Legendary",weight=2,color=Color3.fromRGB(255,202,72)},
}
function M.Select(percent)
 assert(type(percent)=="number" and percent>=0 and percent<100,"Roll must be in [0,100)")
 local edge=0
 for _,reward in ipairs(M.Rewards)do
  edge+=reward.weight
  if percent<edge then return reward end
 end
 error("Gacha weights must total 100")
end
function M.Roll(random)return M.Select(random:NextNumber(0,100))end
function M.Find(amount)
 for _,reward in ipairs(M.Rewards)do if reward.amount==amount then return reward end end
end
return M
