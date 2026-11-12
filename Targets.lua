local _, Q = ...
Q.targets={}; Q.catalog={}; Q.catalogList={}
local function label(value,fallback)
 if type(value)=="string" and value~="" then return value end
 return fallback
end
local bars={
 {"ActionButton","ACTIONBUTTON",12,"Main bar"},
 {"MultiBarBottomLeftButton","MULTIACTIONBAR1BUTTON",12,"Bottom left"},
 {"MultiBarBottomRightButton","MULTIACTIONBAR2BUTTON",12,"Bottom right"},
 {"MultiBarRightButton","MULTIACTIONBAR3BUTTON",12,"Right bar"},
 {"MultiBarLeftButton","MULTIACTIONBAR4BUTTON",12,"Left bar"},
 {"MultiBar5Button","MULTIACTIONBAR5BUTTON",12,"Bar 5"},
 {"MultiBar6Button","MULTIACTIONBAR6BUTTON",12,"Bar 6"},
 {"MultiBar7Button","MULTIACTIONBAR7BUTTON",12,"Bar 7"},
 {"PetActionButton","BONUSACTIONBUTTON",10,"Pet","pet"},
 {"StanceButton","SHAPESHIFTBUTTON",10,"Stance / form","stance"},
}
function Q:BuildCatalog()
 local catalog,list,targets={},{},{}
 for i=1,GetNumBindings() do
  local command,category=GetBinding(i,true)
  if command and not command:match("^HEADER") and not command:match("^PREFACE") then
   -- Categories may already be display text (e.g. "Questie"). An unrelated
   -- global with that name can be a table, so only accept textual translations.
   category=label(category,self.L.Other)
   local item={command=command,name=label(_G["BINDING_NAME_"..command],command),category=label(_G[category],category)}
   catalog[command]=item; list[#list+1]=item
  end
 end
 local function add(frameName,command,group,index,kind)
  local frame=_G[frameName]
  if not catalog[command] and not frame then return end
  local item=catalog[command]
  if not item then
   item={command=command,name=label(_G["BINDING_NAME_"..command],self.L[group].." "..index),category=self.L[group]}
   catalog[command]=item; list[#list+1]=item
  end
  item.bar=self.L[group]; item.frameName=frameName; item.index=index; item.kind=kind
  item.unavailable=not frame
  if frame then targets[#targets+1]={frame=frame,command=command,item=item} end
 end
 for _,bar in ipairs(bars) do for i=1,bar[3] do add(bar[1]..i,bar[2]..i,bar[4],i,bar[5]) end end
 add("ExtraActionButton1","EXTRAACTIONBUTTON1","Extra action",1)
 -- The zone ability button is intentionally omitted: it has no stable native binding command.
 if catalog.VEHICLEEXIT then add("MainMenuBarVehicleLeaveButton","VEHICLEEXIT","Vehicle exit",1) end
 table.sort(list,function(a,b)
  local ac,bc=a.bar or a.category,b.bar or b.category
  if ac~=bc then return ac<bc end
  if a.index and b.index then return a.index<b.index end
  return a.name<b.name
 end)
 self.catalog=catalog; self.catalogList=list; self.targets=targets
end
function Q:ActionDetails(command)
 local item=self.catalog[command]
 if not item then return end
 local frame=item.frameName and _G[item.frameName]
 if not frame then return end
 -- Main-bar commands can be redirected to Blizzard's vehicle/override buttons.
 if command:match("^ACTIONBUTTON%d+$") and GetActionButtonForID then frame=GetActionButtonForID(item.index) or frame end
 local current,texture
 if frame and item.kind=="pet" and GetPetActionInfo then
  local name,icon,isToken=GetPetActionInfo(item.index)
  current=isToken and label(_G[name],label(name)) or label(name)
  texture=isToken and _G[icon] or icon
 elseif frame and item.kind=="stance" and GetShapeshiftFormInfo then
  local icon,_,_,spell=GetShapeshiftFormInfo(item.index); texture=icon
  if spell then current=self:SpellName(spell) end
 elseif frame and GetActionInfo then
  local action=frame.action or (frame.GetPagedID and frame:GetPagedID()) or (frame.GetAttribute and frame:GetAttribute("action"))
  if type(action)=="number" and action>0 then
   local kind,id=GetActionInfo(action)
   local getTexture=GetActionTexture or (C_ActionBar and C_ActionBar.GetActionTexture)
   if kind and getTexture then texture=getTexture(action) end
   if kind=="spell" then current=self:SpellName(id)
   elseif kind=="item" and GetItemInfo then
    local name,_,_,_,_,_,_,_,_,icon=GetItemInfo(id); current=name; texture=texture or icon
   elseif kind=="macro" and GetMacroInfo then
    local name,icon=GetMacroInfo(id); current=name; texture=texture or icon
   elseif kind=="companion" then current=self:SpellName(id) end
  end
 end
 if type(texture)~="number" and type(texture)~="string" then texture=nil end
 return label(current),texture
end
function Q:ActionLabel(command)
 if not command then return self.L["Unbound action"] end
 local item=self.catalog[command]
 if not item then return command end
 local current=self:ActionDetails(command)
 return current and item.name.." - "..current or item.name
end
function Q:SpellName(id)
 if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
 if GetSpellInfo then return GetSpellInfo(id) end
end
function Q:Snapshot()
 local map={}
 for i=1,GetNumBindings() do
  local values={GetBinding(i,true)}; local command=values[1]
  if command then
   for k=3,#values do if values[k] and values[k]~="" then map[values[k]]=command end end
   -- Some Forever builds expose additional keys only through GetBindingKey.
   if GetBindingKey then for _,key in ipairs({GetBindingKey(command)}) do map[key]=command end end
  end
 end
 return map
end
function Q:ApplyNative(map)
 if InCombatLockdown() then return nil,self.L["Editing paused in combat. Your draft is preserved."] end
 local before=self:Snapshot()
 -- Clear changed keys first so swapping two occupied keys does not evict a third binding.
 for _,key in ipairs(self.SortedKeys(before)) do
  if before[key]~=map[key] and not SetBinding(key) then return nil,self:F("Unable to clear %s",self:KeyText(key)) end
 end
 for _,key in ipairs(self.SortedKeys(map)) do
  if before[key]~=map[key] and not SetBinding(key,map[key]) then return nil,self:F("Unable to bind %s",self:KeyText(key)) end
 end
 return true
end
function Q:NativeAPI()
 return {
  locale=function() return GetLocale and GetLocale() end,
  snapshot=function() return self:Snapshot() end,
  scope=function() return GetCurrentBindingSet() end,
  load=function(scope) return LoadBindings(scope) end,
  apply=function(map) return self:ApplyNative(map) end,
  save=function(scope)
   local save=SaveBindings or AttemptToSaveBindings
   if not save then return false,self.L["No supported binding save API on this client."] end
   return save(scope)
  end,
  known=function(command) return self.catalog[command]~=nil end,
  combat=function() return InCombatLockdown() end,
  time=function() return time() end,
  character=function() return (UnitName("player") or "?").."-"..(GetRealmName() or "?") end,
 }
end
