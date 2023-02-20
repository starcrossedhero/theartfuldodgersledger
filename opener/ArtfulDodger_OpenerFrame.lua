if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local Frame = CreateFrame("Button", "ArtfulDodger_OpenerFrame", nil, "InsecureActionButtonTemplate")
Addon.OpenerFrame = Frame

Frame.BoxUpdateEvent = "ARTFULDODGER_JUNKBOXOPENER_BOXUPDATE"
Frame.PositionUpdateEvent = "ARTFULDODGER_JUNKBOXOPENER_POSITIONUPDATE"

Frame.ArtfulDodger = {}
Frame:SetSize(50, 50)
Frame:EnableMouse(true)
Frame:RegisterForClicks("RightButtonUp", "RightButtonDown")
Frame:RegisterForDrag("LeftButton")
Frame:SetScript("PostClick", function(self, button, down) 
    if button == "RightButton" and down == false then
        Addon:SendMessage(Frame.BoxUpdateEvent, self.ArtfulDodger.bagSlot, self.ArtfulDodger.locked)
        if self.ArtfulDodger.locked then
            self.ArtfulDodger.locked = not self.ArtfulDodger.locked
        else
            self:Clear()
        end
    end
end)
Frame:SetMovable(true)
Frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
Frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    Addon:SendMessage(Frame.PositionUpdateEvent, self:GetTop(), self:GetLeft())
end)
Frame:SetScript("OnEnter", function(self)
    if self.ArtfulDodger.bagSlot then
        local bag, slot = strsplit(" ", self.ArtfulDodger.bagSlot)
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
        GameTooltip:ClearLines()
        GameTooltip:SetBagItem(bag, slot)
        GameTooltip:AddLine("Right-click to pick lock or open")
        GameTooltip:AddLine("Left-click and hold to move button")
        GameTooltip:Show()
    end
end)
Frame:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
Frame:Hide()

function Frame:PickLock(bagSlot)
    local bag, slot = strsplit(" ", bagSlot)
    Frame:SetAttribute("type", "spell");
    Frame:SetAttribute("spell", "Pick Lock")
    Frame:SetAttribute("target-bag", bag)
    Frame:SetAttribute("target-slot", slot)
end

function Frame:OpenBox(bagSlot)
    Frame:SetAttribute("type", "item")
    Frame:SetAttribute("item", bagSlot)
end

function Frame:Clear()
    Frame.ArtfulDodger.bagSlot = nil
    Frame.ArtfulDodger.locked = nil
end