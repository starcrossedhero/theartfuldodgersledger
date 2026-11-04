local _, ns = ...
local Addon = ns.Addon
if not Addon then return end

local Readable = ns.Readable

local TIP_EMPTY   = "Pockets: Empty"
local TIP_YES     = "Pockets: Yes"
local TIP_LIKELY  = "Pockets: Likely"
local TIP_NO      = "Pockets: No"
local TIP_REFRESH = "Pockets: Empty (estimated refresh in %s)"

local function FormatRemaining(seconds)
    seconds = math.max(0, math.ceil(seconds))
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local function GuidFromTooltip(tooltip, data)
    if tooltip and type(tooltip.GetUnit) == "function" then
        local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
        if ok and unit and type(UnitGUID) == "function" then
            local fine, guid = pcall(UnitGUID, unit)
            if fine and Readable(guid) then return guid, unit end
        end
    end
    if type(data) == "table" then
        local guid = data.guid
        if Readable(guid) then return guid end
    end
end

local function OnUnitTooltip(tooltip, data)
    local db = Addon.db
    local guid, unit = GuidFromTooltip(tooltip, data)

    if Addon.tipProbe then
        Addon.tipCount = (Addon.tipCount or 0) + 1
        if Addon.tipCount <= 8 then
            local state
            if guid and type(Addon.GetPickpocketState) == "function" then
                local ok, value = pcall(Addon.GetPickpocketState, Addon, unit, guid)
                if ok then state = value end
            end
            Addon:Print("[tip" .. Addon.tipCount .. "]",
                "guid=" .. tostring(guid),
                "state=" .. tostring(state),
                "setting=" .. tostring(db and db.settings and db.settings.tooltip),
                "main=" .. tostring(tooltip == GameTooltip))
        end
    end

    if not db or not db.settings then return end
    if not guid then return end
    if type(tooltip.AddLine) ~= "function" then return end

    local npcID = Addon.NpcID(guid)
    local row = npcID and db.npcs
        and db.npcs[Addon.NpcKey(npcID, Addon.Difficulty())]
    local knownTarget = type(row) == "table" and (tonumber(row.picks) or 0) > 0
    local statusShown = false
    if db.settings.tooltip and type(Addon.GetPickpocketState) == "function" then
        local ok, state, remaining = pcall(Addon.GetPickpocketState, Addon, unit, guid)
        if not ok then state = nil end

        local pocketStatus
        if state == "cooldown" then
            pocketStatus = TIP_REFRESH:format(FormatRemaining(remaining))
        elseif state == "robbed" then
            pocketStatus = TIP_EMPTY
        elseif state == "barren" then
            pocketStatus = TIP_NO
        elseif knownTarget or (type(row) == "table" and row.pickpocketable) then
            pocketStatus = TIP_YES
        elseif state == "likely" then
            pocketStatus = TIP_LIKELY
        end

        if pocketStatus then
            tooltip:AddLine(pocketStatus, 0.55, 0.55, 0.55)
            statusShown = true
        end
    end

    if type(row) ~= "table" then return end

    local picks = tonumber(row.picks) or 0
    local samplePicks = tonumber(row.itemSamplePicks) or 0
    local drops = {}
    if db.settings.tooltipItems and samplePicks > 0 and type(row.items) == "table" then
        for itemKey, quantity in pairs(row.items) do
            if (tonumber(quantity) or 0) > 0 then
                local itemID = tonumber(itemKey) or itemKey
                local hits = tonumber(row.itemPicks and (row.itemPicks[itemID] or row.itemPicks[itemKey])) or 0
                if hits > 0 then
                    local link = row.itemLinks and (row.itemLinks[itemID] or row.itemLinks[itemKey])
                    local name = row.itemNames and (row.itemNames[itemID] or row.itemNames[itemKey])
                    if not name and type(link) == "string" then name = link:match("%[(.-)%]") end
                    drops[#drops + 1] = {
                        name = name or tostring(itemID),
                        rate = hits / samplePicks * 100,
                    }
                end
            end
        end
    end
    table.sort(drops, function(a, b)
        if a.rate == b.rate then return a.name < b.name end
        return a.rate > b.rate
    end)

    local showAverage = db.settings.tooltipCopper and picks > 0
    local showItems = #drops > 0
    local indent = statusShown and "  " or ""
    if showAverage or showItems then
        tooltip:AddLine(indent .. ("Total: %d Pockets"):format(picks), 0.9, 0.82, 0.45)
    end
    if showAverage then
        tooltip:AddLine(indent .. ("Average: %s")
            :format(ns.Coins((tonumber(row.copper) or 0) / picks)), 0.9, 0.82, 0.45)
    end
    if showItems then
        tooltip:AddLine(indent .. "Items:", 0.9, 0.82, 0.45)
        for _, drop in ipairs(drops) do
            local rate = ("%.1f%%%s"):format(drop.rate,
                row.itemRatesApproximate and " (estimated)" or "")
            if type(tooltip.AddDoubleLine) == "function" then
                tooltip:AddDoubleLine(indent .. "  " .. drop.name, rate,
                    0.9, 0.9, 0.9, 0.7, 0.85, 0.7)
            else
                tooltip:AddLine(indent .. "  " .. drop.name .. " - " .. rate, 0.9, 0.9, 0.9)
            end
        end
    end
end

local function InstallTooltipHook()
    if not (TooltipDataProcessor and Enum and Enum.TooltipDataType) then return false end

    local ok, err = pcall(TooltipDataProcessor.AddTooltipPostCall,
        Enum.TooltipDataType.Unit,
        function(tooltip, data)
            local fine, errorMessage = xpcall(
                function() OnUnitTooltip(tooltip, data) end,
                function(message)
                    return tostring(message) .. "\n" .. tostring(debug.traceback("", 2))
                end)
            if not fine and not Addon.tipErrored then
                Addon.tipErrored = true
                Addon:Print("|cffff2020tooltip hook error|r\n" .. tostring(errorMessage))
            end
        end)

    if not ok then Addon:Print("AddTooltipPostCall failed: " .. tostring(err)) end
    return ok
end

local tooltipLoader = CreateFrame("Frame")
tooltipLoader:RegisterEvent("PLAYER_LOGIN")
tooltipLoader:SetScript("OnEvent", function()
    Addon.tooltipHooked = InstallTooltipHook()
    Addon:Print("tooltip hook " ..
        (Addon.tooltipHooked and "installed" or "|cffff2020UNAVAILABLE|r"))
end)