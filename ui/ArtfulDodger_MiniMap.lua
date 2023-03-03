if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local Stats = Addon:GetModule("ArtfulDodger_Stats")
local Minimap = Addon:NewModule("ArtfulDodger_Minimap", "AceEvent-3.0")
local Events = Addon.Events
local L = Addon.Localizations

Minimap.Title = L["The Artful Dodger's Ledger"]
Minimap.Gold = "|cffeec300"
Minimap.White = "|cffFFFFFF"
Minimap.StatusString = Minimap.White.."%s|r"..Minimap.Gold.." /"..L["Hour"].."|r  "..Minimap.White.."%s|r"..Minimap.Gold.." /"..L["Victim"].."|r"
Minimap.timeSinceLastUpdate = 0

Minimap.Button = LibStub("LibDBIcon-1.0")

Minimap.Datasource = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(Minimap.Title, {
    type = "data source", 
    icon = "Interface\\Icons\\INV_Misc_Bag_11", 
    text = string.format(Minimap.StatusString, 
        GetCoinTextureString(0), 
        GetCoinTextureString(0)
    )
})

function Minimap:OnEnable()
    self.settings = Addon.db.settings.minimap
    self.Button:Register(Minimap.Title, Minimap.Datasource, self.settings)
    self:RegisterMessage(Events.Minimap.Toggle, "Toggle")
    self:RegisterMessage(Events.Minimap.IdleThreshold, "UpdateIdleThreshold", value)
end

function Minimap:Toggle(_, hide)
    if hide == self.settings.hide then
        return
    end
    if hide then
        Minimap.Button:Hide(Minimap.Title)
    else
        Minimap.Button:Show(Minimap.Title)
    end
    self.settings.hide = hide
end

function Minimap:UpdateIdleThreshold(value)
    self.settings.idleThresholdSeconds = value
end

function Minimap:Reset()
    self.Datasource.text = string.format(Minimap.StatusString, 
        GetCoinTextureString(Stats:GetSessionCopperPerHour()),
        GetCoinTextureString(Stats:GetSessionCopperPerVictim())
    )
end

function Minimap:Update()
    self.Datasource.text = string.format(Minimap.StatusString,
        GetCoinTextureString(Stats:GetSessionCopperPerHour()),
        GetCoinTextureString(Stats:GetSessionCopperPerVictim())
    )
end

Minimap.Display = CreateFrame("Frame", "ArtfulDodger_MinimapUpdate") 
Minimap.Display:SetScript("OnUpdate", function(self, elapsed)
    Minimap.timeSinceLastUpdate = Minimap.timeSinceLastUpdate + elapsed
    if Minimap.timeSinceLastUpdate > Minimap.settings.updateFrequencySeconds then
        if Stats.db then
            local latest = Addon.db.history.pickpocket[#Addon.db.history.pickpocket]
            if latest and latest.timestamp then
                local timeSinceLastPickPocket = (time() - latest.timestamp)
                if timeSinceLastPickPocket < Minimap.settings.idleThresholdSeconds then
                    Stats.db.session.duration =  Stats.db.session.duration + Minimap.timeSinceLastUpdate
                    Minimap:Update()
                end
            end
        end
        Minimap.timeSinceLastUpdate = 0
    end
end)

function Minimap.Datasource:OnClick(type)
    if type == "LeftButton" then
        Addon:SendMessage(Addon.Events.UI.Toggle)
    elseif type == "RightButton" then
        Minimap:Toggle(nil, not Minimap.settings.hide)
    end
end

function Minimap.Datasource:OnTooltipShow()
    self:AddLine(Minimap.Title)
    self:AddLine("")
    self:AddLine(Stats:GetPrettyPrintTotalLootedString())
end