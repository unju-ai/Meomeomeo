"""Combat targeting + traveling projectile smoke. Usage: python3 tools/test-combat.py /path/to/luau"""
from pathlib import Path
import re
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
luau = Path(sys.argv[1] if len(sys.argv) > 1 else "luau")


def wrap(name: str, rel: str) -> str:
    source = (root / rel).read_text()
    source = re.sub(r"^local \w+ = require\([^\n]+\)\n", "", source, flags=re.MULTILINE)
    return f"local {name} = (function()\n{source}\nend)()\n"


prelude = r"""
local Vector3 = {}
local function dot(self, other)
    return self.X * other.X + self.Y * other.Y + self.Z * other.Z
end
local mt = {
    __index = function(self, key)
        if key == "Magnitude" then
            return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
        elseif key == "Unit" then
            local m = self.Magnitude
            if m < 1e-6 then
                return Vector3.new(0, 0, 0)
            end
            return Vector3.new(self.X / m, self.Y / m, self.Z / m)
        elseif key == "Dot" then
            return dot
        end
        return nil
    end,
    __add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end,
    __sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end,
    __mul = function(a, b)
        if type(a) == "number" then
            return Vector3.new(b.X * a, b.Y * a, b.Z * a)
        end
        return Vector3.new(a.X * b, a.Y * b, a.Z * b)
    end,
}
function Vector3.new(x, y, z)
    return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, mt)
end
local Color3 = {}
function Color3.fromRGB(r, g, b)
    return { R = r, G = g, B = b }
end
"""

script = (
    prelude
    + wrap("RiverEpic", "src/shared/RiverEpic.luau")
    + wrap("RiverEpicJuice", "src/shared/RiverEpicJuice.luau")
    + wrap("CombatFloat", "src/shared/CombatFloat.luau")
    + wrap("LastHitJuice", "src/shared/LastHitJuice.luau")
    + wrap("BountyJuice", "src/shared/BountyJuice.luau")
    + wrap("XpJuice", "src/shared/XpJuice.luau")
    + wrap("Progression", "src/shared/Progression.luau")
    + wrap("LevelUpJuice", "src/shared/LevelUpJuice.luau")
    + wrap("FountainRegenJuice", "src/shared/FountainRegenJuice.luau")
    + wrap("RespawnJuice", "src/shared/RespawnJuice.luau")
    + wrap("ActiveJuice", "src/shared/ActiveJuice.luau")
    + wrap("ScratchJuice", "src/shared/ScratchJuice.luau")
    + wrap("AbilityRefuseJuice", "src/shared/AbilityRefuseJuice.luau")
    + wrap("AbilitySuccessJuice", "src/shared/AbilitySuccessJuice.luau")
    + wrap("Targeting", "src/shared/Targeting.luau")
    + wrap("VisionLogic", "src/shared/VisionLogic.luau")
    + wrap("ProjectileLogic", "src/shared/ProjectileLogic.luau")
    + wrap("ChampionCatalog", "src/shared/ChampionCatalog.luau")
    + wrap("ChampionKits", "src/shared/ChampionKits.luau")
    + (root / "tests/combat-smoke.luau").read_text()
)
with tempfile.TemporaryDirectory(prefix="meo-combat-test-") as folder:
    entry = Path(folder) / "smoke.luau"
    entry.write_text(script)
    result = subprocess.run([str(luau), str(entry)], check=True, capture_output=True, text=True)
named = (
    "Golden Parachute",
    "Encore",
    "Office Hours",
    "Packet Buffer",
    "Overclock",
    "Honor Bleed",
    "Shield Fortify",
    "Alley Mark",
    "Smoke Vanish",
    "Chrome Plate",
    "Lunge Reload",
    "Ward Omen",
    "Foresight Veil",
    "Spell Charge",
    "Charged Meteor",
    "Curse Stacks",
    "Hex Zone",
    "Psi Mark",
    "Mind Nudge",
    "CombatFloat",
    "LastHitJuice",
    "BountyJuice",
    "XpJuice",
    "Progression",
    "LevelUpJuice",
    "FountainRegenJuice",
    "RespawnJuice",
    "ActiveJuice",
    "ScratchJuice",
    "AbilityRefuseJuice",
    "AbilitySuccessJuice",
    "draft teasers",
    "wall clip",
)
missing = [name for name in named if name not in result.stdout]
if missing:
    sys.stderr.write(result.stdout)
    sys.stderr.write(result.stderr)
    raise SystemExit("combat smoke did not name: " + ", ".join(missing))
sys.stdout.write(result.stdout)
