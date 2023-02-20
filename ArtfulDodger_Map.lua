if select(3, UnitClass("player")) ~= 4 then
    return
end

local addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local stats = addon:GetModule("ArtfulDodger_Stats")
local map = addon:NewModule("ArtfulDodger_Map", "AceEvent-3.0")

local FRAME_UPDATE_INTERVAL = 3
local FRAME_TIME_SINCE_LAST_UPDATE = 0
local FRAME

function map:CreateFrame()
    local frame = CreateFrame("Frame", "ArtfulDodger_MapFrame", WorldMapFrame.ScrollContainer)
    frame.text = frame:CreateFontString(nil, "ARTWORK", "GameFontWhite")
    frame.text:SetPoint("BOTTOMLEFT", WorldMapFrame.ScrollContainer, 5, 5)
    frame.text:SetJustifyH("LEFT")
    frame:SetAllPoints(frame.text)
    
    frame.texture = frame:CreateTexture(nil, "BACKGROUND")
    frame.texture:SetPoint("TOPLEFT", frame.text, -5, 5)
    frame.texture:SetPoint("BOTTOMRIGHT", frame.text, 5, -5)
    frame.texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.texture:SetVertexColor(0, 0, 0, 0.3)
    frame:SetScript("OnUpdate", function(self, elapsed)
        FRAME_TIME_SINCE_LAST_UPDATE = FRAME_TIME_SINCE_LAST_UPDATE + elapsed
        if map.settings.enabled then
            if FRAME_TIME_SINCE_LAST_UPDATE >= FRAME_UPDATE_INTERVAL then
                if WorldMapFrame.ScrollContainer:IsVisible() and MouseIsOver(WorldMapFrame.ScrollContainer) then
                    local cursorX, cursorY = WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition()
                    local mapId = WorldMapFrame:GetMapID()
                    
                    if mapId and map:IsValidCoords(cursorX, cursorY) then
                        local mapInfo = C_Map.GetMapInfoAtPosition(mapId, cursorX, cursorY)
                        if mapInfo then
                            map:UpdateFrameText(mapInfo.mapID)
                        else
                            map:UpdateFrameText(mapId)
                        end
                    end
                end
            end
        end
    end)
    frame:SetScript("OnShow", function(self)
        FRAME_TIME_SINCE_LAST_UPDATE = 0
    end)

    return frame
end

function map:UpdateFrameText(mapId)
    local stats = stats:GetStatsForMapAndChildrenByMapId(mapId)
    FRAME.text:SetText(map:GeneratePrettyString(C_Map.GetMapInfo(mapId).name, stats.victims, stats.copper))
end

function map:GeneratePrettyString(name, victims, copper)
    return string.format("%s\nVictims: %d   Coin: %s", name, victims, GetCoinTextureString(copper))
end

function map:IsValidCoords(x, y)
    return x and y and x > 0 and y > 0
end

function map:OnEnable()
    self.db = addon.db
    self.settings = addon.db.settings.map
    FRAME = map:CreateFrame()
    self:RegisterMessage("ArtfulDodger_ToggleMap", "ToggleMap")
end

function map:ToggleMap(_, enabled)
    if enabled == self.settings.enabled then
        return
    end
    if enabled then
        FRAME:Show()
    else
        FRAME:Hide()
    end
    self.settings.enabled = enabled
end