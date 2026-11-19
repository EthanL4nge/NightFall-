-- Caves: zombie nests that are ALWAYS active (day and night) whenever a player is nearby.
-- Each cave keeps a few zombies alive inside, refilling every few seconds, and the zombies are
-- tougher than the night's roamers. Inside: rich ore and boosted chests - risk vs reward.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS:WaitForChild("Config"))

local Util = require(script.Parent.Util)
local Zombies = require(script.Parent.Zombies)

local Caves = {}
Caves.list = {}

local rng = Random.new()
local ACTIVE_RANGE = 240 -- caves only simulate when a player is within this many studs

function Caves.register(cave)
	cave.nextSpawn = 0
	table.insert(Caves.list, cave)
end

-- new run: every cave needs clearing again
function Caves.resetAll()
	for _, c in Caves.list do
		if c.reset then
			c.reset()
		end
	end
end

function Caves.step()
	local night = workspace:GetAttribute("Night") or 1
	local now = os.clock()
	local positions = {}
	for _, p in Players:GetPlayers() do
		local hum, root = Util.aliveHumanoid(p)
		if hum then
			table.insert(positions, root.Position)
		end
	end

	for _, c in Caves.list do
		local near = false
		for _, pos in positions do
			local dx, dz = pos.X - c.x, pos.Z - c.z
			if dx * dx + dz * dz < ACTIVE_RANGE * ACTIVE_RANGE then
				near = true
				break
			end
		end

		-- a short grace period when you first walk into range, so the cave doesn't pounce instantly
		if near and not c.wasNear then
			c.nextSpawn = math.max(c.nextSpawn or 0, now + Config.CaveFirstSpawnDelay)
		end
		c.wasNear = near

		local count = 0
		for _, z in Zombies.list do
			if z.home == c then
				count += 1
				if not near then
					z.noDrop = true
					z.hum.Health = 0 -- nobody around: tidy up
				end
			end
		end

		if near and count < c.max and now >= c.nextSpawn then
			c.nextSpawn = now + Config.CaveRespawnDelay
			local x = c.x + rng:NextNumber(-c.half + 4, c.half - 4)
			local z = c.z + rng:NextNumber(-c.half + 4, c.half - 4)
			local typeName = Zombies.pickType(night + 2)
			local def = Config.Zombies[typeName]
			local model = Zombies.spawn(typeName, Vector3.new(x, c.floorY + 3 * def.scale + 1, z), night + 1 + (c.danger or 0))
			local state = Zombies.list[model]
			if state then
				state.home = c
			end
		end
	end
end

return Caves
