if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local Stats = Addon:GetModule("ArtfulDodger_Stats")
local Cmd = Addon:NewModule("ArtfulDodger_ChatCommands", "AceConsole-3.0", "AceEvent-3.0")
local Events = Addon.Events
local L = Addon.Localizations

Cmd:RegisterChatCommand(L["adl"], "ChatCommandListener")

function Cmd:ChatCommandListener(input)
	local input = strlower(input)
	
	if input == L["history"] then
		print(Stats:GetPrettyPrintTotalLootedString())
	elseif input == L["session"] then
		print(Stats:GetPrettyPrintSessionLootedString())
	elseif input == L["toggle"] then
		Cmd:SendMessage(Events.UI.Toggle)
	elseif input == L["reset"].." "..L["session"] then
		Cmd:SendMessage(Events.Session.Reset)
	elseif input == L["reset"].." "..L["history"] then
		Cmd:SendMessage(Events.Session.Reset)
		Cmd:SendMessage(Events.History.Reset)
		Cmd:SendMessage(Events.UnitFrame.Reset)
	elseif input == L["help"] or input == "" then
		print(L["Usage"])
		print(L["/adl"].." "..L["help"])
		print(L["/adl"].." "..L["history"].." - "..L["List all recorded statistics"])
		print(L["/adl"].." "..L["session"].." - "..L["List current play session statistics"])
		print(L["/adl"].." "..L["toggle"].." - "..L["Open or close the Addon window"])
		print(L["/adl"].." "..L["reset"].." "..L["session"].." - "..L["Clear data from current play session"])
		print(L["/adl"].." "..L["reset"].." "..L["history"].." - "..L["Clear all data"])
	end
end