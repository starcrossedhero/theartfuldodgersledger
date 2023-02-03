if UnitClass('player') ~= 'Rogue' then
    return
end

local addon = LibStub("AceAddon-3.0"):NewAddon("ArtfulDodger", "AceEvent-3.0")
local PickPocketEvent, PickPocketLoot

local defaults = {
	char = {
		settings = {
			minimap = {
				hide = false,
				minimapPos = 136.23
			},
            map = {
                visible = true
            },
			ui = {
				visible = false,
			},
            session = {
                eventTrackingLimit = 100
            },
            stats = {
                updateInterval = 15
            },
            total = {
                lootTrackingLimit = 10000
            }
		},
		stats = {			
			total = {
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
            marks = {}
		},
        session = {},
		history = {}
	}
}

function addon:OnInitialize()
    PickPocketEvent = addon:GetModule("ArtfulDodger_PickPocketEvent")
    PickPocketLoot = addon:GetModule("ArtfulDodger_PickPocketLoot")
	self.db = LibStub("AceDB-3.0"):New("ArtfulDodgerDB", defaults).char
	self.db.stats.session = defaults.char.stats.session
	self.db.stats.session.start = time()
	if self.db.stats.total.start <= 0 then
		self.db.stats.total.start = self.db.stats.session.start
	end
    self.db.session = {}
    addon:StartStatUpdater()
end

function addon:OnDisable()
	self.db.stats.total.duration = self.db.stats.total.duration + self.db.stats.session.duration
end

function addon:OnEnable()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:RegisterEvent("UI_ERROR_MESSAGE")
    self:RegisterEvent("LOOT_READY")
end

function addon:UI_ERROR_MESSAGE(event, errorType, message)
	if (
		message == ERR_ALREADY_PICKPOCKETED or 
		message == SPELL_FAILED_TARGET_NO_POCKETS or 
		message == SPELL_FAILED_ONLY_STEALTHED or 
		message == SPELL_FAILED_ONLY_SHAPESHIFT) then
        print("Pick pocket attempt failed, removing previous event")
        table.remove(self.db.session, #self.db.session)
    end
end

function addon:LOOT_READY(event, slotNumber)
    local markIndex, guid, isLootable
    local loot = {}
    local numLootItems = GetNumLootItems()
    for slotNumber = 1, numLootItems do
        local guid1, quant1, guid2, quant2 = GetLootSourceInfo(slotNumber)
        markIndex = addon:GetPickPocketMarkIndex(guid1)
        if markIndex then
            local lootIcon, lootName, lootQuantity, currencyID, lootQuality, locked, isQuestItem, questID, isActive = GetLootSlotInfo(slotNumber)
            isLootable, _ = CanLootUnit(guid1)
            if slotNumber > 1 and lootName then
                local lootLink = GetLootSlotLink(slotNumber)
                if lootLink then
                    local newItem = Item:CreateFromItemLink(lootLink)
                    newItem:ContinueOnItemLoad(function()
                        local itemName, itemLink, _, _, _, itemType, itemSubType, _, _, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, _, _, isCraftingReagent = GetItemInfo(lootLink)
                        local itemId = newItem:GetItemID()
                        local item = PickPocketLoot.NewItem(itemName, itemLink, itemIcon, lootQuantity, lootQuality, itemSellPrice)
                        local junkboxPrice = PickPocketLoot.GetJunkboxPrice(itemId)
                        if junkboxPrice then
                            item.price = junkboxPrice   
                        end
                        table.insert(loot, item)		
                    end)
                end
            else
                table.insert(loot, PickPocketLoot.NewCoin(self:GetCopperFromLootName(lootName)))
            end
        end
    end
    if addon:IsMarkEligibleForLoot(markIndex) then
        addon:SaveLootToPickPocketEvent(markIndex, loot)
        addon:SavePickPocketHistory(markIndex, loot)
    end
end

function addon:COMBAT_LOG_EVENT_UNFILTERED(event)
	local timestamp, subEvent, _, _, sourceName, _, _, destGuid, destName, _, _, _, spellName = CombatLogGetCurrentEventInfo()
	if self:IsNewPickPocketEvent(sourceName, subEvent, spellName) then
		if subEvent == "SPELL_CAST_SUCCESS" then
            local destNpcId = strsplittable("-", destGuid)[6]
            local mapId = C_Map.GetBestMapForUnit("player")
            local areaName = GetSubZoneText()
            local event = PickPocketEvent.New(time(), 
                {name = destName, guid = destGuid, npcId = destNpcId, level = UnitLevel("target")}, 
                mapId,
                areaName
            )
            print("Pick Pocket spell cast successful, creating event: ", destGuid, destName, mapId, areaName)
			addon:SavePickPocketEvent(event)
		end
    end
end

function addon:StartStatUpdater()
    local interval = self.db.settings.stats.updateInterval
    local timer = interval
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self, elapsed)
        timer = timer - elapsed
        if timer <= 0 then
            timer = interval
            addon:UpdateStats()
        end
    end)
