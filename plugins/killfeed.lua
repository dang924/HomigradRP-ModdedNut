local PLUGIN = PLUGIN
PLUGIN.name = "Kill Feed"
PLUGIN.author = "Copilot"
PLUGIN.desc = "Global kill feed with headshot and airshot icons."

-- ============================================================================
-- SHARED
-- ============================================================================

local ICON_HEADSHOT = 1
local ICON_AIR      = 2
local ICON_NONE     = 0

-- ============================================================================
-- SERVER
-- ============================================================================
if (SERVER) then
	util.AddNetworkString("nut_killfeed_event")

	-- Store last damage hitgroup + airborne state per player
	hook.Add("EntityTakeDamage", "nutKillfeedTrack", function(ent, dmg)
		if (not ent:IsPlayer()) then return end

		local attacker = dmg:GetAttacker()
		if (not IsValid(attacker) or not attacker:IsPlayer()) then return end

		ent._nutLastHitGroup = dmg:GetDamageType() ~= 0 and ent._nutLastHitGroup or ent._nutLastHitGroup
		-- ScalePlayerDamage fires before EntityTakeDamage for the actual hitgroup,
		-- so we tag it there via the helper below
	end)

	hook.Add("ScalePlayerDamage", "nutKillfeedHitgroup", function(client, hitGroup, dmgInfo)
		client._nutLastHitGroup = hitGroup
		-- track whether attacker was airborne at moment of shot
		local attacker = dmgInfo:GetAttacker()
		if (IsValid(attacker) and attacker:IsPlayer()) then
			attacker._nutWasAirborne = not attacker:IsOnGround()
		end
	end)

	hook.Add("PlayerDeath", "nutKillfeedBroadcast", function(victim, inflictor, attacker)
		if (not IsValid(attacker) or not attacker:IsPlayer()) then return end
		if (attacker == victim) then return end

		local hitGroup = victim._nutLastHitGroup or HITGROUP_GENERIC
		local airborne = attacker._nutWasAirborne or false

		local icon = ICON_NONE
		if (hitGroup == HITGROUP_HEAD) then
			icon = ICON_HEADSHOT
		elseif (airborne) then
			icon = ICON_AIR
		end

		local weaponClass = ""
		local wep = attacker:GetActiveWeapon()
		if (IsValid(wep)) then
			weaponClass = wep:GetClass()
		end
		-- Strip common prefixes for readability  (arccw_m16a4 -> M16A4)
		weaponClass = weaponClass:gsub("^arccw_", ""):gsub("^weapon_", ""):gsub("_", " "):upper()

		local attackerName = attacker:Nick()
		local victimName   = victim:Nick()

		net.Start("nut_killfeed_event")
			net.WriteString(attackerName)
			net.WriteString(victimName)
			net.WriteString(weaponClass)
			net.WriteUInt(icon, 4)
		net.Broadcast()

		-- reset per-death state
		victim._nutLastHitGroup  = nil
		attacker._nutWasAirborne = nil
	end)

	return
end

-- ============================================================================
-- CLIENT
-- ============================================================================

local FEED_MAX       = 5
local FEED_LIFETIME  = 6
local FEED_FADETIME  = 1
local ENTRY_H        = 20
local ENTRY_PAD      = 3
local FEED_X_OFFSET  = 10   -- from right edge
local FEED_Y_OFFSET  = 80   -- from top

local ICON_HEADSHOT_CHAR = "☠"  -- rendered text fallback (unicode skull)
local ICON_AIR_CHAR      = "★"

local COLOR_KILLER  = Color(240, 100, 100)
local COLOR_VICTIM  = Color(100, 180, 255)
local COLOR_WEAPON  = Color(200, 200, 200)
local COLOR_ICON    = Color(255, 215, 0)
local COLOR_BG      = Color(0, 0, 0, 120)

local feedEntries = {}

net.Receive("nut_killfeed_event", function()
	local killer     = net.ReadString()
	local victim     = net.ReadString()
	local weaponName = net.ReadString()
	local icon       = net.ReadUInt(4)

	table.insert(feedEntries, 1, {
		killer = killer,
		victim = victim,
		weapon = weaponName,
		icon   = icon,
		born   = CurTime()
	})

	while (#feedEntries > FEED_MAX) do
		table.remove(feedEntries)
	end
end)

local function getIconChar(icon)
	if (icon == ICON_HEADSHOT) then return ICON_HEADSHOT_CHAR end
	if (icon == ICON_AIR) then return ICON_AIR_CHAR end
	return nil
end

local function drawEntry(entry, x, y, alpha)
	local killerW  = surface.GetTextSize(entry.killer)
	local victimW  = surface.GetTextSize(entry.victim)
	local weaponW  = surface.GetTextSize("[" .. entry.weapon .. "]")
	local iconChar = getIconChar(entry.icon)
	local iconW    = iconChar and surface.GetTextSize(iconChar) or 0
	local spacing  = 6

	local totalW = killerW + spacing + (iconChar and (iconW + spacing) or 0) + weaponW + spacing + victimW + spacing * 2

	-- background
	surface.SetDrawColor(COLOR_BG.r, COLOR_BG.g, COLOR_BG.b, math.min(COLOR_BG.a, alpha))
	surface.DrawRect(x - totalW - spacing, y, totalW + spacing * 2, ENTRY_H)

	local curX = x - spacing
	-- draw right-to-left: victim first, then weapon, then icon, then killer

	-- victim (right-aligned)
	draw.SimpleText(entry.victim, "nutMediumFont", curX, y + ENTRY_H / 2,
		Color(COLOR_VICTIM.r, COLOR_VICTIM.g, COLOR_VICTIM.b, alpha),
		TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	curX = curX - victimW - spacing

	-- weapon class
	draw.SimpleText("[" .. entry.weapon .. "]", "nutMediumFont", curX, y + ENTRY_H / 2,
		Color(COLOR_WEAPON.r, COLOR_WEAPON.g, COLOR_WEAPON.b, alpha),
		TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	curX = curX - weaponW - spacing

	-- icon (if any)
	if (iconChar) then
		draw.SimpleText(iconChar, "nutMediumFont", curX, y + ENTRY_H / 2,
			Color(COLOR_ICON.r, COLOR_ICON.g, COLOR_ICON.b, alpha),
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		curX = curX - iconW - spacing
	end

	-- killer
	draw.SimpleText(entry.killer, "nutMediumFont", curX, y + ENTRY_H / 2,
		Color(COLOR_KILLER.r, COLOR_KILLER.g, COLOR_KILLER.b, alpha),
		TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

hook.Add("HUDPaint", "nutKillfeedDraw", function()
	if (#feedEntries == 0) then return end

	surface.SetFont("nutMediumFont")

	local screenW = ScrW()
	local x = screenW - FEED_X_OFFSET
	local y = FEED_Y_OFFSET
	local now = CurTime()

	for i = #feedEntries, 1, -1 do
		local entry = feedEntries[i]
		local age   = now - entry.born

		if (age > FEED_LIFETIME) then
			table.remove(feedEntries, i)
		else
			local alpha = 255
			if (age > FEED_LIFETIME - FEED_FADETIME) then
				alpha = 255 * (1 - (age - (FEED_LIFETIME - FEED_FADETIME)) / FEED_FADETIME)
			end

			drawEntry(entry, x, y, alpha)
			y = y + ENTRY_H + ENTRY_PAD
		end
	end
end)
