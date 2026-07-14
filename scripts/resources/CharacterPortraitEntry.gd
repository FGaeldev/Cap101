# CharacterPortraitEntry.gd
# One row = one speaker's portrait. Editable in Inspector, no code touch to add NPC.
class_name CharacterPortraitEntry
extends Resource

@export var speaker_id: String = ""      # matches "speaker" field in dialogue JSON, e.g. "father"
@export var portrait: Texture2D = null
