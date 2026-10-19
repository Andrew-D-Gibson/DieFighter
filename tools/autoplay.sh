#!/usr/bin/env bash
# Runs the AutoPilot (Source/Systems/Autoloads/auto_pilot.gd): the game playing
# itself for QA and balance testing.
#
# Headless runs are fast-forwarded with --fixed-fps: every frame simulates
# 1/60 s however quickly the machine renders it, so animations and awaits all
# still happen, in order, just compressed. --watch plays one run in a window
# at normal speed instead, to see what a transcript describes.
#
# Usage:
#   tools/autoplay.sh [--seed N] [--runs N] [--jobs N] [--policy NAMES]
#                     [--out DIR] [--time-limit S] [--watch] [--determinism]
#                     [--gauntlet SPEC] [-- extra args]
#   tools/autoplay.sh --replay TRANSCRIPT|BATCH_DIR [--runs N] [--real-time]
#                     [--stop-at-turn N] [--out DIR] [-- extra args]
#
#   --seed N         first seed (default: random); runs use N, N+1, ...
#   --runs N         how many runs (default 1)
#   --jobs N         how many at once (default: CPU count)
#   --policy NAMES   AutoPilot policy (default random): random, smart,
#                    aggressive, turtle or synergy. A comma-separated list
#                    plays every seed (and gauntlet cell) with each, and the
#                    report sets them side by side: the gap between random
#                    and smart is what says which fights reward good play.
#                    --watch and --determinism take the first.
#   --out DIR        output directory (default .autoplay/<timestamp>)
#   --time-limit S   kill a run after S seconds of wall time (default 300;
#                    a run takes seconds, so this only catches a hang)
#   --watch          one run, windowed, real time
#   --determinism    play --seed twice and check both transcripts match
#                    (with --gauntlet, the spec's first scenario × loadout)
#   --gauntlet SPEC  play every scenario × loadout in the spec file (JSON,
#                    see Source/Systems/AutoPilot/auto_pilot_gauntlet.gd and
#                    tools/gauntlets/) on the same seeds: --seed (default 1)
#                    and the spec's "seeds" count, or --runs. Needs python3.
#   -- ...           anything after this goes to the AutoPilot as-is
#                    (e.g. -- --max-turns=100)
#
# Replays (--replay) play a run again in a window, taking screenshots: the
# board before the first move of every turn and arrival, every error and
# broken invariant, and the end. Given a batch directory, it replays the runs
# that batch flagged, worst first (--runs, default 3). Each replay goes in
# <out>/<run>/ (out defaults to replays/ beside the transcript), with
# shots/index.html showing each screenshot beside what happened, and is
# checked against the original transcript: REPRODUCED or DIVERGED.
#   --real-time      play at normal speed (default: as fast as it draws)
#   --stop-at-turn N stop as player turn N starts and leave the game open to
#                    look around or play on by hand; close the window to
#                    finish
#
# Each run writes to the output directory:
#   seed_<N>_<policy>.jsonl      the transcript: turns, moves, errors,
#                                (a gauntlet run adds __<scenario>__<loadout>)
#                                invariant violations, the result
#   seed_<N>_<policy>.debug.txt  the engine's play-by-play (DebugLogger)
#   seed_<N>_<policy>.log        the engine's console output
#
# A batch also writes report.html (tools/autoplay_report.py): how runs ended,
# which encounters kill, and what each enemy and tile did.
#
# A run fails if it stalled, looped, hung, crashed, hit an engine or script
# error, or broke an invariant. A batch ends with a summary grouping the
# failures, with example seeds to replay; runs whose node count kept growing
# are listed too, as a warning. Exit status is non-zero if any run failed.

set -uo pipefail

GODOT="${GODOT:-/Users/drew/Documents/Godot/Godot_4.7_stable.app/Contents/MacOS/Godot}"
PROJECT="$(cd "$(dirname "$0")/.." && pwd)"

seed=""
runs=1
jobs="$(sysctl -n hw.ncpu 2>/dev/null || nproc)"
policies="random"
out=""
time_limit=300
watch=0
determinism=0
gauntlet=""
replay=""
real_time=0
stop_at_turn=0
runs_given=0
extra=()

