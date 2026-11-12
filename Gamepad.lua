local _,Q=...
local L=Q.L
local labels={
 Xbox={PAD1="A",PAD2="B",PAD3="X",PAD4="Y",PADLSHOULDER="LB",PADRSHOULDER="RB",PADLTRIGGER="LT",PADRTRIGGER="RT",PADLSTICK="LS",PADRSTICK="RS",PADBACK="View",PADFORWARD="Menu",PADSYSTEM="Guide",PADSOCIAL="Share"},
 PlayStation={PAD1="Cross",PAD2="Circle",PAD3="Square",PAD4="Triangle",PADLSHOULDER="L1",PADRSHOULDER="R1",PADLTRIGGER="L2",PADRTRIGGER="R2",PADLSTICK="L3",PADRSTICK="R3",PADBACK="Share",PADFORWARD="Options",PADSYSTEM="PS",PADSOCIAL="Touchpad"},
 Nintendo={PAD1="B",PAD2="A",PAD3="Y",PAD4="X",PADLSHOULDER="L",PADRSHOULDER="R",PADLTRIGGER="ZL",PADRTRIGGER="ZR",PADLSTICK="LS",PADRSTICK="RS",PADBACK="-",PADFORWARD="+",PADSYSTEM="Home",PADSOCIAL="Capture"},
}
local common={PADDUP="^",PADDDOWN="v",PADDLEFT="<",PADDRIGHT=">",PADPADDLE1="P1",PADPADDLE2="P2",PADPADDLE3="P3",PADPADDLE4="P4"}
Q.GamepadStyles={"Xbox","PlayStation","Nintendo"}
local nativeStyles={letters="Xbox",xbox="Xbox",shapes="PlayStation",playstation="PlayStation",ps4="PlayStation",ps5="PlayStation",reverse="Nintendo",reverseletters="Nintendo",revletters="Nintendo",nintendo="Nintendo",switch="Nintendo"}
local function readPad(method,...)
 local fn=C_GamePad and C_GamePad[method]
 if type(fn)~="function" then return nil end
 -- A device can disappear between enumerating it and reading its state.
 local ok,value=pcall(fn,...); if ok then return value end
end
local function styleFromName(name)
 if type(name)~="string" then return end
 local s=name:lower()
 if s:find("dualsense",1,true) or s:find("dualshock",1,true) or s:find("playstation",1,true) or s:match("%f[%w]ps[345]%f[%W]") then return "PlayStation" end
 if s:find("nintendo",1,true) or s:find("switch",1,true) or s:find("joy-con",1,true) or s:find("joycon",1,true) then return "Nintendo" end
 if s:find("xbox",1,true) or s:find("xinput",1,true) or s:find("steam deck",1,true) then return "Xbox" end
