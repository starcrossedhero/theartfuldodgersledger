local addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local event = addon:NewModule("ArtfulDodger_PickPocketEvent")

PickPocketEvent = {}
PickPocketEvent.__index = PickPocketEvent
function event.New(eventTime, eventMark, eventMapId, eventAreaName, eventLoot)
	local this = {
		timestamp = eventTime or 0,
		mark = eventMark or {},
		mapId = eventMapId or "",
        areaName = eventAreaName or "",
		loot = eventLoot or {}
	}
	setmetatable(this, self)
	return this
end

function event.CreateRow()
	return {timestamp=self.timestamp, mark=self.mark, mapId=self.mapId, areaName=self.areaName, loot=self.loot}
end

function event.ToString()
	return string.format("PickPocketEvent: timestamp=%d, mark=%s, mapId=%s, areaName=%s, loot=%d", self.timestamp, self.mark.guid, self.mapId, self.areaName, #self.loot)
end

