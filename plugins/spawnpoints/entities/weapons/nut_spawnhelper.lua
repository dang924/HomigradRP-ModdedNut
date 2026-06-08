AddCSLuaFile()

if (CLIENT) then
	SWEP.PrintName = "Spawn Point Helper"
	SWEP.Slot = 0
	SWEP.SlotPos = 1
end

SWEP.HoldType = "pistol"

SWEP.Category = "Nutscript"
SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.ViewModel = "models/weapons/v_pistol.mdl"
SWEP.WorldModel = "models/weapons/w_pistol.mdl"

SWEP.Primary.Delay        = 0.4
SWEP.Primary.Recoil       = 0
SWEP.Primary.Damage       = 0
SWEP.Primary.NumShots     = 0
SWEP.Primary.Cone         = 0
SWEP.Primary.ClipSize     = -1
SWEP.Primary.DefaultClip  = -1
SWEP.Primary.Automatic    = false
SWEP.Primary.Ammo         = "none"

SWEP.Secondary.Delay      = 0.4
SWEP.Secondary.Recoil     = 0
SWEP.Secondary.Damage     = 0
SWEP.Secondary.NumShots   = 0
SWEP.Secondary.Cone       = 0
SWEP.Secondary.ClipSize   = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic  = false
SWEP.Secondary.Ammo       = "none"

function SWEP:Initialize()
	self:SetWeaponHoldType("pistol")
end

function SWEP:Deploy()
	return true
end

function SWEP:Holster()
	return true
end

function SWEP:Think() end
function SWEP:OnRemove() end

-- -------------------------------------------------------------------------
-- SERVER
-- -------------------------------------------------------------------------
if (SERVER) then
	function SWEP:PrimaryAttack()
		local owner = self:GetOwner()
		if (not IsValid(owner) or not owner:IsAdmin()) then return end

		local trace = owner:GetEyeTrace()
		if (not trace.Hit) then return end

		local pos = trace.HitPos + Vector(0, 0, 10)
		local ang = owner:EyeAngles()
		ang.p = 0
		ang.r = 0

		local count = nut.spawnpoints.add(pos, ang)
		owner:notify("Spawn point added. Total: " .. count)
	end

	function SWEP:SecondaryAttack()
		local owner = self:GetOwner()
		if (not IsValid(owner) or not owner:IsAdmin()) then return end

		local removed, count = nut.spawnpoints.removeNearest(owner:GetPos(), 150)

		if (removed) then
			owner:notify("Nearest spawn point removed. Total: " .. count)
		else
			owner:notify("No spawn point within 150 units.")
		end
	end

	function SWEP:Reload()
		local owner = self:GetOwner()
		if (not IsValid(owner) or not owner:IsAdmin()) then return end

		nut.spawnpoints.clearAll()
		owner:notify("All spawn points cleared.")
	end
end

-- -------------------------------------------------------------------------
-- CLIENT
-- -------------------------------------------------------------------------
if (CLIENT) then
	local cachedPoints = {}
	local nextRefresh = 0

	local function fetchPoints()
		if (CurTime() > nextRefresh) then
			net.Start("nut_spawnpoints_fetch")
			net.SendToServer()
			nextRefresh = CurTime() + 2
		end
	end

	net.Receive("nut_spawnpoints_data", function()
		local count = net.ReadUInt(16)
		cachedPoints = {}
		for i = 1, count do
			cachedPoints[i] = net.ReadVector()
		end
	end)

	function SWEP:DrawHUD()
		fetchPoints()

		local w, h = ScrW(), ScrH()
		local cy = h * 0.75
		local _, ty

		_, ty = draw.SimpleText("Left Click: Place spawn point", "nutMediumFont", w / 2, cy, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cy = cy + ty
		_, ty = draw.SimpleText("Right Click: Remove nearest spawn (150u)", "nutMediumFont", w / 2, cy, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cy = cy + ty
		draw.SimpleText("Reload: Clear ALL spawn points", "nutMediumFont", w / 2, cy, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		-- crosshair
		local trace = LocalPlayer():GetEyeTraceNoCursor()
		local aimPos = trace.HitPos:ToScreen()
		if (aimPos and aimPos.visible) then
			surface.SetDrawColor(50, 255, 80, 220)
			surface.DrawLine(aimPos.x, aimPos.y - 10, aimPos.x, aimPos.y + 10)
			surface.DrawLine(aimPos.x - 10, aimPos.y, aimPos.x + 10, aimPos.y)
		end
	end

	hook.Add("PostDrawOpaqueRenderables", "nut_spawnhelper_draw", function()
		local ply = LocalPlayer()
		local wep = ply:GetActiveWeapon()
		if (not IsValid(wep) or wep:GetClass() ~= "nut_spawnhelper") then return end

		for _, pos in ipairs(cachedPoints) do
			render.DrawSphere(pos, 8, 8, 8, Color(50, 255, 80, 200))

			local top = pos + Vector(0, 0, 32)
			render.DrawLine(pos, top, Color(50, 255, 80, 255), true)
		end
	end)
end
