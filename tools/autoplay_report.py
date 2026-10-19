#!/usr/bin/env python3
"""Balance report for a batch of AutoPilot runs.

Reads every transcript (seed_*.jsonl) in a batch directory, as written by
tools/autoplay.sh, and writes report.html beside them: how runs ended, which
encounters kill, what hurts, what each enemy and tile does, and what gets
picked up. Prints the headlines too. A batch that played more than one
policy (tools/autoplay.sh --policy random,smart) sets them side by side: the
gap between how random and smart players fare says which fights and tiles
reward playing well, and which are luck or a wall.

Usage:
    tools/autoplay_report.py <batch dir> [--top N]

Standard library only. Every number comes from the transcripts, which hold
gameplay state only, so a batch re-run from the same seeds reports the same.
"""

import argparse
import glob
import html
import json
import os
import statistics
import sys
from collections import Counter, defaultdict


def load_runs(batch_dir):
    """One dict per transcript: its seed, entries by type, and the result."""
    runs = []
    for path in sorted(glob.glob(os.path.join(batch_dir, "seed_*.jsonl"))):
        entries = []
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if line:
                    entries.append(json.loads(line))
        header = next((e for e in entries if e["type"] == "header"), {})
        result = next((e for e in reversed(entries) if e["type"] == "result"), None)
        runs.append({
            "seed": header.get("seed"),
            "policy": header.get("policy", "?"),
            "entries": entries,
            "result": result,
        })
    return runs


def of_type(run, kind):
    return [e for e in run["entries"] if e["type"] == kind]


def pct(part, whole):
    return 100.0 * part / whole if whole else 0.0


def mean(values):
    values = list(values)
    return statistics.fmean(values) if values else 0.0


# ── Analysis ─────────────────────────────────────────────────────────────────

def overview(runs):
    finished = [r for r in runs if r["result"]]
    outcomes = Counter(r["result"]["outcome"] for r in finished)
    turns = [r["result"]["turns"] for r in finished]
    reached = Counter((r["result"].get("sector", 0), r["result"].get("map_index", 0)) for r in finished)
    fights_won = [sum(1 for v in of_type(r, "visit") if v["result"] == "won" and v["fought"]) for r in runs]
    return {
        "runs": len(runs),
        "no_result": len(runs) - len(finished),
        "outcomes": outcomes,
        "turns_median": statistics.median(turns) if turns else 0,
        "turns_max": max(turns) if turns else 0,
        "fights_won_mean": mean(fights_won),
        "furthest": max(reached) if reached else (0, 0),
        "reached": reached,
        "errors": sum(r["result"].get("errors", 0) for r in finished),
        "violations": sum(r["result"].get("violations", 0) for r in finished),
        "policies": Counter(r["policy"] for r in runs),
    }


def by_policy(runs):
    """Runs grouped by policy, random first (it's the baseline), then the
    rest in the order the batch has them."""
    groups = {}
    for run in runs:
        groups.setdefault(run["policy"], []).append(run)
    order = sorted(groups, key=lambda name: (name != "random", list(groups).index(name)))
    return {name: groups[name] for name in order}


def encounters(runs):
    """Per scenario: how visits went. A fight counts once per visit."""
    table = defaultdict(lambda: {
        "visits": 0, "fights": 0, "won": 0, "fled": 0, "died": 0,
        "hull_lost": [], "turns": [], "offers": 0, "claimed": 0, "bought": 0,
    })
    for run in runs:
        for visit in of_type(run, "visit"):
            row = table[visit["scenario"]]
            row["visits"] += 1
            if visit["fought"]:
                row["fights"] += 1
                row["hull_lost"].append(visit["hull_lost"])
                row["turns"].append(visit["turns"])
            if visit["result"] in ("won", "fled", "died"):
                row[visit["result"]] += 1
            row["offers"] += visit.get("offers", 0)
            row["claimed"] += visit.get("claimed", 0)
            row["bought"] += visit.get("bought", 0)
    return table


