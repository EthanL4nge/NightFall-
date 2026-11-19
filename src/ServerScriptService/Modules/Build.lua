-- Base building: walls, doorways, floors/roofs, ramps, one-key shelters, torches, spike traps, turrets.
-- Four materials (Wood < Stone < Iron < Obsidian) with rising HP. Zombies chew through walls that
-- block their way, so thicker materials = longer survival. Pieces need support: break the bottom and
-- everything resting on it collapses. See BuildShared for the placement math.
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(RS:WaitForChild("Config"))
local BuildShared = require(RS:WaitForChild("BuildShared"))
local Remotes = require(script.Parent.Remotes)
local Util = require(script.Parent.Util)
local Inventory = require(script.Parent.Inventory)

local Build = {}

local folder = Util.folder("Structures")
local queues = {} -- [player] = list of groups (oldest first)
local lastBuild = {}
local MAX_GROUPS_PER_PLAYER = 60
local DARK = Color3.fromRGB(35, 25, 20)

-- set by Main: called with (group, pieceId, player) after a piece is placed (turrets/spikes/torches)
Build.onPlaced = nil

local queueSupportCheck -- defined with the support code further down

local function notify(player, text)
	Remotes.Notify:FireClient(player, text, Color3.fromRGB(255, 120, 120))
end

function Build.place(player, pieceId, matName, level, look)
	local piece = Config.BuildPieces[pieceId]
	local hum, root = Util.aliveHumanoid(player)
	if not piece or not hum then
		return
	end
	local mat = Config.BuildMats[matName] or Config.BuildMats.Wood
	level = math.clamp(math.floor(tonumber(level) or 0), 0, 5)
	if typeof(look) ~= "Vector3" then
		look = root.CFrame.LookVector
	end
	local now = os.clock()
	if now - (lastBuild[player] or 0) < 0.2 then
		return
	end
	lastBuild[player] = now

	local cost = piece.mat and { [mat.res] = piece.cost } or piece.costs
	if not Inventory.canAfford(player, cost) then
		local parts = {}
		for id, n in cost do
			table.insert(parts, n .. " " .. Config.Items[id].name)
		end
		notify(player, "Need " .. table.concat(parts, ", "))
		return
	end

	local rp = root.Position
	local groundY = Util.terrainY(BuildShared.probe(rp, look))
	local specs = BuildShared.layout(pieceId, rp, look, groundY, level)
	if #specs == 0 then
		return
	end
	Inventory.spend(player, cost)

	local hp = piece.hp * (piece.mat and mat.hp or 1)
	local group = Instance.new("Model")
	group.Name = pieceId
	group:SetAttribute("Owner", player.UserId)
	for _, spec in specs do
		local p = Instance.new(spec.class)
		p.Name = spec.name
		p.Size = spec.size
		p.CFrame = spec.cf
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if piece.mat then
			p.Color = mat.color
			p.Material = mat.material
			p:SetAttribute("BaseColor", mat.color)
		else
			p.Color = spec.color or mat.color
			p.Material = spec.material or Enum.Material.Metal
			p:SetAttribute("BaseColor", p.Color)
		end
		p:SetAttribute("Structure", true)
		p:SetAttribute("Label", (piece.mat and (matName .. " ") or "") .. piece.name)
		p:SetAttribute("Health", hp)
		p:SetAttribute("MaxHealth", hp)
		p.Parent = group
	end
	group.Parent = folder

	local q = queues[player]
	if not q then
		q = {}
		queues[player] = q
	end
	table.insert(q, group)
	if #q > MAX_GROUPS_PER_PLAYER then
		local old = table.remove(q, 1)
		if old then
			for _, child in old:GetChildren() do
				if child:IsA("BasePart") then
					queueSupportCheck(child.CFrame, child.Size)
				end
			end
			old:Destroy()
		end
	end

	if Build.onPlaced then
		Build.onPlaced(group, pieceId, player)
	end
end

-- floating HP bar shown for a few seconds after a structure is hit
local function showHealth(part, hp, maxHp)
	local gui = part:FindFirstChild("HpBar")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "HpBar"
		gui.Size = UDim2.fromOffset(130, 30)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 90
		gui.Adornee = part
		local back = Instance.new("Frame")
		back.Name = "Back"
		back.Size = UDim2.new(1, 0, 0, 10)
		back.Position = UDim2.fromOffset(0, 18)
		back.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		back.BorderSizePixel = 0
		back.Parent = gui
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		fill.BorderSizePixel = 0
		fill.Parent = back
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.Size = UDim2.new(1, 0, 0, 16)
		text.BackgroundTransparency = 1
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeTransparency = 0.4
		text.Font = Enum.Font.GothamBold
		text.TextSize = 13
		text.Parent = gui
		gui.Parent = part
	end
	local frac = math.clamp(hp / maxHp, 0, 1)
	gui.Back.Fill.Size = UDim2.fromScale(frac, 1)
	gui.Back.Fill.BackgroundColor3 = Color3.fromRGB(220, 60, 50):Lerp(Color3.fromRGB(80, 210, 90), frac)
	gui.Text.Text = (part:GetAttribute("Label") or "Structure") .. "  " .. math.ceil(hp) .. "/" .. math.ceil(maxHp)
	gui.Enabled = true
	local token = (part:GetAttribute("HpToken") or 0) + 1
	part:SetAttribute("HpToken", token)
	task.delay(4, function()
		if part.Parent and part:GetAttribute("HpToken") == token and gui.Parent then
			gui.Enabled = false
		end
	end)
end

