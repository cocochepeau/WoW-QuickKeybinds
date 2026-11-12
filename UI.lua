local _,Q=...
local L=Q.L
local function text(parent,value,x,y,width,font)
 local t
 if parent.textPool then
  parent.textUsed=(parent.textUsed or 0)+1; t=parent.textPool[parent.textUsed]
  if not t then t=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlight"); parent.textPool[parent.textUsed]=t end
  t:ClearAllPoints(); t:Show()
 else t=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlight") end
 t:SetPoint("TOPLEFT",x,y); if width then t:SetWidth(width) end
 t:SetJustifyH("LEFT"); t:SetText(value or ""); return t
end
local function button(parent,label,x,y,w,fn)
 local b
 if parent.buttonPool then
  parent.buttonUsed=(parent.buttonUsed or 0)+1; b=parent.buttonPool[parent.buttonUsed]
  if not b then b=CreateFrame("Button",nil,parent,"BackdropTemplate"); parent.buttonPool[parent.buttonUsed]=b end
  b:ClearAllPoints(); b:Show(); b:Enable()
 else b=CreateFrame("Button",nil,parent,"BackdropTemplate") end
 b:SetSize(w or 110,28); b:SetPoint("TOPLEFT",x,y); Q:SkinButton(b); b:SetText(label)
 b:SetScript("OnClick",fn); return b
end
local function box(parent,w,h)
 local f=CreateFrame("Frame",nil,parent,"BackdropTemplate"); f:SetSize(w,h)
 Q:SkinPanel(f); return f
end
local function enable(widget,on) if on then widget:Enable() else widget:Disable() end end
local function tooltip(widget,heading,body)
 widget:SetScript("OnEnter",function(self)
  GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(heading,1,.82,0)
  if body then GameTooltip:AddLine(body,1,1,1,true) end
  GameTooltip:Show()
 end)
 widget:SetScript("OnLeave",function() GameTooltip:Hide() end)
end
Q.UIText=text; Q.UIButton=button; Q.UIBox=box
local function scroll(parent,top,bottom)
 local s=CreateFrame("ScrollFrame",nil,parent,"UIPanelScrollFrameTemplate")
 s:SetPoint("TOPLEFT",0,top); s:SetPoint("BOTTOMRIGHT",-28,bottom)
 local child=CreateFrame("Frame",nil,s); child:SetSize(900,1); s:SetScrollChild(child)
 s:HookScript("OnSizeChanged",function(self,w) child:SetWidth(math.max(1,w)) end)
 s:EnableMouseWheel(true); s:SetScript("OnMouseWheel",function(self,delta)
  self:SetVerticalScroll(math.max(0,math.min(self:GetVerticalScroll()-delta*54,self:GetVerticalScrollRange())))
 end)
 return s,child
end
function Q:Confirm(message,callback)
 self:Dialog(message,function(parent)
  local h=math.max(155,math.min(480,parent.heading:GetStringHeight()+82)); parent:SetHeight(h)
  local confirm=button(parent,L.Confirm,12,-h+46,140,function() self:HideDialog(); callback() end); self:SetButtonRole(confirm,"primary")
  button(parent,L.Cancel,160,-h+46,140,function() self:HideDialog() end)
 end,460,155)
end
function Q:Dialog(message,build,w,h)
 self:HideDialog()
 local f=self.dialogFrame
 if not f then f=box(UIParent,w or 760,h or 560); f.textPool={}; f.buttonPool={}; self.dialogFrame=f end
 f:SetSize(w or 760,h or 560); f:SetScript("OnHide",nil); f:ClearAllPoints()
 f:SetPoint("CENTER",UIParent,"CENTER",0,0); f:SetFrameStrata("FULLSCREEN_DIALOG")
 f:SetClampedToScreen(true); f:EnableMouse(true); f:SetFrameLevel(200)
 f.heading=text(f,message,16,-16,(w or 760)-60,"GameFontNormal"); f.heading:SetWordWrap(true)
 self:CloseControl(f,function() self:HideDialog() end)
 f:SetScale(self.ui and self.ui.frame:GetScale() or 1)
 self.dialog=f; build(f); f:Show(); return f
end
function Q:HideDialog()
 if self.dialog then
  local f=self.dialog; f:Hide()
  for _,t in ipairs(f.textPool) do t:Hide() end
  for _,b in ipairs(f.buttonPool) do b:Hide() end
  if self.keyboardDetectionFrame then
   if f.keyboardInput then f.keyboardInput:ClearFocus(); f.keyboardInput:SetScript("OnTextChanged",nil) end
   self.keyboardDetectionFrame=nil
  end
  for _,key in ipairs({"nameInput","textScroll","previewScroll","categoryScroll","keyboardInput"}) do if f[key] then f[key]:Hide() end end
  f.textUsed=0; f.buttonUsed=0; self.dialog=nil
 end
end
function Q:PromptName(default,callback)
 self:Dialog(L.Name,function(f)
  local input=f.nameInput
  if not input then input=CreateFrame("EditBox",nil,f,"InputBoxTemplate"); f.nameInput=input; input:SetSize(360,28); input:SetPoint("TOPLEFT",22,-48) end
  input:Show()
  input:SetMaxLetters(64); input:SetAutoFocus(true); input:SetText(default or ""); input:HighlightText()
  local function accept() local name=input:GetText():match("^%s*(.-)%s*$"); self:HideDialog(); callback(name) end
  input:SetScript("OnEnterPressed",accept); input:SetScript("OnEscapePressed",function() self:HideDialog() end)
  button(f,L.Confirm,16,-96,150,accept); button(f,L.Cancel,178,-96,150,function() self:HideDialog() end)
 end,430,150)
