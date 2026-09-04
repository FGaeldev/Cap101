# puzzle_panel.gd — shared MCQ presentation panel, two independent callers.
#
# MODE_SINGLE: examinable_object.gd's world-object fill-blank puzzle
# (word_id vs distractor word_ids, local on_solve callback). Pre-existing,
# unchanged behavior — do not alter open_single()/_on_choice()'s contract,
# examinable_object.gd depends on it exactly as before.
#
# MODE_CHALLENGE: Comp_Dialogue.gd's challenge_gate line type (TDD §5) via
# DialogueUI.challenge_gate_entered(challenge_id) (TDD §6.5). New — this is
# the "puzzle_panel wiring" Roadmap Phase A item. Pulls question/choices
# straight from ChallengeManager.challenges (mcq only; fill_blank challenge
# data exists in the schema but has no renderer here yet — TDD §6.5 backlog).
# Resolution goes through ChallengeManager.attempt(), which already owns
# first_try tracking, reward granting, and the fail-twice Dictionary-open
# rule — this panel never touches GameState directly, only reads/renders.
# Comp_Dialogue.gd resumes the suspended dialogue itself by listening to
# ChallengeManager.challenge_passed — this panel doesn't call back into it.
extends CanvasLayer

@onready var panel:              PanelContainer = $Panel
@onready var sentence_box:       PanelContainer = $Panel/VBox/SentenceBox
@onready var sentence_label:     Label          = $Panel/VBox/SentenceBox/SentenceLabel
@onready var choices_box:        HBoxContainer  = $Panel/VBox/ChoicesBox
@onready var feedback_label:     Label          = $Panel/VBox/FeedbackLabel
@onready var hint_label:         Label          = $Panel/VBox/HintLabel
@onready var hint_feedback_label: Label         = $Panel/VBox/HintFeedbackLabel
@onready var hint_button:        Button         = $Panel/VBox/HintButton

enum Mode { SINGLE, CHALLENGE }

var _choice_btns: Array   = []
var _mode: int            = Mode.SINGLE
var _correct_id: String   = ""   # MODE_SINGLE: word_id
var _correct_index: int   = -1   # MODE_CHALLENGE: choice index
var _active_challenge_id: String = ""
var _on_solve_callback    = null
var _showing_feedback: bool = false
var _feedback_timer: float  = 0.0
const FEEDBACK_DURATION     = 1.2

func _ready() -> void:
	add_to_group("puzzle_panel")
	visible = false
	for btn in choices_box.get_children():
		_choice_btns.append(btn)
	_apply_style()
	hint_button.pressed.connect(_on_hint_button_pressed)
	# Register-on-ready, call-through-autoload (TDD §2 pattern) — this panel
	# is the "whatever owns puzzle_panel" the challenge_gate doc comment in
	# Comp_Dialogue.gd points at.
	DialogueUI.challenge_gate_entered.connect(_on_challenge_gate_entered)

# --- MODE_SINGLE: examinable_object.gd's fill-blank flow (unchanged) ---

func open_single(
	template: String,
	answer_id: String,
	distractor_ids: Array,
	on_solve: Callable
) -> void:
	_mode              = Mode.SINGLE
	_correct_id        = answer_id
	_on_solve_callback = on_solve
	_showing_feedback  = false
	feedback_label.text = ""
	hint_feedback_label.visible = false
	hint_button.visible = false
	hint_label.visible = true

	sentence_box.visible = true
	sentence_label.text = template.replace("___", "[ _______ ]")

	var choices = ([answer_id] + distractor_ids)
	choices.shuffle()

	for i in range(_choice_btns.size()):
		var btn: Button = _choice_btns[i]
		if i < choices.size():
			var word_data = WordBank.get_word(choices[i])
			btn.text     = word_data.get("akeanon", "???")
			btn.visible  = true
			btn.disabled = false
			btn.set_meta("removed", false)
			_reset_btn(btn)
			_disconnect_choice_handlers(btn)
			btn.pressed.connect(_on_choice.bind(choices[i], btn))
		else:
			btn.visible = false

	visible = true

func _on_choice(word_id: String, btn: Button) -> void:
	if _showing_feedback: return

	if word_id == _correct_id:
		_show_correct_feedback(btn)
	else:
		_show_wrong_feedback(btn, "")
		await get_tree().create_timer(0.4).timeout
		for b in _choice_btns:
			if b.visible and not b.get_meta("removed", false):
				b.disabled = false
				_reset_btn(b)
		feedback_label.text = ""

