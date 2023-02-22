if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local UI = Addon:NewModule("ArtfulDodger_UI", "AceEvent-3.0")
local Stats = Addon:GetModule("ArtfulDodger_Stats")
local Loot = Addon.Loot
local PickPocketTable = Addon.PickPocketTable
local JunkboxTable = Addon.JunkboxTable
local Events = Addon.Events
local AceGUI = LibStub("AceGUI-3.0")

local BASE_UI_FRAME, mapTotalLabel, mapAverageLabel, mapMarksLabel

function UI:OnInitialize()
	UI:RegisterMessage(Events.UI.Toggle, "Toggle")
end

function UI:Toggle()
	if BASE_UI_FRAME then
		BASE_UI_FRAME:Release()
		BASE_UI_FRAME = nil
	else
		BASE_UI_FRAME = UI:CreateBaseUI()
	end
end

function UI:CreateSettingsDisplay()
	local settingsContainer = AceGUI:Create("SimpleGroup")
	settingsContainer:SetFullWidth(true)
	settingsContainer:SetLayout("Flow")

	local checkboxContainer = AceGUI:Create("SimpleGroup")
	checkboxContainer:SetFullWidth(true)
	checkboxContainer:SetLayout("Flow")

	local buttonContainer = AceGUI:Create("SimpleGroup")
	buttonContainer:SetFullWidth(true)
	buttonContainer:SetLayout("Flow")

	local minimapCheckbox = AceGUI:Create("CheckBox")
    minimapCheckbox:SetType("checkbox")
    minimapCheckbox:SetLabel("Minimap Button")
    minimapCheckbox:SetDescription("Add a button to the minimap to access the UI")
	minimapCheckbox:SetValue(not Addon.db.settings.minimap.hide)
    minimapCheckbox:SetCallback("OnValueChanged", function(_, event, value) UI:SendMessage(Events.Minimap.Toggle, not value) end)
	checkboxContainer:AddChild(minimapCheckbox)
    
    local mapCheckbox = AceGUI:Create("CheckBox")
    mapCheckbox:SetType("checkbox")
    mapCheckbox:SetLabel("World Map Display")
    mapCheckbox:SetDescription("Shows map loot stats on world map")
	mapCheckbox:SetValue(Addon.db.settings.map.enabled)
    mapCheckbox:SetCallback("OnValueChanged", function(_, event, value) UI:SendMessage(Events.Map.Toggle, value) end)
	checkboxContainer:AddChild(mapCheckbox)

	local unitFrameCheckbox = AceGUI:Create("CheckBox")
    unitFrameCheckbox:SetType("checkbox")
    unitFrameCheckbox:SetLabel("Unit Frame Display")
    unitFrameCheckbox:SetDescription("Shows icon on UnitFrames to indicate a unit can likely be pick pocketed")
	unitFrameCheckbox:SetValue(Addon.db.settings.unitFrame.enabled)
    unitFrameCheckbox:SetCallback("OnValueChanged", function(_, event, value) UI:SendMessage(Events.UnitFrame.Toggle, value) end)
	checkboxContainer:AddChild(unitFrameCheckbox)

	local tooltipCheckbox = AceGUI:Create("CheckBox")
    tooltipCheckbox:SetType("checkbox")
    tooltipCheckbox:SetLabel("Tooltip Display")
    tooltipCheckbox:SetDescription("Shows average purse size from victim in tooltip")
	tooltipCheckbox:SetValue(Addon.db.settings.tooltip.enabled)
    tooltipCheckbox:SetCallback("OnValueChanged", function(_, event, value) UI:SendMessage(Events.Tooltip.Toggle, value) end)
	checkboxContainer:AddChild(tooltipCheckbox)

	local openerCheckbox = AceGUI:Create("CheckBox")
    openerCheckbox:SetType("checkbox")
    openerCheckbox:SetLabel("Junkbox Opener")
    openerCheckbox:SetDescription("Creates a button to easily unlock and open junkboxes")
	openerCheckbox:SetValue(Addon.db.settings.opener.enabled)
    openerCheckbox:SetCallback("OnValueChanged", function(_, event, value) UI:SendMessage(Events.Opener.Toggle, value) end)
	checkboxContainer:AddChild(openerCheckbox)

	local resetSessionButton = AceGUI:Create("Button")
	resetSessionButton:SetText("Reset Current Session")
	resetSessionButton:SetWidth(200)
	resetSessionButton:SetCallback("OnClick", function() UI:SendMessage(Events.Session.Reset) end)
	buttonContainer:AddChild(resetSessionButton)

	local resetHistoryButton = AceGUI:Create("Button")
	resetHistoryButton:SetText("Reset History")
	resetHistoryButton:SetWidth(200)
	resetHistoryButton:SetCallback("OnClick", function() UI:SendMessage(Events.History.Reset) end)
	buttonContainer:AddChild(resetHistoryButton)

	local resetExclusionsButton = AceGUI:Create("Button")
	resetExclusionsButton:SetText("Reset Exclusions")
	resetExclusionsButton:SetWidth(200)
	resetExclusionsButton:SetCallback("OnClick", function() UI:SendMessage(Events.UnitFrame.Reset) end)
	
	buttonContainer:AddChild(resetExclusionsButton)

	settingsContainer:AddChild(checkboxContainer)
	settingsContainer:AddChild(buttonContainer)

	return settingsContainer
