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
    if low then low:SetText(tostring(minValue)) end
    local high = _G[name .. "High"]
    if high then high:SetText(tostring(maxValue)) end

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

    CreateLabel(panel, panel.name, "GameFontNormalLarge",
        "TOPLEFT", panel, "TOPLEFT", 24, -24)
    CreateLabel(panel, "Display", "GameFontNormal",
        "TOPLEFT", panel, "TOPLEFT", 28, -64)

    local tooltipCheckbox = CreateCheckbox(panel, "Show pickpocket status in unit tooltips", "tooltip", -86)
    local targetBadgeCheckbox = CreateCheckbox(panel, "Show target-frame badge", "targetBadge", -116)
    local targetPosition = CreateDropdown(panel, "Target badge position", "targetBadgePosition", DIRECTIONS, -146)
    local targetIconSize = CreateSlider(panel, "ADLTargetBadgeIconSizeSlider", "targetBadgeIconSize", "Target badge icon size", 8, 32, -188)
    local targetPadding = CreateSlider(panel, "ADLTargetBadgePaddingSlider", "targetBadgePadding", "Target badge spacing", -32, 32, -232)
    local nameplateBadgeCheckbox = CreateCheckbox(panel, "Show nameplate badges", "nameplateBadge", -280)
    local nameplatePosition = CreateDropdown(panel, "Nameplate badge position", "nameplateBadgePosition", DIRECTIONS, -310)
    local nameplateIconSize = CreateSlider(panel, "ADLNameplateBadgeIconSizeSlider", "nameplateBadgeIconSize", "Nameplate badge icon size", 8, 32, -352)
    local nameplatePadding = CreateSlider(panel, "ADLNameplateBadgePaddingSlider", "nameplateBadgePadding", "Nameplate badge spacing", -32, 32, -396)
    local copperCheckbox = CreateCheckbox(panel, "Show average pickpocket copper in unit tooltips", "tooltipCopper", -446)
    local itemsCheckbox = CreateCheckbox(panel, "Show possible pickpocket items and drop rates", "tooltipItems", -476)
    local mapCheckbox = CreateCheckbox(panel, "Show pickpocket details on the world map", "worldMap", -506)
    CreateLabel(panel, "Utilities", "GameFontNormal",
        "TOPLEFT", panel, "TOPLEFT", 28, -554)
    local openerCheckbox = CreateCheckbox(panel, "Show lockbox and junkbox opener", "lockboxOpener", -574)

    CreateLabel(panel, "Data", "GameFontNormal",
        "TOPLEFT", panel, "TOPLEFT", 28, -620)
    CreateButton(panel, "Reset Session", 28, -640, function()
        StaticPopup_Show(SESSION_RESET)
    end)
    CreateButton(panel, "Clear History", 230, -640, function()
        StaticPopup_Show(HISTORY_RESET)
    end)

    panel:SetScript("OnShow", function()
        tooltipCheckbox:SetChecked(Addon.db.settings.tooltip)
        targetBadgeCheckbox:SetChecked(Addon.db.settings.targetBadge)
        nameplateBadgeCheckbox:SetChecked(Addon.db.settings.nameplateBadge)
        UIDropDownMenu_SetText(targetPosition, ChoiceLabel(DIRECTIONS, Addon.db.settings.targetBadgePosition))
        UIDropDownMenu_SetText(nameplatePosition, ChoiceLabel(DIRECTIONS, Addon.db.settings.nameplateBadgePosition))
        targetIconSize:SetValue(Addon.db.settings.targetBadgeIconSize)
        targetPadding:SetValue(Addon.db.settings.targetBadgePadding)
        nameplateIconSize:SetValue(Addon.db.settings.nameplateBadgeIconSize)
        nameplatePadding:SetValue(Addon.db.settings.nameplateBadgePadding)
        copperCheckbox:SetChecked(Addon.db.settings.tooltipCopper)
        itemsCheckbox:SetChecked(Addon.db.settings.tooltipItems)
        mapCheckbox:SetChecked(Addon.db.settings.worldMap)
        openerCheckbox:SetChecked(Addon.db.settings.lockboxOpener)
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    self.category = category
end