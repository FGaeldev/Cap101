# DialogueUI.gd
extends Node

signal dialogue_finished
signal challenge_gate_entered(challenge_id: String)

var _current_component = null
var _dialogue_box      = null
var _choice_box        = null
var _root              = null
var _phrase_box        = null   # lazily instantiated phrase_builder panel
var _quiz_box          = null   # lazily instantiated quiz_panel
var _minigame_box      = null   # lazily instantiated minigame panel (one at a time)
var _minigame_type: String = ""   # minigame_type of the live _minigame_box
var _npc_menu: Control = null
var _npc_menu_callback: Callable

const PHRASE_BUILDER_SCENE := preload("res://scenes/ui/phrase_builder.tscn")
const QUIZ_PANEL_SCENE := preload("res://scenes/ui/quiz_panel.tscn")
## minigame_type -> panel script. Hardcoded (no dir scan: DirAccess is unreliable
## in exported Android builds, TDD 9.1). New minigame = add one entry here.
const MINIGAME_SCRIPTS := {
	"memory_match": preload("res://scripts/ui/memory_match_panel.gd"),
}

func register_box(box: Control) -> void:
	_dialogue_box = box

func register_choice_box(box: Control) -> void:
	_choice_box = box

func register_root(root: Control) -> void:
	_root = root

## Display dialogue text and its optional authored translation.
func show_line(
	speaker: String,
	text: String,
	component,
	portrait_tex,
	translation: String = ""
) -> void:
	_current_component = component

	# Restore controls hidden by the NPC menu before rendering the next line.
	if _npc_menu and is_instance_valid(_npc_menu):
		_npc_menu.hide()
	if _dialogue_box:
		_dialogue_box.show()
		_dialogue_box.display(speaker, text, translation)
	if _choice_box:
		_choice_box.show()
	if _root:
		_root.show_box()
		# Portrait is optional per-NPC art. Missing art hides cleanly.
		_root.set_portrait(portrait_tex, speaker)

func show_choices(choices: Array, component) -> void:
	if _choice_box:
		_choice_box.show_choices(choices, component)


## Show the NPC action menu after the NPC script has ruled out a cutscene trigger.
## The callback receives "talk", "review", or "goodbye".
func show_npc_interaction_menu(npc_display_name: String, callback: Callable) -> void:
	# Reuse DialogueRoot's existing dialogue panel and theme instead of a separate overlay.
	if _root == null:
		push_error("DialogueUI: no root registered, cannot show NPC interaction menu")
		return
	if _npc_menu == null or not is_instance_valid(_npc_menu):
		_npc_menu = VBoxContainer.new()
		_npc_menu.name = "NPCInteractionMenu"
		_npc_menu.add_theme_constant_override("separation", 6)
		var text_column := _root.get_node_or_null("Layout/DialoguePanel/Margin/TextColumn")
		if text_column == null:
			push_error("DialogueUI: DialogueRoot text column not found")
			_npc_menu.queue_free()
			_npc_menu = null
			return
		text_column.add_child(_npc_menu)
		_build_npc_interaction_menu()
	_npc_menu_callback = callback
	var title := _npc_menu.get_node_or_null("NpcName") as Label
	if title:
		title.text = npc_display_name if not npc_display_name.is_empty() else "NPC"
	_root.show_box()
	if _dialogue_box:
		_dialogue_box.hide()
	if _choice_box:
		_choice_box.hide()
	_npc_menu.show()


