if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local AceGUI = LibStub("AceGUI-3.0")
local Loot = Addon.Loot
local L = Addon.Localizations

local BaseTable = Addon.BaseTable

local PickPocketTable = {}
PickPocketTable.__index = PickPocketTable
setmetatable(PickPocketTable, BaseTable)

Addon.PickPocketTable = PickPocketTable

local HEADERS = {
	{
		name = L["Time"],
		width = 90
	},
	{
		name = L["Map"],
		width = 90
	},
	{
		name = L["Area"],
		width = 90
	},
	{
		name = L["Victim"],
		width = 90
	},
	{
		name = L["Price"],
		width = 90
	},
	{
		name = L["Items"],
		width = 90
	}
}

function PickPocketTable:New(datasource)
	return setmetatable(BaseTable:New(datasource, HEADERS), self)
end

function PickPocketTable:Fill(start, finish)
	if self.dataSource and self.scrollGroup then
		self.scrollFrame:ReleaseChildren()
		for e = start, finish, -1 do
			if self.dataSource[e] then
				local event = self.dataSource[e]
				local row = self:Row()
				row:AddChild(self:Cell(date(self.DATE_FORMAT, event.timestamp)))
				row:AddChild(self:Cell(C_Map.GetMapInfo(event.mapId).name))
				row:AddChild(self:Cell(event.areaName))
				row:AddChild(self:Cell(event.victim.name))
				local icons = {}
				local totalPrice = 0
				for i = 1, #event.loot do
					local item = event.loot[i]
					if item.isItem then
						table.insert(icons, self:ItemCell(item.link, item.icon, item.quantity))
					else
						table.insert(icons, self:CoinCell(item.price))
					end
					totalPrice = totalPrice + item.price
				end
				row:AddChild(self:Cell(GetCoinTextureString(totalPrice)))
				if icons then
					for i = 1, #icons do
						row:AddChild(icons[i])
					end
				end
				self.scrollFrame:AddChild(row)
			end
		end
	end
end