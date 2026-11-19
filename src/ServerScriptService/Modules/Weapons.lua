-- Builds weapon Tools as multi-part models (no assets needed).
-- Convention: the Handle is the part your hand holds; the weapon points toward the Handle's -Z.
-- Every extra part is welded to the Handle at an explicit offset. Neon "accent" parts and a light
-- glow in the weapon's rarity color, so epic/legendary gear is easy to spot.
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS:WaitForChild("Config"))

local Weapons = {}

local DARK = Color3.fromRGB(32, 33, 38)
local METAL = Color3.fromRGB(120, 123, 132)
local WOOD = Color3.fromRGB(122, 80, 44)
local GOLD = Color3.fromRGB(238, 192, 62)

local M = Enum.Material
local V = Vector3.new
local CF = CFrame.new
local function rotX(deg) return CFrame.Angles(math.rad(deg), 0, 0) end

-- { name, size, offset (Vector3 or CFrame, relative to the Handle), colorKey, material }
-- colorKey: body (weapon's own color), dark, metal, wood, gold, accent (rarity glow), trim (gold on Epic+)
local LAYOUT = {
	Pistol = {
		handle = V(0.38, 1.0, 0.55), muzzle = V(0, 0.78, -1.45),
		parts = {
			{ "Slide", V(0.42, 0.5, 1.7), V(0, 0.78, -0.35), "body", M.Metal },
			{ "Frame", V(0.38, 0.26, 1.4), V(0, 0.42, -0.4), "dark", M.Metal },
			{ "Port", V(0.44, 0.16, 0.4), V(0, 0.9, -0.3), "dark", M.Metal },
			{ "SlideStripe", V(0.44, 0.1, 1.1), V(0, 0.68, -0.4), "accent", M.Neon },
			{ "Barrel", V(0.2, 0.2, 0.35), V(0, 0.78, -1.3), "trim", M.Metal },
			{ "FrontSight", V(0.1, 0.16, 0.12), V(0, 1.1, -1.05), "dark", M.Metal },
			{ "RearSight", V(0.18, 0.14, 0.12), V(0, 1.1, 0.4), "dark", M.Metal },
			{ "Guard", V(0.08, 0.3, 0.55), V(0, 0.25, -0.65), "dark", M.Metal },
			{ "Hammer", V(0.12, 0.22, 0.14), V(0, 0.95, 0.55), "trim", M.Metal },
			{ "GripBase", V(0.42, 0.18, 0.6), V(0, -0.55, 0.0), "trim", M.Metal },
		},
	},
	SMG = {
		handle = V(0.38, 1.0, 0.55), muzzle = V(0, 0.85, -2.55),
		parts = {
			{ "Body", V(0.5, 0.6, 2.0), V(0, 0.8, -0.65), "body", M.Metal },
			{ "Mag", V(0.3, 1.2, 0.5), CF(0, 0.0, -1.0) * rotX(-8), "dark", M.Metal },
			{ "Shroud", V(0.4, 0.4, 0.8), V(0, 0.85, -1.95), "dark", M.Metal },
			{ "Barrel", V(0.16, 0.16, 0.55), V(0, 0.85, -2.45), "metal", M.Metal },
			{ "Stock", V(0.28, 0.45, 0.9), V(0, 0.75, 0.85), "dark", M.Metal },
			{ "StockPad", V(0.3, 0.6, 0.2), V(0, 0.75, 1.35), "trim", M.Metal },
			{ "Rail", V(0.46, 0.1, 1.5), V(0, 1.15, -0.65), "accent", M.Neon },
			{ "Sight", V(0.14, 0.22, 0.14), V(0, 1.27, -1.25), "dark", M.Metal },
			{ "Port", V(0.52, 0.2, 0.4), V(0, 0.9, -0.2), "dark", M.Metal },
		},
	},
	AssaultRifle = {
		handle = V(0.38, 1.0, 0.55), muzzle = V(0, 0.92, -3.85),
		parts = {
			{ "Receiver", V(0.5, 0.65, 1.8), V(0, 0.85, -0.5), "body", M.Metal },
			{ "Handguard", V(0.55, 0.5, 1.4), V(0, 0.8, -2.0), "wood", M.Wood },
			{ "Barrel", V(0.2, 0.2, 1.3), V(0, 0.92, -3.3), "metal", M.Metal },
			{ "MuzzleBrake", V(0.3, 0.3, 0.35), V(0, 0.92, -3.7), "dark", M.Metal },
			{ "Mag", V(0.32, 1.1, 0.55), CF(0, 0.05, -1.25) * rotX(-12), "dark", M.Metal },
			{ "Stock", V(0.42, 0.8, 1.4), V(0, 0.7, 1.0), "wood", M.Wood },
			{ "StockPad", V(0.44, 0.9, 0.2), V(0, 0.7, 1.75), "trim", M.Metal },
			{ "Rail", V(0.52, 0.1, 2.2), V(0, 1.23, -0.7), "accent", M.Neon },
			{ "RearSight", V(0.18, 0.28, 0.16), V(0, 1.35, 0.25), "dark", M.Metal },
			{ "FrontSight", V(0.1, 0.34, 0.12), V(0, 1.2, -3.0), "dark", M.Metal },
			{ "Port", V(0.54, 0.22, 0.45), V(0, 0.95, -0.15), "dark", M.Metal },
		},
	},
	Shotgun = {
		handle = V(0.38, 1.0, 0.55), muzzle = V(0, 0.95, -3.75),
		parts = {
			{ "Receiver", V(0.5, 0.6, 1.5), V(0, 0.8, -0.35), "metal", M.Metal },
			{ "Barrel", V(0.34, 0.34, 2.6), V(0, 0.97, -2.35), "body", M.Metal },
			{ "MagTube", V(0.26, 0.26, 2.2), V(0, 0.62, -2.15), "dark", M.Metal },
			{ "Pump", V(0.5, 0.42, 1.0), V(0, 0.62, -1.7), "wood", M.Wood },
			{ "Stock", V(0.42, 0.7, 1.5), V(0, 0.65, 1.05), "wood", M.Wood },
			{ "StockPad", V(0.44, 0.85, 0.2), V(0, 0.65, 1.85), "trim", M.Metal },
			{ "Muzzle", V(0.4, 0.4, 0.2), V(0, 0.97, -3.7), "dark", M.Metal },
			{ "Bead", V(0.1, 0.1, 0.1), V(0, 1.2, -3.55), "accent", M.Neon },
			{ "Shells", V(0.36, 0.16, 0.9), V(0, 0.55, 0.0), "accent", M.Neon },
		},
	},
	Sniper = {
		handle = V(0.38, 1.0, 0.55), muzzle = V(0, 0.88, -4.9),
		parts = {
			{ "Body", V(0.42, 0.6, 2.6), V(0, 0.85, -0.7), "body", M.Metal },
			{ "Barrel", V(0.2, 0.2, 2.8), V(0, 0.88, -3.4), "dark", M.Metal },
			{ "Suppressor", V(0.34, 0.34, 1.1), V(0, 0.88, -4.45), "metal", M.Metal },
			{ "Stock", V(0.42, 0.95, 1.7), V(0, 0.7, 1.15), "dark", M.Metal },
			{ "CheekRest", V(0.36, 0.2, 0.9), V(0, 1.25, 1.1), "wood", M.Wood },
			{ "Mag", V(0.3, 0.7, 0.55), V(0, 0.3, -0.9), "dark", M.Metal },
			{ "MountA", V(0.16, 0.22, 0.24), V(0, 1.25, -0.2), "dark", M.Metal },
			{ "MountB", V(0.16, 0.22, 0.24), V(0, 1.25, -1.2), "dark", M.Metal },
			{ "Scope", V(0.32, 0.32, 1.5), V(0, 1.5, -0.7), "dark", M.Metal },
			{ "ScopeRingA", V(0.4, 0.4, 0.12), V(0, 1.5, -0.2), "trim", M.Metal },
			{ "ScopeRingB", V(0.4, 0.4, 0.12), V(0, 1.5, -1.2), "trim", M.Metal },
			{ "LensFront", V(0.28, 0.28, 0.08), V(0, 1.5, -1.47), "accent", M.Neon },
			{ "LensRear", V(0.22, 0.22, 0.08), V(0, 1.5, 0.07), "accent", M.Neon },
			{ "BipodL", V(0.08, 0.9, 0.08), CF(-0.25, 0.1, -3.0) * rotX(15), "metal", M.Metal },
			{ "BipodR", V(0.08, 0.9, 0.08), CF(0.25, 0.1, -3.0) * rotX(15), "metal", M.Metal },
		},
	},
	Sword = {
		handle = V(0.36, 0.36, 1.3),
		parts = {
			{ "Guard", V(1.7, 0.28, 0.4), V(0, 0, -0.85), "trim", M.Metal },
			{ "GuardTipL", V(0.25, 0.4, 0.5), V(-0.85, 0, -0.85), "accent", M.Neon },
			{ "GuardTipR", V(0.25, 0.4, 0.5), V(0.85, 0, -0.85), "accent", M.Neon },
			{ "Blade", V(0.14, 0.75, 3.4), V(0, 0, -2.65), "body", "blade" },
			{ "Edge", V(0.1, 0.9, 3.4), V(0, 0, -2.65), "bladeedge", "blade" },
			{ "Fuller", V(0.17, 0.18, 3.0), V(0, 0, -2.55), "accent", M.Neon },
			{ "Point", V(0.14, 0.45, 0.5), V(0, 0, -4.55), "body", "blade" },
			{ "Pommel", V(0.5, 0.5, 0.5), V(0, 0, 0.8), "trim", M.Metal },
			{ "Wrap", V(0.4, 0.4, 0.2), V(0, 0, 0.05), "dark", M.Fabric },
		},
	},
}

local BLADE_MATERIAL = {
	WoodSword = M.Wood, StoneSword = M.Slate, IronSword = M.Metal, GoldSword = M.Metal,
	FrostBlade = M.Ice, DiamondSword = M.Glass, ObsidianSword = M.Glass,
}

function Weapons.createTool(id, rarity, mag)
	local def = Config.Weapons[id]
	local r = Config.Rarities[rarity]
	local layout = LAYOUT[def.kind == "Melee" and "Sword" or id]

	local tool = Instance.new("Tool")
	tool.Name = r.name .. " " .. def.display
	tool.ToolTip = tool.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = CFrame.new()
	tool:SetAttribute("WeaponId", id)
	tool:SetAttribute("Rarity", rarity)
	if def.kind == "Gun" then
		tool:SetAttribute("Mag", mag or def.mag)
		tool:SetAttribute("Reloading", false)
	end

	local function colorOf(key)
		if key == "body" then
			return def.color
		elseif key == "bladeedge" then
			return def.color:Lerp(Color3.new(1, 1, 1), 0.35)
		elseif key == "dark" then
			return DARK
		elseif key == "metal" then
			return METAL
		elseif key == "wood" then
			return WOOD
		elseif key == "gold" then
			return GOLD
		elseif key == "trim" then
			return rarity >= 4 and GOLD or METAL -- Epic and Legendary get gold trim
		end
		return r.color -- accent
	end

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = layout.handle
	handle.Color = def.kind == "Melee" and WOOD or DARK
	handle.Material = def.kind == "Melee" and M.Wood or M.Metal
	handle.CanCollide = false
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	-- night flashlight (guns only): what other players see; your own first-person view uses a client copy
	if def.kind == "Gun" then
		local fl = Instance.new("SpotLight")
		fl.Name = "Flashlight"
		fl.Face = Enum.NormalId.Front -- Front = the Handle's -Z, the direction the barrel points
		fl.Angle = Config.Flashlight.hipAngle
		fl.Range = Config.Flashlight.range
		fl.Brightness = Config.Flashlight.brightness
		fl.Color = Color3.fromRGB(255, 244, 214)
		fl.Shadows = false
		fl.Enabled = false
		fl.Parent = handle
		game:GetService("CollectionService"):AddTag(fl, "NFlash")
	end

	for _, spec in ipairs(layout.parts) do
		local part = Instance.new("Part")
		part.Name = spec[1]
		part.Size = spec[2]
		part.Color = colorOf(spec[4])
		part.Material = spec[5] == "blade" and (BLADE_MATERIAL[id] or M.Metal) or spec[5]
		part.CanCollide = false
		part.Massless = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		local weld = Instance.new("Weld") -- explicit offset: reliable for parts built outside the world
		weld.Part0 = handle
		weld.Part1 = part
		weld.C0 = typeof(spec[3]) == "CFrame" and spec[3] or CFrame.new(spec[3])
		weld.Parent = part
		part.Parent = tool
	end

	if layout.muzzle then
		local att = Instance.new("Attachment")
		att.Name = "Muzzle"
		att.Position = layout.muzzle
		att.Parent = handle
	end

	local light = Instance.new("PointLight")
	light.Color = r.color
	light.Range = 3 + rarity * 2
	light.Brightness = rarity <= 1 and 0 or (0.3 + rarity * 0.25) -- plain Common gear doesn't glow
	light.Parent = handle

	-- sparkles on Epic / Legendary
	if rarity >= 4 then
		local fx = Instance.new("ParticleEmitter")
		fx.Color = ColorSequence.new(r.color)
		fx.Rate = rarity == 5 and 14 or 7
		fx.Lifetime = NumberRange.new(0.5, 0.9)
		fx.Speed = NumberRange.new(0.5, 1.5)
		fx.SpreadAngle = Vector2.new(180, 180)
		fx.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
		fx.LightEmission = 1
		fx.Parent = handle
	end

	return tool
end

function Weapons.list(player)
	local out = {}
	local function scan(container)
		if container then
			for _, t in container:GetChildren() do
				if t:IsA("Tool") and t:GetAttribute("WeaponId") then
					table.insert(out, t)
				end
			end
		end
	end
	scan(player:FindFirstChildOfClass("Backpack"))
	scan(player.Character)
	return out
end

-- Gives a weapon. If the hotbar is full and allowSwap is true, the currently equipped
-- weapon is swapped out and returned as `replaced` so the caller can drop it on the ground.
function Weapons.give(player, id, rarity, mag, allowSwap)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 3)
	if not backpack then
		return false
	end
	local replaced = nil
	if #Weapons.list(player) >= Config.MaxWeapons then
		if not allowSwap then
			return false
		end
		local equipped = player.Character and player.Character:FindFirstChildOfClass("Tool")
		if not (equipped and equipped:GetAttribute("WeaponId")) then
			return false
		end
		replaced = {
			id = equipped:GetAttribute("WeaponId"),
			rarity = equipped:GetAttribute("Rarity"),
			mag = equipped:GetAttribute("Mag"),
		}
		equipped:Destroy()
	end
	Weapons.createTool(id, rarity or 1, mag).Parent = backpack
	return true, replaced
end

-- Removes all weapons and returns their info (used to drop them when you die)
function Weapons.stripAll(player)
	local infos = {}
	for _, t in Weapons.list(player) do
		table.insert(infos, {
			id = t:GetAttribute("WeaponId"),
			rarity = t:GetAttribute("Rarity"),
			mag = t:GetAttribute("Mag"),
		})
		t:Destroy()
	end
	return infos
end

return Weapons
