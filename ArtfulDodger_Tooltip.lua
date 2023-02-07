if UnitClass('player') ~= 'Rogue' then
    return
end

local addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local stats = addon:GetModule("ArtfulDodger_Stats")
local tooltip = addon:NewModule("ArtfulDodger_Tooltip")

local function OnTooltipSetItem(tooltip, data)
    if tooltip == GameTooltip then
        local guid = UnitGUID("mouseover")
        if guid and UnitCreatureType("mouseover") == "Humanoid" and not UnitIsPlayer("mouseover") and not UnitIsFriend("player", "mouseover") then
            local npcId = select(6, strsplit("-", guid))
            if npcId then 
                tooltip:AddLine("Typical Purse: "..GetCoinTextureString(stats:GetCopperPerMarkType(npcId)))
            end
        end
    end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnTooltipSetItem)