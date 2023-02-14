if UnitClass('player') ~= 'Rogue' then
    return
end

local addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local ui = addon:NewModule("ArtfulDodger_UI", "AceEvent-3.0")
local map = addon:GetModule("ArtfulDodger_Map")
local stats = addon:GetModule("ArtfulDodger_Stats")
local loot = addon:GetModule("ArtfulDodger_Loot")
local PickPocketTable = addon:GetModule("ArtfulDodger_PickPocketTable")
local JunkboxTable = addon:GetModule("ArtfulDodger_JunkboxTable")
local AceGUI = LibStub("AceGUI-3.0")

local LOOT_TOTAL_STRING = "|cffeec300  Pilfered coin:  |cffFFFFFF%s  |r"
local LOOT_MARKS_STRING = "|cffeec300     Picked pockets:  |cffFFFFFF%d  |r"
local LOOT_AVERAGE_STRING = "|cffeec300  Typical purse:  |cffFFFFFF%s  |r"

local DATE_FORMAT = "%Y/%m/%d %H:%M"

local BASE_UI_FRAME, JUNKBOX_HISTORY_TABLE, PICKPOCKET_HISTORY_TABLE

local mapTotalLabel, mapAverageLabel, mapMarksLabel

function ui:OnEnable()
    ui.db = addon.db
	ui:RegisterMessage("ArtfulDodger_MapDropdown_Changed", "StatDisplayMapUpdate")
	ui:RegisterMessage("ArtfulDodger_VictimDropdown_Changed", "StatDisplayVictimUpdate")
end

function ui:ToggleUI()
	if BASE_UI_FRAME then
		BASE_UI_FRAME:Release()
		BASE_UI_FRAME = nil
	else
		BASE_UI_FRAME = ui:CreateBaseUI()
	end
end

function ui:CreateSettingsDisplay()
	local settingsContainer = AceGUI:Create("SimpleGroup")
	settingsContainer:SetFullWidth(true)
	settingsContainer:SetLayout("Flow")
    
    local mapCheckbox = AceGUI:Create("CheckBox")
    mapCheckbox:SetType("checkbox")
    mapCheckbox:SetLabel("World Map Display")
    mapCheckbox:SetDescription("Shows map loot stats on world map")
	mapCheckbox:SetValue(addon.db.settings.map.enabled)
    mapCheckbox:SetCallback("OnValueChanged", function(_, event, value) ui:SendMessage("ArtfulDodger_ToggleMap", value) end)
	settingsContainer:AddChild(mapCheckbox)

	local unitFrameCheckbox = AceGUI:Create("CheckBox")
    unitFrameCheckbox:SetType("checkbox")
    unitFrameCheckbox:SetLabel("Unit Frame Display")
    unitFrameCheckbox:SetDescription("Shows icon on UnitFrames to indicate a unit can likely be pick pocketed")
	unitFrameCheckbox:SetValue(addon.db.settings.unitFrame.enabled)
    unitFrameCheckbox:SetCallback("OnValueChanged", function(_, event, value) ui:SendMessage("ArtfulDodger_ToggleUnitFrame", value) end)
	settingsContainer:AddChild(unitFrameCheckbox)

	local tooltipCheckbox = AceGUI:Create("CheckBox")
    tooltipCheckbox:SetType("checkbox")
    tooltipCheckbox:SetLabel("Tooltip Display")
    tooltipCheckbox:SetDescription("Shows average purse size from victim in tooltip")
	tooltipCheckbox:SetValue(addon.db.settings.tooltip.enabled)
    tooltipCheckbox:SetCallback("OnValueChanged", function(_, event, value) ui:SendMessage("ArtfulDodger_ToggleTooltip", value) end)
	settingsContainer:AddChild(tooltipCheckbox)

	local resetSessionButton = AceGUI:Create("Button")
	resetSessionButton:SetText("Reset Current Session")
	resetSessionButton:SetWidth(200)
	resetSessionButton:SetCallback("OnClick", function() ui:SendMessage("ArtfulDodger_ResetSession") end)
	settingsContainer:AddChild(resetSessionButton)

	local resetHistoryButton = AceGUI:Create("Button")
	resetHistoryButton:SetText("Reset History")
	resetHistoryButton:SetWidth(200)
	resetHistoryButton:SetCallback("OnClick", function() ui:SendMessage("ArtfulDodger_ResetHistory") end)
	settingsContainer:AddChild(resetHistoryButton)

	return settingsContainer
end