# --- MODE_CHALLENGE: ChallengeManager-driven mcq gate ---

func _on_challenge_gate_entered(challenge_id: String) -> void:
	open_challenge(challenge_id)

func open_challenge(challenge_id: String) -> void:
	var data: Dictionary = ChallengeManager.challenges.get(challenge_id, {})
	if data.is_empty():
		push_error("puzzle_panel: unknown challenge_id '%s'" % challenge_id)
		return

	_mode = Mode.CHALLENGE
	_active_challenge_id = challenge_id
	_correct_index = data.get("correct_index", -1)
	_on_solve_callback = null
	_showing_feedback = false
	feedback_label.text = ""
	hint_feedback_label.visible = false
	hint_feedback_label.text = ""
	hint_label.visible = false   # static "Pilia ro kueang!" prompt is SINGLE-mode only

	sentence_box.visible = true
	sentence_label.text = data.get("question", "")

	var choices: Array = data.get("choices", [])
	for i in range(_choice_btns.size()):
		var btn: Button = _choice_btns[i]
		if i < choices.size():
			btn.text     = choices[i]
			btn.visible  = true
			btn.disabled = false
			btn.set_meta("removed", false)
			_reset_btn(btn)
			_disconnect_choice_handlers(btn)
			btn.pressed.connect(_on_challenge_choice.bind(i, btn))
		else:
			btn.visible = false

	_refresh_hint_button()
	visible = true

func _on_challenge_choice(idx: int, btn: Button) -> void:
	if _showing_feedback: return
	var result: Dictionary = ChallengeManager.attempt(_active_challenge_id, idx)

	if result.get("correct", false):
		hint_feedback_label.visible = false
		hint_button.visible = false
		_show_correct_feedback(btn)
		return

	_show_wrong_feedback(btn, result.get("hint", ""))
	await get_tree().create_timer(0.4).timeout
	for b in _choice_btns:
		if b.visible and not b.get_meta("removed", false):
			b.disabled = false
			_reset_btn(b)
	feedback_label.text = ""
	_refresh_hint_button()   # a fail-twice gate opens Dictionary over this panel; button state
							  # still needs to be correct underneath for when the player returns

## Rose Hint Token spend. ChallengeManager owns eligibility (token balance,
## choice-count floor) and picks which index to eliminate — this only
## renders the result. Button visibility is re-checked after every wrong
## answer (_refresh_hint_button) since GameState.rose_hint_tokens can hit 0
## mid-challenge.
func _on_hint_button_pressed() -> void:
	var removed_idx: int = ChallengeManager.remove_wrong_option(_active_challenge_id)
	if removed_idx == -1:
		return
	if removed_idx < _choice_btns.size():
		var btn: Button = _choice_btns[removed_idx]
		btn.set_meta("removed", true)
		btn.disabled = true
		_apply_removed_style(btn)
	_refresh_hint_button()

func _refresh_hint_button() -> void:
	hint_button.visible = _mode == Mode.CHALLENGE and GameState.rose_hint_tokens > 0
	hint_button.text = "Use Rose Hint Token (%d)" % GameState.rose_hint_tokens

# --- Shared feedback rendering ---

func _show_correct_feedback(btn: Button) -> void:
	feedback_label.text = "Husto! Maayo gid!"
	feedback_label.add_theme_color_override("font_color", UIThemeApplier.COLOR_SUCCESS)
	_flash_btn(btn, UIThemeApplier.COLOR_SUCCESS)
	_show_congrats_popup(feedback_label.text)
	for b in _choice_btns:
		b.disabled = true
	_showing_feedback = true
	_feedback_timer   = 0.0

## hint_text: "" in MODE_SINGLE (no per-attempt hint data there), populated
## from ChallengeManager.attempt()'s hint_on_wrong in MODE_CHALLENGE.
func _show_wrong_feedback(btn: Button, hint_text: String) -> void:
	feedback_label.text = "Mali, sulayi liwat!"
	feedback_label.add_theme_color_override("font_color", UIThemeApplier.COLOR_ERROR)
	_flash_btn(btn, UIThemeApplier.COLOR_ERROR)
	if not hint_text.is_empty():
		hint_feedback_label.text = hint_text
		hint_feedback_label.visible = true

