local _, ns = ...
local Addon = ns.Addon
if not Addon then return end

local Options = {}
ns.Options = Options

local SESSION_RESET = "ADL_CONFIRM_SESSION_RESET"
local HISTORY_RESET = "ADL_CONFIRM_HISTORY_RESET"

local function CreateLabel(parent, text, template, point, relativeTo, relativePoint, x, y)
    local label = parent:CreateFontString(nil, "ARTWORK", template)
    label:SetPoint(point, relativeTo, relativePoint, x, y)
    label:SetText(text)
    return label
end

local function CreateCheckbox(parent, text, key, y)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetSize(26, 26)
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", 28, y)
    checkbox:SetChecked(Addon.db.settings[key])

    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
    label:SetText(text)

    checkbox:SetScript("OnClick", function(self)
        Addon.db.settings[key] = self:GetChecked()
        if (key == "targetBadge" or key == "nameplateBadge") and ns.Badges then
            ns.Badges:Refresh()
        end
        if key == "lockboxOpener" and ns.Opener then ns.Opener:Refresh() end
        if key == "worldMap" and ns.Map then ns.Map:Refresh() end
    end)
    return checkbox
end

local DIRECTIONS = {
    { value = "TOP", label = "Top" },
    { value = "BOTTOM", label = "Bottom" },
    { value = "LEFT", label = "Left" },
    { value = "RIGHT", label = "Right" },
}
local function ChoiceLabel(choices, selectedValue)
    for _, choice in ipairs(choices) do
        if choice.value == selectedValue then return choice.label end
    end
    return choices[1].label
end

local function CreateDropdown(parent, text, key, choices, y)
    CreateLabel(parent, text, "GameFontHighlight", "TOPLEFT", parent, "TOPLEFT", 28, y)
    local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 145, y + 6)
    UIDropDownMenu_SetWidth(dropdown, 120)
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        for _, choice in ipairs(choices) do
            local selectedValue = choice.value
            local selectedLabel = choice.label
            local info = UIDropDownMenu_CreateInfo()
            info.text = selectedLabel
            info.checked = Addon.db.settings[key] == selectedValue
            info.func = function()
                Addon.db.settings[key] = selectedValue
                UIDropDownMenu_SetText(dropdown, selectedLabel)
                if ns.Badges then ns.Badges:Refresh() end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetText(dropdown, ChoiceLabel(choices, Addon.db.settings[key]))
    return dropdown
end

local function CreateSlider(parent, name, key, label, minValue, maxValue, y)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetWidth(260)
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 28, y)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    local title = _G[name .. "Text"]
    if title then title:SetText(label) end
    local low = _G[name .. "Low"]
    if low then low:SetText("-") end
    local high = _G[name .. "High"]
    if high then high:SetText("+") end

    local function UpdateValue(value)
        value = math.floor(value + 0.5)
        Addon.db.settings[key] = value
        if title then title:SetText(label .. ": " .. value) end
        if ns.Badges then ns.Badges:Refresh() end
    end
    slider:SetScript("OnValueChanged", function(_, value) UpdateValue(value) end)
    slider:SetValue(Addon.db.settings[key])
    return slider
end

