function GM:PlayerNoClip(client)
	return client:IsAdmin()
end

HOLDTYPE_TRANSLATOR = HOLDTYPE_TRANSLATOR or {}
HOLDTYPE_TRANSLATOR[""] = "normal"
HOLDTYPE_TRANSLATOR["physgun"] = "smg"
HOLDTYPE_TRANSLATOR["ar2"] = "smg"
HOLDTYPE_TRANSLATOR["crossbow"] = "shotgun"
HOLDTYPE_TRANSLATOR["rpg"] = "shotgun"
HOLDTYPE_TRANSLATOR["slam"] = "normal"
HOLDTYPE_TRANSLATOR["grenade"] = "normal"
HOLDTYPE_TRANSLATOR["fist"] = "normal"
HOLDTYPE_TRANSLATOR["melee2"] = "melee"
HOLDTYPE_TRANSLATOR["passive"] = "normal"
HOLDTYPE_TRANSLATOR["knife"] = "melee"
HOLDTYPE_TRANSLATOR["duel"] = "pistol"
HOLDTYPE_TRANSLATOR["camera"] = "smg"
HOLDTYPE_TRANSLATOR["magic"] = "normal"
HOLDTYPE_TRANSLATOR["revolver"] = "pistol"

PLAYER_HOLDTYPE_TRANSLATOR = PLAYER_HOLDTYPE_TRANSLATOR or {}
PLAYER_HOLDTYPE_TRANSLATOR[""] = "normal"
PLAYER_HOLDTYPE_TRANSLATOR["normal"] = "normal"
PLAYER_HOLDTYPE_TRANSLATOR["revolver"] = "normal"
PLAYER_HOLDTYPE_TRANSLATOR["fist"] = "normal"
PLAYER_HOLDTYPE_TRANSLATOR["pistol"] = "normal"
PLAYER_HOLDTYPE_TRANSLATOR["grenade"] = "normal"
PLAYER_HOLDTYPE_TRANSLATOR["melee"] = "normal"
PLAYER_HOLDTYPE_TRANSLATOR["slam"] = "normal"
PLAYER_HOLDTYPE_TRANSLATOR["melee2"] = "normal"
PLAYER_HOLDTYPE_TRANSLATOR["knife"] = "normal"
PLAYER_HOLDTYPE_TRANSLATOR["duel"] = "normal"
PLAYER_HOLDTYPE_TRANSLATOR["bugbait"] = "normal"

local getModelClass = nut.anim.getModelClass
local IsValid = IsValid
local string = string
local type = type

local PLAYER_HOLDTYPE_TRANSLATOR = PLAYER_HOLDTYPE_TRANSLATOR
local HOLDTYPE_TRANSLATOR = HOLDTYPE_TRANSLATOR

local function isActivityValid(client, activity)
	if (not isnumber(activity)) then
		return true
	end

	if (not client.SelectWeightedSequence) then
		return true
	end

	return client:SelectWeightedSequence(activity) ~= -1
end

local function firstValidActivity(client, activities)
	for i = 1, #activities do
		local candidate = activities[i]
		if (isActivityValid(client, candidate)) then
			return candidate
		end
	end
end

local function getReloadGestureForHoldType(client, holdType)
	holdType = HOLDTYPE_TRANSLATOR[holdType] or holdType

	if (holdType == "pistol") then
		return firstValidActivity(client, {
			ACT_HL2MP_GESTURE_RELOAD_PISTOL,
			ACT_HL2MP_GESTURE_RELOAD_REVOLVER,
			ACT_GESTURE_RELOAD_PISTOL
		})
	elseif (holdType == "shotgun") then
		return firstValidActivity(client, {
			ACT_HL2MP_GESTURE_RELOAD_SHOTGUN,
			ACT_GESTURE_RELOAD_SHOTGUN,
			ACT_HL2MP_GESTURE_RELOAD_AR2,
			ACT_HL2MP_GESTURE_RELOAD_SMG1,
			ACT_GESTURE_RELOAD_SMG1
		})
	end

	return firstValidActivity(client, {
		ACT_HL2MP_GESTURE_RELOAD_AR2,
		ACT_HL2MP_GESTURE_RELOAD_SMG1,
		ACT_GESTURE_RELOAD_SMG1
	})
