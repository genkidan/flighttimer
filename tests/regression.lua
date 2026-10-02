-- Run from the addon directory with Lua 5.3 or Fengari.
local clock, taxi, locale = 0, false, "frFR"
local timers, frames = {}, {}
local function widget()
    local w = { scripts = {}, shown = true }
    setmetatable(w, { __index = function(_, key)
        if key == "CreateTexture" or key == "CreateFontString" then return widget end
        if key == "SetScript" then return function(self, event, fn) self.scripts[event] = fn end end
        if key == "SetText" then return function(self, text) self.text = text end end
        if key == "Hide" then return function(self) self.shown = false end end
        if key == "Show" then return function(self) self.shown = true end end
        if key == "IsShown" then return function(self) return self.shown end end
        if key == "GetStringHeight" then return function() return 14 end end
        return function() end
    end })
    return w
end
CreateFrame = function() local f = widget(); frames[#frames + 1] = f; return f end
UIParent, GameTooltip = widget(), widget()
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
GetLocale = function() return locale end
GetTime = function() return clock end
time = function() return 1000 + clock end
date = function() return "12:00:00" end
GetZoneText = function() return "Zone" end
UnitOnTaxi = function() return taxi end
UnitFactionGroup = function() return "Horde" end
PlaySound = function() end
SlashCmdList = {}
local takeTaxiHook
TakeTaxiNode = function() end
hooksecurefunc = function(_, fn) takeTaxiHook = fn end
local nodes = { { name = "Origin", x = 0.12 }, { name = "Middle", x = 0.22 }, { name = "Final", x = 0.32 } }
NumTaxiNodes = function() return #nodes end
TaxiNodeName = function(i) return nodes[i].name end
TaxiNodeGetType = function(i) return i == 1 and "CURRENT" or "REACHABLE" end
TaxiNodePosition = function(i) return nodes[i].x, 0.5 end
GetNumRoutes = function() return 2 end
TaxiGetDestX = function(_, i) return nodes[i + 1].x end
TaxiGetDestY = function() return 0.5 end
C_Timer = { After = function(delay, fn) timers[#timers + 1] = { at = clock + delay, fn = fn } end }
local function advance(seconds)
    clock = clock + seconds
    local pending = timers; timers = {}
    for _, t in ipairs(pending) do
        if t.at <= clock then t.fn() else timers[#timers + 1] = t end
    end
end
local FT = {}
for _, file in ipairs({ "Localization.lua", "FlightData.lua", "Database.lua", "UI.lua", "Core.lua" }) do
    assert(loadfile(file))("FlightTimer", FT)
end
local events = frames[1]
local function event(name, ...) events.scripts.OnEvent(events, name, ...) end
event("ADDON_LOADED", "FlightTimer")

-- Both sound interactions must run without a global Print helper.
assert(Print == nil)
FT.soundButton.scripts.OnClick(FT.soundButton, "LeftButton")
assert(FT.db.profile.soundEnabled == false)
FT.soundMenu.buttons[2].scripts.OnClick(FT.soundMenu.buttons[2])
assert(FT.db.profile.selectedSound == "ready_check")

-- Bundled timings outrank legacy measurements and remain unchanged.
FT.db.routes[FT:RouteKey("A", "B")] = { average = 999 }
assert(FT:GetRouteEstimate("A", "B", "31660270", "40795725") == 199)
assert(not FT:RecordForeverNewRoute("A", "B", 123, nil, "31660270", "40795725"))
assert(FT:RecordForeverNewRoute("N", "M", 20, nil, "new1", "new2"))
assert(FT:RecordForeverNewRoute("N", "M", 40, nil, "new1", "new2"))
assert(FT:GetRouteEstimate("N", "M") == 30)
assert(not FT:RecordForeverNewRoute("Unknown", "Destination", 40))

-- Reset also removes mirrors without hashes and preserves legacy Classic data.
local key = FT:RouteKey("Old", "New")
FT.db.forever.newRoutes[key] = { average = 30 }
FT.db.routes[key] = FT.db.forever.newRoutes[key]
SlashCmdList.FLIGHTTIMER("foreverreset")
assert(FT.db.routes[key] == nil and FT:GetForeverNewRouteCount() == 0)
assert(FT.db.routes[FT:RouteKey("A", "B")])

-- Demo survives automatic ground checks and cannot replace a real flight.
SlashCmdList.FLIGHTTIMER("test")
local demo = FT.activeFlight
advance(3); events.scripts.OnUpdate(events, 3)
event("PLAYER_CONTROL_GAINED"); advance(1)
event("PLAYER_ENTERING_WORLD")
assert(FT.activeFlight == demo)
SlashCmdList.FLIGHTTIMER("test"); assert(FT.activeFlight == demo)
advance(75)
assert(FT.activeFlight == nil and FT:GetForeverNewRouteCount() == 0)
assert(FT.arrivalText.text == FT.L.TEST_DONE)

-- Reload resumes elapsed time; interrupted/offline arrivals are not learned.
taxi = true
FT.db.activeFlight = { from = "N", to = "M", fromHash = "new1", toHash = "new2",
    startEpoch = time() - 20, estimate = 40, learned = true }
event("PLAYER_ENTERING_WORLD")
local flight = FT.activeFlight
assert(clock - flight.startTime == 20)
SlashCmdList.FLIGHTTIMER("test"); assert(FT.activeFlight == flight)
SlashCmdList.FLIGHTTIMER("show"); assert(FT.routeText.text:find("N"))
taxi = false; events.scripts.OnUpdate(events, 1)
assert(FT:GetRouteEstimate("N", "M") == 20)
assert(FT.arrivalText.text == FT.L.ROUTE_SAVED and FT.db.activeFlight == nil)
FT.db.activeFlight = { startEpoch = time() - 500 }
event("PLAYER_ENTERING_WORLD"); assert(FT.activeFlight == nil)

-- Early landing never records a predicted stop.
FT.activeFlight = { from = "N", to = "Wrong", fromHash = "new1", toHash = "wrong",
    startTime = clock - 20, earlyLandingRequested = true, earlyLandingTarget = "Wrong" }
events.scripts.OnUpdate(events, 1)
assert(FT:GetRoute("N", "Wrong") == nil)
assert(FT.arrivalText.text == FT.L.EARLY_NOT_SAVED)

-- Incomplete route timelines discard passed stops instead of guessing.
taxi = true
TaxiRequestEarlyLanding = function() end
FT.activeFlight = { from = "N", to = "End", startTime = clock - 50,
    routeCount = 3, routeStops = { { name = "Passed" }, { name = "Unknown" }, { name = "End" } },
    routeTimeline = { { index = 1, cumulative = 20 } } }
events.scripts.OnUpdate(events, 1)
assert(FT.activeFlight.nextStop == nil and not FT.activeFlight.isDirect)
FT:RequestEarlyLanding()
assert(FT.activeFlight.estimate == nil and FT.activeFlight.to == FT.L.NEXT_STOP_UNKNOWN)
FT.activeFlight = nil; taxi = false

-- Saved idle visibility and complete history reset.
FT.frame = nil; FT.db.profile.alwaysShow = true; FT:CreateUI()
assert(FT.frame:IsShown() and FT.timerText.text == FT.L.READY)
SlashCmdList.FLIGHTTIMER("historyreset")
assert(next(FT.db.routes) == nil and FT:GetForeverNewRouteCount() == 0)

-- A selected multi-hop new route starts without claiming it is direct.
event("TAXIMAP_OPENED"); takeTaxiHook(3)
taxi = true; event("PLAYER_CONTROL_LOST"); advance(1)
assert(FT.activeFlight.from == "Origin" and FT.activeFlight.to == "Final")
assert(not FT.activeFlight.isDirect and FT.activeFlight.nextStop == nil)
assert(FT.db.activeFlight == FT.activeFlight)
advance(20); taxi = false; event("PLAYER_CONTROL_GAINED"); advance(1)
assert(FT:GetRoute("Origin", "Final").average == 21)

-- Known first hop survives a missing later hop, then becomes unknown.
FT:RecordForeverNewRoute("Origin", "Middle", 10, nil, FT:GetNodeHash(0.12), FT:GetNodeHash(0.22))
FT.db.routes[FT:RouteKey("Origin", "Final")] = nil
event("TAXIMAP_OPENED"); takeTaxiHook(3)
taxi = true; event("PLAYER_CONTROL_LOST"); advance(1)
assert(#FT.activeFlight.routeTimeline == 1)
assert(FT.activeFlight.nextStop == "Middle")
advance(12); events.scripts.OnUpdate(events, 1)
assert(FT.activeFlight.nextStop == nil)
FT:RequestEarlyLanding()
taxi = false; event("PLAYER_CONTROL_GAINED"); advance(1)
assert(FT:GetRoute("Origin", "Final") == nil)

-- All additional messages exist in English too.
local french = FT.L
locale = "enUS"; assert(loadfile("Localization.lua"))("FlightTimer", FT)
for k in pairs(french) do assert(type(FT.L[k]) == "string", k) end
print("PASS: sound, Classic priority, learning, resets, demo, reload, early landing, idle UI, translations")
