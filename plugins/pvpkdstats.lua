PLUGIN.name = "PvP K/D Stats"
PLUGIN.author = "GitHub Copilot"
PLUGIN.desc = "Tracks per-character PvP kills/deaths."

if (SERVER) then
	local function incrementStat(character, key)
		if (not character) then
			return
		end

		local current = tonumber(character:getData(key, 0)) or 0
		character:setData(key, current + 1)
	end

	function PLUGIN:PlayerDeath(victim, inflictor, attacker)
		if (not IsValid(victim) or not victim:IsPlayer()) then
			return
		end

		if (not IsValid(attacker) or not attacker:IsPlayer() or attacker == victim) then
			return
		end

		local victimChar = victim:getChar()
		local attackerChar = attacker:getChar()
		if (not victimChar or not attackerChar) then
			return
		end

		incrementStat(attackerChar, "pvpKills")
		incrementStat(victimChar, "pvpDeaths")
	end
end
