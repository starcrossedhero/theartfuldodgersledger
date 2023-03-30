if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local MapPins = Addon:NewModule("ArtfulDodger_Pins", "AceEvent-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local hbd  = LibStub("HereBeDragons-2.0")
local hbdp = LibStub("HereBeDragons-Pins-2.0")

local pool = CreateFramePool("Frame")

MapPins.currentPins = {}

function MapPins:OnInitialize()
    self.settings = Addon.db.settings.pins
    if self.settings.enabled then
        self:RegisterEvent("QUEST_LOG_UPDATE", "MapOpened")
    end
end

function MapPins:MapOpened()
    if WorldMapFrame:IsVisible() then
        local mapId = WorldMapFrame:GetMapID()

        if mapId then
            local history = Addon:GetHistoryByMapId(mapId)
            
            for i = 1, #history do
                local event = history[i]
                if event.mapId and event.x and event.y then
                    print(event.mapId, event.x, event.y)
                    local frame = pool:Acquire()
                    frame:SetWidth(10)
                    frame:SetHeight(10)
                    frame.texture = frame:CreateTexture(nil, "OVERLAY")
                    frame.texture:SetTexture("Interface\\Icons\\INV_Misc_Bag_11")
                    frame.texture:SetPoint("TOPLEFT", frame)
                    frame.texture:SetPoint("BOTTOMRIGHT", frame)
                    frame:SetScript("OnEnter", function(widget)
                        GameTooltip:SetOwner(frame, "ANCHOR_NONE")
                        GameTooltip:SetPoint("TOPLEFT", frame, "BOTTOMLEFT")
                        GameTooltip:ClearLines()
                        GameTooltip:SetText("Victim: "..event.victim.name.."\n".."Purse: "..GetCoinTextureString(Addon.PickPocketEvent.GetCopperFromLoot(event.loot)))
                        GameTooltip:Show()
                    end)
                    frame:SetScript("OnLeave", function()
                        GameTooltip:Hide()
                    end)
                    hbdp:AddWorldMapIconMap(MapPins.currentPins, frame, event.mapId, event.x, event.y)
                end
            end
        end
    else
        hbdp:RemoveAllWorldMapIcons(MapPins.currentPins)
        pool:ReleaseAll()
    end
end