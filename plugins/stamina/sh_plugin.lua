PLUGIN.name = "Stamina"
PLUGIN.author = "Chessnut"
PLUGIN.desc = "Adds a stamina system to limit running."
local PLUGIN = PLUGIN

nut.config.add("defaultStamina", 100, "A higher number means that characters can run longer without tiring.", nil,
{	data = {min = 50, max = 500},
	category = "stamina"
})

nut.config.add("staminaRegenMultiplier", 1, "A higher number means that characters can run regenerate stamina faster.",nil,
{	data = {min = 0.1, max = 20},
	category = "stamina"
})

nut.config.add("crouchStaminaRegenMultiplier", 3, "How much faster stamina regenerates while crouching.", nil,
{	data = {min = 1, max = 10},
	category = "stamina"
})

nut.config.add("crouchStaminaMinRegenPerTick", 5, "Minimum stamina recovered each stamina tick while crouching.", nil,
{	data = {min = 0, max = 30},
	category = "stamina"
})

nut.config.add("jumpStaminaCost", 15, "How much stamina jumping costs (as percentage of max stamina).", nil,
{	data = {min = 0, max = 50},
	category = "stamina"
})

local function getOrganismStamina(client)
	local organism = IsValid(client) and client.organism

	if (not istable(organism) or not istable(organism.stamina)) then
		return
	end

	local pool = organism.stamina
	local maxStamina = tonumber(pool.max or pool.range) or 0

	if (maxStamina <= 0) then
		return
	end

	local current = math.Clamp(tonumber(pool[1]) or maxStamina, 0, maxStamina)
	return pool, current, maxStamina
end

local function syncOrganismStaminaBar(client)
	local _, current, maxStamina = getOrganismStamina(client)

	if (not current) then
		return false
	end

	local displayMax = nut.config.get("defaultStamina", 100)
	local value = math.Clamp((current / maxStamina) * displayMax, 0, displayMax)

	if (math.abs((client:getLocalVar("stm", -1) or -1) - value) > 0.01) then
		client:setLocalVar("stm", value)
	end

	return true, value, displayMax, current, maxStamina
end

local function restoreOrganismStamina(client, amount)
	local pool, current, maxStamina = getOrganismStamina(client)

	if (not pool) then
		return false
	end

	local displayMax = nut.config.get("defaultStamina", 100)
	local organismAmount = (tonumber(amount) or 0) / displayMax * maxStamina
	pool[1] = math.Clamp(current + organismAmount, 0, maxStamina)
	syncOrganismStaminaBar(client)

	return true
end

local function takeJumpStamina(client)
	if (not IsValid(client)) then
		return
	end

	if (syncOrganismStaminaBar(client)) then
		return
	end

	local maxStamina = nut.config.get("defaultStamina", 100)
	local jumpCostPercent = nut.config.get("jumpStaminaCost", 15) or 15
	local jumpCost = math.ceil((jumpCostPercent / 100) * maxStamina)
	local current = client:getLocalVar("stm", 0)

	if (jumpCost <= 0 or current <= 0) then
		return
	end

	client:setLocalVar("stm", math.Clamp(current - jumpCost, 0, maxStamina))
end

local function getRequiredJumpStamina()
	local maxStamina = nut.config.get("defaultStamina", 100)
	local jumpCostPercent = 5

	return math.ceil((jumpCostPercent / 100) * maxStamina)
end

local function canJumpWithStamina(client)
	if (not IsValid(client)) then
		return false
	end

	local minJumpStamina = getRequiredJumpStamina()
	local _, current, maxStamina = getOrganismStamina(client)

	if (current) then
		local displayMax = nut.config.get("defaultStamina", 100)
		return (current / maxStamina) * displayMax >= minJumpStamina
	end

	local current = client:getLocalVar("stm", 0)

	return current >= minJumpStamina
end

local function shouldDrainRunStamina(client)
	if (not IsValid(client)) then
		return false
	end

	if (isfunction(client.isRunning)) then
		return client:isRunning()
	end

	if (client:GetVelocity():Length2D() <= 250) then
		return false
	end

	return client:KeyDown(IN_SPEED) and client:KeyDown(IN_FORWARD)
		and not client:KeyDown(IN_BACK) and not client:KeyDown(IN_WALK)
		and not client:Crouching()
end

