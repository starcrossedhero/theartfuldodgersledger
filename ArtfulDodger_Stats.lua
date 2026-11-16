local _, ns = ...
local Addon = ns.Addon
if not Addon then return end

local Stats = {}
ns.Stats = Stats

local session

function Stats:Init()
    self:ResetSession()
    Addon:RegisterMessage(ns.Events.Loot.PickRecorded, self, "OnPickRecorded")
    Addon:RegisterMessage(ns.Events.Loot.ContainerRecorded, self, "OnContainerRecorded")
    Addon:RegisterMessage(ns.Events.Session.Reset,    self, "ResetSession")
    Addon:RegisterMessage(ns.Events.History.Reset,    self, "ResetHistory")
end

function Stats:ResetSession()
    session = {
        start = time(), picks = 0, copper = 0, items = 0,
        pocketItems = 0, containers = 0, containerCopper = 0, containerItems = 0,
    }
end

function Stats:ResetHistory()
    local db = Addon.db
    db.totals = { casts = 0, picks = 0, already = 0, pocketless = 0, copper = 0 }
    db.npcs, db.recent = {}, {}
    db.locations = {}
    db.items = {}
    db.containers = {}
    db.itemSamplePicks = 0
    self:ResetSession()
end

function Stats:OnContainerRecorded(rec)
    if not session then return end
    session.containers = session.containers + 1
    session.containerCopper = session.containerCopper + (rec.copper or 0)
    for _, item in ipairs(rec.items or {}) do
        local quantity = item.qty or 1
        session.items = session.items + quantity
        session.containerItems = session.containerItems + quantity
    end
end

function Stats:OnPickRecorded(rec)
    if not session then return end
    session.picks  = session.picks + 1
    session.copper = session.copper + (rec.copper or 0)
    for _, item in ipairs(rec.items) do
        local quantity = item.qty or 1
        session.items = session.items + quantity
        session.pocketItems = session.pocketItems + quantity
    end
end

function Stats:GetPrettyPrintTotalLootedString()
    local db = Addon.db
    local t, pocketItems = db.totals, 0
    for _, item in pairs(db.items or {}) do
        if type(item) == "table" then
            pocketItems = pocketItems + (tonumber(item.count) or 0)
        end
    end
    local openings, copper, containerItems = 0, 0, 0
    for _, container in pairs(db.containers or {}) do
        if type(container) == "table" then
            openings = openings + (tonumber(container.openings) or 0)
            copper = copper + (tonumber(container.copper) or 0)
            for _, count in pairs(container.items or {}) do
                containerItems = containerItems + (tonumber(count) or 0)
            end
        end
    end
    return ("Lifetime: %d %s for %s and %d items | %d lockboxes cracked for %s and %d items"):format(
        t.picks, ns.Voice.lifted, ns.Coins(t.copper), pocketItems,
        openings, ns.Coins(copper), containerItems)
end

function Stats:GetPrettyPrintSessionLootedString()
    local mins = math.max(1, math.floor((time() - session.start) / 60))
    return ("Session (%dm): %d %s for %s and %d items | %d lockboxes cracked for %s and %d items | %s stolen per hour"):format(
        mins, session.picks, ns.Voice.lifted, ns.Coins(session.copper), session.pocketItems,
        session.containers, ns.Coins(session.containerCopper), session.containerItems,
        ns.Coins(math.floor(session.copper / mins * 60)))
end

local function TopRow(rows, field)
    table.sort(rows, function(a, b)
        local av, bv = tonumber(a[field]) or 0, tonumber(b[field]) or 0
        if av ~= bv then return av > bv end
        local an, bn = tostring(a.name or ""), tostring(b.name or "")
        if an ~= bn then return an < bn end
        return tostring(a.id or a.npc or "") < tostring(b.id or b.npc or "")
    end)
    if #rows > 0 and (tonumber(rows[1][field]) or 0) > 0 then
        return rows[1]
    end
