local PLUGIN = PLUGIN
PLUGIN.name = "Spawn Points"
PLUGIN.author = "Copilot"
PLUGIN.desc = "Allows admins to place randomized player spawn points."

ALWAYS_RAISED = ALWAYS_RAISED or {}
ALWAYS_RAISED["nut_spawnhelper"] = true

nut = nut or {}
nut.spawnpoints = nut.spawnpoints or {}

if (SERVER) then
	local function getDataPath()
		return "nut_spawnpoints/" .. game.GetMap() .. ".txt"
	end

	local function loadPoints()
		local path = getDataPath()
		if (not file.Exists(path, "DATA")) then return {} end
		local ok, tbl = pcall(util.JSONToTable, file.Read(path, "DATA"))
		return (ok and tbl) or {}
	end

	local function savePoints(points)
		if (not file.Exists("nut_spawnpoints", "DATA")) then
			file.CreateDir("nut_spawnpoints")
		end
		file.Write(getDataPath(), util.TableToJSON(points, true))
	end

	function nut.spawnpoints.add(pos, ang)
		local points = loadPoints()
		points[#points + 1] = {
			pos = {pos.x, pos.y, pos.z},
			ang = {ang.p, ang.y, ang.r}
		}
		savePoints(points)
		return #points
	end

	function nut.spawnpoints.removeNearest(pos, radius)
		radius = radius or 100
		local points = loadPoints()
		local nearestIdx, nearestDist = nil, radius
		for i, p in ipairs(points) do
			local d = pos:Distance(Vector(p.pos[1], p.pos[2], p.pos[3]))
			if (d < nearestDist) then
				nearestIdx, nearestDist = i, d
			end
		end
		if (nearestIdx) then
			table.remove(points, nearestIdx)
			savePoints(points)
			return true, #points
		end
		return false, #points
	end

	function nut.spawnpoints.clearAll()
		savePoints({})
	end

	function nut.spawnpoints.getAll()
		local points = loadPoints()
		local result = {}
		for _, p in ipairs(points) do
			result[#result + 1] = {
				pos = Vector(p.pos[1], p.pos[2], p.pos[3]),
				ang = Angle(p.ang[1], p.ang[2], p.ang[3])
			}
		end
		return result
	end

	function nut.spawnpoints.getRandom()
		local all = nut.spawnpoints.getAll()
		if (#all == 0) then return nil end
		return all[math.random(1, #all)]
	end

	function PLUGIN:PostPlayerLoadout(client)
		if (not IsValid(client) or not client:getChar()) then
			return
		end

		local spawnData = nut.spawnpoints.getRandom()
		if (not spawnData or not spawnData.pos) then
			return
		end

		-- Delay one tick so this wins over engine/default spawn entities.
		timer.Simple(0, function()
			if (not IsValid(client) or not client:Alive()) then
				return
			end

			client:SetPos(spawnData.pos)
			if (spawnData.ang) then
				client:SetEyeAngles(spawnData.ang)
			end
		end)
	end

	util.AddNetworkString("nut_spawnpoints_fetch")
	util.AddNetworkString("nut_spawnpoints_data")

	net.Receive("nut_spawnpoints_fetch", function(len, client)
		local all = nut.spawnpoints.getAll()
		net.Start("nut_spawnpoints_data")
		net.WriteUInt(#all, 16)
		for _, p in ipairs(all) do
			net.WriteVector(p.pos)
		end
		net.Send(client)
	end)
end
