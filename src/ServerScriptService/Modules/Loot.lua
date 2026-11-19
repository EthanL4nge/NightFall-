-- Fortnite-style looting: chests burst into glowing, rarity-colored pickups with light beams.
local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = require(RS:WaitForChild("Config"))
local Remotes = require(script.Parent.Remotes)
local Util = require(script.Parent.Util)
local Inventory = require(script.Parent.Inventory)
local Weapons = require(script.Parent.Weapons)

local Loot = {}
Loot.chests = {}

local rng = Random.new()
local folder = Util.folder("Loot")

local RED = Color3.fromRGB(255, 120, 120)

-- Rolls one drop from a loot table. Weapons get a rarity that improves on later nights.
function Loot.roll(night, tbl)
	local e = Config.pickWeighted(rng, tbl, function(x)
		return Config.lootWeight(x, night)
	end)
	if e.kind == "Weapon" then
		return { kind = "Weapon", id = e.id, rarity = Config.rollRarity(rng, night) }
	end
	return { kind = "Item", id = e.id, amount = rng:NextInteger(e.min, e.max) }
end

function Loot.spawnDrop(pos, drop)
	local y = Util.groundY(pos)
	local color, label
	if drop.kind == "Weapon" then
		local r = Config.Rarities[drop.rarity]
		color = r.color
		label = r.name .. " " .. Config.Weapons[drop.id].display
	else
		color = Config.Items[drop.id].color
		label = Config.Items[drop.id].name .. " x" .. drop.amount
	end

	local model = Instance.new("Model")
	model.Name = "Drop"

	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.new(1.6, 1.6, 1.6)
	core.Color = color
	core.Material = Enum.Material.Neon
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CFrame = CFrame.new(pos.X, y + 1.8, pos.Z) * CFrame.Angles(0.6, 0.6, 0)
	core.Parent = model

	local beam = Instance.new("Part")
	beam.Name = "Beam"
	beam.Size = Vector3.new(0.5, 26, 0.5)
	beam.Color = color
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.55
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CFrame = CFrame.new(pos.X, y + 13, pos.Z)
	beam.Parent = model

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 12
	light.Brightness = 1.5
	light.Parent = core

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 30)
	gui.StudsOffset = Vector3.new(0, 2.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 70
	gui.Parent = core
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = label
	text.TextColor3 = color
	text.Font = Enum.Font.GothamBold
	text.TextSize = 16
	text.TextStrokeTransparency = 0.4
	text.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = label
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = core

	prompt.Triggered:Connect(function(player)
		if model:GetAttribute("Claimed") then
			return
		end
		local hum, root = Util.aliveHumanoid(player)
		if not hum then
			return
		end
		if drop.kind == "Weapon" then
			local ok, replaced = Weapons.give(player, drop.id, drop.rarity, drop.mag, true)
			if not ok then
				Remotes.Notify:FireClient(player, "Hotbar full - equip a weapon to swap it", RED)
				return
			end
			model:SetAttribute("Claimed", true)
			model:Destroy()
			if replaced then
				Loot.spawnDrop(root.Position + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3)), {
					kind = "Weapon", id = replaced.id, rarity = replaced.rarity, mag = replaced.mag,
				})
			end
			Remotes.Notify:FireClient(player, "Picked up " .. label, color)
		else
			model:SetAttribute("Claimed", true)
			model:Destroy()
			Inventory.add(player, drop.id, drop.amount)
			Remotes.Notify:FireClient(player, "+" .. drop.amount .. " " .. Config.Items[drop.id].name, color)
		end
	end)

	model.Parent = folder
	Debris:AddItem(model, 240)
end

-- Chests ---------------------------------------------------------------------
local function setChestOpen(chest, open)
	chest.opened = open
	chest.prompt.Enabled = not open
	if open then
		chest.lid.CFrame = chest.cf * CFrame.new(0, 2.3, -1.6) * CFrame.Angles(math.rad(65), 0, 0)
		chest.light.Brightness = 0
	else
		chest.lid.CFrame = chest.cf * CFrame.new(0, 2.5, 0)
		chest.light.Brightness = 1.2
	end