end
function Q:DetectGamepad()
 if not C_GamePad or type(C_GamePad.GetDeviceMappedState)~="function" then return {style="Xbox",reason="unavailable"} end
 local active=readPad("GetActiveDeviceID"); local combined=readPad("GetCombinedDeviceID")
 local listed=readPad("GetAllDeviceIDs"); local ids,seen={},{}
 if type(listed)=="table" then
  for _,id in ipairs(listed) do
   if type(id)=="number" and id>=0 and id~=combined and not seen[id] then ids[#ids+1]=id; seen[id]=true end
  end
  table.sort(ids)
  if #ids==0 then return {style="Xbox",reason="no_device"} end
  if seen[active] then
   for i,id in ipairs(ids) do if id==active then table.remove(ids,i); table.insert(ids,1,id); break end end
  end
 elseif type(active)=="number" and active>0 and active~=combined then ids[1]=active
 else ids[1]=false end -- Older clients can expose only the optional combined-state API.
 for _,id in ipairs(ids) do
  local state
  if id==false then state=readPad("GetDeviceMappedState") else state=readPad("GetDeviceMappedState",id) end
  if type(state)=="table" then
   local name=type(state.name)=="string" and state.name or nil
   local token=type(state.labelStyle)=="string" and state.labelStyle:lower():gsub("[%s_%-]","") or ""
   local style=nativeStyles[token]
   if style then return {style=style,reason="detected",name=name,deviceID=id or nil} end
   local raw=id~=false and readPad("GetDeviceRawState",id)
   local rawName=type(raw)=="table" and type(raw.name)=="string" and raw.name or nil
   style=styleFromName(name)
   if not style then style=styleFromName(rawName); if style then name=rawName end end
   return {style=style or "Xbox",reason=style and "name" or token=="generic" and "generic" or "unknown",name=name or rawName,deviceID=id or nil}
  end
 end
 return {style="Xbox",reason="no_device"}
end
function Q:ResolveGamepadStyle()
 local chosen=self.engine.db.settings.gamepadStyle
 if labels[chosen] then return chosen,nil,chosen end
 local info=self:DetectGamepad(); return info.style,info,"Auto"
end
function Q:GamepadDetectionSignature(info)
 return info and table.concat({info.style or "",tostring(info.deviceID or ""),info.name or "",info.reason or ""},"\031") or ""
end
function Q:GamepadLabel(key,style)
 local value=common[key] or (labels[style] or labels.Xbox)[key] or key
 local localized={Cross="Cross",Circle="Circle",Square="Square",Triangle="Triangle",View="Controller view",Menu="Menu",Guide="Controller guide",Share="Share",Options="Controller options",PS="PS",Touchpad="Controller touchpad",Home="Controller home",Capture="Controller capture"}
 return localized[value] and self.L[localized[value]] or value
end
function Q:GamepadCVar(name)
 local get=GetCVar or (C_CVar and C_CVar.GetCVar)
 if get then return get(name) end
end
function Q:GamepadSupported(key)
 if not C_GamePad or not C_GamePad.ButtonBindingToIndex then return false end
 return C_GamePad.ButtonBindingToIndex(key)~=nil
end
function Q:GamepadModifierKeys(key)
 local out={}
 for _,mod in ipairs({"shift","ctrl","alt"}) do
  local cvar="GamePadEmulate"..mod:sub(1,1):upper()..mod:sub(2)
  if self:GamepadCVar(cvar)==key then out[#out+1]=mod end
 end
 return out
end
function Q:IsGamepadModifier(key) return #self:GamepadModifierKeys(key)>0 end
function Q:GamepadKeys(style)
 local out={}
 local function add(key,x,y,w,h)
  out[#out+1]={key=key,x=x,y=y,width=w or 72,height=h or 42,gamepad=true}
 end
 add("PADLTRIGGER",192,104,120,34); add("PADRTRIGGER",700,104,120,34)
 add("PADLSHOULDER",192,142,120,34); add("PADRSHOULDER",700,142,120,34)
 local dx,dy=275,184
 if style~="PlayStation" then dx,dy=384,260 end
 add("PADDUP",dx,dy); add("PADDLEFT",dx-78,dy+48); add("PADDRIGHT",dx+78,dy+48); add("PADDDOWN",dx,dy+96)
 add("PAD4",664,184); add("PAD3",586,232); add("PAD2",742,232); add("PAD1",664,280)
 add("PADBACK",416,192,74,34); add("PADFORWARD",522,192,74,34)
 add("PADSYSTEM",471,232,74,34); add("PADSOCIAL",471,272,74,34)
 if style=="PlayStation" then add("PADLSTICK",360,335,96,44) else add("PADLSTICK",240,218,96,52) end
 add("PADRSTICK",556,335,96,44)
 add("PADPADDLE1",20,184); add("PADPADDLE2",20,237); add("PADPADDLE3",920,184); add("PADPADDLE4",920,237)
 return out
end
function Q:BuildGamepadView(parent)
 local ui=self.ui
 ui.gamepadBoard=CreateFrame("Frame",nil,parent); ui.gamepadBoard:SetAllPoints(parent)
 local p=ui.gamepadBoard; ui.gamepadButtons={}
 local body=self.UIBox(p,704,220); body:SetPoint("TOPLEFT",156,-180)
 local left=self.UIBox(p,154,130); left:SetPoint("TOPLEFT",156,-296)
 local right=self.UIBox(p,154,130); right:SetPoint("TOPLEFT",706,-296)
 self.UIText(p,L["Rear buttons"],8,-155,130,"GameFontDisableSmall")
 self.UIText(p,L["Rear buttons"],902,-155,108,"GameFontDisableSmall")
 for _,spec in ipairs(self:GamepadKeys("Xbox")) do
  local b=self.UIButton(p,"",spec.x,-spec.y,spec.width,function() end); b:SetHeight(spec.height); self:SetButtonRole(b,"key")
  b.key=spec.key; b.keySpec=spec
  b.keyLabel=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); b.keyLabel:SetPoint("TOPLEFT",5,-3); b.keyLabel:SetHeight(14); b.keyLabel:SetWordWrap(false)
  b.assignedLabel=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); b.assignedLabel:SetPoint("BOTTOMLEFT",5,4); b.assignedLabel:SetSize(spec.width-10,12); b.assignedLabel:SetWordWrap(false)
  b.actionIcon=b:CreateTexture(nil,"ARTWORK"); b.actionIcon:SetPoint("TOPRIGHT",-4,-3); b.actionIcon:SetSize(14,14); b.actionIcon:SetTexCoord(.08,.92,.08,.92)
  b:RegisterForClicks("LeftButtonUp","RightButtonUp")
  b:SetScript("OnClick",function(self,mouse)
   local full=Q:LayerKey(self.key)
   if mouse=="RightButton" then
    if Q.engine.draft[full] then Q:Confirm(L.Remove.." "..Q:KeyText(full).."?",function() Q:Result(Q.engine:Remove(full)) end) end
   elseif ui.selected then Q:RequestAssign(full,ui.selected)
   elseif Q.engine.draft[full] then ui.selected=Q.engine.draft[full]; Q:RefreshKeyboard()
   else Q:Print(L["No action selected"]) end
  end)
  b:SetScript("OnEnter",function(self) ui.hoverKey=self; Q:KeyboardTooltip(self) end)
  b:SetScript("OnLeave",function() ui.hoverKey=nil; GameTooltip:Hide(); Q:KeyboardSelection() end)
  ui.gamepadButtons[spec.key]=b
 end
 ui.gamepadModifierNote=self.UIText(p,"",344,-110,300,"GameFontDisableSmall"); ui.gamepadModifierNote:SetHeight(64)
 ui.gamepadStatus=self.UIText(p,"",438,-438,565,"GameFontDisableSmall"); ui.gamepadStatus:SetHeight(48)
 self.UIText(p,L["Stick movement uses WoW's movement and camera settings."],4,-466,424,"GameFontDisableSmall")
 local elapsed=0
 p:SetScript("OnUpdate",function(self,dt)
  elapsed=elapsed+dt; if elapsed<.5 then return end; elapsed=0
  if not self:IsVisible() or labels[Q.engine.db.settings.gamepadStyle] then return end
  -- Changing the active controller need not change the keyboard/gamepad input mode.
  local info=Q:DetectGamepad()
  if Q:GamepadDetectionSignature(info)~=Q:GamepadDetectionSignature(ui.gamepadDetection) then Q:RefreshKeyboard() end
 end)
 p:Hide()
end
function Q:RefreshGamepad(style,info)
 local ui,e=self.ui,self.engine
 if not style then style,info=self:ResolveGamepadStyle() end
 ui.gamepadEffectiveStyle=style; ui.gamepadDetection=info
 local editable=not InCombatLockdown() and not e.external
 local mods={}
 for _,spec in ipairs(self:GamepadKeys(style)) do
  local b=ui.gamepadButtons[spec.key]; b.keySpec=spec; b:ClearAllPoints(); b:SetPoint("TOPLEFT",spec.x,-spec.y); b:SetSize(spec.width,spec.height)
  local full=self:LayerKey(spec.key); local cmd=e.draft[full]
  b.qkbKeyState=e.baseline[full]~=cmd and "pending" or cmd and "bound" or "unbound"
  local name,icon=self:ActionDetails(cmd)
  local title=name or cmd and (self.catalog[cmd] and self.catalog[cmd].name or cmd)
  local color=b.qkbKeyState=="pending" and "|cffffcc55" or cmd and "|cff55c9ff" or "|cffdddddd"
  local caption=self:GamepadLabel(spec.key,style); b.keyLabel:SetText(color..caption.."|r"); b.keyLabel:SetWidth(spec.width-(icon and 24 or 10))
  b.assignedLabel:SetText(title or L["Unbound action"]); b.actionIcon:SetTexture(icon); b.actionIcon:SetShown(icon~=nil)
  if editable and self:GamepadSupported(spec.key) then b:Enable() else b:Disable() end
  self:PaintButton(b)
  local modifiers=self:GamepadModifierKeys(spec.key)
  if #modifiers>0 then mods[#mods+1]=caption.." = "..self:ModifierList(modifiers) end
 end
 ui.gamepadModifierNote:SetText(#mods>0 and L["WoW modifier buttons"]..":\n"..table.concat(mods,"\n") or L["Use Shift / Ctrl / Alt above to view modified bindings."])
 local status
 if not C_GamePad or not C_GamePad.ButtonBindingToIndex then status=L["Native gamepad bindings are unavailable on this client."]
 elseif C_GamePad.IsEnabled and not C_GamePad.IsEnabled() then status=L["Gamepad input is disabled in WoW. You can prepare bindings here."]
 else status=L["Left click: assign   •   Right click: remove   •   Hover: full action name"] end
 if info and info.reason~="unavailable" then
  local note
  if info.reason=="no_device" then note=L["No controller detected. Showing an Xbox preview."]
  elseif info.reason=="generic" or info.reason=="unknown" then note=L["Unknown controller layout. Showing Xbox labels; a manual choice is available."]
  else note=L["Detected controller"]..": "..(info.name or style).." ("..style..")" end
  status=status.."\n"..note
 end
 ui.gamepadStatus:SetText(status)
 self:KeyboardSelection(); if ui.hoverKey then self:KeyboardTooltip(ui.hoverKey) end
end