end

function UI:CreateFilterSettings(historyTable)
	local maps = Stats:GetMaps()
	local mapHistory

	local group = AceGUI:Create("SimpleGroup")
	group:SetFullWidth(true)
	group:SetLayout("Flow")

	local mapsDropdown = AceGUI:Create("Dropdown")
	local victimsDropdown = AceGUI:Create("Dropdown")

    mapsDropdown:SetLabel("Maps")
	mapsDropdown:SetHeight(50)
    mapsDropdown:SetRelativeWidth(0.3)
	mapsDropdown:SetList(maps)
	mapsDropdown:AddItem("All", "All Maps")
	mapsDropdown:SetValue("All")
    mapsDropdown:SetCallback("OnValueChanged", function(key)
		local mapId = key.value

		if mapId == "All" then
			historyTable:DataSource(Addon.db.history.pickpocket)
			historyTable:Next()
			victimsDropdown:SetValue("All")
			victimsDropdown:SetDisabled(true)
		else
			mapHistory = Addon:GetHistoryByMapId(mapId)
            historyTable:DataSource(mapHistory)
			historyTable:Next()
			victimsDropdown:SetDisabled(false)
			victimsDropdown:SetList(Stats:GetVictims(mapId))
			victimsDropdown:AddItem("All", "All Victims")
			victimsDropdown:SetValue("All")
		end
		UI:UpdatePickPocketStats(mapId)
    end)

	victimsDropdown:SetDisabled(true)
	victimsDropdown:SetLabel("Victims")
	victimsDropdown:SetHeight(50)
	victimsDropdown:SetRelativeWidth(0.3)
	victimsDropdown:AddItem("All", "All Victims")
	victimsDropdown:SetValue("All")
	victimsDropdown:SetCallback("OnValueChanged", function(key)
		local npcId = key.value

		if npcId == "All" then
			historyTable:DataSource(mapHistory)
			historyTable:Next()
		else
			local victimHistory = Addon:GetHistoryFromTableByNpcId(mapHistory, npcId)
			historyTable:DataSource(victimHistory)
			historyTable:Next()
		end
		UI:UpdatePickPocketStats(mapHistory[1].mapId, npcId)
	end)

	group:AddChild(mapsDropdown)
	group:AddChild(victimsDropdown)

	return group
end

