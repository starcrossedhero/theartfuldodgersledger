if UnitClass('player') ~= 'Rogue' then
    return
end

local addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local ppt = addon:NewModule("ArtfulDodger_PickPocketTable", "AceEvent-3.0")
local AceGUI = LibStub("AceGUI-3.0")

local DATE_FORMAT = "%Y/%m/%d %H:%M:%S"

function ppt:New(dataSource)
	self.scrollFrame = AceGUI:Create("ScrollFrame")
	self.scrollFrame:SetFullWidth(true)
	self.scrollFrame:SetLayout("Flow")
	self.scrollFrame:SetPoint("TOP")

	self.scrollGroup = AceGUI:Create("SimpleGroup")
	self.scrollGroup:SetFullWidth(true)
	self.scrollGroup:SetHeight(400)
	self.scrollGroup:SetLayout("Fill")
	self.scrollGroup:SetPoint("TOP")
	self.scrollGroup:AddChild(self.scrollFrame)

	self.tableGroup = AceGUI:Create("SimpleGroup")
    self.tableGroup:SetFullWidth(true)
    self.tableGroup:SetHeight(500)
    self.tableGroup:AddChild(ppt:Header())
    self.tableGroup:AddChild(self.scrollGroup)
	
	self.dataSource = dataSource or {}
	
	self.pageSize = 20
	self.currentIndex = #self.dataSource
	self.previousIndex = #self.dataSource

	self:RegisterMessage("ArtfulDodger_PickPocketTable_Next", "Next")
	self:RegisterMessage("ArtfulDodger_PickPocketTable_Previous", "Previous")

	self:Next()

	return self
end

function ppt:GetFrame()
	return self.scrollGroup
end

function ppt:DataSource(dataSource)
	self.dataSource = dataSource
	self.currentIndex = #self.dataSource
	self.previousIndex = #self.dataSource
	self:Next()
end

function ppt:Row()
	local row = AceGUI:Create("SimpleGroup")
	row:SetFullWidth(true)
	row:SetLayout("Flow")
	row:SetHeight(20)
    return row
end

function ppt:Cell(title, image, price, quantity)
	local cell

	if image then
		cell = AceGUI:Create("Icon")
		cell:SetImage(image)
		cell:SetImageSize(20,20)
		cell:SetWidth(23)
		cell:SetCallback("OnEnter", function(widget)
			if title then
				if price and string.match(title, "Coin") then
					GameTooltip:SetOwner(widget.frame, "ANCHOR_NONE")
					GameTooltip:SetPoint("TOPLEFT", widget.frame, "BOTTOMLEFT")
					GameTooltip:ClearLines()
					GameTooltip:SetText(title.."\nAmount: "..price)
					GameTooltip:Show()
				else
					GameTooltip:SetOwner(widget.frame, "ANCHOR_NONE")
					GameTooltip:SetPoint("TOPLEFT", widget.frame, "BOTTOMLEFT")
					GameTooltip:ClearLines()
					GameTooltip:SetHyperlink(title)
					GameTooltip:AddLine("Quantity: "..(quantity or 1))
					GameTooltip:Show()
				end
			end
		end)
		cell:SetCallback("OnLeave", function()
			GameTooltip:Hide()
		end)
	else
		cell = AceGUI:Create("Label")
		cell:SetText(title)
		cell:SetWidth(90)
	end

	cell:SetHeight(20)

	return cell
end

function ppt:Next()
	if self.currentIndex >= 0 and self.currentIndex <= #self.dataSource then
		if self.previousIndex - self.pageSize >= 0 - self.pageSize then
			local newIndex
			if self.currentIndex < self.previousIndex then
				newIndex = math.min(self.currentIndex - self.pageSize, #self.dataSource)
			else
				newIndex = math.min(self.previousIndex - self.pageSize, #self.dataSource)
			end
			self:Fill(newIndex + self.pageSize, newIndex)
			self.previousIndex = self.currentIndex
			self.currentIndex = newIndex
		end
	end
end

function ppt:Previous()
	if self.currentIndex <= #self.dataSource and self.previousIndex <= #self.dataSource then
		if self.previousIndex + self.pageSize <= #self.dataSource then
			local newIndex
			if self.currentIndex > self.previousIndex then
				newIndex = math.min(self.currentIndex + self.pageSize, #self.dataSource)
			else
				newIndex = math.min(self.previousIndex + self.pageSize, #self.dataSource)
			end
			self:Fill(newIndex, newIndex - self.pageSize)
			self.previousIndex = self.currentIndex
			self.currentIndex = newIndex
		end
	end
end

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
					if item.name == "Coin" then
						table.insert(icons, self:Cell(item.link, item.icon, GetCoinTextureString(item.price)))
					else
						table.insert(icons, self:Cell(item.link, item.icon, nil, item.quantity))
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

function ppt:AddHeaders(parent)
	ppt:AddHeader(parent, "Time")
	ppt:AddHeader(parent, "Map")
	ppt:AddHeader(parent, "Area")
	ppt:AddHeader(parent, "Victim")
	ppt:AddHeader(parent, "Price")
	ppt:AddHeader(parent, "Items")
end

function ppt:AddHeader(parent, column, width)
	local header = AceGUI:Create("InteractiveLabel")
	header:SetText(column)
	if width then
		header:SetWidth(width)
	else
		header:SetWidth(90)
	end
	header:SetFontObject(GameFontNormal)
	parent:AddChild(header)
end


function ppt:Header()
	local header = AceGUI:Create("SimpleGroup")
	header:SetFullWidth(true)
	header:SetLayout("Flow")
	ppt:AddHeaders(header)
	return header
end