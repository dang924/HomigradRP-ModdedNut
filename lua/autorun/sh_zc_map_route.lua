if SERVER then AddCSLuaFile() end

ZC_MapRoute = ZC_MapRoute or {}

local MapRoute = ZC_MapRoute

local function normalizeMapName(name)
    if not isstring(name) or name == "" then return "" end
    return string.lower(string.Trim(name))
end

local function isTownCanonical(name)
    if not isstring(name) or name == "" then return false end
    return string.match(name, "^d1_town_") ~= nil or string.match(name, "^d2_town_") ~= nil
end

local ACTUAL_CAMPAIGN_SEQUENCE = {
    "d1_trainstation_01",
    "d1_trainstation_02",
    "d1_trainstation_03",
    "d1_trainstation_04",
    "d1_trainstation_05",
    "d1_trainstation_06",
    "d1_canals_01_d",
    "d1_canals_01a",
    "d1_canals_02",
    "d1_canals_03",
    "d1_canals_05",
    "d1_canals_06",
    "d1_canals_07",
    "d1_canals_08",
    "d1_canals_09",
    "d1_canals_10",
    "d1_canals_11",
    "d1_canals_12",
    "d1_canals_13_d",
    "d1_town_01",
    "d1_town_01a",
    "d1_town_02",
    "d1_town_03",
    "d1_town_02a_d",
    "d1_town_04",
    "d1_town_05",
    "d2_coast_01",
    "d2_coast_03",
    "d2_coast_04_d",
    "d2_coast_05",
    "d2_coast_07",
    "d2_coast_08",
    "d2_coast_09",
    "d2_coast_10",
    "d2_coast_11",
    "d2_coast_12",
    "d2_prison_01_d",
    "d2_prison_02",
    "d2_prison_03",
    "d2_prison_04",
    "d2_prison_05",
    "d2_prison_06",
    "d2_prison_07",
    "d2_prison_08_d",
    "d3_c17_01",
    "d3_c17_02_d",
    "d3_c17_03",
    "d3_c17_04",
    "d3_c17_05",
    "d3_c17_06a",
    "d3_c17_06b_d",
    "d3_c17_07_d",
    "d3_c17_09",
    "d3_c17_10a_d",
    "d3_c17_10b_d",
    "d3_c17_11",
    "d3_c17_12_d",
    "d3_c17_12b_d",
    "d3_c17_13_d",
    "d3_citadel_01",
    "d3_citadel_02",
    "d3_citadel_03",
    "d3_citadel_04",
    "d3_citadel_05",
    "d3_breen_01",
}

local CANONICAL_BY_ACTUAL = {
    d1_canals_01_d = "d1_canals_01",
    d1_canals_13_d = "d1_canals_13",
    d1_town_02a_d = "d1_town_02a",
    d2_coast_04_d = "d2_coast_04",
    d2_prison_01_d = "d2_prison_01",
    d2_prison_08_d = "d2_prison_08",
    d3_c17_02_d = "d3_c17_02",
    d3_c17_06b_d = "d3_c17_06b",
    d3_c17_07_d = "d3_c17_07",
    d3_c17_10a_d = "d3_c17_10a",
    d3_c17_10b_d = "d3_c17_10b",
    d3_c17_12_d = "d3_c17_12",
    d3_c17_12b_d = "d3_c17_12b",
    d3_c17_13_d = "d3_c17_13",
}

local NEXT_BY_ACTUAL = {}
local ACTUAL_BY_CANONICAL = {}

for index, actualName in ipairs(ACTUAL_CAMPAIGN_SEQUENCE) do
    local actual = normalizeMapName(actualName)
    local canonical = CANONICAL_BY_ACTUAL[actual] or actual

    ACTUAL_CAMPAIGN_SEQUENCE[index] = actual
    CANONICAL_BY_ACTUAL[actual] = canonical
    ACTUAL_BY_CANONICAL[canonical] = actual

    local nextActual = ACTUAL_CAMPAIGN_SEQUENCE[index + 1]
    if nextActual then
        NEXT_BY_ACTUAL[actual] = normalizeMapName(nextActual)
    end
end

-- Custom map name overrides (add your renamed maps here)
-- (The built-in ACTUAL_CAMPAIGN_SEQUENCE already handles _d suffixed maps.)

function MapRoute.NormalizeMapName(name)
    return normalizeMapName(name)
end

function MapRoute.GetCanonicalMap(name)
    local normalized = normalizeMapName(name)
    if normalized == "" then return "" end
    return CANONICAL_BY_ACTUAL[normalized] or normalized
end

function MapRoute.GetActualMap(name)
    local canonical = MapRoute.GetCanonicalMap(name)
    if canonical == "" then return "" end
    return ACTUAL_BY_CANONICAL[canonical] or canonical
end

function MapRoute.GetExpectedNextMap(currentMap)
    local currentActual = normalizeMapName(currentMap)
    if currentActual == "" then return "" end
    if NEXT_BY_ACTUAL[currentActual] == nil then
        local canonical = CANONICAL_BY_ACTUAL[currentActual] or currentActual
        currentActual = ACTUAL_BY_CANONICAL[canonical] or currentActual
    end
    return NEXT_BY_ACTUAL[currentActual] or ""
end

function MapRoute.ResolveNextMap(currentMap, fallbackTarget)
    local currentCanonical = MapRoute.GetCanonicalMap(currentMap)
    local fallbackCanonical = MapRoute.GetCanonicalMap(fallbackTarget)

    if isTownCanonical(currentCanonical) and fallbackCanonical ~= "" then
        return MapRoute.GetActualMap(fallbackCanonical)
    end

    local expected = MapRoute.GetExpectedNextMap(currentMap)
    if expected == "" then return "" end
    return expected
end

function MapRoute.TargetMatchesExpected(currentMap, candidateTarget)
    local expected = MapRoute.GetExpectedNextMap(currentMap)
    if expected == "" then return false end
    return MapRoute.GetCanonicalMap(expected) == MapRoute.GetCanonicalMap(candidateTarget)
end