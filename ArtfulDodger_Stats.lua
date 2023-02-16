if UnitClass('player') ~= 'Rogue' then
    return
end

local addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local stats = addon:NewModule("ArtfulDodger_Stats", "AceEvent-3.0")
local ppe = addon.PickPocketEvent
local jbe = addon.JunkboxEvent

local defaults = {
	char = {
        history = {
            start = 0,
            duration = 0,
            thefts = 0,
            copper = 0
        },
        session = {
            start = 0,
            duration = 0,
            thefts = 0,
            copper = 0
        },
        maps = {},
        junkboxes = {}
    }
}

function stats:OnInitialize()
    self.db = addon.dbo:GetNamespace("Stats", true)
    if self.db == nil then
        self.db = addon.dbo:RegisterNamespace("Stats", defaults).char
    end
    self.db.session = defaults.char.session
	self.db.session.start = time()
	if self.db.history.start <= 0 then
		self.db.history.start = self.db.session.start
	end
end

function stats:OnEnable()
    stats:RegisterMessage("ArtfulDodger_PickPocketComplete", "PickPocketComplete")
    stats:RegisterMessage("ArtfulDodger_JunkboxLooted", "JunkboxLooted")
    stats:RegisterMessage("ArtfulDodger_ResetHistory", "ResetStats")
    stats:RegisterMessage("ArtfulDodger_ResetSession", "ResetSession")
end

function stats:PickPocketComplete(message, e)
    local copper = e:GetCopperFromLoot()
    self:AddStats(self.db.history, copper)
    self:AddStats(self.db.session, copper)
    self:AddStats(self.db.maps, copper, e.mapId, e.victim.npcId, e.victim.name)
end

function stats:JunkboxLooted(message, e)
    local copper = e:GetCopperFromLoot()
    self:AddStats(self.db.junkboxes, copper, e.itemId)
end

function stats:ResetStats()
	self.db.session = defaults.char.session
    self.db.history = defaults.char.history
    self.db.maps = defaults.char.maps
    self.db.junkboxes = defaults.char.junkboxes

    local time = time()
    self.db.session.start = time
    self.db.history.start = time
end

function stats:ResetSession()
	self.db.session = defaults.char.session
    self.db.session.start = time()
end

function stats:AddStats(statTable, copper, id, npcId, npcName)
    if id then
        if statTable[id] == nil then
            statTable[id] = {copper = 0, thefts = 0, victims = {}}
        end
        statTable[id].copper = statTable[id].copper + copper
        statTable[id].thefts = statTable[id].thefts + 1
        if npcId and npcName then
            if statTable[id].victims[npcId] == nil then
                statTable[id].victims[npcId] = {name = "", copper = 0, thefts = 0}
            end
            statTable[id].victims[npcId].name = npcName
            statTable[id].victims[npcId].copper = statTable[id].victims[npcId].copper + copper
            statTable[id].victims[npcId].thefts = statTable[id].victims[npcId].thefts + 1
        end
    else
        statTable.copper = statTable.copper + copper
        statTable.thefts = statTable.thefts + 1
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

function stats:GetVictims(mapId)
    local victims = {}
    local map = self.db.maps[mapId]

    if map then 
        for npcId, victim in pairs(map.victims) do
            victims[npcId] = victim.name
        end
    end

    table.sort(victims, function(a,b) return a < b end)

    return victims
end

function stats:GetAverageCoinByNpcId(npcId)
    for _, map in pairs(self.db.maps) do
        local victim = map.victims[npcId]
        if victim then 
            return addon:GetCopperPerVictim(victim.copper, victim.thefts)
        end
    end
    return addon:GetCopperPerVictim(0, 0)
end

function stats:GetStatsByMapIdAndNpcId(mapId, npcId)
    local stats = {copper = 0, thefts = 0}
    local map = self.db.maps[mapId]
    if map then
        local npc = map.victims[npcId]
        if npc then
            stats.copper = stats.copper + npc.copper
            stats.thefts = stats.thefts + npc.thefts
        end
    end
    return stats
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
    local thefts = stats:GetStatsForMapId(mapId).thefts + stats:GetStatsForChildMapsByMapId(mapId).thefts
    return {copper = copper, thefts = thefts}
end

