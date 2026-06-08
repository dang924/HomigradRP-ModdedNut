PLUGIN.name = "Kill Recognition"
PLUGIN.author = "Copilot"
PLUGIN.desc = "Recognize players you kill."

if (SERVER) then
	function PLUGIN:PlayerDeath(victim, inflictor, attacker)
		if (not IsValid(victim) or not victim:IsPlayer()) then
			return
		end

		if (not IsValid(attacker) or not attacker:IsPlayer() or attacker == victim) then
			return
		end

		local attackerChar = attacker:getChar()
		local victimChar = victim:getChar()
		if (not attackerChar or not victimChar) then
			return
		end

		if (attackerChar:doesRecognize(victimChar)) then
			return
		end

		if (attackerChar:recognize(victimChar)) then
			attacker:notify("You recognized \"" .. victimChar:getName() .. "\".")
			hook.Run("OnCharRecognized", attacker, victimChar:getID())
		end
	end
end