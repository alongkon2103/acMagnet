local source=game.ReplicatedStorage.BlackHole:FindFirstChild("ArenaMath")
assert(source,"ArenaMath missing")
local A=require(source)
assert(A.NormalizePercent(0)==100 and A.NormalizePercent(999)==200 and A.NormalizePercent(150.6)==151)
for _,value in {0/0,math.huge,-math.huge,"150",true,{}}do assert(A.NormalizePercent(value)==nil)end
assert(A.ScaleAt(1,2,10,9)==1 and A.ScaleAt(1,2,10,11)==2)
assert(math.abs(A.ScaleAt(1,2,10,10.5)-1.875)<1e-6)
local previous=1
for i=0,100 do local v=A.ScaleAt(1,2,10,10+i/100);assert(v>=previous and v>=1 and v<=2);previous=v end
local current=A.ScaleAt(1,2,10,10.3)
assert(A.ScaleAt(current,1,10.3,10.3)==current)
assert(A.ScaleAt(current,1,10.3,11.3)==1)
assert(A.CanChange(false,false,false,false)==false and A.CanChange(false,false,false,true)==true)
return "Arena math checks passed"
