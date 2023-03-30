if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):NewAddon("ArtfulDodger", "AceEvent-3.0")
local hbd  = LibStub("HereBeDragons-2.0")

local defaults = {
	char = {
		settings = {
            lootRespawnSeconds = 480,
			minimap = {
				hide = false,
				minimapPos = 136.23,
                updateFrequencySeconds = 1,
                idleThresholdSeconds = 30
			},
            map = {
                enabled = true,
                updateFrequencySeconds = 0.3
            },
            pins = {
                enabled = false
            },
            history = {
                eventLimit = 100000
            },
            unitFrame = {
                enabled = true
            },
            tooltip = {
                enabled = true
            },
            opener = {
                enabled = true,
                position = {
                    top = 0,
                    left = 0
                }
            }
		},
		history = {
            pickpocket = {},
            junkboxes = {}
        },
        stats = {},
        exclusions = {}
	}
}

-- for tracking attempts, even ones that failed
Addon.RecentPickpockets = {}

Addon.DefaultHistory = function()
    return Addon.ShallowCopy(defaults.char.history)
end

Addon.DefaultExclusions = function()
    return Addon.ShallowCopy(defaults.char.exclusions)
end

function Addon.ShallowCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else
        copy = orig
    end
    return copy
end

function Addon:OnInitialize()
	self.dbo = LibStub("AceDB-3.0"):New("ArtfulDodgerDB", defaults)
    self.db = self.dbo.char
end

function Addon:OnEnable()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:RegisterEvent("UI_ERROR_MESSAGE")
    self:RegisterEvent("LOOT_READY")
    self:RegisterMessage(self.Events.History.Reset, "Reset")
    self:RegisterMessage(self.Events.Exclusions.Reset, "ResetExclusions")
end

function Addon:Reset()
	self.db.history = self.DefaultHistory()
end

function Addon:ResetExclusions()
    self.db.exclusions = self.DefaultExclusions()
end

function Addon:UI_ERROR_MESSAGE(event, errorType, message)
	if message == ERR_ALREADY_PICKPOCKETED then
        local guid = UnitGUID("target")
        if guid then
            if not Addon.RecentPickpockets[guid] then
                Addon.RecentPickpockets[guid] = {timestamp = time()}
            end
        end
        table.remove(self.db.history.pickpocket)
    elseif message == SPELL_FAILED_TARGET_NO_POCKETS then
        local guid = UnitGUID("target")
        if guid then
            local npcId = select(6, strsplit("-", guid))
            if npcId then
                self.db.exclusions[npcId] = true
            end
        end
        table.remove(self.db.history.pickpocket)
    end
end

function Addon:LOOT_READY(event, slotNumber)
    local pickPocketEvent, junkboxItemId, sourceGuid
    local loot = {}
    for slot = 1, GetNumLootItems() do
        local sources = {GetLootSourceInfo(slot)}
        for source = 1, #sources, 2 do
            sourceGuid = sources[source]
            junkboxItem =  self.Loot.GetJunkboxFromGuid(sourceGuid)
            pickPocketEvent = Addon:GetLatestPickPocketByGuid(sourceGuid)
            if pickPocketEvent or junkboxItem then
                local lootItem = self:GetLootFromSlot(slot)
                if lootItem then
                    table.insert(loot, lootItem)
                end
            end
        end
    end
    
    if junkboxItem then
        Addon:SaveJunkboxLoot(time(), sourceGuid, junkboxItem, loot)
    elseif pickPocketEvent then
        Addon:SaveLootToPickPocketEvent(pickPocketEvent, loot)
    end
end

function Addon:GetLootFromSlot(slot)
    local lootIcon, lootName, lootQuantity, _, _, _, _, _, _ = GetLootSlotInfo(slot)
    local lootItem
    if slot > 1 and lootName then
        local lootLink = GetLootSlotLink(slot)
        if lootLink then
            local item = Item:CreateFromItemLink(lootLink)
            if item:IsItemEmpty() == false then
                item:ContinueOnItemLoad(function()
                    local sellPrice
                    local itemId = item:GetItemID()
                    local junkboxItem = self.Loot.GetJunkboxFromItemId(itemId)
                    if junkboxItem then
                        sellPrice = junkboxItem.price
                    else
                        sellPrice = select(11, GetItemInfo(lootLink))
                    end
                    lootItem = self.Loot:NewItem(sourceGuid, itemId, lootName, lootLink, lootIcon, lootQuantity, sellPrice)
                end)
            end
        end
    else
        lootItem = self.Loot:NewCoin(sourceGuid, self:GetCopperFromLootName(lootName))
    end
    return lootItem
end

