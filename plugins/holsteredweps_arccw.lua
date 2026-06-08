PLUGIN.name = "Holstered ArcCW Weapons"
PLUGIN.author = "Copilot"
PLUGIN.desc = "Shows holstered ArcCW weapons on players."

nut.config.add(
	"showHolsteredArccw",
	true,
	"Whether or not holstered ArcCW weapons show on players.",
	nil,
	{category = PLUGIN.name}
)

if (SERVER) then return end

local holsterOffsetX = CreateClientConVar("nut_arccw_holster_x", "0", true, false)
local holsterOffsetY = CreateClientConVar("nut_arccw_holster_y", "0", true, false)
local holsterOffsetZ = CreateClientConVar("nut_arccw_holster_z", "0", true, false)
local holsterPitch = CreateClientConVar("nut_arccw_holster_pitch", "0", true, false)
local holsterYaw = CreateClientConVar("nut_arccw_holster_yaw", "0", true, false)
local holsterRoll = CreateClientConVar("nut_arccw_holster_roll", "0", true, false)

ARCCW_HOLSTER_DRAWINFO = ARCCW_HOLSTER_DRAWINFO or {}

local DEFAULT_ARCCW_DRAW = {
	pos = Vector(4, 7, 18),
	ang = Angle(-30, 190, -5),
	bone = "ValveBiped.Bip01_Spine2"
}

