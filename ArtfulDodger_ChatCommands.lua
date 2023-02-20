if select(3, UnitClass("player")) ~= 4 then
    return
end

local addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local ui = addon:GetModule("ArtfulDodger_UI")
local stats = addon:GetModule("ArtfulDodger_Stats")
local cmd = addon:NewModule("ArtfulDodger_ChatCommands", "AceConsole-3.0", "AceEvent-3.0")

cmd:RegisterChatCommand("adl", "ChatCommandListener")

function cmd:ChatCommandListener(input)
	local input = strlower(input)
	
	if input == "global" then
		print(stats:GetPrettyPrintTotalLootedString())
	elseif input == "session" then
		print(stats:GetPrettyPrintSessionLootedString())
	elseif input == "toggle" then
		ui:ToggleUI()
	elseif input == "reset session" then
		cmd:SendMessage("ArtfulDodger_ResetStats")
	elseif input == "reset all" then
		cmd:SendMessage("ArtfulDodger_ResetStats")
		cmd:SendMessage("ArtfulDodger_ResetHistory")
	elseif input == "help" or input == "" then
		print("Usage")
		print("/adl help")
		print("/adl global - List all recorded statistics")
		print("/adl session - List current play session statistics")
		print("/adl toggle - Open or close the addon window")
		print("/adl reset session - Clear data from current play session")
		print("/adl reset all - Clear all data")
	end
end