#!/usr/bin/env bash
# Runs a Cap101 playtest: static data check + auto-playthrough, both windowed so
# every finding gets a screenshot. Backs up the player's save and settings first
# and puts them back afterwards (only if the run changed them).
#
#   run.sh full                 every playable chapter from a new game
#   run.sh chapter <N>          one chapter from its start state
#   run.sh static               data check only
#
# Env: GODOT (console binary), PLAYTEST_BUDGET (seconds), PLAYTEST_ARGS (extra autoplay args)
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
	static) LABEL="static" ;;
	*) echo "usage: run.sh full | chapter <N> | static"; exit 2 ;;
esac

STAMP="$(date +%Y-%m-%d_%H%M%S)"
OUT="$PROJECT/playtest_reports/${STAMP}_${LABEL}"
mkdir -p "$OUT/shots" "$OUT/backup"
# Keep Godot from importing the screenshots as project assets.
touch "$PROJECT/playtest_reports/.gdignore"

# --- back up the real save ----------------------------------------------------
for f in save.dat save.bak settings.cfg; do
	[ -f "$USERDIR/$f" ] && cp -p "$USERDIR/$f" "$OUT/backup/$f"
done
START_EPOCH="$(date +%s)"

restore() {
	for f in save.dat save.bak settings.cfg; do
		if [ -f "$OUT/backup/$f" ]; then
			# Only put it back if it changed during this run (the user may have
			# played and saved in the editor before we started).
			if [ -f "$USERDIR/$f" ] && [ "$(stat -c %Y "$USERDIR/$f")" -ge "$START_EPOCH" ]; then
				cp -p "$OUT/backup/$f" "$USERDIR/$f"
			fi
		elif [ -f "$USERDIR/$f" ] && [ "$(stat -c %Y "$USERDIR/$f")" -ge "$START_EPOCH" ]; then
			rm -f "$USERDIR/$f"   # the run created it
		fi
	done
	rm -f "$USERDIR/save.tmp"
	if [ -f "$OUT/backup/save.dat" ] && cmp -s "$USERDIR/save.dat" "$OUT/backup/save.dat"; then
		echo "save.dat: restored/unchanged"
	elif [ -f "$OUT/backup/save.dat" ]; then
		echo "WARNING: save.dat differs from backup in $OUT/backup (changed before this run started?)"
	fi
}
trap restore EXIT

cd "$PROJECT" || exit 1

echo "== static check"
timeout -k 5 300 "$GODOT" --path . --script "$SKILL_DIR/validate.gd" -- --out="$OUT" \
	> "$OUT/validate.log" 2>&1
echo "validate exit $?"

if [ "$MODE" != "static" ]; then
	ARGS=(--out="$OUT")
	if [ "$MODE" = "chapter" ]; then ARGS+=(--mode=chapter --chapter="$CHAPTER"); else ARGS+=(--mode=full); fi
	[ -n "${PLAYTEST_BUDGET:-}" ] && ARGS+=(--budget="$PLAYTEST_BUDGET")
	# shellcheck disable=SC2206
	[ -n "${PLAYTEST_ARGS:-}" ] && ARGS+=($PLAYTEST_ARGS)
	HARD_LIMIT=$(( ${PLAYTEST_BUDGET:-1800} + 120 ))
	echo "== autoplay (${ARGS[*]})"
	timeout -k 5 "$HARD_LIMIT" "$GODOT" --path . --script "$SKILL_DIR/autoplay.gd" -- "${ARGS[@]}" \
		> "$OUT/godot.log" 2>&1
	echo "autoplay exit $?"
fi

echo "REPORT_DIR=$OUT"
