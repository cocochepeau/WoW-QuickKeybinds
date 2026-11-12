local _,Q=...
local L=Q.L
local modifiers={LSHIFT=true,RSHIFT=true,LCTRL=true,RCTRL=true,LALT=true,RALT=true,LMETA=true,RMETA=true,UNKNOWN=true}
function Q:NormalizeKey(key)
 if modifiers[key] or key:match("^PAD") and self:IsGamepadModifier(key) then return nil end
 if key=="LeftButton" then key="BUTTON1" elseif key=="RightButton" then key="BUTTON2" elseif key=="MiddleButton" then key="BUTTON3"
 elseif key:match("^Button%d+$") then key=key:upper() end
 local prefix=""
 if IsMetaKeyDown and IsMetaKeyDown() then prefix=prefix.."META-" end
 if IsAltKeyDown() then prefix=prefix.."ALT-" end
 if IsControlKeyDown() then prefix=prefix.."CTRL-" end
 if IsShiftKeyDown() then prefix=prefix.."SHIFT-" end
 if prefix=="" and (key=="BUTTON1" or key=="BUTTON2") then return nil end
 return prefix..key
end
function Q:RequestAssign(key,command,replaceKey)
 local ok,err,conflict=self.engine:Assign(key,command,replaceKey)
 if err=="conflict" then
  self:Confirm(self:KeyText(conflict.key).."\n"..self:ActionLabel(conflict.old).." -> "..self:ActionLabel(conflict.new).."?",function()
   self:Result(self.engine:Assign(conflict.key,conflict.new,conflict.replaceKey,true))
  end)
 else self:Result(ok,err) end
end
function Q:CaptureKey(raw)
 if not self.captureAction or InCombatLockdown() then return end
 if raw=="ESCAPE" then self:StopCapture(); self:HideDialog(); return end
 local key=self:NormalizeKey(raw); if not key then return end
 local command,replace=self.captureAction,self.captureReplace
 self:StopCapture(); self:HideDialog(); self:RequestAssign(key,command,replace)
end
function Q:CaptureGamepadKey(raw)
 if self:IsGamepadModifier(raw) then
  if self.captureHint then self.captureHint:SetText(L["Modifier held. Press another controller button, or Escape to cancel."]) end
 else self:CaptureKey(raw) end
