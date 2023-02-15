if UnitClass('player') ~= 'Rogue' then
    return
end

local addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")

local JunkboxEvent = {}
addon.JunkboxEvent = JunkboxEvent

function JunkboxEvent:New(eventTime, eventItemId, eventGuid, eventLoot)
	local this = {
		timestamp = eventTime or 0,
		itemId = eventItemId or "",
		guid = eventGuid or "",
		loot = eventLoot or {}
	}
	self.__index = self
	setmetatable(this, self)
	return this
end

function JunkboxEvent:CreateRow()
	return {timestamp=self.timestamp, itemId=self.itemId, guid=self.guid, loot=#self.loot}
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

