if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")

local JunkboxEvent = {}
JunkboxEvent.__index = JunkboxEvent

Addon.JunkboxEvent = JunkboxEvent

function JunkboxEvent:New(eventTime, eventItemId, eventGuid, eventLoot)
	local self = {}
	setmetatable(self, JunkboxEvent)

	self.__index = self
	self.timestamp = eventTime or 0
	self.itemId = eventItemId or ""
	self.guid = eventGuid or ""
	self.loot = eventLoot or {}
	
	return self
end

function JunkboxEvent:ToString()
	return string.format("JunkboxEvent: timestamp=%d, itemId=%d, guid=%s, loot=%d", self.timestamp, self.itemId, self.guid, #self.loot)
end

function JunkboxEvent:GetCopperFromLoot()
	local copper = 0
	for i = 1, #self.loot do
        local item = self.loot[i]
        if item and item.price then
            copper = copper + self.loot[i].price
        end
    end
	return copper
end

