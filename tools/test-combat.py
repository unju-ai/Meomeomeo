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
local mt
mt = {
    __index = function(self, key)
        if key == "Magnitude" then
            return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
        elseif key == "Unit" then
            local m = self.Magnitude
            if m < 1e-6 then
                return Vector3.new(0, 0, 0)
            end
            return Vector3.new(self.X / m, self.Y / m, self.Z / m)
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
function Vector3:Dot(other)
    return self.X * other.X + self.Y * other.Y + self.Z * other.Z
end
mt.__index.Dot = function(self, other)
    return self.X * other.X + self.Y * other.Y + self.Z * other.Z
end
"""

script = (
    prelude
    + wrap("Targeting", "src/shared/Targeting.luau")
    + wrap("ProjectileLogic", "src/shared/ProjectileLogic.luau")
    + (root / "tests/combat-smoke.luau").read_text()
)
with tempfile.TemporaryDirectory(prefix="meo-combat-test-") as folder:
    entry = Path(folder) / "smoke.luau"
    entry.write_text(script)
    subprocess.run([str(luau), str(entry)], check=True)