function UI:CreateJunkboxFilter(historyTable)
	local group = AceGUI:Create("SimpleGroup")
	group:SetFullWidth(true)
	group:SetLayout("Flow")

	local junkboxDropdown = AceGUI:Create("Dropdown")

    junkboxDropdown:SetLabel("Maps")
	junkboxDropdown:SetHeight(50)
    junkboxDropdown:SetRelativeWidth(0.3)
	junkboxDropdown:SetList(Loot.GetJunkboxList())
	junkboxDropdown:AddItem("All", "All Junkboxes")
	junkboxDropdown:SetValue("All")
    junkboxDropdown:SetCallback("OnValueChanged", function(key)
		local junkboxId = key.value

		if junkboxId == "All" then
			historyTable:DataSource(Addon.db.history.junkboxes)
			historyTable:Next()
		else
			local junkboxHistory = Addon:GetHistoryByJunkboxId(junkboxId)
			historyTable:DataSource(junkboxHistory)
			historyTable:Next()
		end
		print(junkboxId)
		UI:UpdateJunkboxStats(junkboxId)
    end)

	group:AddChild(junkboxDropdown)

	return group
end

function UI:CreateStatsDisplay()
	local container = AceGUI:Create("SimpleGroup")
	container:SetFullWidth(true)
	container:SetLayout("Flow")
    container:SetHeight(150)

	mapTotalLabel = AceGUI:Create("Label")
	mapTotalLabel:SetRelativeWidth(0.33)
	mapTotalLabel:SetPoint("BOTTOM")
	mapTotalLabel:SetFontObject(GameFontNormal)
	mapTotalLabel:SetHeight(20)
	
	mapAverageLabel = AceGUI:Create("Label")
	mapAverageLabel:SetRelativeWidth(0.33)
	mapAverageLabel:SetPoint("BOTTOMRIGHT")
	mapAverageLabel:SetFontObject(GameFontNormal)
	mapAverageLabel:SetHeight(20)
	
	mapMarksLabel = AceGUI:Create("Label")
	mapMarksLabel:SetRelativeWidth(0.33)
	mapMarksLabel:SetPoint("BOTTOMLEFT")
	mapMarksLabel:SetFontObject(GameFontNormal)
	mapMarksLabel:SetHeight(20)

    mapMarksLabel:SetText(UI:PickPocketVictimString(Stats.db.history.thefts))
    mapAverageLabel:SetText(UI:PickPocketAverageString(Addon:GetCopperPerVictim(Stats.db.history.copper, Stats.db.history.thefts)))
    mapTotalLabel:SetText(UI:PickPocketTotalString(Stats.db.history.copper))

    container:AddChild(mapMarksLabel)
    container:AddChild(mapTotalLabel)
    container:AddChild(mapAverageLabel)

	return container
end

function UI:UpdateJunkboxStats(junkboxId)
	local junkboxStats
	if junkboxId == "All" then
		junkboxStats = Stats:GetStatsForJunkboxes()
	else
		junkboxStats = Stats:GetStatsByJunkboxId(junkboxId)
	end

	mapMarksLabel:SetText(UI:JunkboxesOpenedString(junkboxStats.thefts))
	mapAverageLabel:SetText(UI:JunkboxesAverageString(junkboxStats.copper, junkboxStats.thefts))
	mapTotalLabel:SetText(UI:JunkboxesTotalString(junkboxStats.copper))
end

function UI:UpdatePickPocketStats(mapId, npcId)
	local pickPocketStats
	if npcId then
		if npcId == "All" then
			pickPocketStats = Stats:GetStatsForMapId(mapId)
		else
			pickPocketStats = Stats:GetStatsByMapIdAndNpcId(mapId, npcId)
		end
	else
		if mapId == "All" then
			pickPocketStats = {thefts = Stats.db.history.thefts, copper = Stats.db.history.copper}
		else
			pickPocketStats = Stats:GetStatsForMapId(mapId)
		end
	end
	mapMarksLabel:SetText(UI:PickPocketVictimString(pickPocketStats.thefts))
	mapAverageLabel:SetText(UI:PickPocketAverageString(pickPocketStats.copper, pickPocketStats.thefts))
	mapTotalLabel:SetText(UI:PickPocketTotalString(pickPocketStats.copper))
