@tool
extends VBoxContainer
## The Word Bank workspace shown in the Godot editor's top bar.
##
## `undo` is assigned by plugin.gd. It stays untyped so this screen also runs
## outside the editor, where the EditorUndoRedoManager class doesn't exist.

const Store := preload("word_bank_store.gd")
const References := preload("word_references.gd")

const COLUMNS := [
	{ "key": "id", "title": "ID", "width": 105, "inline": false },
	{ "key": "akeanon", "title": "Akeanon", "width": 170, "inline": true },
	{ "key": "gloss", "title": "Gloss", "width": 260, "inline": true },
	{ "key": "category", "title": "Category", "width": 130, "inline": true },
	{ "key": "area", "title": "Area", "width": 90, "inline": false },
	{ "key": "verified", "title": "Verified", "width": 80, "inline": false },
]
const COL_ID := 0
const COL_VERIFIED := 5
const BASE_AREAS := ["all", "chapter1", "chapter2", "chapter3", "chapter4", "chapter5", "chapter6"]
const STATUS_LABELS := {
	Store.Status.ALL: "All words",
	Store.Status.UNVERIFIED: "Unverified",
	Store.Status.PROBLEMS: "Has problems",
	Store.Status.NO_GLOSS: "No gloss",
	Store.Status.NO_CATEGORY: "No category",
}

var undo = null

var _store := Store.new()
var _references := References.new()
var _selected_id := ""
var _sort_column := 1
var _sort_ascending := true
var _row_ids: Array = []
var _row_items: Array = []
var _area_values: Array = []
var _filter_area_values: Array = []
var _missing: Array = []
var _refresh_queued := false
var _notice := ""

var _search: LineEdit
var _area_filter: OptionButton
var _status_filter: OptionButton
var _add_button: Button
var _delete_button: Button
var _save_button: Button
var _reload_button: Button
var _status: Label
var _tree: Tree
var _tabs: TabContainer
var _form: VBoxContainer
var _empty_hint: Label
var _heading: Label
var _id_field: LineEdit
var _akeanon_field: LineEdit
var _gloss_field: LineEdit
var _category_field: LineEdit
var _category_menu: MenuButton
var _area_field: OptionButton
var _source_field: LineEdit
var _verified_field: CheckBox
var _problems_label: Label
var _uses_label: Label
var _uses_list: ItemList
var _missing_page: VBoxContainer
var _missing_list: ItemList
var _delete_dialog: ConfirmationDialog
var _reload_dialog: ConfirmationDialog


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_toolbar()
	_build_body()
	_build_dialogs()
	_store.changed.connect(_queue_refresh)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and is_visible_in_tree() and _store.is_loaded():
		activate()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey:
		return
	if event.pressed and not event.echo and event.keycode == KEY_S \
			and event.is_command_or_control_pressed() and not event.shift_pressed:
		get_viewport().set_input_as_handled()
		save_now()


## Called whenever the screen is shown or Godot regains focus.
func activate() -> void:
	if not _store.is_loaded():
		_load()
		return
	_references.scan()
	if _store.disk_changed():
		if _store.dirty:
			_prompt_reload("word_bank.json changed outside Godot while you have unsaved edits here.")
		else:
			_load()
			_notice = "Reloaded: the file changed outside Godot."
	_queue_refresh()


func has_unsaved_changes() -> bool:
	return _store.dirty


## Saves pending edits. Used by the Save button, Ctrl+S and the editor's own save.
func save_now() -> void:
	if not _store.is_loaded() or not _store.dirty:
		return
	if _store.disk_changed():
		_prompt_reload("word_bank.json changed outside Godot, so your edits weren't saved.")
		return
	var error := _store.save()
	_notice = error if not error.is_empty() else "Saved."
	if not error.is_empty():
		push_error("Word Bank: %s" % error)
	_queue_refresh()


# --- Layout ---------------------------------------------------------------

