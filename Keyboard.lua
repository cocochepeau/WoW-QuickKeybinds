local _,Q=...
-- Coordinates share a 44px key unit; the navigation block and numpad have gutters.
local unit,gap=44,4
local keys={}
local function add(key,x,y,width,height,group,extra)
 local item={key=key,x=x,y=y,width=width or unit-gap,height=height or 40,group=group or "main"}
 for k,v in pairs(extra or {}) do item[k]=v end
 keys[#keys+1]=item
end
local function row(y,values)
 local x=4
 for _,entry in ipairs(values) do
  local key,width,extra=entry,1,nil
  if type(entry)=="table" then key,width,extra=entry[1],entry[2] or 1,entry[3] end
  add(key,x,y,width*unit-gap,40,"main",extra); x=x+width*unit
 end
end
add("ESCAPE",4,103,nil,36,"function")
for i=1,12 do
 local x=i<=4 and i+1 or i<=8 and i+1.5 or i+2
 add("F"..i,4+x*unit,103,nil,36,"function")
end
row(149,{"`","1","2","3","4","5","6","7","8","9","0","-","=",{"BACKSPACE",2}})
row(194,{{"TAB",1.5},"Q","W","E","R","T","Y","U","I","O","P","[","]",{"\\",1.5}})
row(239,{{"CAPSLOCK",1.75},"A","S","D","F","G","H","J","K","L",";","'",{"ENTER",2.25}})
row(284,{{"LSHIFT",2.25,{modifier="shift",caption="Shift"}},"Z","X","C","V","B","N","M",",",".","/",{"RSHIFT",2.75,{modifier="shift",caption="Shift"}}})
row(329,{
 {"LCTRL",1.25,{modifier="ctrl",caption="Ctrl"}},
 {"WINLEFT",1.25,{system=true,caption="Win"}},
 {"LALT",1.25,{modifier="alt",caption="Alt"}},
 {"SPACE",6.25},
 {"RALT",1.25,{modifier="alt",caption="Alt"}},
 {"WINRIGHT",1.25,{system=true,caption="Win"}},
 {"MENU",1.25,{system=true,caption="Menu"}},
 {"RCTRL",1.25,{modifier="ctrl",caption="Ctrl"}},
})
local nav=680
for i,key in ipairs({"PRINTSCREEN","SCROLLLOCK","PAUSE"}) do add(key,nav+(i-1)*unit,103,nil,36,"navigation") end
for i,key in ipairs({"INSERT","HOME","PAGEUP"}) do add(key,nav+(i-1)*unit,149,nil,nil,"navigation") end
for i,key in ipairs({"DELETE","END","PAGEDOWN"}) do add(key,nav+(i-1)*unit,194,nil,nil,"navigation") end
add("UP",nav+unit,284,nil,nil,"navigation")
for i,key in ipairs({"LEFT","DOWN","RIGHT"}) do add(key,nav+(i-1)*unit,329,nil,nil,"navigation") end
local numpad=828
for i,key in ipairs({"NUMLOCK","NUMPADDIVIDE","NUMPADMULTIPLY","NUMPADMINUS"}) do add(key,numpad+(i-1)*unit,149,nil,nil,"numpad") end
for rowIndex,values in ipairs({{"NUMPAD7","NUMPAD8","NUMPAD9"},{"NUMPAD4","NUMPAD5","NUMPAD6"},{"NUMPAD1","NUMPAD2","NUMPAD3"}}) do
 for i,key in ipairs(values) do add(key,numpad+(i-1)*unit,194+(rowIndex-1)*45,nil,nil,"numpad") end
end
add("NUMPADPLUS",numpad+3*unit,194,nil,86,"numpad")
-- The native client uses ENTER for both Enter keys; both keycaps mirror that binding.
add("ENTER",numpad+3*unit,284,nil,85,"numpad",{alias=true})
add("NUMPAD0",numpad,329,unit*2-gap,nil,"numpad")
add("NUMPADDECIMAL",numpad+2*unit,329,nil,nil,"numpad")
for i=1,8 do add("BUTTON"..i,86+(i-1)*62,389,58,39,"mouse") end
add("MOUSEWHEELUP",610,389,94,39,"mouse")
add("MOUSEWHEELDOWN",714,389,94,39,"mouse")
Q.KeyboardKeys=keys
function Q:RecognizeKeyboardLayout(sample)
 if type(sample)~="string" or #sample~=6 then return end
 local layout=sample:upper()
 if layout=="AZERTY" or layout=="QWERTY" or layout=="QWERTZ" then return layout end
end
function Q:DetectKeyboardLayout()
 if not self.engine or InCombatLockdown() then
  self:Print(self.L["Editing paused in combat. Your draft is preserved."]); return
 end
 self:StopCapture()
 self:Dialog(self.L["Detect keyboard layout"],function(f)
  self.keyboardDetectionFrame=f
  local help=self.UIText(f,self.L["Press the first six letter keys in the top letter row, left to right, just after Tab. Use their physical positions without Shift, Ctrl or Alt."],18,-52,620)
  help:SetHeight(58); help:SetWordWrap(true)
  local input=f.keyboardInput
  if not input then
   input=CreateFrame("EditBox",nil,f,"InputBoxTemplate"); input:SetSize(300,28); input:SetPoint("TOPLEFT",24,-120)
   input:SetMaxLetters(6); input:SetAutoFocus(true); f.keyboardInput=input
  end
  input:SetScript("OnTextChanged",nil); input:SetText(""); input:Show()
  local result=self.UIText(f,"0 / 6",18,-162,620); result:SetHeight(30); result:SetWordWrap(true)
  input:SetScript("OnTextChanged",function(self)
   local sample=self:GetText(); local layout=Q:RecognizeKeyboardLayout(sample)
   if layout then
    Q.engine.db.settings.layout=layout; Q.engine.db.settings.layoutSource="detected"; Q:HideDialog()
    Q.ui.hoverKey=nil; Q.ui.message=Q.L["Keyboard layout detected"]..": "..layout; Q:Refresh()
   elseif #sample>=6 then
    result:SetText(Q.L["Sequence not recognized. Retry, or choose a layout manually."])
   else result:SetText(#sample.." / 6") end
  end)
  input:SetScript("OnEscapePressed",function() self:HideDialog() end)
  self.UIButton(f,self.L.Retry,18,-204,150,function() input:SetText(""); input:SetFocus() end)
  self.UIButton(f,self.L.Cancel,488,-204,150,function() self:HideDialog() end)
  input:SetFocus()
 end,660,248)
end
