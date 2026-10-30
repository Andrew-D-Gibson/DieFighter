#!/usr/bin/env python3
"""Check that the project's UIDs, and Godot's caches of them, agree.

A UID is recorded in three places: the file itself (a .tres/.tscn header, a
.gd.uid/.gdshader.uid sidecar, or an asset's .import file), Godot's runtime
lookup table .godot/uid_cache.bin, and the editor's .godot/editor/
filesystem_cache10. Things break when those disagree, and Godot rarely says
why. This reads all three and reports:

  cache header   uid_cache.bin holds more entries than its header counts.
                 Godot reads only the counted ones, so the rest don't resolve
                 at runtime. Seen when the open editor and a headless run
                 (MCP tools, --import, GUT) both update the cache.
  runtime cache  a UID a file declares is missing from uid_cache.bin, or
                 points at a different path there.
  editor cache   the editor cached a different UID (often -1) for a file than
                 the file declares. It only rescans files whose modified time
                 changed, so this sticks until the file is touched.
  invalid        a UID Godot can't have made: a letter outside its alphabet
                 (z, 9) or a value too big for 64 bits. Usually hand-typed;
                 Godot drops it and gives the file a UID of its own.
  duplicate      two files declare the same UID.
  dangling       a file refers to a UID that no file declares.
  wrong path     an ext_resource's uid and path name different files (Godot
                 follows the uid and warns).
  sidecar        a script with no .uid file, a .uid file left uncommitted,
                 or a .uid/.import file whose script or asset is gone.

    python3 tools/check_uids.py      # report; exit 1 if anything is wrong

Run it with the editor closed: an open editor rewrites both caches as it
rescans, so what's on disk can change mid-check. To rebuild the caches, close
the editor and run Godot (the 4.7 binary) with --headless --path . --import.
"""
import re
import struct
import subprocess
import sys
from pathlib import Path

ROOT: Path = Path(__file__).resolve().parent.parent
GODOT_DIR: Path = ROOT / ".godot"
UID_CACHE: Path = GODOT_DIR / "uid_cache.bin"
EDITOR_CACHE: Path = GODOT_DIR / "editor" / "filesystem_cache10"

# Godot writes UIDs in base 34 with this alphabet (core/io/resource_uid.cpp),
# as a positive 64-bit number. The patterns match wider so a bad UID is
# reported whole rather than cut off at its first bad letter.
_UID_CHARS: str = "abcdefghijklmnopqrstuvwxy012345678"
_MAX_UID: int = 2 ** 63 - 1
_UID_PATTERN: re.Pattern = re.compile(r"uid://[a-z0-9]+")
_HEADER_UID: re.Pattern = re.compile(r'^\[gd_(?:scene|resource)\b[^\]]*\buid="(uid://[a-z0-9]+)"')
_IMPORT_UID: re.Pattern = re.compile(r'^uid="(uid://[a-z0-9]+)"', re.MULTILINE)
_EXT_RESOURCE: re.Pattern = re.compile(r'^\[ext_resource\b[^\]]*\]', re.MULTILINE)
_ATTR: re.Pattern = re.compile(r'\b(uid|path)="([^"]*)"')
_SIDECAR_SOURCES: tuple[str, ...] = (".gd", ".gdshader", ".gdshaderinc")
_REFERRING_SUFFIXES: tuple[str, ...] = (".tscn", ".tres", ".gd", ".godot", ".cfg")
# How many lines of each finding to print before summarising the rest.
_SHOWN: int = 12


def uid_to_text(uid: int) -> str:
    if uid < 0:
        return "uid://<invalid>"
    text: str = ""
    while True:
        text = _UID_CHARS[uid % len(_UID_CHARS)] + text
        uid //= len(_UID_CHARS)
        if uid == 0:
            return "uid://" + text


