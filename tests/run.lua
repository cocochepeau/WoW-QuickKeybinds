local count=0
local function check(value,message) count=count+1; assert(value,message or ("check "..count.." failed")) end
local function equal(a,b,message) check(a==b,(message or "values differ")..": "..tostring(a).." ~= "..tostring(b)) end
local function loadModule(name,Q,env)
 local f=assert(loadfile(addonRoot.."/"..name..".lua")); if env then setfenv(f,env) end
 f("QuickKeybinds",Q)
end
local Q={}; loadModule("Engine",Q)
local E=Q.Engine
local function fixture()
 local s={scope=1,live={A="ACTION1",B="ACTION2",C="ACTION1"},sets={[1]={A="ACTION1",B="ACTION2",C="ACTION1"},[2]={Z="ACTION2"}},saves=0,loads=0,combat=false}
 local api={
  snapshot=function() return Q.Copy(s.live) end, scope=function() return s.scope end,
  combat=function() return s.combat end, time=function() return 1000 end, character=function() return "Player-Realm" end,
  known=function(c) return c=="ACTION1" or c=="ACTION2" or c=="ACTION3" end,
  load=function(which) s.loads=s.loads+1; s.loaded=which; if not s.previewOnly then s.scope=which end; s.live=Q.Copy(s.sets[which]); return true end,
  apply=function(map)
   if s.failApply then s.failApply=false; s.live={BROKEN="ACTION2"}; return nil,"apply failure" end
   if s.evict then s.evict=false; s.live={}; return true end
   s.live=Q.Copy(map); return true
  end,
  save=function(which)
   s.saves=s.saves+1
   if s.failSave then s.failSave=false; return false,"disk failure" end
   s.sets[which]=Q.Copy(s.live)
   s.scope=which
   if s.nilSave then return nil end
   return true
  end,
 }
 local e=E.New(api,{}); assert(e:Begin(1)); return e,s,api
