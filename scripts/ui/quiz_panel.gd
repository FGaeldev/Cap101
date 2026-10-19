# quiz_panel.gd -- multiple-choice vocabulary quiz shown inside dialogue.
#
# Driven by a dialogue line of type "quiz". Two shapes, same type key:
#
#   quiz_type "static"  -- every question authored:
#     { "type": "quiz", "quiz_type": "static",
#       "questions": [ { "question": "...", "correct_answer": "w084" } ],
#       "choices": ["w011", "w084", "w246"],       # word_ids shown as options
#       "choice_display": "gloss",                 # "gloss" | "word"
#       "success": 6, "failure": 7 }
#
#   quiz_type "dynamic" -- questions generated from word_pool at runtime:
#     { "type": "quiz", "quiz_type": "dynamic",
#       "word_pool": ["w101", "w102"],             # ids a question may target
#       "choices": ["w101", "w102", "w113"],       # option pool (answer auto-added)
#       "question_templates": ["What does \"[word]\" mean?",
#                              "What Akeanon word means \"[gloss]\"?"],
#       "question_template_choice_displays": ["gloss", "word"],  # parallel to templates
#       "question_count": 3,                       # optional, see below
#       "pass_ratio": 0.5,                         # optional
#       "success": 24, "failure": 23 }
#
# Rules:
#   * A "questions" entry with BOTH question and correct_answer set is used
#     verbatim (works in either quiz_type). An entry with either blank is a
#     placeholder: dynamic fills it from word_pool, static skips it.
#   * Question count = len(questions) if non-empty, else question_count, else
#     DEFAULT_QUESTION_COUNT.
#   * Template tokens: [word] -> akeanon form, [gloss] -> English gloss.
#   * Words already used this quiz (incl. authored answers) are not drawn
#     again until the pool runs out.
#   * Word pick is weighted by WordBank.get_weighted_review_word (GDD 6.8).
#
# Ownership: renders and reports only. Emits `resolved(passed)`; DialogueUI
# forwards it to the owning DialogueComponent, which jumps to success/failure.
# Never touches GameState/rapport/patience -- no-punishment rule (GDD 7).
# Bad data never softlocks: reports and resolves as a pass.
#
# Instantiated lazily by DialogueUI.show_quiz() as sibling of DialogueRoot.
extends PanelContainer

## Emitted once after the last question's feedback hold.
signal resolved(passed: bool)

## Seconds per-question feedback stays visible before advancing.
const FEEDBACK_HOLD: float = 1.0
## Question count when the line specifies neither "questions" nor "question_count".
const DEFAULT_QUESTION_COUNT: int = 3
## Fraction of questions that must be correct to take the "success" branch.
const DEFAULT_PASS_RATIO: float = 0.5
## Option text source when the line sets no "choice_display".
const DEFAULT_CHOICE_DISPLAY: String = "gloss"
## Shown when a word has no gloss yet (matches Dictionary tab fallback).
const GLOSS_FALLBACK: String = "(meaning pending verification)"
## Option grid columns.
const CHOICE_COLUMNS: int = 2
## Minimum option button height (px).
const CHOICE_BTN_MIN_HEIGHT: float = 24.0
## Dynamic quizzes pad word_pool / choices up to this many ids with known words.
const MIN_POOL_SIZE: int = 6
## Hard cap on option buttons per question (answer + distractors).
const MAX_OPTIONS: int = 6

var _questions: Array = []        # [{prompt, answer, options:[{id,text}]}]
var _index: int = 0               # current question
var _correct_count: int = 0
var _pass_ratio: float = DEFAULT_PASS_RATIO
var _locked: bool = true          # true while feedback shows / closed; ignores input
var _session: int = 0             # bumped on open/close; stale feedback timers bail

var _progress_label: Label
var _prompt_label: Label
var _choice_grid: GridContainer
var _feedback_label: Label

func _ready() -> void:
	# Same footprint as DialogueRoot / phrase_builder (bottom 45% of viewport).
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

## Start the quiz for one "quiz" line. Safe to call repeatedly.
func open(line: Dictionary) -> void:
	_session += 1
	_index = 0
	_correct_count = 0
	_pass_ratio = float(line.get("pass_ratio", DEFAULT_PASS_RATIO))
	_questions = _build_questions(line)

	if _questions.is_empty():
		push_error("QuizPanel: no usable questions built from line, auto-passing.")
		call_deferred("_emit_resolved", true)
		return

	visible = true
	_show_question()

## Hide without resolving (dialogue torn down / ended elsewhere).
func close() -> void:
	_session += 1
	_locked = true
	visible = false

# --- question building -----------------------------------------------------------