## small celebratory popup, built at runtime (no new .tscn — same pattern
## main_menu.gd uses for its bg ColorRects). Fades in over the panel,
## reuses whatever text feedback_label already shows -- no new Akeanon
## copy invented here, just makes the existing "correct" moment pop more.
## Times out inside FEEDBACK_DURATION (1.2s) so it's gone before the panel
## itself hides -- 0.15 in + 0.65 hold + 0.3 out = 1.1s total.
func _show_congrats_popup(text: String) -> void:
	var popup := PanelContainer.new()
	popup.add_theme_stylebox_override("panel", UIThemeApplier.make_panel_style(16))
	popup.set_anchors_preset(Control.PRESET_CENTER_TOP)
	popup.position.y = 30
	popup.modulate.a = 0.0
	add_child(popup)

	var lbl := Label.new()
	lbl.text = "★ %s ★" % text
	lbl.add_theme_color_override("font_color", UIThemeApplier.COLOR_SUCCESS)
	lbl.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XXL)
	UIThemeApplier.apply_display_font(lbl)
	popup.add_child(lbl)

	var tw := create_tween()
	tw.tween_property(popup, "modulate:a", 1.0, 0.15)
	tw.tween_interval(0.65)
	tw.tween_property(popup, "modulate:a", 0.0, 0.3)
	tw.tween_callback(popup.queue_free)

func _disconnect_choice_handlers(btn: Button) -> void:
	if btn.pressed.is_connected(_on_choice):
		btn.pressed.disconnect(_on_choice)
	if btn.pressed.is_connected(_on_challenge_choice):
		btn.pressed.disconnect(_on_challenge_choice)

func _process(delta: float) -> void:
	if not _showing_feedback: return
	_feedback_timer += delta
	if _feedback_timer >= FEEDBACK_DURATION:
		_showing_feedback = false
		visible = false
		if _mode == Mode.SINGLE and _on_solve_callback:
			_on_solve_callback.call()
		# MODE_CHALLENGE: no local callback needed -- ChallengeManager's
		# challenge_passed signal already resumed the suspended
		# DialogueComponent (Comp_Dialogue.gd::_on_challenge_passed).

# tint only, texture never touches. modulate w/ half alpha = color shows thru
# without swapping button's normal look. (prior version swapped stylebox to
# a panel texture here -- that was the bug, button skin changed on answer.)
func _flash_btn(btn: Button, color: Color) -> void:
	btn.modulate = Color(color.r, color.g, color.b, 0.5)
	btn.add_theme_color_override("font_color_disabled", UIThemeApplier.TEXT_DEFAULT)

## Distinct from _flash_btn — a removed (hint-token-eliminated) choice needs
## to stay visually "gone", not flash red/green like an answered choice.
## same tint-only approach, dimmed via TEXT_DISABLED at half alpha.
func _apply_removed_style(btn: Button) -> void:
	var c: Color = UIThemeApplier.TEXT_DISABLED
	btn.modulate = Color(c.r, c.g, c.b, 0.5)
	btn.add_theme_color_override("font_color_disabled", UIThemeApplier.TEXT_DEFAULT)

func _reset_btn(btn: Button) -> void:
	btn.modulate = Color.WHITE  # clear flash/removed tint from _flash_btn / _apply_removed_style
	UIThemeApplier.apply_button_theme(btn, "primary")

func _apply_style() -> void:
	panel.custom_minimum_size = Vector2(340, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER)

	# Was: panel.tres (never existed in repo) -> flat StyleBoxFlat fallback,
	# so this always rendered as a flat rounded-rect, not book chrome.
	# Now uses puzzel.png, the dedicated main-panel art (not the generic
	# placeholder make_panel_style() still uses for SentenceBox below).
	panel.add_theme_stylebox_override("panel", UIThemeApplier.make_puzzle_panel_style())

	hint_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	hint_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_L)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Nested sub-panel — smaller content_margin (8) so the inset doesn't
	# double up against the outer panel's own 14px margin.
	sentence_box.add_theme_stylebox_override("panel", UIThemeApplier.make_panel_style(8))
	sentence_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	sentence_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_L)
	sentence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sentence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	choices_box.alignment = BoxContainer.ALIGNMENT_CENTER
	for btn in _choice_btns:
		btn.custom_minimum_size = Vector2(96, 34)
		btn.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)

	feedback_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	hint_feedback_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	hint_feedback_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	hint_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	UIThemeApplier.apply_button_theme(hint_button, "secondary")
	hint_button.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
