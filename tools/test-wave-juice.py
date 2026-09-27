"""Lane kitten wave telegraph smoke.

Usage: python3 tools/test-wave-juice.py /path/to/luau

The cadence lives in MinionService (first wait, per-kitten step, then the
interval). WaveJuice only predicts the mouths. This does not spawn kittens.
"""
from pathlib import Path
import re
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
luau = Path(sys.argv[1] if len(sys.argv) > 1 else "luau")

minion = (root / "src/server/Match/MinionService.luau").read_text()
if "local KITTEN_STEP = 0.35" not in minion or "task.wait(KITTEN_STEP)" not in minion:
    raise SystemExit("MinionService kitten step drifted from WaveJuice.KittenStep")
if "task.wait(Config.Minions.FirstWaveDelay)" not in minion:
    raise SystemExit("first wave wait left Config.Minions")
if "task.wait(Config.Minions.WaveInterval)" not in minion:
    raise SystemExit("wave interval wait left Config.Minions")
if "Config.Minions.PerLane" not in minion:
    raise SystemExit("kitten count left Config.Minions")
if "CannonKitten.isCannonSlot(wave, i, Config.Minions.PerLane)" not in minion:
    raise SystemExit("cannon slot is not decided in the lane loop")
if 'spawnOne("Blue", lane, i, cannon)' not in minion or 'spawnOne("Red", lane, i, cannon)' not in minion:
    raise SystemExit("cannon flag is not shared by both teams")
if "api.onLastHit(attackerUserId, gold, pos)" not in minion:
    raise SystemExit("last-hit gold left the minion record")
if "Config.Match.MinionGold" not in minion or "Config.Minions.Health" not in minion:
    raise SystemExit("ordinary kitten stats left Config")
if "minion.damage" not in minion or "minion.speed" not in minion:
    raise SystemExit("cannon combat stats are not on the minion")
if "CannonKitten.Name" not in minion or 'sourceName = CannonKitten.Name' not in minion:
    raise SystemExit("Yarn Cannon is not the kill-feed source name")

config = (root / "src/server/Config.luau").read_text()
for needle in ("Health = 95", "Damage = 14", "Speed = 18", "MinionGold = 18", "FirstWaveDelay = 6", "WaveInterval = 22", "PerLane = 3"):
    if needle not in config:
        raise SystemExit(f"locked kitten number drifted: {needle}")

match = (root / "src/server/Match/MatchService.luau").read_text()
if "a {CannonKitten.Name}" not in match:
    raise SystemExit("kill feed does not name the Yarn Cannon")


def wrap(name: str, rel: str) -> str:
    source = (root / rel).read_text()
    source = re.sub(r"^local \w+ = require\([^\n]+\)\n", "", source, flags=re.MULTILINE)
    return f"local {name} = (function()\n{source}\nend)()\n"


def wrap_deps(name: str, rel: str, deps: list[str]) -> str:
    source = (root / rel).read_text()
    source = re.sub(r"^local \w+ = require\([^\n]+\)\n", "", source, flags=re.MULTILINE)
    inject = "\n".join(f"local {dep} = {dep}" for dep in deps)
    return f"local {name} = (function()\n{inject}\n{source}\nend)()\n"


script = (
    wrap("VisionLogic", "src/shared/VisionLogic.luau")
    + wrap("CannonKitten", "src/shared/CannonKitten.luau")
    + wrap_deps("WaveJuice", "src/shared/WaveJuice.luau", ["VisionLogic"])
    + (root / "tests/wave-juice-smoke.luau").read_text()
)
with tempfile.TemporaryDirectory(prefix="meo-wave-juice-test-") as folder:
    entry = Path(folder) / "smoke.luau"
    entry.write_text(script)
    subprocess.run([str(luau), str(entry)], check=True)
