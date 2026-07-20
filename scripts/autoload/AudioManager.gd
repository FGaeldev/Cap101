# scripts/autoload/AudioManager.gd
# Autoload. play_sfx(id) / play_bgm(id) audio interface. Creates "Music" and
# "SFX" buses under Master at runtime (no default_bus_layout.tres dependency).
extends Node

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

const SFX_LIBRARY := {
	"advance":         "res://assets/audio/sfx/advance.wav",
	"word_discovered": "res://assets/audio/sfx/word_discovered.wav",
	"quest_complete":  "res://assets/audio/sfx/quest_complete.wav",
	"menu_click":      "res://assets/audio/sfx/menu_click.wav",
}

const BGM_LIBRARY := {
	"village": "res://assets/audio/bgm/village_loop.wav",
}
# village_loop.wav needs "Loop" enabled in Import dock (off by default).

var _bgm_player: AudioStreamPlayer
var _current_bgm_id: String = ""

func _ready() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = MUSIC_BUS
	add_child(_bgm_player)

	# Requires AudioManager declared after GameState + QuestManager in
	# project.godot's [autoload] list.
	GameState.word_learned.connect(func(_id, _akeanon, _gloss): play_sfx("word_discovered"))
	QuestManager.quest_completed.connect(func(_id): play_sfx("quest_complete"))

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")

## Fire-and-forget one-shot; frees itself when playback finishes.
func play_sfx(id: String) -> void:
	if id not in SFX_LIBRARY:
		push_warning("AudioManager: unknown sfx id '%s'" % id)
		return
	var stream: AudioStream = load(SFX_LIBRARY[id])
	if stream == null:
		push_warning("AudioManager: failed to load sfx '%s' at %s" % [id, SFX_LIBRARY[id]])
		return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = SFX_BUS
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

## No-ops if the requested track is already playing (e.g. re-entering the
## same area shouldn't restart the loop from zero).
func play_bgm(id: String) -> void:
	if id == _current_bgm_id and _bgm_player.playing:
		return
	if id not in BGM_LIBRARY:
		push_warning("AudioManager: unknown bgm id '%s'" % id)
		return
	var stream: AudioStream = load(BGM_LIBRARY[id])
	if stream == null:
		push_warning("AudioManager: failed to load bgm '%s' at %s" % [id, BGM_LIBRARY[id]])
		return

	_bgm_player.stream = stream
	_bgm_player.play()
	_current_bgm_id = id

func stop_bgm() -> void:
	_bgm_player.stop()
	_current_bgm_id = ""

## Bus volume, linear 0.0-1.0.
func set_master_volume(linear: float) -> void:
	_set_bus_volume("Master", linear)

func set_music_volume(linear: float) -> void:
	_set_bus_volume(MUSIC_BUS, linear)

func set_sfx_volume(linear: float) -> void:
	_set_bus_volume(SFX_BUS, linear)

func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clamp(linear, 0.0, 1.0)))
