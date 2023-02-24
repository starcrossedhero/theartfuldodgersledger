if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")

local L = setmetatable({}, {__index=function(_, key)
    return key
end})

Addon.Localizations = L

local locale = GetLocale()

if      locale == "deDE" then
    L["Humanoid"] = "Humanoid"

elseif  locale == "esES" then
    L["Humanoid"] = "Humanoide"

elseif  locale == "esMX" then
    L["Humanoid"] = "Humanoide"

elseif  locale == "frFR" then
    L["Humanoid"] = "Humanoïde"

elseif  locale == "itIT" then
    L["Humanoid"] = "Umanoide"

elseif  locale == "ptBR" then
    L["Humanoid"] = "Humanoide"

elseif  locale == "ruRU" then
    L["Humanoid"] = "Гуманоид"

elseif  locale == "koKR" then
    L["Humanoid"] = "인간형"

elseif  locale == "zhCN" then
    L["Humanoid"] = "人型生物"

elseif  locale == "zhTW" then
    L["Humanoid"] = "人型生物"
end