## Build actions inside existing DialogueRoot. Talk stays disabled while idle_pool is reworked.
func _build_npc_interaction_menu() -> void:
	var title := Label.new()
	title.name = "NpcName"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_L)
	_npc_menu.add_child(title)

	var talk_button := Button.new()
	talk_button.text = "Talk"
	talk_button.disabled = true
	talk_button.custom_minimum_size.y = 36.0
	UIThemeApplier.apply_button_theme(talk_button, "secondary")
	_npc_menu.add_child(talk_button)

	var note := Label.new()
	note.text = "disabled as reworking idle_pool system (10/19/2026)"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XS)
	note.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	_npc_menu.add_child(note)

	var review_button := Button.new()
	review_button.text = "Review"
	review_button.custom_minimum_size.y = 36.0
	UIThemeApplier.apply_button_theme(review_button, "primary")
	review_button.pressed.connect(_on_npc_interaction_choice.bind("review"))
	_npc_menu.add_child(review_button)

	var goodbye_button := Button.new()
	goodbye_button.text = "Goodbye"
	goodbye_button.custom_minimum_size.y = 36.0
	UIThemeApplier.apply_button_theme(goodbye_button, "secondary")
	goodbye_button.pressed.connect(_on_npc_interaction_choice.bind("goodbye"))
	_npc_menu.add_child(goodbye_button)


func _on_npc_interaction_choice(choice: String) -> void:
	if _npc_menu and is_instance_valid(_npc_menu):
		_npc_menu.hide()
	if _dialogue_box:
		_dialogue_box.show()
	if _choice_box:
		_choice_box.show()
	if _root:
		_root.hide_box()
	var callback := _npc_menu_callback
	_npc_menu_callback = Callable()
	if callback.is_valid():
		callback.call(choice)


## Opens the existing dynamic vocabulary quiz as a standalone review session.
## Prefer exposed words; use full word bank only for a brand-new learner.
func show_review_quiz() -> void:
	if _root == null:
		push_error("DialogueUI: no root registered, cannot show review quiz")
		return
	if _quiz_box == null or not is_instance_valid(_quiz_box):
		_quiz_box = QUIZ_PANEL_SCENE.instantiate()
		_root.get_parent().add_child(_quiz_box)

	for conn in _quiz_box.resolved.get_connections():
		_quiz_box.resolved.disconnect(conn["callable"])

	var word_pool: Array = GameState.word_exposures.keys()
	if word_pool.is_empty():
		word_pool = WordBank.words.keys()
	var choices: Array = WordBank.words.keys()
	if word_pool.is_empty() or choices.is_empty():
		push_warning("DialogueUI: cannot start review quiz because word bank is empty")
		return

	var review_line := {
		"type": "quiz",
		"quiz_type": "dynamic",
		"questions": [],
		"word_pool": word_pool,
		"choices": choices,
		"question_count": 5,
		"question_templates": [
			"What does \"[word]\" mean?",
			"What Akeanon word means \"[gloss]\"?"
		],
		"question_template_choice_displays": ["gloss", "word"],
		"choice_display": "gloss",
		"pass_ratio": 0.5
	}
	_current_component = null
	_quiz_box.resolved.connect(_on_review_quiz_resolved, CONNECT_ONE_SHOT)
	_quiz_box.open(review_line)


func _on_review_quiz_resolved(_passed: bool) -> void:
	# Review has no story branch; close overlays and return control to exploration.
	hide()

func hide() -> void:
	if _npc_menu and is_instance_valid(_npc_menu):
		_npc_menu.hide()
	if _dialogue_box:
		_dialogue_box.show()
	if _choice_box:
		_choice_box.show()
	_npc_menu_callback = Callable()
	if _phrase_box and is_instance_valid(_phrase_box):
		_phrase_box.close()
	if _quiz_box and is_instance_valid(_quiz_box):
		_quiz_box.close()
	if _minigame_box and is_instance_valid(_minigame_box):
		_minigame_box.close()
	_current_component = null
	if _choice_box:
		_choice_box.hide_choices()
	if _root:
		_root.hide_box()
	dialogue_finished.emit()

## Hide visuals without ending the dialogue session; challenge gates use this pause.
func hide_box_only() -> void:
	if _phrase_box and is_instance_valid(_phrase_box):
		_phrase_box.close()
	if _quiz_box and is_instance_valid(_quiz_box):
		_quiz_box.close()
	if _minigame_box and is_instance_valid(_minigame_box):
		_minigame_box.close()
	if _choice_box:
		_choice_box.hide_choices()
	if _root:
		_root.hide_box()

