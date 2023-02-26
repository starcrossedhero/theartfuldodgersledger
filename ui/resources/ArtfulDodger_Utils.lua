local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local L = Addon.Localizations
local Utils = {}
Addon.Utils = Utils

--according to wowhead
Utils.CreatureTypes = {
    [L["Humanoid"]] = true, 
    [L["Dragonkin"]] = true,
    [L["Elemental"]] = true,
    [L["Beast"]] = true,
    [L["Mechanical"]] = true,
    [L["Giant"]] = true,
    [L["Undead"]] = true,
    [L["Aberration"]] = true
}

function Utils:IsValidCreatureType(unitId)
    return self.CreatureTypes[UnitCreatureType(unitId)] ~= nil
end

function Utils:IsValidUnit(unitId)
    return not UnitIsPlayer(unitId) and not UnitIsFriend("player", unitId)
end

function Utils:IsValidTarget(unitId)
    return self:IsValidUnit(unitId) and self:IsValidCreatureType(unitId)
end