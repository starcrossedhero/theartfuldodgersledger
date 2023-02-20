if select(3, UnitClass("player")) ~= 4 then
    return
end

local addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local unit = addon:NewModule("ArtfulDodger_UnitFrame", "AceEvent-3.0", "AceTimer-3.0")
local defaults = {
	char = {
        exclusions = {}
    }
}

function unit:OnInitialize()
    self.db = addon.dbo:RegisterNamespace("UnitFrame", defaults).char
    self.settings = addon.db.settings.unitFrame
    self:Register()
end

function unit:Register()
    if self.settings.enabled then
        self:RegisterEvent("UI_ERROR_MESSAGE")
	    self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
        self:RegisterMessage("ArtfulDodger_PickPocketComplete", "UpdateNamePlates")
    end
    self:RegisterMessage("ArtfulDodger_ResetHistory", "ResetExclusions")
    self:RegisterMessage("ArtfulDodger_ToggleUnitFrame", "ToggleUnitFrame")
end

function unit:UnRegister()
    self:UnregisterEvent("UI_ERROR_MESSAGE")
	self:UnregisterEvent("NAME_PLATE_UNIT_ADDED")
    self:UnregisterEvent("NAME_PLATE_UNIT_REMOVED")
    self:UnregisterMessage("ArtfulDodger_PickPocketComplete", "UpdateNamePlates")
end

function unit:ResetExclusions()
    self.db.exclusions = defaults.char.exclusions
end

function unit:OnEnable()
    if self.settings.enabled then
        self.updateTimer = self:ScheduleRepeatingTimer("UpdateNamePlates", self.settings.updateFrequencySeconds)
    end
end

function unit:ToggleUnitFrame(_, enabled)
    if enabled == self.settings.enabled then
        return
    end
    if enabled then
        self.updateTimer = self:ScheduleRepeatingTimer("UpdateNamePlates", self.settings.updateFrequencySeconds)
    else
        self:CancelTimer(self.updateTimer)
        self:ClearNamePlates()
    end
    self.settings.enabled = enabled
end

function unit:NAME_PLATE_UNIT_ADDED(event, unitId)

    unit:UpdateNamePlate(unitId)
end

function unit:NAME_PLATE_UNIT_REMOVED(event, unitId)
    local nameplate = C_NamePlate.GetNamePlateForUnit(unitId)
    if nameplate.ArtfulDodger then
        nameplate.ArtfulDodger:Hide()
        nameplate.ArtfulDodger = nil
    end
end

function unit:UI_ERROR_MESSAGE(event, errorType, message)
    if message == SPELL_FAILED_TARGET_NO_POCKETS then
        local guid = UnitGUID("target")
        if guid then
            local npcId = select(6, strsplit("-", guid))
            if npcId then
                table.insert(self.db.exclusions, npcId)
                unit:UpdateNamePlates()
            end
        end
    end
end

function unit:ClearNamePlates()
    local namePlates = C_NamePlate.GetNamePlates()
    for i = 1, #namePlates do
        local namePlate = C_NamePlate.GetNamePlateForUnit(namePlates[i].namePlateUnitToken)
        if namePlate and namePlate.ArtfulDodger then
            namePlate.ArtfulDodger:Hide()
            namePlate.ArtfulDodger = nil
        end
    end
end

function unit:UpdateNamePlates()
    local namePlates = C_NamePlate.GetNamePlates()
    for i = 1, #namePlates do
        unit:UpdateNamePlate(namePlates[i].namePlateUnitToken)
    end
end

function unit:UpdateNamePlate(unitId)
    local guid = UnitGUID(unitId)
    local npcId = select(6, strsplit("-", guid))
    local namePlate = C_NamePlate.GetNamePlateForUnit(unitId)

    if namePlate and UnitCreatureType(unitId) == "Humanoid" and not UnitIsPlayer(unitId) and not UnitIsFriend("player", unitId) and unit:HasPockets(npcId) then 

        if namePlate.ArtfulDodger == nil then
            unit:AddTextureToNamePlate(namePlate)
        end

        local victim = addon:GetLatestPickPocketByGuid(guid)
        if victim == nil or unit:HasLootRespawned(victim) then
            namePlate.ArtfulDodger:Show()
        else
            namePlate.ArtfulDodger:Hide()
        end
    else
        if namePlate and namePlate.ArtfulDodger then
            namePlate.ArtfulDodger:Hide()
        end
    end
end

function unit:AddTextureToNamePlate(namePlate)
    namePlate.ArtfulDodger = namePlate:CreateTexture(nil, "OVERLAY")
    namePlate.ArtfulDodger:SetTexture("Interface\\Icons\\INV_Misc_Bag_11")
    namePlate.ArtfulDodger:SetSize(15,15)
    namePlate.ArtfulDodger:SetPoint("RIGHT", 5, 0)
    namePlate.ArtfulDodger:Hide()
end

function unit:HasLootRespawned(victim)
    return (time() - victim.timestamp) > self.settings.lootRespawnSeconds
end

function unit:HasPockets(npcId)
    for i = 1, #self.db.exclusions do
        if self.db.exclusions[i] == npcId then
            return false
        end
    end
    return true
end