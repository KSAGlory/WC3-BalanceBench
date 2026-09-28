"""Run the fake-native Lua test using a local Lupa runtime."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "Build" / "testdeps"))
from lupa import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().arg = lua.table_from({1: str(ROOT / "Scripts" / "BalanceBench.lua")})
lua.execute((ROOT / "Tests" / "runner_spec.lua").read_text(encoding="utf-8"))