end

function addon:UpdateStats()
    self.db.stats.session.duration = time() - self.db.stats.session.start
    self.db.stats.session.copper = self:GetTotalCopperFromSession()
    self.db.stats.session.marks = #self.db.session
    self.db.stats.total.copper = self:GetTotalCopperFromHistory()
    self.db.stats.total.marks = #self.db.history
    self.db.stats.maps = self:GetTotalStatsPerMap()
    self.db.stats.marks = self:GetTotalStatsPerMark()
end

function addon:ResetAll()
    self.db.session = defaults.char.session
	self.db.history = defaults.char.history
	self.db.stats = defaults.char.stats
    addon:UpdateStats()
end

function addon:ResetSessionStats()
    self.db.session = defaults.char.session
	self.db.stats.session = defaults.char.stats.session
    self.db.stats.session.start = time()
    self:UpdateStats()
end

function addon:GetPickPocketMarkIndex(guid)
    for event = 1, #self.db.session do
        if guid == self.db.session[event].mark.guid then
            return event
        end
    end
    return nil
end

function addon:SavePickPocketEvent(event)
    if #self.db.session >= self.db.settings.session.eventTrackingLimit then
        table.remove(self.db.session, 0)
    end
    table.insert(self.db.session, event)
end

function addon:IsNewPickPocketEvent(sourceName, subEvent, spellName)
	if sourceName == UnitName("player") and spellName == "Pick Pocket" then
		return true
	end
	return false
end

function addon:GetMaps()
    local maps = {}
    for id, map in pairs(self.db.stats.maps) do
        local info = C_Map.GetMapInfo(id)
        if info then
            maps[id] = info.name
        end
    end
    
    table.sort(maps, function(a,b) return a < b end)
    
    return maps
end

function addon:SaveLootToPickPocketEvent(markIndex, loot)
    local mark = self.db.session[markIndex]
    if mark then
        mark.loot = loot
    end
end

function addon:IsMarkEligibleForLoot(markIndex)
    if self.db.session[markIndex] and #self.db.session[markIndex].loot < 1 then
        return true
    end
    return false
end

function addon:GetTotalCopperFromHistory()
    local copper = 0;
    for event = 1, #self.db.history do
        for i = 1, table.getn(self.db.history[event].loot) do
		  copper = copper + self.db.history[event].loot[i].price
        end
	end
    return copper
end

function addon:GetTotalStatsPerMap()
    local maps = {}
    for event = 1, #self.db.history do
        local mapId = self.db.history[event].mapId

        if mapId then
            local copper = 0
            for i = 1, #self.db.history[event].loot do
                 copper = copper + self.db.history[event].loot[i].price
            end

            if maps[mapId] == nil then
                maps[mapId] = {copper = 0, marks = 0}
            end

            maps[mapId].copper = maps[mapId].copper + copper
            maps[mapId].marks = maps[mapId].marks + 1
        end
    end
    return maps
end

function addon:GetTotalStatsPerMark()
    local marks = {}
    for event = 1, #self.db.history do
        local npcId = self.db.history[event].mark.npcId
        if npcId then
            local copper = 0
            if not marks[npcId] then
                marks[npcId] = {copper = 0, marks = 0}
            end
            for i = 1, #self.db.history[event].loot do
                 copper = copper + self.db.history[event].loot[i].price
            end
            marks[npcId].copper = marks[npcId].copper + copper
            marks[npcId].marks = marks[npcId].marks + 1
        end
    end
    return marks
end

function addon:GetTotalCopperFromSession()
    local copper = 0;
    for event = 1, #self.db.session do
        for i = 1, table.getn(self.db.session[event].loot) do
		  copper = copper + self.db.session[event].loot[i].price
        end
	end
    return copper
end

function addon:SavePickPocketHistory(markIndex)
    print("Saving to history: ", self.db.session[markIndex]:ToString())
    table.insert(self.db.history, self.db.session[markIndex])
    self:SortGlobalLootedHistoryTable()
end

