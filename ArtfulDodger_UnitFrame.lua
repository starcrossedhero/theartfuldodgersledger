local addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local unit = addon:NewModule("ArtfulDodger_UnitFrame", "AceEvent-3.0", "AceTimer-3.0")
local defaults = {
	char = {
        settings = {
            lootRespawnSeconds = 420,
            updateFrequencySeconds = 5
        },
        exclusions = {},
    }
}

function unit:OnInitialize()
    self.db = addon.dbo:RegisterNamespace("UnitFrame", defaults).char
    self:RegisterEvent("UI_ERROR_MESSAGE")
	self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    self:RegisterMessage("ArtfulDodger_PickPocketComplete", "UpdateNamePlates")
end

function unit:OnEnable()
    self.testTimer = self:ScheduleRepeatingTimer("UpdateNamePlates", self.db.settings.updateFrequencySeconds)
end

function unit:NAME_PLATE_UNIT_ADDED(event, unitId)
    unit:UpdateNamePlate(unitId)
end

function unit:NAME_PLATE_UNIT_REMOVED(event, unitId)
    local nameplate = C_NamePlate.GetNamePlateForUnit(unitId)
    if nameplate.ArtfulDodger then
        nameplate.ArtfulDodger:Hide()
    end
end

function unit:UI_ERROR_MESSAGE(event, errorType, message)
	if message == SPELL_FAILED_TARGET_NO_POCKETS then
            local guid = UnitGUID("target")
            if guid then
                table.insert(self.db.exclusions, guid)
                unit:UpdateNamePlates()
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
    local name = UnitName(unitId)
    local namePlate = C_NamePlate.GetNamePlateForUnit(unitId)

    if UnitCreatureType(unitId) == "Humanoid" and not UnitIsPlayer(unitId) and not UnitIsFriend("player", unitId) and unit:HasPocketsByGuid(guid) then 
        local mark = addon:GetLatestPickPocketByGuid(guid)
        if mark == nil then
            if namePlate.ArtfulDodger == nil then
                unit:AddTextureToNamePlate(namePlate)
            end
            namePlate.ArtfulDodger:Show()
        else
            if namePlate and namePlate.ArtfulDodger then
                if unit:HasLootRespawned(mark) then
                    namePlate.ArtfulDodger:Show()
                else
                    namePlate.ArtfulDodger:Hide()
                end
            end
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
end

function unit:HasLootRespawned(mark)
    return (time() - mark.timestamp) > self.db.settings.lootRespawnSeconds
end

function unit:HasPocketsByGuid(guid)
    for i = 1, #self.db.exclusions do
        if self.db.exclusions[i] == guid then
            return false
        end
    end
    return true
end