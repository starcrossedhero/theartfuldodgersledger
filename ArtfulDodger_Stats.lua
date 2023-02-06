if UnitClass('player') ~= 'Rogue' then
    return
end

local addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local stats = addon:NewModule("ArtfulDodger_Stats", "AceEvent-3.0")
local ppe = addon:GetModule("ArtfulDodger_PickPocketEvent")
local jbe = addon:GetModule("ArtfulDodger_JunkboxEvent")

local defaults = {
	char = {
        history = {
            start = 0,
            duration = 0,
            marks = 0,
            copper = 0
        },
        session = {
            start = 0,
            duration = 0,
            marks = 0,
            copper = 0
        },
        maps = {},
        marks = {},
        junkboxes = {},
    }
}

function stats:OnInitialize()
    self.db = addon.dbo:RegisterNamespace("Stats", defaults).char
    self.db.session = defaults.char.session
	self.db.session.start = time()
	if self.db.history.start <= 0 then
		self.db.history.start = self.db.session.start
	end
end

function stats:OnEnable()
    stats:RegisterMessage("ArtfulDodger_PickPocketComplete", "PickPocketComplete")
    stats:RegisterMessage("ArtfulDodger_JunkboxLooted", "JunkboxLooted")
    stats:RegisterMessage("ArtfulDodger_ResetStats", "ResetStats")
    stats:RegisterMessage("ArtfulDodger_ResetSession", "ResetSession")
end

function stats:PickPocketComplete(message, e)
    local copper = e:GetCopperFromLoot()
    self:AddStats(self.db.history, nil, copper)
    self:AddStats(self.db.session, nil, copper)
    self:AddStats(self.db.marks, e.mark.npcId, copper)
    self:AddStats(self.db.maps, e.mapId, copper)
end

function stats:JunkboxLooted(message, e)
    local copper = e:GetCopperFromLoot()
    self:AddStats(self.db.junkboxes, e.itemId, copper)
end

function stats:ResetStats()
	self.db.session = defaults.char.session
    self.db.history = defaults.char.history
    self.db.maps = defaults.char.maps
    self.db.marks = defaults.char.marks
    self.db.junkboxes = defaults.char.junkboxes

    local time = time()
    self.db.session.start = time
    self.db.history.start = time
end

function stats:ResetSession()
	self.db.session = defaults.char.session
    self.db.maps = defaults.char.maps
    self.db.marks = defaults.char.marks
    self.db.junkboxes = defaults.char.junkboxes
    self.db.session.start = time()
end

function stats:AddStats(statTable, id, copper)
    if id then
        if statTable[id] == nil then
            statTable[id] = {copper = 0, marks = 0}
        end
        statTable[id].copper = statTable[id].copper + copper
        statTable[id].marks = statTable[id].marks + 1
    else
        statTable.copper = statTable.copper + copper
        statTable.marks = statTable.marks + 1
    end
end

function stats:GetMaps()
    local maps = {}
    for id, map in pairs(self.db.maps) do
        local info = C_Map.GetMapInfo(id)
        if info then
            maps[id] = info.name
        end
    end
    
    table.sort(maps, function(a,b) return a < b end)
    
    return maps
end

function stats:GetCopperForMapAndChildrenByMapId(mapId)
    return stats:GetCopperByMapId(mapId) + stats:GetCopperForChildMapsByMapId(mapId)
end

function stats:GetCopperForChildMapsByMapId(mapId)
    local copper = 0
    local children = C_Map.GetMapChildrenInfo(mapId, nil, true)
    for _, childMap in ipairs(children) do
        local childMapStats = self.db.maps[childMap.mapID]
        if childMapStats then
            copper = copper + childMapStats.copper
        end
    end
    return copper
end

function stats:GetStatsForMapAndChildrenByMapId(mapId)
    local copper = stats:GetStatsForMapId(mapId).copper + stats:GetStatsForChildMapsByMapId(mapId).copper
    local marks = stats:GetStatsForMapId(mapId).marks + stats:GetStatsForChildMapsByMapId(mapId).marks
    return {copper = copper, marks = marks}
