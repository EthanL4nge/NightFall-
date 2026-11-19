-- Server-authoritative weapons: hitscan guns (with spread/pellets/headshots) and melee arcs.
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(RS:WaitForChild("Config"))
local Remotes = require(script.Parent.Remotes)
local Util = require(script.Parent.Util)
local Inventory = require(script.Parent.Inventory)
local Zombies = require(script.Parent.Zombies)
local Build = require(script.Parent.Build)

local Combat = {}

local rng = Random.new()
local nextFire = setmetatable({}, { __mode = "k" }) -- [tool] = os.clock() when it may fire again

local function spreadDir(dir, deg)
	if deg <= 0 then
		return dir
	end
	local cf = CFrame.lookAt(Vector3.zero, dir)
		* CFrame.Angles(math.rad(rng:NextNumber(-deg, deg)), math.rad(rng:NextNumber(-deg, deg)), 0)
	return cf.LookVector
end

-- Bullets are real projectiles: they travel at def.velocity and fall under Config.BulletGravity,
-- so far shots need a little lead/hold-over (guns are "zeroed" at def.zero studs so close fights feel normal).
local bullets = {}
local MAX_BULLETS = 500
local bulletParams = RaycastParams.new()
bulletParams.FilterType = Enum.RaycastFilterType.Exclude

local function refreshBulletFilter()
	local ignore = { Util.folder("Loot") } -- player-built structures are NOT ignored: bullets hit (and damage) them
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	bulletParams.FilterDescendantsInstances = ignore
end

local function stepBullets(dt)
	if #bullets == 0 then
		return
	end
	refreshBulletFilter()
	local g = Vector3.new(0, -Config.BulletGravity, 0)
	for i = #bullets, 1, -1 do
		local b = bullets[i]
		local newVel = b.vel + g * dt
		local seg = (b.vel + newVel) * 0.5 * dt
		local res = workspace:Raycast(b.pos, seg, bulletParams)
		local dead = false
		if res then
			dead = true
			local model = res.Instance:FindFirstAncestorOfClass("Model")
			if res.Instance:GetAttribute("Structure") then
				Build.damage(res.Instance, b.damage * Config.GunStructureDamage)
			elseif model and Zombies.list[model] then
				local isHead = res.Instance.Name == "Head"
				local dmg = b.damage * (isHead and 2 or 1)
				local killed = Zombies.damage(model, dmg, b.player, isHead)
				if b.player and b.player.Parent then
					Remotes.HitMarker:FireClient(b.player, killed, isHead)
				end
			end
		end
		b.pos += seg
		b.vel = newVel
		b.life -= dt
		if dead or b.life <= 0 then
			table.remove(bullets, i)
		end
	end
end

local function fireGun(player, char, tool, def, aim, aiming)
	local mag = tool:GetAttribute("Mag") or 0
	if mag <= 0 or tool:GetAttribute("Reloading") then
		return
	end
	tool:SetAttribute("Mag", mag - 1)

	local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
	local origin = head.Position
	local toAim = aim - origin
	if toAim.Magnitude < 1 then
		return
	end
	local rarity = tool:GetAttribute("Rarity") or 1
	local r = Config.Rarities[rarity]
	local handle = tool:FindFirstChild("Handle")
	local att = handle and handle:FindFirstChild("Muzzle")
	local muzzle = att and att.WorldPosition or (handle and handle.Position) or origin

	local speed = def.velocity or 900
	-- raise the barrel just enough that the bullet lands on the crosshair out to def.zero studs
	local zeroDist = math.min(toAim.Magnitude, def.zero or 100)
	local lift = 0.5 * Config.BulletGravity * zeroDist / (speed * speed)
	local baseDir = (toAim.Unit + Vector3.new(0, lift, 0)).Unit
	local spread = def.spread * (aiming and (def.adsSpread or 0.4) or 1)
	local life = def.range / speed + 0.1

	for _ = 1, def.pellets do
		local dir = spreadDir(baseDir, spread)
		if #bullets < MAX_BULLETS then
			table.insert(bullets, { pos = origin, vel = dir * speed, life = life, damage = def.damage * r.mult, player = player })
		end
		Remotes.Tracer:FireAllClients(muzzle, dir * speed, r.color, life, player.UserId)
	end
end

local function swingMelee(player, char, tool, def)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local r = Config.Rarities[tool:GetAttribute("Rarity") or 1]
	local look = root.CFrame.LookVector
	local hitAny, killedAny = false, false

	for model, z in Zombies.list do
		if z.hum.Health > 0 and z.root.Parent then
			local offset = z.root.Position - root.Position
			local dist = offset.Magnitude
			if dist <= def.range + 1.5 * z.scale then
				local flat = Vector3.new(offset.X, 0, offset.Z)
				-- must be roughly in front of you (very close targets always count)
				if dist < 4 or (flat.Magnitude > 0.01 and flat.Unit:Dot(look) > 0.2) then
					hitAny = true
					if Zombies.damage(model, def.damage * r.mult, player, false) then
						killedAny = true
					elseif not z.def.boss then
						local kb = (flat.Magnitude > 0.01 and flat.Unit or look) * 38 + Vector3.new(0, 14, 0)
						z.root.AssemblyLinearVelocity = kb / z.scale
					end
				end
			end
		end
	end
	if hitAny then
		Remotes.HitMarker:FireClient(player, killedAny, false)
	end
end

function Combat.init()
	game:GetService("RunService").Heartbeat:Connect(stepBullets)

	Remotes.Attack.OnServerEvent:Connect(function(player, tool, aim, aiming)
		if typeof(tool) ~= "Instance" or not tool:IsA("Tool") or typeof(aim) ~= "Vector3" then
			return
		end
		local hum = Util.aliveHumanoid(player)
		local char = player.Character
		if not hum or not char or tool.Parent ~= char then
			return
		end
		local def = Config.Weapons[tool:GetAttribute("WeaponId")]
		if not def then
			return
		end
		local now = os.clock()
		if now < (nextFire[tool] or 0) then
			return
		end
		nextFire[tool] = now + def.cooldown * 0.9

		if def.kind == "Gun" then
			fireGun(player, char, tool, def, aim, aiming == true)
		else
			swingMelee(player, char, tool, def)
		end
	end)

	Remotes.Reload.OnServerEvent:Connect(function(player, tool)
		if typeof(tool) ~= "Instance" or not tool:IsA("Tool") then
			return
		end
		local hum = Util.aliveHumanoid(player)
		local char = player.Character
		if not hum or not char or tool.Parent ~= char then
			return
		end
		local def = Config.Weapons[tool:GetAttribute("WeaponId")]
		if not def or def.kind ~= "Gun" or tool:GetAttribute("Reloading") then
			return
		end
		if (tool:GetAttribute("Mag") or 0) >= def.mag or Inventory.count(player, "Ammo") <= 0 then
			return
		end
		tool:SetAttribute("Reloading", true)
		task.wait(def.reload)
		if tool.Parent ~= char then -- switched weapons / died: reload cancelled
			tool:SetAttribute("Reloading", false)
			return
		end
		local mag = tool:GetAttribute("Mag") or 0
		local take = math.min(def.mag - mag, Inventory.count(player, "Ammo"))
		Inventory.add(player, "Ammo", -take)
		tool:SetAttribute("Mag", mag + take)
		tool:SetAttribute("Reloading", false)
	end)
end

return Combat