end
function Q:TextDialog(value,importing)
 self:Dialog(L[importing and "Paste a QuickKeybinds export below." or "Copy this text. Imports are validated before they change your draft."],function(f)
  local s,edit=f.textScroll,f.textEdit
  if not s then
   s=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate"); s:SetPoint("TOPLEFT",18,-62); s:SetPoint("BOTTOMRIGHT",-38,60)
   edit=CreateFrame("EditBox",nil,s); edit:SetMultiLine(true); edit:SetFontObject(ChatFontNormal); edit:SetWidth(680); edit:SetAutoFocus(false)
   edit:SetMaxLetters(262145); s:SetScrollChild(edit); f.textScroll=s; f.textEdit=edit
  end
  s:Show(); edit:SetText(value or ""); s:SetVerticalScroll(0)
  edit:SetScript("OnEscapePressed",function() self:HideDialog() end)
  edit:SetScript("OnTextChanged",function(widget) s:UpdateScrollChildRect() end)
  edit:SetScript("OnCursorChanged",function(_,_,y,_,height)
   local pos=-y; local current=s:GetVerticalScroll()
   if pos<current then s:SetVerticalScroll(pos) elseif pos+height>current+s:GetHeight() then s:SetVerticalScroll(pos+height-s:GetHeight()) end
  end)
  if importing then
   button(f,L.Preview,18,-505,170,function()
    local preview,err=self.engine:Import(edit:GetText())
    if not preview then self:Print(err); return end
    self:Preview(preview,preview.name)
   end)
  else button(f,self:F("%s+A / %s+C",L.Ctrl,L.Ctrl),18,-505,180,function() edit:SetFocus(); edit:HighlightText() end) end
  button(f,L.Close,540,-505,170,function() self:HideDialog() end)
  edit:SetFocus(); if not importing then edit:HighlightText() end
 end)
