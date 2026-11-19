-- Active base defenses: auto turrets (limited ammo, refill with E), spike traps, torches.
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(RS:WaitForChild("Config"))
local Remotes = require(script.Parent.Remotes)
local Inventory = require(script.Parent.Inventory)
local Zombies = require(script.Parent.Zombies)
local Build = require(script.Parent.Build)

local Defenses = {}

local turrets = {} -- [group] = state
local spikes = {} -- [group] = state

local AMMO_CAP = 150
local REFILL = 20

local function ownerOf(group)
	local id = group:GetAttribute("Owner")
	return id and Players:GetPlayerByUserId(id) or nil
end

function Defenses.register(group, pieceId, player)
	if pieceId == "Torch" then
		local head = group:FindFirstChild("Head")
		if head then
			local light = Instance.new("PointLight")
			light.Range = 42
			light.Brightness = 2.2
			light.Color = Color3.fromRGB(255, 170, 80)
			light.Parent = head
			local fire = Instance.new("Fire")
			fire.Size = 4
			fire.Heat = 0
			fire.Parent = head
		end
	elseif pieceId == "Turret" then
		local base, gun = group:FindFirstChild("Base"), group:FindFirstChild("Gun")
		if not (base and gun) then
			return
		end
		group:SetAttribute("Ammo", Config.TurretAmmoStart)

		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(120, 28)
		gui.StudsOffset = Vector3.new(0, 3, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 60
		gui.Parent = gun
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBold
		text.TextSize = 15
		text.TextColor3 = Color3.fromRGB(120, 220, 255)
		text.TextStrokeTransparency = 0.4
		text.Parent = gui
		local function refresh()
			text.Text = "TURRET  " .. (group:GetAttribute("Ammo") or 0) .. " ammo"
		end
		group:GetAttributeChangedSignal("Ammo"):Connect(refresh)
		refresh()

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Add " .. REFILL .. " ammo"
		prompt.ObjectText = "Auto Turret"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Parent = base
		prompt.Triggered:Connect(function(p)
			local have = Inventory.count(p, "Ammo")
			local cur = group:GetAttribute("Ammo") or 0
			local give = math.min(REFILL, have, AMMO_CAP - cur)
			if give <= 0 then
				Remotes.Notify:FireClient(p, have <= 0 and "You have no ammo" or "Turret is full", Color3.fromRGB(255, 120, 120))
				return
			end
			Inventory.add(p, "Ammo", -give)
			group:SetAttribute("Ammo", cur + give)
		end)

		turrets[group] = { group = group, gun = gun, nextShot = 0 }
	elseif pieceId == "Spikes" then
		local pad = group:FindFirstChild("Pad")
		if pad then
			spikes[group] = { group = group, pad = pad, nextTick = 0 }
		end
	end
end

function Defenses.step()
	local now = os.clock()

	for group, t in turrets do
		if not group.Parent or not t.gun.Parent then
			turrets[group] = nil
			continue
		end
		local ammo = group:GetAttribute("Ammo") or 0
		if ammo > 0 and now >= t.nextShot then
			local gunPos = t.gun.Position
			local best, bestD = nil, Config.TurretRange
			for _, z in Zombies.list do
				if z.hum.Health > 0 then
					local d = (z.root.Position - gunPos).Magnitude
					if d < bestD then
						best, bestD = z, d
					end
				end
			end
			if best then
				t.nextShot = now + 0.45
				group:SetAttribute("Ammo", ammo - 1)
				local aim = best.root.Position + Vector3.new(0, 1, 0)
				t.gun.CFrame = CFrame.lookAt(gunPos, aim)
				local dist = (aim - gunPos).Magnitude
				Remotes.Tracer:FireAllClients(gunPos + (aim - gunPos).Unit * 2, (aim - gunPos).Unit * 3000, Color3.fromRGB(120, 220, 255), dist / 3000)
				Zombies.damage(best.model, Config.TurretDamage, ownerOf(group), false)
			end
		end
	end

	for group, s in spikes do
		if not group.Parent then
			spikes[group] = nil
			continue
		end
		if not s.pad.Parent then
			group:Destroy() -- pad destroyed: the whole trap goes
			spikes[group] = nil
			continue
		end
		if now >= s.nextTick then
			s.nextTick = now + 0.5
			local c = s.pad.Position
			local hitAny = false
			for _, z in Zombies.list do
				if z.hum.Health > 0 then
					local p = z.root.Position
					local flat = Vector3.new(p.X - c.X, 0, p.Z - c.Z).Magnitude
					if flat < 5 and math.abs(p.Y - c.Y) < 6 then
						hitAny = true
						Zombies.damage(z.model, 20, ownerOf(group), false)
					end
				end
			end
			if hitAny then
				Build.damage(s.pad, 8) -- traps wear out
			end
		end
	end
end

function Defenses.clearAll()
	turrets = {}
	spikes = {}
end

return Defenses
