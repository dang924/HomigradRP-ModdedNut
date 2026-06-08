local PLUGIN = PLUGIN
PLUGIN.name = "New Fancy Third Person"
PLUGIN.author = "Black Tea"
PLUGIN.desc = "Third Person plugin."

nut.config.add("thirdperson", false, "Allow Thirdperson in the server.", nil, {
	category = "server"
})

if (CLIENT) then
	local NUT_CVAR_THIRDPERSON = CreateClientConVar("nut_tp_enabled", "0", true)
	local NUT_CVAR_TP_CLASSIC = CreateClientConVar("nut_tp_classic", "0", true)
	local NUT_CVAR_TP_VERT = CreateClientConVar("nut_tp_vertical", 10, true)
	local NUT_CVAR_TP_HORI = CreateClientConVar("nut_tp_horizontal", 0, true)
	local NUT_CVAR_TP_DIST = CreateClientConVar("nut_tp_distance", 50, true)

	concommand.Add("nut_tp_toggle", function()
		local setTP = GetConVar("nut_tp_enabled"):GetInt() == 0 and 1 or 0
		GetConVar("nut_tp_enabled"):SetInt(setTP)
	end)

	local PANEL = {}

	local maxValues = {
		height = 30,
		horizontal = 30,
		distance = 100
	}
	function PANEL:Init()
		self:SetTitle(L("thirdpersonConfig"))
		self:SetSize(300, 140)
		self:Center()
		self:MakePopup()

		self.list = self:Add("DPanel")
		self.list:Dock(FILL)
		self.list:DockMargin(0, 0, 0, 0)

		local cfg = self.list:Add("DNumSlider")
		cfg:Dock(TOP)
		cfg:SetText("Height") -- Set the text above the slider
		cfg:SetMin(0)				 -- Set the minimum number you can slide to
		cfg:SetMax(30)				-- Set the maximum number you can slide to
		cfg:SetDecimals(0)			 -- Decimal places - zero for whole number
		cfg:SetConVar("nut_tp_vertical") -- Changes the ConVar when you slide
		cfg:DockMargin(10, 0, 0, 5)

		local cfg = self.list:Add("DNumSlider")
		cfg:Dock(TOP)
		cfg:SetText("Horizontal") -- Set the text above the slider
		cfg:SetMin(-30)				 -- Set the minimum number you can slide to
		cfg:SetMax(30)				-- Set the maximum number you can slide to
		cfg:SetDecimals(0)			 -- Decimal places - zero for whole number
		cfg:SetConVar("nut_tp_horizontal") -- Changes the ConVar when you slide
		cfg:DockMargin(10, 0, 0, 5)

		local cfg = self.list:Add("DNumSlider")
		cfg:Dock(TOP)
		cfg:SetText("Distance") -- Set the text above the slider
		cfg:SetMin(0)				 -- Set the minimum number you can slide to
		cfg:SetMax(100)				-- Set the maximum number you can slide to
		cfg:SetDecimals(0)			 -- Decimal places - zero for whole number
		cfg:SetConVar("nut_tp_distance") -- Changes the ConVar when you slide
		cfg:DockMargin(10, 0, 0, 5)

	end
	vgui.Register("nutTPConfig", PANEL, "DFrame")

	local function isAllowed()
		return nut.config.get("thirdperson")
	end

	local allowedWeaponClasses = {
		["nut_hands"] = true,
		["weapon_hands"] = true,
		["nut_keys"] = true,
		["keys"] = true,
		["weapon_keys"] = true,
		["weapon_physgun"] = true,
		["weapon_physcannon"] = true,
		["gmod_tool"] = true
	}

	local function isArcCWWeapon(weapon)
		if (not IsValid(weapon)) then
			return false
		end

		if (weapon.ArcCW or weapon.Base == "arccw_base") then
			return true
		end

		local class = string.lower(weapon:GetClass() or "")
		local base = string.lower(weapon.Base or "")
		return class:find("arccw", 1, true) ~= nil or base:find("arccw", 1, true) ~= nil
	end

	local function isArccwOnSafety(weapon)
		if (not IsValid(weapon) or not isArcCWWeapon(weapon)) then
			return false
		end

		-- Only allow thirdperson on explicit safety states.
		if (weapon.SafetyOn == true or weapon.Safe == true) then
			return true
		end

		if (isfunction(weapon.GetSafe)) then
			local ok, isSafe = pcall(weapon.GetSafe, weapon)
			if (ok and isSafe == true) then
				return true
			end
		end

		if (isfunction(weapon.GetSafety)) then
			local ok, isSafe = pcall(weapon.GetSafety, weapon)
			if (ok and isSafe == true) then
				return true
			end
		end

		if (isfunction(weapon.GetCurrentFiremode)) then
			local ok, firemode = pcall(weapon.GetCurrentFiremode, weapon)
			if (ok) then
				if (istable(firemode)) then
					local mode = tonumber(firemode.Mode or firemode.mode)
					if (mode ~= nil) then
						return mode == 0
					end

					local printName = string.lower(tostring(firemode.PrintName or firemode.printname or ""))
					if (printName == "safe" or printName == "safety") then
						return true
					end

					local modeName = string.lower(tostring(firemode.Name or firemode.name or ""))
					if (modeName == "safe" or modeName == "safety") then
						return true
					end
				elseif (isstring(firemode)) then
					local value = string.lower(firemode)
					if (value == "safe" or value == "safety") then
						return true
					end
				elseif (isnumber(firemode)) then
					return firemode == 0
				end
			end
		end

		return false
	end

	local function canUseThirdPersonWeapon(client)
		local weapon = client:GetActiveWeapon()
		if (not IsValid(weapon)) then
			return false
		end

		if (allowedWeaponClasses[weapon:GetClass()] == true) then
			return true
		end

		-- Allow thirdperson with ArcCW weapons that are on safety
		if (isArcCWWeapon(weapon)) then
			return isArccwOnSafety(weapon)
		end

		return false
	end

	function PLUGIN:SetupQuickMenu(menu)
		if (isAllowed()) then
			menu:addCategory("Thirdperson")
			local button = menu:addCheck(L"thirdpersonToggle", function(panel, state)
				if (state) then
					RunConsoleCommand("nut_tp_enabled", "1")
				else
					RunConsoleCommand("nut_tp_enabled", "0")
				end
			end, NUT_CVAR_THIRDPERSON:GetBool())

			local button = menu:addCheck(L"thirdpersonClassic", function(panel, state)
				if (state) then
					RunConsoleCommand("nut_tp_classic", "1")
				else
					RunConsoleCommand("nut_tp_classic", "0")
				end
			end, NUT_CVAR_TP_CLASSIC:GetBool())

			local button = menu:addButton(L"thirdpersonConfig", function()
				if (nut.gui.tpconfig and nut.gui.tpconfig:IsVisible()) then
					nut.gui.tpconfig:Close()
					nut.gui.tpconfig = nil
				end

				nut.gui.tpconfig = vgui.Create("nutTPConfig")
			end)

			menu:addSpacer()
		end
	end

	function PLUGIN:PlayerBindPress(client, bind, pressed)
		if (not pressed) then
			return
		end

		bind = bind:lower()

		if (bind:find("gm_showspare2", 1, true)) then
			RunConsoleCommand("nut_tp_toggle")
			return true
		end
	end

	local playerMeta = FindMetaTable("Player")

	function playerMeta:CanOverrideView()
		local ragdoll = Entity(self:getLocalVar("ragdoll", 0))

		-- Do not use third person when the character menu is open.
		if (IsValid(nut.gui.char) and nut.gui.char:IsVisible()) then
			return false
		end

		return NUT_CVAR_THIRDPERSON:GetBool() and
			not IsValid(self:GetVehicle()) and
			isAllowed() and
			canUseThirdPersonWeapon(self) and
			IsValid(self) and
			self:getChar() and
			not self:getNetVar("actAng") and
			not IsValid(ragdoll) and
			LocalPlayer():Alive()
	end

	local view, traceData, traceData2, aimOrigin, crouchFactor, ft, trace, curAng
	local clmp = math.Clamp
	crouchFactor = 0
	function PLUGIN:CalcView(client, origin, angles, fov)
		ft = FrameTime()

		if (client:CanOverrideView() and LocalPlayer():GetViewEntity() == LocalPlayer()) then
			if ((client:OnGround() and client:KeyDown(IN_DUCK)) or client:Crouching()) then
				crouchFactor = Lerp(ft*5, crouchFactor, 1)
			else
				crouchFactor = Lerp(ft*5, crouchFactor, 0)
			end

			curAng = owner.camAng or Angle(0, 0, 0)
			view = {}
			traceData = {}
				traceData.start =	client:GetPos() + client:GetViewOffset() +
									curAng:Up() * clmp(NUT_CVAR_TP_VERT:GetInt(), 0, maxValues.height) +
									curAng:Right() * clmp(NUT_CVAR_TP_HORI:GetInt(), -maxValues.horizontal, maxValues.horizontal) -
									client:GetViewOffsetDucked()*.5 * crouchFactor
				traceData.endpos = traceData.start - curAng:Forward() * clmp(NUT_CVAR_TP_DIST:GetInt(), 0, maxValues.distance)
				traceData.filter = client
			view.origin = util.TraceLine(traceData).HitPos
			aimOrigin = view.origin
			view.angles = curAng + client:GetViewPunchAngles()

			traceData2 = {}
				traceData2.start = 	aimOrigin
				traceData2.endpos = aimOrigin + curAng:Forward() * 65535
				traceData2.filter = client

			if (NUT_CVAR_TP_CLASSIC:GetBool() or (owner.isWepRaised and owner:isWepRaised() or
				(owner:KeyDown(bit.bor(IN_FORWARD, IN_BACK, IN_MOVELEFT, IN_MOVERIGHT)) and owner:GetVelocity():Length() >= 10)) ) then
				client:SetEyeAngles((util.TraceLine(traceData2).HitPos - client:GetShootPos()):Angle())
			end

			return view
		end
	end

	local diff, fm, sm
	function PLUGIN:CreateMove(cmd)
		owner = LocalPlayer()

		if (owner:CanOverrideView() and owner:GetMoveType() ~= MOVETYPE_NOCLIP and LocalPlayer():GetViewEntity() == LocalPlayer()) then
			fm = cmd:GetForwardMove()
			sm = cmd:GetSideMove()
			diff = (owner:EyeAngles() - (owner.camAng or Angle(0, 0, 0)))[2] or 0
			diff = diff/90

			cmd:SetForwardMove(fm + sm*diff)
			cmd:SetSideMove(sm + fm*diff)
			return false
		end
	end

	function PLUGIN:InputMouseApply(cmd, x, y, ang)
		owner = LocalPlayer( )

		if (not owner.camAng) then
		    owner.camAng = Angle( 0, 0, 0 )
		end

		if (owner:CanOverrideView() and LocalPlayer():GetViewEntity() == LocalPlayer()) then

			owner.camAng.p = clmp(math.NormalizeAngle( owner.camAng.p + y / 50 ), -85, 85)
			owner.camAng.y = math.NormalizeAngle( owner.camAng.y - x / 50 )

			return true
		end
	end

	function PLUGIN:ShouldDrawLocalPlayer()
		if (
			LocalPlayer():GetViewEntity() == LocalPlayer() and
			not IsValid(LocalPlayer():GetVehicle()) and
			LocalPlayer():CanOverrideView()
		) then
			return true
		end
	end

	function PLUGIN:PlayerFootstep(client, position, foot, soundName, volume)
		if (client ~= LocalPlayer() or not client:CanOverrideView()) then
			return
		end

		local now = CurTime()
		if ((client.nutNextThirdPersonStep or 0) > now) then
			return true
		end

		-- Filter out the very fast duplicate predicted step.
		client.nutNextThirdPersonStep = now + 0.09
	end
end
