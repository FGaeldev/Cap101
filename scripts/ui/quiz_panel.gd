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
#     verbatim (works in either quiz_type). It may set its own "choice_display"
#     (overrides the line's, e.g. "word" for an "Akeanon word for X?" prompt).
#     An entry with either blank is a
#     placeholder: dynamic fills it from word_pool, static skips it.
#   * Question count = len(questions) if non-empty, else question_count, else
#     DEFAULT_QUESTION_COUNT.
#   * Template tokens: [word] -> akeanon form, [gloss] -> English gloss.
#   * Words already used this quiz (incl. authored answers) are not drawn
#     again until the pool runs out.
#   * Word pick is weighted by WordBank.get_weighted_review_word (GDD 6.8).
#   * "fixed_pool": true stops dynamic quizzes padding their pools with other
#     known words, so a numbers quiz only ever asks about numbers.
#   * Color quizzes set "word_colors": {"w198": "d32f2f"} (word_id -> hex). Then
#     a template containing [swatch] shows the answer's color beside the prompt,
#     and choice display "color" makes each option a color instead of text. In
#     color blind mode swatches also name their color, which keeps the quiz
#     playable: it then tests the word's meaning instead of its hue.
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
## Option grid columns above MAX_OPTIONS, so all rows fit the panel height.
const CHOICE_COLUMNS_MANY: int = 3
## Minimum option button height (px).
const CHOICE_BTN_MIN_HEIGHT: float = 24.0
## Dynamic quizzes pad word_pool / choices up to this many ids with known words.
const MIN_POOL_SIZE: int = 6
## Cap on option buttons per question (answer + distractors), unless a dynamic
## quiz scales it with the difficulty tier (GameState.get_quiz_choice_count).
const MAX_OPTIONS: int = 6
## Token in a question template: show the answer's color beside the prompt.
const SWATCH_TOKEN: String = "[swatch]"
## Choice display: options are colors (see "word_colors").
const DISPLAY_COLOR: String = "color"
const SWATCH_SIZE := Vector2(72, 26)
## Keeps white and black swatches visible on the parchment panel.
const SWATCH_BORDER: int = 2
## How far a wrong color fades once the answer is revealed. Fading is a cue that
## doesn't depend on seeing the hue.
const WRONG_SWATCH_ALPHA: float = 0.35

var _questions: Array = []        # [{prompt, answer, swatch, options:[{id,text,color}]}]
var _word_colors: Dictionary = {} # word_id -> hex, this quiz's "word_colors"
var _index: int = 0               # current question
var _correct_count: int = 0
var _pass_ratio: float = DEFAULT_PASS_RATIO
var _locked: bool = true          # true while feedback shows / closed; ignores input
var _session: int = 0             # bumped on open/close; stale feedback timers bail

var _progress_label: Label
var _prompt_label: Label
var _prompt_swatch: PanelContainer
var _prompt_swatch_label: Label
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
	HelpButton.pin(self, "quiz")
	visible = false

# --- public API ----------------------------------------------------------------

## Start the quiz for one "quiz" line. Safe to call repeatedly.
func open(line: Dictionary) -> void:
	_session += 1
	_index = 0
	_correct_count = 0
	_pass_ratio = float(line.get("pass_ratio", DEFAULT_PASS_RATIO))
	_word_colors = line.get("word_colors", {})
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
	var max_options: int = MAX_OPTIONS
	if is_dynamic:
		var scaled: int = GameState.get_quiz_choice_count()
		if scaled > 0:
			max_options = scaled
		if not line.get("fixed_pool", false):
			pool = WordBank.top_up_pool(pool, MIN_POOL_SIZE, true)
			option_pool = WordBank.top_up_pool(option_pool, maxi(MIN_POOL_SIZE, max_options), true)

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
		var display: String = str(q.get("choice_display", default_display))

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
			"prompt": prompt.replace(SWATCH_TOKEN, "").strip_edges(),
			"answer": answer,
			"swatch": str(_word_colors.get(answer, "")) if prompt.contains(SWATCH_TOKEN) else "",
			"options": _build_options(answer, option_pool, display, max_options),
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

## Options for one question: the answer plus up to max_options - 1 distractors from
## option_pool, shuffled. Unknown ids are dropped.
func _build_options(answer: String, option_pool: Array, display: String, max_options: int) -> Array:
	var options: Array = [_make_option(answer, display)]
	var seen_text: Array = [options[0]["text"].to_lower()]
	var distractors: Array = option_pool.duplicate()
	distractors.shuffle()
	for id in distractors:
		if options.size() >= max_options:
			break
		var word: Dictionary = WordBank.get_word(id)
		if id == answer or word.is_empty():
			continue
		if display != "word" and _gloss_word_count(_gloss_of(word)) > 3:
			continue
		var option: Dictionary = _make_option(id, display)
		# Two options with identical text (e.g. shared gloss) would make the
		# question ambiguous -- skip the distractor, never the answer.
		if seen_text.has(option["text"].to_lower()):
			continue
		seen_text.append(option["text"].to_lower())
		options.append(option)
	options.shuffle()
	return options

