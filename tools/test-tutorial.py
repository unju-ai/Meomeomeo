"""First-Practice tip deck smoke. Usage: python3 tools/test-tutorial.py /path/to/luau

The Luau compiler, if beside the executable, syntax-checks the whole src tree.
This steps Next / Skip all / Show tips. It does not replace a Studio playtest.
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
                    local copy = {}
                    for index, child in values.children do
                        copy[index] = child
                    end
                    return copy
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
    ("ChampionKits", "src/shared/ChampionKits.luau"),
    ("ItemKits", "src/shared/ItemKits.luau"),
    ("Theme", "src/client/Theme.luau"),
    ("LobbyPanel", "src/client/UI/LobbyPanel.luau"),
    ("HelpPanel", "src/client/UI/HelpPanel.luau"),
    ("TutorialTips", "src/client/UI/TutorialTips.luau"),
]


def wrap(name: str, rel: str) -> str:
    source = (root / rel).read_text()
    source = re.sub(r"^local \w+ = require\([^\n]+\)\n", "", source, flags=re.MULTILINE)
    return f"local {name} = (function()\n{source}\nend)()\n"


store = (root / "src/server/Tutorial/TutorialStore.luau").read_text()
if "MeoTutorial_v1" not in store or "value == true" not in store:
    raise SystemExit("Tutorial dismiss flag changed shape")
if "SetAsync(keyOf(userId), true)" not in store:
    raise SystemExit("Tutorial dismiss must stay a boolean true")
if "tipSet" in store or "TIP_SET" in store:
    raise SystemExit("Do not version the dismiss flag; Show tips replays the current deck")

chunks = [prelude]
for name, path in modules:
    chunks.append(wrap(name, path))
chunks.append((root / "tests/tutorial-smoke.luau").read_text())
with tempfile.TemporaryDirectory(prefix="meo-tutorial-test-") as folder:
    entry = Path(folder) / "smoke.luau"
    entry.write_text("\n".join(chunks))
    subprocess.run([str(luau), str(entry)], check=True)
