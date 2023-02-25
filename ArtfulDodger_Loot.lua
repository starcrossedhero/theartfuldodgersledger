if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local L = Addon.Localizations

local Loot = {}
Loot.__index = Loot

Addon.Loot = Loot

Loot.COIN_NAME = L["Coin"]
Loot.COIN_LINK = "|cFFCC9900"..Loot.COIN_NAME.."|r"
Loot.COIN_ICON = "Interface\\Icons\\INV_Misc_Coin_01"

--prices pulled from wowhead
Loot.JUNKBOXES = {
	{itemId=16882, price=74},
	{itemId=16883, price=124},
	{itemId=16884, price=254},
	{itemId=16885, price=376},
    {itemId=63349, price=1196},
    {itemId=43575, price=376},
    {itemId=29569, price=371},
    {itemId=88165, price=12786},
    {itemId=106895, price=12786}
}

function Loot:New(sourceGuid, id, name, link, icon, quantity, price, isItem)
    local self = {}
    setmetatable(self, Loot)

    self.__index = self
    self.sourceGuid = sourceGuid
    self.id = id
	self.name = name
	self.link = link
	self.icon = icon
	self.quantity = quantity
    self.price = price
    self.isItem = isItem

	return self
end

function Loot:ToString()
    --return string.format("Loot: sourceGuid=%s, itemId=%s, name=%s, link=%s, icon=%s, quantity=%s, price=%s, isItem=%s", 
        --self.sourceGuid or "", self.id or "", self.name or "", self.link or "", self.icon or "", self.quantity or "", self.price or "", self.isItem or "")
end

function Loot:NewItem(sourceGuid, itemId, name, link, icon, quantity, price)
    return Loot:New(sourceGuid, itemId, name, link, icon, quantity, price, true)
end

function Loot:NewCoin(sourceGuid, price)
    return Loot:New(sourceGuid, nil, nil, nil, nil, 1, price, false)
end

function Loot.CacheJunkboxInfo()
    for i = 1, #Loot.JUNKBOXES do
        if not Loot.JUNKBOXES[i].name then
            local item = Item:CreateFromItemID(Loot.JUNKBOXES[i].itemId)
            item:ContinueOnItemLoad(function()
                Loot.JUNKBOXES[i].name = item:GetItemName() 
                Loot.JUNKBOXES[i].icon = item:GetItemIcon()
                Loot.JUNKBOXES[i].link = item:GetItemLink()
            end)
        end
    end
end

function Loot.GetDefaultJunkboxPrice(itemId)
	for i = 1, #Loot.JUNKBOXES do
        if Loot.JUNKBOXES[i].itemId == itemId then
            return Loot.JUNKBOXES[i].price 
        end
    end
	return nil
end

function Loot.IsJunkbox(itemId)
	for i = 1, #Loot.JUNKBOXES do
        if Loot.JUNKBOXES[i].itemId == itemId then
            return true
        end
    end
	return false
end

function Loot.GetJunkboxList()
    local junkboxes = {}
    for i = 1, #Loot.JUNKBOXES do
        junkboxes[Loot.JUNKBOXES[i].itemId] = Loot.JUNKBOXES[i].name
    end
	return junkboxes
end

function Loot.GetJunkboxFromGuid(guid)
    local itemIdFromGuid = C_Item.GetItemIDByGUID(guid)
	for i = 1, #Loot.JUNKBOXES do
        if Loot.JUNKBOXES[i].itemId == itemIdFromGuid then
            return Loot.JUNKBOXES[i]
        end
    end
	return nil
end

function Loot.GetJunkboxFromItemId(id)
	for i = 1, #Loot.JUNKBOXES do
        if Loot.JUNKBOXES[i].itemId == id then
            return Loot.JUNKBOXES[i]
        end
    end
	return nil
end

Loot.CacheJunkboxInfo()