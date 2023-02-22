if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local UI = Addon:GetModule("ArtfulDodger_UI")
local Stats = Addon:GetModule("ArtfulDodger_Stats")
local CMD = Addon:NewModule("ArtfulDodger_ChatCommands", "AceConsole-3.0", "AceEvent-3.0")
local Events = Addon.Events

CMD:RegisterChatCommand("adl", "ChatCommandListener")

function CMD:ChatCommandListener(input)
	local input = strlower(input)
	
	if input == "global" then
		print(Stats:GetPrettyPrintTotalLootedString())
	elseif input == "session" then
		print(Stats:GetPrettyPrintSessionLootedString())
	elseif input == "toggle" then
		CMD:SendMessage(Events.UI.Toggle)
	elseif input == "reset session" then
		CMD:SendMessage(Events.Session.Reset)
	elseif input == "reset history" then
		CMD:SendMessage(Events.Session.Reset)
		CMD:SendMessage(Events.History.Reset)
		CMD:SendMessage(Events.UnitFrame.Reset)
	elseif input == "help" or input == "" then
		print("Usage")
		print("/adl help")
		print("/adl global - List all recorded statistics")
		print("/adl session - List current play session statistics")
		print("/adl toggle - Open or close the Addon window")
		print("/adl reset session - Clear data from current play session")
		print("/adl reset history - Clear all data")
	end
end