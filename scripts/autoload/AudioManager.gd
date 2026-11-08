# scripts/autoload/AudioManager.gd
# Autoload. play_sfx(id) / play_bgm(id) audio interface. Creates "Music" and
# "SFX" buses under Master at runtime (no default_bus_layout.tres dependency).
extends Node

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

## Volumes are a device setting (like UIScale / Accessibility), not part of a
## save slot: user://settings.cfg [audio], linear 0.0-1.0 per bus.
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "audio"
## First-launch volumes, by bus name (also the config keys).
const DEFAULT_VOLUMES := {"Master": 0.5, MUSIC_BUS: 1.0, SFX_BUS: 1.0}
## Slider drags change the volume every frame; write the file once they settle.
const SAVE_DELAY := 0.5

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
var _save_queued := false

func _ready() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_load_volumes()

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

## Bus volume, linear 0.0-1.0. Saved to settings.cfg shortly after.
func set_master_volume(linear: float) -> void:
	_set_bus_volume("Master", linear)
	_queue_save()

func set_music_volume(linear: float) -> void:
	_set_bus_volume(MUSIC_BUS, linear)
	_queue_save()

func set_sfx_volume(linear: float) -> void:
	_set_bus_volume(SFX_BUS, linear)
	_queue_save()

## Current volume of a bus, linear 0.0-1.0 (1.0 if the bus doesn't exist).
func get_volume(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))

func _load_volumes() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)  # a missing file just means defaults
	for bus_name: String in DEFAULT_VOLUMES:
		_set_bus_volume(bus_name, float(config.get_value(SETTINGS_SECTION, bus_name, DEFAULT_VOLUMES[bus_name])))

func _queue_save() -> void:
	if _save_queued:
		return
	_save_queued = true
	await get_tree().create_timer(SAVE_DELAY).timeout
	_save_queued = false
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)  # keeps the other sections
	for bus_name: String in DEFAULT_VOLUMES:
		config.set_value(SETTINGS_SECTION, bus_name, snappedf(get_volume(bus_name), 0.01))
	config.save(SETTINGS_PATH)

func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clamp(linear, 0.0, 1.0)))
