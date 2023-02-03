local addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local loot = addon:NewModule("ArtfulDodger_PickPocketLoot")

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

PickPocketLoot = {}
PickPocketLoot.__index = PickPocketLoot
function loot.New(name, link, icon, quantity, quality, price, isItem)
	local this = {
		name = name,
		link = link,
		icon = icon,
		quantity = quantity,
        quality = quality,
        price = price,
        isItem = isItem
	}
	setmetatable(this, self)
	return this
end

function loot.NewItem(name, link, icon, quantity, quality, price)
    return loot.New(name, link, icon, quantity, quality, price, true)
end

function loot.NewCoin(price)
    return loot.New(CURRENCY_STRING, CURRENCY_LINK, CURRENCY_ICON_ID, 1, 1, price, false)
end

function loot.GetJunkboxPrice(itemId)
	for i = 1, #JUNKBOXES do
        if JUNKBOXES[i].itemId == itemId then
            return JUNKBOXES[i].price 
        end
    end
	return nil
end