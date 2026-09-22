"""Pawmart item stack + night-market effect smoke. Usage: python3 tools/test-items.py /path/to/luau"""
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
local mt = {
    __index = function(self, key)
        if key == "Magnitude" then
            return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
        end
        return nil
    end,
}
function Vector3.new(x, y, z)
    return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, mt)
end
"""

script = (
    prelude
    + wrap("ItemKits", "src/shared/ItemKits.luau")
    + wrap("ItemCatalog", "src/shared/ItemCatalog.luau")
    + (root / "tests/item-smoke.luau").read_text()
)
with tempfile.TemporaryDirectory(prefix="meo-item-test-") as folder:
    entry = Path(folder) / "smoke.luau"
    entry.write_text(script)
    result = subprocess.run([str(luau), str(entry)], check=True, capture_output=True, text=True)
named = ("Yarn Cleave", "Stall Fang", "Paper Charm", "Control Yarn")
missing = [name for name in named if name not in result.stdout]
if missing:
    sys.stderr.write(result.stdout)
    sys.stderr.write(result.stderr)
    raise SystemExit("item smoke did not name: " + ", ".join(missing))
sys.stdout.write(result.stdout)
