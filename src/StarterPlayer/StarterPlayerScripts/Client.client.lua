--[[ NIGHTFALL - client (LocalScript in StarterPlayer > StarterPlayerScripts, named "Client").
     HUD, controls, weapon firing, crafting menu, bullet tracers. All UI is built in code. ]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(RS:WaitForChild("Config"))
local Regions = require(RS:WaitForChild("Regions"))
local BuildShared = require(RS:WaitForChild("BuildShared"))
local RunService = game:GetService("RunService")
local Remotes = RS:WaitForChild("Remotes")
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local inv = player:WaitForChild("Inventory")
local function cam()
	return workspace.CurrentCamera
end

local WHITE = Color3.new(1, 1, 1)
local RED = Color3.fromRGB(255, 90, 90)
local GREEN = Color3.fromRGB(70, 190, 90)
local GRAY = Color3.fromRGB(90, 90, 95)

-- UI helpers ----------------------------------------------------------------
local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function label(parent, props)
	local base = {
		BackgroundTransparency = 1, TextColor3 = WHITE, Font = Enum.Font.GothamBold,
		TextSize = 18, TextStrokeTransparency = 0.5, Text = "",
	}
	for k, v in props do
		base[k] = v
	end
	return new("TextLabel", base, parent)
end

local gui = new("ScreenGui", { Name = "NightfallHUD", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

-- Top: phase / timer / boss bar ---------------------------------------------
local phaseLabel = label(gui, { Size = UDim2.fromOffset(500, 34), Position = UDim2.new(0.5, -250, 0, 8), TextSize = 28 })
local subLabel = label(gui, { Size = UDim2.fromOffset(600, 22), Position = UDim2.new(0.5, -300, 0, 42), TextSize = 16 })
local bossFrame = new("Frame", { Size = UDim2.fromOffset(440, 20), Position = UDim2.new(0.5, -220, 0, 70),
	BackgroundColor3 = Color3.fromRGB(25, 25, 25), BorderSizePixel = 0, Visible = false }, gui)
local bossFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(190, 30, 30),
	BorderSizePixel = 0 }, bossFrame)
local bossName = label(bossFrame, { Size = UDim2.fromScale(1, 1), Text = "BOSS", TextSize = 14, ZIndex = 2 })

local function fmtTime(s)
	return string.format("%d:%02d", s // 60, s % 60)
end

local function refreshTop()
	local phase = workspace:GetAttribute("Phase") or "Day"
	if player:GetAttribute("InRun") ~= true then
		phaseLabel.Text = "LOBBY"
		phaseLabel.TextColor3 = Color3.fromRGB(190, 160, 255)
		subLabel.Text = ""
		bossFrame.Visible = false
		return
	end
	local night = workspace:GetAttribute("Night") or 1
	local t = workspace:GetAttribute("TimeLeft") or 0
	local zl = workspace:GetAttribute("ZombiesLeft") or 0
	if phase == "Day" then
		phaseLabel.Text = "DAY " .. night
		phaseLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
		subLabel.Text = "Night falls in " .. fmtTime(math.max(0, t))
	else
		phaseLabel.Text = "NIGHT " .. night .. " / " .. Config.FinalNight
		phaseLabel.TextColor3 = RED
		if t >= 0 then
			subLabel.Text = "Dawn in " .. fmtTime(t) .. "   |   Zombies left: " .. zl
		else
			subLabel.Text = "KILL " .. (workspace:GetAttribute("BossName") or "THE BOSS")
		end
	end
	local bossMax = workspace:GetAttribute("BossMax") or 0
	local bossHP = workspace:GetAttribute("BossHP") or 0
	bossName.Text = workspace:GetAttribute("BossName") or "BOSS"
	bossFrame.Visible = bossMax > 0 and bossHP > 0
	bossFill.Size = UDim2.fromScale(bossMax > 0 and math.clamp(bossHP / bossMax, 0, 1) or 0, 1)
end
for _, attr in { "Phase", "Night", "TimeLeft", "ZombiesLeft", "BossMax", "BossHP", "BossName" } do
	workspace:GetAttributeChangedSignal(attr):Connect(refreshTop)
end
player:GetAttributeChangedSignal("InRun"):Connect(refreshTop)
refreshTop()

-- Left: resources -------------------------------------------------------------
local order = Config.ItemOrder
local resFrame = new("Frame", { Size = UDim2.fromOffset(180, 34 + 22 * #order), Position = UDim2.new(0, 10, 0.3, 0),
	BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, BorderSizePixel = 0 }, gui)
new("UICorner", { CornerRadius = UDim.new(0, 8) }, resFrame)
local pickLabel = label(resFrame, { Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(8, 5),
	TextXAlignment = Enum.TextXAlignment.Left, TextSize = 15 })
local resLabels = {}
for i, id in ipairs(order) do
	resLabels[id] = label(resFrame, { Size = UDim2.new(1, -12, 0, 20), Position = UDim2.fromOffset(8, 8 + 22 * i),
		TextXAlignment = Enum.TextXAlignment.Left, TextSize = 15, TextColor3 = Config.Items[id].color })
end

-- Bottom: health / shield / ammo / hints -----------------------------------------
local function bar(y, color)
	local back = new("Frame", { Size = UDim2.fromOffset(320, 14), Position = UDim2.new(0.5, -160, 1, y),
		BackgroundColor3 = Color3.fromRGB(20, 20, 20), BackgroundTransparency = 0.3, BorderSizePixel = 0 }, gui)
	new("UICorner", { CornerRadius = UDim.new(0, 5) }, back)
	local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0 }, back)
	new("UICorner", { CornerRadius = UDim.new(0, 5) }, fill)
	local text = label(back, { Size = UDim2.fromScale(1, 1), TextSize = 11, ZIndex = 2 })
	return fill, text
end
local shieldFill, shieldText = bar(-126, Color3.fromRGB(70, 150, 255))
local healthFill, healthText = bar(-108, Color3.fromRGB(80, 210, 90))

local ammoLabel = label(gui, { Size = UDim2.fromOffset(240, 50), Position = UDim2.new(1, -250, 1, -130),
	TextSize = 38, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(255, 220, 100) })
label(gui, { Size = UDim2.fromOffset(700, 18), Position = UDim2.new(0, 10, 1, -24), TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 0.2,
	Text = "SHIFT sprint | E interact | C craft | RMB aim | B build | V ramp | G wall | F floor | R reload | H bandage J medkit K shield" })

-- Notifications / announcements -------------------------------------------------
local noteLabel = label(gui, { Size = UDim2.fromOffset(600, 28), Position = UDim2.new(0.5, -300, 0.7, 0),
	TextSize = 20, TextTransparency = 1, TextStrokeTransparency = 1 })
local noteToken = 0
local function notify(text, color)
	noteToken += 1
	local mine = noteToken
	noteLabel.Text = text
	noteLabel.TextColor3 = color or WHITE
	noteLabel.TextTransparency = 0
	noteLabel.TextStrokeTransparency = 0.5
	task.delay(2.2, function()
		if mine == noteToken then
			TweenService:Create(noteLabel, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local titleLabel = label(gui, { Size = UDim2.fromOffset(900, 80), Position = UDim2.new(0.5, -450, 0.2, 0),
	TextSize = 64, TextTransparency = 1, TextStrokeTransparency = 1 })
local titleSub = label(gui, { Size = UDim2.fromOffset(900, 30), Position = UDim2.new(0.5, -450, 0.2, 76),
	TextSize = 22, TextTransparency = 1, TextStrokeTransparency = 1 })
local titleToken = 0
local function announce(title, sub, color)
	titleToken += 1
	local mine = titleToken
	titleLabel.Text = title
	titleLabel.TextColor3 = color or WHITE
	titleSub.Text = sub or ""
	titleLabel.TextTransparency, titleLabel.TextStrokeTransparency = 0, 0.4
	titleSub.TextTransparency, titleSub.TextStrokeTransparency = 0, 0.4
	task.delay(4.5, function()
		if mine == titleToken then
			local info = TweenInfo.new(1)
			TweenService:Create(titleLabel, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			TweenService:Create(titleSub, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

Remotes.Notify.OnClientEvent:Connect(notify)
Remotes.Announce.OnClientEvent:Connect(announce)

-- Crosshair + hit marker + damage flash ----------------------------------------------
local crosshair = new("Frame", { Size = UDim2.fromOffset(4, 4), Position = UDim2.new(0.5, -2, 0.5, -2), BackgroundColor3 = WHITE,
	BorderSizePixel = 0 }, gui)
local hitMarker = label(gui, { Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0.5, -20, 0.5, -20),
	Text = "X", TextSize = 34, TextTransparency = 1, TextStrokeTransparency = 1 })
Remotes.HitMarker.OnClientEvent:Connect(function(killed, headshot)
	hitMarker.TextColor3 = killed and RED or (headshot and Color3.fromRGB(255, 220, 80) or WHITE)
	hitMarker.TextTransparency = 0
	TweenService:Create(hitMarker, TweenInfo.new(0.18), { TextTransparency = 1 }):Play()
end)

local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(200, 0, 0),
	BackgroundTransparency = 1, BorderSizePixel = 0, Active = false }, gui)

-- Bullet tracers: each shot is drawn as a streak flying along the same arc the server simulates ------
local tracers = {}
local tracerParams = RaycastParams.new()
tracerParams.FilterType = Enum.RaycastFilterType.Exclude

local vmMuzzleWorld = nil -- set by the first-person gun model below
Remotes.Tracer.OnClientEvent:Connect(function(from, vel, color, life, ownerId)
	if typeof(from) ~= "Vector3" or typeof(vel) ~= "Vector3" or vel.Magnitude < 1 then
		return
	end
	if ownerId == player.UserId and vmMuzzleWorld then
		from = vmMuzzleWorld -- your own bullets leave the gun you see in first person
	end
	local p = new("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Material = Enum.Material.Neon,
		Color = color, Transparency = 0.15, Size = Vector3.new(0.14, 0.14, 6), CFrame = CFrame.lookAt(from, from + vel),
	}, workspace)
	table.insert(tracers, { part = p, pos = from, vel = vel, life = life or 1 })
	-- muzzle flash
	local f = new("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Material = Enum.Material.Neon,
		Shape = Enum.PartType.Ball, Color = Color3.fromRGB(255, 230, 150), Size = Vector3.new(0.8, 0.8, 0.8),
		CFrame = CFrame.new(from),
	}, workspace)
	Debris:AddItem(f, 0.05)
end)

RunService.RenderStepped:Connect(function(dt)
	if #tracers == 0 then
		return
	end
	local ignore = {}
	for _, inst in { player.Character, workspace:FindFirstChild("Loot") } do
		table.insert(ignore, inst)
	end
	tracerParams.FilterDescendantsInstances = ignore
	local g = Vector3.new(0, -Config.BulletGravity, 0)
	for i = #tracers, 1, -1 do
		local t = tracers[i]
		local newVel = t.vel + g * dt
		local seg = (t.vel + newVel) * 0.5 * dt
		local dead = false
		local hit = workspace:Raycast(t.pos, seg, tracerParams)
		if hit then
			seg = hit.Position - t.pos
			dead = true
		end
		t.pos += seg
		t.vel = newVel
		t.life -= dt
		local len = math.max(6, seg.Magnitude * 1.2)
		t.part.Size = Vector3.new(0.14, 0.14, len)
		t.part.CFrame = CFrame.lookAt(t.pos, t.pos + t.vel) * CFrame.new(0, 0, len / 2)
		if dead or t.life <= 0 then
			t.part:Destroy()
			table.remove(tracers, i)
		end
	end
end)

-- Inventory display / crafting menu ----------------------------------------------------
local craftFrame = new("Frame", { Size = UDim2.fromOffset(460, 430), Position = UDim2.new(0.5, -230, 0.5, -215),
	BackgroundColor3 = Color3.fromRGB(20, 22, 28), BackgroundTransparency = 0.08, BorderSizePixel = 0, Visible = false }, gui)
new("UICorner", { CornerRadius = UDim.new(0, 10) }, craftFrame)
label(craftFrame, { Size = UDim2.new(1, 0, 0, 38), Text = "CRAFTING   (press C to close)", TextSize = 20 })
-- first person locks the mouse; a visible Modal button frees the cursor so the menu can be clicked
new("TextButton", { Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Text = "", Modal = true }, craftFrame)
local list = new("ScrollingFrame", { Size = UDim2.new(1, -20, 1, -50), Position = UDim2.fromOffset(10, 44),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y }, craftFrame)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)

local rows = {}
for i, r in ipairs(Config.Recipes) do
	local row = new("Frame", { Size = UDim2.new(1, -10, 0, 48), BackgroundColor3 = Color3.fromRGB(40, 44, 54),
		BorderSizePixel = 0, LayoutOrder = i }, list)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, row)
	label(row, { Size = UDim2.new(0.65, 0, 0, 22), Position = UDim2.fromOffset(10, 3), Text = r.name, TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left })
	local costs = {}
	for item, n in r.cost do
		table.insert(costs, n .. " " .. Config.Items[item].name)
	end
	table.sort(costs)
	label(row, { Size = UDim2.new(0.65, 0, 0, 18), Position = UDim2.fromOffset(10, 26), Text = table.concat(costs, ", "),
		TextSize = 13, Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(190, 190, 200),
		TextXAlignment = Enum.TextXAlignment.Left })
	local btn = new("TextButton", { Size = UDim2.fromOffset(84, 32), Position = UDim2.new(1, -92, 0.5, -16), Text = "Craft",
		Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = WHITE, BackgroundColor3 = GREEN, BorderSizePixel = 0 }, row)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, btn)
	btn.Activated:Connect(function()
		Remotes.Craft:FireServer(r.id)
	end)
	rows[r.id] = { btn = btn, recipe = r }
end

local function refreshInventory()
	for _, id in ipairs(order) do
		resLabels[id].Text = Config.Items[id].name .. ": " .. inv[id].Value
	end
	local tier = player:GetAttribute("PickTier") or 0
	pickLabel.Text = "Pickaxe: " .. Config.PickNames[tier]
	for _, row in rows do
		local owned = row.recipe.pick and tier >= row.recipe.pick
		local ok = true
		for item, n in row.recipe.cost do
			if inv[item].Value < n then
				ok = false
			end
		end
		row.btn.Text = owned and "Owned" or "Craft"
		row.btn.BackgroundColor3 = (ok and not owned) and GREEN or GRAY
	end
end
for _, v in inv:GetChildren() do
	v.Changed:Connect(refreshInventory)
end
player:GetAttributeChangedSignal("PickTier"):Connect(refreshInventory)
refreshInventory()

-- Weapon handling ----------------------------------------------------------------------
local equipped = nil
local equipConns = {}
local firing = false
local sprinting = false

local function updateAmmo()
	local def = equipped and Config.Weapons[equipped:GetAttribute("WeaponId")]
	if def and def.kind == "Gun" then
		if equipped:GetAttribute("Reloading") then
			ammoLabel.Text = "RELOADING"
		else
			ammoLabel.Text = (equipped:GetAttribute("Mag") or 0) .. " / " .. inv.Ammo.Value
		end
	else
		ammoLabel.Text = ""
	end
end
inv.Ammo.Changed:Connect(updateAmmo)

local function tryReload()
	local def = equipped and Config.Weapons[equipped:GetAttribute("WeaponId")]
	if not def or def.kind ~= "Gun" or equipped:GetAttribute("Reloading") then
		return
	end
	if (equipped:GetAttribute("Mag") or 0) >= def.mag then
		return
	end
	if inv.Ammo.Value <= 0 then
		notify("Out of ammo!", RED)
		return
	end
	Remotes.Reload:FireServer(equipped)
end

-- Aiming down sights (hold RIGHT MOUSE), recoil, sway and scopes ------------------------------------
local BASE_FOV = 70
local VM_SCALE = 0.6 -- first-person gun size (1 = full size). Lower = smaller gun on screen
local RECOIL_SCALE = 0.6 -- recoil strength (same pattern, just weaker). 0.5 = half, 0.75 = three quarters
local ADS_DROP = 0.3 -- how far (studs) the gun sits below the crosshair line when aiming. Raise it to push the gun lower on screen.
local aimHeld = false
local shiftDown = false
local adsAlpha = 0
local recoilPitch, recoilYaw = 0, 0
local breath = 4 -- seconds of held breath available (sniper scope, hold SHIFT)
local exhausted = false

local function curDef()
	return equipped and Config.Weapons[equipped:GetAttribute("WeaponId")]
end

local function isAiming()
	local d = curDef()
	return aimHeld and d ~= nil and d.kind == "Gun" and not equipped:GetAttribute("Reloading")
end

local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude
-- where the crosshair is pointing in the world (the server shoots toward this point)
local function aimPoint()
	local c = cam()
	local ignore = { player.Character, workspace:FindFirstChild("Loot"), workspace:FindFirstChild("Structures") }
	local clean = {}
	for _, i in ignore do
		if i then
			table.insert(clean, i)
		end
	end
	aimParams.FilterDescendantsInstances = clean
	local res = workspace:Raycast(c.CFrame.Position, c.CFrame.LookVector * 600, aimParams)
	return res and res.Position or (c.CFrame.Position + c.CFrame.LookVector * 600)
end

-- scope overlay: black everywhere except a circle, plus a reticle
local scope = new("Frame", { Name = "Scope", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Active = false }, gui)
local function blackBox()
	return new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, scope)
end
local boxT, boxB, boxL, boxR = blackBox(), blackBox(), blackBox(), blackBox()
local ring = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1 }, scope)
new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
local ringStroke = new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 200, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, ring)
local hLine = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, scope)
local vLine = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, scope)
new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(4, 4), BackgroundColor3 = Color3.fromRGB(255, 40, 40), BorderSizePixel = 0 }, scope)
local breathLabel = label(scope, { Size = UDim2.fromOffset(300, 20), Position = UDim2.new(0.5, -150, 0.5, 40), TextSize = 14, TextColor3 = WHITE })

local function layoutScope()
	local vp = cam().ViewportSize
	local D = math.floor(math.min(vp.X, vp.Y) * 0.92)
	local cx, cy = vp.X / 2, vp.Y / 2
	ring.Size = UDim2.fromOffset(D, D)
	ringStroke.Thickness = math.ceil(D * 0.22)
	boxT.Size, boxT.Position = UDim2.fromOffset(vp.X, math.max(0, cy - D / 2)), UDim2.fromOffset(0, 0)
	boxB.Size, boxB.Position = UDim2.fromOffset(vp.X, math.max(0, cy - D / 2)), UDim2.fromOffset(0, cy + D / 2)
	boxL.Size, boxL.Position = UDim2.fromOffset(math.max(0, cx - D / 2), D), UDim2.fromOffset(0, cy - D / 2)
	boxR.Size, boxR.Position = UDim2.fromOffset(math.max(0, cx - D / 2), D), UDim2.fromOffset(cx + D / 2, cy - D / 2)
	hLine.Size = UDim2.fromOffset(D, 2)
	vLine.Size = UDim2.fromOffset(2, D)
end

local function setSpeed()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		local speed = sprinting and Config.SprintSpeed or Config.WalkSpeed
		if adsAlpha > 0.3 then
			speed = Config.WalkSpeed * 0.6
		end
		hum.WalkSpeed = speed
	end
end

-- First-person gun model: the real tool is hidden for you and a copy is drawn in front of the camera,
-- so it can sit at the hip, move to the center when aiming, and drop out of view behind a sniper scope.
local vm = nil
local reloadDip = 0

local function destroyVm()
	if vm then
		for _, item in vm.list do
			if item.real.Parent then
				item.real.LocalTransparencyModifier = 0
			end
		end
		vm.model:Destroy()
		vm = nil
	end
	vmMuzzleWorld = nil
end

local function buildVm(tool)
	destroyVm()
	task.spawn(function()
		task.wait(0.2) -- let the tool's welds settle after equipping
		if equipped ~= tool then
			return
		end
		local handle = tool:FindFirstChild("Handle")
		if not handle then
			return
		end
		local model = Instance.new("Model")
		model.Name = "ViewModel"
		local list = {}
		for _, d in tool:GetDescendants() do
			if d:IsA("BasePart") then
				local c = d:Clone()
				for _, ch in c:GetChildren() do
					if ch:IsA("JointInstance") or ch:IsA("WeldConstraint") or ch:IsA("BaseScript") then
						ch:Destroy()
					end
				end
				c.Size = c.Size * VM_SCALE
				c.Anchored = true
				c.CanCollide = false
				c.CanQuery = false
				c.CanTouch = false
				c.Massless = true
				c.Parent = model
				table.insert(list, { part = c, real = d, rel = (function()
						local r = handle.CFrame:ToObjectSpace(d.CFrame)
						return r - r.Position + r.Position * VM_SCALE
					end)() })
			end
		end
		local att = handle:FindFirstChild("Muzzle")
		local muzzleLocal = (att and att:IsA("Attachment") and att.Position or Vector3.new(0, 0, -1.5)) * VM_SCALE
		-- weapons point toward the Handle's -Z, so the handle frame already faces forward; barrelH is how far the
		-- barrel/sights sit above the handle center, which is what we cancel out to see down the sights
		vm = { model = model, list = list, handle = handle, inv = CFrame.new(), muzzle = muzzleLocal,
			barrelH = math.clamp(muzzleLocal.Y, 0.12, 1.1) }
		for _, item in list do
			if item.real == handle then
				vm.light = item.part:FindFirstChild("Flashlight")
			end
		end
		model.Parent = cam()
	end)
end

local lastAiming = false
RunService:BindToRenderStep("NightfallAim", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local c = cam()
	local d = curDef()
	local aiming = isAiming() and not (sprinting and not (d and d.scope))
	local target = aiming and 1 or 0
	adsAlpha += (target - adsAlpha) * math.min(1, dt * 12)
	if math.abs(target - adsAlpha) < 0.01 then
		adsAlpha = target
	end
	if aiming ~= lastAiming then
		lastAiming = aiming
		setSpeed()
	end
	local fov = BASE_FOV
	if d and d.adsFov then
		fov = BASE_FOV + (d.adsFov - BASE_FOV) * adsAlpha
	end
	c.FieldOfView = fov
	UIS.MouseDeltaSensitivity = math.clamp(fov / BASE_FOV, 0.12, 1)
	-- the crosshair stays in the exact middle of the screen; scoped guns use the scope reticle instead.
	-- when aiming without a scope it shrinks to a small dot since the gun no longer covers the center.
	crosshair.Visible = player:GetAttribute("InRun") == true and not (d ~= nil and d.scope == true and adsAlpha > 0.5)
	local dotSize = 4 - 1 * adsAlpha
	crosshair.Size = UDim2.fromOffset(dotSize, dotSize)
	crosshair.Position = UDim2.new(0.5, -dotSize / 2, 0.5, -dotSize / 2)
	local scoped = d ~= nil and d.scope == true and adsAlpha > 0.9
	scope.Visible = scoped
	if scoped then
		layoutScope()
	end

	-- holding breath steadies a scoped sniper for a few seconds
	local holding = scoped and shiftDown and not exhausted and breath > 0
	if holding then
		breath = math.max(0, breath - dt)
		if breath <= 0 then
			exhausted = true
		end
	else
		breath = math.min(4, breath + dt * 0.6)
		if exhausted and breath > 2 then
			exhausted = false
		end
	end
	breathLabel.Text = scoped and (holding and "HOLDING BREATH" or (exhausted and "OUT OF BREATH" or "SHIFT: hold breath")) or ""

	-- sway (bigger the more zoomed, gone when breath held) + recoil that settles back
	local t = os.clock()
	local amp = 0
	if adsAlpha > 0.05 and d and d.scope then -- only scoped weapons (snipers) sway
		amp = 0.0028 * adsAlpha * (fov / BASE_FOV + 0.3) * (holding and 0.08 or 1)
		local walking = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if walking and walking.MoveDirection.Magnitude > 0.1 then
			amp *= 2.2
		end
	end
	local sx = (math.sin(t * 1.3) + math.sin(t * 2.9) * 0.4) * amp
	local sy = (math.cos(t * 1.1) + math.sin(t * 2.3) * 0.5) * amp
	recoilPitch *= math.exp(-dt * 7)
	recoilYaw *= math.exp(-dt * 7)
	c.CFrame = c.CFrame * CFrame.Angles(sx + recoilPitch, sy + recoilYaw, 0)

	-- first-person gun: hip -> center when aiming, dropped well below the view when scoped
	if vm and vm.handle.Parent and equipped then
		local reloading = equipped:GetAttribute("Reloading") == true
		reloadDip += ((reloading and 1 or 0) - reloadDip) * math.min(1, dt * 8)
		local hip = Vector3.new(0.85, -0.8, -1.0)
		-- aiming: barrel centered on the crosshair, gun flat and level (Phantom Forces style); scopes drop the gun away
		local ads = (d and d.scope) and Vector3.new(0.4, -3.6, -1.0) or Vector3.new(0, -(vm.barrelH + 0.1) - ADS_DROP, -1.0)
		local pos = hip:Lerp(ads, adsAlpha) + Vector3.new(0, -0.9 * reloadDip, 0)
		local handleCF = c.CFrame * CFrame.new(pos.X, pos.Y, pos.Z + recoilPitch * 5) * CFrame.Angles(recoilPitch * 3, 0, -0.25 * reloadDip) * vm.inv
		for _, item in vm.list do
			item.part.CFrame = handleCF * item.rel
			if item.real.Parent then
				item.real.LocalTransparencyModifier = 1
			end
		end
		vmMuzzleWorld = handleCF:PointToWorldSpace(vm.muzzle)
		-- flashlight: 30 degree cone from the hip, widening to 50 when aiming down sights; night only
		if vm.light then
			vm.light.Enabled = workspace:GetAttribute("Phase") == "Night"
			vm.light.Angle = Config.Flashlight.hipAngle + (Config.Flashlight.adsAngle - Config.Flashlight.hipAngle) * adsAlpha
		end
		-- hide the real gun's light from yourself so you only see the first-person one
		local realLight = vm.handle:FindFirstChild("Flashlight")
		if realLight and realLight.Enabled then
			realLight.Enabled = false
		end
	end
end)

UIS.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		aimHeld = true
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		shiftDown = true
	end
end)
UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		aimHeld = false
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		shiftDown = false
	end
end)

local function fireOnce(tool)
	local def = Config.Weapons[tool:GetAttribute("WeaponId")]
	if def.kind == "Gun" then
		if tool:GetAttribute("Reloading") then
			return
		end
		if (tool:GetAttribute("Mag") or 0) <= 0 then
			tryReload()
			return
		end
	else
		local v = Instance.new("StringValue") -- tells Roblox's default animate script to swing
		v.Name = "toolanim"
		v.Value = "Slash"
		v.Parent = tool
	end
	local aiming = isAiming()
	Remotes.Attack:FireServer(tool, aimPoint(), aiming)
	if def.kind == "Gun" then
		local kick = (0.010 + (def.damage or 10) * 0.0003) * (aiming and 0.6 or 1) * (def.pellets > 1 and 0.6 or 1) * RECOIL_SCALE
		recoilPitch += kick
		recoilYaw += math.rad(math.random(-10, 10) / 25) * (aiming and 0.5 or 1) * RECOIL_SCALE
	end
end

local function unequip()
	destroyVm()
	for _, c in equipConns do
		c:Disconnect()
	end
	equipConns = {}
	equipped = nil
	firing = false
	updateAmmo()
end

local function equip(tool)
	unequip()
	equipped = tool
	local def = Config.Weapons[tool:GetAttribute("WeaponId")]
	if def.kind == "Gun" then
		buildVm(tool)
	end
	table.insert(equipConns, tool:GetAttributeChangedSignal("Mag"):Connect(updateAmmo))
	table.insert(equipConns, tool:GetAttributeChangedSignal("Reloading"):Connect(updateAmmo))
	table.insert(equipConns, tool.Activated:Connect(function()
		firing = true
		task.spawn(function()
			repeat
				fireOnce(tool)
				task.wait(def.cooldown)
			until not (firing and equipped == tool and (def.auto or def.kind == "Melee"))
		end)
	end))
	table.insert(equipConns, tool.Deactivated:Connect(function()
		firing = false
	end))
	updateAmmo()
end


local function bindCharacter(char)
	sprinting = false
	unequip()
	char.ChildAdded:Connect(function(c)
		if c:IsA("Tool") and c:GetAttribute("WeaponId") then
			equip(c)
		end
	end)
	char.ChildRemoved:Connect(function(c)
		if c == equipped then
			unequip()
		end
	end)
	for _, c in char:GetChildren() do
		if c:IsA("Tool") and c:GetAttribute("WeaponId") then
			equip(c)
		end
	end

	local hum = char:WaitForChild("Humanoid")
	local last = hum.Health
	local function refreshHealth()
		healthFill.Size = UDim2.fromScale(math.clamp(hum.Health / hum.MaxHealth, 0, 1), 1)
		healthText.Text = math.ceil(hum.Health) .. " HP"
		if hum.Health < last - 0.5 then
			flash.BackgroundTransparency = 0.6
			TweenService:Create(flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		end
		last = hum.Health
	end
	hum.HealthChanged:Connect(refreshHealth)
	refreshHealth()
end

local function refreshShield()
	local s = player:GetAttribute("Shield") or 0
	shieldFill.Size = UDim2.fromScale(math.clamp(s / 100, 0, 1), 1)
	shieldText.Text = math.ceil(s) .. " SHIELD"
end
player:GetAttributeChangedSignal("Shield"):Connect(refreshShield)
refreshShield()

player.CharacterAdded:Connect(bindCharacter)
if player.Character then
	task.spawn(bindCharacter, player.Character)
end


-- Region label ---------------------------------------------------------------------------
local regionLabel = label(gui, { Size = UDim2.fromOffset(400, 26), Position = UDim2.new(0.5, -200, 0, 56), TextSize = 18,
	TextTransparency = 0.15 })
local lastRegion
task.spawn(function()
	while true do
		task.wait(0.5)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			local r = Regions.at(root.Position.X, root.Position.Z)
			local info = Regions.Info[r]
			regionLabel.Text = info.name .. (info.danger > 0 and string.rep("  !", info.danger) or "")
			regionLabel.TextColor3 = info.hud
			if r ~= lastRegion then
				lastRegion = r
				notify(info.name .. ": " .. info.text, info.hud)
			end
		end
	end
end)

-- Build mode -----------------------------------------------------------------------------
local buildMode = false
local pieceIdx, matIdx, level = 1, 1, 0
local ghost = new("Part", { Name = "Ghost", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
	Material = Enum.Material.ForceField, Transparency = 0.35, Color = GREEN, Size = Vector3.new(4, 4, 4) }, nil)
local buildLabel = label(gui, { Size = UDim2.fromOffset(820, 64), Position = UDim2.new(0.5, -410, 1, -200), TextSize = 16,
	Visible = false })

local function ghostParams()
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local ign = { workspace:FindFirstChild("Loot"), workspace:FindFirstChild("Zombies"), workspace:FindFirstChild("Structures"), ghost }
	if player.Character then
		table.insert(ign, player.Character)
	end
	local clean = {}
	for _, i in ign do
		if i then
			table.insert(clean, i)
		end
	end
	rp.FilterDescendantsInstances = clean
	return rp
end

local function currentCost()
	local id = Config.BuildOrder[pieceIdx]
	local piece = Config.BuildPieces[id]
	local mat = Config.BuildMatOrder[matIdx]
	if piece.mat then
		return { [Config.BuildMats[mat].res] = piece.cost }, piece.name .. " (" .. mat .. ")"
	end
	return piece.costs, piece.name or id
end

local function refreshBuildLabel()
	local cost, name = currentCost()
	local parts, ok = {}, true
	for res, n in cost do
		table.insert(parts, n .. " " .. Config.Items[res].name)
		if inv:FindFirstChild(res) and inv[res].Value < n then
			ok = false
		end
	end
	local list = {}
	for i, id in Config.BuildOrder do
		table.insert(list, i == pieceIdx and ("[" .. id .. "]") or id)
	end
	buildLabel.Text = table.concat(list, "  ") .. "\n" .. name .. "  |  Height " .. level .. "  |  Cost: " .. table.concat(parts, ", ")
		.. "\nClick place   G wall   V RAMP   F floor   Z/X piece   T material   Q height   B exit"
	buildLabel.TextColor3 = ok and WHITE or RED
	ghost.Color = ok and GREEN or RED
end

local function setBuildMode(on)
	buildMode = on
	buildLabel.Visible = on
	if on then
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:UnequipTools()
		end
		ghost.Parent = workspace
		refreshBuildLabel()
	else
		ghost.Parent = nil
	end
end

local function quickBuild(id)
	for i, v in Config.BuildOrder do
		if v == id then
			pieceIdx = i
		end
	end
	if not buildMode then
		setBuildMode(true)
	end
end

RunService.RenderStepped:Connect(function()
	if not buildMode then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local look = cam().CFrame.LookVector
	local probe = BuildShared.probe(root.Position, look)
	local hit = workspace:Raycast(probe + Vector3.new(0, 6, 0), Vector3.new(0, -300, 0), ghostParams())
	local gy = hit and hit.Position.Y or 0
	local specs, gcf, gsize = BuildShared.layout(Config.BuildOrder[pieceIdx], root.Position, look, gy, level)
	if #specs > 0 and gcf then
		ghost.CFrame = gcf
		ghost.Size = gsize
	end
	refreshBuildLabel()
end)

UIS.InputBegan:Connect(function(input, processed)
	if processed or not buildMode then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local look = cam().CFrame.LookVector
		Remotes.Build:FireServer(Config.BuildOrder[pieceIdx], Config.BuildMatOrder[matIdx], level, look)
	end
end)

local okMap, errMap = pcall(function()
-- Mini map (top right): region colors, landmarks and a dot for every player in the run -------------
local MAP_PX = 230
local mapFrame = new("Frame", { Name = "MiniMap", Size = UDim2.fromOffset(MAP_PX + 12, MAP_PX + 30), Position = UDim2.new(1, -(MAP_PX + 24), 0, 10),
	BackgroundColor3 = Color3.fromRGB(10, 10, 16), BackgroundTransparency = 0.25, BorderSizePixel = 0, Visible = false }, gui)
new("UICorner", { CornerRadius = UDim.new(0, 8) }, mapFrame)
new("UIStroke", { Color = Color3.fromRGB(150, 110, 255), Thickness = 1.5 }, mapFrame)
label(mapFrame, { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 2), Text = "MAP   (N up)", TextSize = 13 })
local mapInner = new("Frame", { Size = UDim2.fromOffset(MAP_PX, MAP_PX), Position = UDim2.fromOffset(6, 22),
	BackgroundColor3 = Color3.fromRGB(20, 20, 26), BorderSizePixel = 0, ClipsDescendants = true }, mapFrame)
local MAP_CELLS = 28
for i = 0, MAP_CELLS - 1 do
	for j = 0, MAP_CELLS - 1 do
		local wx = -Config.MapHalf + (i + 0.5) * (2 * Config.MapHalf / MAP_CELLS)
		local wz = -Config.MapHalf + (j + 0.5) * (2 * Config.MapHalf / MAP_CELLS)
		local col = Regions.Info[Regions.at(wx, wz)].ground:Lerp(Color3.new(0, 0, 0), 0.25)
		new("Frame", { Size = UDim2.new(1 / MAP_CELLS, 1, 1 / MAP_CELLS, 1), Position = UDim2.fromScale(i / MAP_CELLS, j / MAP_CELLS),
			BackgroundColor3 = col, BorderSizePixel = 0 }, mapInner)
	end
end
local function mapPos(x, z)
	return UDim2.fromScale(math.clamp((x + Config.MapHalf) / (2 * Config.MapHalf), 0, 1), math.clamp((z + Config.MapHalf) / (2 * Config.MapHalf), 0, 1))
end
local MARKERS = { -- model name -> size px, color
	City = { 12, Color3.fromRGB(190, 195, 210) }, Town = { 6, Color3.fromRGB(255, 240, 200) }, RuralTown = { 4, Color3.fromRGB(215, 180, 90) },
	Cave = { 6, Color3.fromRGB(255, 60, 50) }, Mountain = { 5, Color3.fromRGB(130, 130, 140) }, Lookout = { 3, Color3.new(1, 1, 1) },
	Ruins = { 4, Color3.fromRGB(190, 100, 255) },
}
task.spawn(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	for _, m in workspace:GetChildren() do
		local def = m:IsA("Model") and MARKERS[m.Name]
		if def then
			local pos = m:GetPivot().Position
			local dot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = mapPos(pos.X, pos.Z), Size = UDim2.fromOffset(def[1], def[1]),
				BackgroundColor3 = def[2], BorderSizePixel = 0, ZIndex = 2 }, mapInner)
			if m.Name == "Mountain" then
				dot.Rotation = 45
			end
		end
	end
end)
local mapDots = {}
task.spawn(function()
	while true do
		task.wait(0.2)
		local inRun = player:GetAttribute("InRun") == true
		mapFrame.Visible = inRun
		if inRun then
			local seen = {}
			for _, p in Players:GetPlayers() do
				local root = p:GetAttribute("InRun") == true and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if root then
					local d = mapDots[p]
					if not d then
						local mine = p == player
						d = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(mine and 9 or 7, mine and 9 or 7),
							BackgroundColor3 = mine and Color3.fromRGB(255, 230, 60) or Color3.fromRGB(80, 255, 120), BorderSizePixel = 1,
							BorderColor3 = Color3.new(0, 0, 0), ZIndex = 5 }, mapInner)
						new("UICorner", { CornerRadius = UDim.new(1, 0) }, d)
						if not mine then
							label(d, { Size = UDim2.fromOffset(80, 12), Position = UDim2.fromOffset(-36, -13), Text = p.Name, TextSize = 9, ZIndex = 6 })
						end
						mapDots[p] = d
					end
					d.Position = mapPos(root.Position.X, root.Position.Z)
					d.Visible = true
					seen[p] = true
				end
			end
			for p, d in mapDots do
				if not seen[p] then
					d:Destroy()
					mapDots[p] = nil
				end
			end
		end
	end
end)

end)
if not okMap then
	warn("[Nightfall] minimap error: " .. tostring(errMap))
