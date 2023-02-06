if UnitClass('player') ~= 'Rogue' then
    return
end

local addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local loot = addon:NewModule("ArtfulDodger_Loot")

local CURRENCY_ID
local CURRENCY_COLOR = "|cFFCC9900"
local CURRENCY_STRING = "Coin"
local CURRENCY_LINK = CURRENCY_COLOR..CURRENCY_STRING.."|r"
local CURRENCY_ICON_ID = "Interface\\Icons\\INV_Misc_Coin_01"

local JUNKBOXES = {
	{itemId=16882, icon=132594, link="\124cffffffff\124Hitem:16882::::::::70:::::\124h[Battered Junkbox]\124h\124r", price=74},
	{itemId=16883, icon=132594, link="\124cffffffff\124Hitem:16883::::::::70:::::\124h[Worn Junkbox]\124h\124r", price=124},
	{itemId=16884, icon=132596, link="\124cffffffff\124Hitem:16884::::::::70:::::\124h[Sturdy Junkbox]\124h\124r", price=254},
	{itemId=16885, icon=132596, link="\124cffffffff\124Hitem:16885::::::::70:::::\124h[Heavy Junkbox]\124h\124r", price=376},
    {itemId=63349, icon=132597, link="\124cffffffff\124Hitem:63349::::::::70:::::\124h[Flame-Scarred Junkbox]\124h\124r", price=1196},
    {itemId=43575, icon=132597, link="\124cffffffff\124Hitem:43575::::::::70:::::\124h[Reinforced Junkbox]\124h\124r", price=376},
    {itemId=29569, icon=132595, link="\124cffffffff\124Hitem:29569::::::::70:::::\124h[Strong Junkbox]\124h\124r", price=371},
    {itemId=88165, icon=132596, link="\124cffffffff\124Hitem:88165::::::::70:::::\124h[Vine-Cracked Junkbox]\124h\124r", price=12786},
    {itemId=106895, icon=132596, link="\124cffffffff\124Hitem:106895::::::::70:::::\124h[Iron-Bound Junkbox]\124h\124r", price=12786}
}

Loot = {}
function loot:New(sourceGuid, id, name, link, icon, quantity, price, isItem)
	local this = {
        sourceGuid = sourceGuid,
        id = id,
		name = name,
		link = link,
		icon = icon,
		quantity = quantity,
        price = price,
        isItem = isItem
	}
    self.__index = self
	setmetatable(this, self)
	return this
end

function loot:ToString()
    return string.format("Loot: sourceGuid=%s, itemId=%s, name=%s, link=%s, icon=%s, quantity=%s, price=%s, isItem=%s", sourceGuid, id, name, link, icon, quantity, price, isItem)
end

function loot:NewItem(sourceGuid, itemId, name, link, icon, quantity, price)
    return loot:New(sourceGuid, itemId, name, link, icon, quantity, price, true)
end

function loot:NewCoin(sourceGuid, price)
    return loot:New(sourceGuid, -1, CURRENCY_STRING, CURRENCY_LINK, CURRENCY_ICON_ID, 1, price, false)
end

function loot.GetDefaultJunkboxPrice(itemId)
	for i = 1, #JUNKBOXES do
        if JUNKBOXES[i].itemId == itemId then
            return JUNKBOXES[i].price 
        end
    end
	return nil
end

function loot.IsJunkbox(itemId)
	for i = 1, #JUNKBOXES do
        if JUNKBOXES[i].itemId == itemId then
            return true
        end
    end
	return false
end

function loot.GetJunkboxes()
    return JUNKBOXES
end

function loot.GetJunkboxFromGuid(guid)
    local itemIdFromGuid = C_Item.GetItemIDByGUID(guid)
	for i = 1, #JUNKBOXES do
        if JUNKBOXES[i].itemId == itemIdFromGuid then
            return JUNKBOXES[i]
        end
    end
	return nil
end

function loot.GetJunkboxFromItemId(id)
	for i = 1, #JUNKBOXES do
        if JUNKBOXES[i].itemId == id then
            return JUNKBOXES[i]
        end
    end
	return nil
end