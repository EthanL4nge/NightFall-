-- Resources/consumables live as IntValues in player.Inventory (auto-replicates to the client HUD).
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS:WaitForChild("Config"))

local Inventory = {}

function Inventory.setup(player)
	local folder = player:FindFirstChild("Inventory")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Inventory"
		for _, id in ipairs(Config.ItemOrder) do
			local v = Instance.new("IntValue")
			v.Name = id
			v.Parent = folder
		end
		folder.Parent = player
	end
	for _, v in folder:GetChildren() do
		v.Value = 0
	end
	player:SetAttribute("PickTier", 0)
	player:SetAttribute("Shield", 0)
end

function Inventory.count(player, id)
	local folder = player:FindFirstChild("Inventory")
	local v = folder and folder:FindFirstChild(id)
	return v and v.Value or 0
end

function Inventory.add(player, id, n)
	local folder = player:FindFirstChild("Inventory")
	local v = folder and folder:FindFirstChild(id)
	if v then
		v.Value = math.max(0, v.Value + n)
	end
end

function Inventory.canAfford(player, cost)
	for id, n in cost do
		if Inventory.count(player, id) < n then
			return false
		end
	end
	return true
end

function Inventory.spend(player, cost)
	if not Inventory.canAfford(player, cost) then
		return false
	end
	for id, n in cost do
		Inventory.add(player, id, -n)
	end
	return true
end

return Inventory
