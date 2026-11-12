local _,Q=...
Q.version="1.0.9"
Q.locale=GetLocale and GetLocale() or "enUS"
Q.LocaleTables={}
Q.requestedLocaleKeys={}; Q.missingLocaleKeys={}; Q.missingLocaleTranslations={}
Q.L=setmetatable({}, {__index=function(_,key)
 Q.requestedLocaleKeys[key]=true
 local english=Q.LocaleTables.enUS or {}
 if english[key]==nil then Q.missingLocaleKeys[key]=true; return key end
 local active=Q.LocaleTables[Q.locale]
 if active and active[key]==nil then Q.missingLocaleTranslations[key]=true end
 return active and active[key] or english[key]
end})
function Q:F(key,...) return string.format(self.L[key],...) end
function Q:ModifierLabel(mod)
 local names={shift="Shift",ctrl="Ctrl",alt="Alt"}
 return self.L[names[mod] or mod]
end
function Q:ModifierList(mods)
 local names={} for _,mod in ipairs(mods) do names[#names+1]=self:ModifierLabel(mod) end
 return table.concat(names," + ")
end
function Q:Print(message)
 if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff55c9ffQuickKeybinds:|r "..tostring(message)) end
end
function Q:KeyText(key)
 if not key then return "" end
 return GetBindingText and GetBindingText(key,"KEY_") or key
end
