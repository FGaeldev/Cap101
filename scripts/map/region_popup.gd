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

func _ready() -> void:  # -- J.Gumban --
	hide()
	go_button.pressed.connect(_on_go_pressed)
	back_button.pressed.connect(_on_back_pressed)

## Called by map_scene.gd on RegionArea.region_selected.
func open_for_region(new_region_id: String, new_region_name: String, region_unlocked: bool) -> void:  # -- J.Gumban -- (adapted: id + locked state)
	region_id = new_region_id
	region_name = new_region_name
	label.text = region_name if region_unlocked else "%s (Coming Soon)" % region_name
	go_button.disabled = not region_unlocked
	show()

func _on_go_pressed() -> void:  # -- J.Gumban -- (adapted: now actually travels)
	hide()
	MapManager.travel_to_region(region_id)

func _on_back_pressed() -> void:  # -- J.Gumban --
	hide()
