local _, ns = ...
local Addon = ns.Addon
if not Addon then
    _G.ArtfulDodger_OnCompartmentClick = function() end
    _G.ArtfulDodger_OnCompartmentEnter = function() end
    _G.ArtfulDodger_OnCompartmentLeave = function() end
    return
end

local UI = {}
ns.UI = UI
local frame
local activeView = "history"
local refreshPending = false
local refreshGeneration = 0
local sortState = {
    history = { key = "time", ascending = false },
    creatures = { key = "avgCopper", ascending = false },
    locations = { key = "avgCopper", ascending = false },
    items = { key = "count", ascending = false },
    containers = { key = "openings", ascending = false },
}

local TABLE_WIDTH = 840
local ROW_HEIGHT = 24
local MAX_COLUMNS = 8

local function ItemQuantity(counts)
    local total = 0
    for _, count in pairs(counts or {}) do
        total = total + (tonumber(count) or 0)
    end
    return total
end

local function ItemSummary(counts, names, links, pickCounts, samplePicks, approximate)
    local items = {}
    for id, count in pairs(counts or {}) do
        local itemID, quantity = tonumber(id) or id, tonumber(count)
        if type(itemID) == "number" and quantity and quantity > 0 then
            local link = links and (links[id] or links[itemID])
            local name = names and (names[id] or names[itemID])
            if not name and type(link) == "string" then name = link:match("%[(.-)%]") end
            local hits = tonumber(pickCounts and (pickCounts[id] or pickCounts[tostring(id)])) or 0
            local averageQuantity = hits > 0 and quantity / hits or 1
            items[#items + 1] = {
                name = name or tostring(id),
                id = itemID,
                link = link,
                count = quantity,
                hits = hits,
                samplePicks = samplePicks or 0,
                averageQuantity = averageQuantity,
                displayedQuantity = math.max(1, math.floor(averageQuantity + 0.5)),
                dropRate = samplePicks and samplePicks > 0
                    and (hits / samplePicks * 100) or nil,
                dropRateApproximate = approximate,
            }
        end
    end
    table.sort(items, function(a, b)
        if a.count == b.count then return a.name < b.name end
        return a.count > b.count
    end)
    local summary = {}
    for i = 1, math.min(3, #items) do
        summary[i] = items[i]
    end
    return summary
end

local function ItemIcon(itemID)
    if C_Item and type(C_Item.GetItemIconByID) == "function" then
        local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
        if ok and icon then return icon end
    end
    local getInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if type(getInstant) == "function" then
        local ok, _, _, _, _, icon = pcall(getInstant, itemID)
        if ok and icon then return icon end
    end
    return 134400
end

local function CreateLootButton(row, index)
    row.lootButtons = row.lootButtons or {}
    local button = row.lootButtons[index]
    if button then return button end

    button = CreateFrame("Button", nil, row)
    button:SetSize(94, 22)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(18, 18)
    button.icon:SetPoint("LEFT", button, "LEFT", 1, 0)
    button.count = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.count:SetPoint("LEFT", button.icon, "RIGHT", 2, 0)
    button.count:SetJustifyH("LEFT")
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local shown = false
        if self.itemLink and GameTooltip.SetHyperlink then
            shown = pcall(GameTooltip.SetHyperlink, GameTooltip, self.itemLink)
        end
        if not shown and GameTooltip.SetItemByID then
            shown = pcall(GameTooltip.SetItemByID, GameTooltip, self.itemID)
        end
        if not shown then GameTooltip:SetText(self.itemName or tostring(self.itemID)) end
        if self.samplePicks and self.samplePicks > 0 then
            GameTooltip:AddLine(("Average drop: %.2f items (shown rounded)"):format(self.averageQuantity), 0.8, 0.8, 0.8)
            GameTooltip:AddLine(("%d total in %d drops across %d pockets"):format(
                self.totalQuantity, self.itemHits, self.samplePicks), 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.lootButtons[index] = button
    return button
end

local function RenderLoot(row, items, x, compact, width)
    items = items or {}
    local step = compact and 26 or 96
    local limit = compact and 1 or math.max(1, math.floor((width or 288) / step))
    for index, item in ipairs(items) do
        if index > limit then break end
        local button = CreateLootButton(row, index)
        button:ClearAllPoints()
        button:SetSize(compact and 22 or 94, 22)
        button:SetPoint("LEFT", row, "LEFT", x + (index - 1) * step, 0)
        button.itemID = item.id
        button.itemLink = item.link
        button.itemName = item.name
        button.averageQuantity = item.averageQuantity or 1
        button.totalQuantity = item.count or 0
        button.itemHits = item.hits or 0
        button.samplePicks = item.samplePicks or 0
        button.icon:SetTexture(ItemIcon(item.id))
        local drop = item.dropRate and (" "
            .. math.floor(item.dropRate + 0.5) .. "%") or " --"
        button.count:SetText("x" .. tostring(item.displayedQuantity or 1)
            .. (compact and "" or "/drop" .. drop))
        if compact then button.count:Hide() else button.count:Show() end
        button:Show()
    end
    for index = limit + 1, #(row.lootButtons or {}) do
        row.lootButtons[index]:Hide()
    end
end

local COLUMNS = {
    history = {
                { key = "time", label = "Time", width = 90, ascending = false,
          format = function(v) return type(v) == "number" and date("%m/%d %H:%M", v) or "" end },
                { key = "name", label = "Mark", width = 160 },
                { key = "zone", label = "Haunt", width = 130 },
                { key = "subzone", label = "Spot", width = 165 },
                { key = "outcome", label = "Job", width = 90 },
                { key = "items", label = "Qty", width = 60, ascending = false },
                { key = "copper", label = "Gains", width = 120, ascending = false,
          format = function(v) return ns.Coins(v or 0) end },
    },
    creatures = {
                    { key = "name", label = "Mark", width = 150 },
                    { key = "diff", label = "Diff", width = 65, ascending = true },
                    { key = "picks", label = "Lifts", width = 55, ascending = false },
                    { key = "copper", label = "Gains", width = 90, ascending = false,
          format = function(v) return ns.Coins(v or 0) end },
                    { key = "avgCopper", label = "Avg Purse", width = 90, ascending = false,
                format = function(v) return ns.Coins(v or 0) end },
                    { key = "quantity", label = "Items", width = 55, ascending = false },
                    { key = "loot", label = "Possible Take", width = 300 },
    },
    locations = {
                    { key = "mapID", label = "Map", width = 55, ascending = true },
                    { key = "zone", label = "Haunt", width = 120 },
                    { key = "subzone", label = "Spot", width = 120 },
                    { key = "picks", label = "Lifts", width = 55, ascending = false },
                    { key = "copper", label = "Gains", width = 90, ascending = false,
          format = function(v) return ns.Coins(v or 0) end },
                    { key = "avgCopper", label = "Avg Purse", width = 90, ascending = false,
                format = function(v) return ns.Coins(v or 0) end },
                    { key = "quantity", label = "Items", width = 55, ascending = false },
                    { key = "loot", label = "Possible Take", width = 250 },
        },
        items = {
            { key = "loot", label = "", width = 32 },
                { key = "name", label = "Find", width = 260 },
                { key = "count", label = "Quantity", width = 110, ascending = false },
                { key = "picks", label = "Lifts", width = 110, ascending = false,
                    format = function(v) return type(v) == "number" and v >= 0 and tostring(v) or "--" end },
                { key = "dropRate", label = "Take %", width = 85, ascending = false,
                    format = function(v, row)
                        if type(v) ~= "number" then return "--" end
                        return ("%.1f%%"):format(v)
                    end },
                { key = "last", label = "Last Lift", width = 140, ascending = false,
                    format = function(v) return type(v) == "number" and v > 0 and date("%m/%d %H:%M", v) or "" end },
    },
        containers = {
                { key = "name", label = "Box", width = 180 },
                { key = "openings", label = "Cracked", width = 70, ascending = false },
                { key = "copper", label = "Gains", width = 100, ascending = false,
                    format = function(v) return ns.Coins(v or 0) end },
                { key = "avgCopper", label = "Avg Box", width = 100, ascending = false,
                    format = function(v) return ns.Coins(v or 0) end },
                { key = "quantity", label = "Items", width = 55, ascending = false },
                { key = "loot", label = "Possible Take", width = 260 },
        },
}

local function TabClick(view)
    return function() UI:SetView(view) end
end

local function SortClick(view, key, ascending)
    return function()
        local state = sortState[view]
        if state.key == key then
            state.ascending = not state.ascending
        else
            state.key = key
            state.ascending = ascending ~= false
        end
        UI:RefreshTable()
    end
end

local function GetRows(view)
    local db, rows = Addon.db, {}
    if view == "history" then
        for _, entry in ipairs(db.recent or {}) do
            rows[#rows + 1] = {
                time = entry.t or 0,
                name = entry.name or (entry.npc and tostring(entry.npc)) or "?",
                zone = entry.zone or "",
                subzone = entry.subzone or "",
                outcome = entry.outcome or "Picked",
                items = entry.items or 0,
                copper = entry.copper or 0,
            }
        end
    elseif view == "creatures" then
        for _, entry in pairs(db.npcs or {}) do
            if not entry.pocketless then
                rows[#rows + 1] = {
                    name = entry.name or tostring(entry.npc or "?"),
                    diff = entry.diff or 0,
                    picks = entry.picks or 0,
                    copper = entry.copper or 0,
                    avgCopper = (entry.picks or 0) > 0 and (entry.copper or 0) / entry.picks or 0,
                    quantity = ItemQuantity(entry.items),
                    itemSamplePicks = entry.itemSamplePicks or 0,
                    loot = ItemSummary(entry.items, entry.itemNames, entry.itemLinks,
                        entry.itemPicks, entry.itemSamplePicks or 0, entry.itemRatesApproximate),
                }
            end
        end
    elseif view == "locations" then
        for mapKey, zones in pairs(db.locations or {}) do
            if type(zones) == "table" then
                for zoneKey, subzones in pairs(zones) do
                    if type(subzones) == "table" then
                        for subzoneKey, entry in pairs(subzones) do
                            if type(entry) == "table" then
                                rows[#rows + 1] = {
                                    mapID = entry.mapID or tonumber(mapKey) or 0,
                                    zone = entry.zone or zoneKey,
                                    subzone = entry.subzone or subzoneKey,
                                    picks = entry.picks or 0,
                                    copper = entry.copper or 0,
                                    avgCopper = (entry.picks or 0) > 0
                                        and (entry.copper or 0) / entry.picks or 0,
                                    quantity = ItemQuantity(entry.items),
                                    itemSamplePicks = entry.itemSamplePicks or 0,
                                    loot = ItemSummary(entry.items, entry.itemNames, entry.itemLinks,
                                        entry.itemPicks, entry.itemSamplePicks or 0,
                                        entry.itemRatesApproximate),
                                }
                            end
                        end
                    end
                end
            end
        end
    end
    if view == "containers" then
        for itemKey, entry in pairs(db.containers or {}) do
            if type(entry) == "table" then
                local openings = tonumber(entry.openings) or 0
                rows[#rows + 1] = {
                    id = entry.id or tonumber(itemKey) or 0,
                    name = entry.name or tostring(entry.id or itemKey),
                    openings = openings,
                    copper = entry.copper or 0,
                    avgCopper = openings > 0 and (entry.copper or 0) / openings or 0,
                    quantity = ItemQuantity(entry.items),
                    itemSamplePicks = entry.itemSamplePicks or 0,
                    loot = ItemSummary(entry.items, entry.itemNames, entry.itemLinks,
                        entry.itemPicks, entry.itemSamplePicks or 0),
                }
            end
            end
    end
    if view == "items" then
        for itemKey, entry in pairs(db.items or {}) do
            if type(entry) == "table" then
                rows[#rows + 1] = {
                    id = entry.id or tonumber(itemKey) or 0,
                    name = entry.name or tostring(entry.id or itemKey),
                    count = entry.count or 0,
                    picks = entry.picks or 0,
                    dropRate = (Addon.db.itemSamplePicks or 0) > 0
                        and (entry.picks or 0) / Addon.db.itemSamplePicks * 100 or nil,
                    dropRateApproximate = entry.dropRateApproximate,
                    last = entry.last or 0,
                    loot = { {
                        id = entry.id or tonumber(itemKey) or 0,
                        name = entry.name or tostring(entry.id or itemKey),
                        link = entry.link,
                        count = entry.count or 0,
                    } },
                }
            end
        end
    end
    return rows
end

local function SortRows(rows, sort)
    table.sort(rows, function(a, b)
        local av, bv = a[sort.key], b[sort.key]
        if type(av) == "string" then av = av:lower() end
        if type(bv) == "string" then bv = bv:lower() end
        if av == bv then
            local aTie = tostring(a.name or a.zone or "") .. tostring(a.subzone or "")
            local bTie = tostring(b.name or b.zone or "") .. tostring(b.subzone or "")
            return aTie < bTie
        end
        if av == nil then return false end
        if bv == nil then return true end
        if sort.ascending then return av < bv end
        return av > bv
    end)
end

function UI:Init()
    Addon:RegisterMessage(ns.Events.UI.Toggle, self, "Toggle")
    Addon:RegisterMessage(ns.Events.Loot.PickRecorded, self, "QueueRefreshIfShown")
    Addon:RegisterMessage(ns.Events.Loot.ContainerRecorded, self, "QueueRefreshIfShown")
    Addon:RegisterMessage(ns.Events.History.AttemptRecorded, self, "QueueRefreshIfShown")
    Addon:RegisterMessage(ns.Events.Session.Reset, self, "RefreshIfShown")
    Addon:RegisterMessage(ns.Events.History.Reset, self, "RefreshIfShown")
end

function UI:Create()
    local f = CreateFrame("Frame", "ArtfulDodgerFrame", UIParent, "BackdropTemplate")
    f:SetSize(940, 600)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetResizable(true)
    f:SetResizeBounds(900, 420, 1400, 1200)
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(0, 0, 0, 0.9)
    f:SetBackdropBorderColor(1, 1, 1, 0.5)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("The Artful Dodger's Ledger")

    CreateFrame("Button", nil, f, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -2, -2)

    f.summary = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.summary:SetPoint("TOPLEFT", 14, -40)

    f.tabs = {}
    local tabSpecs = {
        { id = "history", text = "The Take", width = 88 },
        { id = "creatures", text = "Marks", width = 96 },
        { id = "locations", text = "Haunts", width = 96 },
        { id = "items", text = "Goods", width = 76 },
        { id = "containers", text = "Lockboxes", width = 102 },
        { id = "report", text = "Chronicle", width = 78 },
    }
    local tabX = 14
    for _, spec in ipairs(tabSpecs) do
        local tab = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        tab:SetSize(spec.width, 24)
        tab:SetPoint("TOPLEFT", f, "TOPLEFT", tabX, -66)
        tab:SetText(spec.text)
        tab:SetScript("OnClick", TabClick(spec.id))
        f.tabs[spec.id] = tab
        tabX = tabX + spec.width + 4
    end

    f.header = CreateFrame("Frame", nil, f)
    f.header:SetSize(TABLE_WIDTH, 24)
    f.header:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -98)
    f.headerButtons = {}
    for view, columns in pairs(COLUMNS) do
        local buttons, x = {}, 0
        for index, column in ipairs(columns) do
            local button = CreateFrame("Button", nil, f.header, "UIPanelButtonTemplate")
            button:SetSize(column.width, 24)
            button:SetPoint("LEFT", f.header, "LEFT", x, 0)
            button:SetText(column.label)
            button:SetScript("OnClick", SortClick(view, column.key, column.ascending))
            buttons[index] = button
            x = x + column.width
        end
        f.headerButtons[view] = buttons
    end

    f.scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -126)
    f.scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 42)
    f.tableContent = CreateFrame("Frame", nil, f.scroll)
    f.tableContent:SetSize(TABLE_WIDTH, 1)
    f.scroll:SetScrollChild(f.tableContent)
    f.rowPool = {}
    f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    f.empty:SetPoint("TOPLEFT", f.scroll, "TOPLEFT", 10, -10)
    f.empty:SetText("Nothing recorded yet")

    f.tableSummary = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.tableSummary:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 14)
    f.tableSummary:SetJustifyH("LEFT")
    f:SetScript("OnSizeChanged", function(self, width)
        self.tableSummary:SetWidth(math.max(100, width - 180))
    end)

    local resize = CreateFrame("Button", nil, f)
    resize:SetSize(16, 16)
    resize:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resize:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    resize:SetScript("OnMouseUp", function() f:StopMovingOrSizing() end)

    f.reportScroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.reportScroll:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -98)
    f.reportScroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 42)
    f.editBox = CreateFrame("EditBox", nil, f.reportScroll)
    f.editBox:SetMultiLine(true)
    f.editBox:SetFontObject(ChatFontNormal)
    f.editBox:SetWidth(TABLE_WIDTH)
    f.editBox:SetAutoFocus(false)
    f.editBox:SetMaxLetters(0)
    f.editBox:SetTextInsets(4, 4, 4, 4)
    f.editBox:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    f.reportScroll:SetScrollChild(f.editBox)

    local copy = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    copy:SetSize(110, 22); copy:SetPoint("BOTTOMRIGHT", -32, 12)
    copy:SetText("Copy Report")
    f.copyButton = copy
    copy:SetScript("OnClick", function()
        if not f.diagnosticText then UI:SetView("report") end
        f.editBox:SetFocus(); f.editBox:HighlightText()
        if not f.diagnosticText then print(Addon.prefix .. "selected - press Ctrl+C") end
    end)

    f.reportInfo = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.reportInfo:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 16)
    f.reportInfo:SetPoint("RIGHT", copy, "LEFT", -10, 0)
    f.reportInfo:SetJustifyH("LEFT")
    f.reportInfo:SetWordWrap(false)

    return f
