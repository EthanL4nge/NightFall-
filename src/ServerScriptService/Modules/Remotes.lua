-- Creates every RemoteEvent at runtime so nothing has to be set up by hand in Studio.
local RS = game:GetService("ReplicatedStorage")

local folder = RS:FindFirstChild("Remotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = RS
end

local names = {
	"Attack", "Reload", "Craft", "UseItem", "Build", "StartRun", -- client -> server
	"Tracer", "Notify", "Announce", "HitMarker", -- server -> client
}

local R = {}
for _, name in ipairs(names) do
	local e = folder:FindFirstChild(name) or Instance.new("RemoteEvent")
	e.Name = name
	e.Parent = folder
	R[name] = e
end

return R
