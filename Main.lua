local addonName,Q=...
local events=CreateFrame("Frame")
Q.events=events
function Q:Result(ok,err)
 if not ok and err then
  self:Print(err); if self.ui then self.ui.message=tostring(err); self:Refresh() end
 end
 return ok
end
function Q:Open()
 if not self.engine then return end
 if InCombatLockdown() then self:Print(self.L["Editing paused in combat. Your draft is preserved."]); return end
 if self.hovering then self:StopHover() end
 self:BuildCatalog()
 if not self.engine.draft then if not self:Result(self.engine:Begin(GetCurrentBindingSet())) then return end end
 self.engine:CheckExternal()
 self:CreateUI(); self.ui.frame:Show(); self:Refresh()
end
function Q:Close()
 if not self.ui then return end
 self:StopCapture(); self:StopHover()
 if self.engine:Dirty() then
  self:Confirm(self.L["Close without saving"].."?\n"..self.L["Your draft stays available until reload/logout."],function() self.ui.frame:Hide() end)
 else self.ui.frame:Hide() end
end
function Q:Initialize()
 local _,_,_,interface=GetBuildInfo()
 if not interface or interface<16001 or interface>=20000 then
  self:Print(self.L["This version supports WoW Forever (interface 16001) only."]); return
 end
 QuickKeybindsDB=type(QuickKeybindsDB)=="table" and QuickKeybindsDB or {}
 QuickKeybindsDB.version=1
 self:BuildCatalog(); self.engine=self.Engine.New(self:NativeAPI(),QuickKeybindsDB)
 self.engine.onChange=function() if self.ui then self:Refresh() end end
 SLASH_QUICKKEYBINDS1="/qkb"; SLASH_QUICKKEYBINDS2="/quickkeybinds"
 SlashCmdList.QUICKKEYBINDS=function() self:Open() end
 -- Respect existing /kb owners regardless of the name of their slash handler.
 local claimed=false
 for k,v in pairs(_G) do if type(k)=="string" and k:match("^SLASH_") and type(v)=="string" and v:lower()=="/kb" then claimed=true; break end end
 if not claimed then SLASH_QUICKKEYBINDS3="/kb" end
 self:Print("v"..self.version.." - /qkb")
end
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent",function(_,event,name)
 if event=="ADDON_LOADED" and name==addonName then
  events:UnregisterEvent("ADDON_LOADED"); Q:Initialize()
  if Q.engine then
   for _,e in ipairs({"UPDATE_BINDINGS","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","PLAYER_ENTERING_WORLD","ACTIONBAR_SLOT_CHANGED","ACTIONBAR_PAGE_CHANGED","UPDATE_BONUS_ACTIONBAR","UPDATE_SHAPESHIFT_FORM","UPDATE_SHAPESHIFT_FORMS","PET_BAR_UPDATE","UPDATE_MACROS","GET_ITEM_INFO_RECEIVED","SPELLS_CHANGED"}) do events:RegisterEvent(e) end
   if C_GamePad and C_GamePad.ButtonBindingToIndex then
    for _,e in ipairs({"GAME_PAD_CONNECTED","GAME_PAD_DISCONNECTED","GAME_PAD_ACTIVE_CHANGED","GAME_PAD_CONFIGS_CHANGED","CVAR_UPDATE"}) do events:RegisterEvent(e) end
   end
  end
 elseif not Q.engine then return
 elseif event=="UPDATE_BINDINGS" then Q.engine:CheckExternal()
 elseif event=="PLAYER_REGEN_DISABLED" then
  if Q.keyboardDetectionFrame then Q:HideDialog() end
  if Q.captureFrame then Q:StopCapture(); Q:HideDialog() end
  Q:PauseHover(); if Q.ui then Q:Refresh() end
 elseif event=="PLAYER_REGEN_ENABLED" then
  Q:ResumeHover(); Q.engine:CheckExternal(); if Q.ui then Q:Refresh() end
 elseif event=="PLAYER_ENTERING_WORLD" then Q:BuildCatalog()
 elseif Q.ui and Q.ui.frame:IsShown() then
  if C_Timer and C_Timer.After then
   -- Let Blizzard finish updating the buttons' paged action IDs first.
   if not Q.refreshQueued then
    Q.refreshQueued=true
    C_Timer.After(0,function() Q.refreshQueued=false; if Q.ui.frame:IsShown() then Q:Refresh() end end)
   end
  else Q:Refresh() end
 end
end)
