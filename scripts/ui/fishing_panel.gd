# fishing_panel.gd -- "fishing for words": a timed vocabulary game. A question
# sits at the top; fish swim across the water, each carrying an answer; tap the
# fish with the right one before time runs out. Chapter 4's pier scene (Manong
# Ambo) and the NPC "Review" menu both use it.
#
# Driven by a dialogue line of type "minigame_trigger", minigame_type "fishing":
#   {
#     "type": "minigame_trigger", "minigame_type": "fishing",
#     "word_pool": ["w091", "w355"],   # words the questions are about (required)
#     "seconds": 45,                   # optional: overrides the tier's time
#     "fish": 3,                       # optional: overrides the tier's fish count (2-4)
#     "pass_count": 5,                 # optional: right answers to pass (default 5)
#     "success": 11, "failure": 14
#   }
#
# Each question asks either "What does <Akeanon> mean?" (fish carry English) or
# "Which word means <English>?" (fish carry Akeanon), alternating. Right: the
# fish is caught, points (x combo), +0.5 s, +1 mastery for the word. Wrong: -3 s,
# the right fish lights up for a moment, then a NEW question (no retrying the
# same one). No other penalty (GDD 7). When time runs out a results card shows
# the score and the answers that were missed; Continue resolves.
#
# Difficulty follows GameState.get_difficulty_tier() (like memory match and the
# quiz): tier 1 = 60 s, 2 fish, slow, and the fish stop while a finger is on the
# water; tier 2 = 45 s, 3 fish; tier 3 = 45 s, 4 faster fish, and wrong answers
# picked to look alike (same word type or first letter).
#
# Art: pixel fish from assets/sprites/minigames/fishing_fish.png (drawn by
# art_requests/tools/gen_fish_sprites.gd.txt), each answer written on the fish's
# body, which stretches to fit the word; bubbles drawn in code; the team's water tile.
#
# Ownership: renders and reports only. Emits `resolved(passed)`; DialogueUI
# forwards it. Bad data never softlocks: reports and resolves as a pass.
extends PanelContainer

signal resolved(passed: bool)

const TIERS := {
	1: {"seconds": 60, "fish": 2, "speed": 26.0, "freeze_on_touch": true, "similar": false},
	2: {"seconds": 45, "fish": 3, "speed": 36.0, "freeze_on_touch": false, "similar": false},
	3: {"seconds": 45, "fish": 4, "speed": 48.0, "freeze_on_touch": false, "similar": true},
}
const DEFAULT_PASS_COUNT := 5
## Seconds a right catch adds back (v1.1.6: was 2.0, the clock now mostly just runs down).
const RIGHT_BONUS_SECONDS := 0.5
const WRONG_PENALTY_SECONDS := 3.0
const POINTS := 10
## Every this many right answers in a row adds 1 to the multiplier (max 4).
const COMBO_STEP := 3
const COMBO_MAX := 4
const NEXT_DELAY := 0.5
const WRONG_SHOW := 1.2
const WATER_SHEET := "res://assets/pastrana/pastrana_outdoors.png"
const WATER_CELL := Vector2i(25, 5)
## Space kept clear at the bottom of the water for the seabed (fish swim above it).
const SEABED_CLEAR := 30.0
## Pixel fish kinds in Fish.SHEET (art_requests/tools/gen_fish_sprites.gd.txt):
## bangus, snapper, damselfish, parrotfish.
const FISH_KINDS := 4
const FISH_SIZE := Vector2(96, 60)  # resized per lane and word in Fish.reset()

var _pool: Array = []          # question words
var _answers_pool: Array = []  # words that may appear as wrong answers
var _tier: Dictionary = {}
var _pass_count: int = DEFAULT_PASS_COUNT
var _time_left: float = 0.0
var _time_total: float = 0.0
var _score: int = 0
var _streak: int = 0
var _best_streak: int = 0
var _right: int = 0
var _asked: int = 0
var _missed: Array = []        # [{word, answer}]
var _recent: Array = []
var _direction: int = 0        # 0: Akeanon -> English, 1: English -> Akeanon
var _target: String = ""
var _locked: bool = true
var _running: bool = false
var _finger_down: bool = false
var _session: int = 0
var _fish: Array = []