end

local function openChest(chest)
	if chest.opened or chest.locked then
		return
	end
	setChestOpen(chest, true)
	local night = workspace:GetAttribute("Night") or 1
	local count = 1 + rng:NextInteger(0, 1) + (night >= 4 and 1 or 0) -- 1-3 items per chest
	local drops, hasWeapon = {}, false
	for i = 1, count do
		-- chests in dangerous places (city, caves, towers) roll as if it were a later night
		local d = Loot.roll(night + (chest.boost or 0), Config.LootTable)
		hasWeapon = hasWeapon or d.kind == "Weapon"
		drops[i] = d
	end
	-- weapon "pity": from night 3 a chest with no gun has a growing chance to hold one anyway
	if not hasWeapon and night >= 3 and rng:NextNumber() < math.min(0.5, 0.015 * night) then
		local guns = {}
		for _, e in Config.LootTable do
			if e.kind == "Weapon" then
				table.insert(guns, e)
			end
		end
		local e = Config.pickWeighted(rng, guns, function(x)
			return Config.lootWeight(x, night)
		end)
		drops[count] = { kind = "Weapon", id = e.id, rarity = Config.rollRarity(rng, night + (chest.boost or 0)) }
	end
	for i, d in drops do
		local a = (i / count) * math.pi * 2 + rng:NextNumber(0, 1)
		local p = chest.cf.Position + Vector3.new(math.cos(a) * 4, 0, math.sin(a) * 4)
		Loot.spawnDrop(p, d)
	end
end

-- Vault chests stay locked until their cave is cleared (see World.makeCave / Caves)
function Loot.lock(chest, locked, text)
	chest.locked = locked
	if locked then
		setChestOpen(chest, false)
		chest.prompt.Enabled = false
		chest.lid.Color = Color3.fromRGB(90, 60, 130)
		chest.light.Color = Color3.fromRGB(170, 90, 255)
	else
		chest.prompt.Enabled = not chest.opened
		chest.lid.Color = Color3.fromRGB(190, 110, 255)
	end
	if text then
		chest.prompt.ObjectText = text
	end
end

function Loot.createChest(cf, boost, vault)
	local model = Instance.new("Model")
	model.Name = "Chest"

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(4, 2, 2.6)
	base.Color = Color3.fromRGB(120, 75, 35)
	base.Material = Enum.Material.Wood
	base.Anchored = true
	base.CFrame = cf * CFrame.new(0, 1, 0)
	base.Parent = model

	local lid = Instance.new("Part")
	lid.Name = "Lid"
	lid.Size = Vector3.new(4.1, 1, 2.7)
	lid.Color = Color3.fromRGB(235, 185, 45)
	lid.Material = Enum.Material.Metal
	lid.Anchored = true
	lid.CanCollide = false
	lid.CFrame = cf * CFrame.new(0, 2.5, 0)
	lid.Parent = model

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 90)
	light.Range = 16
	light.Brightness = 1.2
	light.Parent = lid

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = "Loot Chest"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = base

	model.Parent = workspace

	local chest = { model = model, base = base, lid = lid, light = light, prompt = prompt, cf = cf, opened = false, boost = boost or 0, vault = vault }
	prompt.Triggered:Connect(function()
		openChest(chest)
	end)
	table.insert(Loot.chests, chest)
	return chest
end

-- Closes a fraction of opened chests again (called every dawn)
function Loot.refillChests(fraction)
	for _, chest in Loot.chests do
		if chest.vault then
			if fraction >= 1 then -- new run: vaults lock again
				Loot.lock(chest, true)
			end
		elseif chest.opened and rng:NextNumber() <= fraction then
			setChestOpen(chest, false)
		end
	end
end

function Loot.clearDrops()
	folder:ClearAllChildren()
end

return Loot
