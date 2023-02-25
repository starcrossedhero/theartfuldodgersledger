if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")

local L = setmetatable({}, {__index=function(_, key)
    return key
end})

Addon.Localizations = L