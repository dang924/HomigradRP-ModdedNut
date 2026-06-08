AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local function refillModeValues(wep)
    if not istable(wep.modeValuesdef) then return false end

    local changed = false
    wep.modeValues = wep.modeValues or {}

    for i, def in pairs(wep.modeValuesdef) do
        if isnumber(i) and istable(def) and isnumber(def[1]) then
            wep.modeValues[i] = def[1]
            changed = true
        end
    end

    if changed and wep.SetNetVar then
        wep:SetNetVar("modeValues", wep.modeValues)
    end

    return changed
end

local function refillAmmoPools(ply, wep)
    local changed = false

    local function applyChannel(channel, getClip, setClip)
        if not istable(channel) then return end

        local clipSize = tonumber(channel.ClipSize) or -1
        local currentClip = getClip and getClip(wep) or -1
        if clipSize > 0 and isnumber(currentClip) and currentClip >= 0 and setClip then
            if currentClip < clipSize then
                setClip(wep, clipSize)
                changed = true
            end
        end

        local ammoType = channel.Ammo
        if not isstring(ammoType) or ammoType == "" or ammoType == "none" then return end

        local giveAmount = tonumber(channel.DefaultClip) or clipSize
        giveAmount = math.max(math.floor(giveAmount or 0), 1)
        ply:GiveAmmo(giveAmount, ammoType, true)
        changed = true
    end

    applyChannel(wep.Primary, wep.Clip1, wep.SetClip1)
    applyChannel(wep.Secondary, wep.Clip2, wep.SetClip2)

    return changed
end

local function refillSpecialWeaponState(wep)
    local changed = false

    if wep.GetSharedUsesMax and wep.SetSharedUses then
        wep:SetSharedUses(wep:GetSharedUsesMax())
        if wep.SetNetVar and istable(wep.modeValues) then
            wep:SetNetVar("modeValues", wep.modeValues)
        end
        changed = true
    end

    return changed
end

function ENT:Initialize()
    local mdl = self.Model or self:GetModel() or "models/Items/item_item_crate_dynamic.mdl"
    self:SetModel(mdl)

    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    self:SetCollisionGroup(COLLISION_GROUP_NONE)

    self:SetUsesMax(math.max(math.floor(tonumber(self.UsesMax) or 20), 1))
    self:SetUsesLeft(math.max(math.floor(tonumber(self.UsesLeft) or self:GetUsesMax()), 0))
    self:SetCrateKind(self.CrateKind or "small")
    self:SetNextUseTime(0)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetMass(30)
        phys:EnableGravity(true)
        phys:EnableMotion(true)
        phys:Wake()
    else
        -- Some models do not expose valid VPhysics; keep an interactable bbox fallback.
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_BBOX)
        self:SetCollisionBounds(self:OBBMins(), self:OBBMaxs())
    end
end

local function isMedicalItem(wep)
    if not IsValid(wep) then return false end
    local cat = wep.Category or ""
    if string.find(cat, "Medicine", 1, true) or string.find(cat, "Meds", 1, true) then
        return true
    end
    if wep.ScrappersSlot == "Medicine" then return true end
    if wep.MedClass then return true end
    return false
end

function ENT:RefillHeldItem(ply)
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return false, "No held item" end

    if not isMedicalItem(wep) then
        return false, "Crate only refills medical items"
    end

    local changed = false
    changed = refillSpecialWeaponState(wep) or changed
    changed = refillModeValues(wep) or changed
    changed = refillAmmoPools(ply, wep) or changed

    if not changed then
        return false, "Held item cannot be refilled"
    end

    return true, "Refilled"
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if self:GetUsesLeft() <= 0 then return end

    local curTime = CurTime()
    if self:GetNextUseTime() > curTime then
        local waitFor = math.max(self:GetNextUseTime() - curTime, 0)
        activator:ChatPrint(string.format("Crate busy: %.1fs", waitFor))
        return
    end

    local ok, msg = self:RefillHeldItem(activator)
    if not ok then
        activator:ChatPrint(msg)
        return
    end

    self:SetUsesLeft(self:GetUsesLeft() - 1)
    self:SetNextUseTime(curTime + 1.5)
    self:EmitSound("snd_jack_hmcd_ammobox.wav", 70, math.random(96, 104), 1, CHAN_ITEM)

    if self:GetUsesLeft() <= 0 then
        self:Remove()
    end
end
