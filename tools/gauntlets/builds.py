#!/usr/bin/env python3
"""Synergy builds for the Die Fighter, written out as AutoPilot gauntlets.

Each build is a theme (a payoff and what feeds it), in two stages of a run:

  core  what a player could have by mid-run (Sector 2): at most 9 tiles, all
        inside the starting middle 3x3 (columns 1-3), at most 1 rare, 3 dice.
  full  the build finished (Sector 3): at most 12 tiles, using the outer
        columns (Grid Slots), at most 2 rares, 4 dice. It keeps the core's
        tiles where they were, except the starters it names in "sells".

No upgrades (+ tiles): those need two copies of one tile. A full grid is 15
tiles, but a real run ends with about 10 (AutoPilot build batches), hence 12.

Grid cells are "x,y": x 0-4 left to right, y 0-2 top to bottom. Feeds run to
the next cell (right = x+1, down = y+1), and Feed across goes to the mirrored
column (x -> 4-x). A die fed into a tile that won't take it goes to the
targeted ship, so a Polarizer in front of a picky tile hands its rejects to
the enemy, usually as a harmless 1.

Run:  python3 tools/gauntlets/builds.py
It checks every build against Source/Content/Tiles/TileResources (the tile
exists, is offered as a reward, rarity budget, cells) and writes:
  tools/gauntlets/builds_core.json   core builds vs Sector 2 fights
  tools/gauntlets/builds_full.json   full builds vs Sector 3 fights
Then e.g.:  tools/autoplay.sh --gauntlet tools/gauntlets/builds_core.json --policy smart
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TILE_DIR = ROOT / "Source/Content/Tiles/TileResources"
OUT_DIR = Path(__file__).resolve().parent

CORE_MAX_TILES, FULL_MAX_TILES = 9, 12
CORE_MAX_RARES, FULL_MAX_RARES = 1, 2
CORE_DICE, FULL_DICE = 3, 4
RARE = 2
STARTERS = {"damage", "bump", "shield"}

SEEDS = 8

CORE_SCENARIOS = [
    "COMBAT_wolfpack",
    "COMBAT_carrier",
    "COMBAT_defender_disabler",
    "COMBAT_tender_escort",
    "COMBAT_smash_and_grab",
    "COMBAT_spotter",
    "ELITE_hunter_killers",
    "ELITE_lance_squadron",
    {"id": "GATE_sector_warden", "sector": 0},
    "GATE_arc_dynamo",
]
CORE_SECTOR = 1

FULL_SCENARIOS = [
    "COMBAT_wolfpack",
    "COMBAT_carrier",
    "COMBAT_drone_battery",
    "COMBAT_blockade_runner",
    "COMBAT_siege_battery",
    "ELITE_mortar_nest",
    "ELITE_tithe_fleet",
    "ELITE_hunter_killers",
    {"id": "GATE_arc_dynamo", "sector": 1},
    "GATE_bastion",
]
FULL_SECTOR = 2


BUILDS = {
    "goodstuff": {
        "name": "Goodstuff (control)",
        "notes": "No theme: solid commons and uncommons. The bar every themed build has to clear.",
        "core": {
            "1,0": "chain_cannon", "2,0": "twin_barrel", "3,0": "deflector_array",
            "1,1": "damage", "2,1": "bump", "3,1": "shield",
            "1,2": "reactive_armor", "2,2": "counterweight_battery", "3,2": "reroll",
        },
        "full": {"0,0": "overshield_relay", "0,1": "damage", "4,1": "pulse_repeater"},
    },
    "feed_line": {
        "name": "Feed Line",
        "notes": "Relays pass each die down a row and pay out at the end. Receiver Dish (8 when fed) "
                 "gets Booster Stage's +2; Relay Terminal scales with feeds; Crescendo counts every "
                 "activation.",
        "core": {
            "1,0": "surge_relay", "2,0": "booster_stage", "3,0": "receiver_dish",
            "1,1": "polarizer", "2,1": "toll_relay", "3,1": "relay_terminal",
            "1,2": "damage", "2,2": "bump", "3,2": "shield",
        },
        "full": {"0,0": "overshield_relay", "0,1": "signal_relay", "4,0": "crescendo_cannon"},
    },
    "firestarter": {
        "name": "Firestarter",
        "notes": "Napalm Vent in the centre burns the target whenever any of its 8 neighbours fires, "
                 "and Hex Coil adds 2 damage per status applied. Full adds Value Exchange to turn 1s "
                 "into 6s for Flashpoint and Status Catalyst.",
        "core": {
            "1,0": "incendiary_round", "2,0": "fuse_payload", "3,0": "hex_coil",
            "1,1": "damage", "2,1": "napalm_vent", "3,1": "heat_sink",
            "1,2": "bump", "2,2": "shield", "3,2": "dampener",
        },
        "full": {"0,0": "value_exchange", "4,0": "flashpoint", "4,1": "status_catalyst"},
    },
    "pinpoint": {
        "name": "Pinpoint",
        "notes": "Stacks Exposed (+stacks on each single-target hit) and cashes it with many small "
                 "hits: Chain Cannon hits twice, Ratchet and Overclock grow per use. Nudge Down and "
                 "Bump make 4s.",
        "core": {
            "1,0": "nudge_down", "2,0": "chain_cannon", "3,0": "ratchet_cannon",
            "1,1": "sensor_spike", "2,1": "damage", "3,1": "target_painter",
            "1,2": "bump", "2,2": "shield", "3,2": "spotter_drone",
        },
        "full": {"0,1": "hex_coil", "4,0": "deflector_array", "4,1": "overclock_coil"},
    },
    "bulwark": {
        "name": "Bulwark",
        "notes": "Shields persist, so stack them, then turn them into damage: Ballast Tanks feeds a "
                 "1 straight down into Discharge Plate (2x shields spent). Full adds Ram Plating "
                 "(damage = shields, no spend), Fortress Protocol and Shield Siphon.",
        "core": {
            "1,0": "overshield_relay", "2,0": "deflector_array", "3,0": "shield",
            "1,1": "ballast_tanks", "2,1": "damage", "3,1": "counterweight_battery",
            "1,2": "discharge_plate", "2,2": "reactive_armor", "3,2": "bump",
        },
        "full": {"0,1": "shield_siphon", "4,0": "fortress_protocol", "4,1": "ram_plating"},
    },
    "redline": {
        "name": "Redline",
        "notes": "Fill the drive, then hold it full: Preflight Interlock deals 3x die while fully "
                 "charged. Toll Relays feed into it and still pass the die once the drive is full. "
                 "Brownout Plating shields you while it's filling.",
        "core": {
            "1,0": "regenerative_brake", "2,0": "damage", "3,0": "deflector_array",
            "1,1": "toll_relay", "2,1": "toll_relay", "3,1": "preflight_interlock",
            "1,2": "bump", "2,2": "shield", "3,2": "brownout_plating",
        },
        # Ram Scoop at 4,1 with 4,0 and 4,2 left empty: 4 charge a die.
        "full": {"0,0": "governor_coil", "0,1": "toll_relay", "4,1": "ram_scoop"},
    },
    "capacitor_gun": {
        "name": "Capacitor Gun",
        "notes": "The opposite of Redline: bank charge and spend it every turn. Toll -> Afterburner "
                 "-> Arc Tap in one row; Deadweight Drive pays off the charge you just spent.",
        "core": {
            "1,0": "regenerative_brake", "2,0": "deadweight_drive", "3,0": "damage",
            "1,1": "toll_relay", "2,1": "afterburner_relay", "3,1": "arc_tap",
            "1,2": "governor_coil", "2,2": "shield", "3,2": "deflector_array",
        },
        # Ram Scoop at 4,1 with 4,0 and 4,2 left empty: 4 charge a die.
        "full": {"0,0": "sabotage_charge", "0,1": "toll_relay", "4,1": "ram_scoop"},
    },
    "phantom_fleet": {
        "name": "Phantom Fleet",
        "notes": "More dice: holograms from Pilot Light, Holo-Duplicator, Die Splitter (and "
                 "Fabricator, Phantom Squadron). Pays off with Swarm Battery, Broadside and "
                 "Overclock Coil. Pilot Light's 1 feeds Chaff Pod.",
        "core": {
            "1,0": "pilot_light", "2,0": "chaff_pod", "3,0": "swarm_battery",
            "1,1": "holographic_duplicator", "2,1": "broadside", "3,1": "damage",
            "1,2": "die_splitter", "2,2": "bump", "3,2": "shield",
        },
        "full": {"0,1": "fabricator", "4,0": "phantom_squadron", "4,1": "overclock_coil"},
    },
    "snake_eyes": {
        "name": "Snake Eyes",
        "notes": "Twin-dice payouts. Inverter feeds Lucky Seven (a die and its flip always sum to "
                 "7); Pair Lock wants matches, which Bump, Nudge Down and Re-Roll help make. Full "
                 "sells the Dice Cannon for Welder -> Ablative Charge (welded 6s).",
        "core": {
            "1,0": "bump", "2,0": "pair_lock", "3,0": "reroll",
            "1,1": "inverter", "2,1": "lucky_seven", "3,1": "damage",
            "1,2": "nudge_down", "2,2": "twin_barrel", "3,2": "shield",
        },
        "full": {"3,1": "welder", "4,1": "ablative_charge", "4,0": "holding_bay", "4,2": "deflector_array"},
        "sells": ["3,1"],
    },
    "clockwork": {
        "name": "Clockwork",
        "notes": "Countdowns, wound by Fuse Cutter (counts every other countdown down by the die). "
                 "Echo Relay feeds it so it fires twice. Doubler feeds Countdown Cannon.",
        "core": {
            "1,0": "doubler", "2,0": "countdown_cannon", "3,0": "pulse_repeater",
            "1,1": "echo_relay", "2,1": "fuse_cutter", "3,1": "capacitor_bank",
            "1,2": "damage", "2,2": "fuse_payload", "3,2": "shield",
        },
        "full": {"0,1": "bump", "4,0": "fabricator", "4,1": "time_bomb"},
    },
    "static_field": {
        "name": "Static Field",
        "notes": "Control the enemy's dice and intents. Scrambled flips dice they're handed, so "
                 "Turncoat Cannon (10 vs Scrambled) can hand over 6s; Grounding Rod hands them "
                 "1s; Weakened, Jammed, Cryo Lance and Counter-Battery blunt what's left.",
        "core": {
            "1,0": "crossed_wires", "2,0": "dampener", "3,0": "chaff_pod",
            "1,1": "polarizer", "2,1": "turncoat_cannon", "3,1": "cryo_lance",
            "1,2": "grounding_rod", "2,2": "shield", "3,2": "reactive_armor",
        },
        "full": {"0,0": "static_bloom", "0,1": "interdiction_net", "4,1": "counter_battery"},
    },
    "boxcars": {
        "name": "Boxcars",
        "notes": "High faces and area damage. Bumps and Value Exchange push dice to 5-6 for "
                 "Sweeping Battery (all enemies) and Grudge Cannon; Flak Cannon in the centre "
                 "counts its 8 neighbours. Full adds Chaos Explosion.",
        "core": {
            "1,0": "bump", "2,0": "sweeping_battery", "3,0": "grudge_cannon",
            "1,1": "value_exchange", "2,1": "flak_cannon", "3,1": "bump",
            "1,2": "nudge_down", "2,2": "damage", "3,2": "shield",
        },
        "full": {"0,1": "reroll", "4,1": "chaos_explosion", "4,2": "deflector_array"},
    },
    "gun_deck": {
        "name": "Gun Deck",
        "notes": "Two columns of guns around Amplifiers (+2 to the tiles above and below), with "
                 "Reloader in the middle giving every limited tile around it another use. Full "
                 "adds War Footing and a Booster Stage feeding the left column.",
        "core": {
            "1,0": "chain_cannon", "2,0": "bump", "3,0": "twin_barrel",
            "1,1": "amplifier", "2,1": "reloader", "3,1": "amplifier",
            "1,2": "damage", "2,2": "shield", "3,2": "chain_cannon",
        },
        "full": {"0,0": "booster_stage", "0,1": "war_footing", "4,1": "reactive_armor"},
    },
    "blood_pact": {
        "name": "Blood Pact",
        "notes": "Hurt yourself for power, then pass the bill on. Blowtorch's self-Burn moves to "
                 "the enemy with Countermeasures, where Heat Sink (and Flashpoint) feed on it; "
                 "Leeching Shot and Blood Valve trade hull. Cinder Turbine charges off your Burn.",
        "core": {
            "1,0": "leeching_shot", "2,0": "damage", "3,0": "blood_valve",
            "1,1": "blowtorch", "2,1": "countermeasures", "3,1": "heat_sink",
            "1,2": "bump", "2,2": "shield", "3,2": "reactive_armor",
        },
        "full": {"0,0": "cinder_turbine", "4,1": "flashpoint", "4,2": "regenerative_brake"},
    },
}


def read_tiles() -> dict:
    """Tile id -> (rarity, offered_as_reward), from the .tres files."""
    tiles = {}
    for path in TILE_DIR.glob("*.tres"):
        text = path.read_text()
        rarity = re.search(r"^rarity = (\d+)", text, re.M)
        offered = re.search(r"^offered_as_reward = (\w+)", text, re.M)
        tiles[path.stem] = (int(rarity.group(1)) if rarity else 0,
                            offered.group(1) != "false" if offered else True)
    return tiles


def cell(text: str) -> tuple:
    x, y = (int(v) for v in text.split(","))
    return x, y


def full_tiles(build: dict) -> dict:
    tiles = dict(build["core"])
    tiles.update(build["full"])
    return tiles


def check(key: str, build: dict, tiles: dict) -> list:
    problems = []
    core, full = build["core"], full_tiles(build)
    for pos, tile in full.items():
        x, y = cell(pos)
        if not (0 <= x <= 4 and 0 <= y <= 2):
            problems.append(f"{pos} is off the 5x3 grid")
        if tile not in tiles:
            problems.append(f"no tile '{tile}'")
        elif not tiles[tile][1]:
            problems.append(f"'{tile}' isn't offered as a reward")
    for pos in core:
        if not 1 <= cell(pos)[0] <= 3:
            problems.append(f"core tile at {pos} is outside the starting 3x3")
    for pos in build.get("sells", []):
        if core.get(pos) not in STARTERS:
            problems.append(f"sells {pos}, which isn't a starter tile")
    for pos in build["full"]:
        if pos in core and pos not in build.get("sells", []):
            problems.append(f"full replaces core tile at {pos} without listing it in sells")

    def rares(layout: dict) -> int:
        return sum(1 for t in layout.values() if tiles.get(t, (0, True))[0] == RARE)

    if len(core) > CORE_MAX_TILES:
        problems.append(f"core has {len(core)} tiles (max {CORE_MAX_TILES})")
    if len(full) > FULL_MAX_TILES:
        problems.append(f"full has {len(full)} tiles (max {FULL_MAX_TILES})")
    if rares(core) > CORE_MAX_RARES:
        problems.append(f"core has {rares(core)} rares (max {CORE_MAX_RARES})")
    if rares(full) > FULL_MAX_RARES:
        problems.append(f"full has {rares(full)} rares (max {FULL_MAX_RARES})")
    return [f"{key}: {p}" for p in problems]


def spec(description: str, sector: int, scenarios: list, loadouts: dict) -> dict:
    return {"description": description, "seeds": SEEDS, "sector": sector,
            "scenarios": scenarios, "loadouts": loadouts}


def main() -> int:
    tiles = read_tiles()
    problems = [p for key, build in BUILDS.items() for p in check(key, build, tiles)]
    if problems:
        print("\n".join(problems), file=sys.stderr)
        return 1

    core_loadouts, full_loadouts = {}, {}
    for key, build in BUILDS.items():
        core_loadouts[key] = {"name": build["name"], "notes": build["notes"],
                              "tiles": build["core"], "dice": CORE_DICE}
        full_loadouts[key] = {"name": build["name"], "notes": build["notes"],
                              "tiles": full_tiles(build), "dice": FULL_DICE}

    header = "Generated by tools/gauntlets/builds.py; edit the builds there, not here. "
    outputs = {
        "builds_core.json": spec(header + "Synergy builds at mid-run (9 tiles in the starting 3x3, "
                                 "3 dice) against Sector 2.", CORE_SECTOR, CORE_SCENARIOS, core_loadouts),
        "builds_full.json": spec(header + "Synergy builds finished (12 tiles, 4 dice) against "
                                 "Sector 3.", FULL_SECTOR, FULL_SCENARIOS, full_loadouts),
    }
    for name, data in outputs.items():
        (OUT_DIR / name).write_text(json.dumps(data, indent=2) + "\n")
        cells = len(data["scenarios"]) * len(data["loadouts"])
        print(f"wrote tools/gauntlets/{name}: {len(data['loadouts'])} builds x "
              f"{len(data['scenarios'])} scenarios x {SEEDS} seeds = {cells * SEEDS} runs per policy")
    return 0


if __name__ == "__main__":
    sys.exit(main())
