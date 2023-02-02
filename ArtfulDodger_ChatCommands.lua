if UnitClass("player") ~= "Rogue" then
    return
end

local addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local ui = addon:GetModule("ArtfulDodger_UI")
local cmd = addon:NewModule("ArtfulDodger_ChatCommands", "AceConsole-3.0")

cmd:RegisterChatCommand("adl", "ChatCommandListener")

function cmd:ChatCommandListener(input)
	local input = strlower(input)
	
	if input == "global" then
		print(addon:GetPrettyPrintTotalLootedString())
	elseif input == "session" then
		print(addon:GetPrettyPrintSessionLootedString())
	elseif input == "toggle" then
		ui:ToggleUI()
	elseif input == "clear session" then
		addon:ResetSessionStats()
	elseif input == "clear all" then
		addon:ResetAll()
	elseif input == "help" or input == "" then
		print("Usage")
		print("/adl help")
		print("/adl global - List all recorded statistics")
		print("/adl session - List current play session statistics")
		print("/adl toggle - Open or close the addon window")
		print("/adl clear session - Clear data from current play session")
		print("/adl clear all - Clear all data")
	end
end