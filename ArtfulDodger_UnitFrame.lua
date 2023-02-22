if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local Unit = Addon:NewModule("ArtfulDodger_UnitFrame", "AceEvent-3.0", "AceTimer-3.0")
local Events = Addon.Events

local defaults = {
	char = {
        exclusions = {}
    }
}

function Unit:OnInitialize()
    self.db = Addon.dbo:RegisterNamespace("UnitFrame", defaults).char
    self.settings = Addon.db.settings.unitFrame
    self:Register()
end

function Unit:Register()
    if self.settings.enabled then
        self:RegisterEvent("UI_ERROR_MESSAGE")
	    self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
        self:RegisterMessage(Events.Loot.PickPocket, "UpdateNamePlates")
    end
    self:RegisterMessage(Events.History.Reset, "ResetExclusions")
    self:RegisterMessage(Events.UnitFrame.Reset, "ResetExclusions")
    self:RegisterMessage(Events.UnitFrame.Toggle, "ToggleUnitFrame")
end

function Unit:Unregister()
    self:UnregisterEvent("UI_ERROR_MESSAGE")
	self:UnregisterEvent("NAME_PLATE_UNIT_ADDED")
    self:UnregisterEvent("NAME_PLATE_UNIT_REMOVED")
    self:UnregisterMessage(Events.Loot.PickPocket)
    self:UnegisterMessage(Events.UnitFrame.Reset)
end

function Unit:ResetExclusions()
    self.db.exclusions = defaults.char.exclusions
end

function Unit:OnEnable()
    if self.settings.enabled then
        self.updateTimer = self:ScheduleRepeatingTimer("UpdateNamePlates", self.settings.updateFrequencySeconds)
    end
end

function Unit:ToggleUnitFrame(_, enabled)
    if enabled == self.settings.enabled then
        return
    end
    if enabled then
        self.updateTimer = self:ScheduleRepeatingTimer("UpdateNamePlates", self.settings.updateFrequencySeconds)
        self:Register()
    else
        self:CancelTimer(self.updateTimer)
        self:ClearNamePlates()
        self:Unregister()
    end
    self.settings.enabled = enabled
end

function Unit:NAME_PLATE_UNIT_ADDED(event, unitId)

    Unit:UpdateNamePlate(unitId)
end

function Unit:NAME_PLATE_UNIT_REMOVED(event, unitId)
    local nameplate = C_NamePlate.GetNamePlateForUnit(unitId)
    if nameplate.ArtfulDodger then
        nameplate.ArtfulDodger:Hide()
        nameplate.ArtfulDodger = nil
    end
end

function Unit:UI_ERROR_MESSAGE(event, errorType, message)
    if message == SPELL_FAILED_TARGET_NO_POCKETS then
        local guid = UnitGUID("target")
        if guid then
            local npcId = select(6, strsplit("-", guid))
            if npcId then
                table.insert(self.db.exclusions, npcId)
                Unit:UpdateNamePlates()
            end
        end
    end
end

function Unit:ClearNamePlates()
    local namePlates = C_NamePlate.GetNamePlates()
    for i = 1, #namePlates do
        local namePlate = C_NamePlate.GetNamePlateForUnit(namePlates[i].namePlateUnitToken)
        if namePlate and namePlate.ArtfulDodger then
            namePlate.ArtfulDodger:Hide()
            namePlate.ArtfulDodger = nil
        end
    end
end

function Unit:UpdateNamePlates()
    local namePlates = C_NamePlate.GetNamePlates()
    for i = 1, #namePlates do
        Unit:UpdateNamePlate(namePlates[i].namePlateUnitToken)
    end
end

function Unit:UpdateNamePlate(unitId)
    local guid = UnitGUID(unitId)
    local npcId = select(6, strsplit("-", guid))
    local namePlate = C_NamePlate.GetNamePlateForUnit(unitId)

    if namePlate and UnitCreatureType(unitId) == "Humanoid" and not UnitIsPlayer(unitId) and not UnitIsFriend("player", unitId) and Unit:HasPockets(npcId) then 

        if namePlate.ArtfulDodger == nil then
            Unit:AddTextureToNamePlate(namePlate)
        end

        local victim = Addon:GetLatestPickPocketByGuid(guid)
        if victim == nil or Unit:HasLootRespawned(victim) then
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

function Unit:AddTextureToNamePlate(namePlate)
    namePlate.ArtfulDodger = namePlate:CreateTexture(nil, "OVERLAY")
    namePlate.ArtfulDodger:SetTexture("Interface\\Icons\\INV_Misc_Bag_11")
    namePlate.ArtfulDodger:SetSize(15,15)
    namePlate.ArtfulDodger:SetPoint("RIGHT", 5, 0)
    namePlate.ArtfulDodger:Hide()
end

function Unit:HasLootRespawned(victim)
    return (time() - victim.timestamp) > self.settings.lootRespawnSeconds
end

function Unit:HasPockets(npcId)
    for i = 1, #self.db.exclusions do
        if self.db.exclusions[i] == npcId then
            return false
        end
    end
    return true
end