"""Jungle bot route / commit / rotate / Canal Levi priority smoke.

Usage: python3 tools/test-jungle-bot.py /path/to/luau

Levi gates live in tests/jungle-bot-smoke.luau: Hard mid beats leftover camps when
UP, finishes a hurt camp first, peels a visible enemy on the pit, resumes after
death; Normal mid-river assist; Easy ignore. Hard ally peel (BotPeelLogic) beats
leftover camps and lane shove, and interrupts Levi only when the ally is
critically low and the fight is nearby. Hard siege (BotSiegeLogic) hits a
vulnerable post the wave is already under. It loses to peel, Levi, a hurt
camp, and a face-range fight, and beats a wounded finish and a full-HP camp.
The yarn core is not that walk. Hard core (BotCoreLogic) hits an open yarn
core with a winning wave, at half HP, or with two allies already on it. It
uses the same siege ranking: peel, Levi, a hurt camp, and a wounded cat in
face range still win, and a full-HP camp still loses. Hard finish
(BotFinishLogic) hunts a visible wounded champion over a full-HP camp and a
lane shove. It loses to flee, peel, Levi, a hurt camp, a face-range fight,
and an active siege (post or open core). A finish whose cat or next step
sits on the enemy fountain pad (BotFountainLogic, the FountainRegenJuice
disk) is refused; a finish outside that pad still happens. An open core
siege is not that pad. Easy and Normal ignore peel, siege, finish, and core.
"""
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


def wrap_deps(name: str, rel: str, deps: list[str]) -> str:
    source = (root / rel).read_text()
    source = re.sub(r"^local \w+ = require\([^\n]+\)\n", "", source, flags=re.MULTILINE)
    inject = "\n".join(f"local {dep} = {dep}" for dep in deps)
    return f"local {name} = (function()\n{inject}\n{source}\nend)()\n"


script = (
    wrap("VisionLogic", "src/shared/VisionLogic.luau")
    + wrap("RiverEpic", "src/shared/RiverEpic.luau")
    + wrap("RiverEpicJuice", "src/shared/RiverEpicJuice.luau")
    + wrap_deps("CampRespawnJuice", "src/shared/CampRespawnJuice.luau", ["VisionLogic", "RiverEpic"])
    + wrap("FountainRegenJuice", "src/shared/FountainRegenJuice.luau")
    + wrap_deps("BotFountainLogic", "src/shared/BotFountainLogic.luau", ["FountainRegenJuice"])
    + wrap("BotCoreLogic", "src/shared/BotCoreLogic.luau")
    + wrap_deps("BotFinishLogic", "src/shared/BotFinishLogic.luau", ["BotFountainLogic"])
    + wrap("BotPeelLogic", "src/shared/BotPeelLogic.luau")
    + wrap("BotSiegeLogic", "src/shared/BotSiegeLogic.luau")
    + wrap_deps("JungleBotLogic", "src/shared/JungleBotLogic.luau", ["RiverEpic", "BotFountainLogic"])
    + wrap("ItemCatalog", "src/shared/ItemCatalog.luau")
    + wrap_deps("BotShopLogic", "src/shared/BotShopLogic.luau", ["ItemCatalog"])
    + (root / "tests/jungle-bot-smoke.luau").read_text()
)
with tempfile.TemporaryDirectory(prefix="meo-jungle-bot-test-") as folder:
    entry = Path(folder) / "smoke.luau"
    entry.write_text(script)
    subprocess.run([str(luau), str(entry)], check=True)
