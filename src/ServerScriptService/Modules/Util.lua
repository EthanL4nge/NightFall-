local Players = game:GetService("Players")

local Util = {}

function Util.folder(name)
	local f = workspace:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = workspace
	end
	return f
end

-- Y of the first surface below `pos` (ignores loot, zombies and player characters)
function Util.groundY(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { Util.folder("Loot"), Util.folder("Zombies") }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -80, 0), params)
	return hit and hit.Position.Y or 0
end

-- Like groundY but ignores player-built structures (used for building so pieces don't stack by accident)
function Util.terrainY(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { Util.folder("Loot"), Util.folder("Zombies"), Util.folder("Structures") }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -300, 0), params)
	return hit and hit.Position.Y or 0
end

-- Only players who are IN the current run count (lobby players are invisible to zombies, combat, building).
function Util.aliveHumanoid(player)
	if player:GetAttribute("InRun") ~= true then
		return nil, nil
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		return hum, char:FindFirstChild("HumanoidRootPart")
	end
	return nil, nil
end

return Util