end

local function isHumanAnimClass(animClass)
	return animClass == "player"
		or animClass == "citizen_male"
		or animClass == "citizen_female"
		or animClass == "suit_pvp"
end

local function isArccwOnSafety(weapon)
	if (not IsValid(weapon)) then return false end

	if (weapon.SafetyOn == true or weapon.Safe == true) then return true end

	if (isfunction(weapon.GetSafe)) then
		local ok, v = pcall(weapon.GetSafe, weapon)
		if (ok and v == true) then return true end
	end

	if (isfunction(weapon.GetSafety)) then
		local ok, v = pcall(weapon.GetSafety, weapon)
		if (ok and v == true) then return true end
	end

	if (isfunction(weapon.GetCurrentFiremode)) then
		local ok, fm = pcall(weapon.GetCurrentFiremode, weapon)
		if (ok) then
			if (istable(fm)) then
				local mode = tonumber(fm.Mode or fm.mode)
				if (mode ~= nil) then return mode == 0 end
				local pn = string.lower(tostring(fm.PrintName or fm.printname or ""))
				if (pn == "safe" or pn == "safety") then return true end
				local mn = string.lower(tostring(fm.Name or fm.name or ""))
				if (mn == "safe" or mn == "safety") then return true end
			elseif (isstring(fm)) then
				local v = string.lower(fm)
				if (v == "safe" or v == "safety") then return true end
			elseif (isnumber(fm)) then
				return fm == 0
			end
		end
	end

	return false
end

local function isWepRaisedSafe(client)
	if (client and client.isWepRaised) then
		local ok, raised = pcall(client.isWepRaised, client)
		if (ok and raised ~= nil) then
			return raised
		end
	end

	if (client and client.getNetVar) then
		if (client:getNetVar("restricted")) then
			return false
		end

		if (nut and nut.config and nut.config.get and nut.config.get("wepAlwaysRaised")) then
			return true
		end

		return client:getNetVar("raised", false)
	end

	return true
end

