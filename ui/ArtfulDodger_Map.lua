local _, ns = ...
local Addon = ns.Addon
if not Addon then return end

local Map = {}
ns.Map = Map

local PIN_TEMPLATE = "ArtfulDodgerMapPinTemplate"
local provider
local refreshPending = false
local refreshGeneration = 0
local mapShowHooked = false
local MAP_PICKS = "Pockets Lifted"
local MAP_GAINS = "Ill-Gotten Gains"
local MAP_PURSE = "Typical Purse"
local MAP_ITEMS = "Possible Take"

local function LocationPosition(location, sourceMapID, targetMapID)
    local x, y = tonumber(location.positionX), tonumber(location.positionY)
    if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then return end
    if sourceMapID == targetMapID then return x, y end

    if not (C_Map and type(C_Map.GetMapRectOnMap) == "function") then return end
    local ok, left, right, top, bottom = pcall(C_Map.GetMapRectOnMap, sourceMapID, targetMapID)
    if not ok or not left or not right or not top or not bottom then return end

    x = left + (right - left) * x
    y = top + (bottom - top) * y
    if x < 0 or x > 1 or y < 0 or y > 1 then return end
    return x, y
end

local function ShowLocationTooltip(pin)
    local location = pin.location
    if not location then return end

    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:SetText(location.subzone or location.zone or "Known Haunt")
    if location.zone and location.subzone and location.zone ~= location.subzone then
        GameTooltip:AddLine(location.zone, 0.75, 0.75, 0.75)
    end

    local indent = "  "
    local picks = tonumber(location.picks) or 0
    local copper = tonumber(location.copper) or 0
    GameTooltip:AddLine(indent .. (MAP_PICKS .. ": %d"):format(picks), 1, 1, 1)
    GameTooltip:AddLine(indent .. (MAP_GAINS .. ": %s"):format(ns.Coins(copper)), 1, 1, 1)
    if picks > 0 then
        GameTooltip:AddLine(indent .. (MAP_PURSE .. ": %s"):format(ns.Coins(copper / picks)), 1, 1, 1)
    end

    local items = {}
    for itemKey, count in pairs(location.items or {}) do
        local itemID, quantity = tonumber(itemKey), tonumber(count)
        if itemID and quantity and quantity > 0 then
            local name = location.itemNames and (location.itemNames[itemKey] or location.itemNames[itemID])
            local link = location.itemLinks and (location.itemLinks[itemKey] or location.itemLinks[itemID])
            if not name and type(link) == "string" then name = link:match("%[(.-)%]") end
            local hits = tonumber(location.itemPicks and (location.itemPicks[itemKey] or location.itemPicks[itemID])) or 0
            local samples = tonumber(location.itemSamplePicks) or 0
            items[#items + 1] = {
                name = name or tostring(itemID),
                quantity = quantity,
                rate = samples > 0 and hits / samples * 100 or nil,
            }
        end
    end
    table.sort(items, function(a, b)
        if a.quantity == b.quantity then return a.name < b.name end
        return a.quantity > b.quantity
    end)
    if #items > 0 then
        GameTooltip:AddLine(indent .. MAP_ITEMS .. ":", 0.9, 0.82, 0.45)
        for index = 1, math.min(3, #items) do
            local item = items[index]
            local detail = "x" .. tostring(item.quantity)
            if item.rate then detail = detail .. (" (%.1f%%)"):format(item.rate) end
            GameTooltip:AddDoubleLine(indent .. "  " .. item.name, detail, 1, 1, 1, 0.75, 0.85, 0.75)
        end
    end
    GameTooltip:Show()
end

local PinMixin = CreateFromMixins(MapCanvasPinMixin)
local function ApplyRoundMask(frame, texture)
    local mask = frame:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    mask:SetAllPoints(texture)
    texture:AddMaskTexture(mask)
    return mask
end

function PinMixin:OnLoad()
    self:SetSize(30, 30)
    self:UseFrameLevelType("PIN_FRAME_LEVEL_TOPMOST")
    self.MarkerBackground = self:CreateTexture(nil, "ARTWORK")
    self.MarkerBackground:SetAllPoints(self)
    self.MarkerBackground:SetColorTexture(0.05, 0.05, 0.05, 0.9)
    self.MarkerBackgroundMask = ApplyRoundMask(self, self.MarkerBackground)
    self.Texture = self:CreateTexture(nil, "OVERLAY", nil, 7)
    self.Texture:SetSize(24, 24)
    self.Texture:SetPoint("CENTER", self, "CENTER")
    self.TextureMask = ApplyRoundMask(self, self.Texture)
    self.Count = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.Count:SetPoint("BOTTOM", self, "BOTTOM", 0, -1)
    self.Count:SetJustifyH("CENTER")
    self.Count:SetShadowColor(0, 0, 0, 1)
    self.Count:SetShadowOffset(1, -1)
end

function PinMixin:OnAcquired(location)
    self.location = location
    self.Texture:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    self.Texture:SetVertexColor(1, 1, 1, 1)
    self.Texture:SetAlpha(1)
    self.Texture:Show()
    self.Count:SetText(tostring(location.picks or 0))
    self.Count:SetTextColor(1, 1, 1, 1)
    self.Count:Show()
    self:SetAlpha(1)
    self:Show()
end

function PinMixin:OnReleased()
    self.location = nil
    MapCanvasPinMixin.OnReleased(self)
end

function PinMixin:OnMouseEnter()
    ShowLocationTooltip(self)
end

function PinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

_G.ArtfulDodgerMapPinMixin = PinMixin

local ProviderMixin = CreateFromMixins(MapCanvasDataProviderMixin)
function ProviderMixin:OnAdded(mapCanvas)
    MapCanvasDataProviderMixin.OnAdded(self, mapCanvas)
    self:RefreshAllData()
end

function ProviderMixin:OnRemoved(mapCanvas)
    self:RemoveAllData()
    MapCanvasDataProviderMixin.OnRemoved(self, mapCanvas)
end

function ProviderMixin:RemoveAllData()
    if self:GetMap() then self:GetMap():RemoveAllPinsByTemplate(PIN_TEMPLATE) end
end

function ProviderMixin:RefreshAllData()
    self:RemoveAllData()
    local mapCanvas = self:GetMap()
    if not mapCanvas or not mapCanvas:IsShown() then return end
    if not (Addon.db and Addon.db.settings and Addon.db.settings.worldMap) then return end

    local targetMapID = mapCanvas:GetMapID()
    if not targetMapID then return end
    for mapKey, zones in pairs(Addon.db.locations or {}) do
        local sourceMapID = tonumber(mapKey)
        if sourceMapID and sourceMapID > 0 and type(zones) == "table" then
            for _, subzones in pairs(zones) do
                if type(subzones) == "table" then
                    for _, location in pairs(subzones) do
                        if type(location) == "table" and (tonumber(location.positionSamples) or 0) > 0 then
                            local x, y = LocationPosition(location, sourceMapID, targetMapID)
                            if x and y then
                                local pin = self:GetMap():AcquirePin(PIN_TEMPLATE, location)
                                pin:SetPosition(x, y)
                                pin:Show()
                            end
                        end
                    end
                end
            end
        end
    end
end

function Map:Attach()
    if not (WorldMapFrame and type(WorldMapFrame.AddDataProvider) == "function") then return end
    if not (MapCanvasDataProviderMixin and MapCanvasPinMixin) then return end
    if provider then return end

    provider = CreateFromMixins(ProviderMixin)
    WorldMapFrame:AddDataProvider(provider)
    if not mapShowHooked and type(WorldMapFrame.HookScript) == "function" then
        WorldMapFrame:HookScript("OnShow", function() Map:RefreshNow() end)
        mapShowHooked = true
    end
end

function Map:Refresh()
    local mapCanvas = provider and provider:GetMap()
    if not mapCanvas or not mapCanvas:IsShown() or refreshPending then return end

    refreshPending = true
    local generation = refreshGeneration
    C_Timer.After(0, function()
        if generation ~= refreshGeneration then return end
        refreshPending = false
        Map:RefreshNow()
    end)
end

function Map:RefreshNow()
    refreshGeneration = refreshGeneration + 1
    refreshPending = false
    if provider and provider:GetMap() then provider:RefreshAllData() end
end

function Map:Debug()
    local lines = {}
    local worldMap = provider and provider:GetMap()
    if not worldMap then
        lines[1] = "Map provider is not attached."
    else
        local count = 0
        for pin in worldMap:EnumeratePinsByTemplate(PIN_TEMPLATE) do
            count = count + 1
            if count == 1 then
                local x, y = pin:GetPosition()
                local texture = pin.Texture
                lines[#lines + 1] = "Map: " .. tostring(worldMap:GetMapID())
                lines[#lines + 1] = "Position: " .. tostring(x) .. ", " .. tostring(y)
                lines[#lines + 1] = ("Frame: %.0fx%.0f shown=%s alpha=%s"):format(
                    pin:GetWidth(), pin:GetHeight(), tostring(pin:IsShown()), tostring(pin:GetAlpha()))
                lines[#lines + 1] = "Layer: " .. tostring(pin:GetFrameStrata())
                    .. " / " .. tostring(pin:GetFrameLevel())
                lines[#lines + 1] = "Texture: " .. tostring(texture and texture:GetTexture())
                lines[#lines + 1] = "Texture shown=" .. tostring(texture and texture:IsShown())
                    .. " alpha=" .. tostring(texture and texture:GetAlpha())
            end
        end
        lines[#lines + 1] = "Active pins: " .. tostring(count)
    end
    lines[#lines + 1] = "Map display enabled: " .. tostring(Addon.db.settings.worldMap)
    local output = table.concat(lines, "\n")
    if ns.UI and type(ns.UI.ShowText) == "function" then
        ns.UI:ShowText(output)
    else
        Addon:Print(output)
    end
end

function Map:Init()
    Addon:RegisterMessage(ns.Events.Loot.PickRecorded, self, "Refresh")
    Addon:RegisterMessage(ns.Events.History.Reset, self, "Refresh")

    self:Attach()
    local events = CreateFrame("Frame")
    events:RegisterEvent("ADDON_LOADED")
    events:SetScript("OnEvent", function(_, _, loadedAddon)
        if loadedAddon == "Blizzard_WorldMap" or loadedAddon == "Blizzard_MapCanvas" then
            self:Attach()
        end
    end)
end

SLASH_ADLMAP1 = "/adlmap"
SlashCmdList["ADLMAP"] = function() Map:Debug() end