func _build_toolbar() -> void:
	var bar := HBoxContainer.new()
	add_child(bar)

	_search = LineEdit.new()
	_search.placeholder_text = "Search words, IDs, glosses..."
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.custom_minimum_size.x = 200
	_search.text_changed.connect(func(_text): _queue_refresh())
	bar.add_child(_search)

	_area_filter = OptionButton.new()
	_area_filter.tooltip_text = "Show one area only"
	_area_filter.item_selected.connect(func(_index): _queue_refresh())
	bar.add_child(_area_filter)

	_status_filter = OptionButton.new()
	_status_filter.tooltip_text = "Show words needing attention"
	for status in STATUS_LABELS:
		_status_filter.add_item(STATUS_LABELS[status], status)
	_status_filter.item_selected.connect(func(_index): _queue_refresh())
	bar.add_child(_status_filter)

	bar.add_child(VSeparator.new())
	_add_button = _toolbar_button(bar, "Add word", _on_add_pressed)
	_delete_button = _toolbar_button(bar, "Delete", _on_delete_pressed)
	bar.add_child(VSeparator.new())
	_save_button = _toolbar_button(bar, "Save", save_now)
	_reload_button = _toolbar_button(bar, "Reload", _on_reload_pressed)

	_status = Label.new()
	_status.custom_minimum_size.x = 170
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bar.add_child(_status)


func _toolbar_button(parent: Control, label: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.pressed.connect(handler)
	parent.add_child(button)
	return button


func _build_body() -> void:
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)

	_tree = Tree.new()
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_stretch_ratio = 2.0
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_SINGLE
	_tree.columns = COLUMNS.size()
	_tree.column_titles_visible = true
	for column in range(COLUMNS.size()):
		_tree.set_column_custom_minimum_width(column, COLUMNS[column]["width"])
		_tree.set_column_expand(column, COLUMNS[column]["key"] == "gloss")
		_tree.set_column_clip_content(column, true)
	_tree.item_selected.connect(_on_row_selected)
	_tree.item_activated.connect(_on_row_activated)
	_tree.item_edited.connect(_on_cell_edited)
	_tree.column_title_clicked.connect(_on_column_title_clicked)
	split.add_child(_tree)

	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.custom_minimum_size.x = 340
	split.add_child(_tabs)
	_build_details_page()
	_build_missing_page()


