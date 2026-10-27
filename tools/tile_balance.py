#!/usr/bin/env python3
"""How good each tile is, from a batch of AutoPilot transcripts.

Meant for a "smart-randpick" batch (tools/autoplay.sh --policy smart-randpick):
the bot fights as well as "smart" does but takes salvage and shop stock at
random, so whether a tile was taken is a coin flip, not a sign the run was
already going well. That makes "took it" against "passed on it", at the same
offer, a fair test of the tile.

Progress is how far a run got: the furthest map stop it reached, counted
across sectors (STOPS_PER_SECTOR each, the boss last), and a full clear on
top. A win is a run that beat the final boss. Wins are rare while the bot
dies at a boss wall, so the yes/no measure is the next boss: whether a run
offered a tile in sector N went on to beat sector N's boss.

For each tile it reports:
  offer-relative  every first time a run was offered the tile and could have
                  taken it (room on the grid, credits for it): the progress
                  made from that stop on, and the share that beat the next
                  boss, of runs that took it minus runs that passed. Positive
                  means the tile helps.
  naive           win rate and progress of runs whose final build had it, the
                  way a casual tally would read it; biased toward tiles that
                  show up late, side by side so the bias shows.
  usage           how often it fires per player turn it's on the grid, what it
                  makes per activation, and how often it sat there unused.

Stalled, looping and turn-limit runs are game or bot bugs, not results; they
are left out and counted.

Usage:
  tools/tile_balance.py BATCH_DIR [--json OUT.json] [--csv OUT.csv]
"""

import argparse
import csv
import glob
import json
import math
import os
import re
import sys
from collections import defaultdict

STOPS_PER_SECTOR = 14
SECTORS = 3
WIN_STOPS = SECTORS * STOPS_PER_SECTOR
FINISHED = {"victory", "defeat"}
STARTER = {"Dice Cannon", "Bump", "Shield Burst"}
TILE_DIR = os.path.join(os.path.dirname(__file__), "..", "Source", "Content", "Tiles", "TileResources")
RARITY = ["common", "uncommon", "rare"]
# ActivationResource.ActivationType.CANT_BE_ACTIVATED_WITH_DIE: a passive tile.
REFUSES_DICE = 6
OUTPUTS = ("damage", "shields", "heal", "charge", "statuses")
BBCODE = re.compile(r"\[/?[a-z]+(=[^\]]*)?\]")


def plain(label):
    """A tile's name from a snapshot label: "[color=red]Dice Cannon[/color] (-1)"."""
    return re.sub(r" \(-?\d+\)$", "", BBCODE.sub("", label)).strip()


def stops(sector, map_index):
    return sector * STOPS_PER_SECTOR + map_index


def tile_catalog():
    """Name → {rarity, uses, description, file}, read off the tile resources."""
    catalog = {}
    for path in glob.glob(os.path.join(TILE_DIR, "*.tres")):
        text = open(path, encoding="utf-8").read()
        name = re.search(r'^tile_name = "(.*)"$', text, re.M)
        if not name:
            continue
        rarity = re.search(r"^rarity = (\d)", text, re.M)
        uses = re.search(r"^uses_per_turn = (-?\d+)", text, re.M)
        desc = re.search(r'^description = "(.*)"$', text, re.M)
        checks = re.search(r"^activation_checks = .*$", text, re.M)
        blocks = dict(re.findall(r'\[sub_resource [^\]]*id="([^"]+)"\]\n(.*?)(?=\n\[|\Z)', text, re.S))
        passive = bool(checks) and any(
            re.search(r"^type = %d$" % REFUSES_DICE, blocks.get(ref, ""), re.M)
            for ref in re.findall(r'SubResource\("([^"]+)"\)', checks.group(0)))
        catalog[plain(name.group(1))] = {
            "rarity": RARITY[int(rarity.group(1))] if rarity else "common",
            "uses": int(uses.group(1)) if uses else -1,
            "description": BBCODE.sub("", desc.group(1)) if desc else "",
            "file": os.path.basename(path),
            "passive": passive,
        }
    return catalog


