if UnitClass('player') ~= 'Rogue' then
    return
end

local addon = LibStub("AceAddon-3.0"):NewAddon("ArtfulDodger", "AceEvent-3.0")
local PickPocketEvent, JunkboxEvent, Loot

local defaults = {
	char = {
		settings = {
			minimap = {
				hide = false,
				minimapPos = 136.23
			},
            map = {

            },
            history = {
                eventLimit = 10000
            },
            unitFrame = {
                enabled = true,
                lootRespawnSeconds = 420,
                updateFrequencySeconds = 5
            },
            tooltip = {
                enabled = true
            }
		},
		history = {
            pickpocket = {},
            junkboxes = {}
        }
	}
}

function addon:OnInitialize()
    PickPocketEvent = addon:GetModule("ArtfulDodger_PickPocketEvent")
    JunkboxEvent = addon:GetModule("ArtfulDodger_JunkboxEvent")
    Loot = addon:GetModule("ArtfulDodger_Loot")

	self.dbo = LibStub("AceDB-3.0"):New("ArtfulDodgerDB", defaults)
    self.db = self.dbo.char
end

function addon:OnEnable()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:RegisterEvent("UI_ERROR_MESSAGE")
    self:RegisterEvent("LOOT_READY")
    self:RegisterMessage("ArtfulDodger_ResetHistory", "ResetHistory")
end

function addon:ResetHistory()
	self.db.history.pickpocket = defaults.char.history.pickpocket
    self.db.history.junkboxes = defaults.char.history.junkboxes
end

