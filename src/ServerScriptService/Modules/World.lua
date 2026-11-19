-- Generates the 3600 x 3600 map: 5 regions (see Regions.lua), a CITY, bigger TOWNS, RURAL towns with
-- farms, stepped mountains, lookout towers, ruins, zombie CAVES, and region-exclusive resources.
-- Everything is built from blocky parts, no assets. Fixed seed = same world each server.
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS:WaitForChild("Config"))
local Regions = require(RS:WaitForChild("Regions"))
local Remotes = require(script.Parent.Remotes)
local Util = require(script.Parent.Util)
local Inventory = require(script.Parent.Inventory)
local Loot = require(script.Parent.Loot)
local Caves = require(script.Parent.Caves)

local World = {}

local rng = Random.new(2026)
local nodes = Util.folder("Nodes")
local landmarks = {} -- recorded as places are built, used for the lobby scale model
local function mark(kind, x, z, size)
	table.insert(landmarks, { kind = kind, x = x, z = z, size = size })
end
local blocked = {} -- {x, z, radius}: footprints so trees/ore don't spawn inside buildings
local made = 0
local C3 = Color3.fromRGB
local M = Enum.Material

-- Resource nodes ------------------------------------------------------------------------------
-- hold = seconds holding E (slow on purpose). Yield = random min..max x node richness, +lucky 2x.
-- tier = pickaxe tier needed (0 hands, 1 wood, 2 stone, 3 iron, 4 diamond).
local NODE = {
	Tree = { label = "Tree", action = "Chop", res = "Wood", min = 3, max = 9, hold = 2.5, tier = 0, respawn = 90 },
	Stone = { label = "Stone", action = "Mine", res = "Stone", min = 2, max = 8, hold = 3.5, tier = 1, respawn = 100,
		rock = C3(125, 125, 130), speck = C3(95, 95, 100) },
	Iron = { label = "Iron Ore", action = "Mine", res = "Iron", min = 1, max = 5, hold = 5, tier = 2, respawn = 130,
		rock = C3(125, 125, 130), speck = C3(225, 160, 110) },
	Gold = { label = "Gold Ore", action = "Mine", res = "Gold", min = 1, max = 4, hold = 5, tier = 2, respawn = 140,
		rock = C3(150, 135, 105), speck = C3(255, 210, 60) },
	Crystal = { label = "Frost Crystal", action = "Mine", res = "Crystal", min = 1, max = 4, hold = 5, tier = 2, respawn = 140,
		rock = C3(150, 175, 200), speck = C3(170, 235, 255) },
	Diamond = { label = "Diamond Ore", action = "Mine", res = "Diamond", min = 1, max = 3, hold = 7, tier = 3, respawn = 180,
		rock = C3(100, 100, 108), speck = C3(70, 230, 240) },
	Obsidian = { label = "Obsidian", action = "Mine", res = "Obsidian", min = 1, max = 3, hold = 9, tier = 4, respawn = 200,
		rock = C3(35, 25, 50), speck = C3(150, 80, 215) },
}
local NEON_SPECK = { Diamond = true, Crystal = true, Obsidian = true, Gold = true }
local LUCKY_CHANCE = 0.08

-- what grows/spawns where
local TREE = {
	Greenfields = { kind = "tree", trunk = C3(110, 75, 40), leaf = C3(55, 125, 55), scale = 1, yield = 1, count = 260 },
	Darkwood = { kind = "tree", trunk = C3(60, 40, 30), leaf = C3(25, 75, 40), scale = 1.25, yield = 1.5, count = 560 },
	Frostlands = { kind = "tree", trunk = C3(90, 70, 55), leaf = C3(70, 110, 90), snow = true, scale = 1, yield = 0.8, count = 130 },
	Desert = { kind = "cactus", trunk = C3(70, 140, 70), scale = 1, yield = 0.45, count = 90 },
	Ashlands = { kind = "dead", trunk = C3(30, 26, 28), scale = 1, yield = 0.6, count = 60 },
}
local ORE = {
	Greenfields = { Stone = 90 },
	Darkwood = { Stone = 60 },
	Frostlands = { Stone = 40, Iron = 90, Crystal = 45 },
	Desert = { Stone = 40, Gold = 70 },
	Ashlands = { Stone = 30, Diamond = 45, Obsidian = 30 },
}
local MOUNTAIN = { -- count, ore kinds on the ledges, layer colors
	Greenfields = { count = 2, ores = { "Stone", "Stone", "Stone" }, low = C3(92, 110, 80), high = C3(125, 125, 130), snow = false, mat = M.Rock },
	Darkwood = { count = 3, ores = { "Stone", "Stone" }, low = C3(50, 70, 55), high = C3(95, 100, 100), snow = false, mat = M.Rock },
	Frostlands = { count = 4, ores = { "Iron", "Crystal", "Iron", "Stone" }, low = C3(130, 140, 150), high = C3(235, 240, 246), snow = true, mat = M.Rock },
	Desert = { count = 3, ores = { "Gold", "Gold", "Stone" }, low = C3(190, 140, 90), high = C3(220, 180, 120), snow = false, mat = M.Sandstone },
	Ashlands = { count = 4, ores = { "Diamond", "Obsidian", "Stone" }, low = C3(55, 48, 55), high = C3(90, 40, 35), snow = false, mat = M.Basalt },
}
local CAVE_COUNT = { Greenfields = 2, Darkwood = 2, Frostlands = 2, Desert = 2, Ashlands = 2 }
local CAVE_ORE = {
	Greenfields = { "Stone", "Stone" }, Darkwood = { "Stone", "Stone" }, Frostlands = { "Iron", "Crystal" },
	Desert = { "Gold", "Gold" }, Ashlands = { "Diamond", "Obsidian" },
}
local BSTYLE = { -- house look per region
	Greenfields = { wall = C3(175, 135, 85), wmat = M.WoodPlanks, roof = C3(150, 62, 48), rmat = M.Brick, steps = 3 },
	Darkwood = { wall = C3(100, 70, 45), wmat = M.WoodPlanks, roof = C3(45, 70, 50), rmat = M.Slate, steps = 3 },
	Frostlands = { wall = C3(150, 120, 90), wmat = M.WoodPlanks, roof = C3(240, 245, 250), rmat = M.Snow, steps = 3 },
	Desert = { wall = C3(214, 188, 140), wmat = M.Sandstone, roof = C3(196, 165, 110), rmat = M.Sandstone, steps = 1 },
	Ashlands = { wall = C3(65, 58, 64), wmat = M.Basalt, roof = C3(40, 34, 40), rmat = M.Slate, steps = 2 },
}
local CITY_STYLE = { wall = C3(168, 168, 175), wmat = M.Concrete, roof = C3(78, 78, 86), rmat = M.Concrete, steps = 1 }

