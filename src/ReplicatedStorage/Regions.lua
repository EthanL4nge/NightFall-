-- The map is split into 5 regions. Each has its own look, danger level and exclusive resources.
--   Greenfields (center circle)   Wood, Stone         - the safe-ish starting area
--   Frostlands  (north)           Iron, Frost Crystal
--   Desert      (east)            Gold
--   Darkwood    (west)            dense forest, best Wood
--   Ashlands    (south)           Diamond, Obsidian   - most dangerous
local Config = require(script.Parent:WaitForChild("Config"))

local Regions = {}

Regions.CenterRadius = 650

Regions.Info = {
	Greenfields = { name = "Greenfields", text = "Wood, Stone", danger = 0,
		ground = Color3.fromRGB(86, 140, 60), material = Enum.Material.Grass, hud = Color3.fromRGB(130, 230, 110) },
	Frostlands = { name = "Frostlands", text = "Iron, Frost Crystal", danger = 1,
		ground = Color3.fromRGB(225, 236, 245), material = Enum.Material.Snow, hud = Color3.fromRGB(160, 220, 255) },
	Desert = { name = "Redrock Desert", text = "Gold", danger = 1,
		ground = Color3.fromRGB(222, 190, 125), material = Enum.Material.Sand, hud = Color3.fromRGB(255, 205, 100) },
	Darkwood = { name = "Darkwood Forest", text = "Dense forest: best Wood", danger = 1,
		ground = Color3.fromRGB(40, 85, 50), material = Enum.Material.Grass, hud = Color3.fromRGB(90, 190, 110) },
	Ashlands = { name = "Ashlands", text = "Diamond, Obsidian - DEADLY", danger = 2,
		ground = Color3.fromRGB(52, 46, 52), material = Enum.Material.Basalt, hud = Color3.fromRGB(255, 110, 80) },
}

-- danger = extra "nights" of zombie strength when zombies spawn in that region
function Regions.at(x, z)
	local r = Regions.CenterRadius
	if x * x + z * z < r * r then
		return "Greenfields"
	end
	if math.abs(x) < math.abs(z) then
		return z < 0 and "Frostlands" or "Ashlands"
	end
	return x > 0 and "Desert" or "Darkwood"
end

return Regions