end
function Q:Preview(preview,name,onApply)
 local title=(name or L.Draft).." - "..self:F("Pending changes: %d",#preview.changes).." ("..L[self.engine.scope==2 and "Character" or "Account"]..")"
 self:Dialog(title,function(f)
  local s,child=f.previewScroll,f.previewChild
  if not s then s,child=scroll(f,-62,68); f.previewScroll=s; f.previewChild=child; child.textPool={} end
  for _,t in ipairs(child.textPool) do t:Hide() end
  child.textUsed=0; s:Show()
  local y=0
  for _,cmd in ipairs(preview.missing) do text(child,"|cffff7777"..L.Unavailable..": "..cmd.."|r",12,y,660); y=y-30 end
  for _,d in ipairs(preview.changes) do
   local line=self:KeyText(d.key)..": "..self:ActionLabel(d.old).." -> "..self:ActionLabel(d.new)
   local t=text(child,line,12,y,660); t:SetWordWrap(true); y=y-math.max(36,t:GetStringHeight()+10)
  end
  if y==0 then text(child,L["No changes"],12,0,650) end
  child:SetHeight(math.max(1,-y)); s:SetVerticalScroll(0)
  local apply=button(f,L["Apply to draft"],18,-505,190,function()
   local ok,err
   if onApply then ok,err=onApply() else ok,err=self.engine:ApplyPreview(preview,name) end
   if self:Result(ok,err) then self:HideDialog() end
  end)
  enable(apply,#preview.missing==0 and not InCombatLockdown())
  button(f,L.Cancel,540,-505,170,function() self:HideDialog() end)
 end)
end
function Q:PreviewRebase()
 local e=self.engine; local map,err=e:ReadScope(e.scope)
 if not map then self:Result(nil,err); return end
 local desired=self.Copy(map)
 for _,d in ipairs(e:Pending()) do desired[d.key]=d.new end
 self:Preview({map=desired,changes=e.Diff(map,desired),missing={}},L["Rebase draft"],function() return e:Rebase(map) end)
end
function Q:CreateUI()
 if self.ui then return end
 local f=self:CreateWindow(UIParent,1060,740); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true)
 f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
 f:SetScript("OnDragStart",function(self) self:StartMoving() end); f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
 f:EnableKeyboard(true)
 if f.SetPropagateKeyboardInput then f:SetPropagateKeyboardInput(true) end
 f:SetScript("OnKeyDown",function(frame,key)
  local focused=GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
  local close=key=="ESCAPE" and not focused and not self.dialog
  if frame.SetPropagateKeyboardInput then frame:SetPropagateKeyboardInput(not close) end
  if close then self:Close() end
 end)
 local ui={frame=f,page="Bindings",filter="All",query="",rows={},keyButtons={}}; self.ui=ui
 ui.badge=button(UIParent,"QuickKeybinds",0,0,290,function() self:Open() end)
 ui.badge:ClearAllPoints(); ui.badge:SetPoint("TOP",UIParent,"TOP",0,-12); ui.badge:SetFrameStrata("DIALOG"); ui.badge:Hide()
 local icon=f:CreateTexture(nil,"ARTWORK"); icon:SetSize(28,28); icon:SetPoint("TOPLEFT",24,-35); icon:SetTexture("Interface\\Icons\\INV_Misc_Key_03")
 text(f,L["Keybinding manager"],64,-38,265,"GameFontNormalLarge")
 ui.scope=button(f,"",350,-35,172,function()
  local scope=self.engine.scope==1 and 2 or 1
  if self.engine:Dirty() then self:Print(L["Save your changes or discard them before switching scope."]); return end
  self:StopCapture(); self:HideDialog(); self:Result(self.engine:Begin(scope))
 end)
 ui.profile=text(f,"",542,-44,460)
 ui.profile:SetHeight(18); ui.profile:SetWordWrap(false)
 self:CloseControl(f,function() self:Close() end)
 ui.editorPanel=self:Surface(f); ui.editorPanel:SetPoint("TOPLEFT",14,-158); ui.editorPanel:SetPoint("BOTTOMRIGHT",-14,86)
 ui.footerPanel=self:Surface(f); ui.footerPanel:SetPoint("TOPLEFT",14,-658); ui.footerPanel:SetPoint("BOTTOMRIGHT",-14,8)
 ui.statusPanel=self:Surface(f); ui.statusPanel:SetPoint("TOPLEFT",20,-110); ui.statusPanel:SetPoint("TOPRIGHT",-20,-110); ui.statusPanel:SetHeight(42)
 local pages={"Bindings","Keyboard & Mouse","Profiles","History","Settings"}
 ui.nav={}; ui.pages={}
 for i,page in ipairs(pages) do
  ui.nav[page]=button(f,L[page=="Keyboard & Mouse" and "Keyboard & Gamepad" or page],20+(i-1)*204,-74,196,function() self:StopCapture(); ui.hoverKey=nil; ui.page=page; self:Refresh() end); self:SetButtonRole(ui.nav[page],"tab")
  local p=CreateFrame("Frame",nil,f); p:SetPoint("TOPLEFT",24,-164); p:SetPoint("BOTTOMRIGHT",-24,88); ui.pages[page]=p
 end
 ui.status=text(f,"",32,-118,980); ui.status:SetHeight(30); ui.status:SetWordWrap(true)
 ui.externalReload=button(f,L["Reload bindings"],600,-117,190,function()
  self:Confirm(L["Discard this draft?"],function() self:Result(self.engine:Reload()) end)
 end)
 ui.externalRebase=button(f,L["Rebase draft"],800,-117,215,function()
  self:PreviewRebase()
 end)
 ui.pending=text(f,"",20,-664,980)
 ui.undo=button(f,L.Undo,20,-698,110,function() self:Result(self.engine:Undo()) end)
 ui.redo=button(f,L.Redo,138,-698,110,function() self:Result(self.engine:Redo()) end)
 ui.discard=button(f,L.Discard,420,-698,225,function() self:Confirm(L["Discard this draft?"],function() self:Result(self.engine:Discard()) end) end)
 ui.save=button(f,L.Save,656,-698,180,function() if self:Result(self.engine:Save()) then ui.message=L.Saved; self:Refresh() end end)
 self:SetButtonRole(ui.save,"primary")
 button(f,L.Close,848,-698,190,function() self:Close() end)
 f:SetScript("OnHide",function() self:StopCapture(); self:StopHover(); self:HideDialog(); self:RefreshBadge() end)
 self:BuildBindingsPage(); self:BuildKeyboardPage(); self:BuildProfilesPage(); self:BuildHistoryPage(); self:BuildSettingsPage()
 f:Hide()
end
function Q:RefreshBadge()
 if not self.ui or not self.engine.draft then return end
 self.ui.badge:SetText("QuickKeybinds • "..self:F("Pending changes: %d",#self.engine:Pending()))
 self.ui.badge:SetShown(self.engine:Dirty() and not self.ui.frame:IsShown() and not self.hovering)
end
function Q:Refresh()
 if not self.ui or not self.engine.draft then return end
 local ui,e=self.ui,self.engine; local combat=InCombatLockdown(); local editable=not combat and not e.external
 local scale=math.min(e.db.settings.scale or 1,(UIParent:GetWidth()-30)/1060,(UIParent:GetHeight()-30)/740)
 ui.frame:SetScale(math.max(.4,scale))
 ui.scope:SetText(L.Scope..": "..L[e.scope==2 and "Character" or "Account"])
 ui.profile:SetText(L.Profile..": "..(e.activeProfile or L.Draft))
 ui.pending:SetText(self:F("Pending changes: %d",#e:Pending()).."  •  "..L["Your draft stays available until reload/logout."])
 if combat then ui.status:SetText("|cffff7777"..L["Editing paused in combat. Your draft is preserved."].."|r")
 elseif e.external then ui.status:SetText(L["Bindings changed outside QuickKeybinds. Reload them or rebase your draft before saving."])
 else ui.status:SetText(ui.message or L.Ready) end
 ui.status:SetWidth(e.external and 570 or 1000)
 ui.externalReload:SetShown(e.external); ui.externalRebase:SetShown(e.external)
 enable(ui.externalReload,not combat); enable(ui.externalRebase,not combat)
 enable(ui.scope,not combat); enable(ui.undo,editable and #e.undo>0); enable(ui.redo,editable and #e.redo>0)
 enable(ui.save,editable and (e:Dirty() or e.scope~=GetCurrentBindingSet())); enable(ui.discard,not combat and (e:Dirty() or e.external))
 for page,p in pairs(ui.pages) do p:SetShown(page==ui.page); self:SelectButton(ui.nav[page],page==ui.page) end
 if ui.page=="Bindings" then self:RefreshBindings()
 elseif ui.page=="Keyboard & Mouse" then self:RefreshKeyboard()
 elseif ui.page=="Profiles" then self:RefreshProfiles()
 elseif ui.page=="History" then self:RefreshHistory()
 elseif ui.page=="Settings" then self:RefreshSettings() end
 if self.hoverDock then self:RefreshHover() end
 self:RefreshBadge()
end
function Q:BuildBindingsPage()
 local ui=self.ui; local p=ui.pages.Bindings
 local search=CreateFrame("EditBox",nil,p,"InputBoxTemplate"); search:SetSize(420,27); search:SetPoint("TOPLEFT",8,0); search:SetAutoFocus(false)
 search:SetMaxLetters(120); search:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
 search:SetScript("OnTextChanged",function(self) ui.query=self:GetText():lower(); Q:RefreshBindings() end)
 tooltip(search,L["Search action, spell, item or key"])
 text(p,L["Search action, spell, item or key"],8,-30,600,"GameFontDisableSmall")
 ui.category=button(p,L.All,456,0,307,function() self:ChooseCategory() end)
 ui.hover=button(p,L["Hover bind"],780,0,225,function() self:StartHover() end)
 self:SetButtonRole(ui.hover,"primary")
 local filters={"All","Bars","Bound","Unbound","Pending","Unavailable"}; ui.filters={}
 for i,filter in ipairs(filters) do ui.filters[filter]=button(p,L[filter],(i-1)*167,-55,159,function() ui.filter=filter; self:RefreshBindings() end); self:SetButtonRole(ui.filters[filter],"filter") end
 ui.bindingScroll,ui.bindingChild=scroll(p,-91,130)
 ui.selection=text(p,"",4,-382,750,"GameFontNormal"); ui.selection:SetHeight(36)
 ui.add=button(p,L["Add key"],4,-424,160,function() if ui.selected then self:StartCapture(ui.selected) end end)
 ui.clear=button(p,L["Clear all"],174,-424,160,function()
  if ui.selected then local cmd=ui.selected; self:Confirm(L["Clear all"].."?\n"..self:ActionLabel(cmd),function() self:Result(self.engine:Clear(cmd)) end) end
 end)
 ui.bindKeys={}
end
function Q:ChooseCategory()
 local categories={}
 for _,item in ipairs(self.catalogList) do categories[item.bar or item.category or L.Other]=true end
 local list=self.SortedKeys(categories); table.insert(list,1,L.All)
 self:Dialog(L.Category,function(f)
  local s,child=f.categoryScroll,f.categoryChild
  if not s then s,child=scroll(f,-60,30); f.categoryScroll=s; f.categoryChild=child; child.buttonPool={} end
  for _,b in ipairs(child.buttonPool) do b:Hide() end; child.buttonUsed=0; s:Show()
  for i,category in ipairs(list) do
   local index=i
   button(child,category,8,-(i-1)*32,650,function()
    self.ui.categoryFilter=index~=1 and category or nil
    self:HideDialog(); self.ui.bindingScroll:SetVerticalScroll(0); self:RefreshBindings()
   end)
  end
  child:SetHeight(#list*32); s:SetVerticalScroll(0)
 end)
end
function Q:RefreshBindings()
 local ui,e=self.ui,self.engine; if not ui or not e.draft then return end
 local query=ui.query or ""; local filter=ui.filter
 ui.category:SetText(ui.categoryFilter or L.All)
 local changes={}; for _,d in ipairs(e:Pending()) do if d.old then changes[d.old]=true end if d.new then changes[d.new]=true end end
 for name,b in pairs(ui.filters) do self:SelectButton(b,name==filter) end
 local shown={}; local items={}
 for _,item in ipairs(self.catalogList) do items[#items+1]=item end
 for _,cmd in pairs(e.draft) do if not self.catalog[cmd] and not shown[cmd] then items[#items+1]={command=cmd,name=cmd,category=L.Unavailable,unavailable=true}; shown[cmd]=true end end
 local n=0; local editable=not InCombatLockdown() and not e.external
 for _,item in ipairs(items) do
  local cmd=item.command; local bound=e.KeysFor(e.draft,cmd); local label=self:ActionLabel(cmd)
  local match=filter=="All" or filter=="Bars" and item.bar or filter=="Bound" and #bound>0 or filter=="Unbound" and #bound==0 or filter=="Pending" and changes[cmd] or filter=="Unavailable" and item.unavailable
  if ui.categoryFilter and (item.bar or item.category or L.Other)~=ui.categoryFilter then match=false end
  local search=(label.." "..cmd.." "..(item.bar or item.category or "").." "..table.concat(bound," ")):lower()
  if query~="" and not search:find(query,1,true) then
   local localized={} for _,key in ipairs(bound) do localized[#localized+1]=self:KeyText(key) end
   if not table.concat(localized," "):lower():find(query,1,true) then match=false end
  end
  if match then
   n=n+1; local row=ui.rows[n]
   if not row then
    row=CreateFrame("Button",nil,ui.bindingChild,"BackdropTemplate"); row:SetSize(972,44); row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.label=text(row,"",8,-3,620); row.label:SetHeight(18); row.label:SetWordWrap(false)
    row.category=text(row,"",8,-24,560,"GameFontDisableSmall")
    row.keys=text(row,"",640,-9,312); row.keys:SetJustifyH("RIGHT"); row.keys:SetHeight(24); row.keys:SetWordWrap(false)
    row:SetScript("OnClick",function(self) ui.selected=self.command; Q:Refresh() end)
    row:SetScript("OnEnter",function(self)
     GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(self.fullLabel); GameTooltip:AddLine(self.command,.6,.7,.8)
     local labels={} for _,key in ipairs(e.KeysFor(e.draft,self.command)) do labels[#labels+1]=Q:KeyText(key) end
     GameTooltip:AddLine(#labels>0 and table.concat(labels,", ") or L["Unbound action"],1,1,1,true); GameTooltip:Show()
    end)
    row:SetScript("OnLeave",function() GameTooltip:Hide() end)
    ui.rows[n]=row
   end
   row:SetPoint("TOPLEFT",0,-(n-1)*46); row.command=cmd; row.fullLabel=label
   row.label:SetText((ui.selected==cmd and "|cffffd178" or changes[cmd] and "|cffffcc55" or "|cffffffff")..label.."|r")
   self:PaintRow(row,ui.selected==cmd,n%2==0)
   row.category:SetText((item.bar or item.category or L.Other)..(item.unavailable and " • "..L.Unavailable or ""))
   local labels={} for _,key in ipairs(bound) do labels[#labels+1]=self:KeyText(key) end
   row.keys:SetText(#bound>0 and table.concat(labels,", ") or "|cff888888"..L["Unbound action"].."|r"); row:Show()
  end
 end
 for i=n+1,#ui.rows do ui.rows[i]:Hide() end
 ui.bindingChild:SetHeight(math.max(1,n*46))
 ui.bindingScroll:SetVerticalScroll(math.min(ui.bindingScroll:GetVerticalScroll(),math.max(0,n*46-ui.bindingScroll:GetHeight())))
 ui.selection:SetText(ui.selected and self:ActionLabel(ui.selected) or L["No action selected"])
 enable(ui.add,editable and ui.selected and self.catalog[ui.selected]); enable(ui.clear,editable and ui.selected and #e.KeysFor(e.draft,ui.selected)>0)
 -- Every assigned key has its own replace/remove controls in a horizontal scrolling strip.
 if not ui.keyScroll then
  ui.keyScroll=CreateFrame("ScrollFrame",nil,ui.pages.Bindings,"UIPanelScrollFrameTemplate"); ui.keyScroll:SetPoint("TOPLEFT",350,-418); ui.keyScroll:SetSize(630,60)
  ui.keyChild=CreateFrame("Frame",nil,ui.keyScroll); ui.keyChild:SetSize(600,1); ui.keyScroll:SetScrollChild(ui.keyChild)
 end
 for _,r in ipairs(ui.bindKeys) do r.frame:Hide() end
 local bound=ui.selected and e.KeysFor(e.draft,ui.selected) or {}
 for i,key in ipairs(bound) do
  local r=ui.bindKeys[i]
  if not r then
   local f=CreateFrame("Frame",nil,ui.keyChild); f:SetSize(580,30); r={frame=f}; ui.bindKeys[i]=r
   r.label=text(f,"",0,-4,220)
   r.replace=button(f,L.Replace,240,0,155,function() Q:StartCapture(ui.selected,r.key) end)
   r.remove=button(f,L.Remove,407,0,155,function() Q:Result(e:Remove(r.key)) end)
  end
  r.key=key; r.frame:SetPoint("TOPLEFT",0,-(i-1)*32); r.label:SetText(self:KeyText(key)); r.frame:Show(); enable(r.replace,editable); enable(r.remove,editable)
 end
 ui.keyChild:SetHeight(math.max(1,#bound*32))
end

function Q:LayerKey(key)
 local m=self.ui.modifiers; local prefix=""
 if m.alt then prefix=prefix.."ALT-" end
 if m.ctrl then prefix=prefix.."CTRL-" end
 if m.shift then prefix=prefix.."SHIFT-" end
 return prefix..key
end
function Q:BuildKeyboardPage()
 local ui=self.ui; local p=ui.pages["Keyboard & Mouse"]; ui.modifiers={}
 ui.deviceHelp=text(p,L["Select an action on the Bindings page first. Click a key to assign it to the selected action."],4,0,1000)
 ui.keyboardSelection=text(p,"",4,-32,1000,"GameFontNormal")
 ui.keyboardSelection:SetHeight(22); ui.keyboardSelection:SetWordWrap(false)
 ui.modButtons={}
 for i,mod in ipairs({"shift","ctrl","alt"}) do
  ui.modButtons[mod]=button(p,self:ModifierLabel(mod),4+(i-1)*145,-62,136,function() ui.modifiers[mod]=not ui.modifiers[mod]; self:RefreshKeyboard() end)
  self:SetButtonRole(ui.modButtons[mod],"toggle")
 end
 ui.deviceButtons={}
 for i,mode in ipairs({"Keyboard","Gamepad"}) do
  ui.deviceButtons[mode]=button(p,L[mode],460+(i-1)*128,-62,116,function()
   self.engine.db.settings.deviceView=mode; ui.hoverKey=nil; GameTooltip:Hide(); self:RefreshKeyboard()
  end); self:SetButtonRole(ui.deviceButtons[mode],"toggle")
 end
 ui.layoutButton=button(p,"",730,-62,270,function()
  local s=self.engine.db.settings
  if s.deviceView=="Gamepad" then
   local cycle={Auto="Xbox",Xbox="PlayStation",PlayStation="Nintendo",Nintendo="Auto"}; s.gamepadStyle=cycle[s.gamepadStyle or "Auto"] or "Auto"
  else
   local layouts={QWERTY="AZERTY",AZERTY="QWERTZ",QWERTZ="QWERTY"}; s.layout=layouts[s.layout] or "QWERTY"; s.layoutSource="manual"
  end
  ui.hoverKey=nil; GameTooltip:Hide(); self:RefreshKeyboard()
 end)
 ui.detectKeyboard=button(p,L.Detect,928,-62,76,function() self:DetectKeyboardLayout() end)
 ui.keyboardBoard=CreateFrame("Frame",nil,p); ui.keyboardBoard:SetAllPoints(p)
 for _,spec in ipairs(self.KeyboardKeys) do
   local b=button(ui.keyboardBoard,"",spec.x,-spec.y,spec.width,function() end); b:SetHeight(spec.height)
   self:SetButtonRole(b,"key")
   b.keyLabel=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); b.keyLabel:SetHeight(14); b.keyLabel:SetWordWrap(false)
   b.assignedLabel=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); b.assignedLabel:SetPoint("BOTTOMLEFT",4,4); b.assignedLabel:SetSize(spec.width-8,12); b.assignedLabel:SetWordWrap(false)
   b.actionIcon=b:CreateTexture(nil,"ARTWORK"); b.actionIcon:SetSize(12,12); b.actionIcon:SetPoint("TOPRIGHT",-4,-4); b.actionIcon:SetTexCoord(.08,.92,.08,.92); b.actionIcon:Hide()
   b.baseKey=spec.key; b.keySpec=spec; b:RegisterForClicks("LeftButtonUp","RightButtonUp")
   b:SetScript("OnClick",function(self,mouse)
    if self.keySpec.system then return end
    if self.keySpec.modifier then
     if mouse=="LeftButton" then ui.modifiers[self.keySpec.modifier]=not ui.modifiers[self.keySpec.modifier]; Q:RefreshKeyboard() end
     return
    end
    local full=Q:LayerKey(self.key)
    if mouse=="RightButton" then
     if Q.engine.draft[full] then Q:Confirm(L.Remove.." "..Q:KeyText(full).."?",function() Q:Result(Q.engine:Remove(full)) end) end
    elseif ui.selected then Q:RequestAssign(full,ui.selected)
    elseif Q.engine.draft[full] then ui.selected=Q.engine.draft[full]; Q:RefreshKeyboard()
    else Q:Print(L["No action selected"]) end
   end)
   b:SetScript("OnEnter",function(self)
    ui.hoverKey=self; Q:KeyboardTooltip(self)
   end)
   b:SetScript("OnLeave",function() ui.hoverKey=nil; GameTooltip:Hide(); Q:KeyboardSelection() end)
   ui.keyButtons[#ui.keyButtons+1]=b
 end
 text(ui.keyboardBoard,L.Mouse,4,-402,78,"GameFontDisableSmall")
 text(ui.keyboardBoard,L.Numpad,828,-118,172,"GameFontDisableSmall")
 for _,entry in ipairs({{L.Bound,4,self.Theme.bound},{L.Pending,120,self.Theme.pending},{L.Unbound,268,self.Theme.muted}}) do
  local swatch=p:CreateTexture(nil,"ARTWORK"); swatch:SetSize(9,9); swatch:SetPoint("TOPLEFT",entry[2],-441); swatch:SetColorTexture(entry[3][1],entry[3][2],entry[3][3],1)
  text(p,entry[1],entry[2]+16,-438,140,"GameFontHighlightSmall")
 end
 text(ui.keyboardBoard,L["Unmodified left and right mouse buttons are reserved."],438,-438,565,"GameFontDisableSmall")
 text(ui.keyboardBoard,L["Left click: assign   •   Right click: remove   •   Hover: full action name"],4,-466,1000,"GameFontDisableSmall")
 self:BuildGamepadView(p)
end
function Q:InputButtonText(b)
 if b.keySpec.gamepad then
  local mods={} for _,mod in ipairs({"alt","ctrl","shift"}) do if self.ui.modifiers[mod] then mods[#mods+1]=mod end end
  local prefix=#mods>0 and self:ModifierList(mods).." + " or ""
  return prefix..self:GamepadLabel(b.key,self.ui.gamepadEffectiveStyle or "Xbox")
 end
 return self:KeyText(self:LayerKey(b.key))
end
function Q:KeyboardSelection()
 local ui=self.ui; local hovered=ui.hoverKey
 if hovered then
  if hovered.keySpec.modifier then ui.keyboardSelection:SetText(L["Click to toggle this modifier layer."]); return end
  local full=self:LayerKey(hovered.key)
  ui.keyboardSelection:SetText(self:InputButtonText(hovered)..": "..self:ActionLabel(self.engine.draft[full]))
 else ui.keyboardSelection:SetText(ui.selected and self:ActionLabel(ui.selected) or L["No action selected"]) end
end
function Q:KeyboardTooltip(keyButton)
 if keyButton.keySpec.modifier then
  GameTooltip:SetOwner(keyButton,"ANCHOR_RIGHT"); GameTooltip:SetText(L[keyButton.keySpec.caption])
  GameTooltip:AddLine(L["Click to toggle this modifier layer."],1,1,1,true); GameTooltip:Show(); self:KeyboardSelection(); return
 end
 local full=self:LayerKey(keyButton.key); GameTooltip:SetOwner(keyButton,"ANCHOR_RIGHT"); GameTooltip:SetText(self:InputButtonText(keyButton))
 GameTooltip:AddLine(self:ActionLabel(self.engine.draft[full]),1,1,1,true)
 if keyButton.keySpec.gamepad then
  local modifiers=self:GamepadModifierKeys(keyButton.key)
  if #modifiers>0 then GameTooltip:AddLine(L["WoW modifier buttons"]..": "..self:ModifierList(modifiers),1,.82,0,true) end
 end
 if keyButton.keySpec.alias then GameTooltip:AddLine(L["Shares the main Enter binding."],.7,.7,.7,true) end
 GameTooltip:AddLine(L["Clear selected layer key"]..": "..L["Right click"],.6,.7,.8,true); GameTooltip:Show()
 self:KeyboardSelection()
end
function Q:RefreshKeyboard()
 local ui,e=self.ui,self.engine
 local layout=e.db.settings.layout
 local view=e.db.settings.deviceView=="Gamepad" and "Gamepad" or "Keyboard"
 for mode,b in pairs(ui.deviceButtons) do self:SelectButton(b,mode==view) end
 ui.keyboardBoard:SetShown(view=="Keyboard"); ui.gamepadBoard:SetShown(view=="Gamepad")
 ui.deviceHelp:SetText(L[view=="Gamepad" and "Select an action in Bindings, then click a controller button to assign it." or "Select an action on the Bindings page first. Click a key to assign it to the selected action."])
 local style,info,mode
 if view=="Gamepad" then style,info,mode=self:ResolveGamepadStyle() end
 local layoutWidth=view=="Gamepad" and 270 or 190
 ui.layoutButton:SetWidth(layoutWidth); ui.layoutButton.qkbText:SetWidth(layoutWidth-16)
 ui.detectKeyboard:SetShown(view=="Keyboard"); enable(ui.detectKeyboard,not InCombatLockdown())
 ui.layoutButton:SetText(view=="Gamepad" and L["Controller labels"]..": "..(mode=="Auto" and L.Auto.." ("..style..")" or style) or L.Layout..": "..layout)
 for mod,b in pairs(ui.modButtons) do b:SetText(self:ModifierLabel(mod)); self:SelectButton(b,ui.modifiers[mod]) end
 if view=="Gamepad" then self:RefreshGamepad(style,info); return end
 local az={Q="A",W="Z",A="Q",Z="W",M=";",[";"]="M"}; local qz={Y="Z",Z="Y"}
 local short={ESCAPE="Esc",BACKSPACE=L.Backspace,ENTER=L.Enter,SPACE=L.Space,TAB=L.Tab,INSERT=L["Insert short"],DELETE=L["Delete short"],CAPSLOCK=L["Caps Lock short"],PRINTSCREEN=L["Print Screen short"],SCROLLLOCK=L["Scroll Lock short"],PAUSE=L.Pause,PAGEUP=L["Page Up short"],PAGEDOWN=L["Page Down short"],MOUSEWHEELUP=L["Wheel up short"],MOUSEWHEELDOWN=L["Wheel down short"],NUMPADDIVIDE="/",NUMPADMULTIPLY="*",NUMPADMINUS="-",NUMPADPLUS="+",NUMPADDECIMAL=".",NUMLOCK=L["Num Lock short"],UP="^",DOWN="v",LEFT="<",RIGHT=">",HOME=L.Home,END=L.End}
 for _,b in ipairs(ui.keyButtons) do
  local spec=b.keySpec
  b.key=layout=="AZERTY" and (az[b.baseKey] or b.baseKey) or layout=="QWERTZ" and (qz[b.baseKey] or b.baseKey) or b.baseKey
  local full=self:LayerKey(b.key); local cmd=e.draft[full]
  local changed=e.baseline[full]~=cmd; local color=changed and "|cffffcc55" or cmd and "|cff55c9ff" or "|cffaaaaaa"
  b.qkbKeyState=changed and "pending" or cmd and "bound" or "unbound"
  local label=spec.caption and L[spec.caption] or short[b.key] or b.key:match("^NUMPAD(%d+)$") or b.key:match("^BUTTON(%d+)$") and "B"..b.key:match("^BUTTON(%d+)$") or self:KeyText(b.key)
  local name,icon=self:ActionDetails(cmd)
  local assigned=name or cmd and (self.catalog[cmd] and self.catalog[cmd].name or cmd)
  if spec.modifier or spec.system then assigned=nil; icon=nil; b.qkbKeyState="unbound" end
  if spec.modifier then color=ui.modifiers[spec.modifier] and "|cffffcc55" or "|cffdddddd" end
  b:SetText(""); b.keyLabel:ClearAllPoints()
  b.keyLabel:SetWidth(b:GetWidth()-(icon and 22 or 8))
  b.keyLabel:SetPoint(assigned and "TOPLEFT" or "LEFT",4,assigned and -3 or 0)
  b.keyLabel:SetText(color..label.."|r")
  b.assignedLabel:SetText(assigned or ""); b.assignedLabel:SetShown(assigned~=nil)
  b.actionIcon:SetTexture(icon); b.actionIcon:SetShown(icon~=nil)
  enable(b,not spec.system and not InCombatLockdown() and not e.external and full~="BUTTON1" and full~="BUTTON2")
  self:SelectButton(b,spec.modifier and ui.modifiers[spec.modifier])
  self:PaintButton(b)
 end
 self:KeyboardSelection()
 if ui.hoverKey then self:KeyboardTooltip(ui.hoverKey) end
end
function Q:BuildProfilesPage()
 local ui=self.ui; local p=ui.pages.Profiles
 text(p,L["A profile stores bindings, not spells or bar layouts."],4,0,1000)
 button(p,L["New profile"],4,-32,154,function() self:PromptName("",function(name) self:Result(self.engine:CreateProfile(name)); ui.selectedProfile=name; self:RefreshProfiles() end) end)
 button(p,L.Duplicate,167,-32,154,function()
  local name=ui.selectedProfile; local profile=name and self.engine.db.profiles[name]
  if not profile then self:Print(L["No profile selected"]); return end
  self:PromptName(self:F("%s copy",name),function(new) self:Result(self.engine:CreateProfile(new,profile.map)); ui.selectedProfile=new; self:RefreshProfiles() end)
 end)
 button(p,L.Rename,330,-32,154,function()
  local name=ui.selectedProfile; if not name then return end
  self:PromptName(name,function(new) if self:Result(self.engine:RenameProfile(name,new)) then ui.selectedProfile=new; self:RefreshProfiles() end end)
 end)
 button(p,L.Delete,493,-32,154,function()
  local name=ui.selectedProfile; if not name then return end
  self:Confirm(L.Delete.." "..name.."?",function() self.engine.db.profiles[name]=nil; if self.engine.activeProfile==name then self.engine.activeProfile=nil end; ui.selectedProfile=nil; self:Refresh() end)
 end)
 button(p,L["Export draft"],656,-32,172,function() self:TextDialog(self.engine:Export(self.engine.draft,self.engine.activeProfile),false) end)
 button(p,L.Import,837,-32,165,function() self:TextDialog("",true) end)
 ui.profileScroll,ui.profileChild=scroll(p,-80,44); ui.profileRows={}
end
function Q:RefreshProfiles()
 local ui=self.ui; local n=0
 for _,name in ipairs(self.SortedKeys(self.engine.db.profiles)) do
  local profile=self.engine.db.profiles[name]; n=n+1; local row=ui.profileRows[n]
  if not row then
   row=CreateFrame("Button",nil,ui.profileChild,"BackdropTemplate"); row:SetSize(970,62); row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
   row.label=text(row,"",6,-4,560,"GameFontNormal"); row.meta=text(row,"",6,-29,560,"GameFontDisableSmall")
   row.preview=button(row,L.Preview,592,-10,170,function()
    local preview,err=self.engine:PreviewMap(self.engine.db.profiles[row.name].map)
    if preview then self:Preview(preview,row.name) else self:Print(err) end
   end)
   row.export=button(row,L.Export,778,-10,170,function() self:TextDialog(self.engine:Export(self.engine.db.profiles[row.name].map,row.name),false) end)
   row:SetScript("OnClick",function(self) ui.selectedProfile=self.name; Q:RefreshProfiles() end); ui.profileRows[n]=row
  end
  row.name=name; row.label:SetText((ui.selectedProfile==name and "|cffffd178" or "")..name)
  self:PaintRow(row,ui.selectedProfile==name,n%2==0)
  local count=0 for _ in pairs(profile.map) do count=count+1 end
  row.meta:SetText(self:F("Bindings: %d",count).." • "..(profile.character or "").." • "..L[profile.scope==2 and "Character" or "Account"])
  row:SetPoint("TOPLEFT",0,-(n-1)*66); row:Show()
 end
 for i=n+1,#ui.profileRows do ui.profileRows[i]:Hide() end
 ui.profileChild:SetHeight(math.max(1,n*66))
end
function Q:BuildHistoryPage()
 local ui=self.ui; local p=ui.pages.History
 text(p,L["Backup before save"].." • "..L["Restore"].." -> "..L.Preview.." -> "..L["Apply to draft"],4,0,1000)
 ui.historyScroll,ui.historyChild=scroll(p,-42,10); ui.historyRows={}
end
function Q:RefreshHistory()
 local ui=self.ui
 for n,entry in ipairs(self.engine.db.history) do
  local row=ui.historyRows[n]
  if not row then
   row=CreateFrame("Frame",nil,ui.historyChild,"BackdropTemplate"); row:SetSize(970,76)
   row.label=text(row,"",4,-4,710,"GameFontNormal"); row.label:SetHeight(36)
   row.meta=text(row,"",4,-43,710,"GameFontDisableSmall")
   row.restore=button(row,L.Restore,760,-15,190,function()
    local preview,err=self.engine:PreviewMap(row.entry.map)
    if preview then self:Preview(preview,L[row.entry.note].." -> "..L[self.engine.scope==2 and "Character" or "Account"]) else self:Print(err) end
   end)
   ui.historyRows[n]=row
  end
  row.entry=entry; row:SetPoint("TOPLEFT",0,-(n-1)*80); row:Show()
  self:PaintRow(row,false,n%2==0)
  row.label:SetText(L[entry.note].." • "..date(L["History date format"],entry.time))
  row.meta:SetText((entry.character or "").." • "..L[entry.scope==2 and "Character" or "Account"])
 end
 for i=#self.engine.db.history+1,#ui.historyRows do ui.historyRows[i]:Hide() end
 ui.historyChild:SetHeight(math.max(1,#self.engine.db.history*80))
end
function Q:BuildSettingsPage()
 local ui=self.ui; local p=ui.pages.Settings
 ui.settingsControls={}
 local function check(label,key,y)
  local b=CreateFrame("CheckButton",nil,p,"UICheckButtonTemplate"); b:SetSize(28,28); b:SetPoint("TOPLEFT",4,y)
  text(p,L[label],42,y-5,760)
  b:SetScript("OnClick",function(self) Q.engine.db.settings[key]=self:GetChecked() and true or false; Q:Refresh() end)
  ui.settingsControls[key]=b
 end
 check("Confirm key conflicts","confirmConflicts",0); check("Show overlay labels","labels",-44)
 ui.scaleLabel=text(p,"",4,-100,650)
 button(p,"-",690,-94,80,function() self.engine.db.settings.scale=math.max(.6,self.engine.db.settings.scale-.1); self:Refresh() end)
 button(p,"+",785,-94,80,function() self.engine.db.settings.scale=math.min(1.4,self.engine.db.settings.scale+.1); self:Refresh() end)
 ui.opacityLabel=text(p,"",4,-152,650)
 button(p,"-",690,-146,80,function() self.engine.db.settings.opacity=math.max(.1,self.engine.db.settings.opacity-.1); self:Refresh() end)
 button(p,"+",785,-146,80,function() self.engine.db.settings.opacity=math.min(.9,self.engine.db.settings.opacity+.1); self:Refresh() end)
 ui.settingsLayout=button(p,"",4,-202,400,function()
  local cycle={QWERTY="AZERTY",AZERTY="QWERTZ",QWERTZ="QWERTY"}; self.engine.db.settings.layout=cycle[self.engine.db.settings.layout] or "QWERTY"; self.engine.db.settings.layoutSource="manual"; self:Refresh()
 end)
 ui.settingsDetect=button(p,L["Detect keyboard layout"],424,-202,440,function() self:DetectKeyboardLayout() end)
 ui.settingsDefaultLayout=button(p,L["Use client-language default"],4,-244,400,function()
  local e=self.engine; e.db.settings.layout=e.DefaultKeyboardLayout(e.api.locale and e.api.locale()); e.db.settings.layoutSource="locale"; self:Refresh()
 end)
 text(p,"/qkb  •  /quickkeybinds  •  /kb ("..L["if available"]..")\n\n"..L["Your draft stays available until reload/logout."].."\n\n"..L["A profile stores bindings, not spells or bar layouts."].."\n\nQuickKeybinds "..self.version.." • WoW Forever",4,-300,960)
end
function Q:RefreshSettings()
 local ui,s=self.ui,self.engine.db.settings
 ui.settingsControls.confirmConflicts:SetChecked(s.confirmConflicts); ui.settingsControls.labels:SetChecked(s.labels)
 ui.scaleLabel:SetText(L["UI scale"]..": "..self:F("Percentage format",s.scale*100))
 ui.opacityLabel:SetText(L["Overlay opacity"]..": "..self:F("Percentage format",s.opacity*100))
 ui.settingsLayout:SetText(L["Keyboard layout"]..": "..s.layout)
 enable(ui.settingsDetect,not InCombatLockdown())
end