-- STRUCTURAL SUPPORT ------------------------------------------------------------------------------
-- A piece stands if it touches the ground, or touches another piece that stands. When pieces are
-- destroyed (zombies, explosions, old pieces being recycled) we look at everything around the hole;
-- any group of pieces that is no longer connected to the ground comes crashing down.
local debrisFolder = Util.folder("Debris")
local pendingBoxes = {}
local checkScheduled = false
local MAX_COMPONENT = 700 -- very large bases are treated as stable rather than flood-filled
local TOUCH_PAD = 0.7 -- how close two pieces must be to count as touching

local function structureParams()
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	return params
end

local function groundRayParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { folder, debrisFolder, Util.folder("Loot"), Util.folder("Zombies"), Util.folder("Nodes") }
	for _, pl in Players:GetPlayers() do
		if pl.Character then
			table.insert(ignore, pl.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	return params
end

local function isGrounded(part, rayParams)
	local cf, size = part.CFrame, part.Size
	local pts = {
		Vector3.new(0, -size.Y / 2, 0),
		Vector3.new(size.X * 0.45, -size.Y / 2, size.Z * 0.45),
		Vector3.new(-size.X * 0.45, -size.Y / 2, size.Z * 0.45),
		Vector3.new(size.X * 0.45, -size.Y / 2, -size.Z * 0.45),
		Vector3.new(-size.X * 0.45, -size.Y / 2, -size.Z * 0.45),
	}
	for _, local_ in pts do
		local origin = cf:PointToWorldSpace(local_) + Vector3.new(0, 0.6, 0)
		if workspace:Raycast(origin, Vector3.new(0, -2.2, 0), rayParams) then
			return true
		end
	end
	return false
end

local function neighbours(part, params)
	local out = {}
	for _, other in workspace:GetPartBoundsInBox(part.CFrame, part.Size + Vector3.new(TOUCH_PAD, TOUCH_PAD, TOUCH_PAD), params) do
		if other ~= part and other:GetAttribute("Structure") then
			table.insert(out, other)
		end
	end
	return out
end

local function collapse(parts)
	for _, part in parts do
		if part.Parent then
			local group = part.Parent
			part:SetAttribute("Structure", nil)
			part:SetAttribute("Health", nil)
			local bar = part:FindFirstChild("HpBar")
			if bar then
				bar:Destroy()
			end
			part.Parent = debrisFolder
			part.Anchored = false
			part.CanCollide = true
			part.AssemblyLinearVelocity = Vector3.new(math.random(-4, 4), -2, math.random(-4, 4))
			part.AssemblyAngularVelocity = Vector3.new(math.random(-3, 3), math.random(-3, 3), math.random(-3, 3))
			task.delay(5 + math.random() * 2, function()
				if part.Parent then
					part:Destroy()
				end
			end)
			if group and group:IsA("Model") and group ~= folder and #group:GetChildren() == 0 then
				group:Destroy()
			end
		end
	end
end

local function runSupportCheck()
	checkScheduled = false
	local boxes = pendingBoxes
	pendingBoxes = {}
	local params = structureParams()
	local rayParams = groundRayParams()

	-- pieces touching the holes we just made are the ones that may have lost their support
	local candidates = {}
	for _, box in boxes do
		for _, part in workspace:GetPartBoundsInBox(box.cf, box.size + Vector3.new(TOUCH_PAD, TOUCH_PAD, TOUCH_PAD) * 2, params) do
			if part:GetAttribute("Structure") then
				candidates[part] = true
			end
		end
	end

	local settled = {} -- pieces already known to be fine, or already collapsed this pass
	for start in candidates do
		if settled[start] or not start.Parent then
			continue
		end
		local seen = { [start] = true }
		local list = { start }
		local stack = { start }
		local grounded = isGrounded(start, rayParams)
		while #stack > 0 and not grounded do
			local cur = table.remove(stack)
			for _, nb in neighbours(cur, params) do
				if not seen[nb] and not settled[nb] then
					seen[nb] = true
					table.insert(list, nb)
					table.insert(stack, nb)
					if isGrounded(nb, rayParams) then
						grounded = true
						break
					end
				end
			end
			if #list > MAX_COMPONENT then
				grounded = true
			end
		end
		for part in seen do
			settled[part] = true
		end
		if not grounded then
			collapse(list)
		end
	end
end

function queueSupportCheck(cf, size)
	table.insert(pendingBoxes, { cf = cf, size = size })
	if not checkScheduled then
		checkScheduled = true
		task.delay(0.35, runSupportCheck) -- batch several breaks together
	end
end

function Build.damage(part, amount)
	local hp = part:GetAttribute("Health")
	if not hp then
		return
	end
	hp -= amount
	if hp <= 0 then
		local group = part.Parent
		local cf, size = part.CFrame, part.Size
		part:Destroy()
		queueSupportCheck(cf, size)
		-- a group with no solid parts left disappears entirely
		if group and group:IsA("Model") and group ~= folder and #group:GetChildren() == 0 then
			group:Destroy()
		end
		return
	end
	part:SetAttribute("Health", hp)
	showHealth(part, hp, part:GetAttribute("MaxHealth") or hp)
	local base = part:GetAttribute("BaseColor")
	if base then
		part.Color = base:Lerp(DARK, 0.6 * (1 - hp / part:GetAttribute("MaxHealth")))
	end
end

function Build.damageRadius(pos, radius, amount)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	for _, part in workspace:GetPartBoundsInRadius(pos, radius, params) do
		Build.damage(part, amount)
	end
end

function Build.clearAll()
	pendingBoxes = {}
	folder:ClearAllChildren()
	debrisFolder:ClearAllChildren()
	queues = {}
end

function Build.init()
	Remotes.Build.OnServerEvent:Connect(function(player, pieceId, matName, level, look)
		if typeof(pieceId) == "string" and typeof(matName) == "string" then
			Build.place(player, pieceId, matName, level, look)
		end
	end)
end

return Build
