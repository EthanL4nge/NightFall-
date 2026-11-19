-- Placement math shared by the client (ghost preview) and the server (the real thing).
-- Pieces snap to a 12-stud grid. Walls sit on cell edges, floors/ramps on cell centers.
-- `level` raises the piece by 10 studs per level, so you can build roofs and second floors.
local B = {}

B.CELL = 12
B.HEIGHT = 10
B.REACH = 9

function B.snapDir(look)
	local f = Vector3.new(look.X, 0, look.Z)
	if f.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	if math.abs(f.X) > math.abs(f.Z) then
		return Vector3.new(math.sign(f.X), 0, 0)
	end
	return Vector3.new(0, 0, math.sign(f.Z))
end

-- point in front of the player where terrain height should be sampled
function B.probe(rootPos, look)
	return rootPos + B.snapDir(look) * B.REACH
end

-- returns specs, ghostCF, ghostSize
-- specs = list of { name, size, cf, class, color?, material? }
function B.layout(piece, rootPos, look, groundY, level)
	local C, H = B.CELL, B.HEIGHT
	local fwd = B.snapDir(look)
	local ax, az = rootPos.X + fwd.X * B.REACH, rootPos.Z + fwd.Z * B.REACH
	local cellX, cellZ = math.round(ax / C) * C, math.round(az / C) * C

	local feet = rootPos.Y - 3
	local baseY = (feet - groundY < 1.5) and groundY or feet
	local y0 = baseY + level * H -- bottom of the piece

	local specs = {}
	local function add(name, size, cf, class, color, material)
		table.insert(specs, { name = name, size = size, cf = cf, class = class or "Part", color = color, material = material })
	end

	-- wall frame on the cell edge ahead of the player
	local wx, wz, rot
	if fwd.X == 0 then
		wx, wz, rot = cellX, math.round((az - C / 2) / C) * C + C / 2, 0
	else
		wx, wz, rot = math.round((ax - C / 2) / C) * C + C / 2, cellZ, math.pi / 2
	end
	local wallCF = CFrame.new(wx, y0, wz) * CFrame.Angles(0, rot, 0)

	local function wallPieces(cf, doorway)
		if doorway then
			add("DoorL", Vector3.new(3.5, H, 1.5), cf * CFrame.new(-4.25, H / 2, 0))
			add("DoorR", Vector3.new(3.5, H, 1.5), cf * CFrame.new(4.25, H / 2, 0))
			add("Lintel", Vector3.new(5, 3, 1.5), cf * CFrame.new(0, H - 1.5, 0))
		else
			add("Wall", Vector3.new(C, H, 1.5), cf * CFrame.new(0, H / 2, 0))
		end
	end

	local ghostCF = wallCF * CFrame.new(0, H / 2, 0)
	local ghostSize = Vector3.new(C, H, 1.5)

	if piece == "Wall" then
		wallPieces(wallCF, false)
	elseif piece == "Doorway" then
		wallPieces(wallCF, true)
	elseif piece == "Floor" then
		add("Floor", Vector3.new(C, 1, C), CFrame.new(cellX, y0 + 0.5, cellZ))
		ghostCF, ghostSize = CFrame.new(cellX, y0 + 0.5, cellZ), Vector3.new(C, 1, C)
	elseif piece == "Ramp" then
		local c = Vector3.new(cellX, y0 + H / 2, cellZ)
		-- WedgePart's tall edge is local +Z; face the part back toward the player so the high end is ahead
		add("Ramp", Vector3.new(C, H, C), CFrame.lookAt(c, c - fwd), "WedgePart")
		ghostCF, ghostSize = CFrame.new(c), Vector3.new(C, H, C)
	elseif piece == "Shelter" then
		-- a closed 1-cell room around you: 3 walls + a doorway facing where you look + a roof
		local sx, sz = math.round(rootPos.X / C) * C, math.round(rootPos.Z / C) * C
		for _, d in { Vector3.new(0, 0, -1), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0) } do
			local cf = CFrame.new(sx + d.X * C / 2, y0, sz + d.Z * C / 2) * CFrame.Angles(0, d.X ~= 0 and math.pi / 2 or 0, 0)
			wallPieces(cf, d == fwd)
		end
		add("Roof", Vector3.new(C + 1.5, 1, C + 1.5), CFrame.new(sx, y0 + H + 0.5, sz))
		ghostCF = CFrame.new(sx, y0 + (H + 1) / 2, sz)
		ghostSize = Vector3.new(C + 1.5, H + 1, C + 1.5)
	elseif piece == "Torch" then
		local p = rootPos + fwd * 6
		add("Pole", Vector3.new(0.6, 5, 0.6), CFrame.new(p.X, baseY + 2.5, p.Z), "Part", Color3.fromRGB(95, 62, 35), Enum.Material.Wood)
		add("Head", Vector3.new(1.3, 1.3, 1.3), CFrame.new(p.X, baseY + 5.6, p.Z), "Part", Color3.fromRGB(255, 170, 60), Enum.Material.Neon)
		ghostCF, ghostSize = CFrame.new(p.X, baseY + 3, p.Z), Vector3.new(1.5, 6, 1.5)
	elseif piece == "Spikes" then
		local c = Vector3.new(cellX, baseY, cellZ)
		add("Pad", Vector3.new(8, 0.5, 8), CFrame.new(c.X, c.Y + 0.25, c.Z), "Part", Color3.fromRGB(70, 70, 78), Enum.Material.Metal)
		for _, o in { { 0, 0 }, { -2.5, -2.5 }, { 2.5, -2.5 }, { -2.5, 2.5 }, { 2.5, 2.5 } } do
			add("Spike", Vector3.new(0.6, 2.4, 0.6), CFrame.new(c.X + o[1], c.Y + 1.5, c.Z + o[2]), "Part",
				Color3.fromRGB(190, 195, 205), Enum.Material.Metal)
		end
		ghostCF, ghostSize = CFrame.new(c.X, c.Y + 1, c.Z), Vector3.new(8, 2.4, 8)
	elseif piece == "Turret" then
		local p = rootPos + fwd * 7
		add("Base", Vector3.new(3, 1.6, 3), CFrame.new(p.X, baseY + 0.8, p.Z), "Part", Color3.fromRGB(70, 75, 85), Enum.Material.Metal)
		add("Gun", Vector3.new(0.9, 0.9, 3.2), CFrame.new(p.X, baseY + 2.4, p.Z) * CFrame.Angles(0, rot, 0), "Part",
			Color3.fromRGB(120, 220, 255), Enum.Material.Neon)
		ghostCF, ghostSize = CFrame.new(p.X, baseY + 1.6, p.Z), Vector3.new(3, 3.2, 3.2)
	end

	return specs, ghostCF, ghostSize
end

return B