function Addon:SaveJunkboxLoot(timestamp, sourceGuid, junkboxItem, loot)
    local junkbox = self.JunkboxEvent:New(timestamp, junkboxItem.itemId, sourceGuid, loot)
    if Addon:IsJunkboxEligibleForLoot(junkbox) then
        table.insert(self.db.history.junkboxes, junkbox)
        Addon:SendMessage(self.Events.Loot.Junkbox, junkbox)
    end
end

function Addon:IsJunkboxEligibleForLoot(junkboxEvent)
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

function Addon:COMBAT_LOG_EVENT_UNFILTERED(event)
	local timestamp, subEvent, _, sourceGuid, sourceName, _, _, destGuid, destName, _, _, spellId, spellName = CombatLogGetCurrentEventInfo()
	if self:IsNewPickPocketEvent(sourceGuid, spellId) then
		if subEvent == "SPELL_CAST_SUCCESS" then
            local destNpcId = strsplittable("-", destGuid)[6]
            local x, y, mapId, mapType = hbd:GetPlayerZonePosition(true)
            local areaName = GetSubZoneText()

            if destNpcId and mapId then
                local event = self.PickPocketEvent:New(time(), 
                    {name = destName, guid = destGuid, npcId = destNpcId, level = UnitLevel("target")}, 
                    mapId,
                    areaName,
                    x,
                    y
                )
                Addon:SavePickPocketEvent(event)
            end
		end
    end
end

function Addon:EligibleForPickpocket(guid)
    local event = self:GetLatestPickPocketByGuid(guid) or self.RecentPickpockets[guid]
    if event then
        if self:HasLootRespawned(event) then
            self.RecentPickpockets[guid] = nil
            return true
        end
        return false
    end
    return true
end

function Addon:HasLootRespawned(event)
    return (time() - event.timestamp) > self.db.settings.lootRespawnSeconds
end

function Addon:HasPockets(npcId)
    return not self.db.exclusions[npcId]
end

function Addon:GetLatestPickPocketByGuid(guid)
    for event = #self.db.history.pickpocket, 1, -1 do
        local victim = self.db.history.pickpocket[event].victim
        if victim and victim.guid == guid then
            return self.db.history.pickpocket[event]
        end
    end
    return nil
end

function Addon:SavePickPocketEvent(event)
    self.RecentPickpockets[event.victim.guid] = {timestamp = time()}
    self:SendMessage(self.Events.Loot.PickPocketAttempt, event)
    if event and self.db.settings.history.eventLimit >= #self.db.history.pickpocket then
        table.insert(self.db.history.pickpocket, event)
    end
end

function Addon:IsNewPickPocketEvent(sourceGuid, spellId)
	if spellId == 921 and sourceGuid == UnitGUID("player") then
		return true
	end
	return false
end

function Addon:SaveLootToPickPocketEvent(event, loot)
    if #event.loot < 1 then
        event.loot = loot
        Addon:SendMessage(self.Events.Loot.PickPocketComplete, event)
    end
end

function Addon:GetHistoryByMapId(mapId)
	local maps = {}
	for event = 1, #self.db.history.pickpocket, 1 do
		if self.db.history.pickpocket[event].mapId == mapId then
			table.insert(maps, self.db.history.pickpocket[event])
		end
	end
	return maps
end

function Addon:GetHistoryByJunkboxId(junkboxId)
	local victims = {}
	for event = 1, #self.db.history.junkboxes, 1 do
		if self.db.history.junkboxes[event].itemId == junkboxId then
			table.insert(victims, self.db.history.junkboxes[event])
		end
	end
	return victims
end

function Addon:GetHistoryFromTableByNpcId(historyTable, npcId)
	local victims = {}
	for event = 1, #historyTable, 1 do
		if historyTable[event].victim.npcId == npcId then
			table.insert(victims, historyTable[event])
		end
	end
	return victims
end

function Addon:GetCopperPerVictim(copper, count)
	if copper and count and copper > 0 and count > 0 then
        local avg = self:Round((copper / count))
		return avg
	end
	return 0
end

function Addon:GetCopperPerHour(copper, seconds)
	if copper > 0 and seconds > 0 then
		return math.floor(((copper / seconds) * 3600))
	end
	return 0
end

function Addon:Round(x)
	return x + 0.5 - (x + 0.5) % 1
end

function Addon:GetCopperFromLootName(lootName)
	return self:TotalCopper(self:GetCurrencyValues(lootName)) or 0
end

function Addon:GetCurrencyValues(money)
	local gold = money:match(GOLD_AMOUNT:gsub("%%d", "%(%%d+%)")) or 0
	local silver = 	money:match(SILVER_AMOUNT:gsub("%%d", "%(%%d+%)")) or 0
	local copper = money:match(COPPER_AMOUNT:gsub("%%d", "%(%%d+%)")) or 0

	return {gold=gold, silver=silver, copper=copper}
end

function Addon:TotalCopper(currency)
	return (currency.gold * 1000) + (currency.silver * 100) + currency.copper
end