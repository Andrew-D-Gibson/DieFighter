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
#                     [--out DIR] [--watch] [--determinism] [-- extra args]
#
#   --seed N        first seed (default: random); runs use N, N+1, ...
#   --runs N        how many runs (default 1)
#   --jobs N        how many at once (default: CPU count)
#   --policy NAME   AutoPilot policy (default random)
#   --out DIR       output directory (default .autoplay/<timestamp>)
#   --watch         one run, windowed, real time
#   --determinism   play --seed twice and check both transcripts match
#   -- ...          anything after this goes to the AutoPilot as-is
#                   (e.g. -- --max-turns=100)
#
# Each run writes seed_<N>_<policy>.jsonl (the transcript) and .log (the
# engine's output) to the output directory. Exit status is non-zero if any run
# stalled, looped, crashed or logged a script error.

set -uo pipefail

GODOT="${GODOT:-/Users/drew/Documents/Godot/Godot_4.7_stable.app/Contents/MacOS/Godot}"
PROJECT="$(cd "$(dirname "$0")/.." && pwd)"

seed=""
runs=1
jobs="$(sysctl -n hw.ncpu 2>/dev/null || nproc)"
policy="random"
out=""
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

# One run: play_one <seed> <dir>. Prints a one-line summary.
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
		--out="$dir" "${extra_args[@]+"${extra_args[@]}"}" > "$dir/$name.log" 2>&1
	local code=$?
	local result errors
	result=$(grep '"type":"result"' "$dir/$name.jsonl" 2>/dev/null | tail -1)
	errors=$(grep -c "SCRIPT ERROR" "$dir/$name.log")
	echo "seed $run_seed: exit $code, ${errors} script errors, ${result:-no result}"
	[[ $code -eq 0 && $errors -eq 0 && -n "$result" ]]
}
export -f play_one
export GODOT PROJECT policy watch
export extra_joined="${extra[*]+"${extra[*]}"}"

if [[ $determinism -eq 1 ]]; then
	mkdir -p "$out/a" "$out/b"
	play_one "$seed" "$out/a" &
	play_one "$seed" "$out/b" &
	wait
	if diff -q "$out/a/seed_${seed}_${policy}.jsonl" "$out/b/seed_${seed}_${policy}.jsonl" > /dev/null; then
		echo "DETERMINISTIC: seed $seed played identically twice ($out)"
		exit 0
	fi
	echo "NOT DETERMINISTIC: seed $seed diverged. First difference:"
	diff "$out/a/seed_${seed}_${policy}.jsonl" "$out/b/seed_${seed}_${policy}.jsonl" | head -6
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
echo "transcripts: $out"
exit $failed