end

function UI:Refresh()
    frame = frame or self:Create()
    if not frame.initialized then
        frame.initialized = true
        self:SetView(activeView)
    end
    frame.summary:SetText(ns.Stats:GetPrettyPrintTotalLootedString()
        .. "    " .. ns.Stats:GetPrettyPrintSessionLootedString())
    if activeView == "report" then
        frame.reportInfo:SetText(ns.Stats:GetReportMetadata())
        frame.editBox:SetText(table.concat(ns.Stats:BuildReport(), "\n"))
        frame.editBox:SetCursorPosition(0)
    else
        self:RefreshTable()
    end
end

function UI:SetView(view)
    frame = frame or self:Create()
    activeView = view
    frame.diagnosticText = false
    frame.copyButton:SetText("Copy Report")
    local isReport = view == "report"
    if isReport then
        frame.header:Hide()
        frame.scroll:Hide()
        frame.reportScroll:Show()
        frame.tableSummary:Hide()
        frame.reportInfo:Show()
    else
        frame.header:Show()
        frame.scroll:Show()
        frame.reportScroll:Hide()
        frame.tableSummary:Show()
        frame.reportInfo:Hide()
    end
    for id, buttons in pairs(frame.headerButtons) do
        local columns = COLUMNS[id]
        local state = sortState[id]
        for index, button in ipairs(buttons) do
            local column = columns[index]
            local marker = state.key == column.key and (state.ascending and " ^" or " v") or ""
            button:SetText(column.label .. marker)
        end
        if id == view then
            for _, button in ipairs(buttons) do button:Show() end
        else
            for _, button in ipairs(buttons) do button:Hide() end
        end
    end
    for id, tab in pairs(frame.tabs) do
        tab:SetAlpha(id == view and 1 or 0.75)
    end
    if isReport then self:Refresh() else self:RefreshTable() end
