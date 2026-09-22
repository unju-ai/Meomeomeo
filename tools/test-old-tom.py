"""Old Tom jungle-coach smoke. It does not replace a Roblox Studio playtest.

Usage: python3 tools/test-old-tom.py /path/to/luau
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
    ("ModeCatalog", "src/shared/ModeCatalog.luau"),
    ("HostGuide", "src/shared/HostGuide.luau"),
    ("OldTomGuide", "src/shared/OldTomGuide.luau"),
    ("NpcCatalog", "src/server/Npcs/NpcCatalog.luau"),
    ("MockAiProvider", "src/server/Npcs/MockAiProvider.luau"),
    ("Theme", "src/client/Theme.luau"),
    ("NpcChatPanel", "src/client/UI/NpcChatPanel.luau"),
]


def wrap(name: str, rel: str) -> str:
    source = (root / rel).read_text()
    source = re.sub(r"^local \w+ = require\([^\n]+\)\n", "", source, flags=re.MULTILINE)
    return f"local {name} = (function()\n{source}\nend)()\n"


def assert_before(source: str, earlier: str, later: str, label: str) -> None:
    left = source.find(earlier)
    right = source.find(later)
    if left < 0 or right < 0 or left > right:
        raise SystemExit(f"{label}: {earlier} must run before {later}")


http = (root / "src/server/Npcs/HttpAiProvider.luau").read_text()
http_fn = http.split("function HttpAiProvider.complete", 1)[1]
assert_before(http_fn, "HostGuide.reply", "OldTomGuide.reply", "http")
assert_before(http_fn, "OldTomGuide.reply", "HttpService:RequestAsync", "http")

mock = (root / "src/server/Npcs/MockAiProvider.luau").read_text()
mock_fn = mock.split("function MockAiProvider.complete", 1)[1]
assert_before(mock_fn, "HostGuide.reply", "OldTomGuide.reply", "mock")
assert_before(mock_fn, "OldTomGuide.reply", "LINES[context.npc.id]", "mock")

client = (root / "src/client/init.client.luau").read_text()
gate_start = client.find("local function oldTomAmbientOk")
gate_end = client.find("local function showHostMutter")
if gate_start < 0 or gate_end < gate_start:
    raise SystemExit("Old Tom ambient gate missing")
gate = client[gate_start:gate_end]
for phrase in (
    'gameMode ~= "Moba"',
    'phase == "InProgress"',
    "nearRiftFountain",
    "FOUNTAIN_RADIUS = 32",
):
    if phrase not in gate and phrase not in client[client.find("local FOUNTAIN_RADIUS"):gate_end]:
        raise SystemExit(f"Old Tom ambient gate missing {phrase}")
if "Announcer" in gate or "KillFeed" in gate:
    raise SystemExit("Old Tom ambient must stay off the caster feed")
if client.count("OldTomGuide.ambient") != 1:
    raise SystemExit("Old Tom should mutter from the Talk prompt only")

for rel in (
    "src/shared/HostGuide.luau",
    "src/shared/AnnouncerLines.luau",
    "src/server/Match/AnnouncerService.luau",
):
    if "OldTomGuide" in (root / rel).read_text():
        raise SystemExit(f"{rel} should not depend on Old Tom")

chunks = [prelude]
for name, path in modules:
    chunks.append(wrap(name, path))
chunks.append((root / "tests/old-tom-smoke.luau").read_text())
with tempfile.TemporaryDirectory(prefix="meo-old-tom-test-") as folder:
    entry = Path(folder) / "smoke.luau"
    entry.write_text("\n".join(chunks))
    subprocess.run([str(luau), str(entry)], check=True)