var _question: Label
var _timer_label: Label
var _score_label: Label
var _timer_bar: ProgressBar
var _water: Control
var _bubbles: Control
var _feedback: Label
var _results: VBoxContainer
var _results_text: Label
var _play: VBoxContainer

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UIThemeApplier.make_dialogue_style())
	_build_layout()
	HelpButton.pin(self, "fishing")
	visible = false
	set_process(false)

# --- public API ----------------------------------------------------------------

func open(line: Dictionary) -> void:
	_session += 1
	_pool = _valid_ids(line.get("word_pool", []))
	_answers_pool = _pool.duplicate()
	for id in WordBank.top_up_pool(_pool.duplicate(), 12, true):
		if not _answers_pool.has(id) and not WordBank.get_word(id).is_empty():
			_answers_pool.append(id)
	_tier = TIERS.get(clampi(GameState.get_difficulty_tier(), 1, 3), TIERS[2]).duplicate()
	if line.has("seconds"):
		_tier["seconds"] = int(line["seconds"])
	if line.has("fish"):
		_tier["fish"] = clampi(int(line["fish"]), 2, 4)
	_tier["fish"] = mini(int(_tier["fish"]), _answers_pool.size())
	if _pool.is_empty() or int(_tier["fish"]) < 2:
		push_error("Fishing: needs a word_pool and 2+ answer words, auto-passing.")
		call_deferred("_emit_resolved", true)
		return
	_pass_count = maxi(int(line.get("pass_count", DEFAULT_PASS_COUNT)), 1)
	_time_total = float(_tier["seconds"])
	_time_left = _time_total
	_score = 0
	_streak = 0
	_best_streak = 0
	_right = 0
	_asked = 0
	_missed.clear()
	_recent.clear()
	_direction = randi() % 2
	_play.visible = true
	_results.visible = false
	visible = true
	_build_fish(int(_tier["fish"]))
	_running = true
	set_process(true)
	_refresh_hud()
	_next_question.call_deferred()

func close() -> void:
	_session += 1
	_running = false
	_locked = true
	set_process(false)
	visible = false

# --- questions ---------------------------------------------------------------------

func _next_question() -> void:
	if not _running:
		return
	var candidates: Array = _pool.filter(func(id): return not _recent.has(id))
	if candidates.is_empty():
		_recent.clear()
		candidates = _pool.duplicate()
	_target = WordBank.get_weighted_review_word(candidates)
	_recent.append(_target)
	if _recent.size() > maxi(1, _pool.size() / 2):
		_recent.pop_front()
	_direction = 1 - _direction
	var options: Array = [_target]
	for id in _distractors(_target, _fish.size() - 1):
		options.append(id)
	options.shuffle()
	var word: Dictionary = WordBank.get_word(_target)
	if _direction == 0:
		_question.text = "What does \"%s\" mean?" % str(word.get("akeanon", ""))
	else:
		_question.text = "Which word means \"%s\"?" % _short_gloss(str(word.get("gloss", "")))
	for i in _fish.size():
		var f: Fish = _fish[i]
		var id: String = options[i]
		var w: Dictionary = WordBank.get_word(id)
		f.word_id = id
		f.text = _short_gloss(str(w.get("gloss", ""))) if _direction == 0 else str(w.get("akeanon", ""))
		f.set_kind(randi() % FISH_KINDS)
		f.reset(Vector2(_water.size.x, _water.size.y - SEABED_CLEAR), randf_range(0.1, 0.7))
	_feedback.text = ""
	_asked += 1
	_locked = false

## Wrong answers: shown text must differ from the right one's. Tier 3 prefers
## look-alikes (same word type, or same first letter).
func _distractors(target: String, count: int) -> Array:
	var tw: Dictionary = WordBank.get_word(target)
	var shown := {_label_for(target): true}
	var others: Array = _answers_pool.filter(func(id): return id != target)
	others.shuffle()
	if _tier.get("similar", false):
		var cat: String = str(tw.get("category", ""))
		var first: String = str(tw.get("akeanon", " ")).left(1).to_lower()
		others.sort_custom(func(a, b): return _likeness(a, cat, first) > _likeness(b, cat, first))
	var out: Array = []
	for id in others:
		if out.size() >= count:
			break
		var lbl: String = _label_for(id)
		if shown.has(lbl):
			continue
		shown[lbl] = true
		out.append(id)
	return out

