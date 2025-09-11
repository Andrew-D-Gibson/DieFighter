class_name PlayerHealthBar
extends HealthBarController


func _ready() -> void:
	super()
	%Shields.visible = false
	%HealthUpdateBar.visible = false
	%HealthBar.visible = false
	%HealthLabel.visible = false
	%ShieldsLabel.visible = false
	
	%RevealOverlay.material.set_shader_parameter("progress", 0)
	
	Events.health_bar_startup.connect(_startup)
	
	
func _set_shields() -> void:		
	super()
	if health_component.shields < health_component.max_health / 2.0:
		%Shields.frame = 2
	elif health_component.shields < health_component.max_health:
		%Shields.frame = 1
	else:\
		%Shields.frame = 0


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
	%Shields.visible = true
	%HealthUpdateBar.visible = true
	%HealthBar.visible = true
	%HealthLabel.visible = true
	%ShieldsLabel.visible = true
	
	%HealthBar.value = 0
	%HealthUpdateBar.value = 0
	Globals.player.health.health = Globals.player.health.starting_health
	
	_reveal_tween()
	
	
func _show_hull_info() -> void:
	var info: InfoResource = InfoResource.new()
	info.title_label_text = "[color=red]Hull[/color]"
	info.texture = load("uid://cdul5hb8yotks")
	info.bottom_label_text = "If [color=red]Hull[/color] reaches 0, your ship is destroyed"
	
	Events.show_info.emit(info)
	
	
func _show_shield_info() -> void:
	var info: InfoResource = InfoResource.new()
	info.title_label_text = "[color=blue]Shields[/color]"
	info.texture = load("uid://cm0dbq7jogf17")
	info.bottom_label_text = "[color=blue]Shields[/color] absorb [color=red]damage[/color] before it reaches your [color=red]Hull[/color]. Resets after jumping"
	
	Events.show_info.emit(info)


func _reveal_tween() -> void:
	var tween: Tween = get_tree().create_tween()
	var reveal_time: float = 2
	var max_progress: int = 45
	
	tween.tween_property(
		%RevealOverlay, 
		"material:shader_parameter/progress", 
		max_progress, 
		reveal_time
	).from(0)\
	.set_trans(Tween.TRANS_QUAD)\
	.set_ease(Tween.EASE_OUT)