function ui:CreateFilterSettings(historyTable)
	local maps = stats:GetMaps()
	local mapHistory

	local group = AceGUI:Create("SimpleGroup")
	group:SetFullWidth(true)
	group:SetLayout("Flow")

	local mapsDropdown = AceGUI:Create("Dropdown")
	local victimsDropdown = AceGUI:Create("Dropdown")

    mapsDropdown:SetLabel("Maps")
    mapsDropdown:SetRelativeWidth(0.3)
	mapsDropdown:SetList(maps)
	mapsDropdown:AddItem("All", "All Maps")
	mapsDropdown:SetValue("All")
    mapsDropdown:SetCallback("OnValueChanged", function(key)
		local mapId = key.value

		if mapId == "All" then
			historyTable:DataSource(ui.db.history.pickpocket)
			victimsDropdown:SetValue("All")
			victimsDropdown:SetDisabled(true)
		else
			mapHistory = addon:GetHistoryByMapId(mapId)
            historyTable:DataSource(mapHistory)
			victimsDropdown:SetDisabled(false)
			victimsDropdown:SetList(stats:GetVictims(mapId))
			victimsDropdown:AddItem("All", "All Victims")
			victimsDropdown:SetValue("All")
		end
		ui:SendMessage("ArtfulDodger_MapDropdown_Changed", mapId)
    end)

	victimsDropdown:SetDisabled(true)
	victimsDropdown:SetLabel("Victims")
	victimsDropdown:SetRelativeWidth(0.3)
	victimsDropdown:AddItem("All", "All Victims")
	victimsDropdown:SetValue("All")
	victimsDropdown:SetCallback("OnValueChanged", function(key)
		local npcId = key.value

		if npcId == "All" then
			historyTable:DataSource(mapHistory)
		else
			local victimHistory = addon:GetHistoryFromTableByNpcId(mapHistory, npcId)
			historyTable:DataSource(victimHistory)
		end
		ui:SendMessage("ArtfulDodger_VictimDropdown_Changed", mapHistory[1].mapId, npcId)
	end)

	group:AddChild(mapsDropdown)
	group:AddChild(victimsDropdown)

	return group
end

function ui:CreateJunkboxFilter(historyTable)
	local group = AceGUI:Create("SimpleGroup")
	group:SetFullWidth(true)
	group:SetLayout("Flow")

	local junkboxDropdown = AceGUI:Create("Dropdown")

    junkboxDropdown:SetLabel("Maps")
    junkboxDropdown:SetRelativeWidth(0.3)
	junkboxDropdown:SetList(loot.GetJunkboxList())
	junkboxDropdown:AddItem("All", "All Junkboxes")
	junkboxDropdown:SetValue("All")
    junkboxDropdown:SetCallback("OnValueChanged", function(key)
		local junkboxId = key.value
		print(junkboxId)

		if junkboxId == "All" then
			historyTable:DataSource(ui.db.history.junkboxes)
		else
			local junkboxHistory = addon:GetHistoryByJunkboxId(junkboxId)
			historyTable:DataSource(junkboxHistory)
		end
    end)

	group:AddChild(junkboxDropdown)

	return group
end

function ui:CreateStatsDisplay()
	local container = AceGUI:Create("SimpleGroup")
	container:SetFullWidth(true)
	container:SetLayout("Flow")
    container:SetHeight(150)

	mapTotalLabel = AceGUI:Create("Label")
	mapTotalLabel:SetRelativeWidth(0.3)
	mapTotalLabel:SetPoint("BOTTOM")
	mapTotalLabel:SetFontObject(GameFontNormal)
	
	mapAverageLabel = AceGUI:Create("Label")
	mapAverageLabel:SetRelativeWidth(0.3)
	mapAverageLabel:SetPoint("BOTTOM")
	mapAverageLabel:SetFontObject(GameFontNormal)
	
	mapMarksLabel = AceGUI:Create("Label")
	mapMarksLabel:SetRelativeWidth(0.3)
	mapMarksLabel:SetPoint("BOTTOM")
	mapMarksLabel:SetFontObject(GameFontNormal)

    mapMarksLabel:SetText(ui:GetVictimString(stats.db.history.thefts))
    mapAverageLabel:SetText(ui:GetAverageString(addon:GetCopperPerVictim(stats.db.history.copper, stats.db.history.thefts)))
    mapTotalLabel:SetText(ui:GetTotalString(stats.db.history.copper))

    container:AddChild(mapMarksLabel)
    container:AddChild(mapTotalLabel)
    container:AddChild(mapAverageLabel)

	return container