func _build_details_page() -> void:
	var page := MarginContainer.new()
	page.name = "Details"
	_tabs.add_child(page)

	var stack := VBoxContainer.new()
	page.add_child(stack)

	_empty_hint = Label.new()
	_empty_hint.text = "Select a word to edit it."
	_empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_empty_hint)

	_form = VBoxContainer.new()
	_form.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_form)

	_heading = Label.new()
	_heading.add_theme_font_size_override("font_size", 18)
	_heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_form.add_child(_heading)

	var grid := GridContainer.new()
	grid.columns = 2
	_form.add_child(grid)

	_id_field = _add_text_row(grid, "ID", "")
	_id_field.editable = false
	_id_field.tooltip_text = "IDs are permanent: saves and dialogue refer to words by ID."
	_akeanon_field = _add_text_row(grid, "Akeanon", "akeanon")
	_gloss_field = _add_text_row(grid, "Gloss", "gloss")

	_add_row_label(grid, "Category")
	var category_row := HBoxContainer.new()
	category_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(category_row)
	_category_field = LineEdit.new()
	_category_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_category_field.text_changed.connect(_on_field_typed.bind("category"))
	category_row.add_child(_category_field)
	_category_menu = MenuButton.new()
	_category_menu.text = "Choose"
	_category_menu.flat = false
	_category_menu.about_to_popup.connect(_fill_category_menu)
	_category_menu.get_popup().index_pressed.connect(_on_category_chosen)
	category_row.add_child(_category_menu)

	_add_row_label(grid, "Area")
	_area_field = OptionButton.new()
	_area_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_area_field.item_selected.connect(_on_area_chosen)
	grid.add_child(_area_field)

	_source_field = _add_text_row(grid, "Source", "source")

	_add_row_label(grid, "")
	_verified_field = CheckBox.new()
	_verified_field.text = "Verified"
	_verified_field.toggled.connect(_on_verified_toggled)
	grid.add_child(_verified_field)

	_problems_label = Label.new()
	_problems_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problems_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	_form.add_child(_problems_label)

	_form.add_child(HSeparator.new())
	_uses_label = Label.new()
	_form.add_child(_uses_label)
	_uses_list = ItemList.new()
	_uses_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_uses_list.custom_minimum_size.y = 120
	_uses_list.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_form.add_child(_uses_list)
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _add_row_label(grid: GridContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	grid.add_child(label)


func _add_text_row(grid: GridContainer, title: String, key: String) -> LineEdit:
	_add_row_label(grid, title)
	var field := LineEdit.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not key.is_empty():
		field.text_changed.connect(_on_field_typed.bind(key))
	grid.add_child(field)
	return field


func _build_missing_page() -> void:
	_missing_page = VBoxContainer.new()
	_missing_page.name = "Missing words"
	_tabs.add_child(_missing_page)

	var hint := Label.new()
	hint.text = "Marked with a backslash in game text, but not in the word bank. Double-click to add."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_missing_page.add_child(hint)

	_missing_list = ItemList.new()
	_missing_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_missing_list.item_activated.connect(_on_missing_activated)
	_missing_page.add_child(_missing_list)


func _build_dialogs() -> void:
	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "Delete word"
	_delete_dialog.ok_button_text = "Delete"
	_delete_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(_delete_dialog)

	_reload_dialog = ConfirmationDialog.new()
	_reload_dialog.title = "Word bank changed"
	_reload_dialog.ok_button_text = "Reload from disk"
	_reload_dialog.cancel_button_text = "Keep my edits"
	_reload_dialog.confirmed.connect(_load)
	_reload_dialog.canceled.connect(_on_keep_edits)
	add_child(_reload_dialog)


# --- Loading and refreshing -----------------------------------------------

func _load() -> void:
	var error := _store.load_from_disk()
	_references.scan()
	_notice = error
	if not error.is_empty():
		push_error("Word Bank: %s" % error)
	if _selected_id.is_empty() or _store.find(_selected_id).is_empty():
		_selected_id = ""
	_queue_refresh()


func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	if not is_inside_tree():
		return
	if not _selected_id.is_empty() and _store.find(_selected_id).is_empty():
		_selected_id = ""
	_refresh_filter_areas()
	var problems := _store.problems()
	var rows := _store.query(
		_search.text,
		_current_filter_area(),
		_status_filter.get_selected_id(),
		COLUMNS[_sort_column]["key"],
		_sort_ascending)
	_refresh_table(rows, problems)
	_refresh_form(problems)
	_refresh_missing()
	_refresh_toolbar(rows.size())


func _refresh_filter_areas() -> void:
	var values := _known_areas()
	if values == _filter_area_values:
		return
	var current := _current_filter_area()
	_filter_area_values = values
	_area_filter.clear()
	_area_filter.add_item("All areas")
	_area_filter.set_item_metadata(0, "")
	for value in values:
		_area_filter.add_item(value)
		_area_filter.set_item_metadata(_area_filter.item_count - 1, value)
	var index := values.find(current)
	_area_filter.select(index + 1 if index >= 0 else 0)


func _current_filter_area() -> String:
	if _area_filter.item_count == 0 or _area_filter.selected < 0:
		return ""
	return str(_area_filter.get_item_metadata(_area_filter.selected))


func _known_areas() -> Array:
	var values: Array = BASE_AREAS.duplicate()
	for area in _store.areas():
		if not values.has(area):
			values.append(area)
	return values


func _refresh_table(rows: Array, problems: Dictionary) -> void:
	var ids := rows.map(func(word): return str(word.get("id", "")))
	if ids != _row_ids:
		_rebuild_rows(ids)
	for index in range(rows.size()):
		_fill_row(_row_items[index], rows[index], problems)
	for column in range(COLUMNS.size()):
		var title: String = COLUMNS[column]["title"]
		if column == _sort_column:
			title += " (A-Z)" if _sort_ascending else " (Z-A)"
		_tree.set_column_title(column, title)


func _rebuild_rows(ids: Array) -> void:
	_tree.clear()
	_tree.create_item()
	_row_ids = ids
	_row_items = []
	var selected_item: TreeItem = null
	for id in ids:
		var item := _tree.create_item()
		item.set_metadata(COL_ID, id)
		item.set_cell_mode(COL_VERIFIED, TreeItem.CELL_MODE_CHECK)
		item.set_editable(COL_VERIFIED, true)
		_row_items.append(item)
		if id == _selected_id:
			selected_item = item
	if selected_item != null:
		selected_item.select(COL_ID)
		_tree.scroll_to_item(selected_item)


func _fill_row(item: TreeItem, word: Dictionary, problems: Dictionary) -> void:
	var id := str(word.get("id", ""))
	for column in range(COLUMNS.size()):
		if column != COL_VERIFIED:
			item.set_text(column, str(word.get(COLUMNS[column]["key"], "")))
	item.set_checked(COL_VERIFIED, bool(word.get("verified", false)))
	if problems.has(id):
		item.set_icon(COL_ID, _warning_icon())
		item.set_tooltip_text(COL_ID, "\n".join(problems[id]))
	else:
		item.set_icon(COL_ID, null)
		item.set_tooltip_text(COL_ID, "")


func _warning_icon() -> Texture2D:
	if has_theme_icon("StatusWarning", "EditorIcons"):
		return get_theme_icon("StatusWarning", "EditorIcons")
	return null


func _refresh_form(problems: Dictionary) -> void:
	var word := _store.find(_selected_id) if not _selected_id.is_empty() else {}
	_empty_hint.visible = word.is_empty()
	_form.visible = not word.is_empty()
	_delete_button.disabled = word.is_empty()
	if word.is_empty():
		return
	var akeanon := str(word.get("akeanon", ""))
	_heading.text = akeanon if not akeanon.strip_edges().is_empty() else "New word"
	_set_field_text(_id_field, str(word.get("id", "")))
	_set_field_text(_akeanon_field, akeanon)
	_set_field_text(_gloss_field, str(word.get("gloss", "")))
	_set_field_text(_category_field, str(word.get("category", "")))
	_set_field_text(_source_field, str(word.get("source", "")))
	_verified_field.set_pressed_no_signal(bool(word.get("verified", false)))
	_refresh_area_field(str(word.get("area", "")))
	var word_problems: PackedStringArray = problems.get(_selected_id, PackedStringArray())
	_problems_label.text = "\n".join(word_problems)
	_problems_label.visible = not word_problems.is_empty()
	_refresh_uses(word)


## Only writes when different, so typing in a field doesn't move its caret.
func _set_field_text(field: LineEdit, value: String) -> void:
	if field.text != value:
		field.text = value


func _refresh_area_field(value: String) -> void:
	_area_values = _known_areas()
	if not value.is_empty() and not _area_values.has(value):
		_area_values.append(value)
	_area_field.clear()
	for area in _area_values:
		_area_field.add_item(area)
	_area_field.select(_area_values.find(value))


func _refresh_uses(word: Dictionary) -> void:
	var uses := _references.uses_of(_selected_id, _store.forms_of(word))
	_uses_label.text = "Used in %d %s" % [uses.size(), "place" if uses.size() == 1 else "places"]
	_uses_list.clear()
	for use in uses:
		var index := _uses_list.add_item(_describe_use(use))
		_uses_list.set_item_tooltip(index, "%s\n%s" % [_location_of(use), use["text"]])


func _describe_use(use: Dictionary) -> String:
	var line: String = use["text"]
	if not use["speaker"].is_empty():
		line = "%s: %s" % [use["speaker"], line]
	return "%s  -  %s" % [use["file"].get_file().get_basename(), line]


func _location_of(use: Dictionary) -> String:
	return "%s > %s" % [use["file"], use["where"]]


func _refresh_missing() -> void:
	_missing = _references.missing_markers(_store.all_forms())
	_missing_list.clear()
	for entry in _missing:
		var count: int = entry["count"]
		var index := _missing_list.add_item("%s  (%d)" % [entry["form"], count])
		_missing_list.set_item_tooltip(index, "%s\n%s" % [_location_of(entry["example"]), entry["example"]["text"]])
	_tabs.set_tab_title(_missing_page.get_index(), "Missing words (%d)" % _missing.size())


func _refresh_toolbar(shown: int) -> void:
	var loaded := _store.is_loaded()
	_add_button.disabled = not loaded
	_save_button.disabled = not _store.dirty
	_save_button.text = "Save*" if _store.dirty else "Save"
	var text := "%d of %d words" % [shown, _store.words.size()]
	if not _notice.is_empty():
		text = _notice
	elif not _references.errors.is_empty():
		text = "%d data file(s) couldn't be scanned" % _references.errors.size()
	_status.text = text
	_status.tooltip_text = _notice if not _notice.is_empty() else "\n".join(_references.errors)


# --- Edits ----------------------------------------------------------------

## Every edit goes through here so it lands in Godot's undo history. `merge`
## folds quick successive keystrokes in one field into a single undo step.
func _commit(label: String, state: Array, merge: bool = false) -> void:
	_notice = ""
	if undo == null:
		_store.restore(state)
		return
	undo.create_action(label, UndoRedo.MERGE_ENDS if merge else UndoRedo.MERGE_DISABLE, _store)
	undo.add_do_method(_store, "restore", state)
	undo.add_undo_method(_store, "restore", _store.snapshot())
	undo.commit_action()


func _edit_field(id: String, key: String, value: Variant, merge: bool) -> void:
	var state := _store.with_field(id, key, value)
	if not state.is_empty():
		_commit("Word Bank: edit %s of %s" % [key, id], state, merge)


func _on_field_typed(text: String, key: String) -> void:
	if not _selected_id.is_empty():
		_edit_field(_selected_id, key, text, true)


func _fill_category_menu() -> void:
	var popup := _category_menu.get_popup()
	popup.clear()
	for category in _store.categories():
		popup.add_item(category)


func _on_category_chosen(index: int) -> void:
	if not _selected_id.is_empty():
		_edit_field(_selected_id, "category", _category_menu.get_popup().get_item_text(index), false)


func _on_area_chosen(index: int) -> void:
	if not _selected_id.is_empty():
		_edit_field(_selected_id, "area", _area_values[index], false)


func _on_verified_toggled(pressed: bool) -> void:
	if not _selected_id.is_empty():
		_edit_field(_selected_id, "verified", pressed, false)


func _on_add_pressed() -> void:
	_add_word("")
	_akeanon_field.grab_focus()


func _add_word(akeanon: String) -> void:
	var area := _current_filter_area()
	var word := _store.new_word(akeanon, area if not area.is_empty() else Store.DEFAULT_AREA)
	_search.text = ""
	_status_filter.select(_status_filter.get_item_index(Store.Status.ALL))
	_selected_id = word["id"]
	_tabs.current_tab = 0
	_commit("Word Bank: add %s" % word["id"], _store.with_added(word))


func _on_missing_activated(index: int) -> void:
	_add_word(_missing[index]["form"])
	_gloss_field.grab_focus()


func _on_delete_pressed() -> void:
	var word := _store.find(_selected_id)
	if word.is_empty():
		return
	var uses := _references.uses_of(_selected_id, _store.forms_of(word))
	var text := "Delete %s (%s)?" % [_selected_id, str(word.get("akeanon", ""))]
	if not uses.is_empty():
		text += "\n\nIt's used in %d place(s), which will no longer find it." % uses.size()
	text += "\nPlayers who already learned it keep a mastery entry for an ID that's gone."
	_delete_dialog.dialog_text = text
	_delete_dialog.popup_centered()


func _on_delete_confirmed() -> void:
	var id := _selected_id
	_selected_id = ""
	_commit("Word Bank: delete %s" % id, _store.with_removed(id))


func _on_reload_pressed() -> void:
	if _store.dirty:
		_prompt_reload("Reloading discards your unsaved edits.")
	else:
		_load()
		if _notice.is_empty():
			_notice = "Reloaded."
		_queue_refresh()


func _prompt_reload(message: String) -> void:
	if _reload_dialog.visible:
		return
	_reload_dialog.dialog_text = message
	_reload_dialog.popup_centered()


func _on_keep_edits() -> void:
	_store.acknowledge_disk()


# --- Table events ---------------------------------------------------------

func _on_row_selected() -> void:
	var item := _tree.get_selected()
	if item == null:
		return
	var id := str(item.get_metadata(COL_ID))
	if id != _selected_id:
		_selected_id = id
		_tabs.current_tab = 0
		_queue_refresh()


## Double-clicking (or Enter on) a text cell edits it in place.
func _on_row_activated() -> void:
	var column := _tree.get_selected_column()
	if column >= 0 and COLUMNS[column]["inline"]:
		_tree.edit_selected(true)


func _on_cell_edited() -> void:
	var item := _tree.get_edited()
	var column := _tree.get_edited_column()
	if item == null:
		return
	var id := str(item.get_metadata(COL_ID))
	if column == COL_VERIFIED:
		_edit_field(id, "verified", item.is_checked(column), false)
	else:
		_edit_field(id, COLUMNS[column]["key"], item.get_text(column), false)


func _on_column_title_clicked(column: int, mouse_button: int) -> void:
	if mouse_button != MOUSE_BUTTON_LEFT:
		return
	if column == _sort_column:
		_sort_ascending = not _sort_ascending
	else:
		_sort_column = column
		_sort_ascending = true
	_queue_refresh()