function addon:UI_ERROR_MESSAGE(event, errorType, message)
	if (
		message == ERR_ALREADY_PICKPOCKETED or 
		message == SPELL_FAILED_TARGET_NO_POCKETS or 
		message == SPELL_FAILED_ONLY_STEALTHED or 
		message == SPELL_FAILED_ONLY_SHAPESHIFT) then
        --print("Pick pocket attempt failed, removing previous event")
        table.remove(self.db.history.pickpocket, #self.db.history.pickpocket)
    end
end

function addon:LOOT_READY(event, slotNumber)
    local pickPocketEvent, junkboxItemId, sourceGuid
    local loot = {}
    for slot = 1, GetNumLootItems() do
        local sources = {GetLootSourceInfo(slot)}
        for source = 1, #sources, 2 do
            sourceGuid = sources[source]
            junkboxItem =  Loot.GetJunkboxFromGuid(sourceGuid)
            pickPocketEvent = addon:GetLatestPickPocketByGuid(sourceGuid)
            if pickPocketEvent or junkboxItem then
                local lootIcon, lootName, lootQuantity, _, _, _, _, _, _ = GetLootSlotInfo(slot)
                if slot > 1 and lootName then
                    local lootLink = GetLootSlotLink(slot)
                    if lootLink then
                        local item = Item:CreateFromItemLink(lootLink)
                        item:ContinueOnItemLoad(function()
                            local itemSellPrice = select(11, GetItemInfo(lootLink))
                            local itemId = item:GetItemID()
                            table.insert(loot, Loot:NewItem(sourceGuid, itemId, lootName, lootLink, lootIcon, lootQuantity, itemSellPrice))
                        end)
                    end
                else
                    table.insert(loot, Loot:NewCoin(sourceGuid, self:GetCopperFromLootName(lootName)))
                end
            end
        end
    end
    
    if junkboxItem then
        addon:SaveJunkboxLoot(time(), sourceGuid, junkboxItem, loot)
    elseif pickPocketEvent then
        addon:SaveLootToPickPocketEvent(pickPocketEvent, loot)
    end
end

function addon:SaveJunkboxLoot(timestamp, sourceGuid, junkboxItem, loot)
    local junkbox = JunkboxEvent:New(timestamp, junkboxItem.itemId, sourceGuid, loot)
    if addon:IsJunkboxEligibleForLoot(junkbox) then
        table.insert(self.db.history.junkboxes, junkbox)
        addon:SendMessage("ArtfulDodger_JunkboxLooted", junkbox)
    end
end

function addon:IsJunkboxEligibleForLoot(junkboxEvent)
    local junkboxes = self.db.history.junkboxes
    for i = 1, #junkboxes do
        local junkbox = junkboxes[i]
        if junkbox.itemId == junkboxEvent.itemId and junkbox.guid == junkboxEvent.guid then
            if #junkbox.loot < 1 then
                return true
            else
                return false
            end
        end
    end
    return true
end

function addon:COMBAT_LOG_EVENT_UNFILTERED(event)
	local timestamp, subEvent, _, sourceGuid, sourceName, _, _, destGuid, destName, _, _, _, spellName = CombatLogGetCurrentEventInfo()
	if self:IsNewPickPocketEvent(sourceName, subEvent, spellName) then
		if subEvent == "SPELL_CAST_SUCCESS" then
            local destNpcId = strsplittable("-", destGuid)[6]
            local mapId = C_Map.GetBestMapForUnit("player")
            local areaName = GetSubZoneText()
            local event = PickPocketEvent:New(time(), 
                {name = destName, guid = destGuid, npcId = destNpcId, level = UnitLevel("target")}, 
                mapId,
                areaName
            )
            --print("Pick Pocket spell cast successful, creating event: ", event:ToString())
			addon:SavePickPocketEvent(event)
		end
    end
    --if spellName == "Pick Lock" then
    --    print(timestamp, subEvent, sourceGuid, sourceName, destGuid, destName, spellName)
    --end
end

function addon:GetPickPocketVictimIndex(guid)
    for event = #self.db.history.pickpocket, 1, -1 do
        if guid == self.db.history.pickpocket[event].victim.guid then
            return event
        end
    end
    return nil
end

function addon:GetLatestPickPocketByGuid(guid)
    for event = #self.db.history.pickpocket, 1, -1 do
        if guid == self.db.history.pickpocket[event].victim.guid then
            return self.db.history.pickpocket[event]
        end
    end
    return nil
end

function addon:SavePickPocketEvent(event)
    if #self.db.history.pickpocket >= self.db.settings.history.eventLimit then
        --print("Event tracking limit reached. Removing: ", event:ToString())
        table.remove(self.db.history.pickpocket)
    end
    --print("Inserting pick pocket event: ", event:ToString())
    table.insert(self.db.history.pickpocket, event)
    --self:SortGlobalLootedHistoryTable()
end

function addon:IsNewPickPocketEvent(sourceName, subEvent, spellName)
	if sourceName == UnitName("player") and spellName == "Pick Pocket" then
		return true
	end
	return false
end

function addon:SaveLootToPickPocketEvent(event, loot)
    if #event.loot < 1 then
        event.loot = loot
        --print("Saving loot to history: ", event:ToString())
        addon:SendMessage("ArtfulDodger_PickPocketComplete", event)
    end
end

function addon:IsVictimEligibleForLoot(victimIndex)
    if self.db.history.pickpocket[victimIndex] and #self.db.history.pickpocket[victimIndex].loot < 1 then
        return true
    end
    return false
end

function addon:GetTotalCopperFromHistory()
    local copper = 0;
    for event = 1, #self.db.history.pickpocket do
        for i = 1, table.getn(self.db.history.pickpocket[event].loot) do
		  copper = copper + self.db.history.pickpocket[event].loot[i].price
        end
	end
    return copper
end

function addon:GetTotalStatsPerMap()
    local maps = {}
    for event = 1, #self.db.history.pickpocket do
        local mapId = self.db.history.pickpocket[event].mapId

        if mapId then
            local copper = 0
            for i = 1, #self.db.history.pickpocket[event].loot do
                 copper = copper + self.db.history.pickpocket[event].loot[i].price
            end

            if maps[mapId] == nil then
                maps[mapId] = {copper = 0, victims = 0}
            end

            maps[mapId].copper = maps[mapId].copper + copper
            maps[mapId].victims = maps[mapId].victims + 1
        end
    end
    return maps
end

function addon:GetTotalStatsPerVictim()
    local victims = {}
    for event = 1, #self.db.history.pickpocket do
        local npcId = self.db.history.pickpocket[event].victim.npcId
        if npcId then
            local copper = 0
            if not victims[npcId] then
                victims[npcId] = {copper = 0, victims = 0}
            end
            for i = 1, #self.db.history.pickpocket[event].loot do
                 copper = copper + self.db.history.pickpocket[event].loot[i].price
            end
            victims[npcId].copper = victims[npcId].copper + copper
            victims[npcId].victims = victims[npcId].victims + 1
        end
    end
    return victims
end

function addon:GetTotalCopperFromSession()
    local copper = 0;
    for event = 1, #self.db.history.pickpocket do
        for i = 1, table.getn(self.db.history.pickpocket[event].loot) do
		  copper = copper + self.db.history.pickpocket[event].loot[i].price
        end
	end
    return copper
end

function addon:SortGlobalLootedHistoryTable()
	table.sort(self.db.history.pickpocket, function(a,b) if a and b then return a.timestamp > b.timestamp else return false end end)
end

function addon:GetHistoryByMapId(mapId)
	local maps = {}
	for event = 1, #self.db.history.pickpocket, 1 do
		if self.db.history.pickpocket[event].mapId == mapId then
			table.insert(maps, self.db.history.pickpocket[event])
		end
	end
	return maps
end

function addon:GetHistoryByMapIdAndNpcId(mapId, npcId)
	local history = {}
	for event = #self.db.history.pickpocket, 1, -1 do
		if self.db.history.pickpocket[event].mapId == mapId and self.db.history.pickpocket[event].victim.npcId == npcId then
			table.insert(history, self.db.history.pickpocket[event])
		end
	end
	return history
end

function addon:GetVictimNamesFromTable(historyTable)
    local victims = {}
    for i = 1, #historyTable do
        local victim = historyTable[i].victim
        if victims[victim.npcId] == nil then
            victims[victim.npcId] = victim.name
        end
    end
    return victims
end

function addon:GetHistoryByNpcId(npcId)
	local victims = {}
	for event = #self.db.history.pickpocket, 1, -1 do
		if self.db.history.pickpocket[event].victim.npcId == npcId then
			table.insert(victims, self.db.history.pickpocket[event])
		end
	end
	return victims
end

function addon:GetHistoryByJunkboxId(junkboxId)
	local victims = {}
	for event = 1, #self.db.history.junkboxes, 1 do
		if self.db.history.junkboxes[event].itemId == junkboxId then
			table.insert(victims, self.db.history.junkboxes[event])
		end
	end
	return victims
end

function addon:GetHistoryFromTableByNpcId(historyTable, npcId)
	local victims = {}
	for event = 1, #historyTable, 1 do
		if historyTable[event].victim.npcId == npcId then
			table.insert(victims, historyTable[event])
		end
	end
	return victims
end

function addon:GetHistoryByNpcName(name)
	local victims = {}
	for event = #self.db.history.pickpocket, 1, -1 do
		if self.db.history.pickpocket[event].victim.name == name then
			table.insert(victims, self.db.history.pickpocket[event])
		end
	end
	return victims
end

function addon:GetNpcNameByNpcId(npcId)
	for event = #self.db.history.pickpocket, 1, -1 do
        local id = self.db.history.pickpocket[event].victim.npcId
		if id == npcId then
			return self.db.history.pickpocket[event].victim.name
		end
	end
	return nil
end

function addon:GetCopperPerVictim(copper, count)
	if copper and count and copper > 0 and count > 0 then
        local avg = self:Round((copper / count))
		return avg
	end
	return 0
end

function addon:GetCopperPerHour(copper, seconds)
	if copper > 0 and seconds > 0 then
		return math.floor(((copper / seconds) * 3600))
	end
	return 0
end

function addon:Round(x)
	return x + 0.5 - (x + 0.5) % 1
end

function addon:GetCopperFromLootName(lootName)
	return self:TotalCopper(self:GetCurrencyValues(lootName)) or 0
end

function addon:GetCurrencyValues(money)
	local gold = money:match(GOLD_AMOUNT:gsub("%%d", "%(%%d+%)")) or 0
	local silver = 	money:match(SILVER_AMOUNT:gsub("%%d", "%(%%d+%)")) or 0
	local copper = money:match(COPPER_AMOUNT:gsub("%%d", "%(%%d+%)")) or 0

	return {gold=gold, silver=silver, copper=copper}
end

function addon:TotalCopper(currency)
	return (currency.gold * 1000) + (currency.silver * 100) + currency.copper
end