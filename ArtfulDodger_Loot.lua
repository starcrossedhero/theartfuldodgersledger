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
	{itemId=16882, price=74},
	{itemId=16883, price=124},
	{itemId=16884, price=254},
	{itemId=16885, price=376},
    {itemId=63349, price=1196},
    {itemId=43575, price=376},
    {itemId=29569, price=371},
    {itemId=88165, price=12786}
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

function loot:NewItem(sourceGuid, itemId, name, link, icon, quantity, price)
    return loot:New(sourceGuid, name, link, icon, quantity, quality, price, true)
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

function loot.GetJunkboxItemIdFromGuid(guid)
	for i = 1, #JUNKBOXES do
        if JUNKBOXES[i].guid == guid then
            return JUNKBOXES[i].itemId
        end
    end
	return nil
end