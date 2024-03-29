if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local Unit = Addon:NewModule("ArtfulDodger_UnitFrame", "AceEvent-3.0")
local Events = Addon.Events
local L = Addon.Localizations
local Utils = Addon.Utils

function Unit:OnInitialize()
    self.settings = Addon.db.settings.unitFrame
    self:Register()
end

function Unit:Register()
    if self.settings.enabled then
        self:RegisterEvent("UI_ERROR_MESSAGE")
	    self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
        self:RegisterEvent("PLAYER_REGEN_DISABLED", "HideNamePlates")
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "UpdateNamePlates")
        self:RegisterMessage(Events.Loot.PickPocketComplete, "UpdateNamePlateFromEvent")
    end
    self:RegisterMessage(Events.UnitFrame.Toggle, "ToggleUnitFrame")
end

function Unit:Unregister()
    self:UnregisterEvent("UI_ERROR_MESSAGE")
	self:UnregisterEvent("NAME_PLATE_UNIT_ADDED")
    self:UnregisterEvent("NAME_PLATE_UNIT_REMOVED")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:UnregisterMessage(Events.Loot.PickPocketComplete)
end

function Unit:ToggleUnitFrame(_, enabled)
    if enabled == self.settings.enabled then
        return
    end
    if enabled then
        self:Register()
    else
        self:ClearNamePlates()
        self:Unregister()
    end
    self.settings.enabled = enabled
end

function Unit:UpdateNamePlateFromEvent(_, event)
    self:UpdateNamePlate(UnitTokenFromGUID(event.victim.guid))
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
    if message == SPELL_FAILED_TARGET_NO_POCKETS or message == ERR_ALREADY_PICKPOCKETED then
        self:UpdateNamePlate(UnitTokenFromGUID(UnitGUID("target")))
    end
end

function Unit:HideNamePlates()
    local namePlates = C_NamePlate.GetNamePlates()
    for i = 1, #namePlates do
        local namePlate = C_NamePlate.GetNamePlateForUnit(namePlates[i].namePlateUnitToken)
        if namePlate and namePlate.ArtfulDodger then
            namePlate.ArtfulDodger:Hide()
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

    if namePlate and Utils:IsValidTarget(unitId, npcId) and Addon:HasPockets(npcId) then 

        if namePlate.ArtfulDodger == nil then
            self:AddTextureToNamePlate(namePlate)
        end

        if Addon:EligibleForPickpocket(guid) then
            namePlate.ArtfulDodger:Show()
        else
            Addon.RecentPickpockets[guid] = {timestamp = time()}
            namePlate.ArtfulDodger:Hide()
        end
    else
        if namePlate and namePlate.ArtfulDodger then
            namePlate.ArtfulDodger:Hide()
            namePlate.ArtfulDodger = nil
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