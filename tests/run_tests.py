"""Install tests/requirements.txt, then run: python tests/run_tests.py"""
from pathlib import Path
from lupa.lua51 import LuaRuntime
from check_locales import check_locales

root = Path(__file__).resolve().parents[1]
check_locales(root)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('os.setlocale("C", "ctype")')
lua.globals().addonRoot = root.as_posix()
lua.execute((root / "tests" / "run.lua").read_text(encoding="utf-8"))