function GM:TranslateActivity(client, act)
	local model = string.lower(client.GetModel(client))
	local class = getModelClass(model) or "player"
	local weapon = client.GetActiveWeapon(client)
	local onSafety = isArccwOnSafety(weapon)

	if (class == "player") then
		if (not nut.config.get("wepAlwaysRaised") and IsValid(weapon) and onSafety and client.OnGround(client)) then
			if (string.find(model, "zombie")) then
				local tree = nut.anim.zombie

				if (string.find(model, "fast")) then
					tree = nut.anim.fastZombie
				end

				if (tree[act]) then
					return tree[act]
				end
			end

			local holdType = IsValid(weapon) and (weapon.HoldType or weapon.GetHoldType(weapon)) or "normal"

			if (not nut.config.get("wepAlwaysRaised") and IsValid(weapon) and onSafety and client:OnGround()) then
				holdType = PLAYER_HOLDTYPE_TRANSLATOR[holdType] or "passive"
			end

			local tree = nut.anim.player[holdType]

			if (tree) then
				local selected = tree[act]

				if (selected) then
					if (type(selected) == "string") then
						local sequence = client.LookupSequence(client, selected)
						if (sequence and sequence >= 0) then
							client.CalcSeqOverride = sequence

							return
						end
					elseif (isActivityValid(client, selected)) then
						return selected
					end
				end

				local fallback = nut.anim.player.normal and nut.anim.player.normal[act]
				if (fallback) then
					if (type(fallback) == "string") then
						local sequence = client.LookupSequence(client, fallback)
						if (sequence and sequence >= 0) then
							client.CalcSeqOverride = sequence

							return
						end
					elseif (isActivityValid(client, fallback)) then
						return fallback
					end
				end
			end
		end

		local baseAct = self.BaseClass.TranslateActivity(self.BaseClass, client, act)

		if (baseAct == nil or isActivityValid(client, baseAct)) then
			return baseAct
		end

		if (act == ACT_MP_WALK) then
			return firstValidActivity(client, {
				ACT_HL2MP_WALK,
				ACT_WALK,
				ACT_WALK_RIFLE_RELAXED,
				ACT_WALK_AIM_RIFLE_STIMULATED
			})
		elseif (act == ACT_MP_CROUCHWALK) then
			return firstValidActivity(client, {
				ACT_HL2MP_WALK_CROUCH,
				ACT_WALK_CROUCH,
				ACT_WALK_CROUCH_RIFLE,
				ACT_WALK_CROUCH_AIM_RIFLE
			})
		elseif (act == ACT_MP_RUN) then
			return firstValidActivity(client, {
				ACT_HL2MP_RUN,
				ACT_RUN,
				ACT_RUN_RIFLE_RELAXED,
				ACT_RUN_AIM_RIFLE_STIMULATED
			})
		end

		return baseAct
	end

	local tree = nut.anim[class]

	if (tree) then
		local subClass = "normal"

		if (client.InVehicle(client)) then
			local vehicle = client.GetVehicle(client)
			local class = vehicle:isChair() and "chair" or vehicle:GetClass()

			if (tree.vehicle and tree.vehicle[class]) then
				local act = tree.vehicle[class][1]
				local fixvec = tree.vehicle[class][2]

				if (fixvec) then
					client:SetLocalPos(Vector(16.5438, -0.1642, -20.5493))
				end

				if (type(act) == "string") then
					client.CalcSeqOverride = client.LookupSequence(client, act)

					return
				else
					return act
				end
			else
				act = tree.normal[ACT_MP_CROUCH_IDLE][1]

				if (type(act) == "string") then
					client.CalcSeqOverride = client:LookupSequence(act)
				end

				return
			end
		elseif (client.OnGround(client)) then
			client.ManipulateBonePosition(client, 0, vector_origin)

			if (IsValid(weapon)) then
				subClass = weapon.HoldType or weapon.GetHoldType(weapon)
				subClass = HOLDTYPE_TRANSLATOR[subClass] or subClass
			end

			-- 2h weapons on safety: override to normal subclass so arms hang at sides
			if (isHumanAnimClass(class) and class ~= "player" and
				(subClass == "smg" or subClass == "shotgun") and
				isArccwOnSafety(weapon)) then
				subClass = "normal"
			end

			if (tree[subClass] and tree[subClass][act]) then
				local index = 1

				if (isHumanAnimClass(class) and class ~= "player" and subClass ~= "normal" and subClass ~= "passive") then
					local onSafety = isArccwOnSafety(weapon)
					local isSprinting = (act == ACT_MP_RUN)
					-- Aimed pose when weapon is ready (not on safety) and not sprinting
					index = (not onSafety and not isSprinting) and 2 or 1
				end

				local act2 = tree[subClass][act][index]

				if (type(act2) == "string") then
					client.CalcSeqOverride = client.LookupSequence(client, act2)

					return
				end

				return act2
			end
		elseif (tree.glide) then
			return tree.glide
		end
	end
end

function GM:HandlePlayerJumping(client, velocity)
	return self.BaseClass:HandlePlayerJumping(client, velocity)
end

local function playGesture(client, data)
	if (SERVER) then
		client:doGesture(GESTURE_SLOT_CUSTOM, data, true)
	else
		client:AnimRestartGesture(GESTURE_SLOT_CUSTOM, data, true)
	end
end

local function playGestureSequence(client, data)
	if (SERVER) then
		client:AddVCDSequenceToGestureSlot(GESTURE_SLOT_CUSTOM, data, 0, true)
	else
		client:AddVCDSequenceToGestureSlot(GESTURE_SLOT_CUSTOM, data, 0, true)
	end
end

