if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local AceGUI = LibStub("AceGUI-3.0")
local Loot = Addon.Loot

local bt = {}
Addon.BaseTable = bt

bt.DATE_FORMAT = "%Y/%m/%d %H:%M:%S"
bt.HEADERS = {}

function bt:New(dataSource)
    local o = {}
    setmetatable(o, self)
    self.__index = self

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

    self.tableHeader = self:Header()

	self.tableGroup = AceGUI:Create("SimpleGroup")
    self.tableGroup:SetFullWidth(true)
    self.tableGroup:AddChild(self.tableHeader)
    self.tableGroup:AddChild(self.scrollGroup)
	
	self.dataSource = dataSource or {}
	
	self.pageSize = 20
	self.currentIndex = #self.dataSource
	self.previousIndex = #self.dataSource

	return o
end

function bt:GetFrame()
	return self.tableGroup
end

function bt:DataSource(dataSource)
	self.dataSource = dataSource
	self.currentIndex = #self.dataSource
	self.previousIndex = #self.dataSource
end

function bt:Header()
	local tableHeader = AceGUI:Create("SimpleGroup")
	tableHeader:SetFullWidth(true)
	tableHeader:SetLayout("Flow")

    if self.HEADERS then
        for _, header in ipairs(self.HEADERS) do
            tableHeader:AddChild(self:HeaderCell(header.name, header.width)) 
        end
    end

    return tableHeader
end

function bt:Row()
	local row = AceGUI:Create("SimpleGroup")
	row:SetFullWidth(true)
	row:SetLayout("Flow")
	row:SetHeight(20)
    return row
end

function bt:Cell(label)
	local cell = AceGUI:Create("Label")
	cell:SetText(label)
	cell:SetWidth(90)
	return cell
end

function bt:ItemCell(link, image, quantity)
	local cell = AceGUI:Create("Icon")
	cell:SetImage(image)
	cell:SetImageSize(20,20)
	cell:SetWidth(23)
	cell:SetHeight(20)
	cell:SetCallback("OnEnter", function(widget)
		GameTooltip:SetOwner(widget.frame, "ANCHOR_NONE")
		GameTooltip:SetPoint("TOPLEFT", widget.frame, "BOTTOMLEFT")
		GameTooltip:ClearLines()
		GameTooltip:SetHyperlink(link)
		GameTooltip:AddLine("Quantity: "..(quantity or 1))
		GameTooltip:Show()
	end)
	cell:SetCallback("OnLeave", function()
		GameTooltip:Hide()
	end)
	return cell
end

function bt:CoinCell(price)
	local cell = AceGUI:Create("Icon")
	cell:SetImage(Loot.COIN_ICON)
	cell:SetImageSize(20,20)
	cell:SetWidth(23)
	cell:SetHeight(20)
	cell:SetCallback("OnEnter", function(widget)
		GameTooltip:SetOwner(widget.frame, "ANCHOR_NONE")
		GameTooltip:SetPoint("TOPLEFT", widget.frame, "BOTTOMLEFT")
		GameTooltip:ClearLines()
		GameTooltip:SetText(Loot.COIN_LINK.."\nAmount: "..GetCoinTextureString(price))
		GameTooltip:Show()
	end)
	cell:SetCallback("OnLeave", function()
		GameTooltip:Hide()
	end)
	return cell
end

function bt:HeaderCell(name, width)
	local cell = AceGUI:Create("InteractiveLabel")
	cell:SetText(name)
	cell:SetWidth(width)
	cell:SetFontObject(GameFontNormal)
	cell:SetHeight(20)
	return cell
end

function bt:Next()
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

function bt:Previous()
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

function bt:Fill(start, finish)
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