if select(3, UnitClass("player")) ~= 4 then
    return
end

local addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local stats = addon:GetModule("ArtfulDodger_Stats")
local tool = addon:NewModule("ArtfulDodger_Tooltip", "AceEvent-3.0")

function tool:OnInitialize()
    self.settings = addon.db.settings.tooltip
    self:RegisterMessage("ArtfulDodger_ToggleTooltip", "ToggleTooltip")
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, tool.OnTooltipSetItem)
end

function tool:ToggleTooltip(_, enabled)
    self.settings.enabled = enabled
end

function tool.OnTooltipSetItem(tooltip, data)
    if tool.settings.enabled then
        if tooltip == GameTooltip then
            local guid = UnitGUID("mouseover")
            if guid and UnitCreatureType("mouseover") == "Humanoid" and not UnitIsPlayer("mouseover") and not UnitIsFriend("player", "mouseover") then
                local npcId = select(6, strsplit("-", guid))
                if npcId then 
                    tooltip:AddLine("Typical Purse: "..GetCoinTextureString(stats:GetAverageCoinByNpcId(npcId)))
                end
            end
        end
    end
end