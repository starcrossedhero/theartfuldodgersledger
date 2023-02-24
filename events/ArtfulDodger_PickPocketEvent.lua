if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")

local PickPocketEvent = {}
Addon.PickPocketEvent = PickPocketEvent 

function PickPocketEvent:New(eventTime, eventVictim, eventMapId, eventAreaName, eventLoot)
	local this = {
		timestamp = eventTime or 0,
		victim = eventVictim or {},
		mapId = eventMapId or "",
        areaName = eventAreaName or "",
		loot = eventLoot or {}
	}
	self.__index = self
	setmetatable(this, self)
	return this
end

function PickPocketEvent:CreateRow()
	return {timestamp=self.timestamp, victim=self.victim, mapId=self.mapId, areaName=self.areaName, loot=self.loot}
end

function PickPocketEvent:ToString()
	return string.format("PickPocketEvent: timestamp=%d, victim=%s, mapId=%s, areaName=%s, loot=%d", self.timestamp, self.victim.guid, self.mapId, self.areaName, #self.loot)
end

function PickPocketEvent:GetCopperFromLoot()
	local copper = 0
	for i = 1, #self.loot do
        local item = self.loot[i]
        if item and item.price then
            copper = copper + self.loot[i].price
        end
    end
	return copper
end

