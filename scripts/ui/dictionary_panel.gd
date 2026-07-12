# DictionaryPanel.gd — Stardew-tropical style
# [CLAUDE NOTE] Renamed from NotesPanel per panel feedback: free-text
# player-authored meanings removed. Dictionary auto-shows the verified
# gloss for any word once first encountered (see GameState.is_in_dictionary).
extends PanelContainer

const  TEXTURE: String = "res://assets/ui/sv_48.png"

@onready var notes_list: VBoxContainer = $VBoxContainer/ScrollContainer/NotesList
@onready var close_btn:  Button        = $VBoxContainer/HBoxContainer/CloseBtn
@onready var title_label: Label        = $VBoxContainer/HBoxContainer/Label

func _ready() -> void:
	add_to_group("dictionary_panel")
	close_btn.pressed.connect(func(): visible = false)
	visible = false
	_apply_style()

func _apply_style() -> void:
	# Outer panel — nine-patch
	var panel := StyleBoxTexture.new()
	panel.texture = preload(TEXTURE)
	panel.texture_margin_left   = 8  # match exact Aseprite export margin
	panel.texture_margin_right  = 8
	panel.texture_margin_top    = 8
	panel.texture_margin_bottom = 8
	panel.content_margin_left   = 10
	panel.content_margin_right  = 10
	panel.content_margin_top    = 10
	panel.content_margin_bottom = 10
	add_theme_stylebox_override("panel", panel)

	# Title — tropical palette, not brown/cream
	title_label.text = "Diksyunaryo"
	title_label.add_theme_color_override("font_color", Color("f0faf0"))  # mint cream
	title_label.add_theme_font_size_override("font_size", 12)

	# Close button
	UIThemeApplier.apply_icon_button_theme(close_btn, "close")

func _style_button(btn: Button, bg: Color, text_col: Color) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = Color("3a1010")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(3)
	normal.set_content_margin(SIDE_LEFT, 10)
	normal.set_content_margin(SIDE_RIGHT, 10)
	normal.set_content_margin(SIDE_TOP, 4)
	normal.set_content_margin(SIDE_BOTTOM, 4)

	var hover = normal.duplicate()
	hover.bg_color = bg.lightened(0.15)

	var pressed = normal.duplicate()
	pressed.bg_color = bg.darkened(0.2)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_font_size_override("font_size", 11)

func open() -> void:
	_rebuild()
	visible = true

func _rebuild() -> void:
	for child in notes_list.get_children():
		notes_list.remove_child(child)
		child.free()

	for word_id in GameState.word_exposures:
		var word_data = WordBank.get_word(word_id)
		if word_data.is_empty(): continue
		_add_entry(word_id, word_data)

func _add_entry(word_id: String, word_data: Dictionary) -> void:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style = StyleBoxFlat.new()
	card_style.bg_color     = Color("fffdf5")
	card_style.border_color = Color("c8a96e")
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(3)
	card_style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", card_style)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(vbox)

	# Category tag
	var cat_label = Label.new()
	cat_label.text = "[%s]" % word_data.get("category", "")
	cat_label.add_theme_color_override("font_color", Color("4a7c59"))
	cat_label.add_theme_font_size_override("font_size", 9)
	vbox.add_child(cat_label)

	# Akeanon word — big
	var word_label = Label.new()
	word_label.text = word_data.get("akeanon", "???")
	word_label.add_theme_color_override("font_color", Color("2c1810"))
	word_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(word_label)

	# Meaning — read-only, shown once unlocked
	# [CLAUDE NOTE] gloss field currently blank/unverified for all words
	# in word_bank.json (see Tier 1 word-bank-enrichment task). Falls
	# back to a placeholder string until verified glosses are filled in.
	var meaning_label = Label.new()
	var gloss: String = word_data.get("gloss", "")
	meaning_label.text = gloss if not gloss.is_empty() else "(meaning pending verification)"
	meaning_label.add_theme_color_override("font_color", Color("5c3a1e"))
	meaning_label.add_theme_font_size_override("font_size", 10)
	meaning_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(meaning_label)

	# Encounters
	var enc = Label.new()
	enc.text = "Nasubeang: %d beses" % GameState.get_exposure(word_id)
	enc.add_theme_color_override("font_color", Color("4a7c59"))
	enc.add_theme_font_size_override("font_size", 9)
	vbox.add_child(enc)

	notes_list.add_child(card)

	# Gap between cards
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	notes_list.add_child(spacer)