end

function UI:ShowText(text)
    frame = frame or self:Create()
    self:SetView("report")
    frame.diagnosticText = true
    frame.copyButton:SetText("Select Text")
    frame.reportInfo:Hide()
    frame.editBox:SetText(text)
    frame.editBox:SetCursorPosition(0)
    frame:Show()
    frame.editBox:SetFocus()
    frame.editBox:HighlightText()
end

function UI:RefreshTable()
    if not frame or activeView == "report" then return end

    local columns = COLUMNS[activeView]
    local sort = sortState[activeView]
    for index, button in ipairs(frame.headerButtons[activeView]) do
        local column = columns[index]
        local marker = sort.key == column.key and (sort.ascending and " ^" or " v") or ""
        button:SetText(column.label .. marker)
    end

    local rows = GetRows(activeView)
    SortRows(rows, sort)
    frame.tableContent:SetHeight(math.max(1, #rows * ROW_HEIGHT))
    local totalPicks, totalCopper, totalItems, samplePicks = 0, 0, 0, 0
    local approximateRates = false
    for _, data in ipairs(rows) do
        totalPicks = totalPicks + (data.picks or 0)
        totalCopper = totalCopper + (data.copper or 0)
        totalItems = totalItems + (data.quantity or data.count or 0)
        samplePicks = samplePicks + (data.itemSamplePicks or 0)
        if data.itemRatesApproximate then approximateRates = true end
    end
    local averageCopper = totalPicks > 0 and totalCopper / totalPicks or 0
    if activeView == "creatures" or activeView == "locations" then
        frame.tableSummary:SetText(("Ledger: %d lifts  |  %d items  |  %s gains  |  %s purse/lift  |  rates from %d picks%s")
            :format(totalPicks, totalItems, ns.Coins(totalCopper), ns.Coins(averageCopper),
                samplePicks, approximateRates and " (estimated)" or ""))
    elseif activeView == "containers" then
        local openings = 0
        for _, data in ipairs(rows) do openings = openings + (data.openings or 0) end
        frame.tableSummary:SetText(("Lockboxes cracked: %d  |  %d items  |  %s copper")
            :format(openings, totalItems, ns.Coins(totalCopper)))
    elseif activeView == "items" then
        local hasApproximateRates = false
        for _, item in pairs(Addon.db.items or {}) do
            if item.dropRateApproximate then hasApproximateRates = true; break end
        end
        frame.tableSummary:SetText(("Item sample: %d pocket lifts%s")
            :format(Addon.db.itemSamplePicks or 0,
                hasApproximateRates and " (legacy rates estimated)" or ""))
    else
        frame.tableSummary:SetText("Recent jobs, including attempts with no take")
    end
    if activeView == "creatures" then
        frame.empty:SetText("No pockets lifted from these marks yet")
    elseif activeView == "items" then
        frame.empty:SetText("No goods recorded yet")
    elseif activeView == "containers" then
        frame.empty:SetText("No lockboxes cracked yet")
    else
        frame.empty:SetText("Nothing recorded yet")
    end
    if #rows == 0 then frame.empty:Show() else frame.empty:Hide() end

    for rowIndex, data in ipairs(rows) do
        local row = frame.rowPool[rowIndex]
        if not row then
            row = CreateFrame("Button", nil, frame.tableContent)
            row:SetHeight(ROW_HEIGHT)
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints(row)
            row.hover = row:CreateTexture(nil, "HIGHLIGHT")
            row.hover:SetAllPoints(row)
            row.hover:SetColorTexture(0.35, 0.55, 0.5, 0.15)
            row.cells = {}
            for cellIndex = 1, MAX_COLUMNS do
                local cell = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                cell:SetJustifyH("LEFT")
                cell:SetWordWrap(false)
                row.cells[cellIndex] = cell
            end
            row.lootButtons = {}
            frame.rowPool[rowIndex] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame.tableContent, "TOPLEFT", 0, -(rowIndex - 1) * ROW_HEIGHT)
        row:SetWidth(TABLE_WIDTH)
        row.bg:SetColorTexture(0, 0, 0, rowIndex % 2 == 0 and 0.28 or 0.12)
        row:Show()
        for _, button in ipairs(row.lootButtons or {}) do button:Hide() end

        local x = 0
        for columnIndex, column in ipairs(columns) do
            local cell = row.cells[columnIndex]
            cell:ClearAllPoints()
            cell:SetPoint("LEFT", row, "LEFT", x + 7, 0)
            cell:SetWidth(column.width - 12)
            local value = data[column.key]
            if column.key == "loot" then
                cell:SetText("")
                RenderLoot(row, value, x + 7, activeView == "items")
            else
                cell:SetText(column.format and column.format(value, data) or tostring(value or ""))
            end
            cell:Show()
            x = x + column.width
        end
        for columnIndex = #columns + 1, MAX_COLUMNS do
            row.cells[columnIndex]:Hide()
        end
    end
    for rowIndex = #rows + 1, #frame.rowPool do
        frame.rowPool[rowIndex]:Hide()
    end
end

function UI:Show()
    frame = frame or self:Create()
    self:Refresh()
    frame:Show()
end

function UI:RefreshIfShown()
    refreshGeneration = refreshGeneration + 1
    refreshPending = false
    if frame and frame:IsShown() then self:Refresh() end
end

function UI:QueueRefreshIfShown()
    if not frame or not frame:IsShown() or refreshPending then return end

    refreshPending = true
    local generation = refreshGeneration
    C_Timer.After(0, function()
        if generation ~= refreshGeneration then return end
        refreshPending = false
        UI:RefreshIfShown()
    end)
end

function UI:Toggle()
    if frame and frame:IsShown() then frame:Hide() else self:Show() end
end

-- addon compartment (replaces LibDataBroker + LibDBIcon)
function _G.ArtfulDodger_OnCompartmentClick()  ns.UI:Toggle() end
function _G.ArtfulDodger_OnCompartmentEnter(_, button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText("The Artful Dodger's Ledger")
    GameTooltip:AddLine("Click to open", 1, 1, 1)
    GameTooltip:Show()
end
function _G.ArtfulDodger_OnCompartmentLeave() GameTooltip:Hide() end
