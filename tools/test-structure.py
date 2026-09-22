"""Cat Rift structure layout + gate + HP bar smoke. Usage: python3 tools/test-structure.py /path/to/luau"""
from pathlib import Path
import re
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
luau = Path(sys.argv[1] if len(sys.argv) > 1 else "luau")


def wrap(name: str, rel: str) -> str:
    source = (root / rel).read_text()
    return f"local {name} = (function()\n{source}\nend)()\n"


def wrap_deps(name: str, rel: str, deps: list[str]) -> str:
    """Strip script.Parent requires and inject already-wrapped sibling tables."""
    source = (root / rel).read_text()
    source = re.sub(r"^local \w+ = require\([^\n]+\)\n", "", source, flags=re.MULTILINE)
    inject = "\n".join(f"local {dep} = {dep}" for dep in deps)
    return f"local {name} = (function()\n{inject}\n{source}\nend)()\n"


script = (
    wrap("BotCoreLogic", "src/shared/BotCoreLogic.luau")
    + wrap("StructureLogic", "src/shared/StructureLogic.luau")
    + wrap("BillboardHp", "src/shared/BillboardHp.luau")
    + wrap_deps("ChampionPlate", "src/shared/ChampionPlate.luau", ["BillboardHp"])
    + wrap_deps("StructureDeathJuice", "src/shared/StructureDeathJuice.luau", ["StructureLogic"])
    + wrap("StructureAggroJuice", "src/shared/StructureAggroJuice.luau")
    + (root / "tests/structure-smoke.luau").read_text()
)
with tempfile.TemporaryDirectory(prefix="meo-structure-test-") as folder:
    entry = Path(folder) / "smoke.luau"
    entry.write_text(script)
    subprocess.run([str(luau), str(entry)], check=True)
