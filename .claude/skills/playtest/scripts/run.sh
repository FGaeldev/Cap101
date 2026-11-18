#!/usr/bin/env bash
# Runs a Cap101 playtest: static data check + auto-playthrough, both windowed so
# every finding gets a screenshot. Every Godot run saves into its own folder
# (user://playtest/<run>/, via GameState's --save-dir), so the player's save
# slots are never touched; the folders are removed afterwards. settings.cfg is
# shared, so it's backed up and put back if a run changed it.
#
#   run.sh full                 every playable chapter from a new game, one run
#   run.sh chapter <N>          one chapter from its start state
#   run.sh parallel             every story segment (autoplay.gd SEGMENTS: 1, 2a,
#                               2b, 3, 4), each from its start state until the next
#                               chapter's opening cutscene starts, a few at once,
#                               then one merged summary.md
#   run.sh static               data check only
#
# Env: GODOT (console binary), PLAYTEST_BUDGET (seconds, per run), PLAYTEST_ARGS
# (extra autoplay args), PLAYTEST_PARALLEL (runs at once, default 3),
# PLAYTEST_SEGMENTS (default "1 2a 2b 3 4").
# Prints the report folder on the last line: REPORT_DIR=<path>
set -u

MODE="${1:-full}"
CHAPTER="${2:-}"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$SKILL_DIR/../../../.." && pwd)"
GODOT="${GODOT:-C:/Users/ACER/Desktop/Francis/godot/Godot_v4.7.2-stable_win64_console.exe}"
USERDIR="${APPDATA:-$HOME/.local/share}/Godot/app_userdata/BueotHambaeon"

case "$MODE" in
	full) LABEL="full" ;;
	chapter)
		[ -n "$CHAPTER" ] || { echo "usage: run.sh chapter <N>"; exit 2; }
		LABEL="ch${CHAPTER}" ;;
	parallel) LABEL="parallel" ;;
	static) LABEL="static" ;;
	*) echo "usage: run.sh full | chapter <N> | parallel | static"; exit 2 ;;
esac

STAMP="$(date +%Y-%m-%d_%H%M%S)"
OUT="$PROJECT/playtest_reports/${STAMP}_${LABEL}"
SAVE_ROOT="user://playtest/${STAMP}_${LABEL}"
mkdir -p "$OUT/shots" "$OUT/backup"
# Keep Godot from importing the screenshots as project assets.
touch "$PROJECT/playtest_reports/.gdignore"

# --- settings.cfg is shared by every run: back it up -----------------------------
[ -f "$USERDIR/settings.cfg" ] && cp -p "$USERDIR/settings.cfg" "$OUT/backup/settings.cfg"
START_EPOCH="$(date +%s)"

cleanup() {
	if [ -f "$OUT/backup/settings.cfg" ]; then
		# Only put it back if it changed during this run (the user may have
		# changed a setting in the editor before we started).
		if [ -f "$USERDIR/settings.cfg" ] && [ "$(stat -c %Y "$USERDIR/settings.cfg")" -ge "$START_EPOCH" ]; then
			cp -p "$OUT/backup/settings.cfg" "$USERDIR/settings.cfg"
		fi
	fi
	rm -rf "$USERDIR/playtest/${STAMP}_${LABEL}"
	echo "player saves: untouched (runs saved under $SAVE_ROOT, now removed)"
}
trap cleanup EXIT

cd "$PROJECT" || exit 1

echo "== static check"
timeout -k 5 300 "$GODOT" --path . --script "$SKILL_DIR/validate.gd" -- --out="$OUT" \
	--save-dir="$SAVE_ROOT/static/" > "$OUT/validate.log" 2>&1
echo "validate exit $?"

EXTRA=()
# shellcheck disable=SC2206
[ -n "${PLAYTEST_ARGS:-}" ] && EXTRA=($PLAYTEST_ARGS)

if [ "$MODE" = "full" ] || [ "$MODE" = "chapter" ]; then
	ARGS=(--out="$OUT" --save-dir="$SAVE_ROOT/run/")
	if [ "$MODE" = "chapter" ]; then ARGS+=(--mode=chapter --chapter="$CHAPTER"); else ARGS+=(--mode=full); fi
	[ -n "${PLAYTEST_BUDGET:-}" ] && ARGS+=(--budget="$PLAYTEST_BUDGET")
	ARGS+=("${EXTRA[@]}")
	HARD_LIMIT=$(( ${PLAYTEST_BUDGET:-1800} + 120 ))
	echo "== autoplay (${ARGS[*]})"
	timeout -k 5 "$HARD_LIMIT" "$GODOT" --path . --script "$SKILL_DIR/autoplay.gd" -- "${ARGS[@]}" \
		> "$OUT/godot.log" 2>&1
	echo "autoplay exit $?"
fi

if [ "$MODE" = "parallel" ]; then
	MAX="${PLAYTEST_PARALLEL:-3}"
	BUDGET="${PLAYTEST_BUDGET:-1500}"
	HARD_LIMIT=$(( BUDGET + 120 ))
	echo "== segments (${PLAYTEST_SEGMENTS:-1 2a 2b 3 4}), $MAX at once, ${BUDGET}s each"
	for seg in ${PLAYTEST_SEGMENTS:-1 2a 2b 3 4}; do
		while [ "$(jobs -rp | wc -l)" -ge "$MAX" ]; do
			wait -n
		done
		SEG_OUT="$OUT/seg_$seg"
		mkdir -p "$SEG_OUT/shots"
		echo "   start segment $seg ($(date +%H:%M:%S))"
		(
			s0=$(date +%s)
			timeout -k 5 "$HARD_LIMIT" "$GODOT" --path . --script "$SKILL_DIR/autoplay.gd" -- \
				--out="$SEG_OUT" --mode=segment --segment="$seg" --budget="$BUDGET" \
				--save-dir="$SAVE_ROOT/seg_$seg/" "${EXTRA[@]}" > "$SEG_OUT/godot.log" 2>&1
			echo "   segment $seg done: exit $?, $(( $(date +%s) - s0 ))s"
		) &
		sleep 3   # stagger the windows' start-up
	done
	wait
	node "$SKILL_DIR/merge_parallel.js" "$OUT"
fi

echo "REPORT_DIR=$OUT"
