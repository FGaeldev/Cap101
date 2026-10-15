# phrase_builder.gd -- "tap the words in the correct order" dialogue UI.
#
# Driven by a dialogue line of type "phrase_builder":
#   {
#     "type": "phrase_builder",
#     "prompt": "Can you repeat it?",
#     "choices": ["mayad", "nga", "agahon", "ikaw/ka"],   # word bank (incl. distractors)
#     "answer":  ["mayad", "nga", "agahon"],              # correct words, in order
#     "success": 6,                                       # next line index on correct
#     "failure": 7                                        # next line index on wrong
#   }
#
# Ownership: this panel only renders and reports. It emits `resolved(passed)`;
# DialogueUI forwards that to the owning DialogueComponent, which picks the
# success/failure line index (same register-and-call-through pattern as
# puzzle_panel). It never touches GameState, rapport or patience.
#
# Instantiated lazily by DialogueUI.show_phrase_builder() as a sibling of
# DialogueRoot (UILayer), so no .tscn edits to Game.tscn are required.
#
# Words are tracked by bank INDEX, not by string, so a bank that contains the
# same word twice still works and a placed word can be returned to its own slot.
extends PanelContainer

## Emitted once, after the feedback hold, with whether the order was correct.
signal resolved(passed: bool)

## Seconds the correct/wrong feedback stays visible before resolving.
const FEEDBACK_HOLD: float = 1.2
## Bank layout: banks up to BANK_SMALL_MAX words use 2 columns, larger use 3.
const BANK_SMALL_MAX: int = 4
const BANK_COLUMNS_SMALL: int = 2
const BANK_COLUMNS_LARGE: int = 3
## Minimum height (px) of a bank word button; grows past this to fill.
const BANK_BTN_MIN_HEIGHT: float = 24.0
## Max reshuffles to avoid presenting the bank already in answer order.
const MAX_RESHUFFLES: int = 8

var _words: Array = []              # bank strings, in SHUFFLED display order
var _answer: Array = []             # correct words, in order
var _bank_btns: Array = []          # Button per bank index (same order as _words)
var _placed: Array = []             # bank indices in the order the player tapped them
var _locked: bool = false           # true while feedback shows; ignores input

var _prompt_label: Label
var _slot_flow: HFlowContainer
var _slot_hint: Label
var _bank_grid: GridContainer
var _feedback_label: Label
var _clear_btn: Button
var _check_btn: Button

func _ready() -> void:
	# Same footprint as DialogueRoot (bottom 45% of the viewport) so the box
	# swap reads as the dialogue panel changing content, not a new popup.
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.55
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_right = 0.0
	offset_top = 0.0
	offset_bottom = 0.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UIThemeApplier.make_dialogue_style())
	_build_layout()
	visible = false

# --- public API ----------------------------------------------------------------

## Show the builder for one phrase_builder line. Safe to call repeatedly.
func open(line: Dictionary) -> void:
	_locked = false
	_placed.clear()
	_answer = _to_string_array(line.get("answer", []))
	var choices: Array = _to_string_array(line.get("choices", []))

	# Bad data must never softlock the dialogue: report and resolve as a pass
	# (no-punishment rule) so the story keeps moving.
	if _answer.is_empty() or not _answer_in_choices(_answer, choices):
		push_error("PhraseBuilder: 'answer' empty or not a subset of 'choices' (%s / %s)" % [_answer, choices])
		call_deferred("_emit_resolved", true)
		return

	_words = _shuffled_bank(choices, _answer)
	_prompt_label.text = str(line.get("prompt", ""))
	_feedback_label.text = ""
	_rebuild_bank()
	_refresh()
	visible = true

## Hide without resolving (dialogue torn down / ended elsewhere).
func close() -> void:
	_locked = true
	visible = false

# --- layout --------------------------------------------------------------------

func _build_layout() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 3)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	_prompt_label = Label.new()
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	_prompt_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	vbox.add_child(_prompt_label)

	# Answer line: outlined box holding the player's picks, in order.
	var slot_panel := PanelContainer.new()
	slot_panel.custom_minimum_size = Vector2(0, 22)
	slot_panel.add_theme_stylebox_override("panel", _make_slot_style())
	vbox.add_child(slot_panel)

	_slot_flow = HFlowContainer.new()
	_slot_flow.add_theme_constant_override("h_separation", 3)
	_slot_flow.add_theme_constant_override("v_separation", 3)
	slot_panel.add_child(_slot_flow)

	_slot_hint = Label.new()
	_slot_hint.text = "Tap the words in order"
	_slot_hint.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	_slot_hint.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	slot_panel.add_child(_slot_hint)

	# Word bank.
	# Grid (not flow) so word buttons stretch evenly to fill all free space.
	_bank_grid = GridContainer.new()
	_bank_grid.add_theme_constant_override("h_separation", 3)
	_bank_grid.add_theme_constant_override("v_separation", 3)
	_bank_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_bank_grid)

	# Feedback shares the action row to save a row of vertical space.
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	vbox.add_child(actions)

	_feedback_label = Label.new()
	_feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feedback_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	actions.add_child(_feedback_label)

	_clear_btn = _make_button("Clear", "secondary")
	_clear_btn.pressed.connect(_on_clear_pressed)
	actions.add_child(_clear_btn)

	_check_btn = _make_button("Check", "confirm")
	_check_btn.pressed.connect(_on_check_pressed)
	actions.add_child(_check_btn)

