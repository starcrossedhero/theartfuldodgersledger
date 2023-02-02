if UnitClass('player') ~= 'Rogue' then
    return
end

local addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local tooltip = addon:NewModule("ArtfulDodger_Tooltip")

local function OnTooltipSetItem(tooltip, data)
    local unitLink = "|cffffff00|Hunit:%s|h[%s]|h|r"
    if tooltip == GameTooltip then
        local guid = UnitGUID("mouseover")
        local name = UnitName("mouseover")
        local type = UnitCreatureType("mouseover")

        if guid and name and type and type == "Humanoid" then
            local npcId = strsplittable("-", guid)[6]
            tooltip:AddLine("Typical Purse: "..GetCoinTextureString(addon:GetCopperPerMarkType(npcId)))
        end
    end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnTooltipSetItem)