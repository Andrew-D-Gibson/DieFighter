#!/usr/bin/env python3
"""Helpers for replaying AutoPilot runs (tools/autoplay.sh --replay).

    autoplay_replay.py flagged <batch dir> [--limit N]
        Transcripts of the runs a batch flagged: no result (crashed or hung),
        stalled, looping, or with errors or broken invariants. One per line,
        worst first.
    autoplay_replay.py args <transcript>
        The AutoPilot arguments that play that run again, one per line.
    autoplay_replay.py compare <original> <replay>
        Whether the replay played the same run (memory entries and the
        replay's own "stopped" marker aside). Exit status 1 if it didn't.
    autoplay_replay.py gallery <shots dir> <replay transcript>
        Writes index.html in the shots directory: each screenshot beside what
        the transcript says happened from then until the next.

Standard library only.
"""

import argparse
import glob
import html
import json
import os
import sys

# What a replay may differ in without having played a different run.
_IGNORED = {"memory", "stopped"}


def _entries(path):
    out = []
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line:
                try:
                    out.append(json.loads(line))
                except json.JSONDecodeError:
                    # A run killed mid-write leaves half a line.
                    break
    return out


def _result(entries):
    return next((e for e in reversed(entries) if e.get("type") == "result"), None)


def _badness(entries):
    """How badly a run went wrong, 0 for not at all."""
    result = _result(entries)
    if result is None:
        return 4
    if result["outcome"] in ("stalled", "looping"):
        return 3
    if result.get("errors", 0):
        return 2
    if result.get("violations", 0):
        return 1
    return 0


def flagged(batch_dir, limit):
    runs = []
    for path in sorted(glob.glob(os.path.join(batch_dir, "seed_*.jsonl"))):
        badness = _badness(_entries(path))
        if badness:
            runs.append((-badness, path))
    for _, path in sorted(runs)[:limit]:
        print(path)


def args(transcript):
    entries = _entries(transcript)
    header = next((e for e in entries if e.get("type") == "header"), None)
    if header is None:
        sys.exit(f"{transcript} has no header")
    print(f"--seed={header['seed']}")
    print(f"--policy={header['policy']}")
    cell = header.get("gauntlet")
    if cell:
        if not cell.get("spec"):
            sys.exit(f"{transcript} predates replays: its header doesn't name the gauntlet spec")
        print(f"--gauntlet={cell['spec']}")
        print(f"--scenario={cell['scenario']}")
        print(f"--loadout={cell['loadout']}")
        print(f"--sector={cell['sector']}")


def _gameplay(path):
    return [json.dumps(e, sort_keys=True) for e in _entries(path) if e.get("type") not in _IGNORED]


def compare(original, replay):
    a, b = _gameplay(original), _gameplay(replay)
    for index, (left, right) in enumerate(zip(a, b)):
        if left != right:
            print(f"DIVERGED at entry {index + 1}:\n  was: {left[:300]}\n  now: {right[:300]}")
            return 1
    if len(a) != len(b):
        # A replay told to stop early is meant to be shorter.
        stopped = any(e.get("type") == "stopped" for e in _entries(replay))
        if stopped and len(b) < len(a):
            print(f"REPRODUCED up to where it stopped ({len(b)} of {len(a)} entries)")
            return 0
        print(f"DIVERGED: {len(a)} entries before, {len(b)} now")
        return 1
    print("REPRODUCED")
    return 0


# ── Gallery ──────────────────────────────────────────────────────────────────

def _expected_label(entry):
    """The screenshot AutoPilotCamera takes for this entry, if any."""
    kind = entry.get("type")
    if kind == "turn":
        return f"turn_{entry['turn']:03d}"
    if kind == "arrive":
        return f"arrive_{entry['scenario']}"
    if kind == "combat_won":
        return f"won_{entry['scenario']}"
    if kind == "violation":
        return f"violation_{entry['check']}_turn_{entry['turn']:03d}"
    if kind == "error":
        return f"error_turn_{entry['turn']:03d}"
    if kind == "result":
        return f"end_{entry['outcome']}"
    if kind == "stopped":
        return f"stopped_turn_{entry['turn']:03d}"
    return None


def _describe(entry):
    kind = entry.get("type")
    if kind == "turn":
        hand = ", ".join(str(face) for face in entry.get("hand", []))
        line = (f"Turn {entry['turn']} at {entry.get('scenario', '?')}: hull {entry.get('hull')}, "
                f"shields {entry.get('shields')}, charge {entry.get('charge')}, hand [{hand}], "
                f"target {entry.get('target') or '–'}")
        ships = [f"{s['ship']} {s['hull']} hull, intents {' · '.join(a or '–' for a in s.get('intents', []))}"
                 for s in entry.get("ships", [])]
        return [line] + ships
    if kind == "move":
        move = entry["move"]
        if move == "place_die":
            return [f"d{entry['face']}{' (holo)' if entry.get('holographic') else ''} → "
                    f"{_strip(entry['tile'])} [{entry['cell']}]"]
        if move == "target":
            return [f"target {entry['ship']}"]
        if move in ("claim", "buy"):
            return [f"{move} {_strip(entry['item'])}" + (f" for {entry['price']}" if "price" in entry else "")]
        return [move.replace("_", " ")]
    if kind == "arrive":
        return [f"Arrived at {entry['scenario']} (map tile {entry.get('map_index')})"]
    if kind == "combat_won":
        return [f"Won the fight at {entry['scenario']}, hull {entry.get('hull')}"]
    if kind == "error":
        return [f"ERROR at {entry.get('at')}: {entry.get('message')}"]
    if kind == "violation":
        return [f"VIOLATION {entry['check']}: {entry.get('detail')}"]
    if kind == "result":
        return [f"Result: {entry['outcome']} after {entry['turns']} turns"
                + (f", killed by {entry['killed_by']}" if entry.get("killed_by") else "")]
    if kind == "stopped":
        return [f"Stopped at turn {entry['turn']} (--stop-at-turn)"]
    return []


def _strip(text):
    """Drops bbcode colour tags from a tile name."""
    out, depth = [], 0
    for char in text:
        if char == "[":
            depth += 1
        elif char == "]" and depth:
            depth -= 1
        elif not depth:
            out.append(char)
    return "".join(out)


def gallery(shots_dir, transcript):
    entries = _entries(transcript)
    shots = sorted(os.path.basename(p) for p in glob.glob(os.path.join(shots_dir, "*.png")))
    # Each shot is matched to the entry it was taken for, in order; the
    # entries from there to the next shot are what it shows happening.
    anchors = []
    cursor = 0
    for shot in shots:
        label = shot.split("_", 1)[1].rsplit(".", 1)[0]
        for index in range(cursor, len(entries)):
            if _expected_label(entries[index]) == label:
                anchors.append((shot, index))
                cursor = index + 1
                break
        else:
            anchors.append((shot, None))
    cards = []
    for position, (shot, index) in enumerate(anchors):
        lines = []
        if index is not None:
            following = [a for _, a in anchors[position + 1:] if a is not None]
            end = following[0] if following else len(entries)
            for entry in entries[index:end]:
                lines.extend(_describe(entry))
        label = shot.split("_", 1)[1].rsplit(".", 1)[0].replace("_", " ")
        css = " flag" if label.startswith(("error", "violation")) else ""
        cards.append(
            f'<section class="card{css}"><h2>{html.escape(label)}</h2>'
            f'<a href="{html.escape(shot)}"><img src="{html.escape(shot)}" loading="lazy" alt=""></a>'
            + "<ul>" + "".join(f"<li>{html.escape(line)}</li>" for line in lines) + "</ul></section>")
    header = next((e for e in entries if e.get("type") == "header"), {})
    title = f"Replay: seed {header.get('seed', '?')}, {header.get('policy', '?')}"
    if header.get("gauntlet"):
        title += f", {header['gauntlet']['scenario']} × {header['gauntlet']['loadout']}"
    page = ("<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">"
            "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
            f"<title>AutoPilot Replay</title><style>{_CSS}</style></head><body><main>"
            f"<h1>{html.escape(title)}</h1>"
            f'<p class="note">{len(shots)} screenshots from <code>{html.escape(os.path.abspath(transcript))}</code>. '
            "Each shows the board just before the bot's first move there (or the moment of an error), "
            "with what happened until the next.</p>"
            + "".join(cards) + "</main></body></html>")
    path = os.path.join(shots_dir, "index.html")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(page)
    print(path)


_CSS = """
:root { --bg: #f6f6f4; --fg: #1d1d1f; --muted: #6b6b70; --card: #ffffff; --line: #deded8; --bad: #b3261e; }
@media (prefers-color-scheme: dark) {
  :root { --bg: #151517; --fg: #ececee; --muted: #9a9aa2; --card: #1f1f23; --line: #33333a; --bad: #ff8a80; }
}
body { margin: 0; background: var(--bg); color: var(--fg); font: 14px/1.45 system-ui, sans-serif; }
main { max-width: 1040px; margin: 0 auto; padding: 24px 16px 64px; }
h1 { font-size: 22px; margin: 0 0 4px; }
.note { color: var(--muted); margin: 0 0 20px; }
.card { background: var(--card); border: 1px solid var(--line); border-radius: 8px; padding: 12px 14px; margin: 0 0 16px; }
.card.flag { border-color: var(--bad); }
.card.flag h2 { color: var(--bad); }
.card h2 { font-size: 15px; margin: 0 0 8px; text-transform: capitalize; }
.card img { width: 100%; height: auto; image-rendering: pixelated; border-radius: 4px; display: block; }
.card ul { margin: 8px 0 0; padding-left: 18px; color: var(--muted); }
code { font-size: 12px; overflow-wrap: anywhere; }
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("flagged")
    p.add_argument("batch_dir")
    p.add_argument("--limit", type=int, default=3)
    p = sub.add_parser("args")
    p.add_argument("transcript")
    p = sub.add_parser("compare")
    p.add_argument("original")
    p.add_argument("replay")
    p = sub.add_parser("gallery")
    p.add_argument("shots_dir")
    p.add_argument("transcript")
    a = parser.parse_args()
    if a.command == "flagged":
        flagged(a.batch_dir, a.limit)
    elif a.command == "args":
        args(a.transcript)
    elif a.command == "compare":
        sys.exit(compare(a.original, a.replay))
    else:
        gallery(a.shots_dir, a.transcript)


if __name__ == "__main__":
    main()