def damage_sources(runs):
    """Damage the player took, by "Ship: Action" (or environment)."""
    totals = Counter()
    for run in runs:
        for visit in of_type(run, "visit"):
            totals.update(visit.get("damage_taken", {}))
    return totals


def killers(runs):
    return Counter(r["result"].get("killed_by") or "?" for r in runs
                   if r["result"] and r["result"]["outcome"] == "defeat")


def death_places(runs):
    return Counter(r["result"]["scenario"] for r in runs
                   if r["result"] and r["result"]["outcome"] == "defeat")


def enemies(runs):
    table = defaultdict(lambda: {"runs": 0, "destroyed": 0, "escaped": 0,
                                 "damage_to_player": 0, "actions": Counter()})
    for run in runs:
        if not run["result"]:
            continue
        for name, stats in run["result"].get("enemies", {}).items():
            row = table[name]
            row["runs"] += 1
            row["destroyed"] += stats["destroyed"]
            row["escaped"] += stats["escaped"]
            row["damage_to_player"] += stats["damage_to_player"]
            row["actions"].update(stats["actions"])
    return table


def tiles(runs):
    """Per tile: how much it was used and what it produced, plus how runs
    that used it went against the batch as a whole (a crude lift: with a
    random bot, owning a tile is mostly luck, so it hints, not proves)."""
    table = defaultdict(lambda: {"runs": 0, "activations": 0, "damage": 0, "shields": 0,
                                 "heal": 0, "charge": 0, "statuses": 0,
                                 "fights_won": [], "acquired": 0})
    for run in runs:
        if not run["result"]:
            continue
        won = sum(1 for v in of_type(run, "visit") if v["result"] == "won" and v["fought"])
        for name, stats in run["result"].get("tiles", {}).items():
            row = table[name]
            row["runs"] += 1
            row["fights_won"].append(won)
            for key in ("activations", "damage", "shields", "heal", "charge", "statuses"):
                row[key] += stats.get(key, 0)
        for move in of_type(run, "move"):
            if move["move"] in ("claim", "buy"):
                table[move["item"]]["acquired"] += 1
    return table


def acquisitions(runs):
    claims, buys = Counter(), Counter()
    for run in runs:
        for move in of_type(run, "move"):
            if move["move"] == "claim":
                claims[_item_kind(move["item"])] += 1
            elif move["move"] == "buy":
                buys[_item_kind(move["item"])] += 1
    return claims, buys


def _item_kind(item):
    return "credits" if item.endswith(" credits") else item


def gauntlet(runs):
    """Per (scenario, sector) × loadout: how the cell's runs ended. None if
    the batch isn't a gauntlet."""
    cells = defaultdict(lambda: {"runs": 0, "outcomes": Counter(), "hull_lost": [], "turns": []})
    loadouts = []
    for run in runs:
        header = next((e for e in run["entries"] if e["type"] == "header"), {})
        cell_info = header.get("gauntlet")
        if not cell_info or not run["result"]:
            continue
        if cell_info["loadout"] not in loadouts:
            loadouts.append(cell_info["loadout"])
        cell = cells[((cell_info["scenario"], cell_info["sector"]), cell_info["loadout"])]
        cell["runs"] += 1
        cell["outcomes"][run["result"]["outcome"]] += 1
        visit = next((v for v in of_type(run, "visit")), None)
        if visit:
            cell["turns"].append(visit["turns"])
            if run["result"]["outcome"] == "cleared":
                cell["hull_lost"].append(visit["hull_lost"])
    if not cells:
        return None
    scenarios = sorted({key[0] for key in cells}, key=lambda k: (k[1], k[0]))
    return {"cells": cells, "scenarios": scenarios, "loadouts": loadouts}


def failures(runs):
    checks = Counter()
    errors = Counter()
    for run in runs:
        for entry in of_type(run, "violation"):
            checks[entry["check"]] += 1
        for entry in of_type(run, "error"):
            errors[entry["at"]] += 1
    return checks, errors


# ── HTML ─────────────────────────────────────────────────────────────────────

_CSS = """
:root {
  --bg: #f6f5f1; --panel: #ffffff; --ink: #1d1d1b; --muted: #6b6a66;
  --line: #e3e1da; --accent: #5b4bd6; --bad: #c2412d; --good: #2f8a4e; --bar: #d9d4f7;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #15151a; --panel: #1e1e25; --ink: #ecebf2; --muted: #9a99a6;
    --line: #2f2f39; --accent: #a79cff; --bad: #ff7a63; --good: #6fd391; --bar: #3a3566;
  }
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--ink);
  font: 14px/1.45 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
main { max-width: 1100px; margin: 0 auto; padding: 24px 16px 64px; }
h1 { font-size: 22px; margin: 0 0 4px; }
h2 { font-size: 16px; margin: 32px 0 8px; }
p.note { color: var(--muted); margin: 4px 0 12px; max-width: 75ch; }
.cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 12px; margin-top: 16px; }
.card { background: var(--panel); border: 1px solid var(--line); border-radius: 8px; padding: 12px; }
.card .v { font-size: 22px; font-weight: 600; }
.card .k { color: var(--muted); font-size: 12px; }
.scroll { overflow-x: auto; background: var(--panel); border: 1px solid var(--line); border-radius: 8px; }
table { border-collapse: collapse; width: 100%; font-variant-numeric: tabular-nums; }
th, td { padding: 6px 10px; text-align: right; border-bottom: 1px solid var(--line); white-space: nowrap; }
th:first-child, td:first-child { text-align: left; }
th { font-size: 12px; color: var(--muted); font-weight: 600; cursor: pointer; user-select: none; position: sticky; top: 0; background: var(--panel); }
th[data-dir="asc"]::after { content: " ▲"; } th[data-dir="desc"]::after { content: " ▼"; }
tr:last-child td { border-bottom: none; }
td.bad { color: var(--bad); font-weight: 600; } td.good { color: var(--good); }
.barcell { position: relative; }
.barcell span.b { position: absolute; left: 0; top: 4px; bottom: 4px; background: var(--bar); border-radius: 3px; z-index: 0; }
.barcell span.t { position: relative; z-index: 1; }
"""

_JS = """
document.querySelectorAll("table.sortable").forEach(function (table) {
  table.querySelectorAll("th").forEach(function (th, col) {
    th.addEventListener("click", function () {
      var dir = th.dataset.dir === "desc" ? "asc" : "desc";
      table.querySelectorAll("th").forEach(function (o) { delete o.dataset.dir; });
      th.dataset.dir = dir;
      var rows = Array.from(table.tBodies[0].rows);
      rows.sort(function (a, b) {
        var x = a.cells[col].dataset.sort, y = b.cells[col].dataset.sort;
        var nx = parseFloat(x), ny = parseFloat(y);
        var c = (!isNaN(nx) && !isNaN(ny)) ? nx - ny : String(x).localeCompare(String(y));
        return dir === "asc" ? c : -c;
      });
      rows.forEach(function (r) { table.tBodies[0].appendChild(r); });
    });
  });
});
"""


def cell(value, fmt="{}", css="", bar=None, sort=None):
    """A table cell that sorts by its raw value, or by sort when the text
    isn't the number to sort on. bar: 0..1 to draw behind."""
    text = html.escape(fmt.format(value)) if not isinstance(value, str) else html.escape(value)
    if sort is None:
        sort = value if not isinstance(value, str) else value.lower()
    cls = f' class="{css}"' if css else ""
    if bar is not None:
        width = max(0.0, min(1.0, bar)) * 100
        return (f'<td class="barcell {css}" data-sort="{sort}"><span class="b" style="width:{width:.0f}%"></span>'
                f'<span class="t">{text}</span></td>')
    return f'<td{cls} data-sort="{sort}">{text}</td>'


def table(headers, rows):
    head = "".join(f"<th>{html.escape(h)}</th>" for h in headers)
    body = "".join(f"<tr>{''.join(r)}</tr>" for r in rows)
    return f'<div class="scroll"><table class="sortable"><thead><tr>{head}</tr></thead><tbody>{body}</tbody></table></div>'


def counter_table(title_col, counter, total=None, limit=None):
    items = counter.most_common(limit)
    peak = items[0][1] if items else 1
    total = total or sum(counter.values()) or 1
    rows = [[cell(name), cell(count, bar=count / peak), cell(pct(count, total), "{:.0f}%")]
            for name, count in items]
    return table([title_col, "Count", "Share"], rows)


def render(batch_dir, runs, top):
    ov = overview(runs)
    enc = encounters(runs)
    dmg = damage_sources(runs)
    kills = killers(runs)
    places = death_places(runs)
    foes = enemies(runs)
    tiles_used = tiles(runs)
    claims, buys = acquisitions(runs)
    checks, errors = failures(runs)
    seeds = [r["seed"] for r in runs if r["seed"] is not None]
    policies = ", ".join(f"{p} ×{n}" for p, n in ov["policies"].items())

    parts = []
    out = parts.append
    out(f"<h1>AutoPilot balance report</h1>")
    out(f'<p class="note">{len(runs)} runs ({policies}), seeds {min(seeds) if seeds else "?"}–'
        f'{max(seeds) if seeds else "?"}. From <code>{html.escape(os.path.abspath(batch_dir))}</code>. '
        "Click a column to sort.</p>")

    outcome_text = ", ".join(f"{n} {k}" for k, n in ov["outcomes"].most_common())
    cards = [
        ("Runs", ov["runs"]),
        ("Won", ov["outcomes"].get("victory", 0)),
        ("Median turns", f'{ov["turns_median"]:g}'),
        ("Fights won / run", f'{ov["fights_won_mean"]:.1f}'),
        ("Furthest reached", f'sector {ov["furthest"][0] + 1}, tile {ov["furthest"][1]}'),
        ("Errors / violations", f'{ov["errors"]} / {ov["violations"]}'),
    ]
    out('<div class="cards">' + "".join(
        f'<div class="card"><div class="v">{html.escape(str(v))}</div><div class="k">{html.escape(k)}</div></div>'
        for k, v in cards) + "</div>")
    out(f'<p class="note">Outcomes: {html.escape(outcome_text)}'
        + (f'; {ov["no_result"]} crashed or hung' if ov["no_result"] else "") + ".</p>")

    groups = by_policy(runs)
    matrix = gauntlet(runs)
    if len(groups) > 1:
        out(render_policies(groups))
        if matrix:
            out(render_gauntlet_by_policy(groups))
        out(render_encounters_by_policy(groups))
    elif matrix:
        out(render_gauntlet(matrix))

    # Encounters
    out("<h2>Encounters</h2>")
    out('<p class="note">Each scenario visit. Died is the share of visits the run ended in; hull lost and '
        "turns are per fight. A random bot flees often, so compare encounters with each other rather "
        "than reading the rates as how players will do.</p>")
    rows = []
    worst = max((pct(r["died"], r["visits"]) for r in enc.values()), default=1) or 1
    for name, r in enc.items():
        died = pct(r["died"], r["visits"])
        rows.append([
            cell(name), cell(r["visits"]), cell(r["fights"]),
            cell(pct(r["won"], r["visits"]), "{:.0f}%"),
            cell(pct(r["fled"], r["visits"]), "{:.0f}%"),
            cell(died, "{:.0f}%", "bad" if died >= 25 else "", bar=died / worst),
            cell(mean(r["hull_lost"]), "{:.1f}"), cell(mean(r["turns"]), "{:.1f}"),
            cell(r["offers"]), cell(r["claimed"]), cell(r["bought"]),
        ])
    rows.sort(key=lambda row: -float(row[5].split('data-sort="')[1].split('"')[0]))
    out(table(["Scenario", "Visits", "Fights", "Won", "Fled", "Died", "Hull lost", "Turns",
               "Salvage offers", "Claimed", "Bought"], rows))

    # Deaths
    out("<h2>What kills runs</h2>")
    out('<p class="note">The last damage before the hull hit zero, and where the run ended.</p>')
    out(counter_table("Final blow", kills, limit=top))
    out("<h2>Where runs end</h2>")
    out(counter_table("Scenario", places, limit=top))
    out("<h2>Damage taken, by source</h2>")
    out('<p class="note">All damage dealt to the player, before shields, by ship and the action it was '
        "spending. Environment is hazards and the redline.</p>")
    out(counter_table("Source", dmg, limit=top))

    # Enemies
    out("<h2>Enemies</h2>")
    rows = []
    for name, r in foes.items():
        uses = sum(r["actions"].values())
        common = ", ".join(f"{a} ×{n}" for a, n in r["actions"].most_common(3))
        rows.append([
            cell(name), cell(r["runs"]), cell(r["destroyed"]), cell(r["escaped"]),
            cell(uses), cell(r["damage_to_player"]),
            cell(r["damage_to_player"] / uses if uses else 0.0, "{:.1f}"),
            cell(common or "–"),
        ])
    rows.sort(key=lambda row: -float(row[5].split('data-sort="')[1].split('"')[0]))
    out(table(["Enemy", "Runs met", "Destroyed", "Escaped", "Actions", "Damage to player",
               "Damage / action", "Most used"], rows))

    # Tiles
    out("<h2>Tiles</h2>")
    out('<p class="note">Per activation, from runs that activated the tile. Fights won is the mean over '
        "those runs, against the batch's mean of "
        f'{ov["fights_won_mean"]:.1f}: a hint at strength, but with a random bot owning a tile is mostly luck. '
        "Acquired counts salvage claims and shop buys.</p>")
    rows = []
    for name, r in tiles_used.items():
        acts = r["activations"]
        if not acts and not r["acquired"]:
            continue
        lift = mean(r["fights_won"]) - ov["fights_won_mean"] if r["fights_won"] else 0.0
        per = lambda key: r[key] / acts if acts else 0.0
        rows.append([
            cell(name), cell(r["runs"]), cell(r["acquired"]), cell(acts),
            cell(acts / r["runs"] if r["runs"] else 0.0, "{:.1f}"),
            cell(per("damage"), "{:.2f}"), cell(per("shields"), "{:.2f}"),
            cell(per("charge"), "{:.2f}"), cell(per("heal"), "{:.2f}"), cell(per("statuses"), "{:.2f}"),
            cell(mean(r["fights_won"]), "{:.1f}", "good" if lift > 0.5 else ("bad" if lift < -0.5 else "")),
        ])
    rows.sort(key=lambda row: -float(row[3].split('data-sort="')[1].split('"')[0]))
    out(table(["Tile", "Runs used", "Acquired", "Activations", "Per run", "Damage", "Shields",
               "Charge", "Heal", "Status stacks", "Fights won (runs using)"], rows))

    out("<h2>Picked up</h2>")
    out(table(["What", "Claimed from salvage", "Bought"],
              [[cell(name), cell(claims.get(name, 0)), cell(buys.get(name, 0))]
               for name in sorted(set(claims) | set(buys))]))

    if checks or errors:
        out("<h2>Errors and violations</h2>")
        out('<p class="note">tools/autoplay.sh lists seeds to replay for each.</p>')
        if checks:
            out(counter_table("Invariant", checks))
        if errors:
            out(counter_table("Error site", errors, limit=top))

    return ("<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">"
            "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
            f"<title>AutoPilot Report</title><style>{_CSS}</style></head><body><main>"
            + "".join(parts) + f"</main><script>{_JS}</script></body></html>")


def render_policies(groups):
    """One row per policy: how its runs went."""
    rows = []
    for name, group in groups.items():
        ov = overview(group)
        sectors = sum(1 for r in group if r["result"] and r["result"].get("sector", 0) > 0)
        rows.append([
            cell(name), cell(ov["runs"]), cell(ov["outcomes"].get("victory", 0)),
            cell(ov["turns_median"], "{:g}"), cell(ov["fights_won_mean"], "{:.1f}"),
            cell(pct(sectors, ov["runs"]), "{:.0f}%"),
            cell(f'sector {ov["furthest"][0] + 1}, tile {ov["furthest"][1]}'),
        ])
    return ("<h2>Policies</h2>"
            '<p class="note">The same seeds, played by each policy. Random is the floor; smart is a '
            "player who has learned the basics (AutoPilot step 5). Fights won counts every fight, "
            "including the one-hull Fate ships a random bot keeps jumping back into.</p>"
            + table(["Policy", "Runs", "Won", "Median turns", "Fights won / run",
                     "Got past sector 1", "Furthest"], rows))


def render_gauntlet_by_policy(groups):
    """A matrix per policy, then each policy's clear rate against random's."""
    parts = []
    matrices = {name: gauntlet(group) for name, group in groups.items()}
    for name, matrix in matrices.items():
        if matrix:
            parts.append(render_gauntlet(matrix, f"Gauntlet: {name}"))
    baseline = matrices.get("random")
    if not baseline:
        return "".join(parts)
    for name, matrix in matrices.items():
        if name == "random" or not matrix:
            continue
        rows = []
        for scenario, sector in matrix["scenarios"]:
            row = [cell(scenario if sector == 0 else f"{scenario} (sector {sector + 1})")]
            for loadout in matrix["loadouts"]:
                ours = matrix["cells"].get(((scenario, sector), loadout))
                theirs = baseline["cells"].get(((scenario, sector), loadout))
                if not ours or not theirs or not ours["runs"] or not theirs["runs"]:
                    row.append(cell("–"))
                    continue
                rate = pct(ours["outcomes"]["cleared"], ours["runs"])
                gap = rate - pct(theirs["outcomes"]["cleared"], theirs["runs"])
                # A fight nobody clears isn't rewarding skill: it's a wall.
                css = "good" if gap >= 30 else ("bad" if rate < 20 else "")
                row.append(cell(f"{gap:+.0f} pts ({rate:.0f}%)", css=css, sort=gap))
            rows.append(row)
        parts.append(f"<h2>Skill gap: {html.escape(name)} vs random</h2>"
                     '<p class="note">Points of clear rate the policy gains over random on the same '
                     "seeds, then its own rate. A wide gap means the fight rewards playing well; a "
                     "narrow one at a low rate means good play doesn't save it (red).</p>"
                     + table(["Scenario"] + matrix["loadouts"], rows))
    return "".join(parts)


def render_encounters_by_policy(groups):
    """Per scenario, each policy's death rate and hull lost per fight."""
    tables = {name: encounters(group) for name, group in groups.items()}
    scenarios = sorted({scenario for enc in tables.values() for scenario in enc})
    rows = []
    for scenario in scenarios:
        row = [cell(scenario)]
        for name in groups:
            r = tables[name].get(scenario)
            if not r or not r["visits"]:
                row.append(cell("–"))
                continue
            died = pct(r["died"], r["visits"])
            text = f'{died:.0f}% of {r["visits"]}'
            if r["hull_lost"]:
                text += f' · −{mean(r["hull_lost"]):.1f} hull'
            row.append(cell(text, css="bad" if died >= 25 else "", sort=died))
        rows.append(row)
    return ("<h2>Encounters by policy</h2>"
            '<p class="note">The share of visits each policy died in, then hull lost per fight.</p>'
            + table(["Scenario"] + list(groups), rows))


def render_gauntlet(matrix, title="Gauntlet"):
    """Scenario rows × loadout columns: the share of runs that cleared the
    fight, with hull lost (in the runs that cleared it) and turns."""
    loadouts = matrix["loadouts"]
    rows = []
    for scenario, sector in matrix["scenarios"]:
        row = [cell(scenario if sector == 0 else f"{scenario} (sector {sector + 1})")]
        for loadout in loadouts:
            c = matrix["cells"].get(((scenario, sector), loadout))
            if not c or not c["runs"]:
                row.append(cell("–"))
                continue
            rate = pct(c["outcomes"]["cleared"], c["runs"])
            other = c["runs"] - c["outcomes"]["cleared"] - c["outcomes"]["defeat"]
            text = f'{rate:.0f}% of {c["runs"]}'
            if c["hull_lost"]:
                text += f' · −{mean(c["hull_lost"]):.0f} hull'
            text += f' · {mean(c["turns"]):.1f}t'
            if other:
                text += f" · {other} other"
            css = "good" if rate >= 70 else ("bad" if rate < 30 else "")
            row.append(f'<td class="barcell {css}" data-sort="{rate}"><span class="b" style="width:{rate:.0f}%"></span>'
                       f'<span class="t">{html.escape(text)}</span></td>')
        rows.append(row)
    return (f"<h2>{html.escape(title)}</h2>"
            '<p class="note">Each cell: the share of runs that cleared the fight, then the hull those '
            "runs lost and the turns taken (t). Every cell plays the same seeds, so a column against "
            "another compares loadouts on the same draws. Other is anything but cleared or defeat "
            "(fled, passed, gave up). The bot holds its ground: it never jumps out of a fight.</p>"
            + table(["Scenario"] + loadouts, rows))


