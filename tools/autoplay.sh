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
#   tools/autoplay.sh [--seed N] [--runs N] [--jobs N] [--policy NAME]
#                     [--out DIR] [--time-limit S] [--watch] [--determinism]
#                     [-- extra args]
#
#   --seed N         first seed (default: random); runs use N, N+1, ...
#   --runs N         how many runs (default 1)
#   --jobs N         how many at once (default: CPU count)
#   --policy NAME    AutoPilot policy (default random)
#   --out DIR        output directory (default .autoplay/<timestamp>)
#   --time-limit S   kill a run after S seconds of wall time (default 300;
#                    a run takes seconds, so this only catches a hang)
#   --watch          one run, windowed, real time
#   --determinism    play --seed twice and check both transcripts match
#   -- ...           anything after this goes to the AutoPilot as-is
#                    (e.g. -- --max-turns=100)
#
# Each run writes to the output directory:
#   seed_<N>_<policy>.jsonl      the transcript: turns, moves, errors,
#                                invariant violations, the result
#   seed_<N>_<policy>.debug.txt  the engine's play-by-play (DebugLogger)
#   seed_<N>_<policy>.log        the engine's console output
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
policy="random"
out=""
time_limit=300
watch=0
determinism=0
extra=()

while [[ $# -gt 0 ]]; do
	case "$1" in
		--seed) seed="$2"; shift 2 ;;
		--runs) runs="$2"; shift 2 ;;
		--jobs) jobs="$2"; shift 2 ;;
		--policy) policy="$2"; shift 2 ;;
		--out) out="$2"; shift 2 ;;
		--time-limit) time_limit="$2"; shift 2 ;;
		--watch) watch=1; shift ;;
		--determinism) determinism=1; shift ;;
		--) shift; extra=("$@"); break ;;
		*) echo "unknown option: $1" >&2; exit 2 ;;
	esac
done

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

# One run: play_one <seed> <dir>. Prints a one-line summary; fails if the run
# did.
play_one() {
	local run_seed="$1" dir="$2"
	local name="seed_${run_seed}_${policy}"
	local args=(--path "$PROJECT")
	# Arrays don't survive export into xargs' shells, so extras travel joined.
	local extra_args=()
	[[ -n "${extra_joined:-}" ]] && read -ra extra_args <<< "$extra_joined"
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
	local line="seed $run_seed: $outcome after $turns turns, $errors errors, $violations violations"
	if [[ $code -ne 0 || "$errors" != "0" || "$violations" != "0" \
			|| "$outcome" == "stalled" || "$outcome" == "looping" ]]; then
		echo "$line  FAILED"
		return 1
	fi
	echo "$line"
}
export -f play_one
export GODOT PROJECT policy watch time_limit
export extra_joined="${extra[*]+"${extra[*]}"}"

# Seeds whose transcripts contain <pattern>, at most three: example_seeds <pattern>.
example_seeds() {
	grep -l -F -- "$1" "$out"/*.jsonl 2>/dev/null | head -3 \
		| sed -E 's/.*seed_([0-9]+)_.*/\1/' | paste -sd' ' -
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
}

if [[ $determinism -eq 1 ]]; then
	mkdir -p "$out/a" "$out/b"
	play_one "$seed" "$out/a" &
	play_one "$seed" "$out/b" &
	wait
	# Memory use isn't gameplay; it's the one thing allowed to differ.
	name="seed_${seed}_${policy}.jsonl"
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
	play_one "$seed" "$out"
	exit $?
fi

failed=0
seq "$seed" $(( seed + runs - 1 )) \
	| xargs -P "$jobs" -I{} bash -c 'play_one "$1" "$2"' _ {} "$out" \
	|| failed=1
summarize
exit $failed
