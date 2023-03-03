if select(3, UnitClass("player")) ~= 4 then
    return
end

local Addon = LibStub("AceAddon-3.0"):GetAddon("ArtfulDodger")
local Events = {
    History = {
        Reset = "ARTFULDODGER_RESET_HISTORY"
    },
    Session = {
        Reset = "ARTFULDODGER_RESET_SESSION"
    },
    Exclusions = {
        Reset = "ARTFULDODGER_RESET_EXCLUSIONS"
    },
    Loot    = {
        PickPocketAttempt   = "ARTFULDODGER_LOOT_PICKPOCKET_ATTEMPT",
        PickPocketComplete  = "ARTFULDODGER_LOOT_PICKPOCKET_COMPLETE",
        Junkbox             = "ARTFULDODGER_LOOT_JUNKBOX"
    },
    Map     = {
        Toggle = "ARTFULDODGER_MAP_TOGGLE"
    },
    Minimap = {
        Toggle = "ARTFULDODGER_MINIMAP_TOGGLE",
        IdleThreshold = "ARTFULDODGER_MINIMAP_IDLETHRESHOLD"
    },
    Tooltip = {
        Toggle = "ARTFULDODGER_TOOLTIP_TOGGLE"
    },
    UI      = {
        Toggle = "ARTFULDODGER_UI_TOGGLE"
    },
    UnitFrame = {
        Toggle = "ARTFULDODGER_UNITFRAME_TOGGLE"
    },
    Opener = {
        Toggle    = "ARTFULDODGER_OPENER_TOGGLE",
        BoxUpdate = "ARTFULDODGER_OPENER_BOXUPDATE",
        PosUpdate = "ARTFULDODGER_OPENER_POSUPDATE"
    }
}

Addon.Events = Events