end
function Q:StartCapture(command,replaceKey)
 if not self:Result(self.engine:CanEdit()) then return end
 self:StopCapture()
 self:Dialog(self:ActionLabel(command),function(f)
  self.captureFrame=f; self.captureAction=command; self.captureReplace=replaceKey
  self.captureHint=self.UIText(f,L["Press a key, mouse or controller button. Escape cancels."],18,-60,590)
  f:EnableKeyboard(true); if f.SetPropagateKeyboardInput then f:SetPropagateKeyboardInput(false) end
  f:SetScript("OnKeyDown",function(_,key) self:CaptureKey(key) end)
  if f.EnableGamePadButton then
   f:EnableGamePadButton(true); f:SetScript("OnGamePadButtonDown",function(_,key) self:CaptureGamepadKey(key) end)
  end
  f:SetScript("OnMouseDown",function(_,key) self:CaptureKey(key) end)
  f:EnableMouseWheel(true); f:SetScript("OnMouseWheel",function(_,d) self:CaptureKey(d>0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN") end)
  f:SetScript("OnHide",function() self:StopCapture() end)
 end,660,155)
end
function Q:StopCapture()
 if self.captureFrame then
  self.captureFrame:EnableKeyboard(false)
  if self.captureFrame.EnableGamePadButton then self.captureFrame:EnableGamePadButton(false); self.captureFrame:SetScript("OnGamePadButtonDown",nil) end
  self.captureFrame:SetScript("OnKeyDown",nil); self.captureFrame:SetScript("OnMouseDown",nil); self.captureFrame:SetScript("OnMouseWheel",nil)
 end
 self.captureFrame=nil; self.captureAction=nil; self.captureReplace=nil; self.captureHint=nil
end
function Q:HoverKey(target,raw)
 if InCombatLockdown() or not self.hovering or self.dialog then return end
 if raw=="ESCAPE" then self:Result(self.engine:Clear(target.command)); self:RefreshHover(); return end
 local key=self:NormalizeKey(raw); if not key then return end
 -- Release capture before confirmation so typing cannot alter the hovered target behind the dialog.
 self:RequestAssign(key,target.command)
 if self.dialog then self:PauseHover() end
 self:RefreshHover()
end
function Q:StartHover()
 if not self:Result(self.engine:CanEdit()) then return end
 self:StopCapture(); self:HideDialog(); self:BuildCatalog()
 self.ui.frame:Hide(); self.hovering=true; self:RefreshBadge()
 if not self.hoverDock then
  local f=self.UIBox(UIParent,770,112); f:SetPoint("TOP",UIParent,"TOP",0,-60); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true)
  self.hoverDock=f
  self.hoverTitle=self.UIText(f,"QuickKeybinds",14,-12,610,"GameFontNormalLarge")
  self.hoverHelp=self.UIText(f,"",14,-39,600); self.hoverHelp:SetHeight(58)
  local finish=self.UIButton(f,L.Finish,620,-14,130,function() self:StopHover(); self:Open() end); self:SetButtonRole(finish,"primary")
  f:EnableKeyboard(true)
  if f.SetPropagateKeyboardInput then f:SetPropagateKeyboardInput(true) end
  f:SetScript("OnKeyDown",function(frame,key)
   local close=key=="ESCAPE" and not self.hovered and not self.dialog
   if frame.SetPropagateKeyboardInput then frame:SetPropagateKeyboardInput(not close) end
   if close then self:StopHover(); self.ui.frame:Show(); self:Close() end
  end)
  f.ticker=CreateFrame("Frame",nil,f)
  local elapsed=0
  f.ticker:SetScript("OnUpdate",function(_,dt)
   elapsed=elapsed+dt; if elapsed<.12 then return end; elapsed=0
   if self.hovering then self:RefreshHover() end
  end)
 end
 self.hoverDock:SetScale(self.ui.frame:GetScale()); self.hoverDock:Show()
 self.overlays=self.overlays or {}
 for _,target in ipairs(self.targets) do
  local frame=target.frame; local overlay=self.overlays[target.command]
  if not overlay then
   overlay=CreateFrame("Button",nil,UIParent,"BackdropTemplate"); overlay:SetFrameStrata("DIALOG"); overlay:SetFrameLevel(90)
   overlay:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
   overlay:SetBackdropBorderColor(.3,.8,1,1); overlay:EnableMouse(true); overlay:EnableMouseWheel(true)
   overlay.label=overlay:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); overlay.label:SetPoint("CENTER"); overlay.label:SetWidth(85)
   overlay:SetScript("OnEnter",function(self)
    if not Q.hovering or InCombatLockdown() or Q.dialog then return end
    Q.hovered=self.target; self:EnableKeyboard(true)
    if self.EnableGamePadButton then self:EnableGamePadButton(true) end
    if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
    Q:HoverTooltip(self)
   end)
   overlay:SetScript("OnLeave",function(self) self:EnableKeyboard(false); if self.EnableGamePadButton then self:EnableGamePadButton(false) end; Q.hovered=nil; GameTooltip:Hide() end)
   overlay:SetScript("OnHide",function(self) self:EnableKeyboard(false); if self.EnableGamePadButton then self:EnableGamePadButton(false) end; if Q.hovered==self.target then Q.hovered=nil end end)
   overlay:SetScript("OnKeyDown",function(self,key) Q:HoverKey(self.target,key); if self:IsShown() then Q:HoverTooltip(self) end end)
   overlay:SetScript("OnMouseDown",function(self,key) Q:HoverKey(self.target,key) end)
   overlay:SetScript("OnMouseWheel",function(self,d) Q:HoverKey(self.target,d>0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN") end)
   if overlay.EnableGamePadButton then overlay:SetScript("OnGamePadButtonDown",function(self,key) if not Q:IsGamepadModifier(key) then Q:HoverKey(self.target,key) end end) end
   self.overlays[target.command]=overlay
  end
  overlay.target=target; overlay:ClearAllPoints(); overlay:SetAllPoints(frame)
 end
 self:RefreshHover()
end
function Q:HoverTooltip(overlay)
 local target=overlay.target
 GameTooltip:SetOwner(overlay,"ANCHOR_RIGHT"); GameTooltip:SetText(self:ActionLabel(target.command))
 local bound=self.Engine.KeysFor(self.engine.draft,target.command); local labels={}
 for _,key in ipairs(bound) do labels[#labels+1]=self:KeyText(key) end
 GameTooltip:AddLine(#labels>0 and table.concat(labels,", ") or L["Unbound action"],1,1,1,true)
 GameTooltip:AddLine(self:KeyText("ESCAPE")..": "..L["Clear all"],1,.82,0); GameTooltip:Show()
end
function Q:RefreshHover()
 if not self.hovering then return end
 local paused=InCombatLockdown() or self.engine.external or self.dialog~=nil
 self.hoverTitle:SetText("QuickKeybinds • "..self:F("Pending changes: %d",#self.engine:Pending()))
 self.hoverHelp:SetText(InCombatLockdown() and L["Editing paused in combat. Your draft is preserved."] or self.engine.external and L["Bindings changed outside QuickKeybinds. Reload them or rebase your draft before saving."] or L["Hover a Blizzard action button and press a key. Escape clears that action. Click Finish to return."])
 for _,overlay in pairs(self.overlays or {}) do
  local frame=overlay.target.frame
  overlay:SetShown(not paused and frame:IsVisible())
  overlay:SetBackdropColor(.15,.5,.8,self.engine.db.settings.opacity)
  local bound=self.Engine.KeysFor(self.engine.draft,overlay.target.command)
  overlay.label:SetText(self.engine.db.settings.labels and (#bound>0 and self:KeyText(bound[1]) or "-") or "")
 end
end
function Q:PauseHover()
 for _,overlay in pairs(self.overlays or {}) do overlay:EnableKeyboard(false); if overlay.EnableGamePadButton then overlay:EnableGamePadButton(false) end; overlay:Hide() end
 self.hovered=nil; GameTooltip:Hide()
end
function Q:ResumeHover() if self.hovering then self:RefreshHover() end end
function Q:StopHover()
 self.hovering=false; self:PauseHover(); if self.hoverDock then self.hoverDock:Hide() end
 self:RefreshBadge()
end