function GM:DoAnimationEvent(client, event, data)
	local model = client:GetModel():lower()
	local class = nut.anim.getModelClass(model)

	if (event == PLAYERANIMEVENT_GESTURE or event == PLAYERANIMEVENT_CUSTOM_GESTURE) then
		playGesture(client, data)

		return ACT_INVALID
	elseif (event == PLAYERANIMEVENT_CUSTOM_GESTURE_SEQUENCE) then
		playGestureSequence(client, data)

		return ACT_INVALID
	elseif (event == PLAYERANIMEVENT_CUSTOM_SEQUENCE) then
		client:ResetSequence(data)

		return ACT_INVALID
	end

	if (class == "player") then
		if (event == PLAYERANIMEVENT_RELOAD) then
			local weapon = client:GetActiveWeapon()
			if (IsValid(weapon)) then
				local holdType = weapon.HoldType or weapon:GetHoldType() or "normal"
				local gesture = getReloadGestureForHoldType(client, holdType)

				if (gesture and isActivityValid(client, gesture)) then
					client:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, gesture, true)

					return ACT_INVALID
				end
			end
		end

		return self.BaseClass:DoAnimationEvent(client, event, data)
	else
		local weapon = client:GetActiveWeapon()

		if (IsValid(weapon)) then
			local holdType = weapon.HoldType or weapon:GetHoldType()
			holdType = HOLDTYPE_TRANSLATOR[holdType] or holdType

			local animation = nut.anim[class][holdType]

			if (not animation) then
				animation = nut.anim[class].normal
			end

			if (not animation) then return ACT_INVALID end

			if (event == PLAYERANIMEVENT_ATTACK_PRIMARY) then
				client:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, animation.attack or ACT_GESTURE_RANGE_ATTACK_SMG1, true)

				return ACT_VM_PRIMARYATTACK
			elseif (event == PLAYERANIMEVENT_ATTACK_SECONDARY) then
				client:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, animation.attack or ACT_GESTURE_RANGE_ATTACK_SMG1, true)

				return ACT_VM_SECONDARYATTACK
			elseif (event == PLAYERANIMEVENT_RELOAD) then
				client:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, animation.reload or ACT_GESTURE_RELOAD_SMG1, true)

				return ACT_INVALID
			elseif (event == PLAYERANIMEVENT_JUMP) then
				client.m_bJumping = true
				client.m_bFistJumpFrame = true
				client.m_flJumpStartTime = CurTime()

				client:AnimRestartMainSequence()

				return ACT_INVALID
			elseif (event == PLAYERANIMEVENT_CANCEL_RELOAD) then
				client:AnimResetGestureSlot(GESTURE_SLOT_ATTACK_AND_RELOAD)

				return ACT_INVALID
			end
		end
	end

	return ACT_INVALID
end

function GM:PlayerShouldTaunt(client, actid)
	if (not IsValid(client) or not client:Alive()) then
		return false
	end

	if (client:getLocalVar("ragdoll")) then
		return false
	end

	return true
end

function GM:PlayerStartTaunt(client, actid, length)
	if (not IsValid(client) or not actid or actid < 0) then
		return
	end

	client.nutTauntSeq = actid
	client.nutTauntEnd = CurTime() + math.max(tonumber(length) or 0, 0)
end

function GM:EntityEmitSound(data)
	if (data.Entity.nutIsMuted) then
		return false
	end

	-- Block NPC footstep animation events from citizen/male/female player models.
	-- Citizen model walk/run sequences have embedded AE_NPC_LEFTFOOT/RIGHTFOOT events
	-- that emit NPC footstep sounds independently of the PlayerFootstep hook.
	if (CLIENT and IsValid(data.Entity) and data.Entity:IsPlayer()) then
		local snd = string.lower(data.SoundName or "")
		if (
			(snd:find("npc/citizen", 1, true) or snd:find("npc/male", 1, true) or snd:find("npc/female", 1, true)) and
			(snd:find("foot", 1, true) or snd:find("step", 1, true))
		) then
			return false
		end
	end
end

local vectorAngle = FindMetaTable("Vector").Angle
local normalizeAngle = math.NormalizeAngle
local oldCalcSeqOverride
local usingPlayerAnims = true

function GM:HandlePlayerLanding(client, velocity, wasOnGround)
	return self.BaseClass:HandlePlayerLanding(client, velocity, wasOnGround)
end

