# page_journal.gd — PageLeft for Journal (bucket_list) tab.
#
# Was previously the map thumbnail/entry point (MapButton + Philippines/Aklan
# labels) back when Map lived behind a separate overlay. Map is now its own
# BookUI tab (page_map.gd), so that's gone — this is back to an empty
# scaffold. Journal content itself (quest log? achievements? both?) is still
# an open decision — Roadmap Phase A, GDD §6 open question 4 territory —
# not resolved here, just cleaned of the stale map trigger.
extends Control

@onready var placeholder_label: Label = $PlaceholderLabel

func _ready() -> void:
	placeholder_label.text = "Journal — content coming soon"
	placeholder_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	placeholder_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