## Shows the phrase_builder panel for one dialogue line. Instantiated lazily as
## a sibling of DialogueRoot (UILayer), so Game.tscn needs no edit. Result is
## forwarded to the owning DialogueComponent, which picks success/failure line.
func show_phrase_builder(line: Dictionary, component) -> void:
	_current_component = component
	if _phrase_box == null or not is_instance_valid(_phrase_box):
		if _root == null:
			push_error("DialogueUI: no root registered, cannot show phrase builder")
			return
		_phrase_box = PHRASE_BUILDER_SCENE.instantiate()
		_root.get_parent().add_child(_phrase_box)
	_phrase_box.resolved.connect(func(passed: bool):
		_phrase_box.close()
		component.resolve_phrase_builder(passed)
	, CONNECT_ONE_SHOT)
	_phrase_box.open(line)

## Shows the quiz panel for one "quiz" dialogue line. Lazy-instantiated as a
## sibling of DialogueRoot, same as phrase_builder. Result goes to the owning
## DialogueComponent, which picks the success/failure line index.
func show_quiz(line: Dictionary, component) -> void:
	_current_component = component
	if _quiz_box == null or not is_instance_valid(_quiz_box):
		if _root == null:
			push_error("DialogueUI: no root registered, cannot show quiz")
			return
		_quiz_box = QUIZ_PANEL_SCENE.instantiate()
		_root.get_parent().add_child(_quiz_box)
	# Drop stale one-shots left by a quiz closed without resolving, else the
	# next resolve would also fire the old component's handler.
	for conn in _quiz_box.resolved.get_connections():
		_quiz_box.resolved.disconnect(conn["callable"])
	_quiz_box.resolved.connect(func(passed: bool):
		_quiz_box.close()
		component.resolve_quiz(passed)
	, CONNECT_ONE_SHOT)
	_quiz_box.open(line)

## Shows the minigame named by line["minigame_type"]. Lazy-instantiated as a
## sibling of DialogueRoot. Unknown type resolves as a pass so the story never
## softlocks on bad data (no-punishment rule). Result goes to the owning
## DialogueComponent, which picks the success/failure line index.
func show_minigame(line: Dictionary, component) -> void:
	_current_component = component
	var mg_type: String = str(line.get("minigame_type", ""))
	if not MINIGAME_SCRIPTS.has(mg_type):
		push_error("DialogueUI: unknown minigame_type '%s', auto-passing." % mg_type)
		component.call_deferred("resolve_minigame", true)
		return
	if _root == null:
		push_error("DialogueUI: no root registered, cannot show minigame")
		return

	# Reuse the live panel only if it is the same type; otherwise rebuild.
	if _minigame_box == null or not is_instance_valid(_minigame_box) or _minigame_type != mg_type:
		if _minigame_box and is_instance_valid(_minigame_box):
			_minigame_box.queue_free()
		_minigame_box = MINIGAME_SCRIPTS[mg_type].new()
		_minigame_type = mg_type
		_root.get_parent().add_child(_minigame_box)

	# Drop stale one-shots left by a minigame closed without resolving.
	for conn in _minigame_box.resolved.get_connections():
		_minigame_box.resolved.disconnect(conn["callable"])
	_minigame_box.resolved.connect(func(passed: bool):
		_minigame_box.close()
		component.resolve_minigame(passed)
	, CONNECT_ONE_SHOT)
	_minigame_box.open(line)

func player_pressed_advance() -> void:
	if _current_component:
		_current_component.advance()

## True while dialogue box is visible; HUD uses this to hide gameplay controls.
func is_active() -> bool:
	# Include modal panels because quiz/phrase-builder intentionally hide DialogueRoot.
	if _root != null and _root.visible:
		return true
	for overlay in [_npc_menu, _phrase_box, _quiz_box, _minigame_box]:
		if overlay != null and is_instance_valid(overlay) and overlay.visible:
			return true
	return false
