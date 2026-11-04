local _, ns = ...
local Addon = ns.Addon
if not Addon then return end

-- passthrough so the original L["..."] call style keeps working;
-- a real localization table can override it later.
local L = setmetatable({}, { __index = function(_, k) return k end })
ns.L = L

local Commands = {}
ns.Commands = Commands

function Commands:Init()
    SLASH_ARTFULDODGERLEDGER1 = "/" .. L["adl"]
    SlashCmdList["ARTFULDODGERLEDGER"] = function(input)
        Commands:ChatCommandListener(input or "")
    end
    SLASH_ADLPROBE1 = "/adlprobe"
    SLASH_ADLPROBE2 = "/adlp"
    SlashCmdList["ADLPROBE"] = function(input)
        Commands:ProbeListener(input)   -- no lowercasing: GUIDs keep their case
    end
end

function Commands:ChatCommandListener(input)
    input = (input or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

    if input == L["history"] then
        print(ns.Stats:GetPrettyPrintTotalLootedString())
        ns.UI:Show()
    elseif input == L["session"] then
        print(ns.Stats:GetPrettyPrintSessionLootedString())
    elseif input == L["toggle"] then
        Addon:SendMessage(ns.Events.UI.Toggle)
    elseif input == L["reset"] .. " " .. L["session"] then
        Addon:SendMessage(ns.Events.Session.Reset)
        print(Addon.prefix .. "session reset")
    elseif input == L["reset"] .. " " .. L["history"] then
        Addon:SendMessage(ns.Events.History.Reset)
        print(Addon.prefix .. "history cleared")
    elseif input == L["help"] or input == "" then
        print(L["Usage"])
        print("/" .. L["adl"] .. " " .. L["help"])
        print("/" .. L["adl"] .. " " .. L["history"] .. " - " .. L["List all recorded statistics"])
        print("/" .. L["adl"] .. " " .. L["session"] .. " - " .. L["List current play session statistics"])
        print("/" .. L["adl"] .. " " .. L["toggle"] .. " - " .. L["Open or close the Addon window"])
        print("/" .. L["adl"] .. " " .. L["reset"] .. " " .. L["session"] .. " - " .. L["Clear data from current play session"])
        print("/" .. L["adl"] .. " " .. L["reset"] .. " " .. L["history"] .. " - " .. L["Clear all data"])
    else
        print(Addon.prefix .. "unknown command: " .. input .. "   (/adl help)")
    end
end

--==============================================================
--  /adlprobe -- classify units one target click at a time.
--    /adlprobe            arm / disarm
--    /adlprobe np <tok>   one-shot probe of a nameplate token
--                         (works armed or not)
--    /adlprobe clear      wipe the box
--    /adlprobe close      hide the box
--  On each recorded unit, raw API values are dumped into a
--  text box (all pre-selected -> Ctrl+C). The [if] line is an
--  inductive guess from the values above it -- the data decides.
--==============================================================
function Commands:ProbeListener(input)
    input = (input or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local st = _G.__ADLprobe
    if not st then st = { on = false, box = nil, count = 0, frame = nil } end
    _G.__ADLprobe = st

    if input == "close" then
        if st.box then st.box:Hide() end
        return
    end
    if input == "clear" then
        if st.box then st.box:SetText("") end
        return
    end
    if input == "npall" then
        for i = 1, 20 do
            local token = "nameplate" .. i
            if type(UnitExists) == "function" and UnitExists(token) then
                Commands:Record(token)
            end
        end
        return
    end

    local token = input:match("^np%s+(%S+)$")
    if token then
        Commands:Record(token)
        return
    end

    if input == "on" then st.on = true
    elseif input == "off" then st.on = false
    else st.on = not st.on
    end

    if not st.frame then
        st.frame = CreateFrame("Frame")
        st.frame:SetScript("OnEvent", function()
            if st.on then Commands:Record("target") end
        end)
        st.frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    end
    print(Addon.prefix .. (st.on
        and "probe ARMED - click targets to record ( /adlprobe to disarm )"
        or "probe disarmed"))
end

function Commands:Record(token)
    local st = _G.__ADLprobe
    if not st then return end
    if not (type(UnitExists) == "function" and UnitExists(token)) then
        print("[ADL] " .. token .. " is not a live unit - nothing recorded")
        return
    end

    if not st.box then
        st.box = CreateFrame("EditBox", nil, UIParent)
        st.box:SetSize(520, 600)
        st.box:SetPoint("TOPLEFT", 40, 0)
        st.box:SetMultiLine(true)
        st.box:SetFontObject(ChatFontNormal)
        st.box:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    end

    local out = {}
    local function P(s) out[#out + 1] = s end
    local function cc(fn)
        local ok, value = pcall(fn)
        return ok and tostring(value) or "ERR"
    end
    local function F(label, fn)
        P(string.format("  %-13s = %s", label, cc(fn)))
    end

    local you = cc(function() return UnitGUID("player") end)
    -- (removed: UnitOwner, C_PetInfo.GetPetInfo - confirmed absent in this API)

    st.count = st.count + 1
    P("")
    P(string.format("#%d  %s  %s", st.count, date("%H:%M:%S"), token))
    F("name",       function() return UnitName(token) end)
    F("guid",       function() return UnitGUID(token) end)
    P(string.format("  %-13s = %s", "you", you))
    F("petToken",   function() return UnitIsUnit("pet", token) end)
    F("demon",      function() return UnitIsUnit("demon", token) end)
    F("totem",      function() return UnitIsUnit("totem", token) end)
    F("guardian",   function() return UnitIsUnit("guardian", token) end)
    local petGuid = cc(function() return UnitGUID("pet") end)
    P(string.format("  %-13s = %s", "petGuid", petGuid))
    F("playerCtl",  function() return UnitPlayerControlled(token) end)
    F("isControl",  function() return UnitIsControlling(token) end)
    F("canAttack",  function() return UnitCanAttack("player", token) end)
    F("reaction",   function() return UnitReaction("player", token) end)
    F("classify",   function() return UnitClassification(token) end)
    F("class",      function() return UnitClass(token) end)

    local mine = false
    for _, relationship in ipairs({ "pet", "demon", "totem", "guardian" }) do
        local ok, value = pcall(function() return UnitIsUnit(relationship, token) end)
        if ok and value then mine = true break end
    end
    local guid = cc(function() return UnitGUID(token) end)
    if petGuid and petGuid ~= "nil" and petGuid ~= "ERR" and guid == petGuid then mine = true end
    local isPlayer = cc(function() return UnitIsPlayer(token) end) == "true"
    if isPlayer then
        P("  [if] = PLAYER -> hide, no label, no db row")
    elseif mine then
        P("  [if] = MINE -> prelabel 'no pockets', no db row")
    else
        P("  [if] = NOT MINE (other players, their pets, wild) -> cast/db path")
    end

    local box = st.box
    box:Show()
    box:SetText(box:GetText() .. table.concat(out, "\n"))
    box:SetFocus()
    box:HighlightText()
end