class_name PlayerHealthBar
extends HealthBarController

const _HULL_INFO_TEXTURE: Texture2D = preload("uid://cdul5hb8yotks")
const _SHIELDS_INFO_TEXTURE: Texture2D = preload("uid://cm0dbq7jogf17")

## Shield sprite frames, strongest first.
const SHIELD_FRAME_FULL: int = 0
const SHIELD_FRAME_MEDIUM: int = 1
const SHIELD_FRAME_LOW: int = 2


func _ready() -> void:
	super()
	
	%RevealOverlay.material = %RevealOverlay.material.duplicate()
	%RevealOverlay.material.set_shader_parameter("progress", 0.0)
	
	Events.health_bar_startup.connect(_startup)
	Events.cockpit_snap_online.connect(_snap_online)
	
	
func _set_shields() -> void:
	# The base class hides the sprite at zero shields; the frame only matters
	# while it shows.
	super()
	%Shields.frame = shield_frame(health_component.shields, health_component.max_health)


## Which shield sprite frame [param shields] reads as, measured against the
## hull's [param max_health]: full from half the hull up, medium from a
## quarter, low below that.
static func shield_frame(shields: int, max_health: int) -> int:
	if shields >= max_health / 2.0:
		return SHIELD_FRAME_FULL
	if shields >= max_health / 4.0:
		return SHIELD_FRAME_MEDIUM
	return SHIELD_FRAME_LOW


func _get_health_string() -> String:
	return "[wave amp=2.0 freq=1.0 connected=0]HULL\n" + \
	str(health_component.health) + '/' + \
	str(health_component.max_health) + \
	"[/wave]"


func _get_shield_string() -> String:
	return "[wave amp=2.0 freq=1.0 connected=0]" + \
	str(health_component.shields) + \
	"[/wave]"


func _startup() -> void:
	Globals.player.health.health = Globals.player.health.starting_health
	
	_reveal_tween()
	
	
## Same end state as _startup(), reached instantly. The cold open has no room
## for a two-second wipe — the bar needs to already be reading damage when the
## player's eyes land on it.
func _snap_online() -> void:
	Globals.player.health.health = Globals.player.health.starting_health
	%RevealOverlay.hide()
	
	
func _show_hull_info() -> void:
	var info: InfoResource = InfoResource.new()
	info.title_label_text = "[color=red]Hull[/color]"
	info.texture = _HULL_INFO_TEXTURE
	info.bottom_label_text = "If [color=red]Hull[/color] reaches 0, your ship is destroyed"
	
	Events.show_info.emit(info)
	
	
func _show_shield_info() -> void:
	var info: InfoResource = InfoResource.new()
	info.title_label_text = "[color=blue]Shields[/color]"
	info.texture = _SHIELDS_INFO_TEXTURE
	info.bottom_label_text = "[color=blue]Shields[/color] absorb [color=red]damage[/color] before it reaches your [color=red]Hull[/color]. Resets after jumping"
	
	Events.show_info.emit(info)


func _reveal_tween() -> void:
	await RevealOverlay.play(%RevealOverlay, 2.0, 22.0)