-- helpers ---------------------------------------------------------------------------------------
-- every part goes through mk; it yields now and then so a huge map can't hit the script time limit
local function mk(props, parent)
	made += 1
	if made % 150 == 0 then
		task.wait()
	end
	local p = Instance.new(props.Class or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "Class" then
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function glow(part, range, brightness, color)
	local l = Instance.new("PointLight")
	l.Range = range
	l.Brightness = brightness
	l.Color = color or C3(255, 200, 120)
	l.Parent = part
end

local function block(x, z, r)
	table.insert(blocked, { x, z, r })
end

local function isFree(x, z, pad)
	for _, b in blocked do
		local dx, dz = x - b[1], z - b[2]
		local rr = b[3] + pad
		if dx * dx + dz * dz < rr * rr then
			return false
		end
	end
	return true
end

-- random free point, optionally inside one region, at least minR from spawn
local function freeSpot(pad, region, minR)
	local half = Config.MapHalf - 40
	for _ = 1, 80 do
		local x, z = rng:NextNumber(-half, half), rng:NextNumber(-half, half)
		if (not region or Regions.at(x, z) == region) and (x * x + z * z >= (minR or 0) ^ 2) and isFree(x, z, pad) then
			return x, z
		end
	end
	return nil
end

local function richness()
	local rich = rng:NextNumber(0.5, 1.8)
	return rich, 0.8 + (rich - 0.5) / 1.3 * 0.75 -- node size 0.8x (poor) .. 1.55x (rich)
end

local function attachNode(model, part, kind, rich)
	local def = NODE[kind]
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = def.label
	prompt.ActionText = def.action
	prompt.HoldDuration = def.hold
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	local busy = false
	prompt.Triggered:Connect(function(player)
		if busy then
			return
		end
		local tier = player:GetAttribute("PickTier") or 0
		if tier < def.tier then
			Remotes.Notify:FireClient(player, "Need a " .. Config.PickNames[def.tier] .. " Pickaxe (press C)", C3(255, 120, 120))
			return
		end
		busy = true
		local amount = math.max(1, math.floor(rng:NextInteger(def.min, def.max) * rich + 0.5)) + math.max(0, tier - def.tier)
		local lucky = rng:NextNumber() < LUCKY_CHANCE
		if lucky then
			amount *= 2
		end
		Inventory.add(player, def.res, amount)
		Remotes.Notify:FireClient(player, (lucky and "LUCKY!  " or "") .. "+" .. amount .. " " .. Config.Items[def.res].name,
			lucky and C3(255, 230, 90) or Config.Items[def.res].color)
		model.Parent = nil
		task.delay(def.respawn, function()
			model.Parent = nodes
			busy = false
		end)
	end)
end

local function makeTree(x, z, region)
	local ts = TREE[region]
	local rich, s = richness()
	s *= ts.scale
	local model = Instance.new("Model")
	model.Name = ts.kind == "cactus" and "Cactus" or "Tree"
	local trunk
	if ts.kind == "cactus" then
		trunk = mk({ Name = "Trunk", Size = Vector3.new(2.2 * s, 9 * s, 2.2 * s), CFrame = CFrame.new(x, 4.5 * s, z), Color = ts.trunk, Material = M.Grass }, model)
		mk({ Name = "ArmH", Size = Vector3.new(3.4 * s, 1.5 * s, 1.5 * s), CFrame = CFrame.new(x + 2.6 * s, 5 * s, z), Color = ts.trunk, Material = M.Grass }, model)
		mk({ Name = "ArmV", Size = Vector3.new(1.5 * s, 3.5 * s, 1.5 * s), CFrame = CFrame.new(x + 4.1 * s, 6.5 * s, z), Color = ts.trunk, Material = M.Grass }, model)
	elseif ts.kind == "dead" then
		trunk = mk({ Name = "Trunk", Size = Vector3.new(1.7 * s, 9 * s, 1.7 * s), CFrame = CFrame.new(x, 4.5 * s, z), Color = ts.trunk, Material = M.Wood }, model)
		mk({ Name = "Branch", Size = Vector3.new(4 * s, 0.8 * s, 0.8 * s), CFrame = CFrame.new(x + 2 * s, 7 * s, z) * CFrame.Angles(0, 0, 0.5), Color = ts.trunk, Material = M.Wood }, model)
		mk({ Name = "Branch", Size = Vector3.new(0.8 * s, 0.8 * s, 3.4 * s), CFrame = CFrame.new(x, 5.5 * s, z - 1.7 * s) * CFrame.Angles(0.5, 0, 0), Color = ts.trunk, Material = M.Wood }, model)
	else
		trunk = mk({ Name = "Trunk", Size = Vector3.new(2 * s, 10 * s, 2 * s), CFrame = CFrame.new(x, 5 * s, z), Color = ts.trunk, Material = M.Wood }, model)
		mk({ Name = "Leaves", Size = Vector3.new(9 * s, 6 * s, 9 * s), CFrame = CFrame.new(x, 12 * s, z), Color = ts.leaf, Material = M.Grass }, model)
		mk({ Name = "Top", Size = Vector3.new(5 * s, 4 * s, 5 * s), CFrame = CFrame.new(x, 16 * s, z), Color = ts.leaf, Material = M.Grass }, model)
		if ts.snow then
			mk({ Name = "Snow", Size = Vector3.new(9.4 * s, 1 * s, 9.4 * s), CFrame = CFrame.new(x, 15.2 * s, z), Color = C3(245, 248, 252), Material = M.Snow }, model)
		end
	end
	model.PrimaryPart = trunk
	attachNode(model, trunk, "Tree", rich * ts.yield)
	model.Parent = nodes
end

local function makeOre(kind, x, z, baseY)
	baseY = baseY or 0
	local def = NODE[kind]
	local rich, s = richness()
	local model = Instance.new("Model")
	model.Name = def.label
	local rock = mk({ Name = "Rock", Size = Vector3.new(5 * s, 4 * s, 5 * s),
		CFrame = CFrame.new(x, baseY + 2 * s, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
		Color = def.rock, Material = M.Slate }, model)
	if kind ~= "Stone" then
		for i = 1, 5 do
			local onX = i % 2 == 0
			local off = (rng:NextInteger(0, 1) == 0 and -1 or 1) * 2.4 * s
			local offset = onX and Vector3.new(off, rng:NextNumber(-1.2, 1.5) * s, rng:NextNumber(-1.6, 1.6) * s)
				or Vector3.new(rng:NextNumber(-1.6, 1.6) * s, rng:NextNumber(-1.2, 1.5) * s, off)
			mk({ Name = "Speck", Size = Vector3.new(1.3, 1.3, 1.3) * s, CFrame = rock.CFrame * CFrame.new(offset),
				Color = def.speck, Material = NEON_SPECK[kind] and M.Neon or M.SmoothPlastic, CanCollide = false }, model)
		end
	end
	model.PrimaryPart = rock
	attachNode(model, rock, kind, rich)
	model.Parent = nodes
end

-- Mountains: stepped 5-stud layers you can jump up like stairs; the region's ore sits on the ledges.
local function makeMountain(cx, cz, w, region)
	mark("mountain", cx, cz, w)
	local st = MOUNTAIN[region]
	local model = Instance.new("Model")
	model.Name = "Mountain"
	local layers = rng:NextInteger(5, 8)
	local layerH = 5
	local curW, curD = w, w * rng:NextNumber(0.85, 1.2)
	local ox, oz = 0, 0
	local ledges = {}
	for i = 1, layers do
		local snow = st.snow and i > layers - 2
		local color = snow and C3(236, 241, 246) or st.low:Lerp(st.high, (i - 1) / layers)
		mk({ Name = "Layer", Size = Vector3.new(curW, layerH, curD), CFrame = CFrame.new(cx + ox, (i - 1) * layerH + layerH / 2, cz + oz),
			Color = color, Material = snow and M.Snow or st.mat }, model)
		table.insert(ledges, { x = cx + ox, z = cz + oz, w = curW, d = curD, top = i * layerH })
		curW *= 0.78
		curD *= 0.78
		ox += rng:NextNumber(-curW * 0.1, curW * 0.1)
		oz += rng:NextNumber(-curD * 0.1, curD * 0.1)
	end
	model.Parent = workspace
	block(cx, cz, w * 0.7)

	for i = 2, layers - 1 do
		for _ = 1, 2 do
			local kind = st.ores[rng:NextInteger(1, #st.ores)]
			-- the best ore (last in the list) only on the upper ledges
			if kind ~= "Stone" and kind ~= st.ores[1] and i < layers - 2 then
				kind = "Stone"
			end
			local l = ledges[i]
			local side = rng:NextInteger(0, 1) == 0 and -1 or 1
			local px, pz
			if rng:NextInteger(0, 1) == 0 then
				px, pz = side * (l.w / 2 - 3.2), rng:NextNumber(-l.d * 0.3, l.d * 0.3)
			else
				px, pz = rng:NextNumber(-l.w * 0.3, l.w * 0.3), side * (l.d / 2 - 3.2)
			end
			makeOre(kind, l.x + px, l.z + pz, l.top)
		end
	end
end

-- Buildings ------------------------------------------------------------------------------------
-- One generic enterable building: walls with a door + windows, corner posts, roof, furniture, lamp, chests.
local function makeBuilding(parent, cx, cz, yaw, o)
	local W, D, H = o.W, o.D, o.H
	local st = o.style
	local model = Instance.new("Model")
	model.Name = o.name or "House"
	local base = CFrame.new(cx, 0, cz) * CFrame.Angles(0, yaw, 0)

	local function part(name, size, pos, color, mat, props)
		local p = mk({ Name = name, Size = size, CFrame = base * CFrame.new(pos), Color = color, Material = mat }, model)
		if props then
			for k, v in props do
				p[k] = v
			end
		end
		return p
	end
	part("Floor", Vector3.new(W, 1, D), Vector3.new(0, 0.5, 0), C3(140, 105, 65), M.WoodPlanks)

	-- wall along local X or Z at coordinate `fixed`, optional hole (door/window)
	local function wallLine(axis, fixed, len, hole)
		local function seg(a0, a1, y0, y1)
			if a1 - a0 < 0.05 or y1 - y0 < 0.05 then
				return
			end
			local la, ly = a1 - a0, y1 - y0
			local ca, cy = (a0 + a1) / 2, 1 + (y0 + y1) / 2
			local size = axis == "x" and Vector3.new(la, ly, 1) or Vector3.new(1, ly, la)
			local pos = axis == "x" and Vector3.new(ca, cy, fixed) or Vector3.new(fixed, cy, ca)
			part("Wall", size, pos, st.wall, st.wmat)
		end
		if not hole then
			seg(-len / 2, len / 2, 0, H)
			return
		end
		local hl, hr = hole.c - hole.w / 2, hole.c + hole.w / 2
		seg(-len / 2, hl, 0, H)
		seg(hr, len / 2, 0, H)
		seg(hl, hr, 0, hole.bottom)
		seg(hl, hr, hole.top, H)
	end
	local winTop = math.min(6.5, H - 1.5)
	wallLine("x", D / 2 - 0.5, W, { c = 0, w = o.doorW or 5, bottom = 0, top = math.min(7, H - 2) }) -- front (+Z) with door
	wallLine("x", -D / 2 + 0.5, W, { c = 0, w = 5, bottom = 3, top = winTop })
	wallLine("z", W / 2 - 0.5, D, { c = 0, w = 4, bottom = 3, top = winTop })
	wallLine("z", -W / 2 + 0.5, D, { c = 0, w = 4, bottom = 3, top = winTop })

	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		part("Post", Vector3.new(1.4, H, 1.4), Vector3.new(c[1] * (W / 2 - 0.2), 1 + H / 2, c[2] * (D / 2 - 0.2)), st.wall:Lerp(C3(40, 28, 20), 0.5), M.Wood)
	end
	for k = 1, st.steps do
		local sw, sd = W + 2 - (k - 1) * 4, D + 2 - (k - 1) * 4
		if sw > 3 and sd > 3 then
			part("Roof" .. k, Vector3.new(sw, 1, sd), Vector3.new(0, H + k - 0.5, 0), st.roof, st.rmat)
		end
	end

	if W >= 14 then
		part("Table", Vector3.new(3, 1.2, 2), Vector3.new(-W / 2 + 4, 1.6, 1), C3(120, 78, 42), M.Wood)
		part("Bed", Vector3.new(3, 0.9, 6), Vector3.new(W / 2 - 3.5, 1.45, 0), C3(170, 50, 50), M.Fabric)
		part("Pillow", Vector3.new(2, 0.4, 1.2), Vector3.new(W / 2 - 3.5, 2.1, -2.2), C3(240, 240, 240), M.Fabric)
	end
	local lamp = part("Lamp", Vector3.new(1, 1, 1), Vector3.new(0, H, 0), C3(255, 220, 140), M.Neon, { CanCollide = false })
	glow(lamp, 22 + W / 2, 1.3)

	model.Parent = parent
	block(cx, cz, math.max(W, D) * 0.75)

	local xs = { -W / 2 + 4.5, W / 2 - 4.5, 0 }
	for i = 1, o.chests or 0 do
		Loot.createChest(base * CFrame.new(xs[i], 1, -D / 2 + 2.4), o.boost)
	end
	return model
end

local function houseOpts(region, extra)
	local o = { W = 16, D = 14, H = 9, style = BSTYLE[region], chests = rng:NextNumber() < 0.18 and 1 or 0, boost = 0 }
	if extra then
		for k, v in extra do
			o[k] = v
		end
	end
	return o
end

local function lampPost(parent, x, z, tall)
	tall = tall or 14
	mk({ Name = "LampPost", Size = Vector3.new(1, tall, 1), CFrame = CFrame.new(x, tall / 2, z), Color = C3(40, 40, 45), Material = M.Metal }, parent)
	local lamp = mk({ Name = "Lamp", Size = Vector3.new(2.2, 2.2, 2.2), CFrame = CFrame.new(x, tall + 1, z), Color = C3(255, 220, 140), Material = M.Neon }, parent)
	glow(lamp, 40, 1.8)
end

-- Rural town: a few houses, farm plots, hay bales, a barn and a windmill
local function makeRuralTown(vx, vz, region)
	mark("rural", vx, vz, 160)
	local town = Instance.new("Model")
	town.Name = "RuralTown"
	town.Parent = workspace
	local count = rng:NextInteger(3, 4)
	local offset = rng:NextNumber(0, math.pi * 2)
	for i = 1, count do
		local a = offset + i * (math.pi * 2 / count)
		local hx, hz = vx + math.cos(a) * 36, vz + math.sin(a) * 36
		makeBuilding(town, hx, hz, math.atan2(-math.cos(a), -math.sin(a)), houseOpts(region))
	end
	-- barn
	makeBuilding(town, vx + 1, vz - 2, rng:NextInteger(0, 3) * math.pi / 2,
		houseOpts(region, { W = 24, D = 18, H = 11, name = "Barn", style = { wall = C3(150, 50, 45), wmat = M.WoodPlanks, roof = C3(90, 40, 35), rmat = M.WoodPlanks, steps = 2 },
			doorW = 8, chests = rng:NextNumber() < 0.25 and 1 or 0 }))
	-- farm plots
	for p = 1, 2 do
		local fx = vx + (p == 1 and -62 or 62)
		local fz = vz + rng:NextNumber(-16, 16)
		mk({ Name = "Soil", Size = Vector3.new(30, 0.6, 26), CFrame = CFrame.new(fx, 0.3, fz), Color = C3(92, 62, 40), Material = M.Ground }, town)
		for r = -2, 2 do
			mk({ Name = "Crops", Size = Vector3.new(27, 1.8, 1.4), CFrame = CFrame.new(fx, 1.2, fz + r * 4.5),
				Color = (r % 2 == 0) and C3(90, 160, 60) or C3(215, 185, 70), Material = M.Grass, CanCollide = false }, town)
		end
		block(fx, fz, 22)
	end
	for _ = 1, 3 do
		mk({ Name = "Hay", Size = Vector3.new(3, 3, 3), CFrame = CFrame.new(vx + rng:NextNumber(-14, 14), 1.5, vz + rng:NextNumber(14, 24)),
			Color = C3(205, 175, 70), Material = M.Fabric }, town)
	end
	-- windmill
	local wx, wz = vx - 22, vz + 30
	mk({ Name = "MillTower", Size = Vector3.new(6, 18, 6), CFrame = CFrame.new(wx, 9, wz), Color = C3(210, 200, 185), Material = M.Concrete }, town)
	mk({ Name = "MillBladeH", Size = Vector3.new(16, 1.2, 0.5), CFrame = CFrame.new(wx, 15, wz + 3.5), Color = C3(140, 100, 60), Material = M.Wood, CanCollide = false }, town)
	mk({ Name = "MillBladeV", Size = Vector3.new(1.2, 16, 0.5), CFrame = CFrame.new(wx, 15, wz + 3.5), Color = C3(140, 100, 60), Material = M.Wood, CanCollide = false }, town)
	lampPost(town, vx, vz + 12)
	block(vx, vz, 80)
end

-- Town: a main street with houses on both sides, a plaza with a well, a town hall with loot
local function makeTown(tx, tz, region)
	mark("town", tx, tz, 230)
	local town = Instance.new("Model")
	town.Name = "Town"
	town.Parent = workspace
	local theta = rng:NextInteger(0, 3) * math.pi / 2
	local root = CFrame.new(tx, 0, tz) * CFrame.Angles(0, theta, 0)
	local function at(lx, lz, localYaw, o)
		local pos = (root * CFrame.new(lx, 0, lz)).Position
		makeBuilding(town, pos.X, pos.Z, theta + localYaw, o)
	end
	local street = root * CFrame.new(0, 0.2, 0)
	mk({ Name = "Street", Size = Vector3.new(230, 0.4, 14), CFrame = street, Color = C3(135, 120, 100), Material = M.Gravel, CanCollide = false }, town)
	for i = -3, 3 do
		if i ~= 0 then -- leave the middle open for the plaza
			at(i * 32, -30, 0, houseOpts(region))
			at(i * 32 + (i > 0 and 6 or -6), 30, math.pi, houseOpts(region))
		end
	end
	-- town hall at the end of the street, facing it
	at(-128, 0, math.pi / 2, { W = 30, D = 22, H = 13, style = BSTYLE[region], name = "TownHall", chests = 2, boost = 1, doorW = 7 })
	-- plaza well + lamps
	local wellPos = (root * CFrame.new(0, 0, 0)).Position
	mk({ Name = "Well", Size = Vector3.new(6, 3, 6), CFrame = CFrame.new(wellPos.X, 1.5, wellPos.Z), Color = C3(120, 120, 125), Material = M.Cobblestone }, town)
	mk({ Name = "Water", Size = Vector3.new(4, 0.3, 4), CFrame = CFrame.new(wellPos.X, 3.1, wellPos.Z), Color = C3(60, 120, 200), Material = M.Glass, Transparency = 0.3 }, town)
	for _, lx in { -80, -40, 40, 80 } do
		local p = (root * CFrame.new(lx, 0, 9)).Position
		lampPost(town, p.X, p.Z, 12)
	end
	block(tx, tz, 160)
end


-- Skyscraper: hollow glass tower you can walk into. Bare floors joined by ramps (zig-zag), a door on
-- the +Z side, and chests at random spots on random floors (higher floors = better loot).
local function makeSkyscraper(parent, cx, cz, w, floors, shade)
	local FH, T = 14, 2
	local I = w - 2 * T
	local ramp = { w = 8, l = 22 }
	local topY = floors * FH + 1
	local model = Instance.new("Model")
	model.Name = "Skyscraper"
	local wallColor = C3(95 * shade, 125 * shade, 155 * shade)
	local function wall(size, pos)
		mk({ Name = "Wall", Size = size, CFrame = CFrame.new(pos), Color = wallColor, Material = M.Glass, Transparency = 0.2 }, model)
	end
	local wh = topY + 3
	wall(Vector3.new(w, wh, T), Vector3.new(cx, wh / 2, cz - w / 2 + T / 2))
	wall(Vector3.new(T, wh, w - 2 * T), Vector3.new(cx + w / 2 - T / 2, wh / 2, cz))
	wall(Vector3.new(T, wh, w - 2 * T), Vector3.new(cx - w / 2 + T / 2, wh / 2, cz))
	local segW = (w - 8) / 2
	wall(Vector3.new(segW, wh, T), Vector3.new(cx - 4 - segW / 2, wh / 2, cz + w / 2 - T / 2))
	wall(Vector3.new(segW, wh, T), Vector3.new(cx + 4 + segW / 2, wh / 2, cz + w / 2 - T / 2))
	wall(Vector3.new(8, wh - 10, T), Vector3.new(cx, 10 + (wh - 10) / 2, cz + w / 2 - T / 2))
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		mk({ Name = "Corner", Size = Vector3.new(2.5, wh + 1, 2.5), CFrame = CFrame.new(cx + c[1] * w / 2, (wh + 1) / 2, cz + c[2] * w / 2),
			Color = C3(80, 82, 90), Material = M.Concrete }, model)
	end

	-- ramp k climbs from floor k-1 to floor k. odd k: west side, high end north. even k: east side, high end south... see below
	local function rampRect(k)
		if k % 2 == 1 then
			return { x0 = cx - I / 2, x1 = cx - I / 2 + ramp.w, z0 = cz + I / 2 - ramp.l, z1 = cz + I / 2, dir = Vector3.new(0, 0, -1) }
		end
		return { x0 = cx + I / 2 - ramp.w, x1 = cx + I / 2, z0 = cz - I / 2, z1 = cz - I / 2 + ramp.l, dir = Vector3.new(0, 0, 1) }
	end
	local function slab(x0, x1, z0, z1, y)
		if x1 - x0 < 0.1 or z1 - z0 < 0.1 then
			return
		end
		mk({ Name = "Floor", Size = Vector3.new(x1 - x0, 1, z1 - z0), CFrame = CFrame.new((x0 + x1) / 2, y, (z0 + z1) / 2),
			Color = C3(120, 122, 130), Material = M.Concrete }, model)
	end
	local ix0, ix1, iz0, iz1 = cx - I / 2, cx + I / 2, cz - I / 2, cz + I / 2

	for k = 1, floors do
		local y = k * FH + 0.5
		local r = rampRect(k)
		-- floor with a hole where ramp k comes up (hole touches an x edge and a z edge)
		if r.x0 <= ix0 + 0.01 then
			slab(r.x1, ix1, iz0, iz1, y)
		else
			slab(ix0, r.x0, iz0, iz1, y)
		end
		if r.z0 <= iz0 + 0.01 then
			slab(r.x0, r.x1, r.z1, iz1, y)
		else
			slab(r.x0, r.x1, iz0, r.z0, y)
		end
		-- the ramp itself, sitting on floor k-1
		local c = Vector3.new((r.x0 + r.x1) / 2, (k - 1) * FH + 1 + FH / 2, (r.z0 + r.z1) / 2)
		mk({ Name = "Ramp", Class = "WedgePart", Size = Vector3.new(ramp.w, FH, ramp.l), CFrame = CFrame.lookAt(c, c - r.dir),
			Color = C3(150, 152, 160), Material = M.Concrete }, model)
		-- ceiling light
		local lamp = mk({ Name = "Light", Size = Vector3.new(1.5, 0.5, 1.5), CFrame = CFrame.new(cx, k * FH - 0.5 - 0.2, cz), Color = C3(255, 235, 190), Material = M.Neon, CanCollide = false }, model)
		glow(lamp, 28, 0.9, C3(255, 235, 190))
	end
	local lamp0 = mk({ Name = "Light", Size = Vector3.new(1.5, 0.5, 1.5), CFrame = CFrame.new(cx, FH - 0.7, cz), Color = C3(255, 235, 190), Material = M.Neon, CanCollide = false }, model)
	glow(lamp0, 28, 0.9, C3(255, 235, 190))
	local ant = mk({ Name = "Antenna", Size = Vector3.new(0.6, 14, 0.6), CFrame = CFrame.new(cx, wh + 7, cz), Color = C3(255, 60, 60), Material = M.Neon, CanCollide = false }, model)
	glow(ant, 30, 1.2, C3(255, 70, 70))
	model.Parent = parent

	-- chests: ground + roof always, other floors ~55%; random spot each, away from ramps
	local function chestOn(k, boost)
		local top = k == 0 and 0.7 or (k * FH + 1)
		for _ = 1, 12 do
			local x = rng:NextNumber(ix0 + 2.5, ix1 - 2.5)
			local z = rng:NextNumber(iz0 + 2.5, iz1 - 2.5)
			local ok = true
			for _, kk in { k, k + 1 } do
				if kk >= 1 and kk <= floors then
					local r = rampRect(kk)
					if x > r.x0 - 3 and x < r.x1 + 3 and z > r.z0 - 3 and z < r.z1 + 3 then
						ok = false
					end
				end
			end
			if k == 0 and math.abs(x - cx) < 6 and z > iz1 - 8 then
				ok = false
			end
			if ok then
				Loot.createChest(CFrame.new(x, top, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), boost or (3 + math.floor(k / 3)))
				return
			end
		end
	end
	if rng:NextNumber() < 0.4 then
		chestOn(0)
	end
	for k = 1, floors - 1 do
		if rng:NextNumber() < 0.25 then
			chestOn(k)
		end
	end
	chestOn(floors, 9) -- the secret rooftop stash: best rarity odds in the game
	block(cx, cz, w * 0.8)
end

-- City: 6x6 grid of lots on asphalt. Skyscrapers, enterable apartments with boosted loot, a city hall.
local function makeCity(cx, cz)
	mark("city", cx, cz, 410)
	local city = Instance.new("Model")
	city.Name = "City"
	city.Parent = workspace
	local lot, roadW, n = 52, 14, 6
	local pitch = lot + roadW
	local size = n * pitch + roadW
	mk({ Name = "Roads", Size = Vector3.new(size, 0.5, size), CFrame = CFrame.new(cx, 0.25, cz), Color = C3(58, 58, 64), Material = M.Asphalt }, city)

	for i = 0, n - 1 do
		for j = 0, n - 1 do
			local lx = cx - size / 2 + roadW + lot / 2 + i * pitch
			local lz = cz - size / 2 + roadW + lot / 2 + j * pitch
			mk({ Name = "Lot", Size = Vector3.new(lot, 0.4, lot), CFrame = CFrame.new(lx, 0.45, lz), Color = C3(150, 150, 156), Material = M.Concrete }, city)
			local center = (i == 2 or i == 3) and (j == 2 or j == 3)
			local roll = rng:NextNumber()
			if center then
				if i == 2 and j == 2 then
					makeBuilding(city, lx + lot / 2, lz + lot / 2, 0, { W = 44, D = 34, H = 16, style = CITY_STYLE, name = "CityHall", chests = 2, boost = 3, doorW = 9 })
				end
			elseif roll < 0.42 then
				-- enterable skyscraper (bare floors + ramps, chests inside)
				makeSkyscraper(city, lx, lz, rng:NextNumber(30, 40), rng:NextInteger(3, 8), rng:NextNumber(0.6, 1))
			elseif roll < 0.8 then
				-- enterable apartment / shop; door faces a random side
				makeBuilding(city, lx, lz, rng:NextInteger(0, 3) * math.pi / 2, {
					W = 24, D = 18, H = 12, style = CITY_STYLE, name = "Apartment", doorW = 6,
					chests = rng:NextNumber() < 0.3 and (rng:NextNumber() < 0.2 and 2 or 1) or 0, boost = 3 })
			else
				-- plaza: lamp + benches
				lampPost(city, lx, lz, 16)
				for _, b in { { -8, 0 }, { 8, 0 } } do
					mk({ Name = "Bench", Size = Vector3.new(6, 1.2, 1.8), CFrame = CFrame.new(lx + b[1], 1.2, lz + 6), Color = C3(110, 75, 40), Material = M.Wood }, city)
				end
			end
		end
	end
	-- parked cars on the roads
	for _ = 1, 16 do
		local line = rng:NextInteger(0, n)
		local along = rng:NextNumber(-size / 2 + 10, size / 2 - 10)
		local vertical = rng:NextInteger(0, 1) == 0
		local px = vertical and (cx - size / 2 + roadW / 2 + line * pitch) or (cx + along)
		local pz = vertical and (cz + along) or (cz - size / 2 + roadW / 2 + line * pitch)
		local color = C3(rng:NextInteger(40, 230), rng:NextInteger(40, 230), rng:NextInteger(40, 230))
		local sx, sz = vertical and 3.4 or 7, vertical and 7 or 3.4
		mk({ Name = "Car", Size = Vector3.new(sx, 2, sz), CFrame = CFrame.new(px, 1.5, pz), Color = color, Material = M.Metal }, city)
		mk({ Name = "CarTop", Size = Vector3.new(sx * (vertical and 0.9 or 0.5), 1.5, sz * (vertical and 0.5 or 0.9)), CFrame = CFrame.new(px, 3.2, pz), Color = C3(40, 50, 60), Material = M.Glass }, city)
	end
	block(cx, cz, size * 0.78)
end

-- Lookout tower: climb the ledges for a chest on top
local function makeLookout(cx, cz, region)
	mark("lookout", cx, cz, 30)
	local model = Instance.new("Model")
	model.Name = "Lookout"
	local info = Regions.Info[region]
	for i, s in ipairs({ 32, 26, 20, 14, 9 }) do
		mk({ Name = "Step", Size = Vector3.new(s, 5, s), CFrame = CFrame.new(cx, (i - 1) * 5 + 2.5, cz),
			Color = C3(120, 120, 125):Lerp(info.ground, 0.25):Lerp(C3(80, 80, 88), i / 8), Material = M.Cobblestone }, model)
	end
	local torch = mk({ Name = "Torch", Size = Vector3.new(0.8, 1.6, 0.8), CFrame = CFrame.new(cx + 3.4, 25.8, cz + 3.4), Color = C3(255, 160, 60), Material = M.Neon, CanCollide = false }, model)
	glow(torch, 35, 2, C3(255, 170, 80))
	model.Parent = workspace
	block(cx, cz, 24)
	Loot.createChest(CFrame.new(cx - 1.5, 25, cz - 1.5) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), 2)
end

local function makeRuin(cx, cz)
	mark("ruin", cx, cz, 24)
	local ruin = Instance.new("Model")
	ruin.Name = "Ruins"
	local stone = C3(115, 115, 120)
	mk({ Name = "Floor", Size = Vector3.new(24, 1, 24), CFrame = CFrame.new(cx, 0.5, cz), Color = stone, Material = M.Cobblestone }, ruin)
	for side = 1, 4 do
		local alongX = side <= 2
		local sign = (side % 2 == 0) and 1 or -1
		for seg = -1, 1, 2 do
			local h = rng:NextNumber(2.5, 8)
			local off = seg * 7.5
			local size = alongX and Vector3.new(9, h, 1.5) or Vector3.new(1.5, h, 9)
			local pos = alongX and Vector3.new(cx + off, 1 + h / 2, cz + sign * 11.5) or Vector3.new(cx + sign * 11.5, 1 + h / 2, cz + off)
			mk({ Name = "Wall", Size = size, CFrame = CFrame.new(pos), Color = stone, Material = M.Cobblestone }, ruin)
		end
	end
	for _, c in { { -12, -12 }, { 12, -12 }, { -12, 12 }, { 12, 12 } } do
		mk({ Name = "Pillar", Size = Vector3.new(2, 10, 2), CFrame = CFrame.new(cx + c[1], 6, cz + c[2]), Color = C3(200, 200, 205), Material = M.Marble }, ruin)
	end
	mk({ Name = "Beacon", Size = Vector3.new(3, 140, 3), CFrame = CFrame.new(cx, 70, cz), Color = C3(180, 90, 255), Material = M.Neon,
		Transparency = 0.65, CanCollide = false, CanQuery = false, CanTouch = false }, ruin)
	ruin.Parent = workspace
	block(cx, cz, 22)
	for _, c in { { -5, -4 } } do
		Loot.createChest(CFrame.new(cx + c[1], 1, cz + c[2]) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), 1)
	end
end

-- Cave: a rocky mound with a tunnel mouth facing +Z. Dim inside, rich ore, boosted chests, and a
-- zombie nest that never stops (see Caves.lua). Zombies inside count as always awake.
local function makeCave(cx, cz, region)
	mark("cave", cx, cz, 50)
	local model = Instance.new("Model")
	model.Name = "Cave"
	local st = MOUNTAIN[region]
	local rock = st.low:Lerp(C3(70, 70, 76), 0.5)
	local S, H, T = 36, 13, 3 -- interior size, interior height, wall thickness
	local half = S / 2
	local outer = S + 2 * T

	local function slab(name, size, pos, color)
		return mk({ Name = name, Size = size, CFrame = CFrame.new(pos), Color = color or rock, Material = st.mat }, model)
	end
	slab("Floor", Vector3.new(outer, 1, outer + 14), Vector3.new(cx, 0.5, cz + 7), rock:Lerp(C3(0, 0, 0), 0.4))
	slab("Roof", Vector3.new(outer, T, outer), Vector3.new(cx, 1 + H + T / 2, cz))
	slab("WallN", Vector3.new(outer, H, T), Vector3.new(cx, 1 + H / 2, cz - half - T / 2))
	slab("WallE", Vector3.new(T, H, S), Vector3.new(cx + half + T / 2, 1 + H / 2, cz))
	slab("WallW", Vector3.new(T, H, S), Vector3.new(cx - half - T / 2, 1 + H / 2, cz))
	-- south wall with a 9-wide tunnel mouth
	local segW = (outer - 9) / 2
	slab("WallSL", Vector3.new(segW, H, T), Vector3.new(cx - 4.5 - segW / 2, 1 + H / 2, cz + half + T / 2))
	slab("WallSR", Vector3.new(segW, H, T), Vector3.new(cx + 4.5 + segW / 2, 1 + H / 2, cz + half + T / 2))
	slab("Lintel", Vector3.new(9, H - 9, T), Vector3.new(cx, 1 + 9 + (H - 9) / 2, cz + half + T / 2))
	-- tunnel in front
	slab("TunnelL", Vector3.new(T, H, 14), Vector3.new(cx - 4.5 - T / 2, 1 + H / 2, cz + half + T + 7))
	slab("TunnelR", Vector3.new(T, H, 14), Vector3.new(cx + 4.5 + T / 2, 1 + H / 2, cz + half + T + 7))
	slab("TunnelRoof", Vector3.new(9 + 2 * T, T, 14), Vector3.new(cx, 1 + H + T / 2, cz + half + T + 7))
	-- mound on top so it reads as a hill from a distance
	local mw = outer - 6
	for k = 1, 4 do
		slab("Mound" .. k, Vector3.new(mw, 5, mw), Vector3.new(cx + rng:NextNumber(-2, 2), 1 + H + T + (k - 1) * 5 + 2.5, cz + rng:NextNumber(-2, 2)), rock:Lerp(st.high, k / 5))
		mw *= 0.7
	end
	-- stalagmites + dim lights inside
	for _ = 1, 8 do
		local h = rng:NextNumber(3, 6)
		slab("Stalagmite", Vector3.new(1.8, h, 1.8), Vector3.new(cx + rng:NextNumber(-half + 3, half - 3), 1 + h / 2, cz + rng:NextNumber(-half + 3, half - 8)), rock:Lerp(C3(0, 0, 0), 0.3))
	end
	for _, c in { { -half + 2, -half + 2 }, { half - 2, -half + 2 }, { 0, 0 } } do
		local lamp = mk({ Name = "Glowstone", Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(cx + c[1], H - 1, cz + c[2]), Color = C3(255, 160, 70), Material = M.Neon, CanCollide = false }, model)
		glow(lamp, 18, 0.8, C3(255, 150, 70))
	end
	-- tunnel-mouth warning light (red) so it's visible at night
	local warn = mk({ Name = "Warning", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(cx, 11, cz + half + T + 15), Color = C3(255, 40, 40), Material = M.Neon, CanCollide = false }, model)
	glow(warn, 30, 1.5, C3(255, 50, 50))
	model.Parent = workspace
	block(cx, cz, 38)

	-- loot: region ore + boosted chests
	for i, kind in ipairs(CAVE_ORE[region]) do
		makeOre(kind, cx + (i == 1 and -1 or 1) * (half - 5), cz - half + 5, 1)
		makeOre(kind, cx + (i == 1 and -1 or 1) * (half - 5), cz - half + 12, 1)
	end
	-- secret vault: two purple chests that stay LOCKED until you kill enough of the cave's zombies
	local Players = game:GetService("Players")
	local cave = { x = cx, z = cz, half = half, floorY = 1, max = 5, danger = Regions.Info[region].danger, kills = 0, need = 12, cleared = false }
	local vaults = {
		Loot.createChest(CFrame.new(cx - half + 3.5, 1, cz + 2) * CFrame.Angles(0, math.pi / 2, 0), 9, true),
		Loot.createChest(CFrame.new(cx + half - 3.5, 1, cz + 2) * CFrame.Angles(0, -math.pi / 2, 0), 9, true),
	}
	local function relabel()
		for _, v in vaults do
			Loot.lock(v, not cave.cleared, cave.cleared and "Vault" or ("LOCKED Vault: kill zombies " .. cave.kills .. "/" .. cave.need))
		end
	end
	relabel()
	function cave.onKill()
		if cave.cleared then
			return
		end
		cave.kills += 1
		if cave.kills >= cave.need then
			cave.cleared = true
			for _, p in Players:GetPlayers() do
				local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if root and (root.Position - Vector3.new(cx, root.Position.Y, cz)).Magnitude < 160 then
					Remotes.Notify:FireClient(p, "CAVE CLEARED! The vault is unlocked", C3(190, 110, 255))
				end
			end
		end
		relabel()
	end
	function cave.reset()
		cave.kills, cave.cleared = 0, false
		relabel()
	end
	Caves.register(cave)
end


-- Sky lobby: where players wait before a run and where you land after dying. Far above the map.
function World.makeLobby()
	local y, S = 1500, 90
	local model = Instance.new("Model")
	model.Name = "Lobby"
	local function part(name, size, pos, color, mat, props)
		local p = mk({ Name = name, Size = size, CFrame = CFrame.new(pos), Color = color, Material = mat }, model)
		if props then
			for k, v in props do
				p[k] = v
			end
		end
		return p
	end
	part("Floor", Vector3.new(S, 2, S), Vector3.new(0, y, 0), C3(40, 40, 52), M.Slate)
	part("Trim", Vector3.new(S - 8, 0.4, S - 8), Vector3.new(0, y + 1.1, 0), C3(60, 60, 78), M.Concrete)
	for _, w in { { 0, S / 2, S, 1 }, { 0, -S / 2, S, 1 }, { S / 2, 0, 1, S }, { -S / 2, 0, 1, S } } do
		part("Barrier", Vector3.new(w[3], 60, w[4]), Vector3.new(w[1], y + 30, w[2]), C3(120, 90, 255), M.ForceField, { Transparency = 0.8 })
		part("Rail", Vector3.new(w[3], 1, w[4]), Vector3.new(w[1], y + 3, w[2]), C3(255, 80, 60), M.Neon, { CanCollide = false })
	end
	part("Ceiling", Vector3.new(S, 1, S), Vector3.new(0, y + 61, 0), C3(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CanQuery = false })
	-- signs: title on the north wall, welcome message on the south wall, and text painted on the floor
	local function sign(name, pos, face, w, h, lines)
		local p = part(name, Vector3.new(w, h, 2), pos, C3(15, 10, 25), M.SmoothPlastic)
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 40
		sg.Parent = p
		local y0 = 0
		for _, ln in lines do
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, ln.h)
			t.Position = UDim2.fromScale(0, y0)
			y0 += ln.h
			t.BackgroundTransparency = 1
			t.Text = ln.text
			t.TextScaled = true
			t.Font = Enum.Font.GothamBlack
			t.TextColor3 = ln.color
			t.TextStrokeTransparency = 0.2
			t.Parent = sg
		end
	end
	sign("TitleSign", Vector3.new(0, y + 14, -S / 2 + 3), Enum.NormalId.Back, 60, 22, {
		{ text = "NIGHTFALL", h = 0.65, color = C3(255, 90, 60) },
		{ text = "Survive 40 nights", h = 0.35, color = C3(255, 235, 200) },
	})
	sign("WelcomeSign", Vector3.new(0, y + 14, S / 2 - 3), Enum.NormalId.Front, 60, 22, {
		{ text = "WELCOME TO THE LOBBY", h = 0.55, color = C3(190, 160, 255) },
		{ text = "GOOD LUCK!", h = 0.45, color = C3(120, 255, 150) },
	})
	for _, x in { -30, 30 } do
		local lamp = part("Lamp", Vector3.new(2, 2, 2), Vector3.new(x, y + 20, 0), C3(255, 220, 160), M.Neon, { CanCollide = false })
		glow(lamp, 60, 1.4, C3(255, 220, 160))
	end

	-- scale model of the whole world on a table: regions, city, towns, caves, mountains + live player dots
	local half = Config.MapHalf
	local MAP, CELLS = 44, 16
	local mx, mz = 0, -8
	local topY = y + 4.25
	local function toModel(wx, wz)
		return mx + wx / (2 * half) * MAP, mz + wz / (2 * half) * MAP
	end
	part("MapBase", Vector3.new(MAP + 4, 3, MAP + 4), Vector3.new(mx, y + 2.5, mz), C3(30, 28, 40), M.Slate)
	local tile = MAP / CELLS
	for i = 1, CELLS do
		for j = 1, CELLS do
			local wx = -half + (i - 0.5) * (2 * half / CELLS)
			local wz = -half + (j - 0.5) * (2 * half / CELLS)
			part("MapTile", Vector3.new(tile, 0.5, tile), Vector3.new(mx - MAP / 2 + (i - 0.5) * tile, topY, mz - MAP / 2 + (j - 0.5) * tile),
				Regions.Info[Regions.at(wx, wz)].ground, Regions.Info[Regions.at(wx, wz)].material)
		end
	end
	local function minis(kind, px, pz, sizeW)
		local x, z = toModel(px, pz)
		local s = sizeW / (2 * half) * MAP
		local base = topY + 0.25
		if kind == "city" then
			for k = 1, 5 do
				local ox, oz = (k % 3 - 1) * s * 0.3, (math.floor(k / 3) - 0.5) * s * 0.3
				part("MiniCity", Vector3.new(s * 0.28, 1 + k * 0.35, s * 0.28), Vector3.new(x + ox, base + (1 + k * 0.35) / 2, z + oz), C3(170, 175, 190), M.Glass)
			end
		elseif kind == "town" then
			part("MiniTown", Vector3.new(1.6, 0.9, 1.6), Vector3.new(x, base + 0.45, z), C3(235, 205, 160), M.WoodPlanks)
		elseif kind == "rural" then
			part("MiniRural", Vector3.new(0.8, 0.5, 0.8), Vector3.new(x, base + 0.25, z), C3(200, 170, 90), M.WoodPlanks)
		elseif kind == "cave" then
			part("MiniCave", Vector3.new(1, 1, 1), Vector3.new(x, base + 0.5, z), C3(255, 60, 50), M.Neon)
		elseif kind == "mountain" then
			part("MiniMountain", Vector3.new(s, 1, s), Vector3.new(x, base + 0.5, z), C3(110, 110, 122), M.Rock)
			part("MiniPeak", Vector3.new(s * 0.55, 0.9, s * 0.55), Vector3.new(x, base + 1.45, z), C3(225, 225, 235), M.Snow)
		elseif kind == "lookout" then
			part("MiniLookout", Vector3.new(0.5, 1.4, 0.5), Vector3.new(x, base + 0.7, z), C3(240, 240, 240), M.Concrete)
		elseif kind == "ruin" then
			part("MiniRuin", Vector3.new(0.6, 0.6, 0.6), Vector3.new(x, base + 0.3, z), C3(190, 100, 255), M.Neon)
		end
	end
	for _, m in landmarks do
		minis(m.kind, m.x, m.z, m.size)
	end
	local north = part("MapNorth", Vector3.new(1, 1, 1), Vector3.new(mx, topY + 1, mz - MAP / 2 - 1.5), C3(255, 255, 255), M.Neon, { CanCollide = false, Transparency = 1 })
	local nb = Instance.new("BillboardGui")
	nb.Size = UDim2.fromOffset(160, 40)
	nb.StudsOffset = Vector3.new(0, 3, 0)
	nb.AlwaysOnTop = true
	nb.Parent = north
	local nt = Instance.new("TextLabel")
	nt.Size = UDim2.fromScale(1, 1)
	nt.BackgroundTransparency = 1
	nt.Text = "WORLD MAP  (N)"
	nt.TextScaled = true
	nt.Font = Enum.Font.GothamBold
	nt.TextColor3 = C3(255, 255, 255)
	nt.TextStrokeTransparency = 0.3
	nt.Parent = nb
	local dots = Instance.new("Folder")
	dots.Name = "MapDots"
	dots.Parent = model
	World.lobbyMap = { mx = mx, mz = mz, topY = topY, size = MAP, half = half, folder = dots }
	-- big START button: walk up and press E (works even if the on-screen button can't be clicked)
	part("StartPodium", Vector3.new(7, 2.4, 7), Vector3.new(16, y + 2.2, 24), C3(30, 28, 40), M.Slate)
	local btn = part("StartButton", Vector3.new(5, 0.8, 5), Vector3.new(16, y + 3.8, 24), C3(60, 230, 110), M.Neon)
	glow(btn, 25, 1.5, C3(80, 255, 130))
	local sbb = Instance.new("BillboardGui")
	sbb.Size = UDim2.fromOffset(200, 50)
	sbb.StudsOffset = Vector3.new(0, 4, 0)
	sbb.AlwaysOnTop = true
	sbb.MaxDistance = 150
	sbb.Parent = btn
	local sbt = Instance.new("TextLabel")
	sbt.Size = UDim2.fromScale(1, 1)
	sbt.BackgroundTransparency = 1
	sbt.Text = "START RUN"
	sbt.TextScaled = true
	sbt.Font = Enum.Font.GothamBlack
	sbt.TextColor3 = Color3.fromRGB(120, 255, 160)
	sbt.TextStrokeTransparency = 0.3
	sbt.Parent = sbb
	local startPrompt = Instance.new("ProximityPrompt")
	startPrompt.ObjectText = "Nightfall"
	startPrompt.ActionText = "Start Run"
	startPrompt.HoldDuration = 0.3
	startPrompt.MaxActivationDistance = 14
	startPrompt.RequiresLineOfSight = false
	startPrompt.Parent = btn
	World.startPrompt = startPrompt
	World.startLabel = sbt

	local pad = Instance.new("SpawnLocation")
	pad.Name = "LobbySpawn"
	pad.Size = Vector3.new(10, 1, 10)
	pad.CFrame = CFrame.new(0, y + 1.5, 28)
	pad.Anchored = true
	pad.Neutral = true
	pad.Duration = 0
	pad.Transparency = 0.5
	pad.Color = C3(120, 90, 255)
	pad.Material = M.Neon
	pad.Parent = model
	World.lobbySpawn = pad
	model.Parent = workspace
end

-- called about once a second: shows where every player in the run is on the lobby scale model
function World.updateLobbyDots()
	local m = World.lobbyMap
	if not m then
		return
	end
	local seen = {}
	for _, p in game:GetService("Players"):GetPlayers() do
		local root = p:GetAttribute("InRun") == true and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local name = "Dot" .. p.UserId
			local dot = m.folder:FindFirstChild(name)
			if not dot then
				dot = Instance.new("Part")
				dot.Name = name
				dot.Shape = Enum.PartType.Ball
				dot.Size = Vector3.new(1.3, 1.3, 1.3)
				dot.Anchored = true
				dot.CanCollide = false
				dot.CanQuery = false
				dot.Material = Enum.Material.Neon
				dot.Color = Color3.fromRGB(80, 255, 120)
				local bb = Instance.new("BillboardGui")
				bb.Size = UDim2.fromOffset(120, 24)
				bb.StudsOffset = Vector3.new(0, 1.8, 0)
				bb.AlwaysOnTop = true
				bb.Parent = dot
				local tl = Instance.new("TextLabel")
				tl.Size = UDim2.fromScale(1, 1)
				tl.BackgroundTransparency = 1
				tl.Text = p.Name
				tl.TextColor3 = Color3.new(1, 1, 1)
				tl.TextStrokeTransparency = 0.3
				tl.Font = Enum.Font.GothamBold
				tl.TextSize = 14
				tl.Parent = bb
				dot.Parent = m.folder
			end
			local wx = math.clamp(root.Position.X, -m.half, m.half)
			local wz = math.clamp(root.Position.Z, -m.half, m.half)
			dot.Position = Vector3.new(m.mx + wx / (2 * m.half) * m.size, m.topY + 1.2, m.mz + wz / (2 * m.half) * m.size)
			seen[name] = true
		end
	end
	for _, d in m.folder:GetChildren() do
		if not seen[d.Name] then
			d:Destroy()
		end
	end
end

-- Generate ----------------------------------------------------------------------------------------
local function try(label, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[Nightfall] world gen error in " .. label .. ": " .. tostring(err))
	end
end

function World.generate()
	local half = Config.MapHalf

	-- ground: 150-stud tiles colored by region (blocky borders, Minecraft style)
	local T = 150
	local tiles = math.ceil(half * 2 / T)
	for i = 1, tiles do
		for j = 1, tiles do
			local x = -half + (i - 0.5) * T
			local z = -half + (j - 0.5) * T
			local info = Regions.Info[Regions.at(x, z)]
			mk({ Name = "Ground", Size = Vector3.new(T, 4, T), CFrame = CFrame.new(x, -2, z), Color = info.ground, Material = info.material }, workspace)
		end
	end

	for _, w in { { 0, half, half * 2, 2 }, { 0, -half, half * 2, 2 }, { half, 0, 2, half * 2 }, { -half, 0, 2, half * 2 } } do
		mk({ Name = "Boundary", Size = Vector3.new(w[3], 200, w[4]), CFrame = CFrame.new(w[1], 100, w[2]), Transparency = 1, CanQuery = false }, workspace)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.new(0, 0.5, 0)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 3
	spawn.Color = C3(120, 120, 125)
	spawn.Material = M.Cobblestone
	spawn.Parent = workspace
	World.worldSpawn = spawn
	block(0, 0, 35)

	local fire = mk({ Name = "Campfire", Size = Vector3.new(2, 1, 2), CFrame = CFrame.new(10, 0.5, 10), Color = C3(60, 40, 25), Material = M.Wood }, workspace)
	local flame = Instance.new("Fire")
	flame.Size = 7
	flame.Parent = fire
	glow(fire, 30, 2, C3(255, 160, 60))
	for i = 0, 0 do
		local a = i * math.pi + 0.5
		Loot.createChest(CFrame.new(math.cos(a) * 16, 0, math.sin(a) * 16) * CFrame.Angles(0, -a, 0))
	end

	-- the big stuff first so small stuff avoids it
	try("makeCity", makeCity, -430, -440)

	for _, region in { "Greenfields", "Darkwood", "Frostlands", "Desert", "Ashlands" } do
		local x, z = freeSpot(170, region, region == "Greenfields" and 250 or 0)
		if x then
			try("makeTown", makeTown, x, z, region)
		end
	end
	for region, st in MOUNTAIN do
		for _ = 1, st.count do
			local w = rng:NextNumber(110, 200)
			local x, z = freeSpot(w * 0.7 + 20, region, 200)
			if x then
				try("makeMountain", makeMountain, x, z, w, region)
			end
		end
	end
	for region, count in CAVE_COUNT do
		for _ = 1, count do
			local x, z = freeSpot(60, region, 180)
			if x then
				try("makeCave", makeCave, x, z, region)
			end
		end
	end
	for _ = 1, 14 do
		local x, z = freeSpot(100, nil, 250)
		if x then
			try("makeRuralTown", makeRuralTown, x, z, Regions.at(x, z))
		end
	end
	for _ = 1, 8 do
		local x, z = freeSpot(40, nil, 150)
		if x then
			try("makeLookout", makeLookout, x, z, Regions.at(x, z))
		end
	end
	for _ = 1, 6 do
		local x, z = freeSpot(40, nil, 200)
		if x then
			try("makeRuin", makeRuin, x, z)
		end
	end

	for region, ts in TREE do
		for _ = 1, ts.count do
			local x, z = freeSpot(6, region, 25)
			if x then
				try("makeTree", makeTree, x, z, region)
			end
		end
	end
	for region, kinds in ORE do
		for kind, count in kinds do
			for _ = 1, count do
				local x, z = freeSpot(6, region, 30)
				if x then
					try("makeOre", makeOre, kind, x, z)
				end
			end
		end
	end

	-- lone chests in the wild
	for _ = 1, 8 do
		local x, z = freeSpot(8, nil, 60)
		if x then
			Loot.createChest(CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
		end
	end

	try("makeLobby", World.makeLobby) -- last, so the scale model knows where everything ended up
end

return World
