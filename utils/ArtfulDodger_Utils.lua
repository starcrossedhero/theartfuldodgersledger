local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local Types = Addon.CreatureTypes
local Exceptions = Addon.CreatureTypeExceptions
local Utils = {}
Addon.Utils = Utils

function Utils:IsValidUnit(unitId)
    return not UnitIsPlayer(unitId) and not UnitIsFriend("player", unitId)
end

function Utils:IsValidCreature(unitId, npcId)
    return Types[UnitCreatureType(unitId)] or Exceptions[npcId]
end

function Utils:IsValidTarget(unitId, npcId)
    return self:IsValidUnit(unitId) and self:IsValidCreature(unitId, npcId)
end