function addon:SortGlobalLootedHistoryTable()
	table.sort(self.db.history, function(a,b) if a and b then return a.timestamp > b.timestamp else return false end end)
end

function addon:GetMarksForMapAndChildrenByMapId(mapId)
    return addon:GetMarksByMapId(mapId) + addon:GetMarksForChildMapsByMapId(mapId)
end

function addon:GetMarksForChildMapsByMapId(mapId)
    local marks = 0
    local children = C_Map.GetMapChildrenInfo(mapId, nil, true)
    for _, childMap in ipairs(children) do
        local childMapStats = self.db.stats.maps[childMap.mapID]
        if childMapStats then
            marks = marks + childMapStats.marks
        end
    end
    return marks
end

function addon:GetMarksByMapId(mapId)
    local maps = self.db.stats.maps
    if maps[mapId] then
        return maps[mapId].marks
    end
    return 0
end

function addon:GetCopperPerMarkByMapId(mapId)
	local maps = self.db.stats.maps
    if maps and maps[mapId] then
	   return addon:GetCopperPerMark(maps[mapId].copper, maps[mapId].marks)
    end
    return 0
end

function addon:GetCopperForMapAndChildrenByMapId(mapId)
    return addon:GetCopperByMapId(mapId) + addon:GetCopperForChildMapsByMapId(mapId)
end

function addon:GetCopperForChildMapsByMapId(mapId)
    local copper = 0
    local children = C_Map.GetMapChildrenInfo(mapId, nil, true)
    for _, childMap in ipairs(children) do
        local childMapStats = self.db.stats.maps[childMap.mapID]
        if childMapStats then
            copper = copper + childMapStats.copper
        end
    end
    return copper
end

function addon:GetCopperByMapId(mapId)
    local maps = self.db.stats.maps
    if maps[mapId] then
        return maps[mapId].copper
    end
    return 0
end

function addon:GetHistoryByMapId(mapId)
	local maps = {}
	for event = 1, #self.db.history do
		if self.db.history[event].mapId == mapId then
			table.insert(maps, self.db.history[event])
		end
	end
	return maps
end

function addon:GetPrettyPrintTotalLootedString()
	return self:GetPrettyPrintString(date("%b. %d %I:%M %p", self.db.stats.total.start), "historic", "stash", GetCoinTextureString(self.db.stats.total.copper), self.db.stats.total.marks, GetCoinTextureString(self:GetTotalCopperPerMark()))
end

function addon:GetPrettyPrintSessionLootedString()
	return self:GetPrettyPrintString(date("%b. %d %I:%M %p", self.db.stats.session.start), "current", "purse", GetCoinTextureString(self.db.stats.session.copper), self.db.stats.session.marks, GetCoinTextureString(self:GetSessionCopperPerMark()))
end

function addon:GetPrettyPrintString(date, period, store, copper, count, average)
	return string.format("\nSince |cffFFFFFF%s|r,\n\nYour |cff334CFF%s|r pilfering has "..GREEN_FONT_COLOR_CODE.."increased|r your %s by |cffFFFFFF%s|r \nYou've "..RED_FONT_COLOR_CODE.."picked the pockets|r of |cffFFFFFF%d|r mark(s)\nYou've "..RED_FONT_COLOR_CODE.."stolen|r an average of |cffFFFFFF%s|r from each victim", date, period, store, copper, count, average)
end

function addon:GetCopperPerMark(copper, count)
	if copper and count and copper > 0 and count > 0 then
        local avg = self:Round((copper / count))
		return avg
	end
	return 0
end

function addon:GetCopperPerMarkType(npcId)
    local markType = self.db.stats.marks[npcId]
    if markType then
        return self:GetCopperPerMark(markType.copper, markType.marks)
    end
    return 0
end

function addon:GetSessionCopperPerMark()
	return self:GetCopperPerMark(self.db.stats.session.copper, self.db.stats.session.marks)
end

function addon:GetTotalCopperPerMark()
	return self:GetCopperPerMark(self.db.stats.total.copper, self.db.stats.total.marks)
end

function addon:GetCopperPerHour(copper, seconds)
	if copper > 0 and seconds > 0 then
		return math.floor(((copper / seconds) * 3600))
	end
	return 0
end

function addon:GetSessionCopperPerHour()
    return self:GetCopperPerHour(self.db.stats.session.copper, self.db.stats.session.duration)
end

function addon:GetTotalCopperPerHour()
    return self:GetCopperPerHour(self.db.stats.total.copper, self.db.stats.total.duration)
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