while [[ $# -gt 0 ]]; do
	case "$1" in
		--seed) seed="$2"; shift 2 ;;
		--runs) runs="$2"; runs_given=1; shift 2 ;;
		--jobs) jobs="$2"; shift 2 ;;
		--policy) policies="$2"; shift 2 ;;
		--out) out="$2"; shift 2 ;;
		--time-limit) time_limit="$2"; shift 2 ;;
		--watch) watch=1; shift ;;
		--determinism) determinism=1; shift ;;
		--gauntlet) gauntlet="$2"; shift 2 ;;
		--replay) replay="$2"; shift 2 ;;
		--real-time) real_time=1; shift ;;
		--stop-at-turn) stop_at_turn="$2"; shift 2 ;;
		--) shift; extra=("$@"); break ;;
		*) echo "unknown option: $1" >&2; exit 2 ;;
	esac
done

# One replay: replay_one <transcript> <out dir>. Prints how it went; fails if
# the replay didn't play the same run.
replay_one() {
	local transcript="$1" dir="$2/$(basename "$1" .jsonl)"
	local run_args=()
	run_args=($(python3 "$PROJECT/tools/autoplay_replay.py" args "$transcript")) || return 1
	mkdir -p "$dir"
	local godot_args=(--fixed-fps 60 --path "$PROJECT")
	(( real_time )) || godot_args+=(--disable-vsync)
	local pilot_args=(--autoplay "${run_args[@]}" --out="$dir" --screenshots="$dir/shots")
	if (( stop_at_turn > 0 )); then
		pilot_args+=(--stop-at-turn="$stop_at_turn")
	else
		pilot_args+=(--no-mcp)
	fi
	echo "replaying $(basename "$transcript") ..."
	"$GODOT" "${godot_args[@]}" -- "${pilot_args[@]}" "${extra[@]+"${extra[@]}"}" \
		> "$dir/replay.log" 2>&1
	local replayed
	replayed=$(ls "$dir"/seed_*.jsonl 2>/dev/null | head -1)
	if [[ -z "$replayed" ]]; then
		echo "  FAILED: no transcript; see $dir/replay.log"
		return 1
	fi
	local verdict status=0
	verdict=$(python3 "$PROJECT/tools/autoplay_replay.py" compare "$transcript" "$replayed") || status=1
	sed 's/^/  /' <<< "$verdict"
	echo "  $(ls "$dir"/shots/*.png 2>/dev/null | wc -l | tr -d ' ') screenshots:" \
		"$(python3 "$PROJECT/tools/autoplay_replay.py" gallery "$dir/shots" "$replayed")"
	return $status
}

if [[ -n "$replay" ]]; then
	command -v python3 > /dev/null || { echo "--replay needs python3" >&2; exit 2; }
	if [[ -d "$replay" ]]; then
		(( runs_given )) || runs=3
		targets=$(python3 "$PROJECT/tools/autoplay_replay.py" flagged "$replay" --limit "$runs")
		[[ -n "$targets" ]] || { echo "nothing flagged in $replay"; exit 0; }
		[[ -z "$out" ]] && out="$replay/replays"
	elif [[ -f "$replay" ]]; then
		targets="$replay"
		[[ -z "$out" ]] && out="$(dirname "$replay")/replays"
	else
		echo "no transcript or batch at $replay" >&2; exit 2
	fi
	mkdir -p "$out"
	failed=0
	while read -r target; do
		replay_one "$target" "$out" || failed=1
	done <<< "$targets"
	exit $failed
fi

if [[ -n "$gauntlet" ]]; then
	[[ -f "$gauntlet" ]] || { echo "no gauntlet spec at $gauntlet" >&2; exit 2; }
	command -v python3 > /dev/null || { echo "--gauntlet needs python3" >&2; exit 2; }
	# Godot runs from elsewhere, so it gets the absolute path.
	gauntlet="$(cd "$(dirname "$gauntlet")" && pwd)/$(basename "$gauntlet")"
	# The same seeds for every cell, so loadouts face the same draws.
	[[ -z "$seed" ]] && seed=1
fi
[[ -z "$seed" ]] && seed=$(( RANDOM * 32768 + RANDOM ))
if [[ -z "$out" ]]; then
	out="$PROJECT/.autoplay/$(date +%Y%m%d-%H%M%S)"
	# Keep Godot's importer out of the run output.
	mkdir -p "$PROJECT/.autoplay" && touch "$PROJECT/.autoplay/.gdignore"
fi
mkdir -p "$out"

# A field of a one-line JSON object: json_field <line> <name>.
json_field() {
	sed -nE "s/.*\"$2\":(\"([^\"]*)\"|([0-9-]+)).*/\2\3/p" <<< "$1"
}
export -f json_field