end
do
 local e,s=fixture(); check(not e:Dirty()); equal(#e:Pending(),0)
 check(e:Assign("D","ACTION3")); equal(s.live.D,nil,"draft must not touch live keys"); equal(s.saves,0)
 equal(e.draft.D,"ACTION3"); equal(#e:Pending(),1)
 check(e:Undo()); check(not e:Dirty()); check(e:Redo()); equal(e.draft.D,"ACTION3")
 local ok,err,conflict=e:Assign("B","ACTION3"); check(not ok); equal(err,"conflict"); equal(conflict.old,"ACTION2")
 equal(e.draft.B,"ACTION2"); check(e:Assign("B","ACTION3",nil,true)); equal(e.draft.B,"ACTION3")
 check(e:Assign("E","ACTION1","C")); equal(e.draft.C,nil); equal(e.draft.A,"ACTION1"); equal(e.draft.E,"ACTION1")
 check(e:Clear("ACTION1")); equal(#E.KeysFor(e.draft,"ACTION1"),0)
 check(e:Undo()); equal(#E.KeysFor(e.draft,"ACTION1"),2)
 check(e:Remove("E")); equal(e.draft.A,"ACTION1"); equal(e.draft.E,nil)
 check(e:Discard()); check(not e:Dirty()); equal(#e.undo,0); equal(s.saves,0)
 check(not e:Assign("BUTTON1","ACTION1")); check(not e:Assign("BUTTON2","ACTION1")); check(e:Assign("CTRL-BUTTON1","ACTION1"))
 check(not e:Assign("X","EVIL")); equal(e.draft.X,nil)
 check(e:Save()); equal(s.live["CTRL-BUTTON1"],"ACTION1"); equal(s.saves,1); check(not e:Dirty())
 equal(e.db.history[1].kind,"save"); equal(e.db.history[2].kind,"backup"); equal(e.db.history[2].map["CTRL-BUTTON1"],nil)
 check(e:Save()); equal(s.saves,1,"no-op saves should not write")
end
do
 local e,s=fixture(); s.nilSave=true; check(e:Assign("X","ACTION3")); check(e:Save()); equal(s.sets[1].X,"ACTION3")
end
for _,failure in ipairs({"failApply","failSave","evict"}) do
 local e,s=fixture(); local before=Q.Copy(s.live); s[failure]=true; check(e:Assign("D","ACTION3"))
 local ok,err=e:Save(); check(not ok,failure.." should fail"); check(err~=nil); check(E.Equal(s.live,before),failure.." rollback live")
 check(E.Equal(s.sets[1],before),failure.." rollback persisted"); check(e:Dirty(),"draft kept after failure")
 check(e.db.history[1].kind=="backup"); equal(e.draft.D,"ACTION3"); check(e:Save()); equal(s.sets[1].D,"ACTION3")
end
do
 local e,s=fixture(); local before=Q.Copy(s.live)
 check(e:Begin(2)); equal(e.scope,2); equal(e.draft.Z,"ACTION2"); equal(s.scope,1); check(E.Equal(s.live,before)); equal(s.saves,0)
 check(e:Assign("X","ACTION3")); check(not e:Begin(1)); equal(e.scope,2)
 check(e:Save()); equal(s.scope,2); equal(s.sets[2].X,"ACTION3"); check(E.Equal(s.sets[1],before)); equal(e.db.history[2].scope,2)
 check(e:Begin(1)); equal(s.scope,2); equal(e.draft.A,"ACTION1")
 check(e:Save()); equal(s.scope,1); check(E.Equal(s.sets[2],{Z="ACTION2",X="ACTION3"}))
end
do
 local e,s=fixture(); local before=Q.Copy(s.live); check(e:Begin(2)); check(e:Assign("X","ACTION3")); s.failSave=true
 check(not e:Save()); equal(s.scope,1); check(E.Equal(s.live,before)); check(E.Equal(s.sets[2],{Z="ACTION2"})); equal(e.scope,2)
end
do
 local e,s=fixture(); check(e:Assign("X","ACTION3")); s.combat=true
 check(not e:Save()); check(not e:Assign("Y","ACTION2")); check(not e:Undo()); check(not e:Redo()); check(not e:Discard()); check(not e:Begin(2)); check(not e:Rebase()); check(not e:Reload())
 equal(s.saves,0); equal(e.draft.X,"ACTION3"); s.combat=false; check(e:Save())
end
do
 local e,s=fixture(); check(e:Assign("X","ACTION3")); s.live.Y="ACTION2"; s.sets[1].Y="ACTION2"
 e:CheckExternal(); check(e.external); check(not e:Save()); check(not e:Assign("D","ACTION2")); equal(s.saves,0)
 local expected=Q.Copy(s.live); s.live.EXTRA="ACTION2"; s.sets[1].EXTRA="ACTION2"
 check(not e:Rebase(expected),"stale rebase previews must not apply")
 check(e:Rebase()); check(not e.external); equal(e.draft.Y,"ACTION2"); equal(e.draft.X,"ACTION3"); equal(e.baseline.X,nil)
 check(e:Save()); equal(s.live.Y,"ACTION2"); equal(s.live.X,"ACTION3")
 s.scope=2; s.live=Q.Copy(s.sets[2]); e:CheckExternal(); check(e.external); check(e:Reload()); equal(e.scope,2); equal(e.draft.Z,"ACTION2")
end
do
 local e,s=fixture(); check(e:Assign("X","ACTION3")); s.live.A="ACTION2"; s.sets[1].A="ACTION2"
 check(not e:Save(),"save must detect missed UPDATE_BINDINGS events"); equal(s.saves,0)
 check(e:Reload()); equal(e.draft.X,nil); equal(e.draft.A,"ACTION2")
end
do
 local e=fixture(); check(e:CreateProfile("Raid")); check(not e:CreateProfile("Raid")); check(not e:CreateProfile("")); check(not e:CreateProfile("\n"))
 check(e:Assign("D","ACTION3")); equal(e.db.profiles.Raid.map.D,nil,"profiles must be isolated snapshots")
 check(e:CreateProfile("Copy",e.db.profiles.Raid.map)); check(e:RenameProfile("Copy","PvP")); check(not e.db.profiles.Copy)
 check(not e:RenameProfile("PvP","Raid")); check(e:RenameProfile("PvP","PvP"))
 local preview=assert(e:PreviewMap(e.db.profiles.Raid.map)); equal(#preview.changes,1); equal(e.draft.D,"ACTION3")
 check(e:ApplyPreview(preview,"Raid")); equal(e.activeProfile,"Raid"); equal(e.draft.D,nil); check(e:Undo()); equal(e.draft.D,"ACTION3")
 local unknown=assert(e:PreviewMap({X="UNKNOWN"})); equal(#unknown.missing,1); check(not e:ApplyPreview(unknown))
end
do
 local e=fixture(); local map={}; local nativeKeys={"A","SHIFT-1","ALT-CTRL-SHIFT-MOUSEWHEELDOWN","CTRL-BUTTON1","BUTTON10","NUMPADPLUS","[","]","\\","/",";","'","=","-","`",",","."}
 for _,key in ipairs(nativeKeys) do map[key]="ACTION1" end
 local exported=e:Export(map,"Prêtre: PvP 100%")
 local imported=assert(e:Import(exported)); equal(imported.name,"Prêtre: PvP 100%"); check(E.Equal(map,imported.map))
 check(e:Import(exported:gsub("\n","\r\n")))
 for _,bad in ipairs({"return os.execute('bad')","QKB2\tX\nA\tACTION1","QKB1\tX\nA\tACTION1\nA\tACTION2","QKB1\tX\nA%GG\tACTION1","QKB1\tX\nA%\tACTION1","QKB1\tX\nBUTTON1\tACTION1","QKB1\tX\nA\tACTION1%0Aevil","QKB1\tX\nA\tACTION1\textra",string.rep("X",262145)}) do check(not e:Import(bad),"reject bad import: "..bad:sub(1,60)) end
 local missing=assert(e:Import("QKB1\tMissing\nA\tUNAVAILABLE")); equal(missing.missing[1],"UNAVAILABLE"); check(not e:ApplyPreview(missing))
 equal(e.draft.A,"ACTION1"); check(not e:Dirty(),"import preview alone does not change draft")
 for i=1,100 do
  local sample={}; for j=1,20 do sample["CTRL-F"..j]="ACTION"..((i+j)%3+1) end
  local p=assert(e:Import(e:Export(sample,"Test "..i))); check(E.Equal(sample,p.map))
 end
end
do
 local e=fixture(); for i=1,55 do e:Record("backup",{A="ACTION1"},"backup") end
 equal(#e.db.history,50); e.db.history[1].map.A="ACTION2"; equal(e.db.history[2].map.A,"ACTION1")
 e.db.settings.confirmConflicts=false; check(e:Assign("B","ACTION1")); equal(e.draft.B,"ACTION1")
 for i=1,110 do assert(e:Assign("F"..i,"ACTION2")) end
 equal(#e.undo,100); check(e:Undo()); check(e:Assign("T","ACTION3")); equal(#e.redo,0)
end
do
 local e,s,api=fixture(); local original=api.load; local before=Q.Copy(s.live)
 api.load=function(scope) original(scope); if scope==2 then error("load interrupted") end return true end
 check(not e:Begin(2)); equal(s.scope,1); check(E.Equal(s.live,before)); equal(s.saves,0)
end
for _,fail in ipairs({false,true}) do
 local e,s=fixture(); s.previewOnly=true; local original=Q.Copy(s.live)
 check(e:Begin(2)); equal(s.scope,1); equal(e.draft.Z,"ACTION2"); check(E.Equal(s.live,original)); equal(s.saves,0)
 check(e:Assign("X","ACTION3")); s.failSave=fail
 local ok=e:Save()
 if fail then check(not ok); equal(s.scope,1); check(E.Equal(s.live,original)); equal(s.sets[2].X,nil)
 else check(ok); equal(s.scope,2); equal(s.sets[2].X,"ACTION3"); equal(s.live.X,"ACTION3") end
end
do
 local e,s,api=fixture(); local original=api.snapshot; local before=Q.Copy(s.live)
 api.snapshot=function() if s.scope==2 then error("snapshot failed") end return original() end
 check(not e:Begin(2)); equal(s.scope,1); check(E.Equal(s.live,before)); equal(s.saves,0)
end
do
 local e,s,api=fixture(); local original=api.apply
 api.apply=function(map) if s.failAll then return nil,"persistent failure" end return original(map) end
 check(e:Assign("X","ACTION3")); s.failAll=true
 local ok,err=e:Save(); check(not ok); check(err:find("Rollback failed",1,true)); check(e.external); check(e:Dirty()); equal(e.db.history[1].map.A,"ACTION1")
end
do
 local e,s=fixture(); e.baseline.BUTTON1="ACTION1"; e.draft.BUTTON1="ACTION1"
 check(e:Clear("ACTION1")); equal(e.draft.BUTTON1,"ACTION1"); check(e:Remove("BUTTON1")); equal(e.draft.BUTTON1,"ACTION1")
 check(e:Import(e:Export())); local p=assert(e:PreviewMap({Z="ACTION2"})); equal(p.map.BUTTON1,"ACTION1")
 check(e:ApplyPreview(p)); equal(e.draft.BUTTON1,"ACTION1")
end

-- Native API and UI fixture. Unknown methods intentionally fail to catch accidental API assumptions.
local function client(locale,interface,kbOwner,configure)
 local env={}; env._G=env; setmetatable(env,{__index=_G})
 local widgets={}; env.widgets=widgets; local apiState={scope=1,combat=false,map={A="ACTIONBUTTON1",B="ACTIONBUTTON2",C="JUMP"},sets={}}
 apiState.sets[1]=Q.Copy(apiState.map); apiState.sets[2]={Z="JUMP"}
 local methods={}
 local function event(w,key,...) if w.scripts and w.scripts[key] then return w.scripts[key](w,...) end end
 function methods:SetSize(w,h) self.width=w; self.height=h; event(self,"OnSizeChanged",w,h) end
 function methods:SetWidth(w) self.width=w end; function methods:SetHeight(h) self.height=h end
 function methods:GetWidth() return self.width or (self.parent and self.parent:GetWidth()) or 1000 end
 function methods:GetHeight() return self.height or 280 end
 function methods:SetPoint(...) self.points=self.points or {}; self.points[#self.points+1]={...} end
 function methods:ClearAllPoints() self.points={} end
 function methods:SetAllPoints(frame) self.anchor=frame end
 function methods:SetScript(k,f) self.scripts[k]=f end
 function methods:HookScript(k,f) local prev=self.scripts[k]; self.scripts[k]=function(...) if prev then prev(...) end f(...) end end
 function methods:Show() local old=self.shown; self.shown=true; if not old then event(self,"OnShow") end end
 function methods:Hide() local old=self.shown; self.shown=false; if old then event(self,"OnHide") end end
 function methods:SetShown(v) if v then self:Show() else self:Hide() end end
 function methods:IsShown() return self.shown end
 function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
 function methods:SetText(t) self.text=t; if self.fontString then self.fontString.text=t end; event(self,"OnTextChanged",true) end
 function methods:GetText() return self.text or "" end
 function methods:SetScale(s) self.scale=s end; function methods:GetScale() return self.scale or 1 end
 function methods:SetChecked(v) self.checked=v end; function methods:GetChecked() return self.checked end
 function methods:Enable() local old=self.enabled; self.enabled=true; if old==false then event(self,"OnEnable") end end
 function methods:Disable() local old=self.enabled; self.enabled=false; if old~=false then event(self,"OnDisable") end end
 function methods:IsEnabled() return self.enabled end
 function methods:SetFontString(value) self.fontString=value end
 function methods:SetTextColor(...) self.textColor={...} end
 function methods:IsTruncated() return self.truncated or false end
 function methods:SetColorTexture(...) self.colorTexture={...} end
 function methods:SetTitle(value) self.title=value; if self.TitleText then self.TitleText:SetText(value) end end
 function methods:EnableKeyboard(v) self.keyboard=v end
 function methods:EnableGamePadButton(v) self.gamepad=v end
 function methods:EnableMouse(v) self.mouse=v end
 function methods:EnableMouseWheel(v) self.wheel=v end
 function methods:SetPropagateKeyboardInput(v) self.propagate=v end
 function methods:SetScrollChild(c) self.child=c; c.parent=self end
 function methods:GetVerticalScroll() return self.scroll or 0 end
 function methods:SetVerticalScroll(v) self.scroll=v end
 function methods:GetVerticalScrollRange() return math.max(0,(self.child and self.child:GetHeight() or 0)-self:GetHeight()) end
 function methods:GetStringHeight() return math.max(14,math.ceil(#(self.text or "")/85)*14) end
 function methods:SetParent(p) self.parent=p end
 function methods:RegisterEvent(e) self.events[e]=true end; function methods:UnregisterEvent(e) self.events[e]=nil end
 function methods:Click(mouse) if self.enabled~=false then return event(self,"OnClick",mouse or "LeftButton") end end
 function methods:GetAttribute(k) return self.attributes and self.attributes[k] end
 function methods:GetFrameLevel() return 10 end
 for _,name in ipairs({"SetBackdrop","SetBackdropColor","SetBackdropBorderColor","SetJustifyH","SetWordWrap","SetFrameStrata","SetFrameLevel","SetClampedToScreen","SetMovable","RegisterForDrag","StartMoving","StopMovingOrSizing","SetHighlightTexture","SetMaxLetters","SetAutoFocus","HighlightText","SetFocus","ClearFocus","SetMultiLine","SetFontObject","UpdateScrollChildRect","RegisterForClicks","SetOwner","AddLine"}) do methods[name]=function() end end
 local function frame(kind,name,parent,template)
  local w=setmetatable({kind=kind,name=name,parent=parent,template=template,scripts={},events={},shown=true,enabled=true},{__index=methods})
  widgets[#widgets+1]=w; if name then env[name]=w end
  if template=="ButtonFrameTemplate" then w.Inset=frame("Frame",nil,w); w.CloseButton=frame("Button",nil,w); w.TitleText=frame("FontString",nil,w) end
  return w
 end
 function methods:CreateFontString(...) return frame("FontString",nil,self) end
 function methods:CreateTexture(...) return frame("Texture",nil,self) end
 function methods:SetTexture(value) self.texture=value end
 function methods:SetTexCoord(...) self.texCoord={...} end
 function methods:AddLine(value) self.lines=self.lines or {}; self.lines[#self.lines+1]=value end
 function methods:SetBackdrop(value) self.backdrop=value end
 function methods:SetBackdropColor(...) self.backdropColor={...} end
 function methods:SetBackdropBorderColor(...) self.borderColor={...} end
 function methods:SetFocus() self.focused=true end
 function methods:ClearFocus() self.focused=false end
 env.ButtonFrameTemplate_HidePortrait=function(f) f.portraitHidden=true end
 env.CreateFrame=frame; env.UIParent=frame("Frame","UIParent"); env.UIParent:SetSize(1920,1080)
 env.GameTooltip=frame("GameTooltip"); env.ChatFontNormal={}
 env.DEFAULT_CHAT_FRAME={AddMessage=function(_,message) env.lastMessage=message end}
 env.GetLocale=function() return locale or "enUS" end; env.GetBuildInfo=function() return "1.0","0","",interface or 16001 end
 env.SlashCmdList={}; if kbOwner then env.SLASH_OTHER1="/kb"; env.SlashCmdList.OTHER=function() end end
 local commands={"ACTIONBUTTON1","ACTIONBUTTON2","ACTIONBUTTON3","MULTIACTIONBAR1BUTTON1","MULTIACTIONBAR2BUTTON1","MULTIACTIONBAR3BUTTON1","MULTIACTIONBAR4BUTTON1","MULTIACTIONBAR5BUTTON1","MULTIACTIONBAR6BUTTON1","MULTIACTIONBAR7BUTTON1","BONUSACTIONBUTTON1","SHAPESHIFTBUTTON1","EXTRAACTIONBUTTON1","JUMP","TOGGLEBAG4"}
 env.GetNumBindings=function() return #commands end
 env.GetBinding=function(i)
  local cmd=commands[i]; local k=E.KeysFor(apiState.map,cmd); return cmd,"CATEGORY",unpack(k)
 end
 env.GetBindingKey=function(cmd) return unpack(E.KeysFor(apiState.map,cmd)) end
 env.GetCurrentBindingSet=function() return apiState.scope end
 env.LoadBindings=function(scope) apiState.scope=scope; apiState.map=Q.Copy(apiState.sets[scope]); if env.notify then env.notify() end; return true end
 env.SetBinding=function(key,cmd) apiState.map[key]=cmd; if env.notify then env.notify() end; return true end
 env.SaveBindings=function(scope) apiState.sets[scope]=Q.Copy(apiState.map); return true end
 env.GetBindingText=function(key) return "<"..key..">" end
 env.InCombatLockdown=function() return apiState.combat end
 env.time=function() return 1000 end; env.date=function() return "2026-11-11 12:00:00" end
 env.UnitName=function() return "Player" end; env.GetRealmName=function() return "Realm" end
 env.IsShiftKeyDown=function() return apiState.shift end; env.IsControlKeyDown=function() return apiState.ctrl end; env.IsAltKeyDown=function() return apiState.alt end
 for _,name in ipairs({"ActionButton1","ActionButton2","ActionButton3","MultiBarBottomLeftButton1","MultiBarBottomRightButton1","MultiBarRightButton1","MultiBarLeftButton1","MultiBar5Button1","MultiBar6Button1","MultiBar7Button1","PetActionButton1","StanceButton1","ExtraActionButton1"}) do frame("Button",name,env.UIParent) end
 env.ActionButton1.action=1; env.GetActionInfo=function() return "spell",123 end; env.C_Spell={GetSpellName=function() return "Fireball" end}
 env.GetActionTexture=function(slot) return slot+1000 end
 env.GetPetActionInfo=function() return "Attack",1001,false end
 env.GetShapeshiftFormInfo=function() return nil,nil,nil,321 end
 if configure then configure(env,apiState,commands) end
 local addon={}
 for _,module in ipairs({"Locale","Locales/enUS","Locales/frFR","Locales/deDE","Engine","Targets","Theme","Keyboard","Gamepad","UI","Capture","Main"}) do loadModule(module,addon,env) end
 event(addon.events,"OnEvent","ADDON_LOADED","QuickKeybinds")
 env.fire=function(name,...) return event(addon.events,"OnEvent",name,...) end
 env.notify=function() env.fire("UPDATE_BINDINGS") end
 env.find=function(label,parent)
  for i=#widgets,1,-1 do local w=widgets[i]; if w.text==label and w.kind=="Button" and (not parent or w.parent==parent) then return w end end
  error("Missing button: "..label)
 end
 return addon,env,apiState
end
do
 local q,w,s=client(); check(q.engine~=nil); equal(w.SLASH_QUICKKEYBINDS1,"/qkb"); equal(w.SLASH_QUICKKEYBINDS3,"/kb")
 q:Open(); check(q.ui.frame:IsShown()); equal(q.ui.page,"Bindings"); equal(q.ui.rows[1].command~=nil,true)
 check(q:ActionLabel("ACTIONBUTTON1"):find("Fireball",1,true)); equal(q.catalog.MULTIACTIONBAR1BUTTON1.frameName,"MultiBarBottomLeftButton1")
 equal(q.catalog.MULTIACTIONBAR2BUTTON1.frameName,"MultiBarBottomRightButton1"); equal(q.catalog.MULTIACTIONBAR3BUTTON1.frameName,"MultiBarRightButton1")
 equal(q.catalog.MULTIACTIONBAR4BUTTON1.frameName,"MultiBarLeftButton1"); equal(q.catalog.BONUSACTIONBUTTON1.kind,"pet")
 for _,page in ipairs({"Bindings","Keyboard & Mouse","Profiles","History","Settings"}) do q.ui.nav[page]:Click(); equal(q.ui.page,page) end
 q.ui.nav.Bindings:Click(); q.ui.selected="ACTIONBUTTON1"; q:Refresh()
 q:StartCapture("ACTIONBUTTON1"); check(q.captureFrame.keyboard); q:CaptureKey("LSHIFT"); check(q.captureAction~=nil)
 s.ctrl=true; s.shift=true; q:CaptureKey("D"); equal(q.engine.draft["CTRL-SHIFT-D"],"ACTIONBUTTON1"); equal(s.map["CTRL-SHIFT-D"],nil); check(q.captureFrame==nil); s.ctrl=false; s.shift=false
 q:StartCapture("ACTIONBUTTON1"); q:CaptureKey("ESCAPE"); equal(q.captureAction,nil); check(q.dialog==nil)
 q:RequestAssign("B","ACTIONBUTTON1"); check(q.dialog~=nil); equal(q.engine.draft.B,"ACTIONBUTTON2")
 w.find(q.L.Confirm,q.dialog):Click(); equal(q.engine.draft.B,"ACTIONBUTTON1"); equal(q.dialog,nil)
 q.ui.undo:Click(); equal(q.engine.draft.B,"ACTIONBUTTON2"); q.ui.redo:Click(); equal(q.engine.draft.B,"ACTIONBUTTON1")
 q.ui.save:Click(); equal(s.map.B,"ACTIONBUTTON1"); check(not q.engine:Dirty()); equal(#q.engine.db.history,2)
 q.ui.nav.History:Click(); q.ui.historyRows[2].restore:Click(); check(q.dialog~=nil); w.find(q.L["Apply to draft"],q.dialog):Click(); check(q.engine:Dirty()); equal(s.map.B,"ACTIONBUTTON1")
 q.ui.discard:Click(); w.find(q.L.Confirm,q.dialog):Click(); check(not q.engine:Dirty())
 q.ui.nav.Profiles:Click(); w.find(q.L["New profile"],q.ui.pages.Profiles):Click()
 local input; for _,widget in ipairs(w.widgets) do if widget.kind=="EditBox" and widget.parent==q.dialog then input=widget end end
 input:SetText("Test profile"); w.find(q.L.Confirm,q.dialog):Click(); check(q.engine.db.profiles["Test profile"]~=nil)
 q.ui.profileRows[1].preview:Click(); w.find(q.L["Apply to draft"],q.dialog):Click(); equal(q.engine.activeProfile,"Test profile")
 q:TextDialog(q.engine:Export(),false); check(q.dialog~=nil); q:HideDialog(); q:TextDialog(q.engine:Export(),true); w.find(q.L.Preview,q.dialog):Click(); check(q.dialog~=nil); q:HideDialog()
 q.ui.nav["Keyboard & Mouse"]:Click(); local found
 for _,key in ipairs(q.ui.keyButtons) do if key.baseKey=="F5" then found=key end end
 q.ui.modButtons.ctrl:Click(); found:Click(); equal(q.engine.draft["CTRL-F5"],"ACTIONBUTTON1"); equal(s.map["CTRL-F5"],nil)
 found:Click("RightButton"); w.find(q.L.Confirm,q.dialog):Click(); equal(q.engine.draft["CTRL-F5"],nil)
 q.ui.layoutButton:Click(); equal(q.engine.db.settings.layout,"AZERTY"); q:RefreshKeyboard()
 q.ui.nav.Settings:Click(); q.ui.settingsControls.labels:SetChecked(false); q.ui.settingsControls.labels:Click(); check(not q.engine.db.settings.labels)
 q.ui.settingsLayout:Click(); equal(q.engine.db.settings.layout,"QWERTZ")
 q.ui.nav.Bindings:Click(); q:StartHover(); check(q.hovering); check(not q.ui.frame:IsShown()); check(q.hoverDock:IsShown())
 local overlay=q.overlays.ACTIONBUTTON1; overlay.scripts.OnEnter(overlay); check(overlay.keyboard)
 overlay.scripts.OnKeyDown(overlay,"F6"); equal(q.engine.draft.F6,"ACTIONBUTTON1"); equal(s.map.F6,nil)
 overlay.scripts.OnMouseWheel(overlay,1); equal(q.engine.draft.MOUSEWHEELUP,"ACTIONBUTTON1")
 overlay.scripts.OnKeyDown(overlay,"ESCAPE"); equal(#E.KeysFor(q.engine.draft,"ACTIONBUTTON1"),0)
 s.combat=true; w.fire("PLAYER_REGEN_DISABLED"); check(not overlay:IsShown()); check(not overlay.keyboard); check(q.hovering)
 s.combat=false; w.fire("PLAYER_REGEN_ENABLED"); check(overlay:IsShown())
 w.find(q.L.Finish,q.hoverDock):Click(); check(not q.hovering); check(q.ui.frame:IsShown()); check(q.engine:Dirty())
 q:Close(); check(q.dialog~=nil); w.find(q.L.Confirm,q.dialog):Click(); check(not q.ui.frame:IsShown()); check(q.engine:Dirty()); check(q.ui.badge:IsShown()); q.ui.badge:Click(); check(q.ui.frame:IsShown()); check(not q.ui.badge:IsShown())
 q:Result(q.engine:Discard()); s.map.NEW="JUMP"; w.fire("UPDATE_BINDINGS"); check(q.engine.external); check(q.ui.externalReload:IsShown()); check(not q.ui.save.enabled)
 s.sets[1]=Q.Copy(s.map); q.ui.externalRebase:Click(); w.find(q.L["Apply to draft"],q.dialog):Click(); check(not q.engine.external); equal(q.engine.draft.NEW,"JUMP")
 s.combat=true; w.fire("PLAYER_REGEN_DISABLED"); check(not q.ui.add.enabled); check(not q.ui.scope.enabled); s.combat=false; w.fire("PLAYER_REGEN_ENABLED")
 q:StartCapture("ACTIONBUTTON1"); s.combat=true; w.fire("PLAYER_REGEN_DISABLED"); equal(q.captureAction,nil); equal(q.dialog,nil); s.combat=false; w.fire("PLAYER_REGEN_ENABLED")
 q:Confirm("Pool warmup",function() end); q:HideDialog(); local size=#w.widgets
 for i=1,30 do q:Confirm("Confirm "..i,function() end); q:HideDialog() end
 equal(#w.widgets,size,"repeated conflict dialogs must reuse native frames")
 q.ui.nav.Bindings:Click(); q.ui.category:Click(); w.find(q.L["Main bar"],q.dialog.categoryChild):Click(); equal(q.ui.categoryFilter,q.L["Main bar"])
 for _,row in ipairs(q.ui.rows) do if row:IsShown() then check(row.command:match("^ACTIONBUTTON")) end end
 q.ui.category:Click(); w.find(q.L.All,q.dialog.categoryChild):Click(); equal(q.ui.categoryFilter,nil)
 q.ui.filters.Unbound:Click(); for _,row in ipairs(q.ui.rows) do if row:IsShown() then equal(#E.KeysFor(q.engine.draft,row.command),0) end end
 q.ui.filters.All:Click(); q.ui.query="fireball"; q:RefreshBindings(); local matched=0
 for _,row in ipairs(q.ui.rows) do if row:IsShown() then check(q:ActionLabel(row.command):find("Fireball",1,true)); matched=matched+1 end end
 check(matched>0); q.ui.query=""; q:RefreshBindings()
 q.engine:Assign("F10","ACTIONBUTTON1"); q.ui.frame.scripts.OnKeyDown(q.ui.frame,"ESCAPE"); check(q.dialog~=nil); q:HideDialog()
 w.UIParent:SetSize(1024,768); q:Refresh(); check(q.ui.frame:GetScale()*1060<=994); check(q.ui.frame:GetScale()*740<=738)
 -- All scrolling pages keep their content in a scroll child.
 equal(q.ui.bindingChild.parent,q.ui.bindingScroll); equal(q.ui.profileChild.parent,q.ui.profileScroll); equal(q.ui.historyChild.parent,q.ui.historyScroll)
end
do
 local q,w=client("frFR",16001,true); q:Open(); equal(q.L.Bindings,"Raccourcis"); equal(w.SLASH_QUICKKEYBINDS3,nil,"must not steal /kb"); check(q.ui.frame:IsShown())
 q.ui.nav.Profiles:Click(); q.ui.nav.History:Click(); q.ui.nav.Settings:Click()
end
do
 local q,w=client("enUS",120105); check(q.engine==nil); check(w.lastMessage:find("Forever",1,true)); equal(w.SLASH_QUICKKEYBINDS1,nil)
end
do
 local q,w,s=client(); q:Open(); w.AttemptToSaveBindings=w.SaveBindings; w.SaveBindings=nil
 check(q.engine:Assign("F8","ACTIONBUTTON1")); check(q.engine:Save()); equal(s.map.F8,"ACTIONBUTTON1")
 local original=w.SetBinding; local failOnce=true
 w.SetBinding=function(key,cmd) if failOnce then failOnce=false; return nil end return original(key,cmd) end
 check(q.engine:Assign("F9","ACTIONBUTTON1")); local ok,err=q.engine:Save(); check(not ok); check(err:find("Unable to bind",1,true)); equal(s.map.F9,nil); check(q.engine:Dirty())
end
do
 local cases={
  {category="Questie",global={name="Questie"},expected="Questie"},
  {category="BINDING_HEADER_TARGETING",global="Ciblage",expected="Ciblage"},
  {category="Ciblage",global={name="collision"},expected="Ciblage"},
  {category="Missing header",expected="Missing header"},
  {category="",expected="Autres"},
  {category=false,expected="Autres"},
  {category=42,expected="Autres"},
  {category={},expected="Autres"},
  {expected="Autres"},
 }
 for _,case in ipairs(cases) do
  local q,w=client("frFR",16001,false,function(env,state,commands)
   local original=env.GetBinding; commands[#commands+1]="QUESTIE_TOGGLE_JOURNEY"
   if type(case.category)=="string" then env[case.category]=case.global end
   env.BINDING_NAME_QUESTIE_TOGGLE_JOURNEY={name="invalid label"}
   env.BINDING_NAME_ACTIONBUTTON1={name="invalid bar label"}
   env.CreateFrame("Button","ActionButton4",env.UIParent)
   env.BINDING_NAME_ACTIONBUTTON4={name="invalid fallback bar label"}
   env.GetBinding=function(index)
    if commands[index]=="QUESTIE_TOGGLE_JOURNEY" then return "QUESTIE_TOGGLE_JOURNEY",case.category end
    return original(index)
   end
  end)
  equal(q.catalog.QUESTIE_TOGGLE_JOURNEY.category,case.expected)
  equal(q.catalog.QUESTIE_TOGGLE_JOURNEY.name,"QUESTIE_TOGGLE_JOURNEY")
  equal(q.catalog.ACTIONBUTTON1.name,"ACTIONBUTTON1")
  equal(q.catalog.ACTIONBUTTON4.name,q.L["Main bar"].." 4")
  q:Open(); check(q.ui.frame:IsShown()); q:ChooseCategory(); q:HideDialog()
  q.ui.query="questie"; q:RefreshBindings()
  equal(q.ui.rows[1].command,"QUESTIE_TOGGLE_JOURNEY")
  q:BuildCatalog(); equal(q.catalog.QUESTIE_TOGGLE_JOURNEY.category,case.expected)
 end
end
do
 local q,w,s=client("frFR",16001,false,function(env,state)
  state.actions={[1]={"spell",3044},[2]={"item",42},[3]={"macro",7},[13]={"spell",75},[73]={"spell",999}}
  env.QuickKeybindsDB={settings={layout="QWERTY"}} -- Existing manual choices retain their display arrangement.
  env.ActionButton2.action=2; env.ActionButton3.attributes={action=3}
  env.GetActionInfo=function(slot) local a=state.actions[slot]; if a then return unpack(a) end end
  env.C_Spell.GetSpellName=function(id) return ({[3044]="Tir des arcanes",[75]="Tir automatique",[321]="Forme de félin",[999]="Action véhicule"})[id] end
  env.BINDING_NAME_JUMP="Sauter"
  env.GetItemInfo=function() return "Potion de soins",nil,nil,nil,nil,nil,nil,nil,nil,420 end
  env.GetMacroInfo=function() return "Ma macro",700 end
  env.GetPetActionInfo=function() return "PET_ACTION_ATTACK","PET_ATTACK_TEXTURE",true end
  env.PET_ACTION_ATTACK="Attaque"; env.PET_ATTACK_TEXTURE=12345
  env.GetShapeshiftFormInfo=function() return 54321,nil,nil,321 end
 end)
 q:Open(); q.ui.nav["Keyboard & Mouse"]:Click()
 local function key(name) for _,b in ipairs(q.ui.keyButtons) do if b.key==name then return b end end error("Missing key "..name) end
 local a=key("A")
 equal(a.assignedLabel:GetText(),"Tir des arcanes"); equal(a.actionIcon.texture,1001); check(a.actionIcon:IsShown())
 check(a.keyLabel:GetText():find("<A>",1,true)); equal(a.assignedLabel:GetWidth(),a:GetWidth()-8); equal(a.assignedLabel:GetHeight(),12)
 a.scripts.OnEnter(a); check(q.ui.keyboardSelection:GetText():find("Tir des arcanes",1,true))
 check(w.GameTooltip.lines[#w.GameTooltip.lines-1]:find("Tir des arcanes",1,true))
 a.scripts.OnLeave(a); equal(q.ui.hoverKey,nil)
 equal(key("B").assignedLabel:GetText(),"Potion de soins"); equal(key("C").assignedLabel:GetText(),"Sauter"); check(not key("C").actionIcon:IsShown())
 local free=key("F12"); equal(free.assignedLabel:GetText(),""); check(not free.actionIcon:IsShown())
 check(q.engine:Assign("CTRL-A","ACTIONBUTTON2")); q.ui.modButtons.ctrl:Click()
 equal(a.assignedLabel:GetText(),"Potion de soins"); equal(a.actionIcon.texture,1002)
 check(q.engine:Assign("CTRL-A","ACTIONBUTTON3",nil,true)); equal(a.assignedLabel:GetText(),"Ma macro"); equal(a.actionIcon.texture,1003)
 check(q.engine:Undo()); equal(a.assignedLabel:GetText(),"Potion de soins")
 q.ui.modButtons.ctrl:Click(); equal(a.assignedLabel:GetText(),"Tir des arcanes")
 q.ui.layoutButton:Click(); a=key("A"); equal(a.baseKey,"Q"); equal(a.assignedLabel:GetText(),"Tir des arcanes")
 -- A page switch changes the spell shown on the same native button command.
 w.ActionButton1.action=13; w.fire("ACTIONBAR_PAGE_CHANGED"); equal(a.assignedLabel:GetText(),"Tir automatique"); equal(a.actionIcon.texture,1013)
 -- Coalesce action events and read the native button state after its own event handlers.
 local queue={}; w.C_Timer={After=function(_,callback) queue[#queue+1]=callback end}
 w.fire("ACTIONBAR_SLOT_CHANGED"); w.fire("ACTIONBAR_PAGE_CHANGED"); equal(#queue,1)
 w.ActionButton1.action=1; queue[1](); equal(a.assignedLabel:GetText(),"Tir des arcanes"); check(not q.refreshQueued)
 w.C_Timer=nil
 s.actions[1]=nil; w.fire("ACTIONBAR_SLOT_CHANGED"); equal(a.assignedLabel:GetText(),"ACTIONBUTTON1"); check(not a.actionIcon:IsShown())
 s.actions[1]={"spell",3044}; w.fire("SPELLS_CHANGED"); equal(a.assignedLabel:GetText(),"Tir des arcanes")
 local name,icon=q:ActionDetails("BONUSACTIONBUTTON1"); equal(name,"Attaque"); equal(icon,12345)
 name,icon=q:ActionDetails("SHAPESHIFTBUTTON1"); equal(name,"Forme de félin"); equal(icon,54321)
 -- Item and macro icons can come from their own APIs when action textures are absent.
 w.GetActionTexture=nil
 name,icon=q:ActionDetails("ACTIONBUTTON2"); equal(name,"Potion de soins"); equal(icon,420)
 name,icon=q:ActionDetails("ACTIONBUTTON3"); equal(name,"Ma macro"); equal(icon,700)
 w.C_ActionBar={GetActionTexture=function(slot) return slot+9000 end}; q:RefreshKeyboard(); equal(a.actionIcon.texture,9001)
 w.GetActionButtonForID=function() return {action=73} end
 w.fire("UPDATE_BONUS_ACTIONBAR"); equal(a.assignedLabel:GetText(),"Action véhicule"); equal(a.actionIcon.texture,9073)
 name,icon=q:ActionDetails("JUMP"); equal(name,nil); equal(icon,nil)
 equal(s.map.A,"ACTIONBUTTON1","presentation must not change live bindings"); equal(s.map["CTRL-A"],nil)
end
do
 local q,w,s=client("frFR"); q:Open()
 check(q.ui.frame.qkbNative); check(q.ui.frame.portraitHidden); equal(q.ui.frame.title,"QuickKeybinds")
 equal(q.ui.frame.CloseButton.template,nil) -- Reuse the native frame's own close control.
 equal(q.ui.nav.Bindings.qkbRole,"tab"); check(q.ui.nav.Bindings.qkbSelected); check(q.ui.nav.Bindings:IsEnabled())
 q.ui.nav["Keyboard & Mouse"]:Click(); check(q.ui.nav["Keyboard & Mouse"].qkbSelected); check(not q.ui.nav.Bindings.qkbSelected)
 check(q.ui.nav["Keyboard & Mouse"].qkbMark:IsShown()); check(not q.ui.nav.Bindings.qkbMark:IsShown())
 local bound,free
 for _,b in ipairs(q.ui.keyButtons) do if b.key=="A" then bound=b elseif b.key=="F12" then free=b end end
 equal(bound.template,"BackdropTemplate"); equal(bound.qkbRole,"key"); equal(bound.qkbKeyState,"bound"); equal(free.qkbKeyState,"unbound")
 check(bound.borderColor[3]~=free.borderColor[3]); equal(bound.keyLabel:GetWidth(),bound:GetWidth()-22); equal(bound.assignedLabel:GetWidth(),bound:GetWidth()-8)
 q.ui.modButtons.shift:Click(); check(q.ui.modButtons.shift.qkbSelected); check(q.ui.modButtons.shift.qkbMark:IsShown()); equal(bound.qkbKeyState,"unbound")
 q.ui.modButtons.shift:Click(); check(not q.ui.modButtons.shift.qkbSelected)
 check(q.engine:Assign("F12","ACTIONBUTTON1")); equal(free.qkbKeyState,"pending"); equal(free.borderColor[1],.72)
 equal(q.ui.save.qkbRole,"primary"); check(q.ui.save:IsEnabled()); check(q.ui.save.qkbText.textColor[1]>.8)
 q.ui.frame.CloseButton:Click(); check(q.ui.frame:IsShown()); check(q.dialog~=nil); check(q.engine:Dirty()); q:HideDialog()
 q.ui.discard:Click(); w.find(q.L.Confirm,q.dialog):Click(); check(not q.ui.save:IsEnabled()); equal(q.ui.save.qkbText.textColor[1],q.Theme.muted[1])
 q.ui.frame.CloseButton:Click(); check(not q.ui.frame:IsShown()); q:Open()
 -- Text and control bounds fit the page and footer at the fixed reference size.
 for _,b in ipairs(q.ui.keyButtons) do
  equal(b.qkbText:GetWidth(),b:GetWidth()-16)
  local point=b.points[#b.points]; check(point[2]>=0 and point[2]+b:GetWidth()<=1012)
  check(-point[3]+b:GetHeight()<=488)
 end
 q.ui.nav.Bindings:Click(); check(q.ui.filters.All.qkbSelected); check(q.ui.filters.All:IsEnabled())
 q.ui.filters.Pending:Click(); check(q.ui.filters.Pending.qkbSelected); check(not q.ui.filters.All.qkbSelected)
 q.ui.filters.All:Click(); q.ui.rows[1]:Click(); check(q.ui.rows[1].qkbRow)
 q:Confirm("One",function() end); local confirm=w.find(q.L.Confirm,q.dialog); check(confirm.qkbRole=="primary")
 q:HideDialog(); q:PromptName("Profile",function() end); confirm=w.find(q.L.Confirm,q.dialog); equal(confirm.qkbRole,"button"); check(not confirm.qkbSelected); q:HideDialog()
 q.ui.nav["Keyboard & Mouse"]:Click(); s.combat=true; w.fire("PLAYER_REGEN_DISABLED"); check(not free:IsEnabled()); equal(free.borderColor[1],.18)
end
do
 local q,w=client("enUS",16001,false,function(env) env.ButtonFrameTemplate_HidePortrait=nil end)
 q:Open(); check(not q.ui.frame.qkbNative); equal(q.ui.frame.template,"BackdropTemplate")
 equal(q.ui.frame.CloseButton.template,"UIPanelCloseButton"); q.ui.nav["Keyboard & Mouse"]:Click(); check(q.ui.frame:IsShown())
 q.ui.frame.CloseButton:Click(); check(not q.ui.frame:IsShown())
end
do
 local q,w,s=client("frFR",16001,false,function(env,state,commands)
  env.GetBindingText=function(key) return key end
  env.CreateFrame("Button","ActionButton7",env.UIParent).action=7
  commands[#commands+1]="ACTIONBUTTON7"; state.map.F7="ACTIONBUTTON7"; state.sets[1].F7="ACTIONBUTTON7"
  env.C_Spell.GetSpellName=function() return "Morsure de la mangouste" end
 end)
 q:Open(); q.ui.nav["Keyboard & Mouse"]:Click()
 local function key(name,group)
  for _,b in ipairs(q.ui.keyButtons) do if b.baseKey==name and (not group or b.keySpec.group==group) then return b end end
  error("Missing keyboard key: "..name)
 end
 local a,space,enter=key("A"),key("SPACE"),key("ENTER","main")
 check(space:GetWidth()>a:GetWidth()*5,"spacebar should span several letter keys")
 check(enter:GetWidth()>a:GetWidth()*2,"main Enter should be wide")
 check(key("LSHIFT"):GetWidth()>a:GetWidth()*2); check(key("RSHIFT"):GetWidth()>a:GetWidth()*2)
 check(key("TAB"):GetWidth()>a:GetWidth()); check(key("BACKSPACE"):GetWidth()>a:GetWidth())
 check(key("A").keySpec.x>key("Q").keySpec.x,"typing rows should be staggered")
 check(key("Z").keySpec.x>key("A").keySpec.x)
 check(key("F5").keySpec.x-key("F4").keySpec.x>a:GetWidth()+4,"function key groups should have gutters")
 check(key("UP").keySpec.y<key("DOWN").keySpec.y); equal(key("UP").keySpec.x,key("DOWN").keySpec.x)
 check(key("NUMPAD7").keySpec.x>key("PAGEUP").keySpec.x+key("PAGEUP"):GetWidth())
 check(key("NUMPADPLUS"):GetHeight()>a:GetHeight()*2); check(key("NUMPAD0"):GetWidth()>a:GetWidth()*2)
 -- No physical keycaps overlap, including the double-height keypad keys.
 local overlap
 for i,b in ipairs(q.ui.keyButtons) do
  local a=b.keySpec
  for j=i+1,#q.ui.keyButtons do
   local c=q.ui.keyButtons[j].keySpec
   if a.x<c.x+c.width and c.x<a.x+a.width and a.y<c.y+c.height and c.y<a.y+a.height then overlap=a.key.." / "..c.key end
  end
 end
 check(not overlap,"overlapping keycaps: "..tostring(overlap))
 local before=q.Copy(q.engine.draft)
 key("LSHIFT"):Click(); check(q.ui.modifiers.shift); check(key("RSHIFT").qkbSelected); check(q.ui.modButtons.shift.qkbSelected)
 check(q.Engine.Equal(q.engine.draft,before),"modifier keycaps must not assign bare modifiers")
 key("RSHIFT"):Click(); check(not q.ui.modifiers.shift); check(not key("LSHIFT").qkbSelected)
 key("LCTRL"):Click(); check(q.ui.modifiers.ctrl); key("RCTRL"):Click(); check(not q.ui.modifiers.ctrl)
 key("LALT"):Click(); check(q.ui.modifiers.alt); key("RALT"):Click(); check(not q.ui.modifiers.alt)
 check(not key("WINLEFT"):IsEnabled()); key("WINLEFT"):Click(); check(q.Engine.Equal(q.engine.draft,before))
 check(q.engine:Assign("ENTER","ACTIONBUTTON1")); local numEnter=key("ENTER","numpad")
 equal(enter.assignedLabel:GetText(),numEnter.assignedLabel:GetText()); check(numEnter.keySpec.alias)
 numEnter:Click("RightButton"); w.find(q.L.Confirm,q.dialog):Click(); equal(q.engine.draft.ENTER,nil); equal(enter.assignedLabel:GetText(),"")
 equal(q.engine.draft.NUMPADENTER,nil,"do not invent a separate native numpad Enter key")
 local f7=key("F7"); f7.scripts.OnEnter(f7)
 equal(q.ui.keyboardSelection:GetText(),"F7: ACTIONBUTTON7 - Morsure de la mangouste")
 equal(q.L.Enter,"Entrée"); check(f7.keyLabel:GetText():find("F7",1,true))
 f7.scripts.OnLeave(f7)
 for _,name in ipairs({"UI.lua","Capture.lua","Main.lua","Targets.lua"}) do
  local f=assert(io.open(addonRoot.."/"..name,"rb")); local source=f:read("*a"); f:close()
  check(not source:find("\226\134\146",1,true),name.." must not introduce unsupported arrow glyphs")
  check(not source:find("\226\136\146",1,true),name.." must use a font-safe minus")
 end
end
do
 local q,w,s=client("frFR",16001,false,function(env,state)
  state.padEnabled=true; state.fullReads=0
  state.map.PAD1="ACTIONBUTTON1"; state.map.PAD2="ACTIONBUTTON2"; state.map["SHIFT-PAD1"]="ACTIONBUTTON2"; state.sets[1]=Q.Copy(state.map)
  env.ActionButton3.action=3
  env.C_GamePad={ButtonBindingToIndex=function(key) if key:match("^PAD") and key~="PADPADDLE4" then return 0 end end,IsEnabled=function() return state.padEnabled end}
  env.GetCVar=function(name) return ({GamePadEmulateShift="PADLTRIGGER",GamePadEmulateCtrl="PADLSHOULDER",GamePadEmulateAlt="none"})[name] end
  env.SetCVar=function() error("QuickKeybinds must not change native gamepad configuration") end
  local original=env.GetBinding
  env.GetBinding=function(index,includeGamepad) if includeGamepad then state.fullReads=state.fullReads+1 end return original(index) end
 end)
 q:Open(); q.ui.nav["Keyboard & Mouse"]:Click(); q.ui.deviceButtons.Gamepad:Click()
 check(q.ui.gamepadBoard:IsShown()); check(not q.ui.keyboardBoard:IsShown()); check(q.ui.deviceButtons.Gamepad.qkbSelected)
 check(s.fullReads>0); equal(q.engine.baseline.PAD1,"ACTIONBUTTON1"); equal(q.engine.baseline["SHIFT-PAD1"],"ACTIONBUTTON2")
 local gp=q.ui.gamepadButtons
 check(gp.PAD1:IsEnabled()); check(not gp.PADPADDLE4:IsEnabled()); check(gp.PAD1.keyLabel:GetText():find("A",1,true))
 equal(gp.PAD1.assignedLabel:GetText(),"Fireball"); equal(gp.PAD1.actionIcon.texture,1001)
 check(q.ui.gamepadModifierNote:GetText():find("LT = "..q.L.Shift,1,true)); check(q.ui.gamepadModifierNote:GetText():find("LB = "..q.L.Ctrl,1,true))
 q.ui.selected="ACTIONBUTTON3"; gp.PAD3:Click(); equal(q.engine.draft.PAD3,"ACTIONBUTTON3"); equal(s.map.PAD3,nil)
 gp.PAD1:Click(); check(q.dialog~=nil); equal(q.engine.draft.PAD1,"ACTIONBUTTON1"); w.find(q.L.Confirm,q.dialog):Click(); equal(q.engine.draft.PAD1,"ACTIONBUTTON3")
 q.ui.undo:Click(); equal(q.engine.draft.PAD1,"ACTIONBUTTON1"); q.ui.redo:Click(); equal(q.engine.draft.PAD1,"ACTIONBUTTON3")
 gp.PAD2:Click("RightButton"); w.find(q.L.Confirm,q.dialog):Click(); equal(q.engine.draft.PAD2,nil); equal(q.engine.draft.B,"ACTIONBUTTON2")
 q.ui.modButtons.shift:Click(); equal(gp.PAD1.assignedLabel:GetText(),"ACTIONBUTTON2"); check(gp.PAD1.keyLabel:GetText():find("A",1,true))
 gp.PAD4:Click(); equal(q.engine.draft["SHIFT-PAD4"],"ACTIONBUTTON3"); q.ui.modButtons.shift:Click()
 local before=q.Copy(q.engine.draft)
 q.ui.layoutButton:Click(); equal(q.engine.db.settings.gamepadStyle,"Xbox")
 q.ui.layoutButton:Click(); equal(q.engine.db.settings.gamepadStyle,"PlayStation"); check(gp.PAD1.keyLabel:GetText():find(q.L.Cross,1,true)); equal(gp.PADLSTICK.keySpec.y,335)
 q.ui.layoutButton:Click(); equal(q.engine.db.settings.gamepadStyle,"Nintendo"); check(gp.PAD1.keyLabel:GetText():find("B",1,true))
 q.ui.layoutButton:Click(); equal(q.engine.db.settings.gamepadStyle,"Auto"); check(q.Engine.Equal(before,q.engine.draft)); equal(q.engine.db.settings.layout,"AZERTY")
 gp.PAD1.scripts.OnEnter(gp.PAD1); check(q.ui.keyboardSelection:GetText():find(q:GamepadLabel("PAD1",q.ui.gamepadEffectiveStyle),1,true)); gp.PAD1.scripts.OnLeave(gp.PAD1)
 for _,style in ipairs(q.GamepadStyles) do
  local keys=q:GamepadKeys(style); local overlap
  for i,a in ipairs(keys) do
   check(a.x>=0 and a.x+a.width<=1012 and a.y>=103 and a.y+a.height<=430,style.." gamepad bounds")
   for j=i+1,#keys do
    local b=keys[j]
    if a.x<b.x+b.width and b.x<a.x+a.width and a.y<b.y+b.height and b.y<a.y+a.height then overlap=a.key.." / "..b.key end
   end
  end
  check(not overlap,style.." overlapping buttons: "..tostring(overlap))
 end
 q:StartCapture("ACTIONBUTTON3"); local capture=q.captureFrame; check(capture.gamepad)
 capture.scripts.OnGamePadButtonDown(capture,"PADLTRIGGER"); check(q.captureAction~=nil); equal(q.engine.draft.PADLTRIGGER,nil)
 equal(q.captureHint:GetText(),q.L["Modifier held. Press another controller button, or Escape to cancel."])
 s.shift=true; capture.scripts.OnGamePadButtonDown(capture,"PAD3"); s.shift=false
 equal(q.engine.draft["SHIFT-PAD3"],"ACTIONBUTTON3"); check(not capture.gamepad); equal(q.captureAction,nil); equal(s.map["SHIFT-PAD3"],nil)
 local imported=assert(q.engine:Import(q.engine:Export())); equal(imported.map["SHIFT-PAD3"],"ACTIONBUTTON3"); check(q.Engine.Equal(imported.map,q.engine.draft))
 q.ui.save:Click(); equal(s.map.PAD3,"ACTIONBUTTON3"); equal(s.map["SHIFT-PAD3"],"ACTIONBUTTON3"); equal(s.map.A,"ACTIONBUTTON1"); equal(s.map["SHIFT-PAD1"],"ACTIONBUTTON2")
 check(not q.engine:Dirty()); s.padEnabled=false; w.fire("CVAR_UPDATE","GamePadEnable"); equal(q.ui.gamepadStatus:GetText(),q.L["Gamepad input is disabled in WoW. You can prepare bindings here."]); check(gp.PAD1:IsEnabled())
 s.combat=true; w.fire("PLAYER_REGEN_DISABLED"); check(not gp.PAD1:IsEnabled()); s.combat=false; w.fire("PLAYER_REGEN_ENABLED"); check(gp.PAD1:IsEnabled())
 q:StartCapture("ACTIONBUTTON1"); capture=q.captureFrame; s.combat=true; w.fire("PLAYER_REGEN_DISABLED"); check(not capture.gamepad); equal(q.captureAction,nil); s.combat=false; w.fire("PLAYER_REGEN_ENABLED")
 q:StartHover(); local overlay=q.overlays.ACTIONBUTTON1; overlay.scripts.OnEnter(overlay); check(overlay.gamepad)
 overlay.scripts.OnGamePadButtonDown(overlay,"PADLTRIGGER"); equal(q.engine.draft.PADLTRIGGER,nil)
 overlay.scripts.OnGamePadButtonDown(overlay,"PAD4"); equal(q.engine.draft.PAD4,"ACTIONBUTTON1"); equal(s.map.PAD4,nil)
 q:StopHover(); check(not overlay.gamepad); q:Open()
 q.ui.deviceButtons.Keyboard:Click(); check(q.ui.keyboardBoard:IsShown()); check(not q.ui.gamepadBoard:IsShown()); equal(q.engine.db.settings.layout,"AZERTY")
end
do
 local q,w=client(); q:Open(); q.ui.nav["Keyboard & Mouse"]:Click(); q.ui.deviceButtons.Gamepad:Click()
 equal(q.ui.gamepadStatus:GetText(),q.L["Native gamepad bindings are unavailable on this client."])
 for _,b in pairs(q.ui.gamepadButtons) do check(not b:IsEnabled()) end
 q.ui.deviceButtons.Keyboard:Click(); check(q.ui.keyboardBoard:IsShown())
end
do
 local q,w,s=client("frFR",16001,false,function(env,state)
  state.ids={1}; state.active=1; state.devices={[1]={labelStyle="Shapes",name="DualSense Wireless Controller"}}; state.detectReads=0
  env.C_GamePad={
   ButtonBindingToIndex=function() return 0 end, IsEnabled=function() return true end,
   GetCombinedDeviceID=function() return 0 end,
   GetAllDeviceIDs=function() return state.ids end,
   GetActiveDeviceID=function() return state.active end,
   GetDeviceMappedState=function(id) state.detectReads=state.detectReads+1; if state.failState then error("disconnected during read") end; return state.devices[id] end,
  }
  env.SetCVar=function() error("detecting a controller must not change native settings") end
 end)
 q:Open(); q.ui.nav["Keyboard & Mouse"]:Click(); q.ui.deviceButtons.Gamepad:Click()
 local gp=q.ui.gamepadButtons
 equal(q.engine.db.settings.gamepadStyle,nil,"automatic by default without rewriting preferences")
 equal(q.ui.gamepadEffectiveStyle,"PlayStation"); check(q.ui.layoutButton:GetText():find("Auto (PlayStation)",1,true))
 equal(gp.PADLSTICK.keySpec.y,335); check(gp.PAD1.keyLabel:GetText():find(q.L.Cross,1,true))
 check(q.ui.gamepadStatus:GetText():find("DualSense Wireless Controller",1,true))
 local before=q.Copy(q.engine.draft); local initial=q.Copy(s.map)
 s.devices[2]={labelStyle="Letters",name="Xbox Wireless Controller"}; s.ids={2,1}; s.active=2
 w.fire("GAME_PAD_CONNECTED"); equal(q.ui.gamepadEffectiveStyle,"Xbox"); equal(q.ui.gamepadDetection.deviceID,2)
 check(gp.PAD1.keyLabel:GetText():find("A",1,true)); equal(gp.PADLSTICK.keySpec.y,218)
 -- Switching between two live controllers may not emit an input-mode event.
 s.active=1; q.ui.gamepadBoard.scripts.OnUpdate(q.ui.gamepadBoard,.6)
 equal(q.ui.gamepadEffectiveStyle,"PlayStation"); equal(q.ui.gamepadDetection.deviceID,1)
 s.devices[3]={labelStyle="Reverse",name="Nintendo Switch Pro Controller"}; s.ids={1,2,3}; s.active=3
 w.fire("GAME_PAD_ACTIVE_CHANGED",true); equal(q.ui.gamepadEffectiveStyle,"Nintendo"); check(gp.PAD1.keyLabel:GetText():find("B",1,true))
 check(q.Engine.Equal(before,q.engine.draft)); check(q.Engine.Equal(initial,s.map)); equal(#q.engine.undo,0)
 -- A stale active ID never wins over the physical device list after unplugging.
 s.ids={1}; s.active=3; w.fire("GAME_PAD_DISCONNECTED"); equal(q.ui.gamepadEffectiveStyle,"PlayStation"); equal(q.ui.gamepadDetection.deviceID,1)
 s.ids={}; w.fire("GAME_PAD_DISCONNECTED"); equal(q.ui.gamepadEffectiveStyle,"Xbox"); equal(q.ui.gamepadDetection.reason,"no_device")
 check(q.ui.gamepadStatus:GetText():find(q.L["No controller detected. Showing an Xbox preview."],1,true))
 s.ids={3}; s.active=3; w.fire("GAME_PAD_CONNECTED"); equal(q.ui.gamepadEffectiveStyle,"Nintendo")
 -- Explicit overrides survive hotplug, polling, closing and reopening the editor.
 q.ui.layoutButton:Click(); equal(q.engine.db.settings.gamepadStyle,"Xbox")
 local reads=s.detectReads; s.active=1; s.ids={1}; w.fire("GAME_PAD_CONNECTED"); equal(q.ui.gamepadEffectiveStyle,"Xbox")
 q.ui.gamepadBoard.scripts.OnUpdate(q.ui.gamepadBoard,.6); equal(s.detectReads,reads)
 q:Close(); q:Open(); equal(q.engine.db.settings.gamepadStyle,"Xbox"); equal(q.ui.gamepadEffectiveStyle,"Xbox")
 q.ui.layoutButton:Click(); q.ui.layoutButton:Click(); q.ui.layoutButton:Click()
 equal(q.engine.db.settings.gamepadStyle,"Auto"); equal(q.ui.gamepadEffectiveStyle,"PlayStation")
 -- Safe handling of disconnect races, unknown styles and malformed metadata.
 s.failState=true; w.fire("GAME_PAD_CONFIGS_CHANGED"); equal(q.ui.gamepadDetection.reason,"no_device"); s.failState=false
 local cases={
  {labelStyle="Letters",name="Generic name",expected="Xbox",reason="detected"},
  {labelStyle="sHaPeS",name="Generic name",expected="PlayStation",reason="detected"},
  {labelStyle="Reverse",name="Generic name",expected="Nintendo",reason="detected"},
  {labelStyle="Generic",name="DualShock 4",expected="PlayStation",reason="name"},
  {labelStyle="",name="Nintendo Switch Pro",expected="Nintendo",reason="name"},
  {labelStyle="Custom",name="PS5 Controller",expected="PlayStation",reason="name"},
  {labelStyle="Generic",name="XInput device",expected="Xbox",reason="name"},
  {labelStyle="Generic",name="Steam Deck",expected="Xbox",reason="name"},
  {labelStyle="Generic",name="Unbranded gamepad",expected="Xbox",reason="generic"},
  {labelStyle="Unrecognized",name="Unbranded gamepad",expected="Xbox",reason="unknown"},
  {labelStyle={},name={},expected="Xbox",reason="unknown"},
  {labelStyle="Letters",name="DualSense emulated as Xbox",expected="Xbox",reason="detected"},
 }
 for _,case in ipairs(cases) do
  s.devices[1]=case; w.fire("GAME_PAD_CONFIGS_CHANGED"); equal(q.ui.gamepadEffectiveStyle,case.expected); equal(q.ui.gamepadDetection.reason,case.reason)
 end
 check(q.ui.gamepadStatus:GetText():find("DualSense emulated as Xbox",1,true))
 s.devices[1]={labelStyle="Unknown",name="Unknown controller"}; w.fire("GAME_PAD_CONFIGS_CHANGED")
 check(q.ui.gamepadStatus:GetText():find(q.L["Unknown controller layout. Showing Xbox labels; a manual choice is available."],1,true))
 -- Unknown raw metadata can still identify the device when mapped metadata cannot.
 w.C_GamePad.GetDeviceRawState=function() return {name="DualSense"} end
 w.fire("GAME_PAD_CONFIGS_CHANGED"); equal(q.ui.gamepadEffectiveStyle,"PlayStation"); equal(q.ui.gamepadDetection.reason,"name")
 -- Polling reads only while the controller view is visible.
 q.ui.deviceButtons.Keyboard:Click(); reads=s.detectReads; q.ui.gamepadBoard.scripts.OnUpdate(q.ui.gamepadBoard,.6); equal(s.detectReads,reads)
 check(q.Engine.Equal(before,q.engine.draft)); check(q.Engine.Equal(initial,s.map))
end
do
 local q,w=client("enUS",16001,false,function(env)
  env.C_GamePad={ButtonBindingToIndex=function() return 0 end,GetDeviceMappedState=function(id) check(id==nil); return {name="DualSense",labelStyle="Shapes"} end}
 end)
 q:Open(); q.ui.nav["Keyboard & Mouse"]:Click(); q.ui.deviceButtons.Gamepad:Click(); equal(q.ui.gamepadEffectiveStyle,"PlayStation")
 w.C_GamePad.GetAllDeviceIDs=function() error("enumeration unavailable") end
 w.fire("GAME_PAD_CONFIGS_CHANGED"); equal(q.ui.gamepadEffectiveStyle,"PlayStation")
 w.C_GamePad.GetDeviceMappedState=nil; q:RefreshKeyboard(); equal(q.ui.gamepadEffectiveStyle,"Xbox"); equal(q.ui.gamepadDetection.reason,"unavailable")
end
do
 local q,w,s=client("frFR"); q:Open(); q.ui.nav["Keyboard & Mouse"]:Click()
 check(q.ui.detectKeyboard:IsShown()); equal(q.ui.layoutButton:GetWidth(),190)
 equal(q.ui.layoutButton.qkbText:GetWidth(),174)
 local before=q.Copy(q.engine.draft); local live=q.Copy(s.map)
 for _,case in ipairs({{"azerty","AZERTY"},{"QWERTY","QWERTY"},{"qWeRtZ","QWERTZ"}}) do
  q.ui.detectKeyboard:Click(); local input=q.dialog.keyboardInput
  check(input:IsShown()); check(input.focused); check(q.keyboardDetectionFrame~=nil)
  local previous=q.engine.db.settings.layout
  for i=1,5 do input:SetText(case[1]:sub(1,i)); equal(q.engine.db.settings.layout,previous); check(q.dialog~=nil) end
  input:SetText(case[1]); equal(q.engine.db.settings.layout,case[2]); equal(q.dialog,nil); equal(q.keyboardDetectionFrame,nil); check(not input.focused)
  check(q.ui.layoutButton:GetText():find(case[2],1,true)); check(q.Engine.Equal(q.engine.draft,before)); check(q.Engine.Equal(s.map,live)); equal(#q.engine.undo,0)
 end
 for _,sample in ipairs({"","azert","azertyx","foobar","qwertd"," azerty","qwerty ","àzerty"}) do equal(q:RecognizeKeyboardLayout(sample),nil) end
 equal(q:RecognizeKeyboardLayout(nil),nil); equal(q:RecognizeKeyboardLayout({}),nil)
 q.ui.detectKeyboard:Click(); local input=q.dialog.keyboardInput; input:SetText("foobar"); check(q.dialog~=nil); equal(q.engine.db.settings.layout,"QWERTZ")
 w.find(q.L.Retry,q.dialog):Click(); equal(input:GetText(),""); check(input.focused)
 input:SetText("az"); w.find(q.L.Cancel,q.dialog):Click(); equal(q.engine.db.settings.layout,"QWERTZ"); check(not input.focused); equal(input.scripts.OnTextChanged,nil)
 q.ui.detectKeyboard:Click(); input=q.dialog.keyboardInput; input:SetText("qwe"); input.scripts.OnEscapePressed(input); equal(q.dialog,nil); equal(q.engine.db.settings.layout,"QWERTZ")
 q.ui.detectKeyboard:Click(); input=q.dialog.keyboardInput; s.combat=true; w.fire("PLAYER_REGEN_DISABLED")
 equal(q.dialog,nil); equal(q.keyboardDetectionFrame,nil); check(not input.focused); check(not q.ui.detectKeyboard:IsEnabled()); equal(q.engine.db.settings.layout,"QWERTZ")
 q:DetectKeyboardLayout(); equal(q.dialog,nil); s.combat=false; w.fire("PLAYER_REGEN_ENABLED")
 q.ui.nav.Settings:Click(); q.ui.settingsDetect:Click(); input=q.dialog.keyboardInput; input:SetText("azerty")
 check(q.ui.settingsLayout:GetText():find("AZERTY",1,true)); equal(q.engine.db.settings.layout,"AZERTY")
 q.ui.nav["Keyboard & Mouse"]:Click(); q.ui.deviceButtons.Gamepad:Click(); check(not q.ui.detectKeyboard:IsShown()); equal(q.ui.layoutButton:GetWidth(),270)
 q.ui.deviceButtons.Keyboard:Click(); check(q.ui.detectKeyboard:IsShown()); equal(q.engine.db.settings.layout,"AZERTY")
 check(q.Engine.Equal(q.engine.draft,before)); check(q.Engine.Equal(s.map,live))
 -- A persisted display choice survives construction of a new engine/session.
 local restored=q.Engine.New(q:NativeAPI(),q.engine.db); equal(restored.db.settings.layout,"AZERTY")
end
do
 local q,w=client("deDE"); q:Open(); q.ui.nav["Keyboard & Mouse"]:Click()
 equal(q.engine.db.settings.layout,"QWERTZ","German client supplies the default display layout")
 q.ui.detectKeyboard:Click(); q.dialog.keyboardInput:SetText("azerty"); equal(q.engine.db.settings.layout,"AZERTY")
end
do
 for _,locale in ipairs({"frFR","deDE","enUS","enGB","esES","esMX","itIT","ptBR","ruRU","koKR","zhCN","zhTW","unknown"}) do
  local expected=locale=="frFR" and "AZERTY" or locale=="deDE" and "QWERTZ" or "QWERTY"
  local e=E.New({locale=function() return locale end},{})
  equal(e.db.settings.layout,expected,locale.." default"); equal(e.db.settings.layoutSource,"locale")
  for _,override in ipairs({"QWERTY","AZERTY","QWERTZ"}) do
   local existing=E.New({locale=function() error("must not consult locale for a saved override") end},{settings={layout=override}})
   equal(existing.db.settings.layout,override); equal(existing.db.settings.layoutSource,nil)
  end
 end
 local locale="frFR"; local api={locale=function() return locale end}; local db={}
 E.New(api,db); equal(db.settings.layout,"AZERTY")
 locale="deDE"; E.New(api,db); equal(db.settings.layout,"QWERTZ","locale default follows client language on next initialization")
 db.settings.layout="QWERTY"; db.settings.layoutSource="manual"; locale="frFR"; E.New(api,db); equal(db.settings.layout,"QWERTY")
 db.settings.layout="AZERTY"; db.settings.layoutSource="detected"; locale="deDE"; E.New(api,db); equal(db.settings.layout,"AZERTY")
 equal(E.New({},{}).db.settings.layout,"QWERTY","unavailable client locale falls back to QWERTY")
end
do
 local q,w,s=client("frFR"); q:Open(); q.ui.nav["Keyboard & Mouse"]:Click()
 equal(q.engine.db.settings.layout,"AZERTY"); equal(q.engine.db.settings.layoutSource,"locale")
 local draft=q.Copy(q.engine.draft); local live=q.Copy(s.map)
 q.ui.layoutButton:Click(); equal(q.engine.db.settings.layout,"QWERTZ"); equal(q.engine.db.settings.layoutSource,"manual")
 w.GetLocale=function() return "enUS" end
 local restored=q.Engine.New(q:NativeAPI(),q.engine.db); equal(restored.db.settings.layout,"QWERTZ")
 q.ui.nav.Settings:Click(); q.ui.settingsDefaultLayout:Click()
 equal(q.engine.db.settings.layout,"QWERTY"); equal(q.engine.db.settings.layoutSource,"locale")
 q.ui.settingsLayout:Click(); equal(q.engine.db.settings.layout,"AZERTY"); equal(q.engine.db.settings.layoutSource,"manual")
 q.ui.settingsDetect:Click(); q.dialog.keyboardInput:SetText("qwertz")
 equal(q.engine.db.settings.layout,"QWERTZ"); equal(q.engine.db.settings.layoutSource,"detected")
 w.GetLocale=function() return "frFR" end; restored=q.Engine.New(q:NativeAPI(),q.engine.db); equal(restored.db.settings.layout,"QWERTZ")
 q.ui.settingsDefaultLayout:Click(); equal(q.engine.db.settings.layout,"AZERTY"); equal(q.engine.db.settings.layoutSource,"locale")
 check(q.Engine.Equal(q.engine.draft,draft)); check(q.Engine.Equal(s.map,live)); equal(#q.engine.undo,0)
end
for _,locale in ipairs({"enUS","frFR","deDE"}) do
 local q,w,s=client(locale,16001,false,function(env,state)
  env.C_GamePad={ButtonBindingToIndex=function() return 0 end,IsEnabled=function() return true end}
  env.BINDING_NAME_ACTIONBUTTON1="Native localized action"; env.C_Spell.GetSpellName=function() return "Native localized spell" end
 end)
 q:Open()
 local expected=locale=="frFR" and "Options" or locale=="deDE" and "Einstellungen" or "Settings"
 equal(q.ui.nav.Settings:GetText(),expected)
 equal(q:ActionLabel("ACTIONBUTTON1"),"Native localized action - Native localized spell","native action/spell text must be preserved")
 check(q.ui.pending:GetText():find(q:F("Pending changes: %d",0),1,true))
 for _,page in ipairs({"Bindings","Keyboard & Mouse","Profiles","History","Settings"}) do q.ui.nav[page]:Click() end
 q:ChooseCategory(); q:HideDialog()
 q:PromptName("Équipe 100%",function() end); equal(q.dialog.nameInput:GetText(),"Équipe 100%"); q:HideDialog()
 check(q.engine:CreateProfile("Équipe 100%")); q.ui.nav.Profiles:Click(); q.ui.profileRows[1]:Click()
 w.find(q.L.Duplicate,q.ui.pages.Profiles):Click(); equal(q.dialog.nameInput:GetText(),q:F("%s copy","Équipe 100%")); q:HideDialog()
 equal(q.ui.profileRows[1].export:GetText(),q.L.Export)
 local exported=q.engine:Export(q.engine.draft,"Équipe 100%"); local preview=assert(q.engine:Import(exported)); equal(preview.name,"Équipe 100%")
 q:TextDialog(exported,false); w.find(q:F("%s+A / %s+C",q.L.Ctrl,q.L.Ctrl),q.dialog):Click(); q:HideDialog()
 q:TextDialog(exported,true); w.find(q.L.Preview,q.dialog):Click(); w.find(q.L["Apply to draft"],q.dialog):Click()
 q.ui.nav["Keyboard & Mouse"]:Click()
 equal(q.ui.modButtons.ctrl:GetText(),q.L.Ctrl); equal(q.ui.modButtons.shift:GetText(),q.L.Shift)
 for _,b in ipairs(q.ui.keyButtons) do if b.keySpec.modifier then b.scripts.OnEnter(b); b.scripts.OnLeave(b) end end
 q.ui.deviceButtons.Gamepad:Click()
 for _,style in ipairs(q.GamepadStyles) do
  q.engine.db.settings.gamepadStyle=style; q:RefreshKeyboard()
  for _,b in pairs(q.ui.gamepadButtons) do b.scripts.OnEnter(b); b.scripts.OnLeave(b) end
 end
 equal(q:GamepadLabel("PAD1","PlayStation"),q.L.Cross); equal(q:GamepadLabel("PADBACK","Xbox"),q.L["Controller view"])
 q:StartCapture("ACTIONBUTTON1"); equal(q.captureHint:GetText(),q.L["Press a key, mouse or controller button. Escape cancels."]); q:HideDialog()
 q:StartHover(); local overlay=q.overlays.ACTIONBUTTON1; overlay.scripts.OnEnter(overlay); q:HoverTooltip(overlay); q:StopHover(); q:Open()
 local ok,err=q.engine:Import("not an export"); check(not ok); equal(err,q.L["Invalid QuickKeybinds export header (expected QKB1)."])
 q:Result(ok,err); equal(q.ui.message,err)
 ok,err=q.engine:CreateProfile(""); check(not ok); equal(err,q.L["Use a name between 1 and 64 characters."])
 ok,err=q.engine:CreateProfile("Équipe 100%"); check(not ok); equal(err,q.L["A profile with that name already exists."])
 ok,err=q.engine:Assign("F9","UNAVAILABLE"); check(not ok); equal(err,q:F("Unavailable binding command: %s","UNAVAILABLE"))
 ok,err=q.engine:ValidateMap({["bad key"]="ACTIONBUTTON1"}); check(not ok); equal(err,q:F("Invalid key: %s","bad key"))
 check(q.engine:Assign("F8","ACTIONBUTTON1")); q.ui.save:Click(); q.ui.nav.History:Click()
 check(q.ui.historyRows[1].label:GetText():find(q.L["Changes saved"],1,true))
 q.ui.historyRows[2].restore:Click(); q:HideDialog()
 q.ui.scope.qkbText.truncated=true; q.ui.scope.scripts.OnEnter(q.ui.scope); equal(w.GameTooltip:GetText(),q.ui.scope:GetText()); q.ui.scope.scripts.OnLeave(q.ui.scope)
 for key in pairs(q.requestedLocaleKeys) do check(q.LocaleTables.enUS[key]~=nil,locale..": unregistered dynamic locale key "..tostring(key)) end
 check(next(q.missingLocaleKeys)==nil,locale..": missing locale keys")
 check(next(q.missingLocaleTranslations)==nil,locale..": untranslated UI strings")
end
do
 local q,w=client("deDE"); q:Open(); equal(q.L.Shift,"Umschalt"); equal(q.L.Ctrl,"Strg"); equal(q.L.Export,"Exportieren")
 equal(q:GamepadLabel("PAD3","PlayStation"),"Quadrat"); equal(q:F("%s copy","100% Magier"),"100% Magier (Kopie)")
 local fr=client("frFR"); equal(fr.L.Shift,"Maj"); equal(fr.L["Unbound action"],"Non assigné"); equal(fr:GamepadLabel("PAD1","PlayStation"),"Croix")
 local fallback=client("esES"); equal(fallback.L.Settings,"Settings"); equal(fallback.L["Keyboard & Gamepad"],"Keyboard & Gamepad")
end
print("QuickKeybinds: "..count.." checks passed (Lua 5.1, mocked WoW Forever APIs).")
