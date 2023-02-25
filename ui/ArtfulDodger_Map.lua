if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local Stats = Addon:GetModule("ArtfulDodger_Stats")
local Map = Addon:NewModule("ArtfulDodger_Map", "AceEvent-3.0")
local Events = Addon.Events
local L = Addon.Localizations

Map.timeSinceLastUpdate = 0
Map.currentMapId = -1

Map.Frame = CreateFrame("Frame", "ArtfulDodger_MapFrame", WorldMapFrame.ScrollContainer)
Map.Frame:SetPoint("BOTTOMLEFT", WorldMapFrame.ScrollContainer, 75, -40)
Map.Frame:SetHeight(35)

Map.Frame.text = Map.Frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
Map.Frame.text:SetAllPoints(Map.Frame)
Map.Frame.text:SetJustifyH("CENTER")
Map.Frame:SetWidth(math.max(Map.Frame.text:GetWidth(), 300))

Map.Frame.texture = Map.Frame:CreateTexture(nil, "BACKGROUND")
Map.Frame.texture:SetPoint("TOPLEFT", Map.Frame, -50, 10)
Map.Frame.texture:SetPoint("BOTTOMRIGHT", Map.Frame, 50, -10)
Map.Frame.texture:SetTexture(1115847)
Map.Frame.texture:SetAtlas("adventureguide-pane-small")
Map.Frame.texture:SetAlpha(0.95)

Map.Frame:SetScript("OnUpdate", function(self, elapsed)
    Map.timeSinceLastUpdate = Map.timeSinceLastUpdate + elapsed
    if Map.timeSinceLastUpdate >= Map.settings.updateFrequencySeconds then
        Map.timeSinceLastUpdate = 0
        if WorldMapFrame.ScrollContainer:IsVisible() and MouseIsOver(WorldMapFrame.ScrollContainer) then
            local cursorX, cursorY = WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition()
            local mapId = WorldMapFrame:GetMapID()
            
            if mapId and Map:IsValidCoords(cursorX, cursorY) then
                local mapInfo = C_Map.GetMapInfoAtPosition(mapId, cursorX, cursorY)
                if mapInfo then
                    if mapInfo.mapID ~= Map.currentMapId then
                        Map:UpdateFrameText(mapInfo.mapID)
                        Map.currentMapId = mapInfo.mapID
                    end
                else
                    if mapId ~= Map.currentMapId then
                        Map:UpdateFrameText(mapId)
                        Map.currentMapId = mapId
                    end
                end
            end
        end
    end
end)
Map.Frame:SetScript("OnShow", function(self)
    Map.timeSinceLastUpdate = 0
end)

function Map:UpdateFrameText(mapId)
    local stats = Stats:GetStatsForMapId(mapId, true)
    Map.Frame.text:SetText(Map:GeneratePrettyString(C_Map.GetMapInfo(mapId).name, stats.thefts, stats.copper))
end

function Map:GeneratePrettyString(name, victims, copper)
    return string.format("%s\n"..L["Victims"]..": %d   "..L["Coin"]..": %s", name, victims, GetCoinTextureString(copper))
end

function Map:IsValidCoords(x, y)
    return x and y and x > 0 and y > 0
end

function Map:OnEnable()
    self.db = Addon.db
    self.settings = Addon.db.settings.map
    self:RegisterMessage(Events.Map.Toggle, "Toggle")
end

function Map:Toggle(_, enabled)
    if enabled == self.settings.enabled then
        return
    end
    if enabled then
        Map.Frame:Show()
    else
        Map.Frame:Hide()
    end
    self.settings.enabled = enabled
end