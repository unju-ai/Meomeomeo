"""Small Luau smoke harness. It does not replace a Roblox Studio playtest.

Usage: python3 tools/test-brand.py /path/to/luau
The Luau compiler, if beside the executable, syntax-checks the whole src tree.
"""
from pathlib import Path
import re
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
luau = Path(sys.argv[1] if len(sys.argv) > 1 else "luau")
compiler = luau.with_name("luau-compile")
if compiler.is_file():
    sources = sorted((root / "src").rglob("*.luau"))
    for source in sources:
        subprocess.run([str(compiler), str(source)], check=True, stdout=subprocess.DEVNULL)
    print(f"Compiled {len(sources)} Luau source files", flush=True)

prelude = r'''
local Color3 = {}
function Color3.fromRGB(r, g, b) return { _kind = "Color3", R = r, G = g, B = b } end
local Enum = setmetatable({}, { __index = function(_, category)
    return setmetatable({}, { __index = function(_, name) return category .. "." .. name end })
end })
local UDim = { new = function(...) return {...} end }
local UDim2 = { new = function(...) return {...} end, fromOffset = function(...) return {...} end, fromScale = function(...) return {...} end }
local Vector2 = { new = function(x, y) return {X = x, Y = y} end }
local function signal()
    local callbacks = {}
    return {
        Connect = function(_, fn) table.insert(callbacks, fn) end,
        Fire = function(_, ...) for _, fn in callbacks do fn(...) end end,
    }
end
local Instance = {}
function Instance.new(class)
    local values = { ClassName = class, Name = class, children = {},
        AbsoluteSize = { X = 780, Y = 560 }, Changed = signal(),
        MouseButton1Click = signal(), Activated = signal(), FocusLost = signal() }
    local object
    object = setmetatable({}, {
        __index = function(_, key)
            if key == "GetPropertyChangedSignal" then
                return function() return values.Changed end
            elseif key == "Destroy" then
                return function()
                    if values.Parent then
                        local index = table.find(values.Parent.children, object)
                        if index then table.remove(values.Parent.children, index) end
                    end
                end
            elseif key == "FindFirstChild" then
                return function(_, name)
                    for _, child in values.children do if child.Name == name then return child end end
                    return nil
                end
            elseif key == "FindFirstChildWhichIsA" then
                return function(_, kind)
                    for _, child in values.children do if child.ClassName == kind then return child end end
                    return nil
                end
            elseif key == "GetChildren" then
                return function()
                    return values.children
                end
            elseif key == "IsA" then
                return function(_, kind)
                    return values.ClassName == kind
                end
            end
            return values[key]
        end,
        __newindex = function(_, key, value)
            if key == "Color" or key == "BackgroundColor3" or key == "TextColor3" then
                assert(type(value) == "table" and value._kind == "Color3", "Expected Color3 for " .. key)
            end
            values[key] = value
            if key == "Parent" then table.insert(value.children, object) end
        end,
    })
    return object
end
'''
modules = [
    ("BrandCatalog", "src/shared/BrandCatalog.luau"),
    ("ChampionCatalog", "src/shared/ChampionCatalog.luau"),
    ("ModeCatalog", "src/shared/ModeCatalog.luau"),
    ("YarnRunCatalog", "src/shared/YarnRunCatalog.luau"),
    ("HostGuide", "src/shared/HostGuide.luau"),
    ("NpcCatalog", "src/server/Npcs/NpcCatalog.luau"),
    ("MockAiProvider", "src/server/Npcs/MockAiProvider.luau"),
    ("Theme", "src/client/Theme.luau"),
    ("PublishChecklist", "src/shared/PublishChecklist.luau"),
    ("PublishPanel", "src/client/UI/PublishPanel.luau"),
    ("LobbyPanel", "src/client/UI/LobbyPanel.luau"),
    ("HubPanel", "src/client/UI/HubPanel.luau"),
    ("NpcChatPanel", "src/client/UI/NpcChatPanel.luau"),
]
chunks = [prelude]
for name, path in modules:
    source = (root / path).read_text()
    # Replace Roblox module resolution with the actual modules loaded above.
    source = re.sub(r"^local \w+ = require\([^\n]+\)\n", "", source, flags=re.MULTILINE)
    chunks.append(f"local {name} = (function()\n{source}\nend)()\n")
chunks.append((root / "tests/brand-smoke.luau").read_text())
# Aliases the smoke asks out loud. Fail here if a phrase disappears from the authored gate.
guide = (root / "src/shared/HostGuide.luau").read_text().lower()
for phrase in (
    "lantern cap",
    "stall spark",
    "last seen",
    "party queue",
    "yarn cleave",
    "stall fang",
    "paper charm",
    "kitty caster",
    "smart ping",
    "death recap",
    "purse chip",
    "mute me",
    "meme tape",
    "not robux",
    "press 7",
    "hold g",
):
    if phrase not in guide:
        raise SystemExit(f"HostGuide missing authored phrase: {phrase}")
with tempfile.TemporaryDirectory(prefix="meo-brand-test-") as folder:
    entry = Path(folder) / "smoke.luau"
    entry.write_text("\n".join(chunks))
    subprocess.run([str(luau), str(entry)], check=True)
