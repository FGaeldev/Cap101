# scripts/autoload/AudioManager.gd
# Autoload. Audio stub — Roadmap Phase A / GDD §3.6, zero-progress panel-flagged
# item ("original sound", Suggestion_from_Pannelists). Same register-on-ready,
# call-through-autoload pattern as every other system (TDD §2) — no per-scene
# audio setup needed, just AudioManager.play_sfx(id) / play_bgm(id).
#
# Creates "Music" and "SFX" buses under Master at runtime instead of shipping
# a hand-edited default_bus_layout.tres — one less binary resource to merge
# conflicts on, and it self-heals if the bus layout ever gets reset in editor.
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

var _bgm_player: AudioStreamPlayer
var _current_bgm_id: String = ""

func _ready() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = MUSIC_BUS
	add_child(_bgm_player)

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")

## Fire-and-forget one-shot. Spins up a temp AudioStreamPlayer and frees
## itself on finish — no fixed-size pool to manage for a handful of stings.
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

## Bus volume, linear 0.0-1.0 (matches Roadmap's "bus volume" stub ask).
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
