if UnitClass('player') ~= 'Rogue' then
    return
end

local addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local ppe = addon:NewModule("ArtfulDodger_PickPocketEvent")

PickPocketEvent = {}
function ppe:New(eventTime, eventMark, eventMapId, eventAreaName, eventLoot)
	local this = {
		timestamp = eventTime or 0,
		mark = eventMark or {},
		mapId = eventMapId or "",
        areaName = eventAreaName or "",
		loot = eventLoot or {}
	}
	self.__index = self
	setmetatable(this, self)
	return this
end

function ppe:CreateRow()
	return {timestamp=self.timestamp, mark=self.mark, mapId=self.mapId, areaName=self.areaName, loot=self.loot}
end

function ppe:ToString()
	return string.format("PickPocketEvent: timestamp=%d, mark=%s, mapId=%s, areaName=%s, loot=%d", self.timestamp, self.mark.guid, self.mapId, self.areaName, #self.loot)
end

function ppe:GetCopperFromLoot()
	local copper = 0
	for i = 1, #self.loot do
        local item = self.loot[i]
        if item and item.price then
            copper = copper + self.loot[i].price
        end
    end
	return copper
end