func _make_button(label: String, variant: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(0, 16)
	UIThemeApplier.apply_button_theme(btn, variant)
	btn.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	return btn

## Outline-only box. Derived from existing palette constants -- no new color.
func _make_slot_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = UIThemeApplier.TEXT_DISABLED
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(2)
	return sb

# --- bank / slots --------------------------------------------------------------

func _rebuild_bank() -> void:
	for child in _bank_grid.get_children():
		_bank_grid.remove_child(child)
		child.queue_free()
	_bank_btns.clear()
	_bank_grid.columns = BANK_COLUMNS_SMALL if _words.size() <= BANK_SMALL_MAX else BANK_COLUMNS_LARGE
	for i in range(_words.size()):
		var btn := _make_button(_words[i], "primary")
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, BANK_BTN_MIN_HEIGHT)
		btn.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
		btn.pressed.connect(_on_bank_pressed.bind(i))
		_bank_grid.add_child(btn)
		_bank_btns.append(btn)

## Re-syncs slots, bank enabled-state and Check button from `_placed`.
func _refresh() -> void:
	for child in _slot_flow.get_children():
		_slot_flow.remove_child(child)
		child.queue_free()
	for bank_idx in _placed:
		var slot_btn := _make_button(_words[bank_idx], "secondary")
		slot_btn.pressed.connect(_on_slot_pressed.bind(bank_idx))
		_slot_flow.add_child(slot_btn)

	_slot_hint.visible = _placed.is_empty()
	for i in range(_bank_btns.size()):
		_bank_btns[i].disabled = _locked or _placed.has(i)
	_clear_btn.disabled = _locked or _placed.is_empty()
	_check_btn.disabled = _locked or _placed.size() != _answer.size()

# --- input ---------------------------------------------------------------------

func _on_bank_pressed(bank_idx: int) -> void:
	if _locked or _placed.has(bank_idx):
		return
	AudioManager.play_sfx("advance")
	_placed.append(bank_idx)
	_refresh()

## Tapping a placed word returns it to the bank.
func _on_slot_pressed(bank_idx: int) -> void:
	if _locked:
		return
	_placed.erase(bank_idx)
	_refresh()

func _on_clear_pressed() -> void:
	if _locked:
		return
	_placed.clear()
	_refresh()

func _on_check_pressed() -> void:
	if _locked or _placed.size() != _answer.size():
		return
	_locked = true
	var attempt: Array = []
	for bank_idx in _placed:
		attempt.append(_words[bank_idx])
	var passed: bool = attempt == _answer

	_feedback_label.text = "Correct!" if passed else "Not quite."
	_feedback_label.add_theme_color_override(
		"font_color",
		UIThemeApplier.COLOR_SUCCESS if passed else UIThemeApplier.COLOR_ERROR
	)
	_refresh()  # disables everything while locked

	await get_tree().create_timer(FEEDBACK_HOLD).timeout
	# close() may have run during the hold (dialogue torn down) -- don't resolve then.
	if not is_inside_tree() or not visible:
		return
	_emit_resolved(passed)

func _emit_resolved(passed: bool) -> void:
	resolved.emit(passed)

# --- helpers -------------------------------------------------------------------

func _to_string_array(src: Array) -> Array:
	var out: Array = []
	for item in src:
		out.append(str(item))
	return out

func _answer_in_choices(answer: Array, choices: Array) -> bool:
	for w in answer:
		if not choices.has(w):
			return false
	return true

## Shuffles the bank, retrying so it never starts already in answer order
## (only possible to detect when bank == answer length, i.e. no distractors).
func _shuffled_bank(choices: Array, answer: Array) -> Array:
	var bank: Array = choices.duplicate()
	bank.shuffle()
	if bank.size() == answer.size() and bank.size() > 1:
		var tries := 0
		while bank == answer and tries < MAX_RESHUFFLES:
			bank.shuffle()
			tries += 1
	return bank
