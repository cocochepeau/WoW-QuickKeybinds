"""Audit addon-owned text and translated format strings without a running client."""
from pathlib import Path
import re
from lupa.lua51 import LuaRuntime

LITERAL = r'"(?:\\.|[^"\\])*"'
LOOKUP = re.compile(
    rf'\bL\s*\[\s*({LITERAL})\s*\]|\bL\.([A-Za-z_]\w*)|(?:\bT|:F)\s*\(\s*({LITERAL})'
)
RAW_LABEL = re.compile(
    rf':(?:SetText|SetTitle|Print|AddLine|Dialog|Confirm)\s*\(\s*({LITERAL})|'
    rf'(?:\bbutton|\btext|\.UIButton|\.UIText)\s*\(\s*[^,\n]+,\s*({LITERAL})'
)
PRINTF = re.compile(r'%[-+ #0]*\d*(?:\.\d+)?([cdiouxXeEfgGqs%])')


def check_locales(root: Path):
    lua = LuaRuntime(unpack_returned_tuples=True)
    namespace = lua.table()
    loader = lua.eval('function(path, ns) assert(loadfile(path))("QuickKeybinds", ns) end')
    loader((root / 'Locale.lua').as_posix(), namespace)
    catalogs = {}
    for locale in ('enUS', 'frFR', 'deDE'):
        loader((root / 'Locales' / f'{locale}.lua').as_posix(), namespace)
        catalogs[locale] = dict(namespace.LocaleTables[locale].items())
    english = catalogs['enUS']
    for locale, catalog in catalogs.items():
        assert set(catalog) == set(english), f'{locale}: catalog entries differ'
        for key, value in catalog.items():
            assert isinstance(value, str) and value.strip(), f'{locale}: empty entry {key}'
            if key != 'History date format':
                expected = [x for x in PRINTF.findall(english[key]) if x != '%']
                actual = [x for x in PRINTF.findall(value) if x != '%']
                assert actual == expected, f'{locale}: placeholder mismatch for {key}'
    for path in [*root.glob('*.lua'), *root.glob('Locales/*.lua')]:
        source = path.read_text(encoding='utf-8')
        assert '\ufffd' not in source, f'{path.name}: replacement characters in UTF-8 text'
        if path.parent.name == 'Locales':
            continue
        # Remove comments so an example cannot masquerade as a translated UI call.
        code = re.sub(r'--[^\n]*', '', source)
        for match in LOOKUP.finditer(code):
            quoted, field, formatted = match.groups()
            key = field or lua.eval(quoted or formatted)
            assert key in english, f'{path.name}: missing locale key {key!r}'
        for match in RAW_LABEL.finditer(code):
            value = lua.eval(next(x for x in match.groups() if x))
            value = re.sub(r'\|c[0-9a-fA-F]{8}|\|r', '', value)
            if not re.search(r'[A-Za-z]{2}', value):
                continue
            # Brand names and literal slash commands intentionally retain their spelling.
            assert value.startswith(('QuickKeybinds', '/qkb')), f'{path.name}: untranslated UI literal {value!r}'
    print(f'Locale audit: {len(english)} entries complete in English, French and German.')


if __name__ == '__main__':
    check_locales(Path(__file__).resolve().parents[1])
