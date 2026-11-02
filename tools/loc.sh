#!/usr/bin/env bash
# The translation round trip. English is written in the editor (content
# resources' own fields, e.g. a hazard's headline) or in
# Localization/translations.csv (UI text); this moves it out for translation
# and the translations back in. See CONTENT_BUILD_GUIDE "Text & localization".
#
# Usage:
#   tools/loc.sh sync              copy content English into Localization/content.csv;
#                                  translations of changed English are marked stale
#   tools/loc.sh check             report what sync would change, write nothing
#   tools/loc.sh export <locale>   write Localization/pending/<locale>.csv: every
#                                  row that locale is missing or has stale
#   tools/loc.sh import <file> [--status reviewed]
#                                  merge a filled-in export back into the CSVs
#                                  (status defaults to machine), re-import them
#                                  into Godot, then lint
#   tools/loc.sh lint              check + the translation lint test
#                                  (placeholders, tokens, BBCode, length, glyphs)
#   tools/loc.sh tokens <report|convert|verify> --family <red|blue|green|purple|yellow|all>
#                                  [--dry-run] [--against <git ref>]
#                                  tile numbers as {placeholders} bound to the
#                                  steps that hold them (TextTokens): report the
#                                  literals left, convert a family, or verify the
#                                  filled text still reads as it did at a ref
#   tools/loc.sh audit [locale|pseudo|all] [surface ...] [--headless]
#                                  photograph every text surface in each language,
#                                  flag text that overflows or lacks glyphs, and
#                                  write a report (path printed at the end);
#                                  --headless checks text without photos
#
# Locales: zh_CN ja ru de fr es pt_BR (a new code gets a column on import).
# Close the Godot editor first if it has this project open: it rewrites the
# CSVs' import files while the tools run.
set -euo pipefail

GODOT="${GODOT:-/Users/drew/Documents/Godot/Godot_4.7_stable.app/Contents/MacOS/Godot}"
start_dir="$PWD"
cd "$(dirname "$0")/.."

TOOL="res://Source/Systems/Localization/Tools/loc_sync.gd"
LINT_TEST="res://test/content/test_localization.gd"

# Runs the GDScript tool, showing only its own report lines (and any script
# error), and passes its exit status on.
run_tool() {
	set +e +o pipefail
	"$GODOT" --headless --path . --script "$TOOL" -- "$@" 2>&1 \
		| grep -E '^loc: |SCRIPT ERROR|Parse Error' | sed 's/^loc: //'
	local status=${PIPESTATUS[0]}
	set -e -o pipefail
	return "$status"
}

# Godot turns each CSV column into a .translation file on import; the game
# reads those, not the CSV.
reimport() {
	echo "re-importing the CSVs..."
	"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
}

lint() {
	local failed=0
	run_tool check || failed=1
	echo "running the translation lint..."
	local out
	out="$("$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= \
		-gtest="$LINT_TEST" -gexit 2>&1)" || true
	echo "$out" | sed $'s/\x1b\\[[0-9;]*m//g' \
		| grep -E '\[Failed\]|\[Pending\]|^ {4}[A-Za-z_.]+ \[|Passing Tests|Failing Tests|Risky/Pending' \
		| awk '!seen[$0]++' || true
	# No summary at all means the run itself broke.
	if echo "$out" | grep -q 'Failing Tests' || ! echo "$out" | grep -q 'Passing Tests'; then
		failed=1
	fi
	return "$failed"
}

command="${1:-}"
[ $# -gt 0 ] && shift
case "$command" in
	sync)
		run_tool sync "$@"
		;;
	check)
		run_tool check "$@"
		;;
	export)
		[ $# -ge 1 ] || { echo "usage: tools/loc.sh export <locale>" >&2; exit 2; }
		run_tool export "$@"
		;;
	import)
		[ $# -ge 1 ] || { echo "usage: tools/loc.sh import <file> [--status reviewed]" >&2; exit 2; }
		file="$1"
		shift
		# The tool resolves relative paths against the project, so make the
		# file absolute while we still know where the user ran this from.
		case "$file" in
			/*|res://*) ;;
			*) file="$start_dir/$file" ;;
		esac
		run_tool import "$file" "$@"
		reimport
		lint
		;;
	lint)
		lint
		;;
	tokens)
		set +e +o pipefail
		"$GODOT" --headless --path . --script res://Source/Systems/Localization/Tools/tile_text_tokens_cli.gd \
			-- "$@" 2>&1 | grep -E '^tokens: |SCRIPT ERROR|Parse Error' | sed 's/^tokens: //'
		status=${PIPESTATUS[0]}
		set -e -o pipefail
		exit "$status"
		;;
	audit)
		# A window opens: photos need a renderer, which --headless lacks. The
		# run is offline: it never opens the game's MCP port.
		display=()
		audit_args=()
		for arg in "$@"; do
			if [ "$arg" = "--headless" ]; then display=(--headless); else audit_args+=("$arg"); fi
		done
		[ ${#audit_args[@]} -gt 0 ] || audit_args=(all)
		set +e +o pipefail
		"$GODOT" ${display[@]+"${display[@]}"} --path . -s res://Source/Debug/LocAudit/loc_audit_cli.gd \
			-- "${audit_args[@]}" 2>&1 | grep --line-buffered -E '^loc_audit: |SCRIPT ERROR|Parse Error' \
			| sed -l 's/^loc_audit: //'
		status=${PIPESTATUS[0]}
		set -e -o pipefail
		exit "$status"
		;;
	*)
		sed -n '2,35p' "$0" | sed 's/^# \{0,1\}//'
		exit 2
		;;
esac