end

local function TopLocation()
    local rows = {}
    for mapKey, zones in pairs(Addon.db.locations or {}) do
        if type(zones) == "table" then
            for zoneKey, subzones in pairs(zones) do
                if type(subzones) == "table" then
                    for subzoneKey, entry in pairs(subzones) do
                        if type(entry) == "table" then
                            local zone = entry.zone or zoneKey
                            local subzone = entry.subzone or subzoneKey
                            rows[#rows + 1] = {
                                name = zone and subzone and zone ~= subzone
                                    and (subzone .. ", " .. zone) or subzone or zone or tostring(mapKey),
                                picks = tonumber(entry.picks) or 0,
                            }
                        end
                    end
                end
            end
        end
    end
    return TopRow(rows, "picks")
end

local function TopAggregate(entries, field)
    local rows = {}
    for key, entry in pairs(entries or {}) do
        if type(entry) == "table" then
            rows[#rows + 1] = {
                name = entry.name or tostring(entry.id or key),
                id = entry.id or key,
                [field] = tonumber(entry[field]) or 0,
            }
        end
    end
    return TopRow(rows, field)
end

local function AddChronicle(out, db, sessionStats)
    local totals = db.totals
    out[#out + 1] = "HEIST CHRONICLE"
    out[#out + 1] = ""
    out[#out + 1] = "LIFETIME HAUL"

    if (tonumber(totals.picks) or 0) > 0 then
        local average = math.floor((totals.copper or 0) / totals.picks)
        out[#out + 1] = ("%d pockets lifted | %s ill-gotten gains | Typical Purse: %s")
            :format(totals.picks, ns.CoinsText(totals.copper), ns.CoinsText(average))
    else
        out[#out + 1] = "The ledger has yet to record a successful pocket lift."
    end
    out[#out + 1] = ("Attempts: %d casts | %d already lifted | %d pocketless marks")
        :format(totals.casts, totals.already, totals.pocketless)

    local containerOpenings, containerCopper = 0, 0
    for _, container in pairs(db.containers or {}) do
        containerOpenings = containerOpenings + (tonumber(container.openings) or 0)
        containerCopper = containerCopper + (tonumber(container.copper) or 0)
    end
    out[#out + 1] = ("Lockboxes cracked: %d | Lockbox gains: %s")
        :format(containerOpenings, ns.CoinsText(containerCopper))
    out[#out + 1] = ""
    out[#out + 1] = "THIS SESSION'S JOB"
    if sessionStats.picks > 0 or sessionStats.containers > 0 then
        out[#out + 1] = ("%d pockets lifted | %s ill-gotten gains | %d items | %d lockboxes cracked (%s)")
            :format(sessionStats.picks, ns.CoinsText(sessionStats.copper), sessionStats.items,
                sessionStats.containers, ns.CoinsText(sessionStats.containerCopper))
    else
        out[#out + 1] = "No pockets lifted or lockboxes cracked this session."
    end

    out[#out + 1] = ""
    out[#out + 1] = "NOTABLE HAUNTS & FINDS"
    local marks = {}
    for _, row in pairs(db.npcs or {}) do
        if type(row) == "table" and (tonumber(row.picks) or 0) > 0 then
            marks[#marks + 1] = {
                name = ns.ResolveNPCName(row.npc, row.name),
                id = tostring(row.npc or "") .. ":" .. tostring(row.diff or 0),
                copper = tonumber(row.copper) or 0,
                picks = tonumber(row.picks) or 0,
            }
        end
    end
    local mark = TopRow(marks, "copper")
    if mark then
        out[#out + 1] = ("Most profitable mark: %s (%d pockets, %s).")
            :format(mark.name, mark.picks, ns.CoinsText(mark.copper))
    end

    local location = TopLocation()
    if location then
        out[#out + 1] = ("Busiest haunt: %s (%d pockets lifted).")
            :format(location.name, location.picks)
    end

    local item = TopAggregate(db.items, "count")
    if item then
        out[#out + 1] = ("Most common find: %s (%d).")
            :format(item.name, item.count)
    end

    local container = TopAggregate(db.containers, "openings")
    if container then
        out[#out + 1] = ("Most-cracked box: %s (%d opened).")
            :format(container.name, container.openings)
    end
    out[#out + 1] = ""
end

function Stats:GetSortedRows(field)
    local rows = {}
    for _, row in pairs(Addon.db.npcs) do
        if type(row) == "table" and (tonumber(row.picks) or 0) > 0 then
            rows[#rows + 1] = row
        end
    end
    table.sort(rows, function(a, b)
        local av, bv = a[field] or 0, b[field] or 0
        if av == bv then return (a.name or "") < (b.name or "") end
        return av > bv
    end)
    return rows
end

function Stats:GetReportMetadata()
    local clientCompatibility = ns.ClientCompatibility
    return ("%s | build %s | interface %s | project %s"):format(
        Addon.version, tostring(clientCompatibility.buildNumber),
        tostring(clientCompatibility.interfaceVersion), tostring(clientCompatibility.projectID))
end

local function AddTextTable(out, rows, headers, rightAligned, indent)
    local widths = {}
    local function Measure(row)
        for column, value in ipairs(row) do
            local length = strlenutf8 and strlenutf8(value) or #value
            widths[column] = math.max(widths[column] or 0, length)
        end
    end
    if headers then Measure(headers) end
    for _, row in ipairs(rows) do Measure(row) end

    local function Format(row)
        local columns = {}
        for column, value in ipairs(row) do
            local length = strlenutf8 and strlenutf8(value) or #value
            local padding = string.rep(" ", widths[column] - length)
            columns[column] = rightAligned[column] and (padding .. value) or (value .. padding)
        end
        return (indent or "") .. table.concat(columns, "  ")
    end
    if headers then
        out[#out + 1] = Format(headers)
        local length = #headers * 2 - 2
        for _, width in ipairs(widths) do length = length + width end
        out[#out + 1] = (indent or "") .. string.rep("-", length)
    end
    for _, row in ipairs(rows) do out[#out + 1] = Format(row) end
end

function Stats:BuildReport()
    local db, out = Addon.db, {}
    AddChronicle(out, db, session)

    out[#out + 1] = "RECENT JOBS"
    out[#out + 1] = ""
    local recentRows = {}
    for i = #db.recent, math.max(1, #db.recent - 14), -1 do
        local e = db.recent[i]
        local row = e.npc and db.npcs[Addon.NpcKey(e.npc, e.diff)]
        local name = ns.ResolveNPCName(e.npc, e.name, row and row.name)
        recentRows[#recentRows + 1] = { date("%H:%M", e.t), name,
            ns.CoinsText(e.copper), ("%d item(s)"):format(e.items) }
    end
    AddTextTable(out, recentRows, { "time", "mark", "copper", "items" },
        { [3] = true, [4] = true }, "  ")
    if #db.recent == 0 then out[#out + 1] = "  (none)" end
    out[#out + 1] = ""

    out[#out + 1] = "RICHEST MARKS"
    out[#out + 1] = ""
    local rows = Stats:GetSortedRows("copper")
    local markRows = {}
    for i = 1, math.min(#rows, 40) do
        local r = rows[i]
        markRows[#markRows + 1] = { ns.ResolveNPCName(r.npc, r.name), tostring(r.diff),
            tostring(r.picks), ns.CoinsText(r.copper), r.pocketless and "pocketless" or "" }
    end
    AddTextTable(out, markRows, { "mark", "diff", "picks", "copper", "flags" },
        { [2] = true, [3] = true, [4] = true }, "  ")
    if #rows == 0 then out[#out + 1] = "  (no successful lifts recorded yet)" end
    return out
end
