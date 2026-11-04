local _, ns = ...
local Addon = ns.Addon
if not Addon then return end

local Opener = {}
ns.Opener = Opener

local PICK_LOCK_SPELL_ID = 1804
local PICK_LOCK_SPELL_NAME = "Pick Lock"
local button
local countText
local tooltip
local current
local boxes = {}
local unlockedKey
local unlockedItemID

local function ItemIsLocked(bagID, slotID)
    tooltip:ClearLines()
    tooltip:SetBagItem(bagID, slotID)
    local lockedText = type(_G.LOCKED) == "string" and _G.LOCKED or "Locked"
    local lockedSearch = string.lower(lockedText)
    for _, region in ipairs({ tooltip:GetRegions() }) do
        if region:IsObjectType("FontString") then
            local text = region:GetText()
            if type(text) == "string" then
                local line = string.lower(text)
                if line:find(lockedSearch, 1, true)
                    or line:find("requires lockpicking", 1, true) then
                    return true
                end
            end
        end
    end
    return false
end

local function IsRestrictedLocation()
    local _, instanceType = IsInInstance()
    return instanceType == "pvp" or instanceType == "arena"
end

local function SetPosition()
    local position = Addon.db.settings.lockboxOpenerPosition
    button:ClearAllPoints()
    button:SetPoint("CENTER", UIParent, "CENTER", position.x, position.y)
end

local function SetAction(box)
    if not box then
        button:SetAttribute("type", nil)
        button:SetAttribute("spell", nil)
        button:SetAttribute("item", nil)
        button:SetAttribute("target-bag", nil)
        button:SetAttribute("target-slot", nil)
        return
    end

    if box.locked then
        button:SetAttribute("type", "spell")
        button:SetAttribute("spell", PICK_LOCK_SPELL_NAME)
        button:SetAttribute("target-bag", box.bagID)
        button:SetAttribute("target-slot", box.slotID)
        button:SetAttribute("item", nil)
    else
        button:SetAttribute("type", "item")
        button:SetAttribute("item", ("%d %d"):format(box.bagID, box.slotID))
        button:SetAttribute("spell", nil)
        button:SetAttribute("target-bag", nil)
        button:SetAttribute("target-slot", nil)
    end
end

local function FindBoxes()
    local found = {}
    local firstBag = Enum and Enum.BagIndex and Enum.BagIndex.Backpack or BACKPACK_CONTAINER or 0
    local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4
    for bagID = firstBag, lastBag do
        for slotID = 1, C_Container.GetContainerNumSlots(bagID) do
            local itemID = C_Container.GetContainerItemID(bagID, slotID)
            if itemID and ns.ContainerItemIDs[itemID] then
                local key = ("%d:%d"):format(bagID, slotID)
                local info = C_Container.GetContainerItemInfo(bagID, slotID)
                local locked = ItemIsLocked(bagID, slotID)
                if key == unlockedKey and itemID == unlockedItemID then
                    locked = false
                end
                found[#found + 1] = {
                    key = key,
                    bagID = bagID,
                    slotID = slotID,
                    itemID = itemID,
                    icon = info and info.iconFileID,
                    locked = locked,
                }
            end
        end
    end
    return found
end

local function CanShow()
    return Addon.db.settings.lockboxOpener
        and not InCombatLockdown()
        and not IsRestrictedLocation()
end

local function RefreshTooltip()
    if not button or not button:IsMouseOver() then return end
    if not current then
        GameTooltip:Hide()
        return
    end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:SetBagItem(current.bagID, current.slotID)
    GameTooltip:AddLine("Left-click to " .. (current.locked and "pick the lock" or "open the box"))
    GameTooltip:AddLine("Right-click and drag to move")
    GameTooltip:Show()
end

function Opener:Refresh()
    if not button or InCombatLockdown() then return end

    boxes = FindBoxes()
    current = boxes[1]
    if not current then
        SetAction(nil)
        RefreshTooltip()
        button:Hide()
        return
    end

    SetAction(current)
    button:SetNormalTexture(current.icon or 134400)
    countText:SetText(tostring(#boxes))
    button:SetShown(CanShow())
    RefreshTooltip()
end

function Opener:OnContainerRecorded()
    self:Refresh()
end

local function HandleEvent(event, unit, _, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit == "player" and spellID == PICK_LOCK_SPELL_ID and current then
            unlockedKey = current.key
            unlockedItemID = current.itemID
            current.locked = false
            Opener:Refresh()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        button:Hide()
    elseif event == "LOOT_CLOSED" then
        C_Timer.After(0.1, function() Opener:Refresh() end)
    elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_REGEN_ENABLED"
        or event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        Opener:Refresh()
    end
end

function Opener:Init()
    tooltip = CreateFrame("GameTooltip", "ADLOpenerTooltip", UIParent, "GameTooltipTemplate")
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")

    button = CreateFrame("Button", "ADLOpenerButton", UIParent, "InsecureActionButtonTemplate")
    button:SetSize(48, 48)
    button:SetFrameStrata("DIALOG")
    button:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
    button:RegisterForDrag("RightButton")
    button:SetMovable(true)
    button:SetClampedToScreen(true)

    button:SetScript("PreClick", function()
        if not current or current.locked then return end
        local pending = { itemID = current.itemID, at = GetTime() }
        Addon.pendingContainerOpen = pending
        C_Timer.After(5, function()
            if Addon.pendingContainerOpen == pending then
                Addon.pendingContainerOpen = nil
            end
        end)
    end)

    countText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)

    button:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() then self:StartMoving() end
    end)
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local position = Addon.db.settings.lockboxOpenerPosition
        local centerX, centerY = self:GetCenter()
        position.x = centerX - UIParent:GetWidth() / 2
        position.y = centerY - UIParent:GetHeight() / 2
        SetPosition()
    end)
    button:SetScript("OnEnter", function(self)
        if not current then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:SetBagItem(current.bagID, current.slotID)
        GameTooltip:AddLine("Left-click to " .. (current.locked and "pick the lock" or "open the box"))
        GameTooltip:AddLine("Right-click and drag to move")
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    SetPosition()
    local events = CreateFrame("Frame")
    events:SetScript("OnEvent", function(_, event, ...)
        HandleEvent(event, ...)
    end)
    for _, event in ipairs({
        "BAG_UPDATE_DELAYED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "UNIT_SPELLCAST_SUCCEEDED",
        "LOOT_CLOSED",
    }) do
        events:RegisterEvent(event)
    end
    Addon:RegisterMessage(ns.Events.Loot.ContainerRecorded, self, "OnContainerRecorded")
    self:Refresh()
end