function GM:CalcMainActivity(client, velocity)
	local eyeAngles = client.EyeAngles(client)
	local yaw = vectorAngle(velocity)[2]
	local normalized = normalizeAngle(yaw - eyeAngles[2])

	client.SetPoseParameter(client, "move_yaw", normalized)

	local oldSeqOverride = client.CalcSeqOverride
	local seqIdeal, seqOverride = self.BaseClass.CalcMainActivity(self.BaseClass, client, velocity)
	local tauntSequence = client.nutTauntSeq

	if (tauntSequence) then
		if (client:IsPlayingTaunt() or (client.nutTauntEnd or 0) > CurTime()) then
			return seqIdeal, tauntSequence
		end

		client.nutTauntSeq = nil
		client.nutTauntEnd = nil
	end

	return seqIdeal, client.nutForceSeq or oldSeqOverride or client.CalcSeqOverride
end

function GM:OnCharVarChanged(char, varName, oldVar, newVar)
	if (nut.char.varHooks[varName]) then
		for k, v in pairs(nut.char.varHooks[varName]) do
			v(char, oldVar, newVar)
		end
	end
end

function GM:GetDefaultCharName(client, faction)
	local info = nut.faction.indices[faction]

	if (info and info.onGetDefaultName) then
		return info:onGetDefaultName(client)
	end
end

function GM:GetDefaultCharDesc(client, faction)
	local info = nut.faction.indices[faction]

	if (info and info.onGetDefaultDesc) then
		return info:onGetDefaultDesc(client)
	end
end


function GM:CanPlayerUseChar(client, char)
	local banned = char:getData("banned")

	if (banned) then
		if (isnumber(banned) and banned < os.time()) then
			return
		end

		return false, "@charBanned"
	end

	local faction = nut.faction.indices[char:getFaction()]
	if (
		faction and
		hook.Run("CheckFactionLimitReached", faction, char, client)
	) then
		return false, "@limitFaction"
	end
end

-- Whether or not more players are not allowed to load a character of
-- a specific faction since the faction is full.
function GM:CheckFactionLimitReached(faction, character, client)
	if (isfunction(faction.onCheckLimitReached)) then
		return faction:onCheckLimitReached(character, client)
	end

	if (not isnumber(faction.limit)) then return false end

	-- By default, the limit is the number of players allowed in that faction.
	local maxPlayers = faction.limit

	-- If some number less than 1, treat it as a percentage of the player count.
	if (faction.limit < 1) then
		maxPlayers = math.Round(#player.GetAll() * faction.limit)
	end

	return team.NumPlayers(faction.index) >= maxPlayers
end

function GM:CanProperty(client, property, entity)
	if (client:IsAdmin()) then
		return true
	end

	if (CLIENT and (property == "remover" or property == "collision")) then
		return true
	end

	return false
end

function GM:PhysgunPickup(client, entity)
	if (client:IsSuperAdmin()) then
		return true
	end

	if (client:IsAdmin() and !(entity:IsPlayer() and entity:IsSuperAdmin())) then
		return true
	end

	if (self.BaseClass:PhysgunPickup(client, entity) == false) then
		return false
	end

	return false
end

function GM:Move(client, moveData)
	local char = client:getChar()

	if (char) then
		if (client:getNetVar("actAng")) then
			moveData:SetForwardSpeed(0)
			moveData:SetSideSpeed(0)
		end

		if (client:GetMoveType() == MOVETYPE_WALK and moveData:KeyDown(IN_WALK)) then
			local mf, ms = 0, 0
			local speed = client:GetWalkSpeed()
			local ratio = nut.config.get("walkRatio")

			if (moveData:KeyDown(IN_FORWARD)) then
				mf = ratio
			elseif (moveData:KeyDown(IN_BACK)) then
				mf = -ratio
			end

			if (moveData:KeyDown(IN_MOVELEFT)) then
				ms = -ratio
			elseif (moveData:KeyDown(IN_MOVERIGHT)) then
				ms = ratio
			end

			moveData:SetForwardSpeed(mf * speed)
			moveData:SetSideSpeed(ms * speed)
		end
	end
end

function GM:CanItemBeTransfered(itemObject, curInv, inventory)
	if (itemObject.onCanBeTransfered) then
		local itemHook = itemObject:onCanBeTransfered(curInv, inventory)

		return (itemHook ~= false)
	end
end