end

function stats:GetStatsForMapId(mapId)
    local maps = self.db.maps
    if maps[mapId] then
        return {copper = maps[mapId].copper, marks = maps[mapId].marks}
    end
    return {copper = 0, marks = 0}
end

function stats:GetStatsForChildMapsByMapId(mapId)
    local stats = {copper = 0, marks = 0}
    local children = C_Map.GetMapChildrenInfo(mapId, nil, true)
    for _, childMap in ipairs(children) do
        local childMapStats = self.db.maps[childMap.mapID]
        if childMapStats then
            stats.copper = stats.copper + childMapStats.copper
            stats.marks = stats.marks + childMapStats.marks
        end
    end
    return stats
end

function stats:GetMarksForMapAndChildrenByMapId(mapId)
    return stats:GetMarksByMapId(mapId) + stats:GetMarksForChildMapsByMapId(mapId)
end

function stats:GetMarksForChildMapsByMapId(mapId)
    local marks = 0
    local children = C_Map.GetMapChildrenInfo(mapId, nil, true)
    for _, childMap in ipairs(children) do
        local childMapStats = self.db.maps[childMap.mapID]
        if childMapStats then
            marks = marks + childMapStats.marks
        end
    end
    return marks
end

function stats:GetMarksByMapId(mapId)
    local maps = self.db.maps
    if maps[mapId] then
        return maps[mapId].marks
    end
    return 0
end

function stats:GetCopperByMapId(mapId)
    local maps = self.db.maps
    if maps[mapId] then
        return maps[mapId].copper
    end
    return 0
end

function stats:GetCopperPerMarkByMapId(mapId)
	local maps = self.db.maps
    if maps and maps[mapId] then
	   return addon:GetCopperPerMark(maps[mapId].copper, maps[mapId].marks)
    end
    return 0
end

function stats:GetCopperPerMarkType(npcId)
    local markType = self.db.marks[npcId]
    if markType then
        return addon:GetCopperPerMark(markType.copper, markType.marks)
    end
    return 0
end

function stats:GetSessionCopperPerHour()
    return addon:GetCopperPerHour(self.db.session.copper, self.db.session.duration)
end

function stats:GetTotalCopperPerHour()
    return addon:GetCopperPerHour(self.db.history.copper, self.db.history.duration)
end

function stats:GetSessionCopperPerMark()
	return addon:GetCopperPerMark(self.db.session.copper, self.db.session.marks)
end

function stats:GetTotalCopperPerMark()
	return addon:GetCopperPerMark(self.db.history.copper, self.db.history.marks)
end

function stats:GetPrettyPrintTotalLootedString()
	return self:GetPrettyPrintString(date("%b. %d %I:%M %p", self.db.history.start), "historic", "stash", GetCoinTextureString(self.db.history.copper), self.db.history.marks, GetCoinTextureString(self:GetTotalCopperPerMark()))
end

function stats:GetPrettyPrintSessionLootedString()
	return self:GetPrettyPrintString(date("%b. %d %I:%M %p", self.db.session.start), "current", "purse", GetCoinTextureString(self.db.session.copper), self.db.session.marks, GetCoinTextureString(self:GetSessionCopperPerMark()))
end

function stats:GetPrettyPrintString(date, period, store, copper, count, average)
	return string.format("\nSince |cffFFFFFF%s|r,\n\nYour |cff334CFF%s|r pilfering has "..GREEN_FONT_COLOR_CODE.."increased|r your %s by |cffFFFFFF%s|r \nYou've "..RED_FONT_COLOR_CODE.."picked the pockets|r of |cffFFFFFF%d|r mark(s)\nYou've "..RED_FONT_COLOR_CODE.."stolen|r an average of |cffFFFFFF%s|r from each victim", date, period, store, copper, count, average)
end

function stats:GetJunkboxTypes()
    local maps = {}
    for id, map in pairs(self.db.junkboxes) do
        local info = C_Map.GetMapInfo(id)
        if info then
            maps[id] = info.name
        end
    end
    
    table.sort(maps, function(a,b) return a < b end)
    
    return maps
end