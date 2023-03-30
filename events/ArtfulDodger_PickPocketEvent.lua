if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")

local PickPocketEvent = {}
PickPocketEvent.__index = PickPocketEvent

Addon.PickPocketEvent = PickPocketEvent

function PickPocketEvent:New(eventTime, eventVictim, eventMapId, eventAreaName, eventX, eventY, eventLoot)
	local self = {}
	setmetatable(self, PickPocketEvent)

	self.__index = self
	self.timestamp = eventTime or 0
	self.victim = eventVictim or {}
	self.mapId = eventMapId or ""
    self.areaName = eventAreaName or ""
	self.x = eventX
	self.y = eventY
	self.loot = eventLoot or {}

	return self
end

function PickPocketEvent:ToString()
	return string.format("PickPocketEvent: timestamp=%d, victim=%s, mapId=%s, x=%s, y=%s, areaName=%s, loot=%d", self.timestamp, self.victim.guid, self.mapId, self.areaName, self.x, self.y, #self.loot)
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