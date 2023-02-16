local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local Opener = Addon:NewModule("ArtfulDodger_JunkboxOpener", "AceEvent-3.0")
local Loot = Addon.Loot
local AceGUI = LibStub("AceGUI-3.0")

local frame = CreateFrame("Button", "ArtfulDodger_JunkboxOpener", nil, "InsecureActionButtonTemplate")
frame:SetSize(50, 50)
frame:EnableMouse(true)
frame:RegisterForClicks("RightButtonUp", "RightButtonDown")
frame:RegisterForDrag("LeftButton")
frame:SetScript("PostClick", function(self, button, down) 
    if button == "RightButton" and down == false then
        if frame.isLocked == true then
            Opener.Junkboxes[self.bagSlot].state.locked = false
            frame.isLocked = false
        else
            Opener.Junkboxes[self.bagSlot] = nil
            self.bagSlot = nil
            self.isLocked = nil
        end
        Opener:Next()
    end
end)
frame:SetMovable(true)
frame:SetScript("OnDragStart", function(self, button)
    self:StartMoving()
end)
frame:SetScript("OnDragStop", function(self, button)
    self:StopMovingOrSizing()
    Opener.settings.position.top = self:GetTop()
    Opener.settings.position.left = self:GetLeft()
end)
frame:Hide()

local tooltip = CreateFrame("GameTooltip", "ArtfulDodger_JunkboxTooltip", nil, "GameTooltipTemplate")
tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

Opener.Junkboxes = {}

function Opener:OnInitialize()
    self.settings = Addon.db.settings.opener
    if self.settings.enabled then
        self:init()
        self:UpdateBag(nil, 0)
    end
    Opener:RegisterMessage("ArtfulDodger_ToggleOpener", "Toggle")
end

function Opener:init()
    if self.settings.position.top > 0 and self.settings.position.left > 0 then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", self.settings.position.left, self.settings.position.top)
    end
    Opener:RegisterEvent("BAG_UPDATE", "UpdateBag")
end

function Opener:Toggle(_, enabled)
    if enabled == self.settings.enabled then
        return
    end
    if enabled then
        self:init()
        self:UpdateBags()
    else
        Opener:UnregisterEvent("BAG_UPDATE")
        Opener.Junkboxes = {}
        frame.bagSlot = nil
        frame.isLocked = nil
        frame:Hide()
    end
    self.settings.enabled = enabled
end

function Opener:UpdateBags()
    for bagId = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
        self:UpdateBag(_, bagId)
    end
end

function Opener:UpdateBag(_, bagId)
    for slot = 1, C_Container.GetContainerNumSlots(bagId) do
        local bagSlot =  bagId.." "..slot
        local item = C_Container.GetContainerItemInfo(bagId, slot)
        if item and Loot.IsJunkbox(item.itemID) then
            Opener.Junkboxes[bagSlot] = {link = item.hyperlink, icon = item.iconFileID, state = Opener:GetLockState(bagId, slot)}
        elseif Opener.Junkboxes[bagSlot] then
            Opener.Junkboxes[bagSlot] = nil
        end
        Opener:Next()
    end
end

function Opener:Next()
    if frame.bagSlot == nil then
        local iter = pairs(Opener.Junkboxes)
        local bagSlot, item = iter(Opener.Junkboxes)
        self:UpdateButton(bagSlot, item)
    elseif Opener.Junkboxes[frame.bagSlot] then
        self:UpdateButton(frame.bagSlot, Opener.Junkboxes[frame.bagSlot])
    end
end

function Opener:UpdateButton(bagSlot, item)
    if bagSlot and item then
        local bag, slot = strsplit(" ", bagSlot)
        if Opener:CanUnlock(item.state) then
            frame:SetAttribute("type", "spell");
            frame:SetAttribute("spell", "Pick Lock")
            frame:SetAttribute("target-bag", bag)
            frame:SetAttribute("target-slot", slot)
        elseif item.state.locked == false then
            frame:SetAttribute("type", "item")
            frame:SetAttribute("item", bagSlot)
        else
            Opener.Junkboxes[bagSlot] = nil
            return
        end
        frame:SetNormalTexture(item.icon)
        frame:SetScript("OnEnter", function(widget)
            GameTooltip:SetOwner(frame, "ANCHOR_NONE")
            GameTooltip:SetPoint("TOPLEFT", frame, "BOTTOMLEFT")
            GameTooltip:ClearLines()
            GameTooltip:SetBagItem(bag, slot)
            GameTooltip:AddLine("Right-click to pick lock or open")
            GameTooltip:AddLine("Left-click and hold to move button")
            GameTooltip:Show()
        end)
        frame:SetScript("OnLeave", function(self, button)
            GameTooltip:Hide()
        end)
        frame.bagSlot = bagSlot
        frame.isLocked = item.state.locked
        frame:Show()
    else
        frame.bagSlot = nil
        frame:Hide()
    end
end

function Opener:CanUnlock(state)
    local level = UnitLevel("player")

    if state.locked and level > state.level then
        return true
    end
    return false
end

function Opener:GetLockState(bag, slot)
    tooltip:ClearLines()
    tooltip:SetBagItem(bag, slot)

    local state = {locked = false, level = 0}
    local lines = Opener:GetTooltipLines()
    for i = 1, #lines do
        if string.match(lines[i], "Locked") then
            state.locked = true
        elseif string.match(lines[i], "Requires Lockpicking") then
            local level = select(2, strsplit("()", lines[i]))
            if level then
                state.level = tonumber(level)
            end
        end
    end
    return state
end

function Opener:GetTooltipLines()
    local lines = {}
    local regions = {tooltip:GetRegions()}
    for _, r in ipairs(regions) do
        if r:IsObjectType("FontString") then
            local line = r:GetText()
            table.insert(lines, line)
        end
    end
    return lines
end