local function getScaledRunDrainOffset(client, character)
	local endAttrib = character.getAttrib and character:getAttrib("end", 0) or 0
	local stmAttrib = character.getAttrib and character:getAttrib("stm", 0) or 0
	local horizontalSpeed = client:GetVelocity():Length2D()
	local speedPressure = math.Clamp(horizontalSpeed / 250, 1, 2.25)
	local staminaSpeedPressure = math.Clamp(1 + (math.max(stmAttrib, 0) / 300), 1, 1.6)
	local enduranceMul = Lerp(math.Clamp(math.max(endAttrib, 0) / 100, 0, 1), 1.15, 0.55)
	local drain = -2 * speedPressure * staminaSpeedPressure * enduranceMul

	return math.min(drain, -0.1)
end

if (SERVER) then
	function PLUGIN:PostPlayerLoadout(client)
		client:setLocalVar("stm", nut.config.get("defaultStamina", 100))

		local uniqueID = "nutStam"..client:SteamID()
		local offset = 0

		timer.Create(uniqueID, 0.25, 0, function()
			if (not IsValid(client)) then
				timer.Remove(uniqueID)
				return
			end
			local character = client:getChar()
			local inFakeRagdoll = IsValid(client.FakeRagdoll)
				or IsValid(client:GetNWEntity("FakeRagdoll"))
			if ((client:GetMoveType() == MOVETYPE_NOCLIP and not inFakeRagdoll) or not character) then
				return
			end

			local synced, value, displayMax = syncOrganismStaminaBar(client)
			if (synced) then
				if (value <= 0 and not client:getNetVar("brth", false)) then
					client:setNetVar("brth", true)
					hook.Run("PlayerStaminaLost", client)
				elseif (value >= displayMax * 0.5 and client:getNetVar("brth", false)) then
					client:setNetVar("brth", nil)
				end

				return
			end

			if (client:Crouching()) then
				if (offset > 0.5) then
					offset = 1 * nut.config.get("staminaRegenMultiplier", 1)
				else
					offset = 1.75 * nut.config.get("staminaRegenMultiplier", 1)
				end

				-- Keep crouch recovery clearly faster even when run is held.
				offset = math.max(offset + 1.5, nut.config.get("crouchStaminaMinRegenPerTick", 5))
				offset = offset * math.max(nut.config.get("crouchStaminaRegenMultiplier", 3), 2)
			elseif (shouldDrainRunStamina(client)) then
				offset = getScaledRunDrainOffset(client, character)
			elseif (offset > 0.5) then
				offset = 1 * nut.config.get("staminaRegenMultiplier", 1)
			else
				offset = 1.75 * nut.config.get("staminaRegenMultiplier", 1)
			end

			local current = client:getLocalVar("stm", 0)
			local value = math.Clamp(current + offset, 0, nut.config.get("defaultStamina", 100))

			if (current ~= value) then
				client:setLocalVar("stm", value)

				if (value == 0 and not client:getNetVar("brth", false)) then
					client:setNetVar("brth", true)

					hook.Run("PlayerStaminaLost", client)
				elseif (value >= 50 and client:getNetVar("brth", false)) then
					client:setNetVar("brth", nil)
				end
			end
		end)
	end

	local playerMeta = FindMetaTable("Player")

	function playerMeta:restoreStamina(amount)
		if (restoreOrganismStamina(self, amount)) then
			return
		end

		local current = self:getLocalVar("stm", 0)
		local value = math.Clamp(current + amount, 0, nut.config.get("defaultStamina", 100))

		self:setLocalVar("stm", value)
	end

	function PLUGIN:StartCommand(client, command)
		if (not canJumpWithStamina(client)) then
			command:RemoveKey(IN_JUMP)
		end
	end

	function PLUGIN:Think()
		for _, client in ipairs(player.GetAll()) do
			if (not IsValid(client) or not client:Alive()) then
				continue
			end

			if (client:GetMoveType() ~= MOVETYPE_WALK) then
				client.nutWasOnGround = client:OnGround()
				continue
			end

			local onGround = client:OnGround()
			local wasOnGround = client.nutWasOnGround
			if (wasOnGround == nil) then
				client.nutWasOnGround = onGround
				continue
			end

			if (wasOnGround and not onGround and client:KeyDown(IN_JUMP) and client:GetVelocity().z > 60) then
				if ((client.nutNextJumpStamina or 0) <= CurTime()) then
					client.nutNextJumpStamina = CurTime() + 0.2
					takeJumpStamina(client)
				end
			end

			client.nutWasOnGround = onGround
		end
	end

	return
end

if (CLIENT) then
	if (nut.bar) then
	nut.bar.add(function()
		return LocalPlayer():getLocalVar("stm", 0) / nut.config.get("defaultStamina", 100)
	end, Color(200, 200, 40), nil, "stm")
	end
end
