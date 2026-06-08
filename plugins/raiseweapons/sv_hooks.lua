local function isArcCWWeapon(weapon)
	if (not IsValid(weapon)) then
		return false
	end

	local class = string.lower(weapon:GetClass() or "")
	return class:find("arccw", 1, true) ~= nil
end

function PLUGIN:KeyPress(client, key)
	local weapon = client:GetActiveWeapon()
	if (isArcCWWeapon(weapon)) then
		return
	end

	local forcedRaised = hook.Run("ShouldWeaponBeRaised", client, client:GetActiveWeapon())
	if (forcedRaised == true or nut.config.get("wepAlwaysRaised")) then
		return
	end

	if (key == IN_RELOAD) then
		timer.Create("nutToggleRaise"..client:SteamID(), 1, 1, function()
			if (IsValid(client)) then
				client:toggleWepRaised()
			end
		end)
	end
end

function PLUGIN:PlayerSwitchWeapon(client, oldWeapon, newWeapon)
	if (isArcCWWeapon(newWeapon)) then
		return
	end

	local forcedRaised = hook.Run("ShouldWeaponBeRaised", client, newWeapon)
	if (forcedRaised == true or nut.config.get("wepAlwaysRaised")) then
		return
	end

	client:setWepRaised(false)
end
