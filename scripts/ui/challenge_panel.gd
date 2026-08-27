# challenge_panel.gd — Chapter 2 discrete challenge UI (TDD §6.5).
#
# This is the missing rendering layer between Comp_Dialogue's challenge_gate
# line type and ChallengeManager's pure pass/fail logic. Before this file,
# DialogueUI.challenge_gate_entered had zero listeners — a gate would pause
# dialogue correctly but nothing ever showed the question or called
# ChallengeManager.attempt(), so no Chapter 2 gate was actually playable.
#
# Separate system from puzzle_panel.gd (word-bank fill-blank quiz driven by
# examinable_object.gd) — different data shape (mcq question/choices/
# correct_index vs. sentence template/word_id), different trigger path
# (dialogue challenge_gate vs. direct object interact). Do not merge or
# reuse puzzle_panel's group/API for this.
extends CanvasLayer

@onready var panel:          PanelContainer = $Panel
@onready var question_label: Label          = $Panel/VBox/QuestionLabel
@onready var choices_box:    VBoxContainer  = $Panel/VBox/ChoicesBox
@onready var hint_label:     Label          = $Panel/VBox/HintLabel

var _choice_btns: Array = []
var _active_challenge_id: String = ""

func _ready() -> void:
	visible = false
	for btn in choices_box.get_children():
		_choice_btns.append(btn)
	_apply_style()
	DialogueUI.challenge_gate_entered.connect(_open)

## Entry point — fired by Comp_Dialogue via DialogueUI.challenge_gate_entered
## whenever a challenge_gate line is hit and not already passed.
func _open(challenge_id: String) -> void:
	# ChallengeManager.challenges is populated from data/challenges/*.json at
	# _ready (hardcoded CHALLENGE_FILES array, TDD §9 item 1 — Android PCK
	# rule). Public var, read directly rather than adding a getter for a
	# single read site.
	var data: Dictionary = ChallengeManager.challenges.get(challenge_id, {})
	if data.is_empty():
		push_error("ChallengePanel: unknown challenge_id '%s'" % challenge_id)
		return

	_active_challenge_id = challenge_id
	hint_label.text = ""
	question_label.text = data.get("question", "")

	var choices: Array = data.get("choices", [])
	for i in _choice_btns.size():
		var btn: Button = _choice_btns[i]
		if i < choices.size():
			btn.text = str(choices[i])
			btn.visible = true
			btn.disabled = false
			_reset_btn(btn)
			if btn.pressed.is_connected(_on_choice_pressed):
				btn.pressed.disconnect(_on_choice_pressed)
			btn.pressed.connect(_on_choice_pressed.bind(i))
		else:
			btn.visible = false

	visible = true

## ChallengeManager.attempt() is the single source of truth for correct/
## first_try/hint/reward/fail-twice-opens-dictionary — this function only
## renders its result, no gameplay logic lives here.
func _on_choice_pressed(idx: int) -> void:
	var result: Dictionary = ChallengeManager.attempt(_active_challenge_id, idx)

	if result.get("correct", false):
		hint_label.text = "Husto! Maayo gid!"
		hint_label.add_theme_color_override("font_color", UIThemeApplier.COLOR_SUCCESS)
		for b in _choice_btns:
			b.disabled = true
		await get_tree().create_timer(0.8).timeout
		visible = false
		_active_challenge_id = ""
		# No manual dialogue-resume call needed here: Comp_Dialogue itself
		# listens for ChallengeManager.challenge_passed and advances past
		# the gate (see Comp_Dialogue._on_challenge_passed). This panel's
		# only job is to trigger attempt() and get out of the way.
		return

	# Wrong — hint stays visible, buttons re-enable immediately (no
	# rapport/patience penalty, no progress lost, per GDD §7 no-punishment
	# constraint). Fail-twice->BookUI Dictionary trigger already happens
	# inside ChallengeManager.attempt(), not this panel's concern.
	hint_label.text = result.get("hint", "")
	hint_label.add_theme_color_override("font_color", UIThemeApplier.COLOR_ERROR)

func _reset_btn(btn: Button) -> void:
	UIThemeApplier.apply_button_theme(btn, "primary")

func _apply_style() -> void:
	panel.custom_minimum_size = Vector2(340, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER)

	question_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_L)
	question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)

	hint_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	for btn in _choice_btns:
		btn.custom_minimum_size = Vector2(280, 28)
		btn.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
