if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local AceGUI = LibStub("AceGUI-3.0")
local Loot = Addon.Loot
local L = Addon.Localizations

local jbt = Addon.BaseTable:New()
Addon.JunkboxTable = jbt

jbt.HEADERS = {
	{
		name = L["Time"],
		width = 90
	},
	{
		name = L["Junkbox"],
		width = 250
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

function jbt:JunkboxCell(link, image, label)
    local cell = AceGUI:Create("InteractiveLabel")
    cell:SetImage(image)
    cell:SetImageSize(20,20)
    cell:SetWidth(250)
    cell:SetText(label)
    cell:SetCallback("OnEnter", function(widget)
        GameTooltip:SetOwner(widget.frame, "ANCHOR_NONE")
        GameTooltip:SetPoint("TOPLEFT", widget.frame, "BOTTOMLEFT")
        GameTooltip:ClearLines()
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
    end)
    cell:SetCallback("OnLeave", function()
        GameTooltip:Hide()
    end)

    return cell
end

function jbt:Fill(start, finish)
	if self.dataSource and self.scrollGroup then
		self.scrollFrame:ReleaseChildren()
		for e = start, finish, -1 do
			if self.dataSource[e] then
				local event = self.dataSource[e]
                local junkbox = Loot.GetJunkboxFromItemId(event.itemId)
				local icons = {}
				local totalPrice = 0
				local row = self:Row()
                row:AddChild(self:Cell(date(self.DATE_FORMAT, event.timestamp)))
				row:AddChild(self:JunkboxCell(junkbox.link, junkbox.icon, junkbox.name))
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