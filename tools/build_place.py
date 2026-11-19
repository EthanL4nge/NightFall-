import itertools, pathlib, sys
from xml.sax.saxutils import escape

ROOT = pathlib.Path(__file__).resolve().parent.parent / "src"
counter = itertools.count()

def ref():
    return f"RBX{next(counter):04d}"

def src_of(path):
    text = pathlib.Path(path).read_text()
    assert "]]>" not in text, f"CDATA terminator found in {path}"
    return text

def script(cls, name, path):
    return (f'<Item class="{cls}" referent="{ref()}"><Properties>'
            f'<string name="Name">{escape(name)}</string>'
            f'<ProtectedString name="Source"><![CDATA[{src_of(path)}]]></ProtectedString>'
            f'</Properties></Item>')

def container(cls, name, children="", extra=""):
    return (f'<Item class="{cls}" referent="{ref()}"><Properties>'
            f'<string name="Name">{escape(name)}</string>{extra}</Properties>{children}</Item>')

modules_dir = ROOT / "ServerScriptService" / "Modules"
module_items = "".join(
    script("ModuleScript", p.stem, p) for p in sorted(modules_dir.glob("*.lua"))
)

workspace = container("Workspace", "Workspace", "", '<bool name="StreamingEnabled">false</bool>')
lighting = container("Lighting", "Lighting")
rs = container("ReplicatedStorage", "ReplicatedStorage",
               "".join(script("ModuleScript", p.stem, p) for p in sorted((ROOT / "ReplicatedStorage").glob("*.lua"))))
sss = container("ServerScriptService", "ServerScriptService",
                script("Script", "Main", ROOT / "ServerScriptService" / "Main.server.lua")
                + container("Folder", "Modules", module_items))
sps = container("StarterPlayerScripts", "StarterPlayerScripts",
                script("LocalScript", "Client", ROOT / "StarterPlayer" / "StarterPlayerScripts" / "Client.client.lua"))
starter = container("StarterPlayer", "StarterPlayer", sps,
                    '<bool name="EnableMouseLockOption">false</bool>')

players = container("Players", "Players", "", '<int name="MaxPlayersInternal">5</int><int name="PreferredPlayersInternal">5</int>')

doc = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
       'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
       'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
       '<Meta name="ExplicitAutoJoints">true</Meta>'
       + workspace + lighting + players + rs + sss + starter + '</roblox>')

out = (pathlib.Path(__file__).resolve().parent.parent / "builds" / "Nightfall.rbxlx")
out.parent.mkdir(exist_ok=True)
out.write_text('<?xml version="1.0" encoding="utf-8"?>\n' + doc)
print("wrote", out, out.stat().st_size, "bytes")
