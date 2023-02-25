if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local Stats = Addon:NewModule("ArtfulDodger_Stats", "AceEvent-3.0")
local Events = Addon.Events
local L = Addon.Localizations

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
        junkboxes = {},
        maps = {}
    }
}

Stats.DefaultSession = function()
    return Addon.ShallowCopy(defaults.char.session)
end

Stats.DefaultHistory = function()
    return Addon.ShallowCopy(defaults.char.history)
end

function Stats:OnInitialize()
    self.dbo = Addon.dbo:RegisterNamespace("Stats", defaults)
    self.db = self.dbo.char
    self.db.session = self.DefaultSession()
	self.db.session.start = time()
	if self.db.history.start <= 0 then
		self.db.history.start = self.db.session.start
	end
end

function Stats:OnEnable()
    self:RegisterMessage(Events.Loot.PickPocket, "PickPocketComplete")
    self:RegisterMessage(Events.Loot.Junkbox, "JunkboxLooted")
    self:RegisterMessage(Events.History.Reset, "Reset")
    self:RegisterMessage(Events.Session.Reset, "ResetSession")
end

function Stats:PickPocketComplete(message, e)
    local copper = e:GetCopperFromLoot()
    self:AddStats(self.db.history, copper)
    self:AddStats(self.db.session, copper)
    self:AddStats(self.db.maps, copper, e.mapId, e.victim.npcId, e.victim.name)
end

function Stats:JunkboxLooted(message, e)
    local copper = e:GetCopperFromLoot()
    self:AddStats(self.db.junkboxes, copper, e.itemId)
end

function Stats:Reset()
	self.db.session = self.DefaultSession()
    self.db.history = self.DefaultHistory()
    self.db.maps = {}
    self.db.junkboxes = {}

    local time = time()
    self.db.session.start = time
    self.db.history.start = time
end

function Stats:ResetSession()
	self.db.session = self.DefaultSession()
    self.db.session.start = time()
end

function Stats:AddStats(statTable, copper, id, npcId, npcName)
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

function Stats:GetMaps()
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

function Stats:GetVictims(mapId)
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

function Stats:GetAverageCoinByNpcId(npcId)
    for _, map in pairs(self.db.maps) do
        local victim = map.victims[npcId]
        if victim then 
            return Addon:GetCopperPerVictim(victim.copper, victim.thefts)
        end
    end
    return Addon:GetCopperPerVictim(0, 0)
end

function Stats:GetStatsByMapIdAndNpcId(mapId, npcId)
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

function Stats:GetStatsForMapId(mapId, includeChildren)
    local maps = self.db.maps
    local stats = {copper = 0, thefts = 0}
    if maps[mapId] then
        stats.copper = stats.copper + maps[mapId].copper
        stats.thefts = stats.thefts + maps[mapId].thefts
    end
    if includeChildren then
        local childStats = Stats:GetStatsForChildMapsByMapId(mapId)
        stats.copper = stats.copper + childStats.copper
        stats.thefts = stats.thefts + childStats.thefts
    end
    return stats
end

function Stats:GetStatsForChildMapsByMapId(mapId)
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

function Stats:GetStatsByJunkboxId(junkboxId)
    local stats = {copper = 0, thefts = 0}
    local junkbox = self.db.junkboxes[junkboxId]
    if junkbox then
        stats.copper = stats.copper + junkbox.copper
        stats.thefts = stats.thefts + junkbox.thefts
    end
    return stats
end

function Stats:GetStatsForJunkboxes()
    local stats = {copper = 0, thefts = 0}
    for _, junkbox in pairs(self.db.junkboxes) do
        stats.copper = stats.copper + junkbox.copper
        stats.thefts = stats.thefts + junkbox.thefts
    end
    return stats
end

function Stats:GetSessionCopperPerHour()
    return Addon:GetCopperPerHour(self.db.session.copper, self.db.session.duration)
end

function Stats:GetTotalCopperPerHour()
    return Addon:GetCopperPerHour(self.db.history.copper, self.db.history.duration)
end

function Stats:GetSessionCopperPerVictim()
	return Addon:GetCopperPerVictim(self.db.session.copper, self.db.session.thefts)
end

function Stats:GetTotalCopperPerVictim()
	return Addon:GetCopperPerVictim(self.db.history.copper, self.db.history.thefts)
end

function Stats:GetPrettyPrintTotalLootedString()
	return self:PrettyPrint(date("%Y/%m/%d %H:%M:%S", self.db.history.start), GetCoinTextureString(self.db.history.copper), self.db.history.thefts, GetCoinTextureString(self:GetTotalCopperPerVictim()))
end

function Stats:GetPrettyPrintSessionLootedString()
	return self:GetPrettyPrintString(date("%Y/%m/%d %H:%M:%S", self.db.session.start), L["recent"], L["purse"], GetCoinTextureString(self.db.session.copper), self.db.session.thefts, GetCoinTextureString(self:GetSessionCopperPerVictim()))
end

function Stats:GetPrettyPrintString(date, period, store, copper, count, average)
	return string.format("\nSince |cffFFFFFF%s|r\n\nYour |cff334CFF%s|r pilfering has "..GREEN_FONT_COLOR_CODE.."increased|r your %s by |cffFFFFFF%s|r \nYou've "..RED_FONT_COLOR_CODE.."picked the pockets|r of |cffFFFFFF%d|r victim(s)\nYou've "..RED_FONT_COLOR_CODE.."stolen|r an average of |cffFFFFFF%s|r from each victim", date, period, store, copper, count, average)
end

function Stats:PrettyPrint(date, copper, count, average)
    local date = string.format(L["Since"]..self:SubColors(" ^WHITE%s|r"), date)
    local count = string.format(self:SubColors(L["You've ^REDpicked pockets|r of ^WHITE%d|r victim(s)"]), count)
    local total = string.format(self:SubColors(L["You've ^REDpilfered|r a total of ^WHITE%s|r in ill-gotten ^GREENgains|r"]), copper)
    local average = string.format(self:SubColors(L["You've ^REDstolen|r an average of ^WHITE%s|r per victim"]), average)
    return string.format("\n%s\n\n%s\n%s\n%s", date, count, total, average)
end

function Stats:SubColors(string)
    return string:gsub("%^RED", RED_FONT_COLOR_CODE):gsub("%^GREEN", GREEN_FONT_COLOR_CODE):gsub("%^BLUE", BLUE_FONT_COLOR_CODE):gsub("%^WHITE", WHITE_FONT_COLOR_CODE):gsub("%^GOLD", GOLD_FONT_COLOR_CODE)
end

--string:gsub("^R", RED_FONT_COLOR)
--string:gsub("^G", GREEN_FONT_COLOR)
--string:gsub("^B", BLUE_FONT_COLOR)
--string:gsub("^W", WHITE_FONT_COLOR)
--string:gsub("^E", "|r")

--Since ^W%d|r your ^Rhistoric|r pilfering has ^Gincreased|r your stash by ^W%d|r
--Desde ^W%d|r tu robo ^Rhistorico|r ha ^Gaumentado|r tu riqueza en ^W%d|r

--You've ^Rpicked pockets|r of ^W%d|r victim(s)
--Has ^Rrobado los bolsillos|r de ^W%d|r víctima(s)

--You've ^Rstolen|r an average of ^W%s|r from each victim"
--Le has ^Rrobado|r un promedio de ^W%d|r a cada víctima"