end

function ui:StatDisplayMapUpdate(_, mapId)
	if mapId == "All" then
		mapMarksLabel:SetText(ui:GetVictimString(stats.db.history.thefts))
		mapAverageLabel:SetText(ui:GetAverageString(addon:GetCopperPerVictim(stats.db.history.copper, stats.db.history.thefts)))
		mapTotalLabel:SetText(ui:GetTotalString(stats.db.history.copper))
	else
		local stats = stats:GetStatsForMapId(mapId)
		mapMarksLabel:SetText(ui:GetVictimString(stats.thefts))
		mapAverageLabel:SetText(ui:GetAverageString(addon:GetCopperPerVictim(stats.copper, stats.thefts)))
		mapTotalLabel:SetText(ui:GetTotalString(stats.copper))
	end
end

function ui:StatDisplayVictimUpdate(_, mapId, npcId)
	print(mapId, npcId)
	if npcId == "All" then
		local stats = stats:GetStatsForMapId(mapId)
		mapMarksLabel:SetText(ui:GetVictimString(stats.thefts))
		mapAverageLabel:SetText(ui:GetAverageString(addon:GetCopperPerVictim(stats.copper, stats.thefts)))
		mapTotalLabel:SetText(ui:GetTotalString(stats.copper))
	else
		local stats = stats:GetStatsByMapIdAndNpcId(mapId, npcId)
		mapMarksLabel:SetText(ui:GetVictimString(stats.thefts))
		mapAverageLabel:SetText(ui:GetAverageString(addon:GetCopperPerVictim(stats.copper, stats.thefts)))
		mapTotalLabel:SetText(ui:GetTotalString(stats.copper))
	end
end

function ui:GetVictimString(marks)
    return string.format(LOOT_MARKS_STRING, marks)
end

function ui:GetTotalString(copper)
    return string.format(LOOT_TOTAL_STRING, GetCoinTextureString(copper))
end

function ui:GetAverageString(copper)
    return string.format(LOOT_AVERAGE_STRING, GetCoinTextureString(copper))
end

function ui:CreateBaseUI()
	local tab =  AceGUI:Create("TabGroup")
	tab:SetLayout("Flow")
	tab:SetTabs({{text="Picked Pockets", value="tab1"}, {text="Junkboxes", value="tab2"}, {text="Settings", value="tab3"}})
	tab:SetCallback("OnGroupSelected", function(container, event, group)
		container:ReleaseChildren()
		if 	   group == "tab1" then
			local historyTable = PickPocketTable:New(ui.db.history.pickpocket)
			container:AddChild(ui:CreateFilterSettings(historyTable))
			container:AddChild(historyTable:GetFrame())
			container:AddChild(ui:CreateStatsDisplay())
			container:AddChild(ui:TableButtons("ArtfulDodger_PickPocketTable_Next", "ArtfulDodger_PickPocketTable_Previous"))
		elseif group == "tab2" then
			local junkboxTable = JunkboxTable:New(ui.db.history.junkboxes)
			container:AddChild(ui:CreateJunkboxFilter(junkboxTable))
			container:AddChild(junkboxTable:GetFrame())
			container:AddChild(ui:CreateStatsDisplay())
			container:AddChild(ui:TableButtons("ArtfulDodger_JunkboxTable_Next", "ArtfulDodger_JunkboxTable_Previous"))
		elseif group == "tab3" then
			container:AddChild(ui:CreateSettingsDisplay())
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
		ui:ToggleUI()
	end)
	frame:AddChild(tab)

	return frame
end

function ui:TableButtons(nextEvent, previousEvent)
	local buttons = AceGUI:Create("SimpleGroup")
	buttons:SetHeight(50)
	buttons:SetPoint("BOTTOM")
	buttons:SetFullWidth(true)
	buttons:SetLayout("Flow")

	local nextButton = AceGUI:Create("Button")
	nextButton:SetHeight(30)
	nextButton:SetText("Next Page")
	nextButton:SetRelativeWidth(0.5)
	nextButton:SetCallback("OnClick", function() ui:SendMessage(nextEvent) end)

	local previousButton = AceGUI:Create("Button")
	previousButton:SetHeight(30)
	previousButton:SetText("Previous Page")
	previousButton:SetRelativeWidth(0.5)
	previousButton:SetCallback("OnClick", function() ui:SendMessage(previousEvent) end)

	buttons:AddChild(previousButton)
	buttons:AddChild(nextButton)

	return buttons
end