# One run: play_one <seed> <dir> <policy> [<scenario> <loadout>]. The last two
# make it a gauntlet run. Prints a one-line summary; fails if the run did.
play_one() {
	local run_seed="$1" dir="$2" policy="$3" scenario="${4:-}" loadout="${5:-}"
	local name="seed_${run_seed}_${policy}"
	local args=(--path "$PROJECT")
	# Arrays don't survive export into xargs' shells, so extras travel joined.
	local extra_args=()
	[[ -n "${extra_joined:-}" ]] && read -ra extra_args <<< "$extra_joined"
	if [[ -n "$scenario" ]]; then
		name="${name}__${scenario}__${loadout}"
		extra_args+=(--gauntlet="$gauntlet" --scenario="$scenario" --loadout="$loadout")
	fi
	if [[ $watch -eq 0 ]]; then
		args=(--headless --fixed-fps 60 "${args[@]}")
	fi
	"$GODOT" "${args[@]}" -- --autoplay --seed="$run_seed" --policy="$policy" \
		--out="$dir" "${extra_args[@]+"${extra_args[@]}"}" > "$dir/$name.log" 2>&1 &
	local pid=$!
	# A script stuck inside one frame can't stop itself, so this does.
	(
		for (( t = 0; t < time_limit; t++ )); do
			sleep 1
			kill -0 "$pid" 2>/dev/null || exit 0
		done
		kill -9 "$pid" 2>/dev/null
	) &
	local watchdog=$!
	wait "$pid"
	local code=$?
	kill "$watchdog" 2>/dev/null
	wait "$watchdog" 2>/dev/null

	local result outcome turns errors violations
	result=$(grep '"type":"result"' "$dir/$name.jsonl" 2>/dev/null | tail -1)
	if [[ -z "$result" ]]; then
		local why="crashed (exit $code)"
		[[ $code -eq 137 ]] && why="hung, killed after ${time_limit}s"
		echo "seed $run_seed: FAILED, $why, no result; see $name.log"
		return 1
	fi
	outcome=$(json_field "$result" outcome)
	turns=$(json_field "$result" turns)
	errors=$(json_field "$result" errors)
	violations=$(json_field "$result" violations)
	local who=""
	[[ "$policies" == *,* ]] && who=" $policy"
	local line="seed $run_seed$who${scenario:+ $scenario × $loadout}: $outcome after $turns turns, $errors errors, $violations violations"
	if [[ $code -ne 0 || "$errors" != "0" || "$violations" != "0" \
			|| "$outcome" == "stalled" || "$outcome" == "looping" ]]; then
		echo "$line  FAILED"
		return 1
	fi
	echo "$line"
}
export -f play_one
export GODOT PROJECT policies watch time_limit gauntlet
export extra_joined="${extra[*]+"${extra[*]}"}"

