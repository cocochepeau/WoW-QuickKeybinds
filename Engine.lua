local _, Q = ...
local function T(key,...)
 local value=Q.L and Q.L[key] or key
 return select("#",...)>0 and string.format(value,...) or value
end
local E = {}
Q.Engine = E
local function copy(t) local n={} for k,v in pairs(t or {}) do n[k]=v end return n end
Q.Copy = copy
local function keys(t) local a={} for k in pairs(t) do a[#a+1]=k end table.sort(a) return a end
Q.SortedKeys = keys
function E.Equal(a,b)
 for k,v in pairs(a) do if b[k]~=v then return false end end
 for k,v in pairs(b) do if a[k]~=v then return false end end
 return true
end
function E.Diff(a,b)
 local out, union={},copy(a)
 for k in pairs(b) do union[k]=true end
 for _,k in ipairs(keys(union)) do
  if a[k]~=b[k] then out[#out+1]={key=k,old=a[k],new=b[k]} end
 end
 return out
end
function E.KeysFor(map,command)
 local out={} for k,v in pairs(map) do if v==command then out[#out+1]=k end end
 table.sort(out) return out
end
function E.DefaultKeyboardLayout(locale)
 return locale=="frFR" and "AZERTY" or locale=="deDE" and "QWERTZ" or "QWERTY"
end
function E.New(api,db)
 local self=setmetatable({api=api, db=db, undo={}, redo={}}, {__index=E})
 db.profiles=db.profiles or {}; db.history=db.history or {}; db.settings=db.settings or {}
 local s=db.settings
 if s.confirmConflicts==nil then s.confirmConflicts=true end
 if not s.layout or s.layoutSource=="locale" then
  s.layout=E.DefaultKeyboardLayout(api.locale and api.locale()); s.layoutSource="locale"
 end
 s.scale=s.scale or 1; s.opacity=s.opacity or .35
 if s.labels==nil then s.labels=true end
 return self
end
function E:Changed() if self.onChange then self.onChange() end end
function E:Guard(fn)
 self.busy=true
 local ok,a,b=pcall(fn)
 self.busy=false
 if not ok then return nil,T("Unexpected error: %s",tostring(a)) end
 return a,b
end
function E:ReadScope(scope)
 return self:Guard(function()
  local oldScope=self.api.scope(); local live=self.api.snapshot()
  if scope==oldScope then return live end
  if self.api.combat() then return nil,T("Editing paused in combat. Your draft is preserved.") end
  local ok,result=pcall(function()
   local loaded,err=self.api.load(scope)
   if loaded==false then error(err or T("Unable to load binding scope.")) end
   -- GetCurrentBindingSet can continue reporting the saved scope until SaveBindings.
   return self.api.snapshot()
  end)
  -- Always restore even if loading or reading the other scope raised an error.
  local restored,why=pcall(function()
   local loaded,err=self.api.load(oldScope)
   if loaded==false then error(err or T("Unable to restore binding scope.")) end
   local applied,applyErr=self.api.apply(live)
   if not applied then error(applyErr or T("Unable to restore live bindings.")) end
   if self.api.scope()~=oldScope or not E.Equal(self.api.snapshot(),live) then error(T("Live bindings could not be restored.")) end
  end)
  if not restored then
   self:Record("backup",live,"Recovery after scope read failure",oldScope); self.external=true
   return nil,T("%s. A recovery snapshot is available in History.",tostring(why))
  end
  if not ok then return nil,tostring(result) end
  return result
 end)
end
function E:Begin(scope)
 if self.baseline and self:Dirty() then return nil,T("Save your changes or discard them before switching scope.") end
 local map,err=self:ReadScope(scope)
 if not map then return nil,err end
 self.scope=scope; self.baseline=copy(map); self.draft=copy(map)
 self.liveScope=self.api.scope(); self.liveBaseline=self.api.snapshot()
 self.undo={}; self.redo={}; self.external=false; self.activeProfile=nil
 self:Changed() return true
end
function E:Dirty() return self.draft and not E.Equal(self.baseline,self.draft) or false end
function E:Pending() return self.draft and E.Diff(self.baseline,self.draft) or {} end
function E:CanEdit()
 if not self.draft then return nil,T("Open the editor first.") end
 if self.api.combat() then return nil,T("Editing paused in combat. Your draft is preserved.") end
 if self.external then return nil,T("Bindings changed outside QuickKeybinds. Reload them or rebase your draft before saving.") end
 return true
end
function E:CommitDraft(map,label)
 local ok,err=self:CanEdit(); if not ok then return nil,err end
 for _,key in ipairs({"BUTTON1","BUTTON2"}) do map[key]=self.baseline[key] end
 if E.Equal(map,self.draft) then return true end
 self.undo[#self.undo+1]={map=copy(self.draft),profile=self.activeProfile,label=label}
 if #self.undo>100 then table.remove(self.undo,1) end
 self.redo={}; self.draft=copy(map); self.activeProfile=nil; self:Changed() return true
end
function E:Assign(key,command,replaceKey,confirmed)
 local ok,err=self:CanEdit(); if not ok then return nil,err end
 if type(key)~="string" or key=="" or not command then return nil,T("Invalid binding.") end
 if key=="BUTTON1" or key=="BUTTON2" then return nil,T("Unmodified left and right mouse buttons are reserved.") end
 if not self.api.known(command) then return nil,T("Unavailable binding command: %s",command) end
 local old=self.draft[key]
 if old and old~=command and self.db.settings.confirmConflicts and not confirmed then
  return nil,"conflict",{key=key,old=old,new=command,replaceKey=replaceKey}
 end
 local map=copy(self.draft)
 if replaceKey and map[replaceKey]==command then map[replaceKey]=nil end
 map[key]=command
 return self:CommitDraft(map,"Assign "..key)
end
function E:Remove(key) local map=copy(self.draft); map[key]=nil; return self:CommitDraft(map,"Remove "..key) end
function E:Clear(command)
 local map=copy(self.draft) for k,v in pairs(map) do if v==command then map[k]=nil end end
 return self:CommitDraft(map,"Clear "..command)
end
function E:Undo()
 local ok,err=self:CanEdit(); if not ok then return nil,err end
 local state=table.remove(self.undo); if not state then return true end
 self.redo[#self.redo+1]={map=copy(self.draft),profile=self.activeProfile}
 self.draft=state.map; self.activeProfile=state.profile; self:Changed() return true
end
function E:Redo()
 local ok,err=self:CanEdit(); if not ok then return nil,err end
 local state=table.remove(self.redo); if not state then return true end
 self.undo[#self.undo+1]={map=copy(self.draft),profile=self.activeProfile}
 self.draft=state.map; self.activeProfile=state.profile; self:Changed() return true
end
function E:Discard()
 if self.api.combat() then return nil,T("Editing paused in combat. Your draft is preserved.") end
 if self.external then return self:Reload() end
 self.draft=copy(self.baseline); self.undo={}; self.redo={}; self.activeProfile=nil; self:Changed() return true
end
function E:CheckExternal()
 if self.busy or not self.draft then return end
 if self.api.scope()~=self.liveScope or not E.Equal(self.api.snapshot(),self.liveBaseline) then
  self.external=true; self:Changed()
 end
end
function E:Reload()
 if self.api.combat() then return nil,T("Editing paused in combat. Your draft is preserved.") end
 self.baseline=nil; self.draft=nil
 return self:Begin(self.api.scope())
end
function E:Rebase(expectedMap)
 if self.api.combat() then return nil,T("Editing paused in combat. Your draft is preserved.") end
 local patch=self:Pending(); local map,err=self:ReadScope(self.scope)
 if not map then return nil,err end
 if expectedMap and not E.Equal(map,expectedMap) then return nil,T("Bindings changed again. Open a new rebase preview.") end
 local result=copy(map)
 for _,d in ipairs(patch) do result[d.key]=d.new end
 self.baseline=copy(map); self.draft=result; self.undo={}; self.redo={}; self.external=false
 self.liveScope=self.api.scope(); self.liveBaseline=self.api.snapshot(); self:Changed() return true
end
function E:Record(kind,map,note,scope)
 local h=self.db.history
 table.insert(h,1,{kind=kind,map=copy(map),note=note,scope=scope or self.scope,time=self.api.time(),character=self.api.character()})
 while #h>50 do table.remove(h) end
end
function E:Save()
 local ok,err=self:CanEdit(); if not ok then return nil,err end
 self:CheckExternal(); if self.external then return nil,T("Bindings changed outside QuickKeybinds. Reload them or rebase your draft before saving.") end
 if not self:Dirty() and self.api.scope()==self.scope then return true end
 local beforeScope=self.api.scope(); local before=self.api.snapshot()
 local targetBefore,readErr=self:ReadScope(self.scope); if not targetBefore then return nil,readErr end
 local desired=copy(self.draft)
 for _,change in ipairs(E.Diff(targetBefore,desired)) do
  if change.new and not self.api.known(change.new) then return nil,T("Unavailable binding command: %s",change.new) end
 end
 self:Record("backup",targetBefore,"Backup before save")
 local saved,why=self:Guard(function()
  local loaded,loadErr=self.api.load(self.scope); if loaded==false then return nil,loadErr or T("Unable to load binding scope.") end
  local applied,applyErr=self.api.apply(desired); if not applied then return nil,applyErr end
  if not E.Equal(self.api.snapshot(),desired) then return nil,T("The client rejected one or more bindings.") end
  local result,saveErr=self.api.save(self.scope)
  if result==false then return nil,saveErr or T("The client could not save bindings.") end
  if self.api.scope()~=self.scope or not E.Equal(self.api.snapshot(),desired) then return nil,T("The client changed bindings while saving.") end
  return true
 end)
 if not saved then
  local rollback,rollbackErr=self:Guard(function()
   local loaded=self.api.load(self.scope); if loaded==false then return nil,T("Could not load scope for rollback.") end
   local applied,applyErr=self.api.apply(targetBefore); if not applied then return nil,applyErr end
   local persisted,persistErr=self.api.save(self.scope); if persisted==false then return nil,persistErr or T("Could not restore saved bindings.") end
   if beforeScope~=self.scope then
    loaded=self.api.load(beforeScope); if loaded==false then return nil,T("Could not restore original scope.") end
    applied,applyErr=self.api.apply(before); if not applied then return nil,applyErr end
    if self.api.scope()~=beforeScope then
     persisted,persistErr=self.api.save(beforeScope); if persisted==false then return nil,persistErr or T("Could not restore original binding scope.") end
    end
   end
   if self.api.scope()~=beforeScope or not E.Equal(self.api.snapshot(),before) then return nil,T("Original live bindings could not be restored.") end
   return true
  end)
  self.liveScope=self.api.scope(); self.liveBaseline=self.api.snapshot()
  if not rollback then self.external=true; why=T("%s Rollback failed: %s. Restore the automatic backup in History.",tostring(why),tostring(rollbackErr)) end
  self:Changed(); return nil,why
 end
 self.baseline=copy(desired); self.undo={}; self.redo={}; self.external=false
 self.liveScope=self.api.scope(); self.liveBaseline=self.api.snapshot()
 self:Record("save",desired,"Changes saved"); self:Changed(); return true
end
function E:ValidateMap(map)
 if type(map)~="table" then return nil,T("Invalid binding map.") end
 local n=0
 for key,command in pairs(map) do
  n=n+1
  if n>4000 or type(key)~="string" or #key>80 or not key:match("^[A-Z0-9%-%[%]\\/;=',.`+]+$") then return nil,T("Invalid key: %s",tostring(key)) end
  if (key=="BUTTON1" or key=="BUTTON2") and (not self.baseline or self.baseline[key]~=command) then return nil,T("Unmodified left and right mouse buttons are reserved.") end
  if type(command)~="string" or #command>240 or command=="" or command:find("[%c]") then return nil,T("Invalid command.") end
 end
 return true
end
function E:PreviewMap(map)
 local ok,err=self:ValidateMap(map); if not ok then return nil,err end
 -- Preserve the client's camera/movement mouse buttons across profiles from other characters.
 map=copy(map)
 for _,key in ipairs({"BUTTON1","BUTTON2"}) do if self.baseline[key] then map[key]=self.baseline[key] end end
 local missing={} for _,cmd in pairs(map) do if not self.api.known(cmd) then missing[cmd]=true end end
 return {map=copy(map),changes=E.Diff(self.draft,map),missing=keys(missing)}
end
function E:ApplyPreview(preview,name)
 local valid,err=self:PreviewMap(preview.map)
 if not valid then return nil,err end
 preview=valid
 if #preview.missing>0 then return nil,T("This profile contains commands unavailable on this client.") end
 local ok,err=self:CommitDraft(preview.map,"Apply profile")
 if ok then self.activeProfile=name; self:Changed() end
 return ok,err
end
local function validName(name)
 return type(name)=="string" and #name>0 and #name<=64 and not name:find("[%c]") and name:find("%S")
end
function E:CreateProfile(name,map)
 if not validName(name) then return nil,T("Use a name between 1 and 64 characters.") end
 if self.db.profiles[name] then return nil,T("A profile with that name already exists.") end
 self.db.profiles[name]={map=copy(map or self.draft),created=self.api.time(),character=self.api.character(),scope=self.scope}
 self:Changed(); return true
end
function E:RenameProfile(old,name)
 if not self.db.profiles[old] then return nil,T("No profile selected") end
 if not validName(name) then return nil,T("Use a name between 1 and 64 characters.") end
 if name==old then return true end
 if self.db.profiles[name] then return nil,T("A profile with that name already exists.") end
 self.db.profiles[name]=self.db.profiles[old]; self.db.profiles[old]=nil
 if self.activeProfile==old then self.activeProfile=name end
 self:Changed(); return true
end
local function encode(s) return (s:gsub("[^%w _%-%.]",function(c) return string.format("%%%02X",c:byte()) end)) end
local function decode(s)
 if s:gsub("%%[%x][%x]",""):find("%",1,true) then return nil end
 return (s:gsub("%%([%x][%x])",function(h) return string.char(tonumber(h,16)) end))
end
function E:Export(map,name)
 local lines={"QKB1\t"..encode(name or T("Draft"))}
 for _,key in ipairs(keys(map or self.draft)) do lines[#lines+1]=encode(key).."\t"..encode((map or self.draft)[key]) end
 return table.concat(lines,"\n")
end
function E:Import(text)
 if type(text)~="string" or #text>262144 then return nil,T("Import exceeds 256 KB.") end
 local map,name,count={},nil,0
 text=text:gsub("\r\n","\n")
 for line in (text.."\n"):gmatch("(.-)\n") do
  if not name then
   local header=line:match("^QKB1\t(.*)$"); name=header and decode(header)
   if not name or not validName(name) then return nil,T("Invalid QuickKeybinds export header (expected QKB1).") end
  elseif line~="" then
   local a,b=line:match("^([^\t]+)\t([^\t]+)$")
   a=a and decode(a); b=b and decode(b)
   if not a or not b or map[a] then return nil,T("Invalid or duplicate import entry.") end
   map[a]=b; count=count+1; if count>4000 then return nil,T("Too many bindings.") end
  end
 end
 local preview,err=self:PreviewMap(map); if not preview then return nil,err end
 preview.name=name; return preview
end
