-- Crafting menu + consumables (bandage / medkit / shield potion).
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS:WaitForChild("Config"))
local Remotes = require(script.Parent.Remotes)
local Util = require(script.Parent.Util)
local Inventory = require(script.Parent.Inventory)
local Weapons = require(script.Parent.Weapons)

local Crafting = {}

local RED = Color3.fromRGB(255, 120, 120)
local GREEN = Color3.fromRGB(120, 255, 140)

local byId = {}
for _, r in ipairs(Config.Recipes) do
	byId[r.id] = r
end

local using = setmetatable({}, { __mode = "k" })

local function notify(player, text, color)
	Remotes.Notify:FireClient(player, text, color)
end

function Crafting.init()
	Remotes.Craft.OnServerEvent:Connect(function(player, id)
		if typeof(id) ~= "string" then
			return
		end
		local r = byId[id]
		if not r or not Util.aliveHumanoid(player) then
			return
		end
		if r.pick then
			local tier = player:GetAttribute("PickTier") or 0
			if tier >= r.pick then
				notify(player, "You already have that pickaxe", RED)
				return
			end
			if tier ~= r.pick - 1 then
				notify(player, "Craft the previous pickaxe first", RED)
				return
			end
		end
		if r.weapon and #Weapons.list(player) >= Config.MaxWeapons then
			notify(player, "Hotbar full", RED)
			return
		end
		if not Inventory.spend(player, r.cost) then
			notify(player, "Not enough materials", RED)
			return
		end
		if r.pick then
			player:SetAttribute("PickTier", r.pick)
		end
		if r.weapon then
			Weapons.give(player, r.weapon, 1)
		end
		if r.give then
			for item, n in r.give do
				Inventory.add(player, item, n)
			end
		end
		notify(player, "Crafted " .. r.name, GREEN)
	end)

	Remotes.UseItem.OnServerEvent:Connect(function(player, id)
		if typeof(id) ~= "string" then
			return
		end
		local def = Config.Use[id]
		if not def or using[player] then
			return
		end
		local hum = Util.aliveHumanoid(player)
		if not hum then
			return
		end
		if Inventory.count(player, id) < 1 then
			notify(player, "No " .. Config.Items[id].name .. " left", RED)
			return
		end
		if def.heal and hum.Health >= hum.MaxHealth then
			notify(player, "Already at full health", RED)
			return
		end
		if def.shield and (player:GetAttribute("Shield") or 0) >= 100 then
			notify(player, "Shield already full", RED)
			return
		end

		local char = player.Character
		using[player] = true
		notify(player, "Using " .. Config.Items[id].name .. "...", Config.Items[id].color)
		task.wait(def.time)
		using[player] = nil

		if hum.Health <= 0 or player.Character ~= char then
			return
		end
		if not Inventory.spend(player, { [id] = 1 }) then
			return
		end
		if def.heal then
			hum.Health = math.min(hum.MaxHealth, hum.Health + def.heal)
		end
		if def.shield then
			player:SetAttribute("Shield", math.min(100, (player:GetAttribute("Shield") or 0) + def.shield))
		end
	end)
end

return Crafting
