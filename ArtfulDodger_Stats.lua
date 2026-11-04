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
    session = { start = time(), picks = 0, copper = 0, items = 0, containers = 0, containerCopper = 0 }
end

function Stats:ResetHistory()
    local db = Addon.db
    db.totals = { casts = 0, picks = 0, already = 0, barren = 0, copper = 0 }
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
        session.items = session.items + (item.qty or 1)
    end
end

function Stats:OnPickRecorded(rec)
    if not session then return end
    session.picks  = session.picks + 1
    session.copper = session.copper + (rec.copper or 0)
    for _, item in ipairs(rec.items) do
        session.items = session.items + (item.qty or 1)
    end
end

function Stats:GetPrettyPrintTotalLootedString()
    local t = Addon.db.totals
    local openings, copper = 0, 0
    for _, container in pairs(Addon.db.containers or {}) do
        openings = openings + (tonumber(container.openings) or 0)
        copper = copper + (tonumber(container.copper) or 0)
    end
    return ("Total: %d pockets, %s | %d lockboxes, %s"):format(
        t.picks, ns.Coins(t.copper), openings, ns.Coins(copper))
end

function Stats:GetPrettyPrintSessionLootedString()
    local mins = math.max(1, math.floor((time() - session.start) / 60))
    local text = ("Session (%dm): %d pockets, %s, %s/hr"):format(
        mins, session.picks, ns.Coins(session.copper),
        ns.Coins(math.floor(session.copper / mins * 60)))
    if session.containers > 0 then
        text = text .. (" | %d lockboxes, %s"):format(
            session.containers, ns.Coins(session.containerCopper))
    end
    return text
end

function Stats:GetSortedRows(field)
    local rows = {}
    for _, row in pairs(Addon.db.npcs) do rows[#rows + 1] = row end
    table.sort(rows, function(a, b)
        local av, bv = a[field] or 0, b[field] or 0
        if av == bv then return (a.name or "") < (b.name or "") end
        return av > bv
    end)
    return rows
end

function Stats:BuildReport()
    local db, clientCompatibility, out = Addon.db, ns.ClientCompatibility, {}

    out[#out + 1] = ("The Artful Dodger's Ledger   %s"):format(Addon.version)
    out[#out + 1] = ("build %s   interface %s   project %s")
        :format(tostring(clientCompatibility.buildNumber),
            tostring(clientCompatibility.interfaceVersion),
            tostring(clientCompatibility.projectID))
    out[#out + 1] = ""

    local t = db.totals
    out[#out + 1] = ("casts %d   picks %d   already %d   barren %d")
        :format(t.casts, t.picks, t.already, t.barren)
    out[#out + 1] = ("total %s   avg %s/pick"):format(ns.Coins(t.copper),
        ns.Coins(t.picks > 0 and math.floor(t.copper / t.picks) or 0))
    local containerOpenings, containerCopper = 0, 0
    for _, container in pairs(db.containers or {}) do
        containerOpenings = containerOpenings + (tonumber(container.openings) or 0)
        containerCopper = containerCopper + (tonumber(container.copper) or 0)
    end
    out[#out + 1] = ("lockboxes opened %d   lockbox copper %s")
        :format(containerOpenings, ns.Coins(containerCopper))
    out[#out + 1] = Stats:GetPrettyPrintSessionLootedString()
    out[#out + 1] = ""

    out[#out + 1] = ("%-26s %4s %5s %11s  %s"):format("npc", "diff", "picks", "copper", "flags")
    out[#out + 1] = string.rep("-", 60)

    local rows = Stats:GetSortedRows("copper")
    for i = 1, math.min(#rows, 40) do
        local r = rows[i]
        out[#out + 1] = ("%-26s %4s %5d %11s  %s"):format(
            (r.name or tostring(r.npc)):sub(1, 26), tostring(r.diff),
            r.picks, ns.Coins(r.copper), r.barren and "barren" or "")
    end
    if #rows == 0 then out[#out + 1] = "(nothing recorded yet)" end

    out[#out + 1] = ""
    out[#out + 1] = "recent:"
    if #db.recent == 0 then out[#out + 1] = "  (none)" end
    for i = #db.recent, math.max(1, #db.recent - 14), -1 do
        local e = db.recent[i]
        out[#out + 1] = ("  %s  %-24s %10s  %d item(s)"):format(
            date("%H:%M", e.t), (e.name or "?"):sub(1, 24),
            ns.Coins(e.copper), e.items)
    end
    return out
end
