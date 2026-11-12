"""Build a clean install ZIP containing runtime files and documentation."""

import argparse
from pathlib import Path
import re
from zipfile import ZipFile, ZIP_DEFLATED


ADDON = "QuickKeybinds"


def build_release(root, output_dir):
    root = Path(root).resolve()
    toc = root / f"{ADDON}.toc"
    contents = toc.read_text(encoding="utf-8-sig")
    versions = re.findall(r"^## Version:\s*([^\r\n]+)", contents, re.MULTILINE)
    if len(versions) != 1 or not re.fullmatch(r"\d+\.\d+\.\d+", versions[0]):
        raise ValueError("TOC must contain one Version in major.minor.patch format")
    version = versions[0]
    files = {toc, root / "README.md", root / "TESTING.md", root / "LICENSE"}
    for line in contents.splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            path = (root / line.replace("\\", "/")).resolve()
            if not path.is_relative_to(root):
                raise ValueError(f"TOC references a file outside the addon: {line}")
            files.add(path)
    for path in files:
        if not path.is_file():
            raise FileNotFoundError(f"Missing release file: {path}")
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    archive = output_dir / f"{ADDON}-{version}.zip"
    with ZipFile(archive, "w", ZIP_DEFLATED) as output:
        for path in sorted(files):
            output.write(path, f"{ADDON}/{path.relative_to(root).as_posix()}")
    with ZipFile(archive) as result:
        assert result.testzip() is None
        assert set(result.namelist()) == {f"{ADDON}/{path.relative_to(root).as_posix()}" for path in files}
    return version, archive


def main():
    root = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--addon-root", type=Path, default=root)
    parser.add_argument("--output-dir", type=Path, default=root)
    parser.add_argument("--github-output", type=Path)
    args = parser.parse_args()
    version, archive = build_release(args.addon_root, args.output_dir)
    if args.github_output:
        with args.github_output.open("a", encoding="utf-8") as output:
            output.write(f"version={version}\ntag=v{version}\narchive={archive.as_posix()}\n")
    print(f"Built {archive} ({archive.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
