if CLIENT then return end

if not ZC_MapRoute then
    include("autorun/sh_zc_map_route.lua")
end

local MapRoute = ZC_MapRoute or {}

local function CanonicalMapName(name)
    if MapRoute.GetCanonicalMap then return MapRoute.GetCanonicalMap(name) end
    return isstring(name) and string.lower(name) or ""
end

local function IsCoopRoundActive()
    if not CurrentRound then return false end
    local round = CurrentRound()
    return istable(round) and round.name == "coop"
end

local function getLandmark(ent)
    if not IsValid(ent) then return "" end
    return ent.landmark or ent.LandmarkName or ent:GetInternalVariable("landmark") or ""
end

local function disableTrigger(ent, reason)
    if not IsValid(ent) or ent:GetClass() ~= "trigger_changelevel" then return end

    if ent.SetNotSolid then ent:SetNotSolid(true) end
    if ent.SetSolid then ent:SetSolid(SOLID_NONE) end
    if ent.SetTrigger then ent:SetTrigger(false) end
    ent.StartTouch = function(self, toucher) end
    ent.Touch = function(self, toucher) end
end

hook.Add("InitPostEntity", "ZC_DisableChangelevelTriggers_Init", function()
    if not IsCoopRoundActive() then return end

    for _, ent in ipairs(ents.FindByClass("trigger_changelevel")) do
        disableTrigger(ent, "InitPostEntity")
    end
end)

hook.Add("OnEntityCreated", "ZC_DisableChangelevelTriggers_Create", function(ent)
    if not IsValid(ent) or ent:GetClass() ~= "trigger_changelevel" then return end

    timer.Simple(0, function()
        if not IsValid(ent) then return end
        if not IsCoopRoundActive() then return end
        disableTrigger(ent, "OnEntityCreated")
    end)
end)