def read_run(path):
    """One transcript, boiled down; None if it didn't finish."""
    entries = []
    for line in open(path, encoding="utf-8"):
        try:
            entries.append(json.loads(line))
        except json.JSONDecodeError:
            pass  # a run killed mid-write (a hang) leaves half a line
    if not entries:
        return {"outcome": "no_result"}
    result = next((e for e in entries if e.get("type") == "result"), None)
    if result is None:
        return {"outcome": "no_result"}
    run = {"outcome": result["outcome"], "seed": entries[0].get("seed"),
           "final_build": result.get("build", []), "tiles": result.get("tiles", {}),
           "killed_by": result.get("killed_by", "")}
    if run["outcome"] not in FINISHED:
        return run

    sector, best = 0, 0
    owned_turns = defaultdict(int)
    ever_owned = set(STARTER)
    offers = []  # {source, items: [(name, takeable)], at_stops, taken: set}
    open_offers = []
    for e in entries:
        kind = e.get("type")
        if kind == "arrive":
            sector = e.get("sector", sector)
            best = max(best, stops(sector, e["map_index"]))
            ever_owned.update(e.get("build", []))
            open_offers = []
        elif kind == "turn":
            sector = e.get("sector", sector)
            best = max(best, stops(sector, e["map_index"]))
            for label in e.get("tiles", {}).values():
                owned_turns[plain(label)] += 1
        elif kind == "offer":
            room = e.get("room", True)
            if e["source"] == "shop":
                money = e.get("money", 0)
                items = [(i["item"], room and 0 <= i["price"] <= money) for i in e["items"]]
            else:
                items = [(i, room) for i in e["items"]]
            offer = {"source": e["source"], "items": items, "at_stops": best, "sector": sector,
                     "taken": set()}
            offers.append(offer)
            open_offers.append(offer)
        elif kind == "move" and e.get("move") in ("claim", "buy"):
            source = "salvage" if e["move"] == "claim" else "shop"
            ever_owned.add(e["item"])
            for offer in open_offers:
                names = [n for n, _ in offer["items"]]
                if offer["source"] == source and e["item"] in names and e["item"] not in offer["taken"]:
                    offer["taken"].add(e["item"])
                    break
    ever_owned.update(run["final_build"])
    run.update({
        "won": run["outcome"] == "victory",
        "stops": WIN_STOPS if run["outcome"] == "victory" else best,
        "sector": result.get("sector", sector),
        "owned_turns": dict(owned_turns),
        "ever_owned": ever_owned,
        "offers": offers,
    })
    return run


def mean(xs):
    return sum(xs) / len(xs) if xs else float("nan")


def diff_with_se(a, b):
    """Mean of a minus mean of b, and the standard error of that."""
    if len(a) < 2 or len(b) < 2:
        return float("nan"), float("nan")
    def var(xs):
        m = mean(xs)
        return sum((x - m) ** 2 for x in xs) / (len(xs) - 1)
    return mean(a) - mean(b), math.sqrt(var(a) / len(a) + var(b) / len(b))


