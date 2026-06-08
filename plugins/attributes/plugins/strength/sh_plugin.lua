PLUGIN.name = "Strength"
PLUGIN.author = "Chessnut"
PLUGIN.desc = "Adds a strength attribute."

local ATTRIBUTE_MAX = 30

local function getStrengthScale(client)
	local profile = IsValid(client) and client.HGRPAttributeProfile

	if (not profile and HGRP and HGRP.GetAthleticProfile) then
		profile = HGRP.GetAthleticProfile(client)
	end

	if (profile and profile.strengthScale) then
		return math.Clamp(tonumber(profile.strengthScale) or 0, 0, 1)
	end

	local character = IsValid(client) and client.getChar and client:getChar()

	if (character and character.getAttrib) then
		return math.Clamp((tonumber(character:getAttrib("str", 0)) or 0) / ATTRIBUTE_MAX, 0, 1)
	end

	return 0
end

local function getPunchDamageMultiplier(client)
	local multiplier = IsValid(client) and tonumber(client.HGRPAttributePunchDamageMul)

	if (multiplier) then
		return math.Clamp(multiplier, 0.1, 4)
	end

	return Lerp(getStrengthScale(client), 0.45, 1.8)
end

local function getTargetHardness(trace)
	if (not trace or not trace.Hit) then
		return 0
	end

	local entity = trace.Entity

	if (IsValid(entity) and entity:IsPlayer()) then
		local profile = entity.HGRPAttributeProfile or (HGRP and HGRP.GetAthleticProfile and HGRP.GetAthleticProfile(entity))
		return math.Clamp(tonumber(profile and profile.strengthScale) or 0.5, 0, 1)
	end

	if (trace.HitWorld) then
		return 0.8
	end

	if (IsValid(entity)) then
		local physics = entity.GetPhysicsObject and entity:GetPhysicsObject()

		if (IsValid(physics)) then
			return math.Clamp((physics:GetMass() - 15) / 135, 0.35, 0.9)
		end
	end

	return 0.55
end

local function hurtPunchingArm(client, deficit)
	local organism = IsValid(client) and client.organism

	if (not istable(organism)) then
		return
	end

	local risk = tonumber(client.HGRPAttributePunchSelfInjuryMul) or Lerp(getStrengthScale(client), 1, 0.08)

	if (risk <= 0 or math.Rand(0, 1) > math.Clamp(deficit * risk * 0.65, 0, 0.65)) then
		return
	end

	local arm = math.random(1, 2) == 1 and "rarm" or "larm"

	if (organism[arm.."amputated"]) then
		return
	end

	organism[arm] = math.Clamp((tonumber(organism[arm]) or 0) + 0.05 + deficit * risk * 0.12, 0, 1)
	organism.painadd = (tonumber(organism.painadd) or 0) + 0.75 + deficit * risk * 1.5

	if (organism[arm] >= 0.5 and math.Rand(0, 1) < math.Clamp(deficit * risk * 0.25, 0, 0.25)) then
		organism[arm.."dislocation"] = true
	end
end

if (SERVER) then
	function PLUGIN:PlayerGetFistDamage(client, damage, context)
		if (context) then
			context.damage = math.max((tonumber(context.damage) or damage or 0) * getPunchDamageMultiplier(client), 0)
		end
	end

	function PLUGIN:PlayerThrowPunch(client, hit)
		if (client:getChar()) then
			client:getChar():updateAttrib("str", 0.001)
		end

		local strengthScale = getStrengthScale(client)
		local deficit = math.Clamp(getTargetHardness(hit) - strengthScale, 0, 1)

		if (deficit > 0.05) then
			hurtPunchingArm(client, deficit)
		end
	end
end

-- Configuration for the plugin
nut.config.add("strMultiplier", 0.3, "The strength multiplier scale", nil, {
	form = "Float",
	data = {min=0, max=1.0},
	category = "Strength"
})
