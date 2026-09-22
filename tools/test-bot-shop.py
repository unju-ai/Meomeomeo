"""Practice-bot Pawmart plan smoke. Usage: python3 tools/test-bot-shop.py /path/to/luau"""
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
local Color3 = {}
function Color3.fromRGB(r, g, b)
    return { _kind = "Color3", R = r, G = g, B = b }
end
"""

script = (
    prelude
    + wrap("ItemCatalog", "src/shared/ItemCatalog.luau")
    + wrap("ChampionCatalog", "src/shared/ChampionCatalog.luau")
    + wrap("BotShopLogic", "src/shared/BotShopLogic.luau")
    + (root / "tests/bot-shop-smoke.luau").read_text()
)
with tempfile.TemporaryDirectory(prefix="meo-bot-shop-test-") as folder:
    entry = Path(folder) / "smoke.luau"
    entry.write_text(script)
    result = subprocess.run([str(luau), str(entry)], check=True, capture_output=True, text=True)
named = ("Yarnplate", "Paper Charm", "Longclaw", "Stall Fang", "Mana Treat", "Yarn Cleave", "Control Yarn", "Whisker Lens")
missing = [name for name in named if name not in result.stdout]
if missing:
    sys.stderr.write(result.stdout)
    sys.stderr.write(result.stderr)
    raise SystemExit("bot shop smoke did not name: " + ", ".join(missing))
sys.stdout.write(result.stdout)