## Expands a quiz line into concrete questions:
## [{ "prompt": String, "answer": String, "options": [{ "id", "text" }] }]
func _build_questions(line: Dictionary) -> Array:
	var default_display: String = str(line.get("choice_display", DEFAULT_CHOICE_DISPLAY))
	var is_dynamic: bool = str(line.get("quiz_type", "static")) == "dynamic"
	var authored: Array = line.get("questions", [])
	var pool: Array = _to_string_array(line.get("word_pool", line.get("choices", [])))
	var option_pool: Array = _to_string_array(line.get("choices", pool))

	# Dynamic quizzes: pad thin pools with words the player already knows,
	# lowest mastery first, so review never runs on 2-3 words.
	if is_dynamic:
		pool = WordBank.top_up_pool(pool, MIN_POOL_SIZE, true)
		option_pool = WordBank.top_up_pool(option_pool, MIN_POOL_SIZE, true)

	var templates: Array = line.get("question_templates", [])
	if templates.is_empty() and line.has("question_template"):
		templates = [line["question_template"]]
	var displays: Array = line.get("question_template_choice_displays", [])

	var count: int = authored.size()
	if count == 0:
		count = int(line.get("question_count", DEFAULT_QUESTION_COUNT))

	# Reserve authored answers so generated questions don't duplicate them.
	var used: Array = []
	for q in authored:
		var a: String = str(q.get("correct_answer", "")).strip_edges()
		if not a.is_empty():
			used.append(a)

	var built: Array = []
	for i in range(count):
		var q: Dictionary = authored[i] if i < authored.size() else {}
		var answer: String = str(q.get("correct_answer", "")).strip_edges()
		var prompt: String = str(q.get("question", "")).strip_edges()
		var display: String = default_display

		if answer.is_empty() or prompt.is_empty():
			if not is_dynamic:
				push_warning("QuizPanel: static question %d incomplete, skipped." % i)
				continue
			var gen: Dictionary = _generate_question(pool, used, templates, displays, default_display)
			if gen.is_empty():
				continue
			answer = gen["answer"]
			prompt = gen["prompt"]
			display = gen["display"]

		if WordBank.get_word(answer).is_empty():
			push_warning("QuizPanel: unknown answer word id '%s', question skipped." % answer)
			continue

		built.append({
			"prompt": prompt,
			"answer": answer,
			"options": _build_options(answer, option_pool, display),
		})
	return built

## Picks a word + template for one generated question. Returns {} if impossible.
func _generate_question(
	pool: Array, used: Array, templates: Array, displays: Array, default_display: String
) -> Dictionary:
	if pool.is_empty() or templates.is_empty():
		push_warning("QuizPanel: dynamic question needs word_pool and question_templates.")
		return {}

	var t_idx: int = randi() % templates.size()
	var display: String = str(displays[t_idx]) if t_idx < displays.size() else default_display

	# Keep gloss-answer questions concise.
	var eligible_pool: Array = pool
	if display != "word":
		eligible_pool = pool.filter(func(id: String) -> bool:
			return _gloss_word_count(_gloss_of(WordBank.get_word(id))) <= 3
		)
	if eligible_pool.is_empty():
		push_warning("QuizPanel: no eligible words for selected answer display.")
		return {}

	var candidates: Array = eligible_pool.filter(func(id): return not used.has(id))
	if candidates.is_empty():
		candidates = eligible_pool

	var word_id: String = WordBank.get_weighted_review_word(candidates)
	var word: Dictionary = WordBank.get_word(word_id)
	if word.is_empty():
		push_warning("QuizPanel: unknown word id '%s' in word_pool." % word_id)
		return {}
	used.append(word_id)

	var prompt: String = str(templates[t_idx]).replace("[word]", str(word.get("akeanon", "???"))).replace("[gloss]", _gloss_of(word))
	return {"answer": word_id, "prompt": prompt, "display": display}

## Options for one question: answer + option_pool, deduped, unknown ids dropped, shuffled.
func _build_options(answer: String, option_pool: Array, display: String) -> Array:
	var distractors: Array = []
	for id in option_pool:
		if id == answer or distractors.has(id):
			continue
		var candidate_word: Dictionary = WordBank.get_word(id)
		if candidate_word.is_empty():
			continue
		if display != "word" and _gloss_word_count(_gloss_of(candidate_word)) > 3:
			continue
		distractors.append(id)
	distractors.shuffle()
	var ids: Array = [answer]
	ids.append_array(distractors.slice(0, MAX_OPTIONS - 1))
	ids.shuffle()

	var options: Array = []
	var seen_text: Array = []
	for id in ids:
		var word: Dictionary = WordBank.get_word(id)
		if word.is_empty():
			push_warning("QuizPanel: unknown choice word id '%s', dropped." % id)
			continue
		var text: String = str(word.get("akeanon", "???")) if display == "word" else _gloss_of(word)
		# Two options with identical text (e.g. shared gloss) would make the
		# question ambiguous -- drop the distractor, never the answer.
		if id != answer and seen_text.has(text.to_lower()):
			continue
		seen_text.append(text.to_lower())
		options.append({"id": id, "text": text})
	return options

