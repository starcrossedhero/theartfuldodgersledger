--==============================================================
--  ui/ArtfulDodger_Badges.lua
--  Target frame + nameplate badge.
--  Reads spawn state only; never writes to it. Loads after Core
--  so ns.Addon and ns.Readable exist.
--==============================================================
local _, ns = ...
local Addon = ns.Addon
if not Addon then return end

local Badges = {}
ns.Badges = Badges

local TEXT  = { robbed = ns.Voice.emptied }
local COLOR = { robbed = { 0.60, 0.60, 0.60 } }

-- nameplate frames are recycled; cache one fontstring per parent frame
local attached = setmetatable({}, { __mode = "k" })
local icons = setmetatable({}, { __mode = "k" })
local cooldowns = setmetatable({}, { __mode = "k" })
local pickpocketIcon = "Interface\\Icons\\Ability_Sap"
if C_Spell and type(C_Spell.GetSpellTexture) == "function" then
    local ok, texture = pcall(C_Spell.GetSpellTexture, ns.ClientCompatibility.pickpocketSpellID)
    if ok and texture then pickpocketIcon = texture end
end

--========== state lookup ==========
local function GetState(unit)
    return Addon:GetPickpocketState(unit)
end

local function BadgeFor(parent, point, relativePoint, x, y)
    local fs = attached[parent]
    if not fs then
        fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        attached[parent] = fs
    end
    fs:ClearAllPoints()
    fs:SetPoint(point, parent, relativePoint, x, y)
    return fs
end

local function Hide(parent)
    local fs = parent and attached[parent]
    if fs then fs:Hide() end
    local icon = parent and icons[parent]
    if icon then icon:Hide() end
    local cooldown = parent and cooldowns[parent]
    if cooldown then cooldown:Hide() end
end

local function Apply(fs, state)
    if state == "likely" then
        if fs then fs:Hide() end
        return
    end
    local label = state and TEXT[state]
    if not label then
        if fs then fs:Hide() end
        return
    end
    local c = COLOR[state]
    fs:SetText(label)
    fs:SetTextColor(c[1], c[2], c[3])
    fs:Show()
end

local function IconFor(parent, point, relativePoint, x, y, configuredSize)
    local icon = icons[parent]
    if not icon then
        icon = parent:CreateTexture(nil, "OVERLAY")
        icons[parent] = icon
    end
    local size = tonumber(configuredSize) or 16
    size = math.max(8, math.min(32, size))
    icon:SetSize(size, size)
    icon:ClearAllPoints()
    icon:SetPoint(point, parent, relativePoint, x, y)
    icon:SetTexture(pickpocketIcon)
    return icon
end

local function CooldownFor(parent, icon)
    local cooldown = cooldowns[parent]
    if not cooldown then
        cooldown = CreateFrame("Cooldown", nil, parent, "CooldownFrameTemplate")
        cooldown:SetAllPoints(icon)
        if cooldown.SetHideCountdownNumbers then
            cooldown:SetHideCountdownNumbers(false)
        end
        cooldowns[parent] = cooldown
    end
    return cooldown
end

local function BadgeAnchor(position, padding)
    padding = tonumber(padding) or 2
    padding = math.max(-32, math.min(32, padding))
    if position == "TOP" then return "BOTTOM", "TOP", 0, padding end
    if position == "BOTTOM" then return "TOP", "BOTTOM", 0, -padding end
    if position == "LEFT" then return "RIGHT", "LEFT", -padding, 0 end
    return "LEFT", "RIGHT", padding, 0
end

local function SetBadge(parent, unit, enabledKey, positionKey, sizeKey, paddingKey)
    local settings = Addon.db and Addon.db.settings
    if not parent then return end
    if not settings or not settings[enabledKey] then Hide(parent); return end
    if not unit then Hide(parent); return end
    local point, relativePoint, x, y = BadgeAnchor(settings[positionKey], settings[paddingKey])
    local state, remaining, duration = GetState(unit)
    if state == "likely" then
        local fs = attached[parent]
        if fs then fs:Hide() end
        local cooldown = cooldowns[parent]
        if cooldown then cooldown:Hide() end
        IconFor(parent, point, relativePoint, x, y, settings[sizeKey]):Show()
        return
    end
    if state == "cooldown" then
        local fs = attached[parent]
        if fs then fs:Hide() end
        local icon = IconFor(parent, point, relativePoint, x, y, settings[sizeKey])
        icon:Show()
        local cooldown = CooldownFor(parent, icon)
        cooldown:SetCooldown(GetTime() - (duration - remaining), duration)
        cooldown:Show()
        return
    end
    local cooldown = cooldowns[parent]
    if cooldown then cooldown:Hide() end
    local icon = icons[parent]
    if icon then icon:Hide() end
    if state == "robbed" then
        Apply(BadgeFor(parent, point, relativePoint, x, y), state)
    else
        local fs = attached[parent]
        if fs then fs:Hide() end
    end
