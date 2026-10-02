local addonName, FT = ...
FT = _G.FlightTimer

FT.defaults = {
    profile = {
        locked = false,
        scale = 1,
        alpha = 1,
        x = 0,
        y = -210,
        point = "CENTER",
        relativePoint = "CENTER",
        alwaysShow = false,
        soundEnabled = true,
        selectedSound = "raid_warning",
    },
    routes = {},
    forever = {
        newRoutes = {},
    },
    calibration = {
        secondsPerMapUnit = 235,
        samples = 0,
    },
}

local function CopyDefaults(src, dst)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

function FT:InitDB()
    FlightTimerDB = CopyDefaults(self.defaults, FlightTimerDB or {})
    self.db = FlightTimerDB
end

function FT:RouteKey(fromName, toName)
    return tostring(fromName or "?") .. "\031" .. tostring(toName or "?")
end

function FT:GetRoute(fromName, toName)
    if not self.db then return nil end
    return self.db.routes[self:RouteKey(fromName, toName)]
end

function FT:GetRouteEstimate(fromName, toName, fromHash, toHash)
    -- Classic timings always take precedence, including over legacy measurements.
    local builtIn = self:GetBuiltInFlightTime(fromHash, toHash)
    if builtIn and builtIn > 0 then
        return builtIn, true, 0, "database"
    end

    local route = self:GetRoute(fromName, toName)
    if route and route.average and route.average > 0 then
        return route.average, true, route.samples or 1, "personal"
    end

    return nil, false, 0, "learning"
end

function FT:RecordRoute(fromName, toName, duration, distance)
    if not self.db or not fromName or not toName or not duration or duration < 3 then return end

    local key = self:RouteKey(fromName, toName)
    local route = self.db.routes[key] or {
        from = fromName,
        to = toName,
        samples = 0,
        average = 0,
        best = nil,
        worst = nil,
    }

    route.samples = (route.samples or 0) + 1
    route.average = (((route.average or 0) * (route.samples - 1)) + duration) / route.samples
    route.last = duration
    route.best = route.best and math.min(route.best, duration) or duration
    route.worst = route.worst and math.max(route.worst, duration) or duration
    route.updated = time()
    if distance and distance > 0 then route.distance = distance end
    self.db.routes[key] = route

    if distance and distance > 0 then
        local observed = duration / distance
        if observed > 10 and observed < 2000 then
            local c = self.db.calibration
            local n = c.samples or 0
            c.secondsPerMapUnit = (((c.secondsPerMapUnit or 235) * n) + observed) / (n + 1)
            c.samples = n + 1
        end
    end
end

function FT:IsBundledRoute(fromHash, toHash)
    local t = self:GetBuiltInFlightTime(fromHash, toHash)
    return t ~= nil and t > 0
end

-- Forever learning mode: ONLY records a route that does not exist in the
-- bundled Classic database. Existing Classic routes are never re-timed.
function FT:RecordForeverNewRoute(fromName, toName, duration, distance, fromHash, toHash, routeCount)
    if not self.db or not fromName or not toName or not duration or duration < 3 then return false, "invalid" end
    if not fromHash or not toHash then return false, "unidentified" end
    if self:IsBundledRoute(fromHash, toHash) then
        return false, "existing"
    end

    local key = self:RouteKey(fromName, toName)
    local store = self.db.forever and self.db.forever.newRoutes
    if not store then return false, "nodatabase" end
    local route = store[key] or {
        from = fromName, to = toName, fromHash = fromHash, toHash = toHash,
        samples = 0, average = 0, best = nil, worst = nil,
    }
    route.samples = (route.samples or 0) + 1
    route.average = (((route.average or 0) * (route.samples - 1)) + duration) / route.samples
    route.last = duration
    route.best = route.best and math.min(route.best, duration) or duration
    route.worst = route.worst and math.max(route.worst, duration) or duration
    route.updated = time()
    route.distance = distance or route.distance
    route.routeCount = routeCount or route.routeCount
    store[key] = route

    -- Mirror only NEW Forever routes into the normal route cache so the UI can
    -- immediately use the learned time on the next flight.
    self.db.routes[key] = route
    return true, "new"
end

function FT:ResetForeverRoutes()
    for key in pairs(self.db.forever.newRoutes) do
        self.db.routes[key] = nil
    end
    self.db.forever.newRoutes = {}
end

function FT:ResetHistory()
    self.db.routes = {}
    self.db.forever.newRoutes = {}
    self.db.calibration.secondsPerMapUnit = 235
    self.db.calibration.samples = 0
end

function FT:GetForeverNewRouteCount()
    local n = 0
    local store = self.db and self.db.forever and self.db.forever.newRoutes or {}
    for _ in pairs(store) do n = n + 1 end
    return n
end