ARCCW_HOLSTER_DRAWINFO["arccw_bo1_spectre"] = { pos = Vector(-7.571, -3.493, -1.747), ang = Angle(-149.345, 25.758, 180.000), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_waw_357"] = { pos = Vector(-15.551, -12.099, -3.236), ang = Angle(-3.401, -165.655, -80.645), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_base"] = { pos = Vector(-4.987, 7.000, 18.000), ang = Angle(0.000, 180.000, -23.748), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_waw_springfield"] = { pos = Vector(2.779, 0.112, -1.414), ang = Angle(32.193, -159.991, -4.112), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_mifl_fas2_p226"] = { pos = Vector(-6.794, -8.556, -2.140), ang = Angle(24.136, -169.782, -67.674), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_mifl_fas2_g20"] = { pos = Vector(-12.508, -8.487, -3.958), ang = Angle(10.252, -161.820, -65.477), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_bo1_python"] = { pos = Vector(-13.123, -15.085, -4.625), ang = Angle(7.502, -162.165, -61.696), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_bo2_browninghp"] = { pos = Vector(-14.248, -14.097, -5.322), ang = Angle(-2.550, -164.215, -79.191), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_bo1_makarov"] = { pos = Vector(-5.519, -14.715, -5.258), ang = Angle(32.389, -166.314, -68.071), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_bo1_dragunov"] = { pos = Vector(4.265, 2.300, -4.357), ang = Angle(38.970, -162.358, 4.204), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_mifl_fas2_minimi"] = { pos = Vector(9.856, 7.586, -7.942), ang = Angle(36.738, -169.856, 12.667), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_bo1_asp"] = { pos = Vector(-13.419, -16.271, -4.741), ang = Angle(3.804, -162.849, -79.590), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_bo1_skorpion"] = { pos = Vector(-6.168, -4.581, -4.500), ang = Angle(28.030, -170.859, -4.198), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_waw_bar"] = { pos = Vector(1.158, 9.248, -9.850), ang = Angle(33.143, -158.295, 6.517), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_waw_mosin"] = { pos = Vector(1.624, 3.133, -3.248), ang = Angle(29.739, -161.946, 11.098), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_bo1_hk21"] = { pos = Vector(2.892, 0.027, -7.419), ang = Angle(41.582, -162.187, 1.020), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_mifl_fas2_deagle"] = { pos = Vector(-9.647, -4.609, 0.032), ang = Angle(8.261, -162.462, -31.970), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_bo2_mp5"] = { pos = Vector(3.459, 2.782, -2.080), ang = Angle(32.948, -160.349, 1.333), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_cde_ak5"] = { pos = Vector(3.575, 1.507, -2.687), ang = Angle(38.068, -156.616, 2.594), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_waw_tt33"] = { pos = Vector(-10.079, -13.403, -5.065), ang = Angle(13.700, -163.102, -60.147), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_waw_arisaka"] = { pos = Vector(0.694, 3.194, -6.063), ang = Angle(29.131, -157.908, 3.371), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_mifl_fas2_rpk"] = { pos = Vector(3.228, -33.347, -15.004), ang = Angle(167.426, -161.003, 7.679), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_bo1_m14"] = { pos = Vector(3.538, 0.993, -1.647), ang = Angle(27.926, -159.967, -0.421), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_waw_garand"] = { pos = Vector(-2.062, 8.651, -5.418), ang = Angle(27.569, -155.950, 12.940), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_bo1_m202"] = { pos = Vector(9.245, -31.113, 1.909), ang = Angle(-155.123, -162.363, -2.560), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_mifl_fas2_g3"] = { pos = Vector(4.801, 6.552, -5.362), ang = Angle(31.196, -162.580, 2.862), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_mifl_fas2_mac11"] = { pos = Vector(-3.193, 3.828, -10.177), ang = Angle(44.114, -173.120, 5.966), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_bo1_m16"] = { pos = Vector(2.031, -1.699, -1.337), ang = Angle(28.062, -157.148, 2.908), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_bo1_rpg7"] = { pos = Vector(0.903, -12.645, 1.366), ang = Angle(157.961, -164.460, -161.419), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_waw_mp40"] = { pos = Vector(-8.669, -3.265, 1.221), ang = Angle(15.586, -163.493, 18.596), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_mifl_fas2_mp5"] = { pos = Vector(-7.568, 4.769, -4.644), ang = Angle(29.869, -158.777, -5.000), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_mw2_p90"] = { pos = Vector(-11.153, -20.389, -9.461), ang = Angle(3.401, -165.838, -5.000), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_bo1_l96"] = { pos = Vector(-4.802, -31.470, 9.567), ang = Angle(167.295, -162.264, -180.000), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_waw_ppsh41"] = { pos = Vector(-9.842, -8.905, 0.441), ang = Angle(22.979, -162.429, 2.724), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_bo1_chinalake"] = { pos = Vector(1.943, -9.760, 2.329), ang = Angle(30.603, -155.011, -8.362), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_bo1_kiparis"] = { pos = Vector(-8.986, 0.319, -1.499), ang = Angle(19.716, -158.793, -23.711), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_bo1_xl60"] = { pos = Vector(3.116, -8.381, -3.035), ang = Angle(33.582, -168.718, 15.504), bone = "ValveBiped.Bip01_Spine2" }
ARCCW_HOLSTER_DRAWINFO["arccw_mifl_fas2_m79"] = { pos = Vector(6.311, -0.605, 3.225), ang = Angle(11.655, -162.082, -5.000), bone = "ValveBiped.Bip01_Spine2" }

local editorFrame

local function cloneDrawInfo(drawInfo)
	drawInfo = drawInfo or DEFAULT_ARCCW_DRAW

	return {
		pos = Vector(drawInfo.pos.x, drawInfo.pos.y, drawInfo.pos.z),
		ang = Angle(drawInfo.ang.p, drawInfo.ang.y, drawInfo.ang.r),
		bone = drawInfo.bone or DEFAULT_ARCCW_DRAW.bone
	}
end

