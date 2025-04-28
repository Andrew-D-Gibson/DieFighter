class_name HealthBarController
extends Node2D

@export_category('Behavior')
@export var damage_update_time: float = 0.75
var need_to_update_health_white: bool = false
var time_since_health_change: float = 0

@export var text_shake_time: float = 0.25
@export var text_shake_level: int = 8
var health_label_shake_time: float = 0
var shields_label_shake_time: float = 0


@export_category('Components')
@export var health_component: Health


func _ready() -> void:
	_set_shields()
	_set_health()
	
	# Connect health signals
	health_component.health_set.connect(_set_health)
	health_component.health_damaged.connect(func():
		_set_health()
		_start_health_text_shake()
	)
	health_component.health_healed.connect(_set_health)
	
	# Connect shield signals
	health_component.shields_set.connect(_set_shields)
	health_component.shields_damaged.connect(func():
		_set_shields()
		_start_shield_text_shake()
	)
	health_component.shields_reinforced.connect(_set_shields)
	
	
func _process(delta: float) -> void:
	# Handle updating the white damage indicator after hull damage
	if need_to_update_health_white:
		if time_since_health_change > damage_update_time:
			var tween_time = 0.5
			var tween = get_tree().create_tween()
			tween.tween_property($HealthUpdateBar, 'value', float(health_component.health) / health_component.max_health, tween_time).from_current().set_trans(Tween.TRANS_QUAD)
			
			need_to_update_health_white = false
		else:
			time_since_health_change += delta
	
	# Wait for the health shake to stop
	if health_label_shake_time > 0:
		health_label_shake_time -= delta
		
		# Check if we need to end the shake
		if health_label_shake_time < 0:
			$HealthLabel.text = _get_health_string()
		
	# Wait for the shield shake to stop
	if shields_label_shake_time > 0:
		shields_label_shake_time -= delta
		
		# Check if we need to end the shake
		if shields_label_shake_time < 0:
			$ShieldsLabel.text = _get_shield_string()


func _get_health_string() -> String:
	return 'HULL\n' + str(health_component.health) + '/' + str(health_component.max_health)


func _get_shield_string() -> String:
	return str(health_component.shields)
	
	
func _set_health() -> void:
	var tween_time = 0.1
	var tween = get_tree().create_tween()
	tween.tween_property($HealthBar, 'value', float(health_component.health) / health_component.max_health, tween_time).from_current().set_trans(Tween.TRANS_QUAD)
	
	need_to_update_health_white = true
	time_since_health_change = 0
	
	$HealthLabel.text = _get_health_string()


func _start_health_text_shake() -> void:
	$HealthLabel.text = '[shake rate=75, level=' + str(text_shake_level) + ']' + _get_health_string() + '[/shake]'
	health_label_shake_time = text_shake_time
	

func _set_shields() -> void:
	$ShieldsLabel.text = _get_shield_string()
	
	if health_component.shields <= 0:
		$Shields.visible = false
		return
	
	$Shields.visible = true


func _start_shield_text_shake() -> void:
	$ShieldsLabel.text = '[shake rate=75, level=' + str(text_shake_level + 2) + ']' + _get_shield_string() + '[/shake]'
	shields_label_shake_time = text_shake_time
