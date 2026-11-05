class_name HullAlarm
extends Node
## Decides when the player's hull is critical and says so once, through
## Events.player_hull_critical_changed, so everything that reacts to it (the
## screen-edge heartbeat, the dash CRT) agrees on the moment. It also owns
## the one reaction that has nowhere else to live: the music muffles, as if
## heard through a helmet, until the danger passes.
##
## Only in a fight. Limping through a shop on low hull is a choice the player
## has already made, and an alarm there would just nag.

const _KLAXON_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/alarm_klaxon.tres")

## Hull at or below this share of max (and above zero) is critical.
const CRITICAL_FRACTION: float = 0.3

## How muffled the music gets. Low enough to read as "something is wrong",
## high enough that the melody still carries.
const _MUFFLED_CUTOFF_HZ: float = 1400.0
## Where the filter starts and ends: above anything audible, so adding and
## removing it never clicks.
const _OPEN_CUTOFF_HZ: float = 20000.0
const _MUFFLE_SECONDS: float = 1.2
const _UNMUFFLE_SECONDS: float = 2.0

## How long the red-alert pulse that marks the drop into critical lasts.
const _ALERT_SECONDS: float = 1.1

const _MUSIC_BUS: StringName = &"Music"

var is_critical: bool = false

var _health: Health
var _filter: AudioEffectLowPassFilter
var _filter_tween: Tween


## Whether [param health] out of [param max_health] is critical. Zero isn't:
## by then the cockpit is coming apart, and that has its own show.
static func is_critical_at(health: int, max_health: int) -> bool:
	return max_health > 0 and health > 0 and health <= max_health * CRITICAL_FRACTION


func bind(health: Health) -> void:
	_health = health
	_health.health_set.connect(_refresh.bind(true))
	Events.start_combat.connect(_refresh.bind(false))
	Events.combat_finished.connect(_refresh.bind(false))
	Events.game_over.connect(_refresh.bind(false))


func _exit_tree() -> void:
	# The music outlives this scene; it mustn't stay muffled on the menu.
	_remove_filter()


## [param announce] is set when the hull itself changed: a hit that drops the
## ship into critical sounds the klaxon, while a fight that merely starts
## with it already there doesn't.
func _refresh(announce: bool) -> void:
	if not is_instance_valid(_health):
		return
	var in_combat: bool = Globals.state_manager != null \
		and Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT
	var critical: bool = in_combat and is_critical_at(_health.health, _health.max_health)
	if critical == is_critical:
		return
	is_critical = critical
	_set_muffled(critical)
	if critical and announce:
		Events.play_sound.emit(_KLAXON_SFX)
		Events.red_alert.emit(_ALERT_SECONDS)
	Events.player_hull_critical_changed.emit(critical)


func _set_muffled(muffled: bool) -> void:
	if muffled and _filter == null:
		var bus: int = AudioServer.get_bus_index(_MUSIC_BUS)
		if bus == -1:
			return
		_filter = AudioEffectLowPassFilter.new()
		_filter.cutoff_hz = _OPEN_CUTOFF_HZ
		AudioServer.add_bus_effect(bus, _filter)
	if _filter == null:
		return

	if _filter_tween and _filter_tween.is_valid():
		_filter_tween.kill()
	# Real time: a hitstop or the death slow-mo shouldn't stall the music.
	_filter_tween = create_tween().set_ignore_time_scale(true)
	_filter_tween.tween_property(_filter, "cutoff_hz",
		_MUFFLED_CUTOFF_HZ if muffled else _OPEN_CUTOFF_HZ,
		_MUFFLE_SECONDS if muffled else _UNMUFFLE_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if muffled else Tween.EASE_IN)
	if not muffled:
		_filter_tween.finished.connect(_remove_filter)


func _remove_filter() -> void:
	if _filter == null:
		return
	var bus: int = AudioServer.get_bus_index(_MUSIC_BUS)
	if bus != -1:
		for i: int in AudioServer.get_bus_effect_count(bus):
			if AudioServer.get_bus_effect(bus, i) == _filter:
				AudioServer.remove_bus_effect(bus, i)
				break
	_filter = null