func _likeness(id: String, cat: String, first: String) -> int:
	var w: Dictionary = WordBank.get_word(id)
	var score := 0
	if not cat.is_empty() and str(w.get("category", "")) == cat:
		score += 2
	if str(w.get("akeanon", " ")).left(1).to_lower() == first:
		score += 1
	return score

func _label_for(id: String) -> String:
	var w: Dictionary = WordBank.get_word(id)
	return _short_gloss(str(w.get("gloss", ""))) if _direction == 0 else str(w.get("akeanon", ""))

## "Shore / shore" -> "shore"; "but (rather), instead" -> "but"; keeps labels short.
func _short_gloss(g: String) -> String:
	var s := g
	var paren := s.find("(")
	if paren > 0:
		s = s.left(paren)
	for sep in ["/", ",", ";"]:
		var i := s.find(sep)
		if i > 0:
			s = s.left(i)
	s = s.strip_edges().to_lower()
	return s if not s.is_empty() else g.strip_edges()

# --- answering ----------------------------------------------------------------------

func _on_fish_tapped(f: Fish) -> void:
	if _locked or not _running:
		return
	_locked = true
	var session := _session
	var word: Dictionary = WordBank.get_word(_target)
	var pair := "%s = %s" % [str(word.get("akeanon", "")), _short_gloss(str(word.get("gloss", "")))]
	GameState.expose_word(_target)
	if f.word_id == _target:
		_right += 1
		_streak += 1
		_best_streak = maxi(_best_streak, _streak)
		_score += POINTS * _multiplier()
		_time_left = minf(_time_left + RIGHT_BONUS_SECONDS, _time_total)
		GameState.adjust_mastery(_target, 1)
		_catch_effects(f, POINTS * _multiplier())
		f.catch()
		_feedback.text = "Insakto! " + pair
		_feedback.add_theme_color_override("font_color", Accessibility.success_color())
		_refresh_hud()
		await get_tree().create_timer(NEXT_DELAY).timeout
	else:
		_streak = 0
		_time_left = maxf(_time_left - WRONG_PENALTY_SECONDS, 0.0)
		_missed.append(pair)
		f.flash(Accessibility.error_color())
		for other: Fish in _fish:
			if other.word_id == _target:
				other.highlight(Accessibility.success_color())
		_feedback.text = "Not quite. It's " + pair
		_feedback.add_theme_color_override("font_color", Accessibility.error_color())
		_refresh_hud()
		await get_tree().create_timer(WRONG_SHOW).timeout
	if session == _session and _running:
		_next_question()

