--[[ NIGHTFALL - shared config (ModuleScript in ReplicatedStorage, named "Config").
     Nearly everything you'd want to tune lives here: damage, spawn counts, recipes, loot odds. ]]

local Config = {}

-- Game flow ---------------------------------------------------------------
Config.MaxPlayers = 5 -- squad size: servers hold 5 players max, all on one team
Config.FinalNight = 40 -- the run is 40 nights; beat the final boss on this night to win
Config.BossNights = { [20] = "King", [40] = "Overlord" } -- boss fights (night 20 is mid-run, 40 is the finale)
-- PACE: one place to slow the whole game down (1.0 = the old, faster feel)
Config.Pace = {
	zombieSpeed = 0.85, -- zombies move this much as fast
	zombieAttack = 1.3, -- time between zombie hits is this many times longer
	spawnInterval = 1.5, -- seconds between zombie spawns x this
	maxAlive = 0.8, -- fewer zombies on screen at once
	day = 1.3, -- longer days to gather/build
	night = 1.15, -- longer nights
}
Config.DayLength = math.floor(150 * Config.Pace.day) -- seconds of daylight
-- FALL DAMAGE: 1 damage per stud fallen (a 102-stud fall = 102 damage = dead at 100 HP). Drops up to the
-- safe height (jumps, curbs, stairs) are free.
Config.CaveRespawnDelay = 14 -- seconds between new zombies appearing in a cave (was 4)
Config.CaveFirstSpawnDelay = 8 -- seconds before the first one after you enter range
-- night flashlight on guns. Roblox SpotLight "Angle" is the FULL cone width, so 30 = 15 degrees each side of the barrel
Config.Flashlight = { hipAngle = 30, adsAngle = 50, range = 20, brightness = 3.75 }
Config.GunStructureDamage = 1 -- bullets deal this x their damage to player-built structures (0 = guns pass through)
Config.FallDamagePerStud = 1
Config.FallSafeHeight = 12
Config.MaxWeapons = 6
Config.WalkSpeed = 15
Config.SprintSpeed = 22
Config.MapHalf = 1800 -- map is 3600 x 3600 studs (see Regions.lua for the 5 regions)
Config.RespawnBase = 5 -- respawn delay = base + perNight * currentNight
Config.RespawnPerNight = 3
Config.ZombieDropChance = 0.28
function Config.zombieDropChance(night)
	return math.min(0.5, Config.ZombieDropChance + 0.006 * (night - 1))
end

-- Rarity (index 1-5) -------------------------------------------------------
Config.Rarities = {
	{ name = "Common", color = Color3.fromRGB(190, 190, 190), weight = 70, mult = 1.0 },
	{ name = "Uncommon", color = Color3.fromRGB(110, 220, 90), weight = 22, mult = 1.15 },
	{ name = "Rare", color = Color3.fromRGB(70, 140, 255), weight = 6, mult = 1.35 },
	{ name = "Epic", color = Color3.fromRGB(190, 90, 255), weight = 1.8, mult = 1.6 },
	{ name = "Legendary", color = Color3.fromRGB(255, 190, 40), weight = 0.2, mult = 2.0 },
}

function Config.pickWeighted(rng, list, weightOf)
	local total = 0
	for _, e in ipairs(list) do
		total += weightOf(e)
	end
	local roll = rng:NextNumber() * total
	for _, e in ipairs(list) do
		roll -= weightOf(e)
		if roll <= 0 then
			return e
		end
	end
	return list[#list]
end

-- Later nights shift loot toward better rarities
function Config.rollRarity(rng, night)
	return Config.pickWeighted(rng, { 1, 2, 3, 4, 5 }, function(i)
		return Config.Rarities[i].weight * (1 + (i - 1) * 0.05 * (night - 1))
	end)
end

-- Items / resources ---------------------------------------------------------
Config.ItemOrder = { "Wood", "Stone", "Iron", "Gold", "Crystal", "Diamond", "Obsidian", "Ammo", "Bandage", "Medkit", "ShieldPotion" }
Config.Items = {
	Wood = { name = "Wood", color = Color3.fromRGB(190, 135, 80) },
	Stone = { name = "Stone", color = Color3.fromRGB(170, 170, 175) },
	Iron = { name = "Iron", color = Color3.fromRGB(235, 180, 140) },
	Gold = { name = "Gold", color = Color3.fromRGB(255, 205, 70) },
	Crystal = { name = "Frost Crystal", color = Color3.fromRGB(160, 225, 255) },
	Diamond = { name = "Diamond", color = Color3.fromRGB(80, 230, 240) },
	Obsidian = { name = "Obsidian", color = Color3.fromRGB(165, 100, 230) },
	Ammo = { name = "Ammo", color = Color3.fromRGB(255, 210, 80) },
	Bandage = { name = "Bandage", color = Color3.fromRGB(240, 240, 240) },
	Medkit = { name = "Medkit", color = Color3.fromRGB(255, 100, 100) },
	ShieldPotion = { name = "Shield Potion", color = Color3.fromRGB(100, 170, 255) },
}
Config.PickNames = { [0] = "Hands", "Wooden", "Stone", "Iron", "Diamond" }

-- Consumables: H / J / K on the keyboard
Config.Use = {
	Bandage = { heal = 25, time = 1.2 },
	Medkit = { heal = 100, time = 3 },
	ShieldPotion = { shield = 50, time = 2 },
}

-- Weapons -------------------------------------------------------------------
-- Melee swords are crafted (Common). Guns come from chests, drops and zombies.
Config.Weapons = {
	WoodSword = { kind = "Melee", display = "Wooden Sword", damage = 24, cooldown = 0.42, range = 8,
		color = Color3.fromRGB(150, 110, 60), size = Vector3.new(0.5, 0.5, 4) },
	StoneSword = { kind = "Melee", display = "Stone Sword", damage = 34, cooldown = 0.4, range = 8,
		color = Color3.fromRGB(140, 140, 145), size = Vector3.new(0.5, 0.5, 4) },
	IronSword = { kind = "Melee", display = "Iron Sword", damage = 48, cooldown = 0.38, range = 8.5,
		color = Color3.fromRGB(220, 220, 225), size = Vector3.new(0.5, 0.5, 4.2) },
	GoldSword = { kind = "Melee", display = "Gold Sword", damage = 58, cooldown = 0.37, range = 8.5,
		color = Color3.fromRGB(255, 205, 70), size = Vector3.new(0.5, 0.5, 4) },
	FrostBlade = { kind = "Melee", display = "Frost Blade", damage = 66, cooldown = 0.36, range = 9,
		color = Color3.fromRGB(160, 225, 255), size = Vector3.new(0.5, 0.5, 4) },
	DiamondSword = { kind = "Melee", display = "Diamond Sword", damage = 74, cooldown = 0.36, range = 9,
		color = Color3.fromRGB(80, 230, 240), size = Vector3.new(0.5, 0.5, 4.4) },

	ObsidianSword = { kind = "Melee", display = "Obsidian Sword", damage = 105, cooldown = 0.34, range = 9.5,
		color = Color3.fromRGB(70, 35, 110), size = Vector3.new(0.5, 0.5, 4.6) },

	Pistol = { kind = "Gun", display = "Pistol", damage = 22, cooldown = 0.26, mag = 12, reload = 1.1,
		range = 220, spread = 1.0, pellets = 1, auto = false,
		velocity = 650, zero = 90, adsFov = 58, adsSpread = 0.3,
		color = Color3.fromRGB(60, 60, 65), size = Vector3.new(0.4, 0.8, 1.4) },
	SMG = { kind = "Gun", display = "SMG", damage = 11, cooldown = 0.075, mag = 32, reload = 1.5,
		range = 180, spread = 3.0, pellets = 1, auto = true,
		velocity = 750, zero = 80, adsFov = 52, adsSpread = 0.35,
		color = Color3.fromRGB(45, 45, 50), size = Vector3.new(0.45, 0.9, 1.8) },
	AssaultRifle = { kind = "Gun", display = "Assault Rifle", damage = 21, cooldown = 0.12, mag = 30, reload = 1.9,
		range = 300, spread = 1.8, pellets = 1, auto = true,
		velocity = 950, zero = 120, adsFov = 45, adsSpread = 0.3,
		color = Color3.fromRGB(70, 80, 60), size = Vector3.new(0.45, 0.9, 2.8) },
	Shotgun = { kind = "Gun", display = "Shotgun", damage = 11, cooldown = 0.85, mag = 6, reload = 2.2,
		range = 70, spread = 6.0, pellets = 8, auto = false,
		velocity = 600, zero = 40, adsFov = 60, adsSpread = 0.6,
		color = Color3.fromRGB(110, 70, 40), size = Vector3.new(0.5, 0.8, 3) },
	Sniper = { kind = "Gun", display = "Sniper Rifle", damage = 110, cooldown = 1.5, mag = 4, reload = 2.5,
		range = 500, spread = 0.1, pellets = 1, auto = false,
		velocity = 1800, zero = 250, adsFov = 12, adsSpread = 0.02, scope = true,
		color = Color3.fromRGB(35, 40, 55), size = Vector3.new(0.4, 0.7, 3.6) },
}

-- Crafting (C key). pick = pickaxe tier granted; weapon = tool granted; give = items granted
Config.Recipes = {
	{ id = "WoodPick", name = "Wooden Pickaxe (mine Stone)", cost = { Wood = 8 }, pick = 1 },
	{ id = "StonePick", name = "Stone Pickaxe (mine Iron)", cost = { Wood = 4, Stone = 10 }, pick = 2 },
	{ id = "IronPick", name = "Iron Pickaxe (mine Diamond)", cost = { Wood = 4, Iron = 10 }, pick = 3 },
	{ id = "WoodSword", name = "Wooden Sword", cost = { Wood = 10 }, weapon = "WoodSword" },
	{ id = "StoneSword", name = "Stone Sword", cost = { Wood = 4, Stone = 12 }, weapon = "StoneSword" },
	{ id = "IronSword", name = "Iron Sword", cost = { Wood = 4, Iron = 10 }, weapon = "IronSword" },
	{ id = "DiamondPick", name = "Diamond Pickaxe (mine Obsidian)", cost = { Wood = 4, Diamond = 8 }, pick = 4 },
	{ id = "GoldSword", name = "Gold Sword", cost = { Wood = 4, Gold = 8 }, weapon = "GoldSword" },
	{ id = "FrostBlade", name = "Frost Blade", cost = { Wood = 4, Iron = 8, Crystal = 6 }, weapon = "FrostBlade" },
	{ id = "DiamondSword", name = "Diamond Sword", cost = { Wood = 4, Diamond = 6 }, weapon = "DiamondSword" },
	{ id = "ObsidianSword", name = "Obsidian Sword", cost = { Wood = 4, Obsidian = 8, Diamond = 4 }, weapon = "ObsidianSword" },
	{ id = "AmmoPack", name = "Ammo Pack x30", cost = { Iron = 2, Stone = 2 }, give = { Ammo = 30 } },
	{ id = "BandagePack", name = "Bandages x3", cost = { Wood = 6 }, give = { Bandage = 3 } },
	{ id = "Medkit", name = "Medkit", cost = { Iron = 3, Wood = 2 }, give = { Medkit = 1 } },
	{ id = "ShieldPotion", name = "Shield Potion", cost = { Diamond = 1, Stone = 4 }, give = { ShieldPotion = 1 } },
	{ id = "FrostPotion", name = "Shield Potion (Frost)", cost = { Crystal = 2, Stone = 2 }, give = { ShieldPotion = 1 } },
}

-- Building (B = build mode; G = quick wall, V = quick ramp) ----------------------------------
-- Pieces cost `cost` units of the chosen material, or fixed `costs`. HP is multiplied by the material.
Config.BuildOrder = { "Wall", "Doorway", "Floor", "Ramp", "Shelter", "Torch", "Spikes", "Turret" }
Config.BuildPieces = {
	Wall = { name = "Wall", cost = 8, hp = 600, mat = true },
	Doorway = { name = "Doorway", cost = 8, hp = 500, mat = true },
	Floor = { name = "Floor / Roof", cost = 6, hp = 450, mat = true },
	Ramp = { name = "Ramp", cost = 6, hp = 450, mat = true },
	Shelter = { name = "Shelter (room + roof)", cost = 34, hp = 600, mat = true },
	Torch = { name = "Torch", costs = { Wood = 3 }, hp = 80 },
	Spikes = { name = "Spike Trap", costs = { Iron = 4, Wood = 2 }, hp = 240 },
	Turret = { name = "Auto Turret", costs = { Iron = 8, Gold = 6, Ammo = 30 }, hp = 500 },
}
Config.BuildMatOrder = { "Wood", "Stone", "Iron", "Obsidian" }
Config.BuildMats = {
	Wood = { res = "Wood", hp = 0.6, color = Color3.fromRGB(160, 115, 65), material = Enum.Material.WoodPlanks },
	Stone = { res = "Stone", hp = 1.6, color = Color3.fromRGB(135, 135, 140), material = Enum.Material.Cobblestone },
	Iron = { res = "Iron", hp = 3, color = Color3.fromRGB(175, 180, 190), material = Enum.Material.DiamondPlate },
	Obsidian = { res = "Obsidian", hp = 6, color = Color3.fromRGB(45, 25, 70), material = Enum.Material.Slate },
}
Config.BulletGravity = 110 -- studs/s^2 pulling bullets down (bullet drop)
Config.TurretAmmoStart = 40
Config.TurretDamage = 16
Config.TurretRange = 75

-- Zombies -------------------------------------------------------------------
Config.Zombies = {
	Walker = { display = "Zombie", hp = 60, dmg = 10, speed = 10, scale = 1, minNight = 1, weight = 10,
		colors = { skin = Color3.fromRGB(88, 150, 70), shirt = Color3.fromRGB(0, 150, 170), pants = Color3.fromRGB(50, 50, 140) } },
	Runner = { display = "Runner", hp = 40, dmg = 8, speed = 19, scale = 0.9, minNight = 2, weight = 6,
		colors = { skin = Color3.fromRGB(125, 175, 85), shirt = Color3.fromRGB(170, 60, 60), pants = Color3.fromRGB(40, 40, 40) } },
	Brute = { display = "Brute", hp = 260, dmg = 26, speed = 8, scale = 1.5, minNight = 3, weight = 3,
		colors = { skin = Color3.fromRGB(60, 110, 55), shirt = Color3.fromRGB(100, 30, 30), pants = Color3.fromRGB(45, 35, 30) } },
	Exploder = { display = "Exploder", hp = 35, dmg = 0, speed = 15, scale = 1, minNight = 4, weight = 3, explode = true,
		colors = { skin = Color3.fromRGB(70, 200, 70), shirt = Color3.fromRGB(60, 190, 60), pants = Color3.fromRGB(50, 170, 50) } },
	Overlord = { display = "THE OVERLORD", hp = 30000, hpPerExtraPlayer = 9000, dmg = 70, speed = 15, scale = 3.6, boss = true,
		colors = { skin = Color3.fromRGB(40, 20, 55), shirt = Color3.fromRGB(20, 5, 30), pants = Color3.fromRGB(15, 10, 20) } },
	King = { display = "ZOMBIE KING", hp = 9000, hpPerExtraPlayer = 3000, dmg = 40, speed = 13, scale = 2.8, boss = true,
		colors = { skin = Color3.fromRGB(55, 95, 55), shirt = Color3.fromRGB(110, 20, 20), pants = Color3.fromRGB(30, 30, 30) } },
}

-- Night difficulty curve: every number here scales with the night count
function Config.nightStats(n)
	return {
		hp = 1 + 0.18 * (n - 1), -- x8 by night 40
		dmg = 1 + 0.08 * (n - 1), -- x4 by night 40
		speed = (1 + 0.012 * (n - 1)) * Config.Pace.zombieSpeed,
		total = 8 + 5 * n, -- zombies spawned this night (for 1 player)
		maxAlive = math.floor(math.min(18 + 2 * n, 70) * Config.Pace.maxAlive),
		interval = math.max(0.6, 3.0 - 0.1 * n) * Config.Pace.spawnInterval, -- seconds between spawns
		length = math.floor((90 + 4 * n) * Config.Pace.night), -- night length in seconds
	}
end

-- Loot tables ---------------------------------------------------------------
Config.LootTable = {
	-- weapons are only ~16% of rolls; the strong ones are very rare
	{ kind = "Weapon", id = "Pistol", w = 9 },
	{ kind = "Weapon", id = "SMG", w = 5 },
	{ kind = "Weapon", id = "AssaultRifle", w = 3, grow = 0.14 },
	{ kind = "Weapon", id = "Shotgun", w = 4 },
	{ kind = "Weapon", id = "Sniper", w = 0.8, grow = 0.14 },
	{ kind = "Weapon", id = "IronSword", w = 2, grow = 0.1 },
	-- supplies make up the bulk of every chest
	{ kind = "Item", id = "Ammo", w = 40, min = 15, max = 35 },
	{ kind = "Item", id = "Bandage", w = 24, min = 1, max = 3 },
	{ kind = "Item", id = "Wood", w = 24, min = 8, max = 20 },
	{ kind = "Item", id = "Stone", w = 18, min = 6, max = 14 },
	{ kind = "Item", id = "Iron", w = 9, min = 2, max = 6 },
	{ kind = "Item", id = "ShieldPotion", w = 5, min = 1, max = 1 },
	{ kind = "Item", id = "Medkit", w = 3, min = 1, max = 1 },
	{ kind = "Item", id = "Diamond", w = 1.2, min = 1, max = 2 },
}

-- Weapons get more common every night (strong guns faster) so you are never stuck unarmed late game.
-- Night 1: ~16% of chest rolls are weapons. Night 20: ~31%. Night 40: ~39% (plus a guaranteed-gun "pity" chance).
function Config.lootWeight(e, night)
	local n = math.min(night, 40) - 1
	if e.kind == "Weapon" then
		return e.w * (1 + n * (e.grow or 0.08))
	end
	if e.id == "Ammo" then
		return e.w * (1 + n * 0.03) -- keep guns fed
	end
	return e.w
end

Config.ZombieLoot = {
	{ kind = "Item", id = "Ammo", w = 40, min = 6, max = 15 },
	{ kind = "Item", id = "Bandage", w = 15, min = 1, max = 2 },
	{ kind = "Item", id = "ShieldPotion", w = 6, min = 1, max = 1 },
	{ kind = "Item", id = "Medkit", w = 3, min = 1, max = 1 },
	{ kind = "Weapon", id = "Pistol", w = 5 },
	{ kind = "Weapon", id = "SMG", w = 3 },
	{ kind = "Weapon", id = "Shotgun", w = 2 },
}

return Config