end

--========== plates ==========
local function PlateFrame(unit)
    local np = C_NamePlate and C_NamePlate.GetNamePlateForUnit(unit)
    if not np then return nil end
    return np.UnitFrame or np          -- consistent key for cache + hide
end

function Badges:RefreshPlate(unit)
    local parent = PlateFrame(unit)
    if not parent then return end
    SetBadge(parent, unit, "nameplateBadge", "nameplateBadgePosition",
        "nameplateBadgeIconSize", "nameplateBadgePadding")
end

function Badges:HidePlate(unit)
    Hide(PlateFrame(unit))
end

--========== target ==========
local function RefreshTarget()
    if not TargetFrame then return end
    if not UnitExists("target") then Hide(TargetFrame); return end
    SetBadge(TargetFrame, "target", "targetBadge", "targetBadgePosition",
        "targetBadgeIconSize", "targetBadgePadding")
end

local function RefreshCurrent()
    RefreshTarget()
    if UnitExists("target") then Badges:RefreshPlate("target") end
    if UnitExists("mouseover") then Badges:RefreshPlate("mouseover") end
end

local function RefreshAllPlates()
    if not (C_NamePlate and C_NamePlate.GetNumNameplateNodes) then return end
    local ok, n = pcall(C_NamePlate.GetNumNameplateNodes)
    if not ok or not n then return end
    for i = 1, n do
        local ok2, plat = pcall(C_NamePlate.GetNamePlateNodeByIndex, i)
        local uf = ok2 and plat and plat.Unit
        if uf and type(uf.GetUnit) == "function" then
            local ok3, unit = pcall(uf.GetUnit, uf)
            if ok3 and unit then Badges:RefreshPlate(unit) end
        end
    end
end

--========== events ==========
local function HandleEvent(event, arg1)
    if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        RefreshCurrent()
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        Badges:RefreshPlate(arg1)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        Badges:HidePlate(arg1)
    elseif event == "UNIT_FLAGS" or event == "UNIT_FACTION" then
        if arg1 == "target" then
            RefreshTarget()
            Badges:RefreshPlate(arg1)
        elseif type(arg1) == "string" and arg1:match("^nameplate%d+$") then
            Badges:RefreshPlate(arg1)
        end
    elseif event == "UI_ERROR_MESSAGE" then
        C_Timer.After(0.1, function()      -- let Core learn pocketlessness first
            RefreshTarget()
            RefreshAllPlates()
        end)
    end
end

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(_, event, arg1)
    local ok, err = pcall(HandleEvent, event, arg1)
    if not ok and not Badges.errored then
        Badges.errored = true
        Addon:Print("|cffff2020badge error|r " .. tostring(err))
    end
end)


function Badges:Init()
    for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD",
                         "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
                         "UNIT_FLAGS", "UNIT_FACTION",
                         "UI_ERROR_MESSAGE" }) do
        f:RegisterEvent(e)
    end
    Addon:RegisterMessage(ns.Events.Loot.PickRecorded, self, "OnPickRecorded")
    RefreshCurrent()
    Addon:Print("badges ready")
end

function Badges:OnPickRecorded(rec)
    RefreshCurrent()
    RefreshAllPlates()
    if not rec then return end

    local duration = Addon:GetPocketRefreshSeconds(rec.npc, rec.diff, rec.mapID)
    C_Timer.After(duration + 0.25, function()
        RefreshCurrent()
        RefreshAllPlates()
    end)
end

function Badges:Refresh()
    RefreshCurrent()
    RefreshAllPlates()
end