## "+points" floating up from the fish, and a ring of bubbles where it was.
func _catch_effects(f: Fish, points: int) -> void:
	var centre: Vector2 = f.position + f.size / 2.0
	var burst := Burst.new()
	burst.position = centre
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_water.add_child(burst)
	var pop := Label.new()
	pop.text = "+%d" % points
	pop.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XL)
	pop.add_theme_color_override("font_color", Color("fff4dc"))
	pop.add_theme_color_override("font_outline_color", Color("2a2430"))
	pop.add_theme_constant_override("outline_size", 5)
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.position = centre - Vector2(16, 30)
	_water.add_child(pop)
	var tw := pop.create_tween()
	tw.tween_property(pop, "position:y", pop.position.y - 34.0, 0.8)
	tw.parallel().tween_property(pop, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.tween_callback(pop.queue_free)

func _multiplier() -> int:
	return mini(1 + _streak / COMBO_STEP, COMBO_MAX)

# --- time, end -------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _running:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_time_left = 0.0
		_end_round()
	var factor: float = 0.0 if (_tier.get("freeze_on_touch", false) and _finger_down) else 1.0
	for f: Fish in _fish:
		f.swim(delta * factor, float(_tier["speed"]), _water.size)
	_bubbles.queue_redraw()
	_refresh_hud()

func _end_round() -> void:
	_running = false
	_locked = true
	var passed: bool = _right >= _pass_count
	var lines: Array[String] = []
	lines.append("Score %d   ·   %d right of %d   ·   best combo %d" % [_score, _right, _asked, _best_streak])
	lines.append("You caught enough words!" if passed else "Catch %d right to pass. Try again soon." % _pass_count)
	if not _missed.is_empty():
		lines.append("")
		lines.append("Words to remember:")
		var seen := {}
		for m: String in _missed:
			if not seen.has(m) and seen.size() < 6:
				seen[m] = true
				lines.append("   " + m)
	_results_text.text = "\n".join(lines)
	_play.visible = false
	_results.visible = true
	_results.set_meta("passed", passed)
	(_results.get_node("Continue") as Button).grab_focus()

func _emit_resolved(passed: bool) -> void:
	resolved.emit(passed)

func _refresh_hud() -> void:
	_timer_label.text = "%d s" % ceili(_time_left)
	_timer_bar.value = _time_left / maxf(_time_total, 1.0) * 100.0
	var mult := _multiplier()
	_score_label.text = "Score %d%s" % [_score, ("   x%d" % mult) if mult > 1 else ""]

# --- input -----------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if _results.visible and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_on_continue()
		get_viewport().set_input_as_handled()
	elif _running and event.keycode >= KEY_1 and event.keycode < KEY_1 + _fish.size():
		_on_fish_tapped(_fish[event.keycode - KEY_1])  # lanes top to bottom
		get_viewport().set_input_as_handled()

## Easy tier: the fish hold still while a finger (or the mouse) is on the water.
func _on_water_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		_finger_down = event.pressed

func _on_continue() -> void:
	if not _results.visible:
		return
	_results.visible = false
	_emit_resolved(bool(_results.get_meta("passed", false)))

# --- layout ----------------------------------------------------------------------------

func _build_layout() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	add_child(margin)
	var stack := Control.new()
	margin.add_child(stack)

	_play = VBoxContainer.new()
	_play.set_anchors_preset(Control.PRESET_FULL_RECT)
	_play.add_theme_constant_override("separation", 4)
	stack.add_child(_play)
	# Question on its own line; time, score and the time bar on the row under it,
	# on the left (the top-right corner is where the HUD's buttons sit).
	_question = Label.new()
	_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_question.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XL)
	_question.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	_play.add_child(_question)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_play.add_child(row)
	_timer_label = Label.new()
	_timer_label.custom_minimum_size = Vector2(44, 0)
	_timer_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	_timer_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	row.add_child(_timer_label)
	_score_label = Label.new()
	_score_label.custom_minimum_size = Vector2(110, 0)
	_score_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	_score_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	row.add_child(_score_label)
	_timer_bar = ProgressBar.new()
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size = Vector2(0, 8)
	_timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timer_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_timer_bar)

	_water = Control.new()
	_water.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_water.clip_contents = true
	_water.mouse_filter = Control.MOUSE_FILTER_PASS
	_water.gui_input.connect(_on_water_input)
	_play.add_child(_water)
	var backdrop := Backdrop.new()
	backdrop.fish = _fish
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_water.add_child(backdrop)
	# The team's water tile, faint, for ripples over the depth shading.
	var ripples := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load(WATER_SHEET)
	atlas.region = Rect2(WATER_CELL * 16, Vector2(16, 16))
	ripples.texture = atlas
	ripples.stretch_mode = TextureRect.STRETCH_TILE
	ripples.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ripples.modulate = Color(1, 1, 1, 0.16)
	ripples.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ripples.set_anchors_preset(Control.PRESET_FULL_RECT)
	_water.add_child(ripples)
	_bubbles = Bubbles.new()
	_bubbles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubbles.set_anchors_preset(Control.PRESET_FULL_RECT)
	_water.add_child(_bubbles)

	_feedback = Label.new()
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	_feedback.custom_minimum_size = Vector2(0, 22)
	_play.add_child(_feedback)

	_results = VBoxContainer.new()
	_results.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results.alignment = BoxContainer.ALIGNMENT_CENTER
	_results.add_theme_constant_override("separation", 10)
	_results.visible = false
	stack.add_child(_results)
	var title := Label.new()
	title.text = "Time!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XXL)
	title.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	_results.add_child(title)
	_results_text = Label.new()
	_results_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_text.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	_results_text.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	_results.add_child(_results_text)
	var cont := Button.new()
	cont.name = "Continue"
	cont.text = "Continue"
	cont.custom_minimum_size = Vector2(160, 0)
	cont.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UIThemeApplier.apply_button_theme(cont, "primary")
	cont.pressed.connect(func():
		AudioManager.play_sfx("menu_click")
		_on_continue())
	_results.add_child(cont)

