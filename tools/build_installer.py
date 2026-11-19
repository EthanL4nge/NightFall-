import pathlib
R = pathlib.Path(__file__).resolve().parent.parent / "src"
def lit(p):
    t = pathlib.Path(p).read_text()
    assert "]=====]" not in t
    return "[=====[\n" + t + "]=====]"
mods = "".join(f'\t{{ "{p.stem}", {lit(p)} }},\n' for p in sorted((R/"ServerScriptService/Modules").glob("*.lua")))
rsmods = "\n".join(f'make("ModuleScript", "{p.stem}", RS, {lit(p)})' for p in sorted((R/"ReplicatedStorage").glob("*.lua")))
out = f'''-- NIGHTFALL INSTALLER: paste this whole file into Roblox Studio's Command Bar and press Enter.
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SP = game:GetService("StarterPlayer")
local SPS = SP:WaitForChild("StarterPlayerScripts")

local function fresh(parent, name)
	local old = parent:FindFirstChild(name)
	if old then old:Destroy() end
end
local function make(class, name, parent, source)
	fresh(parent, name)
	local o = Instance.new(class)
	o.Name = name
	if source then o.Source = source end
	o.Parent = parent
	return o
end

{rsmods}

fresh(SSS, "Modules")
local modules = Instance.new("Folder")
modules.Name = "Modules"
modules.Parent = SSS
local list = {{
{mods}}}
for _, m in ipairs(list) do
	make("ModuleScript", m[1], modules, m[2])
end

make("Script", "Main", SSS, {lit(R/"ServerScriptService/Main.server.lua")})
make("LocalScript", "Client", SPS, {lit(R/"StarterPlayer/StarterPlayerScripts/Client.client.lua")})

pcall(function() SP.EnableMouseLockOption = false end)
pcall(function() workspace.StreamingEnabled = false end)
-- remove the default Baseplate so the generated map is the only ground
local bp = workspace:FindFirstChild("Baseplate")
if bp then bp:Destroy() end
print("NIGHTFALL installed! Press F5 (Play) to start.")
'''
(pathlib.Path(__file__).resolve().parent.parent / "builds" / "Nightfall-Installer.txt").write_text(out)
pass
print(len(out))