func _make_option(id: String, display: String) -> Dictionary:
	var word: Dictionary = WordBank.get_word(id)
	var option: Dictionary = {"id": id, "text": str(word.get("akeanon", "???")) if display == "word" else _gloss_of(word)}
	if display == DISPLAY_COLOR:
		option["color"] = str(_word_colors.get(id, ""))
		option["akeanon"] = str(word.get("akeanon", "???"))
	return option

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
	_prompt_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Beside the prompt, not above it: full option grids use the panel's height.
	var prompt_row := HBoxContainer.new()
	prompt_row.add_theme_constant_override("separation", 6)
	vbox.add_child(prompt_row)
	prompt_row.add_child(_prompt_label)

	_prompt_swatch = PanelContainer.new()
	_prompt_swatch.custom_minimum_size = SWATCH_SIZE
	_prompt_swatch_label = Label.new()
	_prompt_swatch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_swatch_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_swatch_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	_prompt_swatch.add_child(_prompt_swatch_label)
	prompt_row.add_child(_prompt_swatch)

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
	_show_prompt_swatch(q)

	# remove_child before free: queue_free alone leaves the old buttons in the
	# grid for a frame and the new row lays out against stale cells.
	for child in _choice_grid.get_children():
		_choice_grid.remove_child(child)
		child.queue_free()

	var options: Array = q["options"]
	_choice_grid.columns = CHOICE_COLUMNS_MANY if options.size() > MAX_OPTIONS else CHOICE_COLUMNS
	for i in range(options.size()):
		var btn := Button.new()
		btn.text = options[i]["text"]
		btn.custom_minimum_size = Vector2(0, CHOICE_BTN_MIN_HEIGHT)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UIThemeApplier.apply_button_theme(btn, "primary")
		btn.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
		if not str(options[i].get("color", "")).is_empty():
			_style_color_option(btn, options[i])
		btn.pressed.connect(_on_option_pressed.bind(i, btn))
		_choice_grid.add_child(btn)

func _show_prompt_swatch(q: Dictionary) -> void:
	var hex: String = q.get("swatch", "")
	_prompt_swatch.visible = not hex.is_empty()
	if hex.is_empty():
		return
	var color := Color(hex)
	_prompt_swatch.add_theme_stylebox_override("panel", _make_swatch_style(color))
	_prompt_swatch_label.add_theme_color_override("font_color", _readable_on(color))
	_prompt_swatch_label.text = _gloss_of(WordBank.get_word(q["answer"])) if Accessibility.color_blind else ""

## Turns an option button into a color. The color name only shows in color blind
## mode; everyone gets the Akeanon word once the answer is revealed.
func _style_color_option(btn: Button, option: Dictionary) -> void:
	var color := Color(str(option["color"]))
	var style := _make_swatch_style(color)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		btn.add_theme_stylebox_override(state, style)
	var text_color := _readable_on(color)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		btn.add_theme_color_override(key, text_color)
	btn.text = option["text"] if Accessibility.color_blind else ""

func _make_swatch_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = UIThemeApplier.TEXT_EMPHASIS
	style.set_border_width_all(SWATCH_BORDER)
	style.set_corner_radius_all(2)
	return style

func _readable_on(color: Color) -> Color:
	return Color.BLACK if color.get_luminance() > 0.5 else Color.WHITE

## After an answer: color options reveal their Akeanon word and the wrong ones
## fade. Tinting them, like text options, would change the color being tested.
func _reveal_color_options(options: Array, answer: String) -> void:
	for i in range(options.size()):
		var btn: Button = _choice_grid.get_child(i)
		btn.text = options[i]["akeanon"]
		if options[i]["id"] != answer:
			btn.modulate.a = WRONG_SWATCH_ALPHA

func _on_option_pressed(option_idx: int, btn: Button) -> void:
	if _locked:
		return
	_locked = true

	var q: Dictionary = _questions[_index]
	var options: Array = q["options"]
	var correct: bool = options[option_idx]["id"] == q["answer"]
	GameState.adjust_mastery(q["answer"], 1 if correct else -1)

	var is_color_question: bool = not str(options[option_idx].get("color", "")).is_empty()
	if correct:
		_correct_count += 1
		_feedback_label.text = "Insakto"
		_feedback_label.add_theme_color_override("font_color", Accessibility.success_color())
	else:
		_feedback_label.text = "Not quite"
		_feedback_label.add_theme_color_override("font_color", Accessibility.error_color())
	if is_color_question:
		_reveal_color_options(options, q["answer"])
	else:
		_flash_btn(btn, Accessibility.success_color() if correct else Accessibility.error_color())
		# Reveal the right answer so a miss still teaches (no punishment).
		for i in range(options.size()):
			if not correct and options[i]["id"] == q["answer"]:
				_flash_btn(_choice_grid.get_child(i), Accessibility.success_color())
		if Accessibility.color_blind:
			_label_result(options, q["answer"], btn)
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

## Color blind mode: says in words which answer was right and which was picked.
func _label_result(options: Array, answer: String, picked: Button) -> void:
	for i in range(options.size()):
		var btn: Button = _choice_grid.get_child(i)
		if options[i]["id"] == answer:
			btn.text = "%s (correct)" % btn.text
		elif btn == picked:
			btn.text = "%s (wrong)" % btn.text

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