# Seeds whose transcripts contain <pattern>, at most three: example_seeds <pattern>.
example_seeds() {
	grep -l -F -- "$1" "$out"/*.jsonl 2>/dev/null | head -3 \
		| sed -E 's/.*seed_([0-9]+)_([a-z]+)(__.*)?\.jsonl$/\1_\2\3/' | paste -sd' ' -
}

# What a batch found, grouped, with seeds to replay.
summarize() {
	echo
	echo "== Outcomes"
	grep -h '"type":"result"' "$out"/*.jsonl 2>/dev/null \
		| sed -nE 's/.*"outcome":"([a-z_]*)".*/\1/p' | sort | uniq -c | sort -rn
	local missing
	missing=$(( runs - $(grep -l '"type":"result"' "$out"/*.jsonl 2>/dev/null | wc -l) ))
	(( missing > 0 )) && printf '%7d no result (crashed or hung)\n' "$missing"

	local checks
	checks=$(grep -h '"type":"violation"' "$out"/*.jsonl 2>/dev/null \
		| sed -nE 's/.*"check":"([a-z_]*)".*/\1/p' | sort | uniq -c | sort -rn)
	if [[ -n "$checks" ]]; then
		echo
		echo "== Invariant violations (count, check, example seeds)"
		while read -r count check; do
			printf '%7d %-32s %s\n' "$count" "$check" "$(example_seeds "\"check\":\"$check\"")"
		done <<< "$checks"
	fi

	local leaks
	leaks=$(grep -h '"leaks":' "$out"/*.jsonl 2>/dev/null \
		| sed -nE 's/.*"leaks":\["([a-z_]*)".*/\1/p' | sort | uniq -c | sort -rn)
	if [[ -n "$leaks" ]]; then
		echo
		echo "== Memory warnings, not failures (count, warning, example seeds)"
		while read -r count leak; do
			printf '%7d %-32s %s\n' "$count" "$leak" "$(example_seeds "\"leaks\":[\"$leak")"
		done <<< "$leaks"
	fi

	local errors
	errors=$(grep -h '"type":"error"' "$out"/*.jsonl 2>/dev/null \
		| sed -nE 's/.*"message":"(([^"\\]|\\.)*)".*"at":"([^"]*)".*/\3 ~~ \1/p' \
		| sort | uniq -c | sort -rn | head -15)
	if [[ -n "$errors" ]]; then
		echo
		echo "== Errors (count, where, message, example seeds)"
		local count rest
		while read -r count rest; do
			printf '%7d %s\n        %s\n        seeds: %s\n' "$count" "${rest%% ~~ *}" \
				"${rest#* ~~ }" "$(example_seeds "\"at\":\"${rest%% ~~ *}\"")"
		done <<< "$errors"
	fi
	echo
	echo "transcripts: $out"
	if [[ -n "$(python3 "$PROJECT/tools/autoplay_replay.py" flagged "$out" --limit 1 2>/dev/null)" ]]; then
		echo "to watch the worst of them again, with screenshots: tools/autoplay.sh --replay $out"
	fi
}

IFS=',' read -ra policy_list <<< "$policies"
first_policy="${policy_list[0]}"

if [[ $determinism -eq 1 ]]; then
	policy="$first_policy"
	mkdir -p "$out/a" "$out/b"
	cell=()
	name="seed_${seed}_${policy}.jsonl"
	if [[ -n "$gauntlet" ]]; then
		# A gauntlet is checked on its first scenario and loadout.
		read -ra cell <<< "$(python3 -c 'import json,sys; s=json.load(open(sys.argv[1])); c=s["scenarios"][0]; print(c["id"] if isinstance(c, dict) else c, next(iter(s["loadouts"])))' "$gauntlet")"
		name="seed_${seed}_${policy}__${cell[0]}__${cell[1]}.jsonl"
	fi
	play_one "$seed" "$out/a" "$policy" "${cell[@]+"${cell[@]}"}" &
	play_one "$seed" "$out/b" "$policy" "${cell[@]+"${cell[@]}"}" &
	wait
	# Memory use isn't gameplay; it's the one thing allowed to differ.
	if diff -q <(grep -v '"type":"memory"' "$out/a/$name") \
			<(grep -v '"type":"memory"' "$out/b/$name") > /dev/null; then
		echo "DETERMINISTIC: seed $seed played identically twice ($out)"
		exit 0
	fi
	echo "NOT DETERMINISTIC: seed $seed diverged. First difference:"
	diff <(grep -v '"type":"memory"' "$out/a/$name") \
		<(grep -v '"type":"memory"' "$out/b/$name") | head -6
	exit 1
fi

if [[ $watch -eq 1 ]]; then
	play_one "$seed" "$out" "$first_policy"
	exit $?
fi

failed=0
if [[ -n "$gauntlet" ]]; then
	# One line per run: seed, policy, scenario, loadout.
	cells=$(python3 - "$gauntlet" "$seed" "$runs" "$runs_given" "$policies" <<'PYEOF'
import json, sys
spec = json.load(open(sys.argv[1]))
first, runs, runs_given = int(sys.argv[2]), int(sys.argv[3]), sys.argv[4] == "1"
count = runs if runs_given else int(spec.get("seeds", 10))
scenarios = [s["id"] if isinstance(s, dict) else s for s in spec["scenarios"]]
for scenario in scenarios:
    for loadout in spec["loadouts"]:
        for run_seed in range(first, first + count):
            for policy in sys.argv[5].split(","):
                print(run_seed, policy, scenario, loadout)
PYEOF
	) || { echo "can't read gauntlet spec $gauntlet" >&2; exit 2; }
	runs=$(wc -l <<< "$cells" | tr -d ' ')
	export out
	xargs -P "$jobs" -n 4 bash -c 'play_one "$1" "$out" "$2" "$3" "$4"' _ <<< "$cells" || failed=1
else
	lines=$(for (( s = seed; s < seed + runs; s++ )); do
		for policy in "${policy_list[@]}"; do echo "$s $policy"; done
	done)
	runs=$(wc -l <<< "$lines" | tr -d ' ')
	export out
	xargs -P "$jobs" -n 2 bash -c 'play_one "$1" "$out" "$2"' _ <<< "$lines" || failed=1
fi
summarize
if command -v python3 > /dev/null; then
	echo
	python3 "$PROJECT/tools/autoplay_report.py" "$out" || true
fi
exit $failed
