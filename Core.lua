local addonName, FT = ...
FT = _G.FlightTimer
local L = FT.L

local eventFrame = CreateFrame("Frame")
local taxiSnapshot = nil
local pendingTaxi = nil

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffc44dFlightTimer|r: " .. tostring(msg))
end

local function UnitIsOnTaxi()
    if UnitOnTaxi then
        return UnitOnTaxi("player")
    end
    return false
end

local function CaptureTaxiMap()
    if not NumTaxiNodes or not TaxiNodeName or not TaxiNodeGetType then return end
    local count = NumTaxiNodes()
    if not count or count <= 0 then return end

    local currentIndex, currentName
    local nodes = {}

    for i = 1, count do
        local nodeType = TaxiNodeGetType(i)
        local name = TaxiNodeName(i)
        local x, y
        if TaxiNodePosition then x, y = TaxiNodePosition(i) end
        nodes[i] = { name = name, nodeType = nodeType, x = x, y = y, hash = FT:GetNodeHash(x) }
        if nodeType == "CURRENT" then
            currentIndex = i
            currentName = name
        end
    end

    taxiSnapshot = {
        currentIndex = currentIndex,
        currentName = currentName,
        nodes = nodes,
        capturedAt = GetTime(),
    }
end

local function GetApproxDistance(src, dst)
    if not src or not dst or not src.x or not src.y or not dst.x or not dst.y then return nil end
    local dx, dy = dst.x - src.x, dst.y - src.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d <= 0 or d > 2 then return nil end
    return d
end

local function FindNodeByPosition(x, y)
    if not taxiSnapshot or not taxiSnapshot.nodes or not x or not y then return nil end

    local bestNode, bestDistance
    for _, node in ipairs(taxiSnapshot.nodes) do
        if node.x and node.y and node.name then
            local dx, dy = node.x - x, node.y - y
            local d = (dx * dx) + (dy * dy)
            if not bestDistance or d < bestDistance then
                bestDistance = d
                bestNode = node
            end
        end
    end

    -- Taxi route coordinates and taxi-node coordinates should be nearly identical.
    -- Keep a small tolerance so we never report a completely unrelated flight point.
    if bestNode and bestDistance and bestDistance <= 0.0025 then
        return bestNode
    end
    return nil
end

