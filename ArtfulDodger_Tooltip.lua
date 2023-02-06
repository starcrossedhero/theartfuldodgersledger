if UnitClass('player') ~= 'Rogue' then
    return
end

local addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local stats = addon:GetModule("ArtfulDodger_Stats")
local tooltip = addon:NewModule("ArtfulDodger_Tooltip")

local function OnTooltipSetItem(tooltip, data)
    local unitLink = "|cffffff00|Hunit:%s|h[%s]|h|r"
    if tooltip == GameTooltip then
        local guid = UnitGUID("mouseover")
        if guid and UnitCreatureType("mouseover") == "Humanoid" and not UnitIsPlayer("mouseover") and not UnitIsFriend("player", "mouseover") then
            local npcId = strsplittable("-", guid)[6]
            tooltip:AddLine("Typical Purse: "..GetCoinTextureString(stats:GetCopperPerMarkType(npcId)))
        end
    end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnTooltipSetItem)