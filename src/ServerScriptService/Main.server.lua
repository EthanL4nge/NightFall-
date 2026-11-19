--[[ NIGHTFALL - main server script (Script in ServerScriptService, named "Main").
     Runs the day/night loop, escalating zombie waves, the Zombie King finale, and player lifecycle. ]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local StarterPlayer = game:GetService("StarterPlayer")

local Modules = script.Parent:WaitForChild("Modules")
local Config = require(RS:WaitForChild("Config"))
local Remotes = require(Modules.Remotes)
local Inventory = require(Modules.Inventory)
local Weapons = require(Modules.Weapons)
local Loot = require(Modules.Loot)
local Build = require(Modules.Build)
local Defenses = require(Modules.Defenses)
local Caves = require(Modules.Caves)
local Zombies = require(Modules.Zombies)
local Combat = require(Modules.Combat)
local Crafting = require(Modules.Crafting)
local World = require(Modules.World)

Players.CharacterAutoLoads = false -- we respawn players ourselves (delay grows each night)
pcall(function()
	StarterPlayer.EnableMouseLockOption = false -- Shift is our sprint key
	StarterPlayer.CameraMode = Enum.CameraMode.Classic -- lobby is third person; runs switch to first person per player
end)

-- Lighting ------------------------------------------------------------------
if not Lighting:FindFirstChildOfClass("Sky") then
	Instance.new("Sky").Parent = Lighting
end
Lighting.GlobalShadows = true

local function setClock(hour)
	hour = hour % 24
	Lighting.ClockTime = hour
	local light = math.clamp(math.sin((hour - 6) / 12 * math.pi), 0, 1)
	local night = workspace:GetAttribute("Night") or 1
	local final = Config.BossNights[night] ~= nil and workspace:GetAttribute("Phase") == "Night"
	Lighting.Brightness = 0.5 + 1.7 * light
	Lighting.Ambient = Color3.fromRGB(12, 12, 28):Lerp(Color3.fromRGB(95, 95, 95), light)
	Lighting.OutdoorAmbient = Color3.fromRGB(28, 28, 58):Lerp(Color3.fromRGB(135, 135, 135), light)
	-- nights get foggier (= scarier) as the game goes on
	local nightFog = math.max(120, 300 - 22 * night)
	Lighting.FogEnd = nightFog + (1400 - nightFog) * light
	Lighting.FogStart = 10
	Lighting.FogColor = final and Color3.fromRGB(45, 0, 0) or Color3.fromRGB(8, 8, 20):Lerp(Color3.fromRGB(190, 205, 230), light)
end

local function announce(title, sub, color)
	Remotes.Announce:FireAllClients(title, sub, color or Color3.new(1, 1, 1))
end

-- Players -------------------------------------------------------------------
local LOBBY_COUNTDOWN = 10
local DEATH_DELAY = 4

local function lobbySpawn()
	return World.lobbySpawn or World.worldSpawn
end

local function inRunCount()
	local n = 0
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("InRun") == true then
			n += 1
		end
	end
	return n
end

local function setCamera(player, firstPerson)
	pcall(function()
		player.CameraMode = firstPerson and Enum.CameraMode.LockFirstPerson or Enum.CameraMode.Classic
		player.CameraMaxZoomDistance = firstPerson and 0.5 or 40
		player.CameraMinZoomDistance = 0.5
	end)
end

local function toLobby(player)
	setCamera(player, false)
	player:SetAttribute("InRun", false)
	player:SetAttribute("Ready", false)
	player.RespawnLocation = lobbySpawn()
	task.spawn(function()
		player:LoadCharacter()
	end)
end

-- puts a player into the active run with fresh gear at the world spawn
local function joinRun(player)
	if not player.Parent or player:GetAttribute("InRun") == true then
		return
	end
	setCamera(player, true)
	player:SetAttribute("InRun", true)
	player:SetAttribute("Ready", false)
	Inventory.setup(player)
	Inventory.add(player, "Bandage", 2)
	local k = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Kills")
	if k then
		k.Value = 0
	end
	player:SetAttribute("DeathId", (player:GetAttribute("DeathId") or 0) + 1)
	player.RespawnLocation = World.worldSpawn
	task.spawn(function()
		player:LoadCharacter()
	end)
end

local function onCharacter(player, char)
	local hum = char:WaitForChild("Humanoid")
	hum.MaxHealth = 100
	hum.Health = 100
	hum.WalkSpeed = Config.WalkSpeed
	hum.UseJumpPower = true
	hum.JumpPower = 50
	local regen = char:WaitForChild("Health", 1) -- no passive regen: heal with bandages/medkits
	if regen then
		regen:Destroy()
	end
	player:SetAttribute("Shield", 0)
	if player:GetAttribute("InRun") == true then
		Weapons.give(player, "WoodSword", 1)
	end

	-- fall damage: 1 HP per stud fallen (see Config.FallDamagePerStud / FallSafeHeight)
	local root = char:WaitForChild("HumanoidRootPart")
	local peak = nil
	local fallConn
	fallConn = RunService.Heartbeat:Connect(function()
		if not char.Parent or hum.Health <= 0 then
			fallConn:Disconnect()
			return
		end
		local y = root.Position.Y
		local grounded = hum.FloorMaterial ~= Enum.Material.Air or hum:GetState() == Enum.HumanoidStateType.Climbing
		if grounded then
			if peak then
				local drop = peak - y
				peak = nil
				if drop > Config.FallSafeHeight and player:GetAttribute("InRun") == true then
					local dmg = math.floor(drop * Config.FallDamagePerStud)
					hum:TakeDamage(dmg) -- falls ignore shields
					Remotes.Notify:FireClient(player, "Fall damage -" .. dmg .. "  (fell " .. math.floor(drop) .. " studs)", Color3.fromRGB(255, 120, 90))
				end
			end
		else
			peak = math.max(peak or y, y)
		end
	end)

	hum.Died:Connect(function()
		local wasInRun = player:GetAttribute("InRun") == true
		local id = (player:GetAttribute("DeathId") or 0) + 1
		player:SetAttribute("DeathId", id)
		if wasInRun then
			local root = char:FindFirstChild("HumanoidRootPart")
			local pos = root and root.Position or Vector3.new(0, 5, 0)
			-- your guns drop where you fell for teammates to grab
			for _, info in Weapons.stripAll(player) do
				if not (info.id == "WoodSword" and info.rarity == 1) then
					Loot.spawnDrop(pos + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4)), {
						kind = "Weapon", id = info.id, rarity = info.rarity, mag = info.mag,
					})
				end
			end
			player:SetAttribute("InRun", false) -- zombies/combat stop seeing you right away
			Remotes.Announce:FireClient(player, "YOU DIED", "Survived " .. math.max(0, (workspace:GetAttribute("Night") or 1) - 1)
				.. " nights. Back to the lobby...", Color3.fromRGB(255, 80, 80))
			task.wait(DEATH_DELAY)
		else
			task.wait(2)
		end
		if player.Parent and player:GetAttribute("DeathId") == id then
			toLobby(player)
		end
	end)
end

local function setupPlayer(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Parent = ls
	ls.Parent = player

	Inventory.setup(player)
	player:SetAttribute("InRun", false)
	player:SetAttribute("Ready", false)
	setCamera(player, false)

	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	player.RespawnLocation = lobbySpawn()
	player:LoadCharacter()
end

-- Start a new run, or jump into the one in progress (squads are capped at Config.MaxPlayers)
local function requestStart(player)
	if player:GetAttribute("InRun") == true or not player.Character then
		return
	end
	if workspace:GetAttribute("RunActive") then
		if inRunCount() >= Config.MaxPlayers then
			Remotes.Notify:FireClient(player, "The squad is full (" .. Config.MaxPlayers .. "/" .. Config.MaxPlayers .. ")", Color3.fromRGB(255, 120, 120))
			return
		end
		joinRun(player)
	else
		player:SetAttribute("Ready", true)
	end
end
Remotes.StartRun.OnServerEvent:Connect(requestStart) -- on-screen lobby button / ENTER key
-- Zombie AI tick (5x per second is plenty)
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc >= 0.2 then
		acc = 0
		Zombies.step()
		Caves.step()
		Defenses.step()
	end
end)

-- Run flow ------------------------------------------------------------------
local function resetRun()
	Zombies.killAll(true)
	Build.clearAll()
	Defenses.clearAll()
	Loot.clearDrops()
	Loot.refillChests(1)
	Caves.resetAll()
	workspace:SetAttribute("BossMax", 0)
	workspace:SetAttribute("BossHP", 0)
	workspace:SetAttribute("ZombiesLeft", 0)
	workspace:SetAttribute("Night", 1)
end

local function updateAlive()
	workspace:SetAttribute("RunAlive", inRunCount())
end

local function runDay(n)
	workspace:SetAttribute("Night", n)
	workspace:SetAttribute("Phase", "Day")
	if n > 1 then
		Loot.refillChests(0.2)
	end
	announce("DAY " .. n, "Gather, craft, build, explore. Night is coming." .. (Config.BossNights[n] and "  BOSS TONIGHT!" or ""), Color3.fromRGB(255, 220, 120))
	local t0, len = os.clock(), Config.DayLength
	while true do
		local e = os.clock() - t0
		if e >= len then
			break
		end
		updateAlive()
		if inRunCount() == 0 then
			return false
		end
		workspace:SetAttribute("TimeLeft", math.ceil(len - e))
		setClock(6 + 12 * e / len)
		task.wait(0.1)
	end
	return true
end

local function runNight(n)
	local stats = Config.nightStats(n)
	local bossType = Config.BossNights[n]
	local final = bossType ~= nil
	workspace:SetAttribute("Phase", "Night")
	workspace:SetAttribute("TimeLeft", final and -1 or stats.length)
	announce(
		"NIGHT " .. n,
		final and (Config.Zombies[bossType].display .. " RISES - KILL IT" .. (n >= Config.FinalNight and " TO WIN" or "")) or "Survive until dawn",
		Color3.fromRGB(255, 70, 70)
	)

	local playerCount = math.max(1, inRunCount())
	local total = math.floor(stats.total * (0.6 + 0.4 * playerCount))
	local spawned, nextSpawn = 0, 0
	local bossDead = false

	if final then
		local conn
		conn = Zombies.BossKilled.Event:Connect(function()
			bossDead = true
			conn:Disconnect()
		end)
		task.spawn(function()
			task.wait(2)
			while not Zombies.spawnAround(n, bossType) do
				if inRunCount() == 0 then
					return
				end
				task.wait(1) -- nobody alive right now? keep trying until someone respawns
			end
		end)
	end

	local t0 = os.clock()
	while true do
		updateAlive()
		if inRunCount() == 0 then
			return false
		end
		local e = os.clock() - t0
		if final then
			if bossDead then
				break
			end
			setClock(0)
		else
			if e >= stats.length then
				break
			end
			setClock(18 + 12 * e / stats.length)
		end

		if (final or spawned < total) and os.clock() >= nextSpawn and Zombies.alive() < stats.maxAlive then
			if Zombies.spawnAround(n, Zombies.pickType(n)) then
				spawned += 1
			end
			nextSpawn = os.clock() + stats.interval * (final and 1.8 or 1)
		end

		workspace:SetAttribute("TimeLeft", final and -1 or math.ceil(stats.length - e))
		workspace:SetAttribute("ZombiesLeft", Zombies.alive() + (final and 0 or math.max(0, total - spawned)))
		task.wait(0.1)
	end
	return true
end

local function dawn(n)
	workspace:SetAttribute("Phase", "Day")
	workspace:SetAttribute("ZombiesLeft", 0)
	setClock(6)
	Zombies.killAll(false) -- sunlight burns the undead
	announce("DAWN", "You survived night " .. n .. "! Supply drop: +2 Bandages, +20 Ammo", Color3.fromRGB(255, 220, 120))
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("InRun") == true then
			Inventory.add(p, "Bandage", 2)
			Inventory.add(p, "Ammo", 20)
		end
	end
end

-- wait in the lobby until someone presses START, then count down so friends can join too
local function lobbyPhase()
	workspace:SetAttribute("RunActive", false)
	workspace:SetAttribute("Phase", "Lobby")
	workspace:SetAttribute("TimeLeft", 0)
	workspace:SetAttribute("LobbyCountdown", -1)
	workspace:SetAttribute("Night", 1)
	setClock(11)
	while true do
		local anyReady = false
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("Ready") == true and p:GetAttribute("InRun") ~= true then
				anyReady = true
			end
		end
		if anyReady then
			break
		end
		task.wait(0.4)
	end
	for i = LOBBY_COUNTDOWN, 1, -1 do
		workspace:SetAttribute("LobbyCountdown", i)
		task.wait(1)
	end
	workspace:SetAttribute("LobbyCountdown", -1)
end

-- Boot ----------------------------------------------------------------------
World.generate()
if World.startPrompt then
	World.startPrompt.Triggered:Connect(requestStart) -- physical START button in the lobby
end

-- keep the physical button's text in sync with the game state
task.spawn(function()
	while true do
		task.wait(1)
		if World.startPrompt then
			local active = workspace:GetAttribute("RunActive") == true
			World.startPrompt.ActionText = active and "Join Run" or "Start Run"
			World.startPrompt.ObjectText = "Squad " .. inRunCount() .. "/" .. Config.MaxPlayers
			if World.startLabel then
				World.startLabel.Text = active and "JOIN RUN" or "START RUN"
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		World.updateLobbyDots()
	end
end)
Build.onPlaced = Defenses.register
Build.init()
Combat.init()
Crafting.init()

Players.PlayerAdded:Connect(function(player)
	if #Players:GetPlayers() > Config.MaxPlayers then
		player:Kick("Server full (max " .. Config.MaxPlayers .. " players). Please join another server.")
		return
	end
	setupPlayer(player)
end)
for _, p in Players:GetPlayers() do
	task.spawn(setupPlayer, p)
end

while true do
	lobbyPhase()
	resetRun()
	workspace:SetAttribute("RunActive", true)
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Ready") == true and inRunCount() < Config.MaxPlayers then
			joinRun(p)
		end
	end

	local night, won = 1, false
	while true do
		if not runDay(night) then
			break
		end
		if not runNight(night) then
			break
		end
		if night >= Config.FinalNight then
			won = true
			break
		end
		dawn(night)
		night += 1
	end

	workspace:SetAttribute("RunActive", false)
	workspace:SetAttribute("Phase", "Day")
	workspace:SetAttribute("ZombiesLeft", 0)
	Zombies.killAll(true)
	if won then
		setClock(10)
		announce("VICTORY!", "THE OVERLORD has fallen. You beat all 40 nights of NIGHTFALL! Back to the lobby in 15s...", Color3.fromRGB(120, 255, 140))
		task.wait(15)
	else
		announce("EVERYONE FELL", "The run is over at night " .. night .. ". Back to the lobby - press START to try again from Day 1.", Color3.fromRGB(255, 80, 80))
		task.wait(5)
	end
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("InRun") == true or p.Character == nil then
			toLobby(p)
		end
	end
end

-- gun flashlights: on during Night only (and only while the gun is out in the world, not in a backpack)
do
	local CS = game:GetService("CollectionService")
	local function refresh(light)
		light.Enabled = workspace:GetAttribute("Phase") == "Night" and light:IsDescendantOf(workspace)
	end
	local function hook(light)
		refresh(light)
		light.AncestryChanged:Connect(function()
			refresh(light)
		end)
	end
	CS:GetInstanceAddedSignal("NFlash"):Connect(hook)
	for _, l in CS:GetTagged("NFlash") do
		hook(l)
	end
	workspace:GetAttributeChangedSignal("Phase"):Connect(function()
		for _, l in CS:GetTagged("NFlash") do
			refresh(l)
		end
	end)
end
