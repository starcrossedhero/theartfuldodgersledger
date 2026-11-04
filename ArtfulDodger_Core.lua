--==============================================================
--  Namespace, database, detection. Replaces AceAddon/AceEvent/
--  AceDB and the dead COMBAT_LOG_EVENT_UNFILTERED trigger.
--==============================================================
local addonName, ns = ...

if select(3, UnitClass("player")) ~= 4 then return end   -- rogues only

local Addon = {}
ns.Addon = Addon
Addon.addonName = addonName
Addon.version = "v0.1.0-alpha"
Addon.prefix = "|cff69ccf0ADL|r "

function Addon:Print(...)
    local p = {}
    for i = 1, select("#", ...) do p[i] = tostring((select(i, ...))) end
    print(self.prefix .. table.concat(p, " "))
end

--========== message bus (replaces AceEvent) ==========
local Events = {
    UI      = { Toggle = "ADL_UI_TOGGLE" },
    Session = { Reset  = "ADL_SESSION_RESET" },
    History = { Reset  = "ADL_HISTORY_RESET", AttemptRecorded = "ADL_HISTORY_ATTEMPT_RECORDED" },
    Loot    = {
        PickRecorded = "ADL_PICK_RECORDED",
        ContainerRecorded = "ADL_CONTAINER_RECORDED",
    },
}
ns.Events = Events

local bus = {}

