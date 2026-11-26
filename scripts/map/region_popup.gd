extends CanvasLayer
## region_popup.gd
## "Mag-adto / Balik" (Go / Back) confirmation popup for node-map travel.
## Shows locked regions as unavailable rather than hiding them, so players
## can see the full map shape before areas unlock in Phase C content scale-up.
##
## Panel/label/button structure and Akeanon button labels are J. Gumban's
## original prototype. Adapted so go_button actually travels (via MapManager)
## instead of only hiding the popup, and to show a locked/"Coming Soon" state.
## -- J.Gumban --

@onready var label: Label = $CenterContainer/PanelContainer/BoxContainer/VBoxContainer/Label
@onready var go_button: Button = $CenterContainer/PanelContainer/BoxContainer/VBoxContainer/HBoxContainer/go_button
@onready var back_button: Button = $CenterContainer/PanelContainer/BoxContainer/VBoxContainer/HBoxContainer/back_button

var region_id: String = ""
var region_name: String = ""
## Free walk for regions with a fare (docs/ECONOMY_PLAN.md): costs time, not money.
var walk_button: Button

func _ready() -> void:  # -- J.Gumban --
	hide()
	# Buttons were unthemed (default engine flat gray) — sheet texture never
	# applied. go=confirm (positive action), back=secondary, per UI Style Guide §4.
	UIThemeApplier.apply_button_theme(go_button, "confirm")
	UIThemeApplier.apply_button_theme(back_button, "secondary")
	go_button.pressed.connect(_on_go_pressed)
	back_button.pressed.connect(_on_back_pressed)
	walk_button = Button.new()
	walk_button.name = "walk_button"
	walk_button.custom_minimum_size = go_button.custom_minimum_size
	UIThemeApplier.apply_button_theme(walk_button, "secondary")
	go_button.get_parent().add_child(walk_button)
	go_button.get_parent().move_child(walk_button, go_button.get_index() + 1)
	walk_button.pressed.connect(_on_walk_pressed)

## Called by map_scene.gd on RegionArea.region_selected.
func open_for_region(new_region_id: String, new_region_name: String, region_unlocked: bool) -> void:  # -- J.Gumban -- (adapted: id + locked state)
	region_id = new_region_id
	region_name = new_region_name
	# v1.1.9 ("lacks condition to go to Bakhawan"): a locked place says what opens it.
	var hint: String = str(MapManager.get_region(region_id).get("locked_hint", ""))
	label.text = region_name if region_unlocked else ("%s\n%s" % [region_name, hint] if not hint.is_empty() else "%s (Coming Soon)" % region_name)
	go_button.disabled = not region_unlocked
	go_button.text = "Mag-adto"
	walk_button.visible = false
	if not region_unlocked:
		show()
		return
	var blocked: String = MapManager.travel_blocked_reason(region_id)
	if not blocked.is_empty():
		label.text = "%s\n%s" % [region_name, blocked]
		go_button.disabled = true
		show()
		return
	# Fare: ride (pay with coins) or walk for free (the clock moves instead).
	var fare: int = MapManager.fare_for(region_id)
	if fare > 0:
		var region: Dictionary = MapManager.get_region(region_id)
		var walk_min: int = int(region.get("walk_minutes", 0))
		var walk_text: String = ("%d h" % (walk_min / 60)) if walk_min >= 60 and walk_min % 60 == 0 else ("%d min" % walk_min)
		label.text = "%s\n%s ₱%d, or walk (%s).\nYou have ₱%d." % [region_name,
				region.get("vehicle", "Ride"), fare, walk_text, GameState.pesos]
		go_button.text = "Ride ₱%d" % fare
		go_button.disabled = GameState.pesos < fare
		walk_button.text = "Walk"
		walk_button.visible = true
	show()

func _on_go_pressed() -> void:  # -- J.Gumban -- (adapted: now actually travels)
	hide()
	MapManager.travel_to_region(region_id, MapManager.RIDE)

func _on_walk_pressed() -> void:
	hide()
	MapManager.travel_to_region(region_id, MapManager.WALK)

func _on_back_pressed() -> void:  # -- J.Gumban --
	hide()
