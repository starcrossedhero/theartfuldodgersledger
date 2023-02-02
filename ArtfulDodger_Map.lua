if UnitClass('player') ~= 'Rogue' then
    return
end

local addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local map = addon:NewModule("ArtfulDodger_Map")
local AceGUI = LibStub("AceGUI-3.0")

local FRAME_UPDATE_INTERVAL = 0.1
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
    end)
    frame:SetScript("OnShow", function(self)
        FRAME_TIME_SINCE_LAST_UPDATE = 0
    end)

    return frame
end

function map:UpdateFrameText(mapId)
    FRAME.text:SetText(map:GeneratePrettyString(C_Map.GetMapInfo(mapId).name, addon:GetMarksForMapAndChildrenByMapId(mapId), addon:GetCopperForMapAndChildrenByMapId(mapId)))
end

function map:GeneratePrettyString(name, marks, copper)
    return string.format("%s\nMarks: %d   Coin: %s", name, marks, GetCoinTextureString(copper))
end

function map:IsValidCoords(x, y)
    return x and y and x > 0 and y > 0
end

function map:OnEnable()
    map.db = addon.db
    FRAME = map:CreateFrame()
end

function map:ToggleMap(state)
    if state then
        FRAME:Show()
    else
        FRAME:Hide()
    end
end