def is_valid_uid(text: str) -> bool:
    value: int = 0
    for char in text.removeprefix("uid://"):
        if char not in _UID_CHARS:
            return False
        value = value * len(_UID_CHARS) + _UID_CHARS.index(char)
    return value <= _MAX_UID


def res_path(path: Path) -> str:
    return "res://" + path.relative_to(ROOT).as_posix()


def project_files() -> list[Path]:
    """Every file Godot sees: skips dot folders and any folder with a .gdignore."""
    found: list[Path] = []
    pending: list[Path] = [ROOT]
    while pending:
        folder: Path = pending.pop()
        if (folder / ".gdignore").exists():
            continue
        for entry in folder.iterdir():
            if entry.name.startswith("."):
                continue
            if entry.is_dir():
                pending.append(entry)
            else:
                found.append(entry)
    return found


def uncommitted_files() -> set[str]:
    """Untracked files git isn't told to ignore."""
    try:
        listing: str = subprocess.run(["git", "ls-files", "--others", "--exclude-standard"], cwd=ROOT,
            capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return set()
    return {"res://" + line for line in listing.splitlines()}


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return ""


def declared_uids(files: list[Path], report) -> dict[str, list[str]]:
    """UID -> the res:// paths that declare it (more than one is a duplicate).
    Invalid UIDs are reported and left out, as Godot leaves them out."""
    declared: dict[str, list[str]] = {}

    def declare(uid: str, owner: str) -> None:
        if is_valid_uid(uid):
            declared.setdefault(uid, []).append(owner)
        else:
            report("invalid", f"{owner} declares {uid}")

    for path in files:
        if path.suffix in (".tres", ".tscn"):
            with path.open(encoding="utf-8", errors="replace") as handle:
                match = _HEADER_UID.match(handle.readline())
            if match:
                declare(match.group(1), res_path(path))
        elif path.suffix in (".uid", ".import"):
            # Checked as orphans elsewhere; one with nothing beside it declares nothing.
            if not path.with_suffix("").exists():
                continue
            if path.suffix == ".uid":
                uid: str = read_text(path).strip()
                if _UID_PATTERN.fullmatch(uid):
                    declare(uid, res_path(path.with_suffix("")))
            else:
                match = _IMPORT_UID.search(read_text(path))
                if match:
                    declare(match.group(1), res_path(path.with_suffix("")))
    return declared


def read_uid_cache() -> tuple[dict[str, str], int, int] | None:
    """(UID -> path for the counted entries, counted, actually present)."""
    if not UID_CACHE.exists():
        return None
    data: bytes = UID_CACHE.read_bytes()
    counted: int = struct.unpack_from("<I", data, 0)[0]
    entries: dict[str, str] = {}
    present: int = 0
    offset: int = 4
    while offset + 12 <= len(data):
        uid, length = struct.unpack_from("<qi", data, offset)
        offset += 12
        path: str = data[offset:offset + length].decode("utf-8", errors="replace")
        offset += length
        if present < counted:
            entries[uid_to_text(uid)] = path
        present += 1
    return entries, counted, present


def read_editor_cache() -> dict[str, str] | None:
    """res:// path -> the UID the editor cached for it."""
    if not EDITOR_CACHE.exists():
        return None
    cached: dict[str, str] = {}
    folder: str = "res://"
    for line in read_text(EDITOR_CACHE).splitlines()[1:]:
        fields: list[str] = line.split("::")
        if line.startswith("::"):
            folder = fields[1]
        elif len(fields) > 2:
            try:
                cached[folder + fields[0]] = uid_to_text(int(fields[2]))
            except ValueError:
                pass
    return cached


def editor_is_open() -> bool:
    try:
        processes: str = subprocess.run(["ps", "-axo", "command"], capture_output=True,
            text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return False
    project: str = str(ROOT)
    return any("godot" in line.lower() and project in line and ("--editor" in line or " -e" in line)
        for line in processes.splitlines())


def main() -> int:
    findings: dict[str, list[str]] = {}

    def report(kind: str, message: str) -> None:
        findings.setdefault(kind, []).append(message)

    if editor_is_open():
        print("Note: the Godot editor is open on this project, so the caches can change"
            " under this check. Close it for a reliable result.\n")

    files: list[Path] = project_files()
    declared: dict[str, list[str]] = declared_uids(files, report)
    owner_of: dict[str, str] = {uid: owners[0] for uid, owners in declared.items()}

    for uid, owners in declared.items():
        if len(owners) > 1:
            report("duplicate", f"{uid} is declared by {', '.join(owners)}")

    runtime = read_uid_cache()
    if runtime is None:
        print("No .godot/uid_cache.bin yet; skipping the runtime cache checks.")
    else:
        entries, counted, present = runtime
        if present != counted:
            report("cache header", f"uid_cache.bin holds {present} entries but its header counts"
                f" {counted}; the last {present - counted} can't be resolved at runtime")
        for uid, owner in owner_of.items():
            cached_path: str | None = entries.get(uid)
            if cached_path is None:
                report("runtime cache", f"{owner} ({uid}) isn't in uid_cache.bin")
            elif cached_path != owner:
                report("runtime cache", f"{uid} is {owner}, but uid_cache.bin says {cached_path}")

    editor = read_editor_cache()
    if editor is not None:
        for uid, owner in owner_of.items():
            cached_uid: str | None = editor.get(owner)
            if cached_uid is not None and cached_uid != uid:
                report("editor cache", f"{owner} declares {uid}, the editor cached {cached_uid}")

    for path in files:
        if path.suffix not in _REFERRING_SUFFIXES:
            continue
        text: str = read_text(path)
        if not text:
            continue
        here: str = res_path(path)
        own_uid: str | None = None
        if path.suffix in (".tres", ".tscn"):
            match = _HEADER_UID.match(text)
            own_uid = match.group(1) if match else None
            for tag in _EXT_RESOURCE.findall(text):
                attrs: dict[str, str] = dict(_ATTR.findall(tag))
                uid = attrs.get("uid", "")
                target: str = attrs.get("path", "")
                if uid in owner_of and target and owner_of[uid] != target:
                    report("wrong path", f"{here}: {uid} is {owner_of[uid]}, but the path says {target}")
        for uid in sorted(set(_UID_PATTERN.findall(text))):
            if uid == own_uid or uid in owner_of:
                continue
            if not is_valid_uid(uid):
                report("invalid", f"{here} refers to {uid}")
            else:
                report("dangling", f"{here} refers to {uid}, which no file declares")

    uncommitted: set[str] = uncommitted_files()
    for path in files:
        if path.suffix in _SIDECAR_SOURCES:
            sidecar: Path = path.with_name(path.name + ".uid")
            if not sidecar.exists():
                report("sidecar", f"{res_path(path)} has no .uid file (open the project in the editor,"
                    " or run --import, to make one)")
            elif res_path(sidecar) in uncommitted:
                report("sidecar", f"{res_path(sidecar)} isn't committed")
        elif path.suffix in (".uid", ".import") and not path.with_suffix("").exists():
            what: str = "script" if path.suffix == ".uid" else "asset"
            report("sidecar", f"{res_path(path)} has no {what} beside it")

    if not findings:
        print(f"All {len(owner_of)} UIDs agree with both caches.")
        return 0
    for kind, messages in findings.items():
        print(f"{kind}: {len(messages)}")
        for message in messages[:_SHOWN]:
            print(f"  {message}")
        if len(messages) > _SHOWN:
            print(f"  ... and {len(messages) - _SHOWN} more")
    if {"cache header", "runtime cache", "editor cache"} & findings.keys():
        print("\nStale caches: close the editor, then run Godot (the 4.7 binary) with"
            " --headless --path . --import. If an editor-cache entry survives that, touch the"
            " file and import again.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