function Addon:RegisterMessage(msg, target, method)
    bus[msg] = bus[msg] or {}
    bus[msg][#bus[msg] + 1] = { target = target or self, method = method }
end

function Addon:SendMessage(msg, ...)
    local list = bus[msg]
    if not list then return end
    for i = 1, #list do
        local listener = list[i]
        local fn = listener.target[listener.method]
        if fn then
            local ok, err = pcall(fn, listener.target, ...)
            if not ok and not listener.errorReported then
                listener.errorReported = true
                self:Print("message listener error (" .. tostring(msg) .. "/"
                    .. tostring(listener.method) .. "): " .. tostring(err))
            end
        end
    end
end

--========== client compatibility ==========
local _, buildNumber, _, interfaceVersion = GetBuildInfo()
local ClientCompatibility = {
    buildNumber = buildNumber,
    interfaceVersion = interfaceVersion,
    projectID = WOW_PROJECT_ID or 0,
    pickpocketSpellID = 921,
    alreadyPickedMessage = _G.ERR_ALREADY_PICKPOCKETED,
    noPocketsMessage = _G.SPELL_FAILED_TARGET_NO_POCKETS,
    getItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo,
    getItemIDByGUID = C_Item and C_Item.GetItemIDByGUID,
    getBestMapForUnit = C_Map and C_Map.GetBestMapForUnit,
    getPlayerMapPosition = C_Map and C_Map.GetPlayerMapPosition,
}
ns.ClientCompatibility = ClientCompatibility

local secretValueCheck = _G.issecretvalue
local function IsSecretValue(v)
    if type(secretValueCheck) ~= "function" then return false end
    local ok, secret = pcall(secretValueCheck, v)
    return ok and secret == true
end

local function Readable(v)    return type(v) == "string" and not IsSecretValue(v) end
local function ReadableNum(v) return type(v) == "number" and not IsSecretValue(v) end
ns.Readable = Readable

local function Difficulty() return select(3, GetInstanceInfo()) or 0 end
Addon.Difficulty = Difficulty

local function NpcID(guid)   -- Creature-0-3020-2444-142988-190962-... -> 190962
    if not Readable(guid) then return nil end
    local id = guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)")
        or guid:match("^Vehicle%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    return tonumber(id)
end
Addon.NpcID = NpcID

local function NpcKey(npcID, diff)
    if not npcID then return nil end
    return npcID .. ":" .. tostring(diff or 0)
end
Addon.NpcKey = NpcKey

function ns.Coins(copper)
    local c = math.floor((copper or 0) + 0.5)
    local g, s, p = math.floor(c / 10000), math.floor((c % 10000) / 100), c % 100
    if g > 0 then return ("%dg %ds %dc"):format(g, s, p) end
    if s > 0 then return ("%ds %dc"):format(s, p) end
    return ("%dc"):format(p)
end

--========== failure taxonomy (verified enUS 12.1.5) ==========
local REASON_OF = {}
for _, name in ipairs({
    "TARGET_NO_POCKETS", "OUT_OF_RANGE", "NOT_IN_CONTROL", "ONLY_STEALTHED",
    "AFFECTING_COMBAT", "INTERRUPTED_COMBAT", "CANT_STEALTH", "BAD_TARGETS",
    "BAD_IMPLICIT_TARGETS", "TARGET_FRIENDLY", "TARGET_IS_PLAYER",
    "TARGETS_DEAD", "TARGET_NOT_LOOTED",
}) do
    local s = _G["SPELL_FAILED_" .. name]
    if type(s) == "string" then
        REASON_OF[s] = (REASON_OF[s] and false) or name
    end
end

--========== database ==========
local DB_VERSION = 3

local function NewDB()
    return {
        version  = DB_VERSION,
        build    = ClientCompatibility.buildNumber,
        settings = {
            tooltip = true, tooltipCopper = false, tooltipItems = false, worldMap = false,
            lockboxOpener = true, lockboxOpenerPosition = { x = 0, y = 0 },
            targetBadge = true, nameplateBadge = true,
            targetBadgePosition = "RIGHT", nameplateBadgePosition = "RIGHT",
            targetBadgeIconSize = 16, targetBadgePadding = -20,
            nameplateBadgeIconSize = 16, nameplateBadgePadding = -5,
        },
        totals   = { casts = 0, picks = 0, already = 0, barren = 0, copper = 0 },
        npcs     = {},   -- ["<npcID>:<difficulty>"] = row
        locations = {},  -- [mapID][zone][subzone] = aggregate
        items    = {},   -- [itemID] = aggregate
        containers = {}, -- [container itemID] = aggregate
        itemSamplePicks = 0,
        recent   = {},   -- ring buffer, 50
        prices   = {},   -- [itemID] = sellPrice
    }
end

function Addon:Row(npcID, diff)
    local k = NpcKey(npcID, diff)
    if not k then return nil end
    local row = self.db.npcs[k]
    if not row then
        row = { npc = npcID, diff = diff or 0, picks = 0, already = 0,
            barren = false, pickpocketable = false, copper = 0,
            items = {}, first = time(), last = 0 }
        self.db.npcs[k] = row
    end
    return row
end

function Addon:HasPockets(npcID, diff)
    local row = self.db.npcs[NpcKey(npcID, diff or Difficulty())]
    if row and row.pickpocketable then return true end
    return not (row and row.barren)
end

Addon.POCKET_REFRESH_SECONDS = 7 * 60

function Addon:GetPocketRefreshSeconds(npcID, diff, mapID)
    return self.POCKET_REFRESH_SECONDS
end

--========== runtime spawn state: array, never keyed by GUID ==========
local MAX_SPAWNS = 200
local spawns = {}

local function FindSpawn(guid)
    if not Readable(guid) then return nil end
    for i = 1, #spawns do
        if spawns[i].guid == guid then return spawns[i] end
    end
end

local function SetSpawn(guid, state, npc, diff)
    if not Readable(guid) then return end
    local s = FindSpawn(guid)
    if not s then
        if #spawns >= MAX_SPAWNS then table.remove(spawns, 1) end
        s = { guid = guid }
        spawns[#spawns + 1] = s
    end
    s.state, s.npc, s.diff, s.at = state or s.state, npc or s.npc, diff or s.diff, GetTime()
end

function Addon:GetSpawnState(guid)
    local s = FindSpawn(guid)
    if s and s.state then return s.state end
    local npc = NpcID(guid)
    local row = npc and self.db.npcs[NpcKey(npc, Difficulty())]
    if row and row.barren then return "barren" end
end

local function UnitBool(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if not ok or type(value) ~= "boolean" or IsSecretValue(value) then return nil end
    return value
end

local function IsNPCUnit(unit)
    return type(unit) == "string"
        and UnitBool(UnitExists, unit) == true
        and UnitBool(UnitIsPlayer, unit) == false
        and UnitBool(UnitPlayerControlled, unit) == false
end

local function IsHumanoidUnit(unit)
    if not IsNPCUnit(unit) or type(UnitCreatureType) ~= "function" then
        return false
    end

    local ok, _, creatureTypeID = pcall(UnitCreatureType, unit)
    return ok and ReadableNum(creatureTypeID) and creatureTypeID == 7
end

function Addon:GetPickpocketState(unit, guid)
    if not Readable(guid) and type(unit) == "string" and type(UnitGUID) == "function" then
        local ok, value = pcall(UnitGUID, unit)
        if ok and Readable(value) then guid = value end
    end

    local npc = NpcID(guid)
    if not npc then return nil end

    local state = self:GetSpawnState(guid)
    if state == "robbed" then
        local spawn = FindSpawn(guid)
        if not (spawn and ReadableNum(spawn.pickedAt)) then return "robbed" end
        local duration = self:GetPocketRefreshSeconds(spawn.npc, spawn.diff, spawn.mapID)
        local remaining = duration - (GetTime() - spawn.pickedAt)
        if remaining > 0 then return "cooldown", remaining, duration end
    end
    if state == "barren" or not self:HasPockets(npc, Difficulty()) then
        return IsHumanoidUnit(unit) and "barren" or nil
    end
    local row = self.db.npcs[NpcKey(npc, Difficulty())]
    local knownPickpocketable = row and row.pickpocketable

    if not IsNPCUnit(unit)
        or UnitBool(UnitIsDeadOrGhost, unit) ~= false
        or UnitBool(UnitCanAttack, "player", unit) ~= true
        or (not knownPickpocketable and not IsHumanoidUnit(unit)) then
        return nil
    end
    return "likely"
end

--========== event plumbing ==========
local frame = CreateFrame("Frame")
Addon.registered = {}

function Addon:RegisterEvent(event, unit)
    if self.registered[event] then return end
    local ok
    if unit then ok = pcall(frame.RegisterUnitEvent, frame, event, unit)
    else         ok = pcall(frame.RegisterEvent,     frame, event) end
    self.registered[event] = ok or nil
end
Addon.RegisterUnitEvent = Addon.RegisterEvent

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if (...) ~= Addon.addonName then return end
        Addon:Initialize()
        return
    end
    local fn = Addon[event]
    if fn then
        local ok, err = pcall(fn, Addon, ...)
        if not ok then Addon:Print("error in " .. event .. ": " .. tostring(err)) end
    end
end)
frame:RegisterEvent("ADDON_LOADED")

function Addon:Initialize()
    if type(ArtfulDodgerDB) == "table" and ArtfulDodgerDB.version == 1 then
        ArtfulDodgerDB.version = 2
        ArtfulDodgerDB.containers = {}
    end
    if type(ArtfulDodgerDB) == "table" and ArtfulDodgerDB.version == 2 then
        ArtfulDodgerDB.version = DB_VERSION
    end
    if type(ArtfulDodgerDB) ~= "table" or ArtfulDodgerDB.version ~= DB_VERSION then
        if type(ArtfulDodgerDB) == "table" and next(ArtfulDodgerDB) ~= nil then
            self:Print("discarding database from an older schema")
        end
        ArtfulDodgerDB = NewDB()
    end
    self.db = ArtfulDodgerDB

    self.db.settings = self.db.settings or {}
    if self.db.settings.tooltip == nil then self.db.settings.tooltip = true end
    if self.db.settings.lockboxOpener == nil then self.db.settings.lockboxOpener = true end
    if type(self.db.settings.lockboxOpenerPosition) ~= "table" then
        self.db.settings.lockboxOpenerPosition = { x = 0, y = 0 }
    end
    if type(self.db.settings.lockboxOpenerPosition.x) ~= "number" then
        self.db.settings.lockboxOpenerPosition.x = 0
    end
    if type(self.db.settings.lockboxOpenerPosition.y) ~= "number" then
        self.db.settings.lockboxOpenerPosition.y = 0
    end
    if self.db.settings.targetBadge == nil then self.db.settings.targetBadge = true end
    if self.db.settings.nameplateBadge == nil then self.db.settings.nameplateBadge = true end
    if self.db.settings.targetBadgePosition == nil then self.db.settings.targetBadgePosition = "RIGHT" end
    if self.db.settings.nameplateBadgePosition == nil then self.db.settings.nameplateBadgePosition = "RIGHT" end
    if self.db.settings.targetBadgeIconSize == nil then self.db.settings.targetBadgeIconSize = 16 end
    if self.db.settings.targetBadgePadding == nil then self.db.settings.targetBadgePadding = -20 end
    if self.db.settings.nameplateBadgeIconSize == nil then self.db.settings.nameplateBadgeIconSize = 16 end
    if self.db.settings.nameplateBadgePadding == nil then self.db.settings.nameplateBadgePadding = -5 end
    if self.db.settings.tooltipCopper == nil then self.db.settings.tooltipCopper = false end
    if self.db.settings.tooltipItems == nil then self.db.settings.tooltipItems = false end
    if self.db.settings.worldMap == nil then self.db.settings.worldMap = false end
    self.db.locations = self.db.locations or {}
    self.db.items = self.db.items or {}
    self.db.containers = self.db.containers or {}
    if type(self.db.itemSamplePicks) ~= "number" then
        self.db.itemSamplePicks = 0
        for _, item in pairs(self.db.items) do
            if type(item) == "table" then item.picks = 0 end
        end
    end

    if not next(self.db.items) then
        for _, creature in pairs(self.db.npcs or {}) do
            for itemKey, count in pairs(creature.items or {}) do
                local itemID, quantity = tonumber(itemKey), tonumber(count)
                if itemID and quantity and quantity > 0 then
                    local item = self.db.items[itemID]
                    if not item then
                        item = { id = itemID, count = 0, picks = 0, last = 0 }
                        self.db.items[itemID] = item
                    end
                    item.count = item.count + quantity
                    local names, links = creature.itemNames or {}, creature.itemLinks or {}
                    local link = links[itemKey] or links[itemID]
                    item.name = item.name or names[itemKey] or names[itemID]
                        or (type(link) == "string" and link:match("%[(.-)%]"))
                    item.link = item.link or link
                end
            end
        end
    end
    for _, item in pairs(self.db.items) do
        if type(item) == "table" and (type(item.picks) ~= "number" or item.picks < 0) then
            item.picks = 0
        end
    end

    if self.db.dropRateVersion ~= 1 then
        local creatureHits = {}
        local creaturePicks = 0
        for _, creature in pairs(self.db.npcs or {}) do
            local picks = tonumber(creature.picks) or 0
            creaturePicks = creaturePicks + picks
            creature.itemSamplePicks = picks
            creature.itemPicks = creature.itemPicks or {}
            creature.itemRatesApproximate = true
            for itemKey, count in pairs(creature.items or {}) do
                local itemID, quantity = tonumber(itemKey) or itemKey, tonumber(count)
                if quantity and quantity > 0 then
                    local hits = tonumber(creature.itemPicks[itemID] or creature.itemPicks[itemKey]) or 0
                    hits = math.max(hits, 1)
                    creature.itemPicks[itemID] = hits
                    creatureHits[itemID] = (creatureHits[itemID] or 0) + hits
                end
            end
        end

        for _, zones in pairs(self.db.locations or {}) do
            if type(zones) == "table" then
                for _, subzones in pairs(zones) do
                    if type(subzones) == "table" then
                        for _, location in pairs(subzones) do
                            if type(location) == "table" then
                                location.itemSamplePicks = tonumber(location.picks) or 0
                                location.itemPicks = location.itemPicks or {}
                                location.itemRatesApproximate = true
                                for itemKey, count in pairs(location.items or {}) do
                                    local itemID, quantity = tonumber(itemKey) or itemKey, tonumber(count)
                                    if quantity and quantity > 0 then
                                        local hits = tonumber(location.itemPicks[itemID]
                                            or location.itemPicks[itemKey]) or 0
                                        location.itemPicks[itemID] = math.max(hits, 1)
                                        if not creatureHits[itemID] then creatureHits[itemID] = 1 end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        for itemKey, item in pairs(self.db.items) do
            if type(item) == "table" then
                local itemID = tonumber(itemKey) or item.id or itemKey
                item.picks = math.max(tonumber(item.picks) or 0, creatureHits[itemID] or 0)
                item.dropRateApproximate = true
            end
        end
        self.db.itemSamplePicks = math.max(tonumber(self.db.totals.picks) or 0, creaturePicks)
        self.db.dropRateVersion = 1
    end

    -- pocket availability is learned per build and may change with patches
    if self.db.build ~= ClientCompatibility.buildNumber then
        for _, row in pairs(self.db.npcs) do
            row.barren = false
            row.pickpocketable = false
        end
        self.db.build = ClientCompatibility.buildNumber
    end

    if ns.Stats  then ns.Stats:Init()  end
    if ns.UI     then ns.UI:Init()     end
    if ns.Map    then ns.Map:Init()    end
    if ns.Commands then ns.Commands:Init() end
    if ns.Badges then ns.Badges:Init() end
    if ns.Opener then ns.Opener:Init() end
    if ns.Options then ns.Options:Init() end

    self:Enable()
end

function Addon:Enable()
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    self:RegisterEvent("LOOT_OPENED")
    self:RegisterEvent("UI_ERROR_MESSAGE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    self:Print(self.version, "build " .. tostring(ClientCompatibility.buildNumber),
        "interface " .. tostring(ClientCompatibility.interfaceVersion),
        "pickpocket=" .. ClientCompatibility.pickpocketSpellID,
        "noPocketsMessage=" .. tostring(ClientCompatibility.noPocketsMessage ~= nil),
        "alreadyPickedMessage=" .. tostring(ClientCompatibility.alreadyPickedMessage ~= nil))
end

--========== detection ==========
function Addon:PLAYER_ENTERING_WORLD() spawns = {} end

local function LocationText(fn)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn)
    if ok and Readable(value) and value ~= "" then return value end
end

local function PlayerLocation()
    local mapID
    if type(ClientCompatibility.getBestMapForUnit) == "function" then
        local ok, value = pcall(ClientCompatibility.getBestMapForUnit, "player")
        if ok and ReadableNum(value) then mapID = value end
    end

    local zone = LocationText(GetRealZoneText) or LocationText(GetZoneText)
    local subzone = LocationText(GetSubZoneText)
    local mapX, mapY
    if mapID and type(ClientCompatibility.getPlayerMapPosition) == "function" then
        local ok, position = pcall(ClientCompatibility.getPlayerMapPosition, mapID, "player")
        if ok and position and type(position.GetXY) == "function" then
            local fine, x, y = pcall(position.GetXY, position)
            if fine and ReadableNum(x) and ReadableNum(y)
                and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                mapX, mapY = x, y
            end
        end
    end
    return mapID, zone, subzone, mapX, mapY
end

function Addon:PLAYER_TARGET_CHANGED()
    if not UnitExists("target") then return end
    local g = UnitGUID("target")
    if Readable(g) then self.lastGUID, self.lastAt = g, GetTime() end
end

function Addon:UNIT_SPELLCAST_SUCCEEDED(unit, castGUID, spellID)
    if not ReadableNum(spellID) then return end
    if spellID ~= ClientCompatibility.pickpocketSpellID then return end

    local guid = UnitGUID("target")
    if not Readable(guid) then guid = nil end
    if guid then self.lastGUID, self.lastAt = guid, GetTime() end

    local name = UnitName("target")
    local mapID, zone, subzone, mapX, mapY = PlayerLocation()
    self.pending = {
        guid = guid, name = Readable(name) and name or nil,
        npc  = guid and NpcID(guid) or nil, diff = Difficulty(),
        mapID = mapID, zone = zone, subzone = subzone,
        mapX = mapX, mapY = mapY,
        at = GetTime(), copper = 0, items = {},
    }
    self.db.totals.casts = self.db.totals.casts + 1
end

local function ReadLootWindow()
    local rec = { copper = 0, items = {} }
    for slot = 1, (GetNumLootItems() or 0) do
        local name, _, quantity, _, _, _, _, _, _, isCoin = GetLootSlotInfo(slot)
        if isCoin then
            local amount = select(2, GetLootSourceInfo(slot))
            if ReadableNum(amount) then rec.copper = rec.copper + amount end
        else
            local link = GetLootSlotLink(slot)
            local itemID = Readable(link) and tonumber(link:match("item:(%d+)")) or nil
            if itemID then
                rec.items[#rec.items + 1] = {
                    id = itemID,
                    qty = ReadableNum(quantity) and quantity or 1,
                    name = Readable(name) and name or (Readable(link) and link:match("%[(.-)%]")),
                    link = Readable(link) and link or nil,
                }
                Addon:ResolvePrice(itemID)
            end
        end
    end
    return rec
end

function Addon:LOOT_OPENED(autoLoot, isFromItem)
    local pending = self.pendingContainerOpen
    local pendingItemID = pending and GetTime() - pending.at <= 5 and pending.itemID
    self.pendingContainerOpen = nil
    if isFromItem or pendingItemID then
        self:RecordContainerLoot(pendingItemID)
        self.pending = nil
        return
    end

    local rec = self.pending
    if not rec then return end
    if GetTime() - rec.at > 6 then self.pending = nil; return end

    local src = GetLootSourceInfo(1)
    if Readable(src) and Readable(rec.guid) and src ~= rec.guid then return end

    local loot = ReadLootWindow()
    rec.copper, rec.items = loot.copper, loot.items

    self:RecordPick(rec)
    self.pending = nil
end

local function ContainerIDFromGUID(guid)
    local getItemID = ClientCompatibility.getItemIDByGUID
    if not Readable(guid) or type(getItemID) ~= "function" then return nil end
    local ok, itemID = pcall(getItemID, guid)
    if ok and ReadableNum(itemID) and ns.ContainerItemIDs[itemID] then return itemID end
end

local function LootFromOpenWindow(fallbackItemID)
    local containerID
    for slot = 1, (GetNumLootItems() or 0) do
        local sources = { GetLootSourceInfo(slot) }
        for source = 1, #sources, 2 do
            containerID = ContainerIDFromGUID(sources[source])
            if containerID then break end
        end
        if containerID then break end
    end
    if not containerID and ns.ContainerItemIDs[fallbackItemID] then
        containerID = fallbackItemID
    end
    if not containerID then return nil end

    local rec = ReadLootWindow()
    rec.id = containerID
    return rec
end

local function ItemQuantity(item)
    return ReadableNum(item.qty) and item.qty > 0 and item.qty or 1
end

local function AddItemSample(row, items, onItem)
    row.items = row.items or {}
    row.itemNames = row.itemNames or {}
    row.itemLinks = row.itemLinks or {}
    row.itemPicks = row.itemPicks or {}
    row.itemSamplePicks = (tonumber(row.itemSamplePicks) or 0) + 1

    local seenItems = {}
    local itemCount = 0
    for _, item in ipairs(items or {}) do
        local quantity = ItemQuantity(item)
        itemCount = itemCount + quantity
        row.items[item.id] = (tonumber(row.items[item.id]) or 0) + quantity
        if item.name then row.itemNames[item.id] = item.name end
        if item.link then row.itemLinks[item.id] = item.link end
        local firstInSample = not seenItems[item.id]
        if firstInSample then
            row.itemPicks[item.id] = (tonumber(row.itemPicks[item.id]) or 0) + 1
            seenItems[item.id] = true
        end
        if onItem then onItem(item, quantity, firstInSample) end
    end
    return itemCount
end

function Addon:RecordContainerLoot(fallbackItemID)
    local rec = LootFromOpenWindow(fallbackItemID)
    if not rec then return end

    local itemName, itemLink
    if type(ClientCompatibility.getItemInfo) == "function" then
        local ok, name, link = pcall(ClientCompatibility.getItemInfo, rec.id)
        if ok then
            itemName = Readable(name) and name or nil
            itemLink = Readable(link) and link or nil
        end
    end
    rec.name, rec.link = itemName, itemLink

    local container = self.db.containers[rec.id]
    if not container then
        container = {
            id = rec.id, openings = 0, copper = 0, items = {},
            itemNames = {}, itemLinks = {}, itemPicks = {}, itemSamplePicks = 0,
        }
        self.db.containers[rec.id] = container
    end
    container.name = rec.name or container.name
    container.link = rec.link or container.link
    container.openings = container.openings + 1
    container.copper = container.copper + rec.copper
    container.last = time()
    local itemCount = AddItemSample(container, rec.items)
    rec.t, rec.itemsCount = time(), itemCount
    rec.outcome = "Lockbox opened"
    self.db.recent[#self.db.recent + 1] = {
        t = rec.t, name = rec.name or ("Lockbox " .. rec.id), containerID = rec.id,
        copper = rec.copper, items = itemCount, outcome = rec.outcome,
    }
    while #self.db.recent > 50 do table.remove(self.db.recent, 1) end
    self:SendMessage(Events.Loot.ContainerRecorded, rec)
end

function Addon:UI_ERROR_MESSAGE(errType, message)
    if not Readable(message) then return end

    if ClientCompatibility.alreadyPickedMessage
        and message == ClientCompatibility.alreadyPickedMessage then
        local g = self:ErrorTarget()
        local npc = g and NpcID(g)
        if g then SetSpawn(g, "robbed", npc, Difficulty()) end
        local row = self:Row(npc, Difficulty())
        if row then row.already = row.already + 1; row.last = time() end
        self.db.totals.already = self.db.totals.already + 1
        self.pending = nil                          -- the cast DID fire
        return
    end

    local reason = REASON_OF[message]
    if not reason then return end                   -- unclassified: never changes state

    if reason == "TARGET_NO_POCKETS" then
        local g = self:ErrorTarget()
        local npc = g and NpcID(g)
        if npc then
            local row = self:Row(npc, Difficulty())
            if row and not row.pickpocketable and not row.barren then
                row.barren = true; row.last = time()
                self.db.totals.barren = self.db.totals.barren + 1
            end
            SetSpawn(g, "barren", npc, Difficulty())
        end
        local rec = self.pending or {}
        local mapID, zone, subzone = rec.mapID, rec.zone, rec.subzone
        if not mapID and not zone and not subzone then
            mapID, zone, subzone = PlayerLocation()
        end
        local name = Readable(rec.name) and rec.name or nil
        if not name then
            local ok, targetName = pcall(UnitName, "target")
            if ok and Readable(targetName) then name = targetName end
        end
        local entry = {
            t = time(), name = name, npc = npc, diff = rec.diff or Difficulty(),
            mapID = mapID, zone = zone, subzone = subzone,
            copper = 0, items = 0, outcome = "No pockets",
        }
        self.db.recent[#self.db.recent + 1] = entry
        while #self.db.recent > 50 do table.remove(self.db.recent, 1) end
        self:SendMessage(Events.History.AttemptRecorded, entry)
    end

    self.pending = nil                              -- attempt over, nothing learned
end

function Addon:ErrorTarget()
    if self.pending and Readable(self.pending.guid) then return self.pending.guid end
    if Readable(self.lastGUID) and (GetTime() - (self.lastAt or 0)) < 3 then
        return self.lastGUID
    end
end

--========== recording ==========
local function LocationRow(rec)
    local locations = Addon.db.locations
    local mapID = ReadableNum(rec.mapID) and rec.mapID or 0
    local zone = Readable(rec.zone) and rec.zone or ""
    local subzone = Readable(rec.subzone) and rec.subzone or ""

    local byMap = locations[mapID]
    if not byMap then
        byMap = {}
        locations[mapID] = byMap
    end
    local byZone = byMap[zone]
    if not byZone then
        byZone = {}
        byMap[zone] = byZone
    end
    local row = byZone[subzone]
    if not row then
        row = {
            mapID = mapID > 0 and mapID or nil,
            zone = zone ~= "" and zone or nil,
            subzone = subzone ~= "" and subzone or nil,
            picks = 0, copper = 0, items = {}, itemNames = {}, itemLinks = {},
            itemPicks = {}, itemSamplePicks = 0, last = 0,
        }
        byZone[subzone] = row
    end
    return row
end

function Addon:RecordPick(rec)
    local t = self.db.totals
    t.picks  = t.picks + 1
    t.copper = t.copper + (rec.copper or 0)

    local location = LocationRow(rec)
    location.picks = location.picks + 1
    location.copper = location.copper + (rec.copper or 0)
    location.last = time()
    if ReadableNum(rec.mapX) and ReadableNum(rec.mapY)
        and rec.mapX >= 0 and rec.mapX <= 1 and rec.mapY >= 0 and rec.mapY <= 1 then
        local samples = tonumber(location.positionSamples) or 0
        location.positionX = ((tonumber(location.positionX) or 0) * samples + rec.mapX) / (samples + 1)
        location.positionY = ((tonumber(location.positionY) or 0) * samples + rec.mapY) / (samples + 1)
        location.positionSamples = samples + 1
    end
    self.db.itemSamplePicks = (self.db.itemSamplePicks or 0) + 1
    local itemCount = AddItemSample(location, rec.items, function(it, quantity, firstInSample)
        local item = self.db.items[it.id]
        if not item then
            item = { id = it.id, name = it.name, link = it.link, count = 0, picks = 0, last = 0 }
            self.db.items[it.id] = item
        end
        item.name = it.name or item.name
        item.link = it.link or item.link
        item.count = item.count + quantity
        if firstInSample then
            item.picks = (item.picks or 0) + 1
        end
        item.last = time()
    end)

    local row = self:Row(rec.npc, rec.diff)
    if row then
        row.name   = row.name or rec.name
        row.pickpocketable = true
        row.barren = false
        row.picks  = row.picks + 1
        row.copper = row.copper + (rec.copper or 0)
        row.last   = time()
        AddItemSample(row, rec.items)
    end

    SetSpawn(rec.guid, "robbed", rec.npc, rec.diff)
    local spawn = FindSpawn(rec.guid)
    if spawn then
        spawn.pickedAt, spawn.mapID = GetTime(), rec.mapID
    end

    self.db.recent[#self.db.recent + 1] = {
        t = time(), name = rec.name, npc = rec.npc, diff = rec.diff,
        mapID = rec.mapID, zone = rec.zone, subzone = rec.subzone,
        copper = rec.copper or 0, items = itemCount, outcome = "Picked",
    }
    while #self.db.recent > 50 do table.remove(self.db.recent, 1) end

    self:SendMessage(Events.Loot.PickRecorded, rec)
end

function Addon:ResolvePrice(itemID)
    if self.db.prices[itemID] then return end
    if not (Item and Item.CreateFromItemID) then return end
    local item = Item:CreateFromItemID(itemID)
    if not item then return end
    item:ContinueOnItemLoad(function()
        -- C_Item.GetItemInfo returns 18 ordered values; sellPrice is #11.
        local get = ClientCompatibility.getItemInfo
        if type(get) ~= "function" then return end
        local ok, price = pcall(function() return select(11, get(itemID)) end)
        if ok and type(price) == "number" and price > 0 then
            Addon.db.prices[itemID] = price
        end
    end)
end

--========== diagnostics ==========
SLASH_ADLDIAG1 = "/adldiag"
SlashCmdList["ADLDIAG"] = function()
    local db = Addon.db
    if not db then Addon:Print("not initialised yet"); return end

    local rows, npcLootRows, locationLootRows, itemRows = 0, 0, 0, 0
    for _ in pairs(db.npcs) do rows = rows + 1 end
    for _, row in pairs(db.npcs) do
        if type(row.items) == "table" and next(row.items) then
            npcLootRows = npcLootRows + 1
        end
    end
    for _ in pairs(db.items or {}) do itemRows = itemRows + 1 end
    for _, zones in pairs(db.locations or {}) do
        if type(zones) == "table" then
            for _, subzones in pairs(zones) do
                if type(subzones) == "table" then
                    for _, location in pairs(subzones) do
                        if type(location) == "table" and type(location.items) == "table"
                            and next(location.items) then
                            locationLootRows = locationLootRows + 1
                        end
                    end
                end
            end
        end
    end

    Addon:Print("db=true",
        "tooltipSetting=" .. tostring(db.settings and db.settings.tooltip),
        "hooked=" .. tostring(Addon.tooltipHooked),
        "spawns=" .. #spawns, "npcRows=" .. rows,
        "npcLootRows=" .. npcLootRows, "locationLootRows=" .. locationLootRows,
        "itemRows=" .. itemRows)

    local g = UnitGUID("target")
    Addon:Print("target=" .. tostring(UnitName("target")),
        "npc=" .. tostring(NpcID(g)), "diff=" .. Difficulty(),
        "state=" .. tostring(g and Addon:GetSpawnState(g)))

    for i = 1, math.min(#spawns, 8) do
        local s = spawns[i]
        Addon:Print("spawn" .. i, s.state or "?", tostring(s.npc), (s.guid or ""):sub(-10))
    end

    Addon.tipProbe, Addon.tipCount = true, 0
    Addon:Print("hover up to 8 units for per-hover detail")
end