local function CreateButton(parent, text, x, y, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(190, 26)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function RegisterDialogs()
    StaticPopupDialogs[SESSION_RESET] = {
        text = "Reset this play session's statistics?",
        button1 = YES,
        button2 = CANCEL,
        OnAccept = function()
            Addon:SendMessage(ns.Events.Session.Reset)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopupDialogs[HISTORY_RESET] = {
        text = "Clear all recorded history and reset the current session? This cannot be undone.",
        button1 = YES,
        button2 = CANCEL,
        OnAccept = function()
            Addon:SendMessage(ns.Events.History.Reset)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

function Options:Init()
    if not (Settings and Settings.RegisterCanvasLayoutCategory
        and Settings.RegisterAddOnCategory) then
        Addon:Print("Settings API unavailable; options page not registered")
        return
    end

    RegisterDialogs()

    local panel = CreateFrame("Frame")
    panel.name = "The Artful Dodger's Ledger"

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    content:SetSize(1, 760)
    scroll:SetScrollChild(content)
    local function ResizeContent(self)
        content:SetWidth(math.max(1, self:GetWidth()))
    end
    scroll:SetScript("OnSizeChanged", ResizeContent)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local position = self:GetVerticalScroll() - delta * 40
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), position)))
    end)
    ResizeContent(scroll)

    CreateLabel(content, panel.name, "GameFontNormalLarge",
        "TOPLEFT", content, "TOPLEFT", 24, -24)
    CreateLabel(content, "Display", "GameFontNormal",
        "TOPLEFT", content, "TOPLEFT", 28, -64)

    local tooltipCheckbox = CreateCheckbox(content, "Show pickpocket status in unit tooltips", "tooltip", -86)
    local targetBadgeCheckbox = CreateCheckbox(content, "Show target-frame pickpocket badge", "targetBadge", -116)
    local targetPosition = CreateDropdown(content, "Target-frame badge anchor", "targetBadgePosition", DIRECTIONS, -146)
    local targetIconSize = CreateSlider(content, "ADLTargetBadgeIconSizeSlider", "targetBadgeIconSize", "Target-frame badge size", 8, 32, -188)
    local targetHorizontalOffset = CreateSlider(content, "ADLTargetBadgeHorizontalOffsetSlider", "targetBadgeHorizontalOffset", "Target-frame badge horizontal offset", -32, 32, -232)
    local targetVerticalOffset = CreateSlider(content, "ADLTargetBadgeVerticalOffsetSlider", "targetBadgeVerticalOffset", "Target-frame badge vertical offset", -32, 32, -266)
    local nameplateBadgeCheckbox = CreateCheckbox(content, "Show nameplate pickpocket badges", "nameplateBadge", -314)
    local nameplatePosition = CreateDropdown(content, "Nameplate badge anchor", "nameplateBadgePosition", DIRECTIONS, -344)
    local nameplateIconSize = CreateSlider(content, "ADLNameplateBadgeIconSizeSlider", "nameplateBadgeIconSize", "Nameplate badge size", 8, 32, -386)
    local nameplateHorizontalOffset = CreateSlider(content, "ADLNameplateBadgeHorizontalOffsetSlider", "nameplateBadgeHorizontalOffset", "Nameplate badge horizontal offset", -32, 32, -430)
    local nameplateVerticalOffset = CreateSlider(content, "ADLNameplateBadgeVerticalOffsetSlider", "nameplateBadgeVerticalOffset", "Nameplate badge vertical offset", -32, 32, -464)
    local copperCheckbox = CreateCheckbox(content, "Show average pickpocket copper in unit tooltips", "tooltipCopper", -514)
    local itemsCheckbox = CreateCheckbox(content, "Show past pickpocket loot and drop rates in unit tooltips", "tooltipItems", -544)
    local mapCheckbox = CreateCheckbox(content, "Show pickpocket statistics on the world map", "worldMap", -574)
    CreateLabel(content, "Utilities", "GameFontNormal",
        "TOPLEFT", content, "TOPLEFT", 28, -622)
    local openerCheckbox = CreateCheckbox(content, "Show lockbox and junkbox opener", "lockboxOpener", -642)

    CreateLabel(content, "Data", "GameFontNormal",
        "TOPLEFT", content, "TOPLEFT", 28, -688)
    CreateButton(content, "Reset Session", 28, -708, function()
        StaticPopup_Show(SESSION_RESET)
    end)
    CreateButton(content, "Clear History", 230, -708, function()
        StaticPopup_Show(HISTORY_RESET)
    end)

    panel:SetScript("OnShow", function()
        tooltipCheckbox:SetChecked(Addon.db.settings.tooltip)
        targetBadgeCheckbox:SetChecked(Addon.db.settings.targetBadge)
        nameplateBadgeCheckbox:SetChecked(Addon.db.settings.nameplateBadge)
        UIDropDownMenu_SetText(targetPosition, ChoiceLabel(DIRECTIONS, Addon.db.settings.targetBadgePosition))
        UIDropDownMenu_SetText(nameplatePosition, ChoiceLabel(DIRECTIONS, Addon.db.settings.nameplateBadgePosition))
        targetIconSize:SetValue(Addon.db.settings.targetBadgeIconSize)
        targetHorizontalOffset:SetValue(Addon.db.settings.targetBadgeHorizontalOffset)
        targetVerticalOffset:SetValue(Addon.db.settings.targetBadgeVerticalOffset)
        nameplateIconSize:SetValue(Addon.db.settings.nameplateBadgeIconSize)
        nameplateHorizontalOffset:SetValue(Addon.db.settings.nameplateBadgeHorizontalOffset)
        nameplateVerticalOffset:SetValue(Addon.db.settings.nameplateBadgeVerticalOffset)
        copperCheckbox:SetChecked(Addon.db.settings.tooltipCopper)
        itemsCheckbox:SetChecked(Addon.db.settings.tooltipItems)
        mapCheckbox:SetChecked(Addon.db.settings.worldMap)
        openerCheckbox:SetChecked(Addon.db.settings.lockboxOpener)
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    self.category = category
end