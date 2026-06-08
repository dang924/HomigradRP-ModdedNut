PLUGIN.name = "Character ID Tools"
PLUGIN.author = "GitHub Copilot"
PLUGIN.desc = "Adds commands to show or copy NutScript character IDs."

local NET_COPY_CHAR_ID = "nutCharIDCopy"

if (SERVER) then
	util.AddNetworkString(NET_COPY_CHAR_ID)
end

local function getCharacterID(client)
	if (not IsValid(client) or not client.getChar) then return nil end

	local character = client:getChar()
 	if (not character or not character.getID) then return nil end

	local charID = tonumber(character:getID())
	if (not charID) then return nil end

	return charID, character
end

nut.command.add("myid", {
	syntax = "",
	onRun = function(client)
		local charID = getCharacterID(client)
		if (not charID) then
			return client:notify("You do not have an active character ID.")
		end

		client:notify("Your character ID is #" .. charID .. ".")
	end
})

nut.command.add("copyid", {
	syntax = "",
	onRun = function(client)
		if (not IsValid(client)) then return end

		local trace = client:GetEyeTraceNoCursor()
		local target = IsValid(trace.Entity) and trace.Entity or nil
		if (not IsValid(target) or not target:IsPlayer()) then
			return client:notify("Aim at a player to copy their character ID.")
		end

		local charID = getCharacterID(target)
		if (not charID) then
			return client:notify("That player does not have an active character ID.")
		end

		net.Start(NET_COPY_CHAR_ID)
			net.WriteUInt(charID, 32)
			net.WriteString(target:Name())
		net.Send(client)

		client:notify("Copied " .. target:Name() .. "'s character ID (#" .. charID .. ") to your clipboard.")
	end
})

if (CLIENT) then
	net.Receive(NET_COPY_CHAR_ID, function()
		local charID = net.ReadUInt(32)
		local name = net.ReadString()

		SetClipboardText(tostring(charID))
		LocalPlayer():notify("Copied " .. name .. "'s character ID (#" .. charID .. ") to your clipboard.")
	end)
end