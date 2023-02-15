if UnitClass('player') ~= 'Rogue' then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local AceGUI = LibStub("AceGUI-3.0")
local Loot = Addon.Loot

local ppt = Addon.BaseTable:New()
Addon.PickPocketTable = ppt

ppt.HEADERS = {
	{
		name = "Time",
		width = 90
	},
	{
		name = "Map",
		width = 90
	},
	{
		name = "Area",
		width = 90
	},
	{
		name = "Victim",
		width = 90
	},
	{
		name = "Price",
		width = 90
	},
	{
		name = "Items",
		width = 90
	}
}

function ppt:Fill(start, finish)
	if self.dataSource and self.scrollGroup then
		self.scrollFrame:ReleaseChildren()
		for e = start, finish, -1 do
			if self.dataSource[e] then
				local event = self.dataSource[e]
				local row = self:Row()
				row:AddChild(self:Cell(date(DATE_FORMAT, event.timestamp)))
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