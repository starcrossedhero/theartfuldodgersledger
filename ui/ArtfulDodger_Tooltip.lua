if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local Stats = Addon:GetModule("ArtfulDodger_Stats")
local Events = Addon.Events
local Tool = Addon:NewModule("ArtfulDodger_Tooltip", "AceEvent-3.0")
local Utils = Addon.Utils
local L = Addon.Localizations

function Tool:OnInitialize()
    self.settings = Addon.db.settings.tooltip
    self:RegisterMessage(Events.Tooltip.Toggle, "Toggle")
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, Tool.OnTooltipSetItem)
end

function Tool:Toggle(_, enabled)
    self.settings.enabled = enabled
end

function Tool.OnTooltipSetItem(tooltip, data)
    if Tool.settings.enabled then
        if tooltip == GameTooltip then
            local guid = UnitGUID("mouseover")
            if guid then 
                local npcId = select(6, strsplit("-", guid))
                if npcId and Utils:IsValidTarget("mouseover") and Addon:HasPockets(npcId) then
                    tooltip:AddLine(L["Typical Purse"]..": "..GetCoinTextureString(Stats:GetAverageCoinByNpcId(npcId)))
                end
            end
        end
    end
end