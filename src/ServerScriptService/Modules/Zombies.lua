-- Zombie rigs (built from parts, no assets), AI, special types and the Zombie King boss.
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local PathfindingService = game:GetService("PathfindingService")

local Config = require(RS:WaitForChild("Config"))
local Regions = require(RS:WaitForChild("Regions"))
local Remotes = require(script.Parent.Remotes)
local Util = require(script.Parent.Util)
local Damage = require(script.Parent.Damage)
local Build = require(script.Parent.Build)
local Loot = require(script.Parent.Loot)

local Zombies = {}
Zombies.list = {} -- [model] = state
Zombies.BossKilled = Instance.new("BindableEvent")

local rng = Random.new()
local folder = Util.folder("Zombies")

-- zombies don't collide with each other (stops huge clumps)
local groupOk = pcall(function()
	PhysicsService:RegisterCollisionGroup("Zombies")
	PhysicsService:CollisionGroupSetCollidable("Zombies", "Zombies", false)
end)

-- Standard R6 joint offsets so the default walk animation works on our blocky zombies
local J = {
	RootJoint = { CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
	Neck = { CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, -0.75, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
	RightShoulder = { CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
	LeftShoulder = { CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
	RightHip = { CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
	LeftHip = { CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
}

local function scaled(cf, s)
	local p = cf.Position
	return CFrame.new(p.X * s, p.Y * s, p.Z * s) * (cf - p)
end

local function buildRig(scale, colors, isBoss)
	local model = Instance.new("Model")
	model.Name = "Zombie"

	local function part(name, size, color, offset, collide)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * scale
		p.Color = color
		p.CanCollide = collide
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CFrame = CFrame.new(offset * scale)
		p.Parent = model
		return p
	end

	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), colors.shirt, Vector3.zero, true)
	root.Transparency = 1
	local torso = part("Torso", Vector3.new(2, 2, 1), colors.shirt, Vector3.zero, true)
	local head = part("Head", Vector3.new(1.5, 1.5, 1.5), colors.skin, Vector3.new(0, 1.75, 0), true)
	local rarm = part("Right Arm", Vector3.new(1, 2, 1), colors.skin, Vector3.new(1.5, 0, 0), false)
	local larm = part("Left Arm", Vector3.new(1, 2, 1), colors.skin, Vector3.new(-1.5, 0, 0), false)
	local rleg = part("Right Leg", Vector3.new(1, 2, 1), colors.pants, Vector3.new(0.5, -2, 0), false)
	local lleg = part("Left Leg", Vector3.new(1, 2, 1), colors.pants, Vector3.new(-0.5, -2, 0), false)

	local function motor(name, jointKey, p0, p1)
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = scaled(J[jointKey][1], scale)
		m.C1 = scaled(J[jointKey][2], scale)
		m.Parent = p0
	end
	motor("RootJoint", "RootJoint", root, torso)
	motor("Neck", "Neck", torso, head)
	motor("Right Shoulder", "RightShoulder", torso, rarm)
	motor("Left Shoulder", "LeftShoulder", torso, larm)
	motor("Right Hip", "RightHip", torso, rleg)
	motor("Left Hip", "LeftHip", torso, lleg)

	-- glowing red eyes (head faces -Z)
	local function attach(p)
		p.CanCollide = false
		p.Massless = true
		local w = Instance.new("Weld") -- explicit offset, so it's correct before the model enters the world
		w.Part0 = head
		w.Part1 = p
		w.C0 = head.CFrame:ToObjectSpace(p.CFrame)
		w.Parent = p
	end
	for _, x in { -0.35, 0.35 } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Size = Vector3.new(0.3, 0.22, 0.1) * scale
		eye.Color = Color3.fromRGB(255, 40, 40)
		eye.Material = Enum.Material.Neon
		eye.CFrame = head.CFrame * CFrame.new(x * scale, 0.15 * scale, -0.78 * scale)
		eye.Parent = model
		attach(eye)
	end
	if isBoss then
		local crown = Instance.new("Part")
		crown.Name = "Crown"
		crown.Size = Vector3.new(1.7, 0.6, 1.7) * scale
		crown.Color = Color3.fromRGB(255, 200, 40)
		crown.Material = Enum.Material.Neon
		crown.CFrame = head.CFrame * CFrame.new(0, 1.05 * scale, 0)
		crown.Parent = model
		attach(crown)
	end

	model.PrimaryPart = root
	return model, root
end

local function setGroup(model)
	if not groupOk then
		return
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CollisionGroup = "Zombies"
		end
	end
end

-- counts the night's roaming zombies (cave zombies are tracked separately and don't count)
function Zombies.alive()
	local n = 0
	for _, z in Zombies.list do
		if not z.home then
			n += 1
		end
	end
	return n
end

function Zombies.pickType(night)
	local pool = {}
	for name, def in Config.Zombies do
		if not def.boss and def.minNight <= night then
			-- special types get more common the further into the game you are
			local w = def.weight * (def.minNight > 1 and (1 + 0.25 * (night - def.minNight)) or 1)
			table.insert(pool, { name = name, w = w })
		end
	end
	return Config.pickWeighted(rng, pool, function(x)
		return x.w
	end).name
end

function Zombies.spawn(typeName, pos, night)
	local def = Config.Zombies[typeName]
	local stats = Config.nightStats(night)
	local scale = def.scale

	local model, root = buildRig(scale, def.colors, def.boss)

	local hp = def.hp * stats.hp
	if def.boss then
		local inRun = 0
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("InRun") then
				inRun += 1
			end
		end
		local extra = math.max(0, inRun - 1)
		hp = def.hp + (def.hpPerExtraPlayer or 0) * extra
	end

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R6
	hum.HipHeight = 0
	hum.MaxHealth = hp
	hum.Health = hp
	hum.WalkSpeed = def.speed * stats.speed
	hum.UseJumpPower = true
	hum.JumpPower = 55
	hum.DisplayName = def.display
	hum.NameDisplayDistance = def.boss and 300 or 0
	hum.HealthDisplayDistance = def.boss and 300 or 50
	hum.HealthDisplayType = def.boss and Enum.HumanoidHealthDisplayType.AlwaysOn
		or Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
	hum.Parent = model

	local animator = Instance.new("Animator")
	animator.Parent = hum

	model:PivotTo(CFrame.new(pos))
	setGroup(model)
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil) -- server simulates zombies so they behave identically for everyone
	end)

	-- Roblox's stock R6 walk animation (owned by Roblox, free for every experience)
	pcall(function()
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://180426354"
		local track = animator:LoadAnimation(anim)
		track.Looped = true
		track:Play()
		track:AdjustSpeed(math.clamp(hum.WalkSpeed / 12, 0.6, 2))
	end)

	local now = os.clock()
	local z = {
		model = model, hum = hum, root = root, def = def, scale = scale, night = night,
		dmg = def.dmg * (def.boss and 1 or stats.dmg), cd = (def.boss and 1.2 or 1.0) * Config.Pace.zombieAttack, nextAttack = 0,
		range = 4.5 * scale, lastPos = pos, stuckAt = now,
		nextSlam = now + 7, nextSummon = now + 10,
		waypoints = nil, wpIdx = 1, wpExpire = 0, pathing = false,
	}
	Zombies.list[model] = z

	if def.boss then
		workspace:SetAttribute("BossName", def.display)
		workspace:SetAttribute("BossMax", hp)
		workspace:SetAttribute("BossHP", hp)
		hum.HealthChanged:Connect(function(h)
			workspace:SetAttribute("BossHP", math.max(0, h))
		end)
	end

	hum.Died:Connect(function()
		Zombies.list[model] = nil
		local atk = z.lastAttacker
		if atk and atk.Parent then
			local ls = atk:FindFirstChild("leaderstats")
			local kills = ls and ls:FindFirstChild("Kills")
			if kills then
				kills.Value += 1
			end
		end
		if not z.noDrop and not def.boss and rng:NextNumber() < Config.zombieDropChance(night) then
			Loot.spawnDrop(root.Position, Loot.roll(night, Config.ZombieLoot))
		end
		if z.home and z.home.onKill and not z.noDrop then
			z.home.onKill()
		end
		if def.boss then
			workspace:SetAttribute("BossHP", 0)
			Zombies.BossKilled:Fire()
		end
		Debris:AddItem(model, 3)
	end)

	return model
end

-- Spawns a zombie 55-85 studs from a random living player
function Zombies.spawnAround(night, typeName)
	local targets = {}
	for _, p in Players:GetPlayers() do
		local hum, root = Util.aliveHumanoid(p)
		if hum then
			table.insert(targets, root)
		end
	end
	if #targets == 0 then
		return nil
	end
	local center = targets[rng:NextInteger(1, #targets)].Position
	local a = rng:NextNumber(0, math.pi * 2)
	local d = rng:NextNumber(55, 85)
	local half = Config.MapHalf - 12
	local x = math.clamp(center.X + math.cos(a) * d, -half, half)
	local zz = math.clamp(center.Z + math.sin(a) * d, -half, half)
	local def = Config.Zombies[typeName]
	local gy = Util.groundY(Vector3.new(x, 40, zz))
	-- zombies are stronger in more dangerous regions (Ashlands = +2 nights of strength)
	local bonus = def.boss and 0 or Regions.Info[Regions.at(x, zz)].danger
	return Zombies.spawn(typeName, Vector3.new(x, gy + 3 * def.scale + 1, zz), night + bonus)
end

function Zombies.damage(model, amount, attacker, headshot)
	local z = Zombies.list[model]
	if not z or z.hum.Health <= 0 then
		return false
	end
	z.lastAttacker = attacker
	z.hum.Health -= amount
	return z.hum.Health <= 0
end

function Zombies.killAll(includeBoss)
	for _, z in Zombies.list do
		-- dawn burns the night's zombies; cave dwellers only go away on a full reset
		if (includeBoss or not z.def.boss) and (includeBoss or not z.home) then
			z.noDrop = true
			z.hum.Health = 0
		end
	end
end

-- AI ------------------------------------------------------------------------
local function computePath(z, targetPos)
	if z.pathing then
		return
	end
	z.pathing = true
	z.pathTarget = targetPos
	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = math.min(3, 2 * z.scale),
			AgentHeight = 5 * z.scale,
			AgentCanJump = true,
			WaypointSpacing = 5,
		})
		local ok = pcall(function()
			path:ComputeAsync(z.root.Position, targetPos)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			z.waypoints = path:GetWaypoints()
			z.wpIdx = 2
			z.wpExpire = os.clock() + 12
			z.wpAdvance = os.clock()
			z.noPath = nil
		else
			z.waypoints = nil
			z.noPath = os.clock()
		end
		z.pathing = false
	end)
end

function Zombies.explode(z)
	if z.exploded then
		return
	end
	z.exploded = true
	local pos = z.root.Position
	local fx = Instance.new("Explosion")
	fx.Position = pos
	fx.BlastRadius = 12
	fx.BlastPressure = 0
	fx.DestroyJointRadiusPercent = 0
	fx.Parent = workspace
	for _, p in Players:GetPlayers() do
		local hum, root = Util.aliveHumanoid(p)
		if hum then
			local d = (root.Position - pos).Magnitude
			if d <= 13 then
				Damage.player(p, 55 * z.dmgMult * (1 - d / 16))
			end
		end
	end
	Build.damageRadius(pos, 13, 300)
	z.noDrop = true
	z.hum.Health = 0
end

local function bossSlam(z, targets)
	local pos = z.root.Position
	local fx = Instance.new("Explosion")
	fx.Position = pos - Vector3.new(0, 6, 0)
	fx.BlastRadius = 24
	fx.BlastPressure = 0
	fx.DestroyJointRadiusPercent = 0
	fx.Parent = workspace
	for _, t in targets do
		local away = t.root.Position - pos
		if away.Magnitude <= 26 then
			Damage.player(t.player, z.dmg * 0.9)
			local dir = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1)
			t.root.AssemblyLinearVelocity = dir * 45 + Vector3.new(0, 55, 0)
		end
	end
	Build.damageRadius(pos, 24, 500)
	Remotes.Notify:FireAllClients("" .. z.def.display .. " slams the ground!", Color3.fromRGB(255, 80, 80))
