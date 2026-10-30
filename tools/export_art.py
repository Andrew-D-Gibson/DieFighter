#!/usr/bin/env python3
"""Export the .aseprite sources in Art/ to the PNGs the game loads from Assets/.

Art/ mirrors Assets/: Art/Textures/UI/foo.aseprite exports to
Assets/Textures/UI/foo.png when it has one frame, or to foo-Sheet.png (a
horizontal strip of every frame) when it has several. Only visible layers are
drawn. Folders under Art/ whose name starts with "_" (palettes, layout
workfiles) are never exported.

A PNG is only rewritten when its pixels change, so re-exporting everything is
cheap and leaves untouched art byte-for-byte alone (no churn in git, no
reimport in Godot).

    python3 tools/export_art.py                  # export every source
    python3 tools/export_art.py Art/Textures/UI  # only these files/folders
    python3 tools/export_art.py --since ORIG_HEAD
                                                 # only sources changed since a
                                                 # commit, plus uncommitted ones
    python3 tools/export_art.py --check          # write nothing; exit 1 if any
                                                 # PNG is stale or has no source

Needs Aseprite (set ASEPRITE to its binary if it isn't found) and Pillow.
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("export_art: Pillow is missing; install it with `python3 -m pip install pillow`.")

ROOT: Path = Path(__file__).resolve().parent.parent
ART: Path = ROOT / "Art"
ASSETS: Path = ROOT / "Assets"
LUA: Path = ROOT / "tools" / "export_art.lua"
SOURCE_SUFFIXES: tuple[str, ...] = (".aseprite", ".ase")
ASEPRITE_CANDIDATES: tuple[str, ...] = (
    "/Applications/Aseprite.app/Contents/MacOS/aseprite",
    "/Applications/Steam_Aseprite.app/Contents/MacOS/aseprite",
    "~/Library/Application Support/Steam/steamapps/common/Aseprite/Aseprite.app/Contents/MacOS/aseprite",
)
# Unreferenced leftovers that clash with a source's name, kept until someone
# decides to delete them. Nothing in the game loads them.
UNSOURCED_OK: tuple[str, ...] = (
    "Assets/Textures/Backgrounds/ScrollingObjects/Fate/fate_cluster-Sheet.png",
    "Assets/Textures/Backgrounds/ScrollingObjects/Fate/fate_mote-Sheet.png",
    "Assets/Textures/Backgrounds/ScrollingObjects/Fate/fate_shard_1-Sheet.png",
    "Assets/Textures/Backgrounds/ScrollingObjects/Fate/fate_shard_2-Sheet.png",
    "Assets/Textures/Backgrounds/ScrollingObjects/Fate/fate_shard_3-Sheet.png",
    "Assets/Textures/Modifiers/lockout.png",
)


def find_aseprite() -> str:
    for candidate in [os.environ.get("ASEPRITE", ""), shutil.which("aseprite") or ""] + list(ASEPRITE_CANDIDATES):
        path: str = os.path.expanduser(candidate)
        if path and os.access(path, os.X_OK):
            return path
    sys.exit("export_art: Aseprite not found; set ASEPRITE to its binary.")


def is_exported(source: Path) -> bool:
    rel: Path = source.relative_to(ART)
    return source.suffix in SOURCE_SUFFIXES and not any(part.startswith("_") for part in rel.parts[:-1])


def all_sources() -> list[Path]:
    return sorted(p for p in ART.rglob("*") if p.is_file() and is_exported(p))


def output_base(source: Path) -> Path:
    """Assets path of the export, without the .png / -Sheet.png ending."""
    return (ASSETS / source.relative_to(ART)).with_suffix("")


def git_lines(*args: str) -> list[str]:
    result = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=True)
    return [line for line in result.stdout.splitlines() if line]


def sources_since(rev: str) -> list[Path]:
    changed: set[str] = set(git_lines("diff", "--name-only", rev, "HEAD", "--", "Art"))
    changed |= set(git_lines("diff", "--name-only", "HEAD", "--", "Art"))
    changed |= set(git_lines("ls-files", "--others", "--exclude-standard", "--", "Art"))
    picked: list[Path] = []
    for name in sorted(changed):
        path: Path = ROOT / name
        if path.exists() and is_exported(path):
            picked.append(path)
        elif not path.exists() and path.suffix in SOURCE_SUFFIXES:
            print(f"note: {name} was deleted; its PNG in Assets/ is left in place", file=sys.stderr)
    return picked


def sources_under(paths: list[str]) -> list[Path]:
    picked: list[Path] = []
    for raw in paths:
        path: Path = Path(raw).resolve()
        if path.is_dir():
            picked += [p for p in path.rglob("*") if p.is_file() and is_exported(p)]
        elif path.is_file() and is_exported(path):
            picked.append(path)
        else:
            sys.exit(f"export_art: {raw} is not an exported source under Art/")
    return sorted(set(picked))


def pixels(path: Path) -> tuple[tuple[int, int], bytes]:
    """RGBA pixels with fully transparent pixels zeroed, since their RGB is invisible noise."""
    image: Image.Image = Image.open(path).convert("RGBA")
    alpha: Image.Image = image.getchannel("A").point(lambda a: 255 if a else 0)
    cleared: Image.Image = Image.new("RGBA", image.size, (0, 0, 0, 0))
    cleared.paste(image, mask=alpha)
    return image.size, cleared.tobytes()


def render(sources: list[Path], scratch: Path) -> dict[Path, Path]:
    """Renders every source in one Aseprite run; returns source -> rendered PNG."""
    jobs: Path = scratch / "jobs.tsv"
    with jobs.open("w") as handle:
        for index, source in enumerate(sources):
            handle.write(f"{source}\t{scratch / str(index)}\n")
    result = subprocess.run(
        [find_aseprite(), "-b", "--script-param", f"jobs={jobs}", "--script", str(LUA)],
        capture_output=True, text=True, timeout=600)
    rendered: dict[Path, Path] = {}
    for line in result.stdout.splitlines():
        status, source, detail = (line.split("\t") + ["", ""])[:3]
        if status == "ok":
            rendered[Path(source)] = Path(detail)
        elif status == "error":
            print(f"error: {Path(source).relative_to(ROOT)}: {detail}", file=sys.stderr)
    missing: list[Path] = [s for s in sources if s not in rendered]
    if missing and not any(line.startswith("error") for line in result.stdout.splitlines()):
        sys.exit(f"export_art: Aseprite rendered nothing.\n{result.stdout}{result.stderr}")
    return rendered


def unsourced_pngs() -> list[Path]:
    expected: set[Path] = set()
    for source in all_sources():
        base: Path = output_base(source)
        expected |= {base.with_suffix(".png"), base.parent / (base.name + "-Sheet.png")}
    return sorted(p for p in ASSETS.rglob("*.png")
        if p not in expected and str(p.relative_to(ROOT)) not in UNSOURCED_OK)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("paths", nargs="*", help="sources or folders under Art/ (default: all)")
    parser.add_argument("--since", metavar="REV", help="only sources changed since REV, plus uncommitted ones")
    parser.add_argument("--check", action="store_true", help="write nothing; exit 1 if anything is stale")
    args = parser.parse_args()

    if args.since:
        sources: list[Path] = sources_since(args.since)
    elif args.paths:
        sources = sources_under(args.paths)
    else:
        sources = all_sources()
    if not sources:
        print("export_art: nothing to export")
        return 0

    problems: int = 0
    written: list[str] = []
    with tempfile.TemporaryDirectory(prefix="export_art_") as tmp:
        rendered: dict[Path, Path] = render(sources, Path(tmp))
        problems += len(sources) - len(rendered)
        for source, image in rendered.items():
            base: Path = output_base(source)
            sheet: bool = image.name.endswith("-Sheet.png")
            target: Path = base.with_name(base.name + ("-Sheet.png" if sheet else ".png"))
            other: Path = base.with_name(base.name + (".png" if sheet else "-Sheet.png"))
            rel: Path = target.relative_to(ROOT)
            if other.exists() and str(other.relative_to(ROOT)) not in UNSOURCED_OK:
                print(f"warning: {other.relative_to(ROOT)} also exists; {source.relative_to(ROOT)} now has "
                    f"{'several frames' if sheet else 'one frame'}, so it exports {rel.name}",
                    file=sys.stderr)
            if target.exists() and pixels(target) == pixels(image):
                continue
            if args.check:
                print(f"stale: {rel}  (from {source.relative_to(ROOT)})")
                problems += 1
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(image, target)
                written.append(str(rel))

    if args.check:
        for png in unsourced_pngs():
            print(f"no source: {png.relative_to(ROOT)}")
            problems += 1
        print(f"export_art: checked {len(sources)} sources, {problems} problem(s)")
        return 1 if problems else 0

    for name in written:
        print(f"exported {name}")
    print(f"export_art: {len(written)} PNG(s) updated, {len(sources) - len(written)} already current")
    if written:
        print("Godot reimports them the next time the editor gets focus "
            "(or run `Godot --headless --path . --import`). New PNGs get a new .import to commit.")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
