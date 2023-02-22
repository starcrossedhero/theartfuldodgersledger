if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local Opener = Addon:NewModule("ArtfulDodger_JunkboxOpener", "AceEvent-3.0")
local Frame = Addon.OpenerFrame
local Loot = Addon.Loot
local Events = Addon.Events
local AceGUI = LibStub("AceGUI-3.0")

local Tooltip = CreateFrame("GameTooltip", "ArtfulDodger_OpenerTooltip", nil, "GameTooltipTemplate")
Tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

Opener.Junkboxes = {}

function Opener:OnInitialize()
    self.settings = Addon.db.settings.opener
    if self.settings.enabled then
        self:init()
        self:UpdateBag(nil, 0) --update backpack because it doesn't get called on login
    end
end

function Opener:Register()
    if self.settings.enabled then
        self:RegisterEvent("BAG_UPDATE", "UpdateBag")
        self:RegisterEvent("PLAYER_REGEN_DISABLED", "ShowFrame", false)
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "ShowFrame", true)
        self:RegisterEvent("PLAYER_ENTERING_BATTLEGROUND", "ShowFrame", false)
        self:RegisterEvent("PLAYER_ENTERING_WORLD", "ShowFrame", true)
        self:RegisterMessage(Events.Opener.BoxUpdate, "BoxUpdate")
        self:RegisterMessage(Events.Opener.PosUpdate, "PositionUpdate")
    end
    self:RegisterMessage(Events.Opener.Toggle, "Toggle")
end

function Opener:Unregister()
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    self:UnregisterEvent("PLAYER_ENTERING_BATTLEGROUND")
    self:UnregisterEvent("PLAYER_REGEN_DISABLED")
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:UnregisterEvent("BAG_UPDATE")
    self:UnregisterMessage(Events.Opener.BoxUpdate)
    self:UnregisterMessage(Events.Opener.PosUpdate)
end

function Opener:BoxUpdate(_, bagSlot, locked)
    if self.Junkboxes[bagSlot] then
        if locked == true then
            self.Junkboxes[bagSlot].state.locked = false
            self.Junkboxes[bagSlot].state.level = 0
        else
            self.Junkboxes[bagSlot] = nil
        end
    end
    self:NextBox()
end

function Opener:PositionUpdate(_, top, left)
    self.settings.position.top = top
    self.settings.position.left = left
end

function Opener:init()
    if self.settings.position.top > 0 and self.settings.position.left > 0 then
        Frame:ClearAllPoints()
        Frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", self.settings.position.left, self.settings.position.top)
    end
    self:Register()
end

function Opener:ShowFrame(show)
    if show and self:ShouldShowFrame() then
        Frame:Show()
    else
        Frame:Hide()
    end
end

function Opener:ShouldShowFrame()
    return self.settings.enabled and not UnitInBattleground("player") and Opener.Junkboxes and Frame.ArtfulDodger.bagSlot
end

function Opener:Toggle(_, enabled)
    if enabled == self.settings.enabled then
        return
    end
    if enabled then
        self:init()
        self:UpdateBags()
    else
        Opener.Junkboxes = {}
        Frame.ArtfulDodger.bagSlot = nil
        Frame.ArtfulDodger.locked = nil
        Frame:Hide()
        self:Unregister()
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
            if self:HasItemChanged(bagId, slot, item) then
                self.Junkboxes[bagSlot] = {link = item.hyperlink, icon = item.iconFileID, state = self:GetLockState(bagSlot)}
            end
        elseif self.Junkboxes[bagSlot] then
            self.Junkboxes[bagSlot] = nil
        end
    end
    self:NextBox()
end

function Opener:HasItemChanged(bagSlot, newItem)
    return not self.Junkboxes[bagSlot] or self.Junkboxes[bagSlot].link ~= newItem.hyperlink or self.Junkboxes[bagSlot].state ~= self:GetLockState(bagSlot)
end

function Opener:NextBox()
    if not Frame.ArtfulDodger.bagSlot then
        local bagSlot, item = next(self.Junkboxes)
        self:UpdateButton(bagSlot, item)
    elseif self.Junkboxes[Frame.ArtfulDodger.bagSlot] then
        self:UpdateButton(Frame.ArtfulDodger.bagSlot, self.Junkboxes[Frame.ArtfulDodger.bagSlot])
    end
end

function Opener:UpdateButton(bagSlot, item)
    if bagSlot and item then
        if self:CanUnlock(item.state) then
            Frame:SetPickLock(bagSlot)
        elseif item.state.locked == false then
            Frame:SetOpenBox(bagSlot)
        else
            Opener.Junkboxes[bagSlot] = nil
            Frame:Clear()
            return
        end
        Frame:SetNormalTexture(item.icon)
        Frame.ArtfulDodger.bagSlot = bagSlot
        Frame.ArtfulDodger.locked = item.state.locked
        self:ShowFrame(true)
    else
        Frame:Clear()
        self:ShowFrame(false)
    end
end

function Opener:CanUnlock(state)
    local level = UnitLevel("player")

    if state.locked and level > state.level then
        return true
    end
    return false
end

function Opener:GetLockState(bagSlot)
    local bag, slot = strsplit(" ", bagSlot)
    local state = {locked = false, level = 0}

    Tooltip:ClearLines()
    Tooltip:SetBagItem(bag, slot)
    
    local lines = self:GetTooltipLines()

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
    local regions = {Tooltip:GetRegions()}
    for _, r in ipairs(regions) do
        if r:IsObjectType("FontString") then
            local line = r:GetText()
            if line then
                table.insert(lines, line)
            end
        end
    end
    return lines
end