end

-- Lobby screen: shown whenever you are not in a run (after joining, after dying, after a run ends) ----------
local lobby = new("Frame", { Size = UDim2.fromOffset(560, 250), Position = UDim2.new(0.5, -280, 1, -400),
	BackgroundColor3 = Color3.fromRGB(14, 12, 24), BackgroundTransparency = 0.12, BorderSizePixel = 0, Visible = true }, gui)
new("UICorner", { CornerRadius = UDim.new(0, 14) }, lobby)
new("UIStroke", { Color = Color3.fromRGB(150, 110, 255), Thickness = 2 }, lobby)
new("TextButton", { Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Text = "", Modal = true }, lobby) -- frees the cursor so the button can always be clicked
label(lobby, { Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 8), Text = "NIGHTFALL", TextSize = 44, TextColor3 = Color3.fromRGB(255, 90, 60) })
local lobbyStatus = label(lobby, { Size = UDim2.new(1, -40, 0, 70), Position = UDim2.fromOffset(20, 62), TextSize = 19, TextWrapped = true })
local lobbyBtn = new("TextButton", { Size = UDim2.fromOffset(300, 56), Position = UDim2.new(0.5, -150, 1, -84), BackgroundColor3 = GREEN,
	Text = "START RUN", Font = Enum.Font.GothamBold, TextSize = 26, TextColor3 = WHITE, AutoButtonColor = true, BorderSizePixel = 0 }, lobby)
new("UICorner", { CornerRadius = UDim.new(0, 10) }, lobbyBtn)
label(lobby, { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -22), TextSize = 13, TextTransparency = 0.3,
	Text = "Press ENTER or the green START button on the podium. Squads are up to 5 players. If everyone dies, the next run starts from Day 1." })

local function refreshLobby()
	local inRun = player:GetAttribute("InRun") == true
	lobby.Visible = not inRun
	if inRun then
		return
	end
	local active = workspace:GetAttribute("RunActive") == true
	local cd = workspace:GetAttribute("LobbyCountdown") or -1
	local ready = player:GetAttribute("Ready") == true
	if active then
		lobbyStatus.Text = "A run is in progress: Night " .. (workspace:GetAttribute("Night") or 1) .. " / " .. Config.FinalNight
			.. "  |  " .. (workspace:GetAttribute("RunAlive") or 0) .. "/" .. Config.MaxPlayers .. " alive.\nJoin them with fresh gear!"
		lobbyBtn.Text = "JOIN RUN"
		lobbyBtn.BackgroundColor3 = GREEN
	elseif cd >= 0 then
		lobbyStatus.Text = "Run starting in " .. cd .. "...\nPress the button to be part of it."
		lobbyBtn.Text = ready and "READY!" or "JOIN"
		lobbyBtn.BackgroundColor3 = ready and GRAY or GREEN
	elseif ready then
		lobbyStatus.Text = "Starting..."
		lobbyBtn.Text = "READY!"
		lobbyBtn.BackgroundColor3 = GRAY
	else
		lobbyStatus.Text = "No run active.\nPress START to begin a new run from Day 1. Friends can join during the countdown."
		lobbyBtn.Text = "START RUN"
		lobbyBtn.BackgroundColor3 = GREEN
	end
end
lobbyBtn.Activated:Connect(function()
	Remotes.StartRun:FireServer()
end)
for _, attr in { "RunActive", "LobbyCountdown", "Night", "RunAlive" } do
	workspace:GetAttributeChangedSignal(attr):Connect(refreshLobby)
end
player:GetAttributeChangedSignal("InRun"):Connect(refreshLobby)
player:GetAttributeChangedSignal("Ready"):Connect(refreshLobby)
refreshLobby()

-- Keybinds ---------------------------------------------------------------------------

local actions = {
	[Enum.KeyCode.R] = tryReload,
	[Enum.KeyCode.C] = function()
		craftFrame.Visible = not craftFrame.Visible
		refreshInventory()
	end,
	[Enum.KeyCode.G] = function()
		quickBuild("Wall")
	end,
	[Enum.KeyCode.V] = function()
		quickBuild("Ramp") -- ramps let you climb mountains, towers and walls: stack them with Q (height)
	end,
	[Enum.KeyCode.F] = function()
		quickBuild("Floor")
	end,
	[Enum.KeyCode.B] = function()
		setBuildMode(not buildMode)
	end,
	[Enum.KeyCode.Z] = function()
		if buildMode then
			pieceIdx = (pieceIdx - 2) % #Config.BuildOrder + 1
		end
	end,
	[Enum.KeyCode.X] = function()
		if buildMode then
			pieceIdx = pieceIdx % #Config.BuildOrder + 1
		end
	end,
	[Enum.KeyCode.T] = function()
		if buildMode then
			matIdx = matIdx % #Config.BuildMatOrder + 1
		end
	end,
	[Enum.KeyCode.Q] = function()
		if buildMode then
			level = (level + 1) % 6
		end
	end,
	[Enum.KeyCode.H] = function()
		Remotes.UseItem:FireServer("Bandage")
	end,
	[Enum.KeyCode.J] = function()
		Remotes.UseItem:FireServer("Medkit")
	end,
	[Enum.KeyCode.K] = function()
		Remotes.UseItem:FireServer("ShieldPotion")
	end,
}

UIS.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		sprinting = true
		setSpeed()
		return
	end
	if player:GetAttribute("InRun") ~= true then
		if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
			Remotes.StartRun:FireServer()
		end
		return
	end
	local fn = actions[input.KeyCode]
	if fn then
		fn()
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		sprinting = false
		setSpeed()
	end
end)
