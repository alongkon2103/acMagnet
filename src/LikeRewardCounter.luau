-- Counts explicit raw per-event TikTok likes. quantity is a reward count, never a like count.
local M={}
function M.IsLike(e)
 for _,field in ipairs({"giftId","type","kind","event"})do
  local s=tostring(e[field]or ""):lower()
  if s=="like"or s=="likes"then return true end
 end
 return false
end
function M.new(threshold)
 assert(type(threshold)=="number"and threshold>=1 and threshold%1==0)
 local self={remainder=0,total=0,status="WAITING",seen={},order={},pending=nil}
 function self:Process(e,grant)
  if self.seen[e.id]then return true,"duplicate"end
  local p=self.pending
  if not p then
   local count=e.rawLikeCount
   if count==nil then count=e.likeCount end
   if type(count)~="number"or count~=count or count%1~=0 or count<0 or count>10000000 then
    self.status="RAW_COUNT_MISSING"
    return true,"likes_missing_raw_count"
   end
   local sum=self.remainder+count
   p={id=e.id,count=count,remainder=sum%threshold,left=math.floor(sum/threshold),chunk=1}
   self.pending=p
  elseif p.id~=e.id then return false,"likes_previous_receipt_pending"end
  while p.left>0 do
   local n=math.min(100,p.left)
   local ok,reason=grant(n,e.id..":likes:"..p.chunk)
   if not ok and reason~="duplicate"then self.status="RETRYING";return false,reason end
   p.left-=n;p.chunk+=1
  end
  self.total+=p.count;self.remainder=p.remainder;self.pending=nil;self.status="COUNTING"
  self.seen[e.id]=true;table.insert(self.order,e.id)
  if #self.order>4096 then self.seen[table.remove(self.order,1)]=nil end
  return true
 end
 return self
end
return M
