if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local Events = {
    History = {},
    Session = {},
    Loot    = {},
    Map     = {},
    Minimap = {},
    Tooltip = {},
    UI      = {},
    UnitFrame = {},
    Opener = {}
}
Addon.Events = Events

Events.History.Reset    = "ARTFULDODGER_RESET_HISTORY"
Events.Session.Reset    = "ARTFULDODGER_RESET_SESSION"

Events.Loot.PickPocket  = "ARTFULDODGER_LOOT_PICKPOCKET"
Events.Loot.Junkbox     = "ARTFULDODGER_LOOT_JUNKBOX"

Events.Map.Toggle       = "ARTFULDODGER_MAP_TOGGLE"
Events.Minimap.Toggle   = "ARTFULDODGER_MINIMAP_TOGGLE"
Events.Tooltip.Toggle   = "ARTFULDODGER_TOOLTIP_TOGGLE"
Events.UI.Toggle        = "ARTFULDODGER_UI_TOGGLE"

Events.UnitFrame.Toggle = "ARTFULDODGER_UNITFRAME_TOGGLE"
Events.UnitFrame.Reset  = "ARTFULDODGER_UNITFRAME_RESET"

Events.Opener.Toggle    = "ARTFULDODGER_OPENER_TOGGLE"
Events.Opener.BoxUpdate = "ARTFULDODGER_OPENER_BOXUPDATE"
Events.Opener.PosUpdate = "ARTFULDODGER_OPENER_POSUPDATE"