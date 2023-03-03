if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local L = Addon.Localizations

--Generally pick pocketable types
local Types = {
    [L["Humanoid"]] = true,
    [L["Undead"]] = true,
    [L["Demon"]] = true
}
setmetatable(Types, {__index=function()
    return false
end})

Addon.CreatureTypes = Types