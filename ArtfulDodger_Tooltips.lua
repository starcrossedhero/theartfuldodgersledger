local _, ns = ...
local Addon = ns.Addon
if not Addon then return end

local Readable = ns.Readable

local TIP_ROBBED  = "Robbed"
local TIP_YES     = "Known Mark"
local TIP_LIKELY  = "Likely Mark"
local TIP_NO      = "No Pockets"
local TIP_REFRESH = "Robbed (payday in %s)"
local TIP_PICKS   = "Pockets Lifted"
local TIP_PURSE   = "Typical Purse"
local TIP_ITEMS   = "Possible Take"

local function FormatRemaining(seconds)
    seconds = math.max(0, math.ceil(seconds))
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local function GuidFromTooltip(tooltip, data)
    if tooltip and type(tooltip.GetUnit) == "function" then
        local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
        if ok and unit then
            local guid
            if type(UnitGUID) == "function" then
                local fine, value = pcall(UnitGUID, unit)
                if fine and Readable(value) then guid = value end
            end
            return guid, unit
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

    if Addon.inspectEnabled and unit and ns.Commands then
        ns.Commands:InspectUnit(unit, tooltip, data)
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
            pocketStatus = TIP_ROBBED
        elseif state == "pocketless" then
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
        tooltip:AddLine(indent .. ("%s: %d"):format(TIP_PICKS, picks), 0.9, 0.82, 0.45)
    end
    if showAverage then
        tooltip:AddLine(indent .. ("%s: %s")
            :format(TIP_PURSE, ns.Coins((tonumber(row.copper) or 0) / picks)), 0.9, 0.82, 0.45)
    end
    if showItems then
        tooltip:AddLine(indent .. TIP_ITEMS .. ":", 0.9, 0.82, 0.45)
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

local function FormatHookError(message)
    local ok, text = pcall(tostring, message)
    if not ok or not Readable(text) then text = "<unreadable error>" end

    local trace = ""
    if type(debug) == "table" and type(debug.traceback) == "function" then
        local fine, result = pcall(debug.traceback, "", 2)
        if fine and Readable(result) then trace = result end
    end
    return text .. trace
end

local function InstallTooltipHook()
    if not (TooltipDataProcessor and Enum and Enum.TooltipDataType) then return false end

    local ok, err = pcall(TooltipDataProcessor.AddTooltipPostCall,
        Enum.TooltipDataType.Unit,
        function(tooltip, data)
            local fine, errorMessage = xpcall(
                function() OnUnitTooltip(tooltip, data) end,
                    FormatHookError)
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
    Addon:Debug("tooltip hook " ..
        (Addon.tooltipHooked and "installed" or "|cffff2020UNAVAILABLE|r"))
end)