## One fish per lane, top to bottom; alternate lanes swim the other way.
func _build_fish(count: int) -> void:
	for f in _fish:
		f.queue_free()
	_fish.clear()
	for i in count:
		var f := Fish.new()
		f.lane = i
		f.lanes = count
		f.dir = 1 if i % 2 == 0 else -1
		f.kind = i % FISH_KINDS
		f.size = FISH_SIZE
		f.tapped.connect(_on_fish_tapped)
		_water.add_child(f)
		_fish.append(f)

func _valid_ids(raw_ids: Array) -> Array:
	var out: Array = []
	for raw in raw_ids:
		var id: String = str(raw).strip_edges()
		if id.is_empty() or out.has(id):
			continue
		if WordBank.get_word(id).is_empty():
			push_warning("Fishing: unknown word id '%s' dropped." % id)
			continue
		out.append(id)
	return out

# --- fish --------------------------------------------------------------------------------

## A fish with its answer written on its body, built in five parts:
##   tail | padding | word | padding | head
## Tail and head are the sprite as drawn (columns before BAND_FROM, from BAND_TO
## on). The middle is one column of the label band stretched to exactly the
## word's width plus PAD on each side, so every word sits centred with the same
## space before the gill line and after the tail. Tap anywhere on it.
class Fish extends Control:
	signal tapped(fish)
	const SHEET := preload("res://assets/sprites/minigames/fishing_fish.png")
	const CELL := Vector2(32, 20)
	## The label band in sprite pixels: columns BAND_FROM..BAND_TO (exclusive, the
	## gill line), rows centred on BAND_MID_Y; BAND_COL is the plain column that
	## stretches. Must match art_requests/tools/gen_fish_sprites.gd.txt (BAND_*, GILL_X).
	const BAND_FROM := 8
	const BAND_TO := 23
	const BAND_COL := 13       # plain body: behind the fins, in front of the tail
	## Fins drawn back over the middle, centred (sprite rects: x, y, w, h).
	const DORSAL := Rect2(14, 0, 6, 6)
	const BELLY_FIN := Rect2(15, 14, 4, 6)
	const BAND_MID_Y := 10.0
	## Space between the word and the tail / the gill line, in sprite pixels.
	const PAD := 2.0
	## Shortest middle, in sprite pixels, so a one-letter word still looks like a fish.
	const MIN_MIDDLE := 8.0
	## Seconds per tail frame.
	const FRAME_TIME := 0.22
	const TEXT_FILL := Color("2a2430")

	var word_id: String = ""
	var text: String = "":
		set(v):
			text = v
			queue_redraw()
	var lane: int = 0
	var lanes: int = 3
	var dir: int = 1
	var kind: int = 0              # row in SHEET
	var px_scale: float = 3.0
	var _middle_px: float = 0.0    # width of the pad|word|pad part on screen
	var _base_y: float = 0.0       # lane position; swim() bobs around it
	var _font_size: int = 14
	var _t: float = 0.0
	var _flash: Color = Color(0, 0, 0, 0)
	var _ring: Color = Color(0, 0, 0, 0)
	var _caught: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	## A new kind each question, so the lanes don't always hold the same fish.
	func set_kind(k: int) -> void:
		kind = k
		queue_redraw()

	## Sizes the fish for its lane and its word, and puts it at "at" (0..1) across.
	func reset(area: Vector2, at: float) -> void:
		_caught = false
		modulate = Color.WHITE
		_flash = Color(0, 0, 0, 0)
		_ring = Color(0, 0, 0, 0)
		var lane_h: float = area.y / maxf(lanes, 1)
		# Biggest pixel scale the lane fits (4x with two lanes), text a size up with it.
		px_scale = 2.0
		for s: float in [4.0, 3.0, 2.5]:
			if lane_h >= CELL.y * s + 4.0:
				px_scale = s
				break
		_font_size = UIThemeApplier.FONT_SIZE_XL if px_scale >= 4.0 \
				else (UIThemeApplier.FONT_SIZE_M if px_scale >= 3.0 \
				else (UIThemeApplier.FONT_SIZE_S if px_scale >= 2.5 else UIThemeApplier.FONT_SIZE_XS))
		var tw: float = get_theme_default_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
		_middle_px = maxf(tw + PAD * 2.0 * px_scale, MIN_MIDDLE * px_scale)
		size = Vector2((BAND_FROM + (CELL.x - BAND_TO)) * px_scale + _middle_px, CELL.y * px_scale)
		position = Vector2(area.x * at, lane * lane_h + (lane_h - size.y) / 2.0)
		_base_y = position.y
		queue_redraw()

	func swim(delta: float, speed: float, area: Vector2) -> void:
		_t += delta
		if _caught:
			return
		position.x += dir * speed * delta
		position.y = _base_y + sin(_t * 2.2 + lane * 1.7) * 2.5  # gentle bob
		if dir > 0 and position.x > area.x:
			position.x = -size.x
		elif dir < 0 and position.x < -size.x:
			position.x = area.x
		queue_redraw()

	func catch() -> void:
		_caught = true
		var tw := create_tween()
		tw.tween_property(self, "position:y", position.y - 40.0, 0.4)
		tw.parallel().tween_property(self, "modulate:a", 0.0, 0.4)

	func flash(c: Color) -> void:
		_flash = c
		queue_redraw()

	func highlight(c: Color) -> void:
		_ring = c
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		var press: bool = (event is InputEventScreenTouch and event.pressed) \
				or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
				and event.device != InputEvent.DEVICE_ID_EMULATION)
		if press and not _caught:
			tapped.emit(self)
			accept_event()

	func _draw() -> void:
		if _ring.a > 0.0:
			# Soft pulsing glow behind the right answer: three nested ellipses.
			var pulse := 0.75 + 0.25 * sin(_t * 8.0)
			var c := size / 2.0
			for i in 3:
				var k := 1.0 - i * 0.18
				var pts := PackedVector2Array()
				for j in 24:
					var a := TAU * j / 24.0
					pts.append(c + Vector2(cos(a) * size.x * 0.62 * k, sin(a) * size.y * 0.75 * k))
				draw_colored_polygon(pts, Color(_ring.lightened(0.3), 0.16 * pulse))
		var s := px_scale
		var row_y: float = kind * CELL.y
		var fx: float = (int(_t / FRAME_TIME) % 2) * CELL.x
		var tint: Color = Color.WHITE if _flash.a == 0.0 else _flash.lerp(Color.WHITE, 0.35)
		# Sprite faces right; mirror the whole fish for ones swimming left.
		if dir < 0:
			draw_set_transform(Vector2(size.x, 0.0), 0.0, Vector2(-1, 1))
		var tail_w: float = BAND_FROM * s
		var head_w: float = (CELL.x - BAND_TO) * s
		# tail
		draw_texture_rect_region(SHEET, Rect2(0, 0, tail_w, CELL.y * s),
				Rect2(fx, row_y, BAND_FROM, CELL.y), tint)
		# padding + word + padding: one band column, stretched
		draw_texture_rect_region(SHEET, Rect2(tail_w, 0, _middle_px, CELL.y * s),
				Rect2(fx + BAND_COL, row_y, 1, CELL.y), tint)
		# fins, centred over the word
		var centre_x: float = tail_w + _middle_px / 2.0
		for fin_rect: Rect2 in [DORSAL, BELLY_FIN]:
			draw_texture_rect_region(SHEET,
					Rect2(centre_x - fin_rect.size.x * s / 2.0, fin_rect.position.y * s, fin_rect.size.x * s, fin_rect.size.y * s),
					Rect2(fx + fin_rect.position.x, row_y + fin_rect.position.y, fin_rect.size.x, fin_rect.size.y), tint)
		# head (gill line, eye, snout)
		draw_texture_rect_region(SHEET, Rect2(tail_w + _middle_px, 0, head_w, CELL.y * s),
				Rect2(fx + BAND_TO, row_y, CELL.x - BAND_TO, CELL.y), tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# The word, centred on the label band, never mirrored.
		var font := get_theme_default_font()
		var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
		var mid: float = BAND_FROM * s + _middle_px / 2.0
		if dir < 0:
			mid = size.x - mid
		var base := Vector2(mid - tw / 2.0, BAND_MID_Y * s + _font_size * 0.35)
		draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, TEXT_FILL)

