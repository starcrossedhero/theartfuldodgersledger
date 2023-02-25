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
Minimap.StatusString = Minimap.Gold..L["Victims"]..":|r "..Minimap.White.."%d|r   "..Minimap.Gold..L["Coin"]..":|r "..Minimap.White.."%s|r  "..Minimap.Gold..L["Per Hour"]..":|r  "..Minimap.White.."%s|r"..Minimap.Gold.."  "..L["Per Victim"]..":|r  "..Minimap.White.."%s|r"
Minimap.timeSinceLastUpdate = 0

Minimap.Button = LibStub("LibDBIcon-1.0")

Minimap.Datasource = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(Minimap.Title, {
    type = "data source", 
    icon = "Interface\\Icons\\INV_Misc_Bag_11", 
    text = string.format(Minimap.StatusString, 
        0,
        GetCoinTextureString(0),
        GetCoinTextureString(0), 
        GetCoinTextureString(0)
    )
})

function Minimap:OnEnable()
    self.settings = Addon.db.settings.minimap
    self.Button:Register(Minimap.Title, Minimap.Datasource, self.settings)
    self:RegisterMessage(Events.Minimap.Toggle, "Toggle")
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

function Minimap:Reset()
    self.Datasource.text = string.format(Minimap.StatusString, 
        Stats.db.session.thefts,
        GetCoinTextureString(Stats.db.session.copper),
        GetCoinTextureString(Stats:GetSessionCopperPerHour()),
        GetCoinTextureString(Stats:GetSessionCopperPerVictim())
    )
end

Minimap.Display = CreateFrame("Frame", "ArtfulDodger_MinimapUpdate") 
Minimap.Display:SetScript("OnUpdate", function(self, elapsed)
    Minimap.timeSinceLastUpdate = Minimap.timeSinceLastUpdate + elapsed
    if Minimap.timeSinceLastUpdate > Minimap.settings.updateFrequencySeconds then
        Minimap.timeSinceLastUpdate = 0
        if Stats.db then
            local duration = time() - Stats.db.session.start
            Minimap.Datasource.text = string.format(Minimap.StatusString, 
                Stats.db.session.thefts,
                GetCoinTextureString(Stats.db.session.copper),
                GetCoinTextureString(Stats:GetSessionCopperPerHour()),
                GetCoinTextureString(Stats:GetSessionCopperPerVictim())
            )
            Stats.db.session.duration = duration
        end
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