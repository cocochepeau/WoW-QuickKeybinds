local _,Q=...
local white="Interface\\Buttons\\WHITE8X8"
Q.Theme={
 gold={.88,.72,.42}, text={.91,.89,.84}, muted={.52,.52,.50},
 bound={.35,.68,.85}, pending={1,.78,.32},
}
local backdrop={bgFile=white,edgeFile=white,edgeSize=1,insets={left=1,right=1,top=1,bottom=1}}
function Q:SkinPanel(frame)
 frame:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=32,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
 frame:SetBackdropColor(.11,.11,.12,.98); frame:SetBackdropBorderColor(.43,.40,.34,1)
end
function Q:Surface(parent)
 -- Background regions stay underneath the window's text and never intercept clicks.
 local fill=parent:CreateTexture(nil,"BACKGROUND",nil,-3); fill:SetColorTexture(.055,.055,.06,.93)
 for _,edge in ipairs({{"TOPLEFT","TOPRIGHT","height"},{"BOTTOMLEFT","BOTTOMRIGHT","height"},{"TOPLEFT","BOTTOMLEFT","width"},{"TOPRIGHT","BOTTOMRIGHT","width"}}) do
  local line=parent:CreateTexture(nil,"BACKGROUND",nil,-2); line:SetColorTexture(.24,.23,.20,1)
  line:SetPoint(edge[1],fill,edge[1],0,0); line:SetPoint(edge[2],fill,edge[2],0,0)
  if edge[3]=="height" then line:SetHeight(1) else line:SetWidth(1) end
 end
 return fill
end
function Q:CreateWindow(parent,width,height)
 local f
 if type(ButtonFrameTemplate_HidePortrait)=="function" then
  f=CreateFrame("Frame",nil,parent,"ButtonFrameTemplate")
  ButtonFrameTemplate_HidePortrait(f); f.qkbNative=true
  if f.SetTitle then f:SetTitle("QuickKeybinds") elseif f.TitleText then f.TitleText:SetText("QuickKeybinds") end
  if f.Inset then
   f.Inset:ClearAllPoints(); f.Inset:SetPoint("TOPLEFT",8,-28); f.Inset:SetPoint("BOTTOMRIGHT",-8,8)
  end
 else
  f=CreateFrame("Frame",nil,parent,"BackdropTemplate"); self:SkinPanel(f); f.qkbNative=false
  local title=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); title:SetPoint("TOP",0,-8); title:SetText("QuickKeybinds")
 end
 f:SetSize(width,height); return f
end
function Q:CloseControl(parent,callback)
 local b=parent.CloseButton
 if not b then b=CreateFrame("Button",nil,parent,"UIPanelCloseButton"); parent.CloseButton=b end
 b:ClearAllPoints(); b:SetPoint("TOPRIGHT",-4,-4); b:SetSize(24,24)
 b:SetScript("OnClick",callback); return b
end
function Q:PaintButton(b)
 local enabled=b:IsEnabled(); local role=b.qkbRole; local selected=b.qkbSelected
 local bg={.12,.12,.13}; local edge={.32,.30,.26}; local fg=self.Theme.text
 if role=="tab" or role=="filter" or role=="toggle" then
  bg={.08,.08,.09}; edge={.21,.20,.18}
  if selected then bg={.19,.16,.10}; edge={.62,.47,.24}; fg=self.Theme.gold end
 elseif role=="primary" then bg={.23,.17,.075}; edge={.62,.47,.23}; fg=self.Theme.gold
 elseif role=="key" then
  bg={.085,.09,.10}; edge={.25,.25,.25}
  if b.qkbKeyState=="bound" then edge={.24,.40,.49}; bg={.085,.12,.15}
  elseif b.qkbKeyState=="pending" then edge={.72,.52,.18}; bg={.19,.15,.08} end
  if selected then bg={.19,.16,.10}; edge={.62,.47,.24} end
 end
 if not enabled then bg={.075,.075,.08}; edge={.18,.18,.18}; fg=self.Theme.muted
 elseif b.qkbPressed then bg={.24,.21,.15}; edge=self.Theme.gold
 elseif b.qkbHover then bg={.20,.18,.14}; edge={.67,.54,.32} end
 b:SetBackdropColor(bg[1],bg[2],bg[3],1); b:SetBackdropBorderColor(edge[1],edge[2],edge[3],1)
 if b.qkbText then b.qkbText:SetTextColor(fg[1],fg[2],fg[3],1) end
 if b.qkbMark then b.qkbMark:SetShown(selected and enabled or false) end
end
function Q:SkinButton(b)
 if not b.qkbText then
  b:SetBackdrop(backdrop)
  b.qkbText=b:CreateFontString(nil,"OVERLAY","GameFontHighlight")
  b.qkbText:SetPoint("CENTER"); b.qkbText:SetWordWrap(false); b:SetFontString(b.qkbText)
  b.qkbMark=b:CreateTexture(nil,"OVERLAY"); b.qkbMark:SetColorTexture(.88,.72,.42,1)
  b.qkbMark:SetPoint("BOTTOMLEFT",1,1); b.qkbMark:SetPoint("BOTTOMRIGHT",-1,1); b.qkbMark:SetHeight(2); b.qkbMark:Hide()
  b:HookScript("OnEnter",function(self)
   self.qkbHover=true; Q:PaintButton(self)
   if self.qkbText.IsTruncated and self.qkbText:IsTruncated() then
    GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(self:GetText()); GameTooltip:Show(); self.qkbLabelTooltip=true
   end
  end)
  b:HookScript("OnLeave",function(self)
   self.qkbHover=false; self.qkbPressed=false; Q:PaintButton(self)
   if self.qkbLabelTooltip then self.qkbLabelTooltip=false; GameTooltip:Hide() end
  end)
  b:HookScript("OnMouseDown",function(self) self.qkbPressed=true; Q:PaintButton(self) end)
  b:HookScript("OnMouseUp",function(self) self.qkbPressed=false; Q:PaintButton(self) end)
  b:HookScript("OnEnable",function(self) Q:PaintButton(self) end)
  b:HookScript("OnDisable",function(self) self.qkbHover=false; self.qkbPressed=false; Q:PaintButton(self) end)
 end
 b.qkbRole="button"; b.qkbSelected=false; b.qkbHover=false; b.qkbPressed=false
 b.qkbText:SetWidth(math.max(1,b:GetWidth()-16)); b.qkbText:SetHeight(20)
 self:PaintButton(b)
end
function Q:SetButtonRole(b,role) b.qkbRole=role; self:PaintButton(b) end
function Q:SelectButton(b,selected) b.qkbSelected=selected and true or false; self:PaintButton(b) end
function Q:PaintRow(row,selected,alternate)
 if not row.qkbRow then row:SetBackdrop(backdrop); row.qkbRow=true end
 if selected then row:SetBackdropColor(.18,.15,.09,1); row:SetBackdropBorderColor(.52,.40,.23,1)
 else
  local shade=alternate and .085 or .065
  row:SetBackdropColor(shade,shade,shade+.005,1); row:SetBackdropBorderColor(0,0,0,0)
 end
end