function stats:GetStatsForMapId(mapId)
    local maps = self.db.maps
    if maps[mapId] then
        return {copper = maps[mapId].copper, thefts = maps[mapId].thefts}
    end
    return {copper = 0, thefts = 0}
end

function stats:GetStatsForChildMapsByMapId(mapId)
    local stats = {copper = 0, thefts = 0}
    local children = C_Map.GetMapChildrenInfo(mapId, nil, true)
    for _, childMap in ipairs(children) do
        local childMapStats = self.db.maps[childMap.mapID]
        if childMapStats then
            stats.copper = stats.copper + childMapStats.copper
            stats.thefts = stats.thefts + childMapStats.thefts
        end
    end
    return stats
end

function stats:GetTheftsForMapAndChildrenByMapId(mapId)
    return stats:GetTheftsByMapId(mapId) + stats:GetTheftsForChildMapsByMapId(mapId)
end

function stats:GetTheftsForChildMapsByMapId(mapId)
    local thefts = 0
    local children = C_Map.GetMapChildrenInfo(mapId, nil, true)
    for _, childMap in ipairs(children) do
        local childMapStats = self.db.maps[childMap.mapID]
        if childMapStats then
            thefts = thefts + childMapStats.thefts
        end
    end
    return thefts
end

function stats:GetTheftsByMapId(mapId)
    local maps = self.db.maps
    if maps[mapId] then
        return maps[mapId].thefts
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

function stats:GetCopperPerVictimByMapId(mapId)
	local maps = self.db.maps
    if maps and maps[mapId] then
	   return addon:GetCopperPerVictim(maps[mapId].copper, maps[mapId].thefts)
    end
    return 0
end

function stats:GetCopperPerVictimType(npcId)
    local victimType = self.db.map[npcId]
    if victimType then
        return addon:GetCopperPerVictim(victimType.copper, victimType.thefts)
    end
    return 0
end

function stats:GetStatsByJunkboxId(junkboxId)
    local stats = {copper = 0, thefts = 0}
    local junkbox = self.db.junkboxes[junkboxId]
    if junkbox then
        stats.copper = stats.copper + junkbox.copper
        stats.thefts = stats.thefts + junkbox.thefts
    end
    return stats
end

function stats:GetStatsForJunkboxes()
    local stats = {copper = 0, thefts = 0}
    for _, junkbox in pairs(self.db.junkboxes) do
        stats.copper = stats.copper + junkbox.copper
        stats.thefts = stats.thefts + junkbox.thefts
    end
    return stats
end

function stats:GetSessionCopperPerHour()
    return addon:GetCopperPerHour(self.db.session.copper, self.db.session.duration)
end

function stats:GetTotalCopperPerHour()
    return addon:GetCopperPerHour(self.db.history.copper, self.db.history.duration)
end

function stats:GetSessionCopperPerVictim()
	return addon:GetCopperPerVictim(self.db.session.copper, self.db.session.thefts)
end

function stats:GetTotalCopperPerVictim()
	return addon:GetCopperPerVictim(self.db.history.copper, self.db.history.thefts)
end

function stats:GetPrettyPrintTotalLootedString()
	return self:GetPrettyPrintString(date("%Y/%m/%d %H:%M:%S", self.db.history.start), "historic", "stash", GetCoinTextureString(self.db.history.copper), self.db.history.thefts, GetCoinTextureString(self:GetTotalCopperPerVictim()))
end

function stats:GetPrettyPrintSessionLootedString()
	return self:GetPrettyPrintString(date("%Y/%m/%d %H:%M:%S", self.db.session.start), "current", "purse", GetCoinTextureString(self.db.session.copper), self.db.session.thefts, GetCoinTextureString(self:GetSessionCopperPerVictim()))
end

function stats:GetPrettyPrintString(date, period, store, copper, count, average)
	return string.format("\nSince |cffFFFFFF%s|r,\n\nYour |cff334CFF%s|r pilfering has "..GREEN_FONT_COLOR_CODE.."increased|r your %s by |cffFFFFFF%s|r \nYou've "..RED_FONT_COLOR_CODE.."picked the pockets|r of |cffFFFFFF%d|r victim(s)\nYou've "..RED_FONT_COLOR_CODE.."stolen|r an average of |cffFFFFFF%s|r from each victim", date, period, store, copper, count, average)
end