local function CaptureRouteStops(destIndex)
    local stops = {}
    local routeCount = nil

    if GetNumRoutes then
        local ok, value = pcall(GetNumRoutes, destIndex)
        if ok and type(value) == "number" and value > 0 then
            routeCount = value
        end
    end

    if routeCount and TaxiGetDestX and TaxiGetDestY then
        for routeIndex = 1, routeCount do
            local okX, x = pcall(TaxiGetDestX, destIndex, routeIndex)
            local okY, y = pcall(TaxiGetDestY, destIndex, routeIndex)
            if okX and okY and x and y then
                local node = FindNodeByPosition(x, y)
                if node and (not stops[#stops] or stops[#stops].name ~= node.name) then
                    stops[#stops + 1] = {
                        name = node.name,
                        hash = node.hash,
                        x = node.x,
                        y = node.y,
                    }
                end
            end
        end
    end

    -- Ensure the selected destination is represented as the final stop.
    local destination = taxiSnapshot and taxiSnapshot.nodes and taxiSnapshot.nodes[destIndex]
    if destination and destination.name then
        if #stops == 0 or stops[#stops].name ~= destination.name then
            stops[#stops + 1] = {
                name = destination.name,
                hash = destination.hash,
                x = destination.x,
                y = destination.y,
            }
        end
    end

    return stops, routeCount
end

local function BuildPendingTaxi(destIndex)
    if not taxiSnapshot or not taxiSnapshot.nodes then return end
    local src = taxiSnapshot.nodes[taxiSnapshot.currentIndex or -1]
    local dst = taxiSnapshot.nodes[destIndex]
    if not src or not dst or not src.name or not dst.name then return end

    local distance = GetApproxDistance(src, dst)
    local routeStops, routeCount = CaptureRouteStops(destIndex)
    local nextStop = routeStops and routeStops[1] and routeStops[1].name or dst.name
    local isDirect = (routeCount and routeCount <= 1) or (nextStop == dst.name)

    pendingTaxi = {
        from = src.name,
        to = dst.name,
        distance = distance,
        fromHash = src.hash,
        toHash = dst.hash,
        selectedAt = GetTime(),
        routeStops = routeStops,
        routeCount = routeCount,
        nextStop = nextStop,
        isDirect = isDirect,
    }
end


local function BuildRouteTimeline(fromName, fromHash, routeStops, fullEstimate)
    if not routeStops or #routeStops == 0 then return nil end

    local timeline = {}
    local previousName = fromName
    local previousHash = fromHash
    local segmentCumulative = 0
    local lastCumulative = 0

    for index, stop in ipairs(routeStops) do
        if not stop or not stop.name then return nil end

        -- First choice: use the known duration from the ORIGINAL departure to
        -- this exact stop. This is much more reliable than adding individual
        -- hop durations, because WoW's bundled taxi data can contain slightly
        -- different timings depending on the complete selected route.
        local cumulative = select(1, FT:GetRouteEstimate(fromName, stop.name, fromHash, stop.hash))
        local segment = select(1, FT:GetRouteEstimate(previousName, stop.name, previousHash, stop.hash))

        if segment and segment > 0 then
            segmentCumulative = segmentCumulative + segment
        end

        -- If the origin->stop timing is missing or is not monotonic for this
        -- selected route, fall back to the sum of the known hop timings.
        if not cumulative or cumulative <= lastCumulative then
            cumulative = segmentCumulative > lastCumulative and segmentCumulative or nil
        end

        if not cumulative or cumulative <= lastCumulative then
            return nil
        end

        timeline[#timeline + 1] = {
            index = index,
            name = stop.name,
            hash = stop.hash,
            segment = segment,
            cumulative = cumulative,
        }

        lastCumulative = cumulative
        previousName = stop.name
        previousHash = stop.hash
    end

    -- The last stop must line up with the duration displayed by FlightTimer.
    -- Only apply a gentle scale when the route data is close enough to avoid
    -- turning a bad intermediate estimate into an even worse one.
    local finalCumulative = timeline[#timeline] and timeline[#timeline].cumulative
    if fullEstimate and fullEstimate > 0 and finalCumulative and finalCumulative > 0 then
        local scale = fullEstimate / finalCumulative
        if scale > 0.85 and scale < 1.15 then
            for _, entry in ipairs(timeline) do
                entry.cumulative = entry.cumulative * scale
                if entry.segment then entry.segment = entry.segment * scale end
            end
        end
    end

    return timeline
end

local function GetCurrentRouteStop(flight, elapsed)
    if not flight or not flight.routeStops or #flight.routeStops == 0 then return nil, nil end

    if flight.routeTimeline then
        elapsed = math.max(0, elapsed or 0)

        -- Advance slightly before the exact recorded timestamp. Taxi timings
        -- vary by a few seconds and TaxiRequestEarlyLanding applies to the
        -- next reachable hop, so keeping an already-reached stop on screen is
        -- more misleading than advancing a couple of seconds early.
        local PASS_MARGIN = 3

        for _, entry in ipairs(flight.routeTimeline) do
            if elapsed < math.max(0, entry.cumulative - PASS_MARGIN) then
                return flight.routeStops[entry.index], entry.index, entry.cumulative
            end
        end
        return flight.routeStops[#flight.routeStops], #flight.routeStops, flight.estimate
    end

    return flight.routeStops[1], 1, nil
end

local function RefreshNextStop(flight, elapsed, force)
    if not flight or flight.earlyLandingRequested then return end

    local stop, index = GetCurrentRouteStop(flight, elapsed)
    if not stop or not stop.name then return end

    local dynamicDirect = (index == #flight.routeStops)
    local changed = force or flight.currentStopIndex ~= index or flight.nextStop ~= stop.name or flight.isDirect ~= dynamicDirect

    flight.currentStopIndex = index
    flight.nextStop = stop.name
    flight.nextStopHash = stop.hash
    flight.isDirect = dynamicDirect

    if changed and FT.SetCancelState then
        FT:SetCancelState(false, stop.name, dynamicDirect, false)
    end
end

local function RecalculateForEarlyLanding(flight)
    if not flight then return end

    local elapsed = math.max(0, GetTime() - flight.startTime)
    local stop, stopIndex, stopCumulative = GetCurrentRouteStop(flight, elapsed)
    local stopName = (stop and stop.name) or flight.nextStop
    local stopHash = (stop and stop.hash) or flight.nextStopHash
    if not stopName then return end

    local estimate, learned, _, source = FT:GetRouteEstimate(flight.from, stopName, flight.fromHash, stopHash)
    -- Prefer the route timeline because it represents the exact path currently
    -- being flown, whereas a normal flight from the origin to this stop can
    -- occasionally use a different connection.
    if stopCumulative and stopCumulative > 0 then
        estimate = stopCumulative
        learned = true
        source = source or "database"
    end

    flight.originalTo = flight.originalTo or flight.to
    flight.originalEstimate = flight.originalEstimate or flight.estimate
    flight.to = stopName
    flight.toHash = stopHash or flight.toHash
    flight.estimate = estimate
    flight.learned = learned
    flight.source = source
    flight.earlyLandingTarget = stopName
    flight.earlyLandingTargetHash = stopHash
    flight.earlyLandingStopIndex = stopIndex

    if FT.SwitchToEarlyLandingUI then
        FT:SwitchToEarlyLandingUI(flight.from, stopName, estimate, learned, source, elapsed)
    end
end

function FT:RequestEarlyLanding()
    local flight = self.activeFlight
    if not flight or not UnitIsOnTaxi() then return end

    if flight.isDirect then
        if self.SetCancelState then
            self:SetCancelState(false, flight.to, true, false)
        end
        Print(L.DIRECT_FLIGHT)
        return
    end

    if not TaxiRequestEarlyLanding then
        Print(L.CANCEL_UNAVAILABLE)
        return
    end

    local ok = pcall(TaxiRequestEarlyLanding)
    if ok then
        flight.earlyLandingRequested = true
        RecalculateForEarlyLanding(flight)
        if self.SetCancelState then
            self:SetCancelState(true, flight.earlyLandingTarget or flight.nextStop, false, false)
        end
        Print(string.format(L.EARLY_LANDING_REQUESTED, flight.earlyLandingTarget or flight.nextStop or L.NEXT_STOP_UNKNOWN))
    else
        Print(L.CANCEL_UNAVAILABLE)
    end
end

local function StartFlight()
    if FT.activeFlight then return end

    local fromName = pendingTaxi and pendingTaxi.from
    local toName = pendingTaxi and pendingTaxi.to
    local distance = pendingTaxi and pendingTaxi.distance
    local fromHash = pendingTaxi and pendingTaxi.fromHash
    local toHash = pendingTaxi and pendingTaxi.toHash

    fromName = fromName or (taxiSnapshot and taxiSnapshot.currentName) or GetZoneText() or "?"
    toName = toName or "Destination"

    local estimate, learned, _, source = FT:GetRouteEstimate(fromName, toName, fromHash, toHash)

    local routeStops = pendingTaxi and pendingTaxi.routeStops or nil
    local routeTimeline = BuildRouteTimeline(fromName, fromHash, routeStops, estimate)

    FT.activeFlight = {
        from = fromName,
        to = toName,
        startTime = GetTime(),
        estimate = estimate,
        learned = learned,
        distance = distance,
        fromHash = fromHash,
        toHash = toHash,
        source = source,
        routeStops = routeStops,
        routeTimeline = routeTimeline,
        routeCount = pendingTaxi and pendingTaxi.routeCount or nil,
        nextStop = pendingTaxi and pendingTaxi.nextStop or toName,
        nextStopHash = routeStops and routeStops[1] and routeStops[1].hash or toHash,
        isDirect = pendingTaxi and pendingTaxi.isDirect or false,
        earlyLandingRequested = false,
    }

    RefreshNextStop(FT.activeFlight, 0, true)
    FT:ShowFlightUI(fromName, toName, estimate, learned, source, FT.activeFlight.nextStop, FT.activeFlight.isDirect)
    pendingTaxi = nil
end

local function EndFlight()
    local flight = FT.activeFlight
    if not flight then return end

    local duration = math.max(0, GetTime() - flight.startTime)
    if duration >= 3 then
        if flight.earlyLandingRequested and flight.earlyLandingTarget then
            -- Save the real shortened route under the intermediate stop, never under the original destination.
            FT:RecordForeverNewRoute(flight.from, flight.earlyLandingTarget, duration, nil, flight.fromHash, flight.earlyLandingTargetHash, flight.earlyLandingStopIndex)
        elseif not flight.earlyLandingRequested then
            local saved, why = FT:RecordForeverNewRoute(flight.from, flight.to, duration, flight.distance, flight.fromHash, flight.toHash, flight.routeCount)
            if saved then
                Print(string.format("NOUVEAU trajet Forever appris : %s -> %s = %.1fs", flight.from, flight.to, duration))
            elseif why == "existing" then
                Print(string.format("Trajet Classic connu : %s -> %s (aucun recalcul)", flight.from, flight.to))
            end
        end
    end

    FT.activeFlight = nil
    FT:FinishFlightUI(duration, flight.earlyLandingRequested)
end

local elapsedAccumulator = 0
eventFrame:SetScript("OnUpdate", function(_, elapsed)
    if not FT.activeFlight then return end
    elapsedAccumulator = elapsedAccumulator + elapsed
    if elapsedAccumulator < 0.05 then return end
    elapsedAccumulator = 0

    local f = FT.activeFlight
    local flown = GetTime() - f.startTime
    RefreshNextStop(f, flown, false)
    FT:UpdateFlightUI(flown, f.estimate, f.learned)

    if flown > 2 and not UnitIsOnTaxi() then
        EndFlight()
    end
end)

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded ~= addonName then return end
        FT:InitDB()
        FT:CreateUI()

        if hooksecurefunc and TakeTaxiNode then
            hooksecurefunc("TakeTaxiNode", function(index)
                BuildPendingTaxi(index)
            end)
        end

        Print("v2.0.0 Forever chargé - apprentissage uniquement des NOUVEAUX trajets. " .. L.HELP)

    elseif event == "TAXIMAP_OPENED" then
        CaptureTaxiMap()

    elseif event == "PLAYER_CONTROL_LOST" then
        C_Timer.After(0.05, function()
            if UnitIsOnTaxi() then StartFlight() end
        end)

    elseif event == "PLAYER_CONTROL_GAINED" then
        C_Timer.After(0.05, function()
            if FT.activeFlight and not UnitIsOnTaxi() then EndFlight() end
        end)

    elseif event == "PLAYER_ENTERING_WORLD" then
        if FT.activeFlight and not UnitIsOnTaxi() then EndFlight() end
    end
end)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("TAXIMAP_OPENED")
eventFrame:RegisterEvent("PLAYER_CONTROL_LOST")
eventFrame:RegisterEvent("PLAYER_CONTROL_GAINED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

SLASH_FLIGHTTIMER1 = "/flytimer"
SLASH_FLIGHTTIMER2 = "/ft"
SlashCmdList.FLIGHTTIMER = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    if msg == "lock" then
        FT:SetLocked(true)
        Print(L.LOCKED)
    elseif msg == "unlock" then
        FT:SetLocked(false)
        Print(L.UNLOCKED)
    elseif msg == "reset" then
        FT:ResetPosition()
        Print(L.RESET)
    elseif msg == "historyreset" then
        FT.db.routes = {}
        FT.db.calibration.secondsPerMapUnit = 235
        FT.db.calibration.samples = 0
        Print(L.HISTORY_RESET)
    elseif msg == "forever" or msg == "newroutes" then
        Print(string.format("%d nouveau(x) trajet(s) Forever appris.", FT:GetForeverNewRouteCount()))
        local store = FT.db.forever and FT.db.forever.newRoutes or {}
        for _, route in pairs(store) do
            Print(string.format("%s -> %s : %.1fs (%d mesure%s)", route.from, route.to, route.average or 0, route.samples or 0, (route.samples or 0) > 1 and "s" or ""))
        end
    elseif msg == "foreverreset" then
        FT.db.forever.newRoutes = {}
        -- Do not erase Classic data. Remove only mirrored Forever learned routes.
        for key, route in pairs(FT.db.routes or {}) do
            if route and route.fromHash and route.toHash and not FT:IsBundledRoute(route.fromHash, route.toHash) then
                FT.db.routes[key] = nil
            end
        end
        Print("Nouveaux trajets Forever effacés. Base Classic conservée.")
    elseif msg == "hide" then
        FT.db.profile.alwaysShow = false
        if FT.frame and not FT.activeFlight then FT.frame:Hide() end
    elseif msg == "show" then
        FT.db.profile.alwaysShow = true
        FT:CreateUI()
        FT.routeText:SetText("FlightTimer")
        FT.timerText:SetText("Prêt")
        FT.arrivalText:SetText("La barre s’activera automatiquement au prochain fly.")
        FT.bar:SetMinMaxValues(0, 1)
        FT.bar:SetValue(0)
        FT:SetCancelState(false, nil, true, false)
        FT.frame:Show()
    elseif msg == "test" then
        FT:CreateUI()
        FT.activeFlight = {
            from = L.TEST_FROM,
            to = L.TEST_TO,
            startTime = GetTime(),
            estimate = 78,
            learned = true,
            test = true,
            nextStop = L.TEST_STOP,
            isDirect = false,
        }
        FT:ShowFlightUI(L.TEST_FROM, L.TEST_TO, 78, true, "personal", L.TEST_STOP, false)
        C_Timer.After(78, function()
            if FT.activeFlight and FT.activeFlight.test then EndFlight() end
        end)
    else
        Print(L.HELP)
    end
end