## The water behind the fish: lighter near the surface, deeper blue below, slow
## light rays from above, drifting specks, the pixel seabed along the bottom
## (fishing_seabed.png, tinted for depth) and a soft shadow under each fish.
class Backdrop extends Control:
	const SEABED := preload("res://assets/sprites/minigames/fishing_seabed.png")
	const SEABED_SCALE := 2.0
	const TOP := Color(0.42, 0.68, 0.86)
	const BOTTOM := Color(0.10, 0.27, 0.48)
	const BANDS := 14
	var fish: Array = []
	var _t: float = 0.0

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		# Depth: stepped bands, pixel-art style rather than a smooth gradient.
		for i in BANDS:
			var y0 := h * i / BANDS
			draw_rect(Rect2(0, y0, w, h / BANDS + 1.0), TOP.lerp(BOTTOM, float(i) / (BANDS - 1)))
		# Light rays from the surface, swaying slowly.
		for i in 5:
			var x := fposmod(i * w * 0.23 + sin(_t * 0.3 + i) * 30.0, w + 120.0) - 60.0
			var spread := 26.0 + (i % 3) * 14.0
			var ray := PackedVector2Array([Vector2(x, 0), Vector2(x + spread, 0),
					Vector2(x + spread * 2.4 + 60.0, h), Vector2(x + 60.0, h)])
			draw_colored_polygon(ray, Color(1, 1, 1, 0.05 + 0.02 * sin(_t * 0.8 + i)))
		# Drifting specks.
		for i in 22:
			var sx := fposmod(i * 97.0 + _t * (4.0 + i % 4), w)
			var sy := fposmod(i * 53.0 + sin(_t * 0.5 + i) * 6.0, h - 30.0)
			draw_rect(Rect2(sx, sy, 2, 2), Color(1, 1, 1, 0.18))
		# Seabed, tiled along the bottom.
		var bed_h := SEABED.get_height() * SEABED_SCALE
		var bed_y := h - bed_h
		draw_set_transform(Vector2(0, bed_y), 0.0, Vector2(SEABED_SCALE, SEABED_SCALE))
		draw_texture_rect(SEABED, Rect2(0, 0, w / SEABED_SCALE + 1.0, SEABED.get_height()), true, Color(0.72, 0.84, 0.95))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Shadows on the sand, smaller and fainter for fish higher up.
		for f in fish:
			if not is_instance_valid(f) or f.modulate.a < 0.5:
				continue
			var cx: float = f.position.x + f.size.x / 2.0
			var height: float = clampf((bed_y - (f.position.y + f.size.y)) / maxf(h, 1.0), 0.0, 1.0)
			var rx: float = f.size.x * 0.32 * (1.0 - height * 0.5)
			var pts := PackedVector2Array()
			for k in 16:
				var a := TAU * k / 16.0
				pts.append(Vector2(cx + cos(a) * rx, bed_y + bed_h * 0.62 + sin(a) * 3.0))
			draw_colored_polygon(pts, Color(0.05, 0.1, 0.2, 0.28 * (1.0 - height * 0.7)))

## A ring of bubbles where a fish was caught; frees itself.
class Burst extends Control:
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t > 0.6:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := _t / 0.6
		for i in 8:
			var a := TAU * i / 8.0 + 0.3
			var p := Vector2(cos(a), sin(a) * 0.7) * (8.0 + k * 34.0) + Vector2(0, -k * 14.0)
			draw_arc(p, 2.5 + (i % 3), 0.0, TAU, 10, Color(1, 1, 1, 0.8 * (1.0 - k)), 1.5)

## Bubbles rising through the water.
class Bubbles extends Control:
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta

	func _draw() -> void:
		for i in 14:
			var x := fposmod(i * 73.0, maxf(size.x, 1.0))
			var y := size.y - fposmod(_t * (14.0 + i % 5 * 4.0) + i * 41.0, size.y + 20.0)
			draw_arc(Vector2(x + sin(_t * 2.0 + i) * 3.0, y), 2.0 + i % 3, 0.0, TAU, 10, Color(1, 1, 1, 0.45), 1.0)