end

function Zombies.step()
	local now = os.clock()
	local targets = {}
	for _, p in Players:GetPlayers() do
		local hum, root = Util.aliveHumanoid(p)
		if hum then
			table.insert(targets, { player = p, root = root })
		end
	end
	if #targets == 0 then
		return
	end

	local structureParams = RaycastParams.new()
	structureParams.FilterType = Enum.RaycastFilterType.Include
	structureParams.FilterDescendantsInstances = { Util.folder("Structures") }

	-- "can this zombie just walk straight at you?": solid things between count (walls, buildings, mountains),
	-- but not other zombies, trees/rocks, loot or the players themselves
	local losParams = RaycastParams.new()
	losParams.FilterType = Enum.RaycastFilterType.Exclude
	local losIgnore = { Util.folder("Zombies"), Util.folder("Nodes"), Util.folder("Loot") }
	for _, t in targets do
		if t.root.Parent then
			table.insert(losIgnore, t.root.Parent)
		end
	end
	losParams.FilterDescendantsInstances = losIgnore
	local pathBudget = 6 -- path requests started per AI tick

	for model, z in Zombies.list do
		local root, hum = z.root, z.hum
		if hum.Health <= 0 or not root.Parent then
			Zombies.list[model] = nil
			continue
		end
		local pos = root.Position

		local best, bestD, bestScore = nil, math.huge, math.huge
		for _, t in targets do
			local off = t.root.Position - pos
			local d = off.Magnitude
			-- height makes you harder to reach, so a zombie prefers a closer ground target
			local score = d + 1.2 * math.max(0, math.abs(off.Y) - 6)
			if score < bestScore then
				best, bestD, bestScore = t, d, score
			end
		end

		-- Zombie King abilities
		if z.def.boss then
			if now >= z.nextSlam and bestD < 40 then
				z.nextSlam = now + 9
				bossSlam(z, targets)
			end
			if now >= z.nextSummon and Zombies.alive() < 60 then
				z.nextSummon = now + 12
				for _ = 1, 3 do
					local off = Vector3.new(rng:NextNumber(-14, 14), 0, rng:NextNumber(-14, 14))
					local spot = pos + off
					local type_ = rng:NextNumber() < 0.5 and "Walker" or "Runner"
					Zombies.spawn(type_, Vector3.new(spot.X, Util.groundY(spot) + 5, spot.Z), z.night)
				end
			end
		end

		-- cave dwellers stay near their cave
		local leash = false
		if z.home then
			local homePos = Vector3.new(z.home.x, pos.Y, z.home.z)
			if (homePos - pos).Magnitude > 110 and bestD > 18 then
				hum:MoveTo(homePos)
				leash = true
			end
		end

		if leash then
			-- walking back to the cave
		elseif bestD <= z.range then
			hum:MoveTo(pos)
			local flat = Vector3.new(best.root.Position.X, pos.Y, best.root.Position.Z)
			if (flat - pos).Magnitude > 0.1 then
				root.CFrame = CFrame.lookAt(pos, flat)
			end
			if z.def.explode then
				z.dmgMult = Config.nightStats(z.night).dmg
				Zombies.explode(z)
			elseif now >= z.nextAttack then
				z.nextAttack = now + z.cd
				-- a wall between you and the zombie takes the hit instead of you
				local hit = workspace:Raycast(pos, best.root.Position - pos, structureParams)
				if hit then
					Build.damage(hit.Instance, z.dmg)
				else
					Damage.player(best.player, z.dmg)
				end
			end
		else
			local tp = best.root.Position
			local dest = tp
			local dy = tp.Y - pos.Y
			local flatDist = Vector3.new(tp.X - pos.X, 0, tp.Z - pos.Z).Magnitude

			-- every 0.6s decide whether walking straight at the player will work
			if now >= (z.nextCheck or 0) then
				z.nextCheck = now + 0.6
				local eye = pos + Vector3.new(0, 2 * z.scale, 0)
				local blocked = workspace:Raycast(eye, tp - eye, losParams) ~= nil
				z.needPath = (blocked or math.abs(dy) > 5) and not (flatDist > 220 and math.abs(dy) <= 5)
			end

			if z.needPath then
				local stale = not z.waypoints or now > z.wpExpire
					or (z.pathTarget and (z.pathTarget - tp).Magnitude > 10)
					or (now - (z.wpAdvance or now)) > 2.5
				if stale and not z.pathing and pathBudget > 0 and now >= (z.nextPathAt or 0) then
					pathBudget -= 1
					z.nextPathAt = now + 1.0
					z.wpAdvance = now
					computePath(z, tp)
				end
			else
				z.waypoints = nil
			end

			local breaching = false
			if z.waypoints and now < z.wpExpire then
				-- follow the route: climbs ramps, goes through doorways and up skyscraper floors
				local wps = z.waypoints
				local wp = wps[z.wpIdx]
				while wp and (Vector3.new(wp.Position.X, pos.Y, wp.Position.Z) - pos).Magnitude < 3.5
					and math.abs(wp.Position.Y - pos.Y) < 5 do
					z.wpIdx += 1
					z.wpAdvance = now
					wp = wps[z.wpIdx]
				end
				if wp then
					dest = wp.Position
					if wp.Action == Enum.PathWaypointAction.Jump then
						hum.Jump = true
					end
				else
					z.waypoints = nil
				end
			elseif z.needPath and z.noPath and now - z.noPath < 4 then
				-- no route exists (you are walled in): go for the wall itself
				local dir = Vector3.new(tp.X - pos.X, 0, tp.Z - pos.Z)
				if dir.Magnitude > 0.1 then
					local hit = workspace:Raycast(pos + Vector3.new(0, 2, 0), dir.Unit * (4 * z.scale + 4), structureParams)
					if hit then
						breaching = true
						hum:MoveTo(pos)
						if now >= z.nextAttack then
							z.nextAttack = now + z.cd
							Build.damage(hit.Instance, z.dmg)
						end
					end
				end
			end
			if not breaching then
				hum:MoveTo(dest)
			end

			-- stuck? jump, chew through any wall in the way, otherwise ask for a route
			if now - z.stuckAt >= 0.9 then
				local moved = (pos - z.lastPos).Magnitude
				z.lastPos = pos
				z.stuckAt = now
				if moved < 1.0 and not breaching then
					hum.Jump = true
					local dir = Vector3.new(tp.X - pos.X, 0, tp.Z - pos.Z)
					if dir.Magnitude > 0.1 then
						local hit = workspace:Raycast(pos, dir.Unit * (4 * z.scale + 3), structureParams)
						if hit then
							Build.damage(hit.Instance, z.dmg)
						else
							z.needPath = true
							z.nextPathAt = 0
						end
					end
				end
			end
		end
	end
end

return Zombies