local function getSortedWeaponClasses()
	local classes = {}
	local seen = {}

	for _, weaponTable in ipairs(weapons.GetList() or {}) do
		local class = string.lower(tostring(weaponTable.ClassName or weaponTable.class or ""))
		if (class ~= "" and not seen[class]) then
			seen[class] = true
			classes[#classes + 1] = class
		end
	end

	for class in pairs(ARCCW_HOLSTER_DRAWINFO) do
		class = string.lower(class)
		if (not seen[class]) then
			seen[class] = true
			classes[#classes + 1] = class
		end
	end

	table.sort(classes)
	return classes
end

local function buildOffsetLine(class, drawInfo)
	return string.format(
		"ARCCW_HOLSTER_DRAWINFO[%q] = { pos = Vector(%.3f, %.3f, %.3f), ang = Angle(%.3f, %.3f, %.3f), bone = %q }",
		class,
		drawInfo.pos.x,
		drawInfo.pos.y,
		drawInfo.pos.z,
		drawInfo.ang.p,
		drawInfo.ang.y,
		drawInfo.ang.r,
		drawInfo.bone
	)
end

local function buildAllOffsetExport()
	local keys = {}
	for class in pairs(ARCCW_HOLSTER_DRAWINFO) do
		keys[#keys + 1] = class
	end
	table.sort(keys)

	local lines = {"-- ArcCW holster offsets"}
	for _, class in ipairs(keys) do
		local drawInfo = ARCCW_HOLSTER_DRAWINFO[class]
		if (drawInfo and drawInfo.pos and drawInfo.ang and drawInfo.bone) then
			lines[#lines + 1] = buildOffsetLine(class, drawInfo)
		end
	end

	return table.concat(lines, "\n")
end

local function openHolsterEditor()
	local localClient = LocalPlayer()
	if (not IsValid(localClient) or (not localClient:IsAdmin() and not localClient:IsSuperAdmin())) then
		chat.AddText(Color(255, 80, 80), "[ArcCW Holster] Admin required.")
		return
	end

	if (IsValid(editorFrame)) then
		editorFrame:SetVisible(true)
		editorFrame:MakePopup()
		return
	end

	editorFrame = vgui.Create("DFrame")
	editorFrame:SetSize(520, 640)
	editorFrame:Center()
	editorFrame:SetTitle("ArcCW Holster Offset Editor")
	editorFrame:MakePopup()

	local container = editorFrame:Add("DScrollPanel")
	container:Dock(FILL)
	container:DockMargin(8, 8, 8, 8)

	local classLabel = container:Add("DLabel")
	classLabel:Dock(TOP)
	classLabel:SetText("Weapon Class")
	classLabel:DockMargin(0, 0, 0, 4)

	local classCombo = container:Add("DComboBox")
	classCombo:Dock(TOP)
	classCombo:DockMargin(0, 0, 0, 10)
	classCombo:SetSortItems(false)

	local boneLabel = container:Add("DLabel")
	boneLabel:Dock(TOP)
	boneLabel:SetText("Bone Name")
	boneLabel:DockMargin(0, 0, 0, 4)

	local boneEntry = container:Add("DTextEntry")
	boneEntry:Dock(TOP)
	boneEntry:DockMargin(0, 0, 0, 10)

	local controls = {}
	local updatingControls = false
	local selectedClass = nil

	local function createSlider(name, minValue, maxValue, decimals)
		local slider = container:Add("DNumSlider")
		slider:Dock(TOP)
		slider:DockMargin(0, 0, 0, 4)
		slider:SetText(name)
		slider:SetMin(minValue)
		slider:SetMax(maxValue)
		slider:SetDecimals(decimals or 2)
		return slider
	end

	controls.posX = createSlider("Pos X", -40, 40, 2)
	controls.posY = createSlider("Pos Y", -40, 40, 2)
	controls.posZ = createSlider("Pos Z", -40, 40, 2)
	controls.angP = createSlider("Pitch", -180, 180, 2)
	controls.angY = createSlider("Yaw", -180, 180, 2)
	controls.angR = createSlider("Roll", -180, 180, 2)

	local buttonPanel = container:Add("DPanel")
	buttonPanel:Dock(TOP)
	buttonPanel:DockMargin(0, 8, 0, 0)
	buttonPanel:SetTall(80)
	buttonPanel.Paint = nil

	local saveSelectedButton = buttonPanel:Add("DButton")
	saveSelectedButton:SetText("Print Selected")
	saveSelectedButton:SetSize(160, 28)
	saveSelectedButton:SetPos(0, 0)

	local printAllButton = buttonPanel:Add("DButton")
	printAllButton:SetText("Print All")
	printAllButton:SetSize(160, 28)
	printAllButton:SetPos(170, 0)

	local copyAllButton = buttonPanel:Add("DButton")
	copyAllButton:SetText("Copy All")
	copyAllButton:SetSize(160, 28)
	copyAllButton:SetPos(340, 0)

	local resetButton = buttonPanel:Add("DButton")
	resetButton:SetText("Reset Selected To Default")
	resetButton:SetSize(500, 28)
	resetButton:SetPos(0, 38)

	local function writeCurrentSelection()
		if (updatingControls or not selectedClass or selectedClass == "") then
			return
		end

		ARCCW_HOLSTER_DRAWINFO[selectedClass] = {
			pos = Vector(
				controls.posX:GetValue(),
				controls.posY:GetValue(),
				controls.posZ:GetValue()
			),
			ang = Angle(
				controls.angP:GetValue(),
				controls.angY:GetValue(),
				controls.angR:GetValue()
			),
			bone = string.Trim(boneEntry:GetValue() or "") ~= ""
				and boneEntry:GetValue()
				or DEFAULT_ARCCW_DRAW.bone
		}
	end

	local function loadSelection(class)
		selectedClass = string.lower(tostring(class or ""))
		if (selectedClass == "") then
			return
		end

		local drawInfo = cloneDrawInfo(ARCCW_HOLSTER_DRAWINFO[selectedClass])
		ARCCW_HOLSTER_DRAWINFO[selectedClass] = drawInfo

		updatingControls = true
		controls.posX:SetValue(drawInfo.pos.x)
		controls.posY:SetValue(drawInfo.pos.y)
		controls.posZ:SetValue(drawInfo.pos.z)
		controls.angP:SetValue(drawInfo.ang.p)
		controls.angY:SetValue(drawInfo.ang.y)
		controls.angR:SetValue(drawInfo.ang.r)
		boneEntry:SetValue(drawInfo.bone)
		updatingControls = false
	end

	for _, slider in pairs(controls) do
		slider.OnValueChanged = writeCurrentSelection
	end

	boneEntry.OnValueChange = writeCurrentSelection

	classCombo.OnSelect = function(panel, index, value)
		loadSelection(value)
	end

	saveSelectedButton.DoClick = function()
		if (not selectedClass or selectedClass == "") then
			chat.AddText(Color(255, 80, 80), "[ArcCW Holster] Select a weapon class first.")
			return
		end

		writeCurrentSelection()
		local drawInfo = ARCCW_HOLSTER_DRAWINFO[selectedClass]
		local line = buildOffsetLine(selectedClass, drawInfo)
		print(line)
		chat.AddText(Color(120, 255, 120), "[ArcCW Holster] Printed selected offset to console.")
	end

	printAllButton.DoClick = function()
		writeCurrentSelection()
		local output = buildAllOffsetExport()
		print(output)
		chat.AddText(Color(120, 255, 120), "[ArcCW Holster] Printed all offsets to console.")
	end

	copyAllButton.DoClick = function()
		writeCurrentSelection()
		local output = buildAllOffsetExport()
		SetClipboardText(output)
		chat.AddText(Color(120, 255, 120), "[ArcCW Holster] Copied all offsets to clipboard.")
	end

	resetButton.DoClick = function()
		if (not selectedClass or selectedClass == "") then
			return
		end

		ARCCW_HOLSTER_DRAWINFO[selectedClass] = cloneDrawInfo(DEFAULT_ARCCW_DRAW)
		loadSelection(selectedClass)
		chat.AddText(Color(180, 220, 255), "[ArcCW Holster] Reset " .. selectedClass .. " to default.")
	end

	local classes = getSortedWeaponClasses()
	for _, class in ipairs(classes) do
		classCombo:AddChoice(class)
	end

	if (#classes > 0) then
		classCombo:ChooseOption(classes[1], 1)
		loadSelection(classes[1])
	end
end

concommand.Add("nut_arccw_holster_editor", openHolsterEditor)
concommand.Add("nut_arccw_holster_print", function()
	local output = buildAllOffsetExport()
	print(output)
	chat.AddText(Color(120, 255, 120), "[ArcCW Holster] Printed all offsets to console.")
end)

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

local function getArcCWWorldModel(weapon)
	if (not IsValid(weapon)) then
		return nil
	end

	-- Check common ArcCW model properties
	local model = weapon.WorldModel or weapon.WorldModelOffset or weapon.Model or nil

	if (not model or model == "") then
		-- Try to get from weapon table
		model = weapon:GetClass() and scripted_ents.GetStored(weapon:GetClass()) or nil
		if (model) then
			model = model.t.WorldModel or model.t.Model or nil
		end
	end

	return model
end

function PLUGIN:PostPlayerDraw(client)
	if (not nut.config.get("showHolsteredArccw")) then return end
	if (not client:getChar()) then return end
	if (client == LocalPlayer() and not client:ShouldDrawLocalPlayer()) then
		return
	end

	local wep = client:GetActiveWeapon()
	local curClass = ((wep and wep:IsValid()) and wep:GetClass():lower() or "")

	client.holsteredArccwWeapons = client.holsteredArccwWeapons or {}

	-- Clean up old, invalid holstered weapon models.
	for k, v in pairs(client.holsteredArccwWeapons) do
		local weapon = client:GetWeapon(k)
		if (not IsValid(weapon)) then
			v:Remove()
			client.holsteredArccwWeapons[k] = nil
		end
	end

	-- Create holstered models for each ArcCW weapon.
	for k, v in ipairs(client:GetWeapons()) do
		if (not isArcCWWeapon(v)) then continue end

		local class = v:GetClass():lower()
		local drawInfo = ARCCW_HOLSTER_DRAWINFO[class] or DEFAULT_ARCCW_DRAW
		local worldModel = getArcCWWorldModel(v)

		if (not worldModel or worldModel == "") then continue end

		if (not IsValid(client.holsteredArccwWeapons[class])) then
			local model = ClientsideModel(worldModel, RENDERGROUP_TRANSLUCENT)
			model:SetNoDraw(true)
			client.holsteredArccwWeapons[class] = model
		end

		local drawModel = client.holsteredArccwWeapons[class]
		local boneIndex = client:LookupBone(drawInfo.bone)

		if (not boneIndex or boneIndex < 0) then continue end
		local bonePos, boneAng = client:GetBonePosition(boneIndex)

		if (curClass ~= class and IsValid(drawModel)) then
			local right = boneAng:Right()
			local up = boneAng:Up()
			local forward = boneAng:Forward()
			local angPitch = drawInfo.ang[1] + holsterPitch:GetFloat()
			local angYaw = drawInfo.ang[2] + holsterYaw:GetFloat()
			local angRoll = drawInfo.ang[3] + holsterRoll:GetFloat()
			local posX = drawInfo.pos[1] + holsterOffsetX:GetFloat()
			local posY = drawInfo.pos[2] + holsterOffsetY:GetFloat()
			local posZ = drawInfo.pos[3] + holsterOffsetZ:GetFloat()

			boneAng:RotateAroundAxis(right, angPitch)
			boneAng:RotateAroundAxis(up, angYaw)
			boneAng:RotateAroundAxis(forward, angRoll)

			bonePos = bonePos
				+ posX * right
				+ posY * forward
				+ posZ * up

			drawModel:SetRenderOrigin(bonePos)
			drawModel:SetRenderAngles(boneAng)
			drawModel:DrawModel()
		end
	end
end

function PLUGIN:EntityRemoved(entity)
	if (entity.holsteredArccwWeapons) then
		for k, v in pairs(entity.holsteredArccwWeapons) do
			v:Remove()
		end
	end
end

-- Cleanup on load
for k, v in ipairs(player.GetAll()) do
	for k2, v2 in ipairs(v.holsteredArccwWeapons or {}) do
		v2:Remove()
	end
	v.holsteredArccwWeapons = nil
end
