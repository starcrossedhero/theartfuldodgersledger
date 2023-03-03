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

function Opener:init()
    if self.settings.position.top > 0 and self.settings.position.left > 0 then
        Frame:ClearAllPoints()
        Frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", self.settings.position.left, self.settings.position.top)
    end
    self:Register()
end

function Opener:Register()
    if self.settings.enabled then
        self:RegisterEvent("BAG_UPDATE", "UpdateBag")
        self:RegisterEvent("PLAYER_REGEN_DISABLED", "ShowFrame", false)
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "ShowFrame", true)
        self:RegisterEvent("PLAYER_ENTERING_BATTLEGROUND", "ShowFrame", false)
        self:RegisterEvent("PLAYER_ENTERING_WORLD", "ShowFrame", true)
        self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        self:RegisterEvent("LOOT_READY")
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
    self:UnregisterEvent("LOOT_READY")
    self:UnregisterMessage(Events.Opener.PosUpdate)
end

function Opener:UNIT_SPELLCAST_SUCCEEDED(event, target, guid, spellId)
    if target == "player" and spellId == 1804 then    
        if Frame.ArtfulDodger.Junkbox then
            local guid = Frame.ArtfulDodger.Junkbox.guid
            if self.Junkboxes[guid] then 
                self.Junkboxes[guid].state = {locked = false, level = 0}
                self:UpdateButton(self.Junkboxes[guid])
            else
                Frame:Clear()
                self:NextBox()
            end
        end
    end
end

function Opener:LOOT_READY(event, slotNumber)
    for slot = 1, GetNumLootItems() do
        local sources = {GetLootSourceInfo(slot)}
        for source = 1, #sources, 2 do
            local sourceGuid = sources[source]
            if self.Junkboxes[sourceGuid] then
                self.Junkboxes[sourceGuid] = nil
                Frame:Clear()
                self:NextBox()
            end
        end
    end
end

function Opener:PositionUpdate(_, top, left)
    self.settings.position.top = top
    self.settings.position.left = left
end

function Opener:ShowFrame(show)
    if show and self:ShouldShowFrame() then
        Frame:Show()
    else
        Frame:Hide()
    end
end

function Opener:ShouldShowFrame()
    return self.settings.enabled and not UnitInBattleground("player") and Opener.Junkboxes and Frame.ArtfulDodger.Junkbox
end

function Opener:Toggle(_, enabled)
    if enabled == self.settings.enabled then
        return
    end
    if enabled then
        self:init()
        self:UpdateBags()
    else
        self.Junkboxes = {}
        Frame.ArtfulDodger.Junkbox = nil
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

function Opener:getTableSize()
    local count = 0
    for _, _ in pairs(self.Junkboxes) do
        count = count + 1
    end
    return count
end


function Opener:UpdateBag(_, bagId)
    local updated = false
    for slotId = 1, C_Container.GetContainerNumSlots(bagId) do
        local item = Item:CreateFromBagAndSlot(bagId, slotId)
        if item and Loot.IsJunkbox(item:GetItemID()) then
            local guid = item:GetItemGUID()
            local junkbox = self.Junkboxes[guid]
            local state = self:GetLockState(bagId, slotId)
            if junkbox then
                if self:HasJunkboxChanged(junkbox, bagId, slotId, state) then
                    self.Junkboxes[guid] = Opener:Junkbox(bagId, slotId, item, state)
                    updated = true
                end
            else
                self.Junkboxes[guid] = Opener:Junkbox(bagId, slotId, item, state)
                updated = true
            end
        end
    end
    if updated then
        self:NextBox()
    end
end

function Opener:Junkbox(bagId, slotId, item, state)
    return {bagId = bagId, slotId = slotId, guid = item:GetItemGUID(), name = item:GetItemName(), link = item:GetItemLink(), icon = item:GetItemIcon(), state = state}
end

function Opener:HasJunkboxChanged(junkbox, bagId, slotId, state)
    return junkbox.bagId ~= bagId and junkbox.slotId ~= slotId and junkbox.state.locked ~= state.locked
end

function Opener:NextBox()
    if Frame.ArtfulDodger.Junkbox then
        local guid = Frame.ArtfulDodger.Junkbox.guid
        self:UpdateButton(self.Junkboxes[guid])
    else
        local _, junkbox = next(self.Junkboxes)
        self:UpdateButton(junkbox)
    end
end

function Opener:UpdateButton(item)
    if item then
        Frame:SetNormalTexture(item.icon)
        if self.Junkboxes then
            Frame.Counter.text:SetText(self:getTableSize())
        end
        Frame.ArtfulDodger.Junkbox = item
        if self:CanUnlock(item.state) then
            Frame:SetPickLock()
        elseif item.state.locked == false then
            Frame:SetOpenBox()
        else
            self.Junkboxes[item.guid] = nil
            Frame:Clear()
            return
        end
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

function Opener:GetLockState(bagId, slotId)
    local state = {locked = false, level = 0}

    Tooltip:ClearLines()
    Tooltip:SetBagItem(bagId, slotId)
    
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