def analyse(runs, catalog):
    done = [r for r in runs if r["outcome"] in FINISHED]
    base_stops = mean([r["stops"] for r in done])
    base_win = mean([r["won"] for r in done])
    per = defaultdict(lambda: {
        "took_gain": [], "passed_gain": [], "took_boss": [], "passed_boss": [],
        "offered": 0, "taken": 0, "offered_salvage": 0, "offered_shop": 0,
        "final_runs": [], "owned_runs": [],
        "activations": 0, "owned_turns": 0, "idle_runs": 0, "owned_3plus": 0,
        "damage": 0, "shields": 0, "heal": 0, "charge": 0, "statuses": 0,
    })
    for r in done:
        seen = set()
        for offer in r["offers"]:
            for name, takeable in offer["items"]:
                if name == "die" or name.endswith(" credits"):
                    continue
                t = per[name]
                t["offered"] += 1
                t["offered_" + offer["source"]] += 1
                took = name in offer["taken"]
                t["taken"] += took
                # The first chance only: a run offered a tile again is one
                # that lasted, which would tilt the passes toward long runs.
                if not takeable or name in seen:
                    continue
                seen.add(name)
                gain = r["stops"] - offer["at_stops"]
                t["took_gain" if took else "passed_gain"].append(gain)
                beat_boss = r["won"] or r["sector"] > offer["sector"]
                t["took_boss" if took else "passed_boss"].append(float(beat_boss))
        for name in r["final_build"]:
            per[name]["final_runs"].append(r)
        for name in r["ever_owned"]:
            per[name]["owned_runs"].append(r)
        for name, turns in r["owned_turns"].items():
            t = per[name]
            stats = r["tiles"].get(name, {})
            t["owned_turns"] += turns
            t["activations"] += stats.get("activations", 0)
            for key in OUTPUTS:
                t[key] += stats.get(key, 0)
            # Passive tiles never activate; what they make is the tell.
            if turns >= 3:
                t["owned_3plus"] += 1
                t["idle_runs"] += not any(stats.get(k, 0) for k in ("activations",) + OUTPUTS)

    rows = []
    for name, t in per.items():
        if name not in catalog and name not in STARTER:
            continue
        d_gain, se_gain = diff_with_se(t["took_gain"], t["passed_gain"])
        d_boss, se_boss = diff_with_se(t["took_boss"], t["passed_boss"])
        acts = t["activations"]
        info = catalog.get(name, {})
        rows.append({
            "tile": name,
            "rarity": info.get("rarity", "starter"),
            "uses_per_turn": info.get("uses", -1),
            "passive": info.get("passive", False),
            "description": info.get("description", ""),
            "starter": name in STARTER,
            "offered": t["offered"],
            "offered_salvage": t["offered_salvage"],
            "offered_shop": t["offered_shop"],
            "take_rate": t["taken"] / t["offered"] if t["offered"] else None,
            "n_took": len(t["took_gain"]),
            "n_passed": len(t["passed_gain"]),
            "delta_stops": d_gain, "delta_stops_se": se_gain,
            "delta_boss": d_boss, "delta_boss_se": se_boss,
            "took_boss": mean(t["took_boss"]), "passed_boss": mean(t["passed_boss"]),
            "n_final": len(t["final_runs"]),
            "final_win": mean([r["won"] for r in t["final_runs"]]),
            "final_past_s1": mean([r["sector"] >= 1 for r in t["final_runs"]]),
            "final_stops": mean([r["stops"] for r in t["final_runs"]]),
            "n_owned": len(t["owned_runs"]),
            "owned_win": mean([r["won"] for r in t["owned_runs"]]),
            "owned_past_s1": mean([r["sector"] >= 1 for r in t["owned_runs"]]),
            "owned_stops": mean([r["stops"] for r in t["owned_runs"]]),
            "owned_turns": t["owned_turns"],
            "activations_per_turn": acts / t["owned_turns"] if t["owned_turns"] else None,
            "idle_share": t["idle_runs"] / t["owned_3plus"] if t["owned_3plus"] else None,
            "per_activation": {k: (t[k] / acts if acts else 0.0) for k in OUTPUTS},
            "per_turn": {k: (t[k] / t["owned_turns"] if t["owned_turns"] else 0.0) for k in OUTPUTS},
        })
    rows.sort(key=lambda row: -999 if math.isnan(row["delta_stops"]) else -row["delta_stops"])
    return {"runs": len(runs), "finished": len(done), "base_stops": base_stops, "base_win": base_win,
            "sector_reached": _hist([r["sector"] for r in done]),
            "base_past_s1": mean([r["sector"] >= 1 for r in done]),
            "excluded": {o: sum(1 for r in runs if r["outcome"] == o)
                         for o in {r["outcome"] for r in runs} - FINISHED},
            "stops_hist": _hist([r["stops"] for r in done]),
            "tiles": rows}


def _hist(values):
    counts = defaultdict(int)
    for v in values:
        counts[v] += 1
    return dict(sorted(counts.items()))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("batch")
    parser.add_argument("--json")
    parser.add_argument("--csv")
    args = parser.parse_args()
    paths = sorted(glob.glob(os.path.join(args.batch, "*.jsonl")))
    if not paths:
        sys.exit("no transcripts in " + args.batch)
    report = analyse([read_run(p) for p in paths], tile_catalog())
    if args.json:
        with open(args.json, "w", encoding="utf-8") as out:
            json.dump(report, out, indent=1, default=lambda x: None)
    if args.csv:
        with open(args.csv, "w", newline="", encoding="utf-8") as out:
            fields = [k for k in report["tiles"][0] if k not in ("per_activation", "per_turn", "description")]
            writer = csv.DictWriter(out, fieldnames=fields, extrasaction="ignore")
            writer.writeheader()
            writer.writerows(report["tiles"])

    print("%d runs, %d finished (excluded: %s); mean progress %.1f stops of %d, win rate %.1f%%"
          % (report["runs"], report["finished"], report["excluded"] or "none",
             report["base_stops"], WIN_STOPS, 100 * report["base_win"]))
    print("%-24s %-8s %5s %5s %5s  %13s  %12s  %9s %7s %6s" % (
        "tile", "rarity", "offer", "took", "pass", "Δstops±se", "Δboss%±se", "final stp", "act/t", "idle"))
    for row in report["tiles"]:
        def fmt(v, se, scale=1.0):
            return "   n/a" if math.isnan(v) else "%+5.1f ±%4.1f" % (v * scale, se * scale)
        print("%-24s %-8s %5d %5d %5d  %13s  %12s  %4d %4.1f %7s %6s" % (
            row["tile"][:24], row["rarity"], row["offered"], row["n_took"], row["n_passed"],
            fmt(row["delta_stops"], row["delta_stops_se"]), fmt(row["delta_boss"], row["delta_boss_se"], 100),
            row["n_final"], row["final_stops"] if row["n_final"] else 0,
            "%.2f" % row["activations_per_turn"] if row["activations_per_turn"] is not None else "-",
            "%.0f%%" % (100 * row["idle_share"]) if row["idle_share"] is not None else "-"))


if __name__ == "__main__":
    main()