end

function UI:JunkboxesOpenedString(count)
	return string.format("|cffeec300 Junkboxes Opened: |cffFFFFFF%d  |r", count)
end

function UI:JunkboxesTotalString(copper)
	return string.format("|cffeec300 Junkbox coin: |cffFFFFFF%s|r", GetCoinTextureString(copper))
end

function UI:JunkboxesAverageString(copper, count)
	return string.format("|cffeec300 Typical value: |cffFFFFFF%s  |r", GetCoinTextureString(Addon:GetCopperPerVictim(copper, count)))
end

function UI:PickPocketVictimString(victims)
    return string.format("|cffeec300 Picked pockets: |cffFFFFFF%d|r", victims)
end

function UI:PickPocketTotalString(copper)
    return string.format("|cffeec300 Pilfered coin: |cffFFFFFF%s|r", GetCoinTextureString(copper))
end

function UI:PickPocketAverageString(copper, thefts)
    return string.format("|cffeec300 Typical purse: |cffFFFFFF%s|r", GetCoinTextureString(Addon:GetCopperPerVictim(copper, thefts)))
end

function UI:CreateBaseUI()
	local tab =  AceGUI:Create("TabGroup")
	tab:SetLayout("Flow")
	tab:SetTabs({{text="Picked Pockets", value="tab1"}, {text="Junkboxes", value="tab2"}, {text="Settings", value="tab3"}})
	tab:SetCallback("OnGroupSelected", function(container, event, group)
		container:ReleaseChildren()
		if 	   group == "tab1" then
			local historyTable = PickPocketTable:New(Addon.db.history.pickpocket)
			container:AddChild(UI:CreateFilterSettings(historyTable))
			container:AddChild(historyTable:GetFrame())
			container:AddChild(UI:CreateStatsDisplay())
			container:AddChild(UI:TableButtons(historyTable))
			historyTable:Next()
			UI:UpdatePickPocketStats("All")
		elseif group == "tab2" then
			local junkboxTable = JunkboxTable:New(Addon.db.history.junkboxes)
			container:AddChild(UI:CreateJunkboxFilter(junkboxTable))
			container:AddChild(junkboxTable:GetFrame())
			container:AddChild(UI:CreateStatsDisplay())
			container:AddChild(UI:TableButtons(junkboxTable))
			junkboxTable:Next()
			UI:UpdateJunkboxStats("All")
		elseif group == "tab3" then
			container:AddChild(UI:CreateSettingsDisplay())
		end
		container:DoLayout()
	end)
	tab:SelectTab("tab1")

	local frame = AceGUI:Create("Window")
	frame:SetTitle("The Artful Dodger's Ledger")
	frame:SetLayout("Fill")
	frame:SetPoint("CENTER")
	frame:SetHeight(650)
	frame:SetWidth(650)
	frame:EnableResize(false)
	frame:SetCallback("OnClose", function(widget)
		UI:Toggle()
	end)
	frame:AddChild(tab)

	return frame
end

function UI:TableButtons(sourceTable)
	local buttons = AceGUI:Create("SimpleGroup")
	buttons:SetHeight(50)
	buttons:SetPoint("BOTTOM")
	buttons:SetFullWidth(true)
	buttons:SetLayout("Flow")

	local nextButton = AceGUI:Create("Button")
	nextButton:SetHeight(30)
	nextButton:SetText("Next Page")
	nextButton:SetRelativeWidth(0.5)
	nextButton:SetCallback("OnClick", function() sourceTable:Next() end)

	local previousButton = AceGUI:Create("Button")
	previousButton:SetHeight(30)
	previousButton:SetText("Previous Page")
	previousButton:SetRelativeWidth(0.5)
	previousButton:SetCallback("OnClick", function() sourceTable:Previous() end)

	buttons:AddChild(previousButton)
	buttons:AddChild(nextButton)

	return buttons
end