local addonName, FT = ...
FT = _G.FlightTimer
local L = FT.L

local eventFrame = CreateFrame("Frame")
local taxiSnapshot = nil
local pendingTaxi = nil

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffc44dFlightTimer|r: " .. tostring(msg))
end
function FT:Print(msg)
    Print(msg)
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
    pendingTaxi = nil
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
    if not src or not dst or not src.name or not dst.name then pendingTaxi = nil; return end

    local distance = GetApproxDistance(src, dst)
    local routeStops, routeCount = CaptureRouteStops(destIndex)
    local nextStop = routeStops and routeStops[1] and routeStops[1].name or dst.name
    local isDirect = routeCount and routeCount <= 1 or false

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

-- Personal measurements are specific to the client, faction, locale and path.
-- Both coordinates are retained; Classic's historical X hashes stay separate.
local function RouteContext(origin, stops, count)
    if not origin or not origin.x or not origin.y or not count or #stops ~= count then return nil end
    local build = GetBuildInfo and select(2, GetBuildInfo()) or "unknown"
    local parts = { tostring(build), UnitFactionGroup("player") or "unknown", GetLocale() }
    local function append(node)
        if not node or not node.x or not node.y then return false end
        parts[#parts + 1] = string.format("%.8f,%.8f", node.x, node.y)
        return true
    end
    append(origin)
    for _, stop in ipairs(stops) do
        if not append(stop) then return nil end
    end
    return table.concat(parts, ":")
end


local function BuildRouteTimeline(fromName, fromHash, routeStops, fullEstimate, origin)
    if not routeStops or #routeStops == 0 then return nil end

    local timeline = {}
    local previousName = fromName
    local previousHash = fromHash
    local segmentCumulative = 0
    local lastCumulative = 0
    local prefix = {}

    for index, stop in ipairs(routeStops) do
        if not stop or not stop.name then return nil end

        -- First choice: use the known duration from the ORIGINAL departure to
        -- this exact stop. This is much more reliable than adding individual
        -- hop durations, because WoW's bundled taxi data can contain slightly
        -- different timings depending on the complete selected route.
        prefix[#prefix + 1] = stop
        local context = RouteContext(origin, prefix, #prefix)
        local previous = index == 1 and origin or routeStops[index - 1]
        local segmentContext = RouteContext(previous, { stop }, 1)
        local cumulative = select(1, FT:GetRouteEstimate(fromName, stop.name, fromHash, stop.hash, context or "unidentified"))
        local segment = select(1, FT:GetRouteEstimate(previousName, stop.name, previousHash, stop.hash, segmentContext or "unidentified"))

        if segment and segment > 0 then
            segmentCumulative = segmentCumulative + segment
        end

        -- If the origin->stop timing is missing or is not monotonic for this
        -- selected route, fall back to the sum of the known hop timings.
        if not cumulative or cumulative <= lastCumulative then
            cumulative = segmentCumulative > lastCumulative and segmentCumulative or nil
        end

        if not cumulative or cumulative <= lastCumulative then
            break
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
        if #timeline == #routeStops and scale > 0.85 and scale < 1.15 then
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
        if #flight.routeTimeline == #flight.routeStops then
            return flight.routeStops[#flight.routeStops], #flight.routeStops, flight.estimate
        end
    end

    -- Without a complete timeline, the next reachable stop is unknown.
    return nil, nil
end

local function RefreshNextStop(flight, elapsed, force)
    if not flight or flight.earlyLandingRequested then return end

    local stop, index = GetCurrentRouteStop(flight, elapsed)
    if not stop or not stop.name then
        local changed = force or flight.nextStop ~= (flight.routeCount == 1 and flight.to or nil)
            or flight.currentStopIndex ~= nil or flight.isDirect ~= (flight.routeCount == 1)
        flight.nextStop = flight.routeCount == 1 and flight.to or nil
        flight.nextStopHash = nil
        flight.currentStopIndex = nil
        flight.isDirect = flight.routeCount == 1
        if changed and FT.SetCancelState then
            FT:SetCancelState(false, flight.nextStop, flight.isDirect, false)
        end
        return
    end

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
    local stopName = stop and stop.name
    local stopHash = stop and stop.hash
    if not stopName then
        flight.estimate = nil
        flight.to = L.NEXT_STOP_UNKNOWN
        FT:SwitchToEarlyLandingUI(flight.from, flight.to, nil, false, "learning", elapsed)
        return
    end

    local estimate, learned, _, source = FT:GetRouteEstimate(flight.from, stopName, flight.fromHash, stopHash, "unidentified")
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
    if not flight or flight.test or flight.earlyLandingRequested or not UnitIsOnTaxi() then return end
    RefreshNextStop(flight, GetTime() - flight.startTime, true)

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

    local ok, result = pcall(TaxiRequestEarlyLanding)
    if ok and result ~= false then
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
    if FT.activeFlight and not FT.activeFlight.test then return end
    if FT.activeFlight then FT.activeFlight = nil end
    if pendingTaxi and GetTime() - pendingTaxi.selectedAt > 30 then pendingTaxi = nil end

    local fromName = pendingTaxi and pendingTaxi.from
    local toName = pendingTaxi and pendingTaxi.to
    local distance = pendingTaxi and pendingTaxi.distance
    local fromHash = pendingTaxi and pendingTaxi.fromHash
    local toHash = pendingTaxi and pendingTaxi.toHash

    fromName = fromName or (taxiSnapshot and taxiSnapshot.currentName) or GetZoneText() or "?"
    toName = toName or "Destination"

    local routeStops = pendingTaxi and pendingTaxi.routeStops or nil
    local origin = taxiSnapshot and taxiSnapshot.nodes[taxiSnapshot.currentIndex or -1]
    local routeCount = pendingTaxi and pendingTaxi.routeCount
    local context = routeStops and RouteContext(origin, routeStops, routeCount)
    local estimate, learned, _, source = FT:GetRouteEstimate(fromName, toName, fromHash, toHash, context or "unidentified")
    local routeTimeline = BuildRouteTimeline(fromName, fromHash, routeStops, estimate, origin)

    FT.activeFlight = {
        from = fromName,
        to = toName,
        startTime = GetTime(),
        startEpoch = time(),
        estimate = estimate,
        learned = learned,
        distance = distance,
        fromHash = fromHash,
        toHash = toHash,
        source = source,
        context = context,
        identityVersion = 2,
        routeStops = routeStops,
        routeTimeline = routeTimeline,
        routeCount = pendingTaxi and pendingTaxi.routeCount or nil,
        nextStop = pendingTaxi and pendingTaxi.nextStop or toName,
        nextStopHash = routeStops and routeStops[1] and routeStops[1].hash or toHash,
        isDirect = pendingTaxi and pendingTaxi.isDirect or false,
        earlyLandingRequested = false,
    }
    FT.db.activeFlight = FT.activeFlight

    RefreshNextStop(FT.activeFlight, 0, true)
    FT:ShowFlightUI(fromName, toName, estimate, learned, source, FT.activeFlight.nextStop, FT.activeFlight.isDirect)
    pendingTaxi = nil
end

local function EndFlight()
    local flight = FT.activeFlight
    if not flight then return end

    local duration = math.max(0, GetTime() - flight.startTime)
    local status = flight.test and L.TEST_DONE or L.FLIGHT_DONE
    if duration >= 3 and not flight.test then
        if flight.earlyLandingRequested then
            -- The game has not confirmed which node received the player.
            -- Never associate this duration with a predicted intermediate stop.
            status = L.EARLY_NOT_SAVED
        elseif not flight.earlyLandingRequested then
            local saved, why
            if flight.context then
                saved, why = FT:RecordForeverNewRoute(flight.from, flight.to, duration, flight.distance, flight.fromHash, flight.toHash, flight.routeCount, flight.context, flight.routeStops)
            elseif FT:IsBundledRoute(flight.fromHash, flight.toHash) then
                why = "existing"
            end
            if saved then
                status = L.ROUTE_SAVED
                Print(string.format(L.NEW_ROUTE, flight.from, flight.to, duration))
            elseif why == "existing" then
                status = L.CLASSIC_DONE
                Print(string.format(L.CLASSIC_ROUTE, flight.from, flight.to))
            end
        end
    end

    FT.activeFlight = nil
    FT.db.activeFlight = nil
    FT:FinishFlightUI(duration, status)
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

    if not f.test and flown > 2 and not UnitIsOnTaxi() then
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

        Print(L.LOADED .. " " .. L.HELP)

    elseif event == "TAXIMAP_OPENED" then
        CaptureTaxiMap()

    elseif event == "PLAYER_CONTROL_LOST" then
        C_Timer.After(0.05, function()
            if UnitIsOnTaxi() then StartFlight() else pendingTaxi = nil end
        end)

    elseif event == "PLAYER_CONTROL_GAINED" then
        C_Timer.After(0.05, function()
            if FT.activeFlight and not FT.activeFlight.test and not UnitIsOnTaxi() then EndFlight() end
        end)

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not FT.activeFlight and FT.db and FT.db.activeFlight then
            local saved = FT.db.activeFlight
            if UnitIsOnTaxi() and saved.startEpoch then
                saved.startTime = GetTime() - math.max(0, time() - saved.startEpoch)
                FT.activeFlight = saved
                FT:ShowFlightUI(saved.from, saved.to, saved.estimate, saved.learned,
                    saved.source, saved.nextStop, saved.isDirect)
                if saved.earlyLandingRequested then
                    FT:SetCancelState(true, saved.earlyLandingTarget, false, false)
                end
            else
                FT.db.activeFlight = nil
            end
        end
        if FT.activeFlight and not FT.activeFlight.test and not UnitIsOnTaxi() then EndFlight() end
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
        FT:ResetHistory()
        Print(L.HISTORY_RESET)
    elseif msg == "forever" or msg == "newroutes" then
        Print(string.format(L.ROUTE_COUNT, FT:GetForeverNewRouteCount()))
        local store = FT.db.forever and FT.db.forever.newRoutes or {}
        for _, route in pairs(store) do
            Print(string.format(L.ROUTE_ENTRY, route.from, route.to, route.average or 0, route.samples or 0))
        end
    elseif msg == "foreverreset" then
        FT:ResetForeverRoutes()
        Print(L.FOREVER_RESET)
    elseif msg == "hide" then
        FT.db.profile.alwaysShow = false
        if FT.frame and not FT.activeFlight then FT.frame:Hide() end
    elseif msg == "show" then
        FT.db.profile.alwaysShow = true
        FT:CreateUI()
        if not FT.activeFlight then FT:ShowIdleUI() else FT.frame:Show() end
    elseif msg == "test" then
        if FT.activeFlight or UnitIsOnTaxi() then
            Print(L.TEST_BUSY)
            return
        end
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
        local testFlight = FT.activeFlight
        C_Timer.After(78, function()
            if FT.activeFlight == testFlight then EndFlight() end
        end)
    else
        Print(L.HELP)
    end
end
