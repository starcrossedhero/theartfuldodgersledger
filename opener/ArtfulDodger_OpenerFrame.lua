if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local Events = Addon.Events
local L = Addon.Localizations
local Frame = CreateFrame("Button", "ArtfulDodger_OpenerFrame", nil, "InsecureActionButtonTemplate")
local Counter = CreateFrame("Frame", "ArtfulDodger_OpenerCounter", Frame)
Counter:SetPoint("TOPRIGHT", Frame, 5, 5)
Counter:SetHeight(10)
Counter:SetWidth(10)
Counter.text = Counter:CreateFontString(nil, "ARTWORK", "GameFontNormal")
Counter.text:SetAllPoints(Counter)
Counter.text:SetJustifyH("CENTER")

Counter.texture = Counter:CreateTexture(nil, "BACKGROUND")
Counter.texture:SetPoint("TOPLEFT", Counter.text, -3, 3)
Counter.texture:SetPoint("BOTTOMRIGHT", Counter.text, 3, -3)
Counter.texture:SetTexture(1115847)
Counter.texture:SetAtlas("adventureguide-pane-small")
Counter.texture:SetAlpha(0.95)

Frame.Counter = Counter

Addon.OpenerFrame = Frame

Frame.ArtfulDodger = {}
Frame:SetText("TEST")
Frame:SetSize(50, 50)
Frame:EnableMouse(true)
Frame:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
Frame:RegisterForDrag("RightButton")
Frame:SetMovable(true)
Frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
Frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    Addon:SendMessage(Events.Opener.PosUpdate, self:GetTop(), self:GetLeft())
end)
Frame:SetScript("OnEnter", function(self)
    if self.ArtfulDodger.Junkbox then
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
        GameTooltip:ClearLines()
        GameTooltip:SetText(self.ArtfulDodger.Junkbox.name)
        GameTooltip:AddLine(L["Left-click to unlock or open"])
        GameTooltip:AddLine(L["Right-click and hold to move button"])
        GameTooltip:Show()
    end
end)
Frame:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
Frame:Hide()

function Frame:SetPickLock()
    Frame:SetAttribute("type", "spell");
    Frame:SetAttribute("spell", "Pick Lock")
    Frame:SetAttribute("target-bag", self.ArtfulDodger.Junkbox.bagId)
    Frame:SetAttribute("target-slot", self.ArtfulDodger.Junkbox.slotId)
end

function Frame:SetOpenBox()
    local bagSlot = self.ArtfulDodger.Junkbox.bagId.." "..self.ArtfulDodger.Junkbox.slotId
    Frame:SetAttribute("type", "item")
    Frame:SetAttribute("item", bagSlot)
end

function Frame:Clear()
    Frame.ArtfulDodger.Junkbox = nil
end