def headlines(runs, top):
    groups = by_policy(runs)
    if len(groups) > 1:
        lines = []
        for name, group in groups.items():
            lines.append(f"[{name}] " + _headlines_for(group, top))
        return "\n".join(lines)
    return _headlines_for(runs, top)


def _headlines_for(runs, top):
    ov = overview(runs)
    enc = encounters(runs)
    lines = [f"{ov['runs']} runs: " + ", ".join(f"{n} {k}" for k, n in ov["outcomes"].most_common())
             + f"; median {ov['turns_median']:g} turns, {ov['fights_won_mean']:.1f} fights won per run"]
    matrix = gauntlet(runs)
    if matrix:
        for scenario, sector in matrix["scenarios"]:
            rates = []
            for loadout in matrix["loadouts"]:
                c = matrix["cells"].get(((scenario, sector), loadout))
                if c and c["runs"]:
                    rates.append(f"{loadout} {pct(c['outcomes']['cleared'], c['runs']):.0f}%")
            lines.append(f"  {scenario}: " + ", ".join(rates))
    deadliest = sorted(((pct(r["died"], r["visits"]), name, r["visits"]) for name, r in enc.items()
                        if r["visits"] >= 5), reverse=True)[:top]
    if deadliest:
        lines.append("Deadliest encounters (died / visits, 5+ visits): "
                     + ", ".join(f"{name} {rate:.0f}% of {n}" for rate, name, n in deadliest))
    kills = killers(runs).most_common(top)
    if kills:
        lines.append("Top final blows: " + ", ".join(f"{name} ×{n}" for name, n in kills))
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("batch_dir")
    parser.add_argument("--top", type=int, default=12, help="rows in the ranked lists (default 12)")
    args = parser.parse_args()

    runs = load_runs(args.batch_dir)
    if not runs:
        sys.exit(f"no transcripts in {args.batch_dir}")
    report = os.path.join(args.batch_dir, "report.html")
    with open(report, "w", encoding="utf-8") as handle:
        handle.write(render(args.batch_dir, runs, args.top))
    print(headlines(runs, 3))
    print(f"report: {report}")


if __name__ == "__main__":
    main()