func _gloss_of(word: Dictionary) -> String:
	var gloss: String = str(word.get("gloss", "")).strip_edges()
	return gloss if not gloss.is_empty() else GLOSS_FALLBACK


## Count words in a gloss to avoid unwieldy answer choices.
func _gloss_word_count(gloss: String) -> int:
	var normalized := gloss.strip_edges()
	return 0 if normalized.is_empty() else normalized.split(" ", false).size()

# --- layout ----------------------------------------------------------------------

func _build_layout() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 3)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	_progress_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	vbox.add_child(_progress_label)

	_prompt_label = Label.new()
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	_prompt_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	vbox.add_child(_prompt_label)

	_choice_grid = GridContainer.new()
	_choice_grid.columns = CHOICE_COLUMNS
	_choice_grid.add_theme_constant_override("h_separation", 3)
	_choice_grid.add_theme_constant_override("v_separation", 3)
	_choice_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_choice_grid)

	_feedback_label = Label.new()
	_feedback_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_feedback_label)

# --- flow ------------------------------------------------------------------------

func _show_question() -> void:
	var q: Dictionary = _questions[_index]
	_locked = false
	_progress_label.text = "%d / %d" % [_index + 1, _questions.size()]
	_prompt_label.text = q["prompt"]
	_feedback_label.text = ""

	# remove_child before free: queue_free alone leaves the old buttons in the
	# grid for a frame and the new row lays out against stale cells.
	for child in _choice_grid.get_children():
		_choice_grid.remove_child(child)
		child.queue_free()

	var options: Array = q["options"]
	for i in range(options.size()):
		var btn := Button.new()
		btn.text = options[i]["text"]
		btn.custom_minimum_size = Vector2(0, CHOICE_BTN_MIN_HEIGHT)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UIThemeApplier.apply_button_theme(btn, "primary")
		btn.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
		btn.pressed.connect(_on_option_pressed.bind(i, btn))
		_choice_grid.add_child(btn)

func _on_option_pressed(option_idx: int, btn: Button) -> void:
	if _locked:
		return
	_locked = true

	var q: Dictionary = _questions[_index]
	var options: Array = q["options"]
	var correct: bool = options[option_idx]["id"] == q["answer"]
	GameState.adjust_mastery(q["answer"], 1 if correct else -1)

	if correct:
		_correct_count += 1
		_flash_btn(btn, UIThemeApplier.COLOR_SUCCESS)
		_feedback_label.text = "Insakto"
		_feedback_label.add_theme_color_override("font_color", UIThemeApplier.COLOR_SUCCESS)
	else:
		_flash_btn(btn, UIThemeApplier.COLOR_ERROR)
		_feedback_label.text = "Not quite"
		_feedback_label.add_theme_color_override("font_color", UIThemeApplier.COLOR_ERROR)
		# Reveal the right answer so a miss still teaches (no punishment).
		for i in range(options.size()):
			if options[i]["id"] == q["answer"]:
				_flash_btn(_choice_grid.get_child(i), UIThemeApplier.COLOR_SUCCESS)
	for b in _choice_grid.get_children():
		b.disabled = true

	var session := _session
	await get_tree().create_timer(FEEDBACK_HOLD).timeout
	if session != _session:
		return   # closed or reopened during the hold

	_index += 1
	if _index >= _questions.size():
		_finish()
	else:
		_show_question()

func _finish() -> void:
	_locked = true
	GameState.save_game()   # persist mastery changes from this quiz
	var ratio: float = float(_correct_count) / float(_questions.size())
	_emit_resolved(ratio >= _pass_ratio)

func _emit_resolved(passed: bool) -> void:
	resolved.emit(passed)

## Tint only, never swap the button texture (same approach as puzzle_panel).
func _flash_btn(btn: Button, color: Color) -> void:
	btn.modulate = Color(color.r, color.g, color.b, 0.5)
	btn.add_theme_color_override("font_color_disabled", UIThemeApplier.TEXT_DEFAULT)

func _to_string_array(raw: Array) -> Array:
	var out: Array = []
	for item in raw:
		var s: String = str(item).strip_edges()
		if not s.is_empty():
			out.append(s)
	return out
