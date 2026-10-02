-- Read-only audit of the bundled timings. Run from the addon directory.
_G.FlightTimer = {}
assert(loadfile("FlightData.lua"))("FlightTimer", _G.FlightTimer)
local function sortedKeys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end
local total, unique = 0, {}
for _, faction in ipairs({ "Alliance", "Horde" }) do
    local routes = FlightTimer.FlightData[faction]
    local nodes, graph = {}, {}
    local count, minimum, maximum, noReverse, invalid = 0, math.huge, 0, 0, 0
    for from, row in pairs(routes) do
        nodes[from] = true; graph[from] = graph[from] or {}
        for to, seconds in pairs(row) do
            nodes[to] = true; graph[to] = graph[to] or {}
            graph[from][to] = true; graph[to][from] = true
            count = count + 1
            minimum = math.min(minimum, seconds); maximum = math.max(maximum, seconds)
            if from == to or seconds <= 0 or seconds ~= math.floor(seconds) then invalid = invalid + 1 end
            if not routes[to] or not routes[to][from] then noReverse = noReverse + 1 end
        end
    end
    local visited, components = {}, {}
    for _, root in ipairs(sortedKeys(nodes)) do
        if not visited[root] then
            local queue, component = { root }, {}
            visited[root] = true
            local i = 1
            while i <= #queue do
                local node = queue[i]; i = i + 1
                component[#component + 1] = node
                for nextNode in pairs(graph[node]) do
                    if not visited[nextNode] then visited[nextNode] = true; queue[#queue + 1] = nextNode end
                end
            end
            table.sort(component); components[#components + 1] = component
        end
    end
    local possible, missing = 0, 0
    for _, component in ipairs(components) do
        possible = possible + #component * (#component - 1)
        for _, from in ipairs(component) do
            for _, to in ipairs(component) do
                if from ~= to and not (routes[from] and routes[from][to]) then missing = missing + 1 end
            end
        end
    end
    print(string.format("%s: nodes=%d, durations=%d, min=%ds, max=%ds, invalid=%d, missing_reverse=%d",
        faction, #sortedKeys(nodes), count, minimum, maximum, invalid, noReverse))
    print(string.format("  Connected components=%d; possible ordered pairs within components=%d; missing=%d; coverage=%.1f%%",
        #components, possible, missing, count / possible * 100))
    for i, component in ipairs(components) do
        print(string.format("  Component %d: %d nodes (%s)", i, #component, table.concat(component, ",")))
    end
    for node in pairs(nodes) do unique[node] = true end
    total = total + count
end
print(string.format("Total: %d directed durations, %d unique coordinate hashes (not stable node IDs).", total, #sortedKeys(unique)))
print("Coverage describes this table only. Connected components are not a Forever route manifest.")
