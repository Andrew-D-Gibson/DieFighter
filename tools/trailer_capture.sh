#!/usr/bin/env bash
# Records trailer shots (Source/Debug/Trailer/Shots/*.tres) with Godot's Movie
# Maker: every frame is rendered and saved at exactly 1/FPS of game time,
# however long the machine takes to draw it, so takes are frame-perfect, at
# full resolution, with the game's own audio, and identical take after take.
#
# Each shot opens in a window, plays its beats and quits. Shots without beats
# (civilian, pact, sandbox) are played by hand: the window stays up until you
# close it or --max-seconds runs out, and Movie Maker records whatever you do
# (keep the trailer hotkeys in mind: F1 trailer mode, 1-0 set pieces, F6
# marker).
#
# Two names aren't shots but scenes, recorded in trailer mode for as long as
# --max-seconds allows (close the window to stop sooner):
#   cold_open  the opening cutscene, straight into the ambush fight
#   menu       the main menu and its diorama
#
# Usage:
#   tools/trailer_capture.sh <shot> [<shot> ...] [options]
#   tools/trailer_capture.sh --all [options]
#
#   --all            every shot in Source/Debug/Trailer/Shots
#   --fps N          frames per second of video (default 60)
#   --png            a PNG sequence + WAV per take instead of one AVI:
#                    lossless, for the final cut (about 3 MB a frame)
#   --out DIR        where takes go (default captures/<timestamp>)
#   --max-seconds N  end a take after N seconds of video, beats or not
#                    (default 120)
#   --vertical       also cut a 1080x1920 crop centred on the tile grid,
#                    for Shorts/TikTok (needs ffmpeg)
#   --crop-x X       left edge of the vertical crop in 1920x1080 pixels
#                    (default 581: the Die Fighter's grid in the middle)
#   -- ...           anything after this goes to the game as-is
#
# Each take is <out>/<shot>.avi (or <shot>/frame########.png + .wav), beside
# a marker log <shot>_<time>.txt: the frame and second of every `mark` beat,
# for finding the moments in the edit.
#
# GODOT is the 4.7.1 binary (default: `godot` on PATH).

set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
FPS=60
PNG=0
OUT=""
MAX_SECONDS=120
VERTICAL=0
CROP_X=581
SHOTS=()
EXTRA=()

while [[ $# -gt 0 ]]; do
	case "$1" in
		--all)
			for file in Source/Debug/Trailer/Shots/*.tres; do
				SHOTS+=("$(basename "$file" .tres)")
			done
			shift ;;
		--fps) FPS="$2"; shift 2 ;;
		--png) PNG=1; shift ;;
		--out) OUT="$2"; shift 2 ;;
		--max-seconds) MAX_SECONDS="$2"; shift 2 ;;
		--vertical) VERTICAL=1; shift ;;
		--crop-x) CROP_X="$2"; shift 2 ;;
		--) shift; EXTRA=("$@"); break ;;
		-h|--help) sed -n '2,40p' "$0"; exit 0 ;;
		-*) echo "unknown option $1 (see --help)" >&2; exit 2 ;;
		*) SHOTS+=("$1"); shift ;;
	esac
done

if [[ ${#SHOTS[@]} -eq 0 ]]; then
	echo "name a shot, or --all. Shots:" >&2
	ls Source/Debug/Trailer/Shots/ | sed 's/\.tres$//; s/^/  /' >&2
	exit 2
fi
command -v "$GODOT" > /dev/null || { echo "no Godot at '$GODOT' (set GODOT)" >&2; exit 2; }
if [[ $VERTICAL -eq 1 ]]; then
	command -v ffmpeg > /dev/null || { echo "--vertical needs ffmpeg" >&2; exit 2; }
fi

OUT="${OUT:-captures/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUT"
# Keeps Godot from importing thousands of frames if OUT is inside the project.
touch "$OUT/.gdignore"
OUT_ABS="$(cd "$OUT" && pwd)"

failed=0
for shot in "${SHOTS[@]}"; do
	scene=()
	game_args=(--trailer-shot="$shot" --trailer-quit)
	case "$shot" in
		cold_open) scene=(res://Source/Scenes/Cutscenes/opening_cutscene.tscn); game_args=(--trailer) ;;
		menu) scene=(res://Source/Systems/UI/MainMenu/main_menu.tscn); game_args=(--trailer) ;;
	esac
	if [[ ${#scene[@]} -eq 0 && ! -f "Source/Debug/Trailer/Shots/$shot.tres" ]]; then
		echo "no shot '$shot'" >&2
		failed=1
		continue
	fi
	if [[ $PNG -eq 1 ]]; then
		mkdir -p "$OUT_ABS/$shot"
		movie="$OUT_ABS/$shot/frame.png"
	else
		movie="$OUT_ABS/$shot.avi"
	fi
	echo "== $shot -> $movie"
	# --quit-after counts frames: the ceiling for a take whose beats never
	# reach `quit` (or a shot played by hand).
	if ! "$GODOT" --path . --write-movie "$movie" --fixed-fps "$FPS" \
		--quit-after "$((MAX_SECONDS * FPS))" ${scene[@]+"${scene[@]}"} \
		-- "${game_args[@]}" --trailer-log-dir="$OUT_ABS" ${EXTRA[@]+"${EXTRA[@]}"}; then
		echo "   $shot: the game exited with an error" >&2
		failed=1
		continue
	fi
	if [[ $VERTICAL -eq 1 && $PNG -eq 0 ]]; then
		# 608x1080 is 9:16; nearest-neighbour keeps the pixels square-ish
		# at the non-integer 1.78x.
		ffmpeg -loglevel error -y -i "$movie" \
			-vf "crop=608:1080:${CROP_X}:0,scale=1080:1920:flags=neighbor" \
			-c:v libx264 -crf 14 -pix_fmt yuv420p -c:a aac "$OUT_ABS/${shot}_vertical.mp4"
		echo "   vertical: $OUT_ABS/${shot}_vertical.mp4"
	fi
done

echo "Takes in $OUT_ABS"
exit $failed
